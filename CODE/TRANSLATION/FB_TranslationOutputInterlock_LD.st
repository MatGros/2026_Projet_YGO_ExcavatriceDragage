(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_TranslationOutputInterlock_LD — Barrière finale frein / AC600 M3
   ───────────────────────────────────────────────────────────────
   📥 Reçoit exclusivement les demandes métier de FB_Translation.
   📤 Produit seul les commandes AC600 et frein vers PRG_06_Outputs_LD.
   🆕 LOT2 2026-08-05 : DriveFreqRefWord (WORD, échelle ×100 confirmée terrain)
      ajouté en sortie — seule forme exploitable par le mapping E/S CODESYS du
      registre PDO 0x3100 (DriveFreqRefHz en REAL reste disponible, IHM/diag).
   🔒 BrakeCommandOpenConfirmed confirme le contacteur/bobine de desserrage,
      jamais la position mécanique du frein.
   ⏱️ Watchdog fixe T#500ms, démarré uniquement par BrakeReleaseRequest.
   🔑 Après timeout, RestartInhibit exige : Reset avec cause disparue,
      demande neutre explicite (mot 0), puis nouvelle demande 1 ou 2.
   🔧 REX 2026-08-05 : Reset du watchdog frein reconstruit en pattern Cause/Ack
      (CODE_QUALITY_STANDARDS §9) — plus jamais conditionné par un état externe
      instantané (audit sécurité M3, même classe que l'incident EmergencyArmingFailed).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationOutputInterlock_LD
VAR_INPUT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL; // 🔧 REX 2026-08-05 (audit sécurité) : volontairement non lu ci-dessous —
                                          // SafeStop est une rampe rapide gérée en amont par FB_Translation
                                          // (Enable maintenu, AGENTS.md "SafeStop = rampe rapide"). Cette barrière
                                          // ne coupe qu'après la retombée effective de la demande à zéro, sauf
                                          // gate dur/timeout/défaut final (§4) — couper ici immédiatement sur
                                          // SafeStop dupliquerait la rampe en un arrêt brutal, contraire au
                                          // comportement spécifié. Entrée conservée pour interface standard
                                          // complète (AF_Partie-03 §1bis), pas un oubli.
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL;
    RequestedDriveControlWord    : WORD; // 0=None, 1=Fwd, 2=Rev, 7=Reset AC600
    RequestedDriveFreqHz         : REAL;
END_VAR
VAR_OUTPUT
    Ready                        : BOOL;
    Busy                         : BOOL;
    Done                         : BOOL;
    Error                        : BOOL;
    ErrorId                      : WORD; // bit0 : absence confirmation contacteur desserrage > 500 ms
    State                        : E_State;
    StateAtError                 : E_State;
    Reason                       : E_TranslationFinalInterlockReason;
    BrakeTimeoutElapsed          : TIME;
    RestartInhibit               : BOOL; // TRUE : neutralisation puis nouvelle demande exigées après défaut
    DriveControlWord             : WORD;
    DriveFreqRefHz               : REAL;
    DriveFreqRefWord             : WORD; // 🆕 LOT2 2026-08-05 : DriveFreqRefHz mis à l'échelle registre PDO 0x3100 (WORD, écriture EtherCAT)
    BrakeCmd                     : BOOL;
END_VAR
VAR
    ResetEdge                    : R_TRIG;
    ErrorEdge                    : R_TRIG;
    BrakeTimeout                 : TON;
    MovementRequested            : BOOL;
    NeutralRequestSeen           : BOOL;
    ResetRequired                : BOOL; // Timeout : front Reset obligatoire avant toute nouvelle marche
    // 🔧 REX 2026-08-05 : pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) — voir §2 ci-dessous
    BrakeTimeoutCause             : BOOL;
    BrakeTimeoutAck               : BOOL := TRUE;
    BrakeTimeoutCauseEdge         : R_TRIG;
END_VAR
VAR CONSTANT
    // 🆕 LOT2 2026-08-05 : échelle confirmée terrain (utilisateur) sur le registre 0x3100
    // AC600 (M3_SetpointFrequencyHz, %QW7) — WORD=5000 correspond à 50,00 Hz, même
    // résolution 0,01 Hz que le retour mesuré 0x3102 (M3_ActualFrequencyHz_Filtered).
    DriveFreqWordScale            : REAL := 100.0;
    // Borne haute avant conversion : marge large sous le plafond WORD (655,35 Hz à l'échelle
    // ci-dessus) tout en restant très au-dessus de _TranslationMaxFreq_Hz (60,0 Hz nominal) —
    // protège uniquement contre un débordement WORD, pas une limite métier (déjà bornée en amont).
    DriveFreqWordMaxHz            : REAL := 600.0;
END_VAR

// ── 1. FRONT RESET AVANT GATE ───────────────────────────────────────────
// Le front est échantillonné même pendant Enable/AU faux. Un Reset maintenu
// durant une gate ne peut donc jamais devenir un faux acquittement au retour.
ResetEdge(CLK := Reset);

// RestartInhibit et ResetRequired sont volontairement conservés : un changement
// Enable/AU ne doit jamais réautoriser automatiquement le mouvement après timeout.
IF NOT Enable OR NOT PowerContactorEngaged THEN
    BrakeTimeout(IN := FALSE, PT := T#500ms);
    DriveControlWord := 0;
    DriveFreqRefHz := 0.0;
    DriveFreqRefWord := 0;
    BrakeCmd := FALSE;
    BrakeTimeoutElapsed := T#0ms;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    // ErrorId reste publiquement visible même hors Enable/AU : une retombée de gate
    // ne doit jamais masquer un timeout mémorisé ni remplacer l'acquittement conscient.
    Error := (ErrorId <> 16#0000);
    State := E_State.DISABLED;
    Reason := E_TranslationFinalInterlockReason.NONE;
    RETURN;
END_IF;

MovementRequested := (RequestedDriveControlWord = 1) OR (RequestedDriveControlWord = 2);

// ── 2. Watchdog : exclusivement après ordre effectif de desserrage ──────
// Pendant RestartInhibit, BrakeCmd reste coupé : l'ordre amont n'est donc plus
// effectif et le watchdog ne doit pas créer une nouvelle faute en boucle.
// 🔧 REX 2026-08-05 : pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) — l'ancien
// "ELSIF ResetEdge.Q AND BrakeCommandOpenConfirmed" pouvait perdre silencieusement
// un front Reset si BrakeCommandOpenConfirmed rebondissait à FALSE exactement au
// scan du Reset (même classe que l'incident EmergencyArmingFailed). Le Reset est
// désormais TOUJOURS effectif sur l'acquittement (BrakeTimeoutAck) ; l'interlock de
// sécurité (RestartInhibit, §3) reste basé sur la cause brute (BrakeTimeoutCause /
// Error), jamais sur l'acquittement seul — l'acquittement n'ouvre jamais l'interlock.
BrakeTimeout(IN := BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed
                   AND NOT RestartInhibit, PT := T#500ms);
BrakeTimeoutElapsed := BrakeTimeout.ET;
IF BrakeTimeout.Q THEN
    BrakeTimeoutCause := TRUE;
ELSIF BrakeCommandOpenConfirmed THEN
    BrakeTimeoutCause := FALSE;   // cause réellement disparue (retour desserrage confirmé)
END_IF;
BrakeTimeoutCauseEdge(CLK := BrakeTimeoutCause);
IF BrakeTimeoutCauseEdge.Q THEN
    BrakeTimeoutAck := FALSE;    // nouvelle occurrence -> ré-alarme, ack remis à zéro
    RestartInhibit := TRUE;
    ResetRequired := TRUE;
    NeutralRequestSeen := FALSE;
    Reason := E_TranslationFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED;
END_IF;
IF ResetEdge.Q THEN
    BrakeTimeoutAck := TRUE;     // toujours effectif, sans condition externe
    ResetRequired := FALSE;
END_IF;
IF BrakeTimeoutCause OR NOT BrakeTimeoutAck THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// ── 3. Réarmement anti-redémarrage automatique ──────────────────────────
// Le mot 7 est un reset AC600, pas un neutre opérateur : il reste autorisé avec
// fréquence nulle mais ne solde pas RestartInhibit. Seul le mot 0, vu APRÈS
// disparition de la cause et front Reset, autorise ensuite une nouvelle demande.
IF RestartInhibit AND NOT Error AND NOT ResetRequired AND NOT ResetEdge.Q THEN
    IF RequestedDriveControlWord = 0 THEN
        NeutralRequestSeen := TRUE;
    ELSIF NeutralRequestSeen AND MovementRequested THEN
        RestartInhibit := FALSE;
        NeutralRequestSeen := FALSE;
    END_IF;
END_IF;

// ── 4. Décision finale : zéro couple utile sans confirmation frein ──────
DriveControlWord := 0;
DriveFreqRefHz := 0.0;
DriveFreqRefWord := 0;
// SafeStop est traité en amont par FB_Translation : rampe rapide avec Enable
// maintenu. La commande/frein suivent cette rampe jusqu'à demande nulle ; seul
// un gate dur, timeout ou défaut final impose ici la coupure immédiate.
BrakeCmd := BrakeReleaseRequest AND NOT Error AND NOT RestartInhibit;
Ready := NOT Error AND NOT RestartInhibit;
Busy := FALSE;
Done := FALSE;
State := E_State.READY;

IF Error THEN
    BrakeCmd := FALSE;
    State := E_State.DISABLED;
ELSIF RequestedDriveControlWord = 7 THEN
    // Reset AC600 préservé, toujours sans consigne fréquence ni couple utile.
    DriveControlWord := 7;
ELSIF RestartInhibit THEN
    Reason := E_TranslationFinalInterlockReason.RESTART_INHIBITED;
    State := E_State.INIT;
ELSIF MovementRequested THEN
    // Double condition obligatoire : ordre effectif de desserrage ET confirmation
    // contacteur/bobine. Une confirmation résiduelle seule ne peut jamais autoriser
    // couple ou fréquence AC600.
    IF BrakeReleaseRequest AND BrakeCommandOpenConfirmed THEN
        DriveControlWord := RequestedDriveControlWord;
        DriveFreqRefHz := MAX(0.0, RequestedDriveFreqHz);
        Busy := TRUE;
        State := E_State.BUSY;
    ELSE
        Busy := TRUE;
        State := E_State.INIT;
    END_IF;
END_IF;

// ── 5. Mise à l'échelle finale REAL Hz -> WORD registre PDO 0x3100 ──────
// 🆕 LOT2 2026-08-05 : conversion unique en sortie de chaîne, quelle que soit la branche
// qui a fixé DriveFreqRefHz ci-dessus — jamais recalculée ailleurs (producteur unique).
DriveFreqRefWord := REAL_TO_WORD(LIMIT(0.0, DriveFreqRefHz, DriveFreqWordMaxHz) * DriveFreqWordScale);

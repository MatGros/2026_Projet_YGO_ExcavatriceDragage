(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_TranslationOutputInterlock_LD — Barrière finale frein / AC600 M3
   ───────────────────────────────────────────────────────────────
   📥 Reçoit exclusivement les demandes métier de FB_Translation.
   📤 Produit seul les commandes AC600 et frein vers PRG_10_Outputs_LD.
   🔒 BrakeCommandOpenConfirmed confirme le contacteur/bobine de desserrage,
      jamais la position mécanique du frein.
   ⏱️ Watchdog fixe T#500ms, démarré uniquement par BrakeReleaseRequest.
   🔑 Après timeout, RestartInhibit exige : Reset avec cause disparue,
      demande neutre explicite (mot 0), puis nouvelle demande 1 ou 2.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationOutputInterlock_LD
VAR_INPUT
    Enable                       : BOOL;
    Reset                        : BOOL;
    EmergencyStopOk              : BOOL;
    SafeStop                     : BOOL;
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
    BrakeCmd                     : BOOL;
END_VAR
VAR
    ResetEdge                    : R_TRIG;
    ErrorEdge                    : R_TRIG;
    BrakeTimeout                 : TON;
    MovementRequested            : BOOL;
    NeutralRequestSeen           : BOOL;
    ResetRequired                : BOOL; // Timeout : front Reset obligatoire avant toute nouvelle marche
END_VAR

// ── 1. FRONT RESET AVANT GATE ───────────────────────────────────────────
// Le front est échantillonné même pendant Enable/AU faux. Un Reset maintenu
// durant une gate ne peut donc jamais devenir un faux acquittement au retour.
ResetEdge(CLK := Reset);

// RestartInhibit et ResetRequired sont volontairement conservés : un changement
// Enable/AU ne doit jamais réautoriser automatiquement le mouvement après timeout.
IF NOT Enable OR NOT EmergencyStopOk THEN
    BrakeTimeout(IN := FALSE, PT := T#500ms);
    DriveControlWord := 0;
    DriveFreqRefHz := 0.0;
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
BrakeTimeout(IN := BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed
                   AND NOT RestartInhibit, PT := T#500ms);
BrakeTimeoutElapsed := BrakeTimeout.ET;
IF BrakeTimeout.Q THEN
    ErrorId := ErrorId OR 16#0001;
    RestartInhibit := TRUE;
    ResetRequired := TRUE;
    NeutralRequestSeen := FALSE;
    Reason := E_TranslationFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED;
ELSIF ResetEdge.Q AND BrakeCommandOpenConfirmed THEN
    ErrorId := ErrorId AND 16#FFFE;
    ResetRequired := FALSE;
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

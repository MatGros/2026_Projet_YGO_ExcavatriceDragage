(* =======================================================================
   🛡️ FB_TranslationOutputInterlock_LD — Barrière finale frein / AC600 M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Barrière de sécurité finale pour frein et variateur AC600 M3
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
   🔌 Interface : Interlock de sortie (entre FB_Translation et PRG_06_Outputs_LD)
   🔒 Sécurité : Surveillance feedback frein et watchdog de desserrage
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TranslationOutputInterlock_LD
VAR_INPUT
    // === COMMANDES & ETATS GENERAL ===
    Enable                       : BOOL;   // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                        : BOOL;   // --> [CMD] Acquittement defaut sur front
    SafeStop                     : BOOL;   // --> [SAFE] Entree securite pour interface standard
    PowerContactorEngaged              : BOOL;   // --> [SAFE] Chaine AU rearmee et puissance OK

    // === DEMANDES DE COMMANDE AMONT ===
    BrakeReleaseRequest          : BOOL;   // --> [CMD] Demande de desserrage frein
    BrakeCommandOpenConfirmed    : BOOL;   // --> [HW] Confirmation ouverture frein (contacteur/bobine)
    RequestedDriveControlWord    : WORD;   // --> [CMD] Mot de commande variateur (0=None, 1=Fwd, 2=Rev, 7=Reset)
    RequestedDriveFreqHz         : REAL;   // --> [CMD] Frequence de consigne variateur (Hz)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                        : BOOL;   // <-- [STAT] FB pret a fonctionner
    Busy                         : BOOL;   // <-- [STAT] Interlock actif
    Done                         : BOOL;   // <-- [STAT] Action terminee
    Error                        : BOOL;   // <-- [STAT] Synthese defaut
    ErrorId                      : WORD;   // <-- [DIAG] Code erreur (bit0: timeout desserrage frein)
    State                        : E_State;   // <-- [STAT] Etat courant machine d'etat
    StateAtError                 : E_State;   // <-- [DIAG] Etat memorise lors du dernier defaut
    Reason                       : E_TranslationFinalInterlockReason;   // <-- [DIAG] Cause de blocage

    // === ORDRES ACTIONNEURS VALIDES ===
    DriveControlWord             : WORD;   // <-- [ACT] Mot de commande variateur valide
    DriveFreqRefHz               : REAL;   // <-- [ACT] Frequence de consigne variateur valide (Hz)
    DriveFreqRefWord             : WORD;   // <-- [ACT] Frequence mise a l'echelle registre PDO 0x3100
    BrakeCmd                     : BOOL;   // <-- [ACT] Ordre ouverture frein valide

    // === DIAGNOSTICS & TEMPORISATIONS ===
    BrakeTimeoutElapsed          : TIME;   // <-- [DIAG] Ecoule temporisation watchdog frein
    RestartInhibit               : BOOL;   // <-- [DIAG] Inhibition redemarrage actif
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge                    : R_TRIG;   // . [LOC] Detecteur front montant Reset
    ErrorEdge                    : R_TRIG;   // . [LOC] Detecteur front montant Erreur
    BrakeTimeoutCauseEdge        : R_TRIG;   // . [LOC] Detecteur nouvelle occurrence cause timeout

    // === TEMPORISATEURS INTERNES ===
    BrakeTimeout                 : TON;   // . [LOC] Temporisateur watchdog desserrage frein

    // === VARIABLES LOCALES INTERNES ===
    MovementRequested            : BOOL;   // . [LOC] Demande de mouvement active
    NeutralRequestSeen           : BOOL;   // . [LOC] Demande neutre (mot 0) observee
    ResetRequired                : BOOL;   // . [LOC] Front Reset obligatoire avant nouvelle marche
    BrakeTimeoutCause            : BOOL;   // . [LOC] Cause brute timeout desserrage frein
    BrakeTimeoutAck              : BOOL := TRUE;   // . [LOC] Accuse operateur (TRUE = pas d'alarme)
END_VAR
VAR CONSTANT
    // === ECHELLE & BORNES REGISTRE PDO ===
    DriveFreqWordScale            : REAL := 100.0;   // Echelle registre 0x3100 (WORD=5000 -> 50,00 Hz)
    DriveFreqWordMaxHz            : REAL := 600.0;   // Borne haute anti-debordement WORD (Hz)
END_VAR

{region "§1 Front reset et gate"}
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
{endregion}

{region "§2 Watchdog frein"}
// ── 2. Watchdog : exclusivement après ordre effectif de desserrage ──────
// Pendant RestartInhibit, BrakeCmd reste coupé : l'ordre amont n'est donc plus
// effectif et le watchdog ne doit pas créer une nouvelle faute en boucle.
// Pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) : le Reset est TOUJOURS effectif sur
// l'acquittement (BrakeTimeoutAck), sans condition externe — un front Reset ne peut
// jamais être perdu si la confirmation rebondit au même scan. L'interlock de sécurité
// (RestartInhibit, §3) reste basé sur la cause brute (BrakeTimeoutCause / Error), jamais
// sur l'acquittement seul — l'acquittement n'ouvre jamais l'interlock.
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
{endregion}

{region "§3 Réarmement anti-redémarrage"}
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
{endregion}

{region "§4 Décision finale"}
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
{endregion}

{region "§5 Mise à l'échelle"}
// ── 5. Mise à l'échelle finale REAL Hz -> WORD registre PDO 0x3100 ──────
// Conversion unique en sortie de chaîne, quelle que soit la branche qui a fixé
// DriveFreqRefHz ci-dessus — jamais recalculée ailleurs (producteur unique).
DriveFreqRefWord := REAL_TO_WORD(LIMIT(0.0, DriveFreqRefHz, DriveFreqWordMaxHz) * DriveFreqWordScale);
{endregion}

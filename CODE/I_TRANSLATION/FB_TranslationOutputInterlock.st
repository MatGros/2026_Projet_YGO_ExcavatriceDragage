(* =======================================================================
   🛡️ FB_TranslationOutputInterlock — Barrière finale frein / AC600 M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Barrière de sécurité finale pour frein et variateur AC600 M3
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔌 Interface : Interlock de sortie (entre FB_Translation et PRG_06_Outputs)
   🔒 Sécurité : Surveillance feedback frein et watchdog de desserrage
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TranslationOutputInterlock
VAR_INPUT
    // === COMMANDES & ETATS GENERAL ===
    Enable                       : BOOL;   // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                        : BOOL;   // --> [CMD] Acquittement defaut sur front
    SafeStop                     : BOOL;   // --> [SAFE] Entree securite pour interface standard
    PowerContactorEngaged        : BOOL;   // --> [SAFE] Chaine AU rearmee et puissance OK

    // === DEMANDES DE COMMANDE AMONT ===
    BrakeReleaseRequest          : BOOL;   // --> [CMD] Demande de desserrage frein
    BrakeCommandOpenConfirmed    : BOOL;   // --> [HW] Confirmation ouverture frein (contacteur/bobine)
    RequestedDriveControlWord    : WORD;   // --> [CMD] Mot de commande variateur (0=None, 1=Fwd, 2=Rev, 7=Reset)
    RequestedDriveFreqHz         : REAL;   // --> [CMD] Frequence de consigne variateur (Hz)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                        : BOOL;   // <-- [STAT] FB pret a fonctionner (sortie libre, hors ST_Status)
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                        : ST_Fault;
    Reason                       : E_TranslationFinalInterlockReason;   // <-- [DIAG] Cause de blocage

    // === ORDRES ACTIONNEURS VALIDES ===
    DriveControlWord             : WORD;   // <-- [ACT] Mot de commande variateur valide
    DriveFreqCmd_Hz              : REAL;   // <-- [ACT] Frequence de consigne variateur valide (Hz)
    DriveFreqCmdWord             : WORD;   // <-- [ACT] Frequence mise a l'echelle registre PDO 0x3100
    BrakeCmd                     : BOOL;   // <-- [ACT] Ordre ouverture frein valide

    // === DIAGNOSTICS & TEMPORISATIONS ===
    BrakeTimeoutElapsed          : TIME;   // <-- [DIAG] Ecoule temporisation watchdog frein
    RestartInhibit               : BOOL;   // <-- [DIAG] Inhibition redemarrage actif
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge                    : R_TRIG;   // . [LOC] Detecteur front montant Reset
    BrakeTimeoutCauseEdge        : R_TRIG;   // . [LOC] Detecteur nouvelle occurrence cause timeout

    // === TEMPORISATEURS INTERNES ===
    BrakeTimeout                 : TON;   // . [LOC] Temporisateur watchdog desserrage frein

    // === VARIABLES LOCALES INTERNES ===
    MovementRequested            : BOOL;   // . [LOC] Demande de mouvement active
    NeutralRequestSeen           : BOOL;   // . [LOC] Demande neutre (mot 0) observee
    ResetRequired                : BOOL;   // . [LOC] Front Reset obligatoire avant nouvelle marche
    BrakeTimeoutCause            : BOOL;   // . [LOC] Cause brute timeout desserrage frein
    BrakeTimeoutAck              : BOOL := TRUE;   // . [LOC] Accuse operateur (TRUE = pas d'alarme)

    // === SOCLE DEFAUT ===
    instFault                    : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses                   : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées
END_VAR
VAR CONSTANT
    // === ECHELLE & BORNES REGISTRE PDO ===
    DriveFreqWordScale            : REAL := 100.0;   // Echelle registre 0x3100 (WORD=5000 -> 50,00 Hz)
    DriveFreqWordMaxHz            : REAL := 600.0;   // Borne haute anti-debordement WORD (Hz)
END_VAR

// ── 1. FRONT RESET AVANT GATE ───────────────────────────────────────────
ResetEdge(CLK := Reset);

IF NOT Enable OR NOT PowerContactorEngaged THEN
    BrakeTimeout(IN := FALSE, PT := T#500ms);
    DriveControlWord := 0;
    DriveFreqCmd_Hz := 0.0;
    DriveFreqCmdWord := 0;
    BrakeCmd := FALSE;
    BrakeTimeoutElapsed := T#0ms;
    Ready := FALSE;
    Reason := E_TranslationFinalInterlockReason.NONE;
    RETURN;
END_IF;

MovementRequested := (RequestedDriveControlWord = 1) OR (RequestedDriveControlWord = 2);

// ── 2. Watchdog : exclusivement après ordre effectif de desserrage ──────
BrakeTimeout(
    IN := BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed AND NOT RestartInhibit,
    PT := T#500ms
);
BrakeTimeoutElapsed := BrakeTimeout.ET;

IF BrakeTimeout.Q THEN
    BrakeTimeoutCause := TRUE;
ELSIF BrakeCommandOpenConfirmed THEN
    BrakeTimeoutCause := FALSE;
END_IF;

BrakeTimeoutCauseEdge(CLK := BrakeTimeoutCause);
IF BrakeTimeoutCauseEdge.Q THEN
    BrakeTimeoutAck := FALSE;
    RestartInhibit := TRUE;
    ResetRequired := TRUE;
    NeutralRequestSeen := FALSE;
    Reason := E_TranslationFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED;
END_IF;

IF ResetEdge.Q THEN
    BrakeTimeoutAck := TRUE;
    ResetRequired := FALSE;
END_IF;

instCauses[0].Active   := BrakeTimeoutCause OR NOT BrakeTimeoutAck;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Timeout confirmation ouverture frein translation';

instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

// ── 3. Réarmement anti-redémarrage automatique ──────────────────────────
IF RestartInhibit AND NOT Fault.Error AND NOT ResetRequired AND NOT ResetEdge.Q THEN
    IF RequestedDriveControlWord = 0 THEN
        NeutralRequestSeen := TRUE;
    ELSIF NeutralRequestSeen AND MovementRequested THEN
        RestartInhibit := FALSE;
        NeutralRequestSeen := FALSE;
    END_IF;
END_IF;

// ── 4. Décision finale : zéro couple utile sans confirmation frein ──────
DriveControlWord := 0;
DriveFreqCmd_Hz := 0.0;
DriveFreqCmdWord := 0;

BrakeCmd := BrakeReleaseRequest AND NOT Fault.Error AND NOT RestartInhibit;
Ready := NOT Fault.Error AND NOT RestartInhibit;

IF Fault.Error THEN
    BrakeCmd := FALSE;
ELSIF RequestedDriveControlWord = 7 THEN
    DriveControlWord := 7;
ELSIF RestartInhibit THEN
    Reason := E_TranslationFinalInterlockReason.RESTART_INHIBITED;
ELSIF MovementRequested THEN
    IF BrakeReleaseRequest AND BrakeCommandOpenConfirmed THEN
        DriveControlWord := RequestedDriveControlWord;
        DriveFreqCmd_Hz := MAX(0.0, RequestedDriveFreqHz);
    END_IF;
END_IF;

// ── 5. Mise à l'échelle finale REAL Hz -> WORD registre PDO 0x3100 ──────
DriveFreqCmdWord := REAL_TO_WORD(LIMIT(0.0, DriveFreqCmd_Hz, DriveFreqWordMaxHz) * DriveFreqWordScale);

END_FUNCTION_BLOCK

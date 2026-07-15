(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_Chariot — Bloc Safety pour le Chariot M3 (EtherCAT)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.5.md
   🔁 Rôle : Surveillance joystick, bus EtherCAT, rotation de phases, 
      thermique frein commun, Méca A (vitesse non commandée à l'arrêt), 
      Méca B (frein/variateur en mouvement à l'arrêt), et Fdc extrêmes.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Safety_Chariot
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    EmergencyStopOk     : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                : E_Mode;      // Mode courant
    JoystickOnline      : BOOL;        // instDiagCanOpen.Joystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.Joystick.Operational
    PhaseRotationOk     : BOOL;        // PRG_00_Inputs.PhaseRotationOk (TRUE = OK)
    BrakeThermalFeedback: BOOL;        // Thermique frein commun M1/M2/M3 (NC, TRUE = surchauffe/perte)

    // 🔌 Spécifique EtherCAT & Capteurs réels
    DriveOnline         : BOOL;        // Status diagnostic communication EtherCAT (Online)
    DriveOperational    : BOOL;        // Status diagnostic communication EtherCAT (Operational)
    DriveStatusWord     : WORD;        // Mot d'état variateur AC600
    DriveActualFreqHz   : REAL;        // Vitesse réelle variateur (Hz)
    BrakeFeedback       : BOOL;        // Retour d'état bobine frein (NC conditionné)
    BrakeCmd            : BOOL;        // Commande frein
    Direction           : INT;         // Direction commandée
    LimitSwitchFwd      : BOOL;        // Fin de course extrême avant
    LimitSwitchRev      : BOOL;        // Fin de course extrême arrière
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0 : perte joystick ; bit1 : perte com EtherCAT ; bit2 : rotation phases ; bit3 : thermique frein ; bit4 : Méca B (incohérence arrêt) ; bit5 : Méca A (mouvement non commandé) ; bit6 : Fdc extrême atteint
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Décélération rapide (PLC)
    PowerCutOff         : BOOL;        // 🧨 Coup de poing / coupure puissance amont
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    TonMecaB            : TON;         // Sécurité à l'arrêt (Méca B)
    TonMecaA            : TON;         // Sécurité mouvement non commandé (Méca A)
    PostRampTimeout     : TIME := T#3S;
    UncommandedActiveB  : BOOL;
    UncommandedActiveA  : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Error := FALSE;
    ErrorId := 16#0000;
    SafeStop := FALSE;
    PowerCutOff := FALSE;
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
    State := E_State.DISABLED;
    Busy := FALSE; Done := FALSE; Ready := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
ResetEdge(CLK := Reset);

// 🔍 2. PERTE JOYSTICK/CAN (bit0)
IF (NOT JoystickOnline OR NOT JoystickOperational) THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔍 2bis. PERTE ETHERCAT VARIATEUR M3 (bit1)
IF (NOT DriveOnline OR NOT DriveOperational) THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 🔍 3. MAUVAISE ROTATION DE PHASE (bit2)
IF NOT PhaseRotationOk THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// 🔍 3ter. THERMIQUE FREIN COMMUN M1/M2/M3 (bit3)
IF BrakeThermalFeedback THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🔍 3quater. INCOHÉRENCE À L'ARRÊT (Méca B — bit4)
// Si le chariot est commandé à l'arrêt (Direction = 0 et frein appliqué) mais que le variateur 
// tourne toujours (Operation bit0 = 1) ou que le frein est resté ouvert (feedback = TRUE) > 3s
IF (Direction = 0) AND NOT BrakeCmd THEN
    UncommandedActiveB := DriveStatusWord.0 OR BrakeFeedback;
ELSE
    UncommandedActiveB := FALSE;
END_IF;

TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);

IF TonMecaB.Q THEN
    ErrorId := ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFEF;
END_IF;

// 🔍 3quinquies. MOUVEMENT NON COMMANDÉ (Méca A — bit5)
// Si le chariot est commandé à l'arrêt, mais qu'une fréquence réelle est mesurée (> 0.5 Hz) pendant > 1s
IF (Direction = 0) AND NOT BrakeCmd THEN
    UncommandedActiveA := ABS(DriveActualFreqHz) > 0.5;
ELSE
    UncommandedActiveA := FALSE;
END_IF;

TonMecaA(IN := UncommandedActiveA, PT := T#1S);

IF TonMecaA.Q THEN
    ErrorId := ErrorId OR 16#0020;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFDF;
END_IF;

// 🔍 3sexies. DÉPASSEMENT FINS DE COURSE EXTRÊMES (bit6)
IF LimitSwitchFwd OR LimitSwitchRev THEN
    ErrorId := ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFBF;
END_IF;

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SafeStop := Error OR NOT EmergencyStopOk;

// PowerCutOff actif si thermique frein (bit3), incohérence arrêt (bit4),
// mouvement non commandé (bit5), ou dépassement de fin de course (bit6)
PowerCutOff := (ErrorId AND 16#0078) <> 16#0000;

Busy := FALSE;
Done := FALSE;

// 🚦 5. STATE MACHINE (phase diagnostic)
IF Error THEN
    State := E_State.ERROR;
ELSE
    State := E_State.READY;
END_IF;

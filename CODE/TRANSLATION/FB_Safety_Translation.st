(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_Translation — Bloc Safety pour le Translation M3 (EtherCAT)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.9.md
   🔁 Rôle : Surveillance joystick, bus EtherCAT, rotation de phases, 
      thermique frein commun, Méca A (vitesse non commandée à l'arrêt), 
      Méca B (frein/variateur en mouvement à l'arrêt), et Fdc extrêmes.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Safety_Translation
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    EmergencyStopOk     : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                : E_Mode;      // Mode courant
    JoystickOnline      : BOOL;        // instDiagCanOpen.DeviceJoystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.DeviceJoystick.Operational
    HeartbeatIhmOk      : BOOL;        // 💓 IHM↔PLC : TRUE après front post-boot, FALSE = perte communication opérateur
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
    SensorWordIncoherent: BOOL;        // 🆕 REX 2026-07-18 : mot des 5 capteurs position hors combinaisons valides (FB_Translation_PositionDecoder.Incoherent)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Perte communication opérateur" - joystick CAN ou heartbeat IHM absent ; bit1: "Perte communication EtherCAT" - perte com EtherCAT ; bit2: "Défaut Rotation Phases" - rotation phases ; bit3: "Surchauffe Frein Translation" - thermique frein ; bit4: "Absence confirmation arrêt (Méca B)" - Méca B (incohérence arrêt) ; bit5: "Mouvement non commandé (Méca A)" - Méca A (mouvement non commandé) ; bit6: "Limite extrême Translation atteinte" - Fdc extrême atteint ; bit7: "Incohérence mot capteurs position" - combinaison des 5 capteurs Trémie/PV/P2/P1/Maintenance hors table valide
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Décélération rapide (PLC)
    PowerCutOff         : BOOL;        // 🧨 Coup de poing / coupure puissance amont
    ErrorOperatorComm   : BOOL;        // 🎮 Perte communication opérateur : joystick CAN ou heartbeat IHM (bit0)
    ErrorDriveComm      : BOOL;        // 📡 Perte communication EtherCAT variateur (bit1)
    ErrorPhaseRotation  : BOOL;        // ⚡ Mauvaise rotation de phases (bit2)
    ErrorBrakeThermal   : BOOL;        // 🌡️ Surchauffe thermique frein commun (bit3)
    ErrorMecaB          : BOOL;        // 🛑 Absence confirmation arrêt (Méca B - bit4)
    ErrorMecaA          : BOOL;        // 🔄 Mouvement non commandé (Méca A - bit5)
    ErrorLimitSwitch    : BOOL;        // 🚧 Limite extrême Translation atteinte (bit6)
    ErrorSensorIncoherent: BOOL;       // 🧭 Incohérence mot capteurs position (bit7)
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
    ErrorOperatorComm := FALSE;
    ErrorDriveComm := FALSE;
    ErrorPhaseRotation := FALSE;
    ErrorBrakeThermal := FALSE;
    ErrorMecaB := FALSE;
    ErrorMecaA := FALSE;
    ErrorLimitSwitch := FALSE;
    ErrorSensorIncoherent := FALSE;
    TonMecaB(IN := FALSE);
    TonMecaA(IN := FALSE);
    State := E_State.DISABLED;
    Busy := FALSE; Done := FALSE; Ready := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
ResetEdge(CLK := Reset);

// 🔍 2. PERTE COMMUNICATION OPÉRATEUR (bit0) — joystick CAN ou heartbeat IHM.
IF (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk) THEN
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
// Si le translation est commandé à l'arrêt (Direction = 0 et frein appliqué) mais que le variateur 
// tourne toujours (Operation bit0 = 1) ou que le frein est resté ouvert (feedback = TRUE) > 3s
IF NOT HeartbeatIhmOk THEN
    // 💓 Perte IHM : l'arrêt est exigé même si une ancienne Direction reste mémorisée.
    // Méca B confirme fréquence nulle, variateur hors Operation et frein serré avant de
    // laisser l'escalade PowerCutOff intervenir après PostRampTimeout.
    UncommandedActiveB := (ABS(DriveActualFreqHz) > 0.5) OR DriveStatusWord.0 OR BrakeFeedback;
ELSIF (Direction = 0) AND NOT BrakeCmd THEN
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
// Si le translation est commandé à l'arrêt, mais qu'une fréquence réelle est mesurée (> 0.5 Hz) pendant > 1s
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

// 🔍 3septies. INCOHÉRENCE MOT CAPTEURS POSITION (bit7)
// 🆕 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 §3bis) — toute combinaison des 5
// capteurs Trémie/PV/P2/P1/Maintenance hors des 6 mots valides (progression monotone) signale
// un capteur collé/HS ou un défaut mécanique : escalade SafeStop + PowerCutOff, même traitement
// que Méca A/B (défense en profondeur, décision utilisateur).
IF SensorWordIncoherent THEN
    ErrorId := ErrorId OR 16#0080;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FF7F;
END_IF;

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SafeStop := Error OR NOT EmergencyStopOk;

// PowerCutOff actif si thermique frein (bit3), incohérence arrêt (bit4),
// mouvement non commandé (bit5), dépassement de fin de course (bit6),
// ou incohérence mot capteurs position (bit7)
PowerCutOff := (ErrorId AND 16#00F8) <> 16#0000;

// Décapsulage du bitfield ErrorId pour l'IHM
ErrorOperatorComm   := (ErrorId AND 16#0001) <> 16#0000;
ErrorDriveComm      := (ErrorId AND 16#0002) <> 16#0000;
ErrorPhaseRotation  := (ErrorId AND 16#0004) <> 16#0000;
ErrorBrakeThermal   := (ErrorId AND 16#0008) <> 16#0000;
ErrorMecaB          := (ErrorId AND 16#0010) <> 16#0000;
ErrorMecaA          := (ErrorId AND 16#0020) <> 16#0000;
ErrorLimitSwitch    := (ErrorId AND 16#0040) <> 16#0000;
ErrorSensorIncoherent := (ErrorId AND 16#0080) <> 16#0000;

Busy := FALSE;
Done := FALSE;

// 🚦 5. STATE MACHINE (phase diagnostic)
State := E_State.READY;


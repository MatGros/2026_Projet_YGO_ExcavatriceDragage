(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Translation — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.7.md
   🔌 FB DE MOUVEMENT : porte StartStop + SafeStop en plus de l'interface
      standard. Précédence Enable > SafeStop > StartStop.
   📡 Pilotage exclusivement ETHERCAT nominal (mot de commande, consigne fréquence).
   🧩 Compose FB_Brake (réutilisé TEL QUEL depuis COMMUN).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation
VAR_INPUT
    Enable                      : BOOL;        // Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                       : BOOL;        // Acquittement défaut (front)
    EmergencyStopOk             : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                        : E_Mode;      // Mode courant
    StartStop                   : BOOL;        // TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                    : BOOL;        // Sortie FB_Safety_Translation : TRUE = rampe décélération RAPIDE (Enable maintenu)
    Direction                   : INT;         // -1 = Rev, 0 = Neutre, +1 = Fwd (source d'autorité du sens)
    SpeedRefPct                 : REAL;        // Magnitude de la consigne (de 0 à 100%)
    PositionSensorTarget        : BOOL;        // Capteur position cible courante
    LimitSwitchFwd              : BOOL;        // Fin de course extrême avant
    LimitSwitchRev              : BOOL;        // Fin de course extrême arrière

    // 🔌 Spécifique ETHERCAT (image process EtherCAT, rafraîchie par EtherCatTask 4ms)
    DriveStatusWord              : WORD;       // Mot d'état AC600 lu depuis l'image d'entrée EtherCAT
    DriveActualFreqHz            : REAL;       // Fréquence réelle mesurée (Hz)

    BypassContactorCheck         : BOOL;       // 🧪 TRUE = désactive StuckClosed/StuckOpen pour le frein (simulation)
    BrakeFeedback                : BOOL;       // Retour d'état câblé bobine frein translation

    // Réglages rampe (RETAIN)
    RampAccelRate                : REAL := 20.0;    // %/s — accélération
    RampDecelNormalRate          : REAL := 40.0;    // %/s — décélération normale
    RampDecelFastRate            : REAL := 100.0;   // %/s — décélération RAPIDE
    DirectionInterlockDelay      : TIME := T#200ms; // Délai avant d'autoriser un changement de sens à l'arrêt

    // Réglages ETHERCAT uniquement (RETAIN)
    ApproachTime                 : TIME := T#5s;    // Temps estimé avant ralentissement auto
    ApproachSpeedPct             : REAL := 20.0;    // Vitesse réduite d'approche (PV)
    DriveFreqScaleMaxHz          : REAL := 60.0;    // Échelle 0..100 % → 0..60Hz (T30: Max 60Hz, fonctionnement standard/nominal 30Hz à 50% de consigne)

    // Réglages communs
    CaptorDebounce                : TIME := T#100ms; // Filtrage capteur de position cible
    BrakeDelayContactClose        : TIME := T#100ms; // Voir FB_Brake
    BrakeDelayMagnetise           : TIME := T#300ms; // Voir FB_Brake
    BrakeDelayMotorDecel          : TIME := T#500ms; // Voir FB_Brake
    BrakeFeedbackTimeout          : TIME := T#1s;    // Voir FB_Brake
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Défaut frein Translation" - Brake.Error ; bit3: "Défaut variateur AC600" - défaut variateur (DriveStatusWord.4) ; bit6: "Limite extrême Translation atteinte" - Fdc extrême atteint
    State               : E_State;
    StateAtError        : E_State;
    TargetReached        : BOOL;       // Capteur position cible
    DriveControlWord     : WORD;       // Mot de commande AC600
    DriveFreqRefHz        : REAL;      // Consigne fréquence
    BrakeCmd                : BOOL;    // Commande bobine frein — TRUE = relâché
    BrakeContactorCheck  : ST_ContactorCheck; // Diag contacteur frein
END_VAR
VAR
    Brake                : FB_Brake;       // Séquence frein
    CycleTimeCalc        : FB_CycleTime;
    SpeedRamp             : FB_Ramp;       // Rampe de vitesse logicielle (PLC)
    ResetEdge            : R_TRIG;
    ErrorEdge            : R_TRIG;
    DirectionChangeDelay : TON;            // Interlock changement de sens
    CommandedDirection   : INT;            // Sens réellement appliqué
    RampTargetPct        : REAL;
    ApproachTimer         : TON;           // Déclenche le ralentissement auto
    CaptorDebounceTon     : TON;
    ArrivalEdge            : R_TRIG;
    DirectionAtArrival     : INT;
    ArrivalLock             : BOOL;        // Arrêt exact sur capteur cible
    MovementRequested      : BOOL;         // Pilote FB_Brake
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. GATE (Enable / EmergencyStopOk) — neutralisation totale, sorties sûres
IF NOT Enable OR NOT EmergencyStopOk THEN
    DriveControlWord := 0; DriveFreqRefHz := 0.0;

    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeCmd := Brake.BrakeCmd;
    BrakeContactorCheck := Brake.ContactorCheck;

    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ApproachTimer(IN := FALSE, PT := ApproachTime);
    SpeedRamp(Target := 0.0, AccelRate := RampAccelRate, DecelRate := RampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

    ArrivalLock := FALSE;

    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);   // MainTask = 10 ms

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 📡 3. CAPTEUR POSITION CIBLE (debounce)
CaptorDebounceTon(IN := PositionSensorTarget, PT := CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;

// ⚙️ 4. CORE — arbitrage rampe : Enable > SafeStop > StartStop
RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop THEN
    // Si butée fin de course extrême atteinte dans le sens de marche demandé, consigne forcée à 0
    IF (Direction = 1 AND LimitSwitchFwd) OR (Direction = -1 AND LimitSwitchRev) THEN
        RampTargetPct := 0.0;
    ELSE
        RampTargetPct := ABS(SpeedRefPct);
    END_IF;
END_IF;

// ⏱️ 4bis. RALENTISSEMENT AUTO À L'APPROCHE
ApproachTimer(IN := (StartStop AND NOT SafeStop), PT := ApproachTime);
IF ApproachTimer.Q THEN
    RampTargetPct := LIMIT(0.0, RampTargetPct, ApproachSpeedPct);
END_IF;

// 🎯 4ter. ARRÊT EXACT SUR CAPTEUR (verrouille le sens tant que le capteur cible reste actif)
ArrivalEdge(CLK := TargetReached);
IF ArrivalEdge.Q THEN
    DirectionAtArrival := CommandedDirection;
END_IF;
ArrivalLock := TargetReached AND (Direction = DirectionAtArrival) AND (DirectionAtArrival <> 0);
IF ArrivalLock THEN
    RampTargetPct := 0.0;
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := RampAccelRate,
          DecelRate := SEL(SafeStop, RampDecelNormalRate, RampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

// 🔒 5. INTERLOCK CHANGEMENT DE SENS — jamais Fwd+Rev simultanés (vitesse confirmée nulle)
IF Direction <> CommandedDirection THEN
    IF CommandedDirection = 0 AND Direction <> 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ELSIF ABS(SpeedRamp.Current) < 0.1 THEN
        DirectionChangeDelay(IN := TRUE, PT := DirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
END_IF;

MovementRequested := (CommandedDirection <> 0) AND (ABS(SpeedRamp.Current) > 0.1);

// 🔀 5bis. SORTIE PHYSIQUE (ETHERCAT)
DriveFreqRefHz := (ABS(SpeedRamp.Current) / 100.0) * DriveFreqScaleMaxHz;

// Pilotage nominal Given Command 1 (0x3101) :
// 0: None, 1: Forward, 2: Reverse, 7: Reset
IF Reset THEN
    DriveControlWord := 7; // Reset défaut variateur
ELSIF Error THEN
    DriveControlWord := 0; // Arrêt sur défaut
ELSIF MovementRequested THEN
    IF CommandedDirection = 1 THEN
        DriveControlWord := 1; // Marche avant
    ELSIF CommandedDirection = -1 THEN
        DriveControlWord := 2; // Marche arrière
    ELSE
        DriveControlWord := 0;
    END_IF;
ELSE
    DriveControlWord := 0;
END_IF;

// Sécurité : si Fdc extrême atteint dans le sens de marche, coupure commande immédiate (sans rampe ni couple)
IF (CommandedDirection = 1 AND LimitSwitchFwd) OR (CommandedDirection = -1 AND LimitSwitchRev) THEN
    DriveControlWord := 0;
    DriveFreqRefHz := 0.0;
    SpeedRamp(Target := 0.0, AccelRate := 0.0, DecelRate := 100000.0, CycleTimeS := 1.0);
END_IF;

// 🛑 6. FREIN (composé, réutilisé tel quel)
Brake(Enable := TRUE, Reset := Reset, MovementRequested := MovementRequested,
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout,
      BypassContactorCheck := BypassContactorCheck);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

// 🧾 7. ERRORID (bitfield, cumul)
IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// Défaut variateur (bit3) : lu via EtherCAT (DriveStatusWord.4)
IF DriveStatusWord.4 THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// Défaut fin de course extrême atteint (bit6)
IF LimitSwitchFwd OR LimitSwitchRev THEN
    ErrorId := ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFBF;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🚦 8. STATE MACHINE (phase)
IF (NOT StartStop OR SafeStop) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;

// 🛡️ 9. SORTIE SÛRE SUR DÉFAUT
IF Error THEN
    DriveControlWord := 0; DriveFreqRefHz := 0.0;
    BrakeCmd := FALSE;
END_IF;

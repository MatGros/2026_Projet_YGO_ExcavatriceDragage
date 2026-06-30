// FB_Encoder_Abs — Refactored version
// Conformance with AF_Partie3 + EtherCAT bus gate + ErrorId bitfield
// Replace the original FB_Encoder_Abs content with this code

FUNCTION_BLOCK FB_Encoder_Abs
VAR_INPUT
    Enable              : BOOL;   // Active la logique
    Reset               : BOOL;   // Acquittement défaut (front obligatoire)
    SafeStop            : BOOL;   // Arrêt sûr forcé
    SafetyOk            : BOOL;   // Conditions globales OK
    EthOnline           : BOOL;   // Esclave EtherCAT présent
    EthOperational      : BOOL;   // Esclave EtherCAT opérationnel

    In_Alarms           : UINT;   // %IW2 — hardware alarm word
    In_Warnings         : UINT;   // %IW3
    In_PosValue         : UDINT;  // %ID2 — raw position
    In_SpdValue         : INT;    // %IW6 — raw speed

    HomingTrigger       : BOOL;   // Rising edge trigger for water level homing
    WaterLevelOffset    : REAL;   // Water level offset in metres

    InvertDirection     : BOOL;   // Mechanical direction inversion
    MaxSpeedThreshold   : INT := 5000;

    TeachActive         : BOOL;   // Calibration mode
    TeachStartRaw       : UDINT;  // Teach point A raw position
    TeachEndRaw         : UDINT;  // Teach point B raw position
    TeachRealDistance   : REAL;   // Measured distance A→B in metres
END_VAR
VAR_OUTPUT
    Ready               : BOOL;   // Block operational
    Busy                : BOOL;   // Processing active
    Done                : BOOL;   // Action complete
    Error               : BOOL;   // Mirror of (ErrorId <> 0)
    ErrorId             : WORD;   // Bitfield: bit0=alarm, bit1=overspeed, bit2=offline, bit3=not operational
    State               : WORD;   // Operational phase (0=disabled, 1=ready, 2=processing)
    StateAtError        : WORD;   // Snapshot of SlaveState at error instant

    Out_PresetCmd       : UINT;   // %QW2 — preset command
    Out_PresetValue     : UDINT;  // %QD2 — preset value to write

    ActualPositionM     : REAL;   // Final position in metres
    ActualSpeedFiltered : REAL;   // Filtered speed for monitoring
    EmergencyStop       : BOOL;   // Immediate braking request (overspeed action)
END_VAR
VAR_IN_OUT
    Config_PulsePerMeter : REAL;  // Persistent calibration
END_VAR
VAR
    GetCycleTime        : FB_CycleTime;
    ScaleStage          : FB_Encoder_Scale;
    SafetyStage         : FB_Encoder_Safety;
    ResetEdge           : R_TRIG;

    LocalRawPos         : UDINT;
    LastHomingTrigger   : BOOL;
    LastSlaveState      : WORD;
END_VAR

// 🛑 1. GATE DE SÉCURITÉ (Prioritaire)
IF NOT Enable OR SafeStop OR NOT EthOnline OR NOT EthOperational THEN
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    State := 0;  // DISABLED
    Out_PresetCmd := 0;
    Out_PresetValue := 0;
    ActualSpeedFiltered := 0.0;
    EmergencyStop := TRUE;  // Fail-safe
    RETURN;
END_IF;

Ready := TRUE;
State := 1;  // READY

// 🔑 2. RESET DÉFAUT (front obligatoire)
ResetEdge(CLK := Reset);

IF ResetEdge.Q THEN
    // Clear error only if all causes have disappeared
    IF EthOnline AND EthOperational AND (In_Alarms = 0) AND (SafetyStage.OverspeedTrip = FALSE) THEN
        ErrorId := 16#0000;
        Error := FALSE;
        StateAtError := 0;
    END_IF;
END_IF;

// 📥 3. ACQUISITION &amp; CYCLE TIME
GetCycleTime();

// Handle direction inversion
IF InvertDirection THEN
    LocalRawPos := 16#FFFFFFFF - In_PosValue;
ELSE
    LocalRawPos := In_PosValue;
END_IF;

// ⚙️ 4. HOMING / PRESET LOGIC (single implementation)
IF HomingTrigger AND NOT LastHomingTrigger THEN
    Out_PresetValue := REAL_TO_UDINT(WaterLevelOffset * Config_PulsePerMeter);
    Out_PresetCmd := 16#0001;
    Busy := TRUE;
ELSE
    Out_PresetCmd := 16#0000;
    Busy := FALSE;
END_IF;
LastHomingTrigger := HomingTrigger;

// 🧾 5. ERROR DETECTION (bitfield)

// bit0 = hardware alarm
IF (In_Alarms &lt;&gt; 0) THEN
    IF NOT Error THEN
        StateAtError := 1;  // Capture error state
    END_IF;
    ErrorId.0 := TRUE;
ELSE
    ErrorId.0 := FALSE;
END_IF;

// PIPELINE SCALING
ScaleStage(
    CurrentRawPos := LocalRawPos,
    OffsetValueB := 0.0,
    EnableTeach := TeachActive,
    StartTeachPos := TeachStartRaw,
    EndTeachPos := TeachEndRaw,
    RealDistMeters := TeachRealDistance,
    PulsePerMeter := Config_PulsePerMeter
);
ActualPositionM := ScaleStage.PositionMeters;

// PIPELINE SAFETY &amp; SPEED
SafetyStage(
    RawSpeed := In_SpdValue,
    MaxSpeedLimit := MaxSpeedThreshold,
    CycleTimeS := GetCycleTime.CycleTimeS
);
ActualSpeedFiltered := SafetyStage.FilteredSpeed;

// bit1 = overspeed
IF SafetyStage.OverspeedTrip THEN
    IF NOT Error THEN
        StateAtError := 2;
    END_IF;
    ErrorId.1 := TRUE;
ELSE
    ErrorId.1 := FALSE;
END_IF;

// bit2 = EtherCAT offline
IF NOT EthOnline THEN
    IF NOT Error THEN
        StateAtError := 3;
    END_IF;
    ErrorId.2 := TRUE;
ELSE
    ErrorId.2 := FALSE;
END_IF;

// bit3 = EtherCAT not operational
IF NOT EthOperational THEN
    IF NOT Error THEN
        StateAtError := 4;
    END_IF;
    ErrorId.3 := TRUE;
ELSE
    ErrorId.3 := FALSE;
END_IF;

// 6. ERROR OUTPUT &amp; EMERGENCY ACTION
Error := (ErrorId &lt;&gt; 16#0000);
EmergencyStop := SafetyStage.OverspeedTrip OR Error;
Done := NOT Error;

END_FUNCTION_BLOCK

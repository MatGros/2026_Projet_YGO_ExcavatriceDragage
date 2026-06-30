FUNCTION_BLOCK FB_BusAggregator
VAR_INPUT
    Enable              : BOOL;

    // CAN bus health (from FB_DiagCanOpen)
    CanOnline           : BOOL;
    CanOperational      : BOOL;
    JoystickOnline      : BOOL;
    JoystickOperational : BOOL;

    // ETHERCAT slave health (from 3x FB_DiagEthercat instances)
    Cod1Online          : BOOL;
    Cod1Operational     : BOOL;
    Cod2Online          : BOOL;
    Cod2Operational     : BOOL;
    VariateurOnline     : BOOL;
    VariateurOperational: BOOL;
END_VAR
VAR_OUTPUT
    Ready               : BOOL;

    // Consolidated bus health
    CanHealthy          : BOOL;       // CanOnline AND CanOperational AND JoystickOperational
    EthercatHealthy     : BOOL;       // All 3 slaves operational (Cod1 AND Cod2 AND Variateur)
    GlobalHealthy       : BOOL;       // CanHealthy AND EthercatHealthy

    // Per-equipment availability (used by functional FBs to determine degradation level)
    JoystickAvailable   : BOOL;
    EncoderM1Available  : BOOL;
    EncoderM2Available  : BOOL;
    VariateurAvailable  : BOOL;
END_VAR

// 🛑 GATE
IF NOT Enable THEN
    Ready := FALSE;
    CanHealthy := FALSE;
    EthercatHealthy := FALSE;
    GlobalHealthy := FALSE;
    JoystickAvailable := FALSE;
    EncoderM1Available := FALSE;
    EncoderM2Available := FALSE;
    VariateurAvailable := FALSE;
    RETURN;
END_IF;

Ready := TRUE;

// 🔍 CAN BUS CONSOLIDATION
CanHealthy := CanOperational AND JoystickOperational;
JoystickAvailable := JoystickOnline AND JoystickOperational;

// 🔍 ETHERCAT CONSOLIDATION
EthercatHealthy :=
    (Cod1Online AND Cod1Operational) AND
    (Cod2Online AND Cod2Operational) AND
    (VariateurOnline AND VariateurOperational);

// Per-equipment availability (can be individually down)
EncoderM1Available := Cod1Online AND Cod1Operational;
EncoderM2Available := Cod2Online AND Cod2Operational;
VariateurAvailable := VariateurOnline AND VariateurOperational;

// 🧾 GLOBAL HEALTH
GlobalHealthy := CanHealthy AND EthercatHealthy;

END_FUNCTION_BLOCK

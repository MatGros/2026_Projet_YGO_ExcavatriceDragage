// ===== E_DegradationLevel =====
// Enum for system degradation levels
// To be created in CODESYS as a separate POU in _TYPES folder

TYPE E_DegradationLevel :
(
    FULL        := 0,    // All systems operational
    LEVEL1      := 1,    // Encoder OK, Joystick OK, brake degraded
    LEVEL2      := 2,    // Joystick OK, encoder down, manual without position feedback
    MAINTENANCE := 3     // Joystick down or CAN bus dead, machine locked
);
END_TYPE


// ===== ST_BusHealth =====
// Unified bus health structure passed via GVL to all functional FBs
// Consolidates CAN and ETHERCAT status per-equipment

TYPE ST_BusHealth :
STRUCT
    CanHealthy          : BOOL;  // CAN bus and joystick both operational
    EthercatHealthy     : BOOL;  // All 3 ETHERCAT slaves operational
    GlobalHealthy       : BOOL;  // CAN AND ETHERCAT both healthy

    JoystickAvailable   : BOOL;  // Joystick online and operational (CAN)
    EncoderM1Available  : BOOL;  // Encoder M1 online and operational (ETHERCAT)
    EncoderM2Available  : BOOL;  // Encoder M2 online and operational (ETHERCAT)
    VariateurAvailable  : BOOL;  // Variateur online and operational (ETHERCAT)
END_STRUCT
END_TYPE

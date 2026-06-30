// PROGRAM PRG_BusMonitor
// System program: centralizes bus diagnostics and health monitoring
// Calls: FB_DiagCanOpen + 3x FB_DiagEthercat + FB_BusAggregator
// Updates: GVL_BusHealth with consolidated health status
// Task: MainTask (20ms) or CanTask (10ms) depending on bus polling speed

PROGRAM PRG_BusMonitor
VAR
    // ===== DIAGNOSTIC INSTANCES =====
    DiagCanOpen        : FB_DiagCanOpen;
    DiagEthEncoderM1   : FB_DiagEthercat;
    DiagEthEncoderM2   : FB_DiagEthercat;
    DiagEthVariateur   : FB_DiagEthercat;

    // ===== AGGREGATION INSTANCE =====
    BusAggregator      : FB_BusAggregator;

    // ===== ENABLE FLAG =====
    DiagnosticsEnabled : BOOL := TRUE;
END_VAR

// ========================================
// 1. CAN BUS DIAGNOSTIC
// ========================================
DiagCanOpen(
    Enable := DiagnosticsEnabled,
    Reset := GVL_DEBUG.DBG_ResetBusHealth,  // or button from IHM
    BusState := CANopen_Manager.GetBusState(...),  // Provide actual bus state
    BusDiagAvailable := TRUE,                      // Assume available
    DeviceState := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState(...),  // Joystick node
    DevDiagAvailable := TRUE
);

// ========================================
// 2. ETHERCAT DIAGNOSTICS (3 slaves)
// ========================================

// Encoder M1 (Treuil M1)
DiagEthEncoderM1(
    Enable := DiagnosticsEnabled,
    Reset := GVL_DEBUG.DBG_ResetBusHealth,
    WcState := CoE_Encoder1_WcState,      // EtherCAT Working Counter state
    SlaveState := CoE_Encoder1_State      // Slave operational state
);

// Encoder M2 (Treuil M2)
DiagEthEncoderM2(
    Enable := DiagnosticsEnabled,
    Reset := GVL_DEBUG.DBG_ResetBusHealth,
    WcState := CoE_Encoder2_WcState,
    SlaveState := CoE_Encoder2_State
);

// Variateur (Translation or other ETHERCAT device)
DiagEthVariateur(
    Enable := DiagnosticsEnabled,
    Reset := GVL_DEBUG.DBG_ResetBusHealth,
    WcState := CoE_Variateur_WcState,
    SlaveState := CoE_Variateur_State
);

// ========================================
// 3. BUS AGGREGATION
// ========================================
BusAggregator(
    Enable := DiagnosticsEnabled,

    // CAN inputs from DiagCanOpen
    CanOnline := DiagCanOpen.BusOnline,
    CanOperational := DiagCanOpen.BusOperational,
    JoystickOnline := DiagCanOpen.JoystickOnline,
    JoystickOperational := DiagCanOpen.JoystickOperational,

    // ETHERCAT inputs from 3x DiagEthercat
    Cod1Online := DiagEthEncoderM1.Online,
    Cod1Operational := DiagEthEncoderM1.Operational,
    Cod2Online := DiagEthEncoderM2.Online,
    Cod2Operational := DiagEthEncoderM2.Operational,
    VariateurOnline := DiagEthVariateur.Online,
    VariateurOperational := DiagEthVariateur.Operational
);

// ========================================
// 4. UPDATE GLOBAL HEALTH STRUCTURE (GVL)
// ========================================
GVL_BusHealth.BusHealth.CanHealthy := BusAggregator.CanHealthy;
GVL_BusHealth.BusHealth.EthercatHealthy := BusAggregator.EthercatHealthy;
GVL_BusHealth.BusHealth.GlobalHealthy := BusAggregator.GlobalHealthy;
GVL_BusHealth.BusHealth.JoystickAvailable := BusAggregator.JoystickAvailable;
GVL_BusHealth.BusHealth.EncoderM1Available := BusAggregator.EncoderM1Available;
GVL_BusHealth.BusHealth.EncoderM2Available := BusAggregator.EncoderM2Available;
GVL_BusHealth.BusHealth.VariateurAvailable := BusAggregator.VariateurAvailable;

END_PROGRAM

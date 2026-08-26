VAR_GLOBAL
    // === 📥 ENTRÉES MATÉRIELLES (HwReal) ===

    // Treuils M1 / M2
    M1_ContactorsReleased_DI     : BOOL;
    M1_ThermalOk_DI              : BOOL;
    M1_BrakeIsOpen_DI            : BOOL;
    M2_ContactorsReleased_DI     : BOOL;
    M2_ThermalOk_DI              : BOOL;
    M2_BrakeIsOpen_DI            : BOOL;
    M1M2_TopPositionFree_DI      : BOOL;
    M2_TensionedCable_DI         : BOOL;

    // Codeurs absolus
    COD1_PosValue                : DINT;
    COD1_Alarms                  : DWORD;
    COD1_Warnings                : DWORD;
    COD1_PresetTTrigCmd          : BOOL;
    COD1_CodeSeqTrigCmd          : BOOL;
    COD1_PresetValue             : DINT;
    COD1_CODEUR                  : FB_DeviceStub;

    COD2_PosValue                : DINT;
    COD2_Alarms                  : DWORD;
    COD2_Warnings                : DWORD;
    COD2_PresetTTrigCmd          : BOOL;
    COD2_CodeSeqTrigCmd          : BOOL;
    COD2_PresetValue             : DINT;
    COD2_CODEUR                  : FB_DeviceStub;

    // Translation M3 (AC600)
    M3_PosTremie_DI              : BOOL;
    M3_PosPV_DI                  : BOOL;
    M3_PosPVP2_DI                : BOOL;
    M3_PosP1_DI                  : BOOL;
    M3_PosMaintenance_DI         : BOOL;
    M3_BrakeIsOpen_DI            : BOOL;
    M3_ThermalOK_DI              : BOOL;
    M3_StatusWord                : WORD;
    M3_ActualFrequencyHz         : WORD;
    AC600_ECAT_Drive             : FB_DeviceStub;

    // Joystick Opérateur / CANopen
    JoyXRaw_ANA1                 : INT;
    JoyYRaw_ANA2                 : INT;
    JoyBtnRaw                    : WORD;
    CANbus                       : FB_DeviceStub;
    JOY1_JOYSTICK_MCB560_CO4201A : FB_DeviceStub;

    // Sécurités / Communs Machine
    PowerContactorEngaged_DI     : BOOL;
    EmergencyChainClosed_DI      : BOOL;
    PhaseRotationOk_DI           : BOOL;
    M1_M2_M3_BrakeThermalOk_DI   : BOOL;
    M1_M2_KoboldBottomTouch_DI   : BOOL;
    HydraulicThermalOk_DI        : BOOL;
    ConveyorInfeedReady_DI       : BOOL;
    TremieFull_OR_GateRaised_DI  : BOOL;

    // Modules d'E/S déportées
    Local_Digital_IO             : FB_DeviceStub;
    VH_0800END                   : FB_DeviceStub;
    VH_0808ETP                   : FB_DeviceStub;

    // === 📤 SORTIES MATÉRIELLES (PRG_06_Outputs) ===

    // Treuil M1 (Retenue)
    M1_RelayFwd_Up_DQ            : BOOL;
    M1_RelayRev_Down_DQ          : BOOL;
    M1_SpeedContactor_1_DQ       : BOOL;
    M1_SpeedContactor_2_DQ       : BOOL;
    M1_SpeedContactor_3_DQ       : BOOL;
    M1_SpeedContactor_4_DQ       : BOOL;
    M1_BrakeRelease_RQ           : BOOL;

    // Treuil M2 (Benne)
    M2_RelayFwd_Up_Close_DQ      : BOOL;
    M2_RelayRev_Down_Open_DQ     : BOOL;
    M2_SpeedContactor_1_DQ       : BOOL;
    M2_SpeedContactor_2_DQ       : BOOL;
    M2_SpeedContactor_3_DQ       : BOOL;
    M2_SpeedContactor_4_DQ       : BOOL;
    M2_BrakeRelease_RQ           : BOOL;

    // Translation M3
    M3_CommandWord               : WORD;
    M3_SetpointFrequencyHz       : WORD;
    M3_BrakeRelease_RQ           : BOOL;

    // Capteur fond Kobold
    M1_M2_KoboldMeasureEnable_DQ : BOOL;

    // Chaîne Arrêt d'Urgence / Puissance
    PowerKeepAlive_A_RQ          : BOOL;
    PowerKeepAlive_B_RQ          : BOOL;
    EmergencyArming_RQ           : BOOL;
END_VAR

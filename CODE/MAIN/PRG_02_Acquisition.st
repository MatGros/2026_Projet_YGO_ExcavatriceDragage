(* ═══════════════════════════════════════════════════════════════
   📡 PRG_02_Acquisition — Programme d'Acquisition et Qualification I/O
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §2
   ⚙️ Exécuté en tête de la chaîne métier (après les initialisations système).
   🎯 Rôle unique : Produire les images HwReal/HwRealQualified/HwSim/HwIn,
      acquérir et traiter les mesures codeurs (M1/M2), décoder M3, traiter le joystick
      et publier les retours.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_02_Acquisition

VAR_OUTPUT
    HwReal                   : ST_HardwareImage;  (* Image brute réelle ; TRUE = état physique lu *)
    HwRealQualified          : ST_HardwareImage;  (* Image réelle TOR filtrée ; TRUE = état stable *)
    HwSim                    : ST_HardwareImage;  (* Image simulée ; TRUE = état modèle normalisé *)
    HwIn                     : ST_HardwareImage;  (* Image utilisée ; TRUE = état logique métier *)
    WinchInputSourceChanged  : BOOL;              (* TRUE pendant 1 cycle si source Winch change *)

    TranslationPosTremie      : BOOL;   (* TRUE = translation en position Trémie *)
    TranslationPosPV          : BOOL;   (* TRUE = translation en zone pré-ralentissement PV *)
    TranslationPosP2          : BOOL;   (* TRUE = translation en position P2 *)
    TranslationPosP1          : BOOL;   (* TRUE = translation en position P1 *)
    TranslationPosMaintenance : BOOL;   (* TRUE = translation en position Maintenance *)

    M3_StatusWord_Filtered        : UINT; (* WORD/UINT d'état variateur filtré *)
    M3_ActualFrequencyHz_Filtered : UINT; (* UINT fréquence M3 filtrée, unité : 0,01 Hz *)

    M3_LimitSwitchFwd          : BOOL; (* TRUE = limite avant active *)
    M3_LimitSwitchRev          : BOOL; (* TRUE = limite arrière active *)
    M3_SensorWordIncoherent    : BOOL; (* TRUE = mot capteurs incohérent *)
    M3_SensorsWord             : BYTE; (* BYTE mot capteurs M3 *)

    (* 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (§1bis).
       Granularité MODULE, pas canal : GetDeviceState() est un état de carte. *)
    LocalDigitalIoOk           : BOOL;   (* TRUE = module Local_Digital_IO opérationnel *)
    Vh0800EndOk                : BOOL;   (* TRUE = module VH_0800END opérationnel (freins/thermiques/AU) *)
    Vh0808EtpOk                : BOOL;   (* TRUE = module VH_0808ETP opérationnel (positions M3/hydraulique/crible) *)
    InputModuleFault           : BOOL;   (* TRUE = au moins un des 3 modules DI hors service *)
END_VAR

VAR
    (* ── Filtrage temporel des 22 TOR réelles ── *)
    instFilterPowerContactor      : FB_DigitalInputFilter;
    instFilterEmergencyChain      : FB_DigitalInputFilter;
    instFilterPhaseRotation       : FB_DigitalInputFilter;
    instFilterBrakeThermal        : FB_DigitalInputFilter;
    instFilterM1Brake              : FB_DigitalInputFilter;
    instFilterM2Brake              : FB_DigitalInputFilter;
    instFilterM3Brake              : FB_DigitalInputFilter;
    instFilterM1Contactors         : FB_DigitalInputFilter;
    instFilterM1Thermal            : FB_DigitalInputFilter;
    instFilterM2Contactors         : FB_DigitalInputFilter;
    instFilterM2Thermal            : FB_DigitalInputFilter;
    instFilterTensionedCable       : FB_DigitalInputFilter;
    instFilterKobold               : FB_DigitalInputFilter;
    instFilterM3Thermal            : FB_DigitalInputFilter;
    instFilterTopPosition          : FB_DigitalInputFilter;
    instFilterPosTremie            : FB_DigitalInputFilter;
    instFilterPosPV                : FB_DigitalInputFilter;
    instFilterPosP2                : FB_DigitalInputFilter;
    instFilterPosP1                : FB_DigitalInputFilter;
    instFilterPosMaintenance       : FB_DigitalInputFilter;
    instFilterHydraulicThermal     : FB_DigitalInputFilter;
    instFilterConveyorReady        : FB_DigitalInputFilter;

    (* ── Blocs complexes ── *)
    instSimBench             : FB_SimBench;
    instJoystick             : FB_Joystick;
    instEncoderAbsM1         : FB_Encoder_Abs;
    instEncoderScaleM1       : FB_Encoder_Scale;
    instHomingM1             : FB_Encoder_Homing;
    instEncoderAbsM2         : FB_Encoder_Abs;
    instEncoderScaleM2       : FB_Encoder_Scale;
    instHomingM2             : FB_Encoder_Homing;
    instPosDecoderM3         : FB_Translation_PositionDecoder;

    (* ── Filtrage retours variateur M3 ── *)
    instCycleTimeAcq            : FB_CycleTime;
    instFilterM3StatusWord      : FB_Filter_PT1;
    instFilterM3ActualFreqHz    : FB_Filter_PT1;

    (* ── Mémoire bascule simulation Winch ── *)
    WinchInputSourceSimulated         : BOOL;
    PreviousWinchInputSourceSimulated : BOOL;
    WinchInputSourceInitialized       : BOOL;
END_VAR

// === 📥 §1 ACQUISITION BRUTE (HwReal) ===

// Winch M1 / M2 et codeurs
HwReal.Winch.M1_ContactorsReleased_DI := M1_ContactorsReleased_DI;
HwReal.Winch.M1_ThermalOk_DI          := M1_ThermalOk_DI;
HwReal.Winch.M1_BrakeIsOpen_DI        := M1_BrakeIsOpen_DI;

HwReal.Winch.M2_ContactorsReleased_DI := M2_ContactorsReleased_DI;
HwReal.Winch.M2_ThermalOk_DI          := M2_ThermalOk_DI;
HwReal.Winch.M2_BrakeIsOpen_DI        := M2_BrakeIsOpen_DI;

HwReal.Winch.M1M2_TopPositionFree_DI  := M1M2_TopPositionFree_DI;
HwReal.Winch.M2_TensionedCable_DI     := M2_TensionedCable_DI;

HwReal.Winch.COD1_PosValue            := COD1_PosValue;
HwReal.Winch.COD1_Alarms              := COD1_Alarms;
HwReal.Winch.COD1_Warnings            := COD1_Warnings;
HwReal.Winch.COD1_DeviceState         := COD1_CODEUR.GetDeviceState();

HwReal.Winch.COD2_PosValue            := COD2_PosValue;
HwReal.Winch.COD2_Alarms              := COD2_Alarms;
HwReal.Winch.COD2_Warnings            := COD2_Warnings;
HwReal.Winch.COD2_DeviceState         := COD2_CODEUR.GetDeviceState();

// Translation M3 et variateur AC600
HwReal.Translation.M3_PosTremie_DI      := M3_PosTremie_DI;
HwReal.Translation.M3_PosPV_DI          := M3_PosPV_DI;
HwReal.Translation.M3_PosP2_DI          := M3_PosP2_DI;
HwReal.Translation.M3_PosP1_DI          := M3_PosP1_DI;
HwReal.Translation.M3_PosMaintenance_DI := M3_PosMaintenance_DI;
HwReal.Translation.M3_BrakeIsOpen_DI    := M3_BrakeIsOpen_DI;
HwReal.Translation.M3_ThermalFeedback_DI:= M3_ThermalFeedback_DI;
HwReal.Translation.M3_StatusWord        := M3_StatusWord;
HwReal.Translation.M3_ActualFrequencyHz := M3_ActualFrequencyHz;
HwReal.Translation.AC600_DeviceState    := AC600_ECAT_Drive.GetDeviceState();

// Opérateur / Joystick / bus CANopen
HwReal.Operator.JoyXRaw_ANA1      := JoyXRaw_ANA1;
HwReal.Operator.JoyYRaw_ANA2      := JoyYRaw_ANA2;
HwReal.Operator.JoyBtnRaw         := JoyBtnRaw;
HwReal.Operator.CanBusState       := CANbus.GetBusState();
HwReal.Operator.JOY1_DeviceState  := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();

// Sécurités / Communs Machine
HwReal.Machine.PowerContactorEngaged_DI   := PowerContactorEngaged_DI;
HwReal.Machine.EmergencyChainClosed_DI    := EmergencyChainClosed_DI;
HwReal.Machine.PhaseRotationOk_DI         := PhaseRotationOk_DI;
HwReal.Machine.BrakeThermalOk_DI          := BrakeThermalOk_DI;
HwReal.Machine.M1_M2_KoboldContactFond_DI := M1_M2_KoboldContactFond_DI;
HwReal.Machine.HydraulicThermalOk_DI      := HydraulicThermalOk_DI;
HwReal.Machine.ConveyorInfeedReady_DI     := ConveyorInfeedReady_DI;

// === 🧰 §1bis FILTRAGE TOR RÉEL ===
// HwReal reste brut pour le diagnostic. HwRealQualified porte la même image
// après filtrage temporel ; aucune inversion ni information de santé carte ici.
HwRealQualified := HwReal;

instFilterPowerContactor(InputRaw := HwReal.Machine.PowerContactorEngaged_DI, FilterTime := T#20MS);
HwRealQualified.Machine.PowerContactorEngaged_DI := instFilterPowerContactor.State;
instFilterEmergencyChain(InputRaw := HwReal.Machine.EmergencyChainClosed_DI, FilterTime := T#20MS);
HwRealQualified.Machine.EmergencyChainClosed_DI := instFilterEmergencyChain.State;
instFilterPhaseRotation(InputRaw := HwReal.Machine.PhaseRotationOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.PhaseRotationOk_DI := instFilterPhaseRotation.State;
instFilterBrakeThermal(InputRaw := HwReal.Machine.BrakeThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.BrakeThermalOk_DI := instFilterBrakeThermal.State;
instFilterKobold(InputRaw := HwReal.Machine.M1_M2_KoboldContactFond_DI, FilterTime := T#20MS);
HwRealQualified.Machine.M1_M2_KoboldContactFond_DI := instFilterKobold.State;
instFilterHydraulicThermal(InputRaw := HwReal.Machine.HydraulicThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.HydraulicThermalOk_DI := instFilterHydraulicThermal.State;
instFilterConveyorReady(InputRaw := HwReal.Machine.ConveyorInfeedReady_DI, FilterTime := T#20MS);
HwRealQualified.Machine.ConveyorInfeedReady_DI := instFilterConveyorReady.State;

instFilterM1Contactors(InputRaw := HwReal.Winch.M1_ContactorsReleased_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_ContactorsReleased_DI := instFilterM1Contactors.State;
instFilterM1Thermal(InputRaw := HwReal.Winch.M1_ThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_ThermalOk_DI := instFilterM1Thermal.State;
instFilterM1Brake(InputRaw := HwReal.Winch.M1_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_BrakeIsOpen_DI := instFilterM1Brake.State;
instFilterM2Contactors(InputRaw := HwReal.Winch.M2_ContactorsReleased_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_ContactorsReleased_DI := instFilterM2Contactors.State;
instFilterM2Thermal(InputRaw := HwReal.Winch.M2_ThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_ThermalOk_DI := instFilterM2Thermal.State;
instFilterM2Brake(InputRaw := HwReal.Winch.M2_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_BrakeIsOpen_DI := instFilterM2Brake.State;
instFilterTensionedCable(InputRaw := HwReal.Winch.M2_TensionedCable_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_TensionedCable_DI := instFilterTensionedCable.State;
instFilterTopPosition(InputRaw := HwReal.Winch.M1M2_TopPositionFree_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1M2_TopPositionFree_DI := instFilterTopPosition.State;

instFilterM3Brake(InputRaw := HwReal.Translation.M3_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_BrakeIsOpen_DI := instFilterM3Brake.State;
instFilterM3Thermal(InputRaw := HwReal.Translation.M3_ThermalFeedback_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_ThermalFeedback_DI := instFilterM3Thermal.State;
instFilterPosTremie(InputRaw := HwReal.Translation.M3_PosTremie_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosTremie_DI := instFilterPosTremie.State;
instFilterPosPV(InputRaw := HwReal.Translation.M3_PosPV_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosPV_DI := instFilterPosPV.State;
instFilterPosP2(InputRaw := HwReal.Translation.M3_PosP2_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosP2_DI := instFilterPosP2.State;
instFilterPosP1(InputRaw := HwReal.Translation.M3_PosP1_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosP1_DI := instFilterPosP1.State;
instFilterPosMaintenance(InputRaw := HwReal.Translation.M3_PosMaintenance_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosMaintenance_DI := instFilterPosMaintenance.State;

// 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (AF06 §3bis).
// GetDeviceState() = RUNNING => module opérationnel. Pas de bypass simulation ici :
// un module DI absent en simulation banc reste un fait matériel réel, pas un choix modélisé.
LocalDigitalIoOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING);
Vh0800EndOk      := (VH_0800END.GetDeviceState() = DEVICE_STATE.RUNNING);
Vh0808EtpOk      := (VH_0808ETP.GetDeviceState() = DEVICE_STATE.RUNNING);
InputModuleFault := NOT (LocalDigitalIoOk AND Vh0800EndOk AND Vh0808EtpOk);


// === 🎭 §2 SIMULATION & AIGUILLAGE (HwIn) ===

instSimBench(
    Enable                   := GVL_Simulation.SimulationModeActive,
    M1_RelayFwd              := GVL_Global.M1RelayFwd,
    M1_RelayRev              := GVL_Global.M1RelayRev,
    M1_SpeedContactor_1      := GVL_Global.M1SpeedContactor1,
    M1_SpeedContactor_2      := GVL_Global.M1SpeedContactor2,
    M1_SpeedContactor_3      := GVL_Global.M1SpeedContactor3,
    M1_SpeedContactor_4      := GVL_Global.M1SpeedContactor4,
    M1_SpeedRefPct           := PRG_04_Treuils_Benne.M1_SpeedRef_Active,
    M1_PresetTriggerCmd      := instEncoderAbsM1.PresetTriggerCmd,
    M1_PresetValueOut        := instEncoderAbsM1.PresetValueOut,
    M1_BrakeCmd              := GVL_Global.M1BrakeCmd,
    M2_RelayFwd              := GVL_Global.M2RelayFwd,
    M2_RelayRev              := GVL_Global.M2RelayRev,
    M2_SpeedContactor_1      := GVL_Global.M2SpeedContactor1,
    M2_SpeedContactor_2      := GVL_Global.M2SpeedContactor2,
    M2_SpeedContactor_3      := GVL_Global.M2SpeedContactor3,
    M2_SpeedContactor_4      := GVL_Global.M2SpeedContactor4,
    M2_SpeedRefPct           := PRG_04_Treuils_Benne.M2_SpeedRef_Active,
    M2_PresetTriggerCmd      := instEncoderAbsM2.PresetTriggerCmd,
    M2_PresetValueOut        := instEncoderAbsM2.PresetValueOut,
    M2_BrakeCmd              := GVL_Global.M2BrakeCmd,
    M3_Direction             := PRG_05_Translation.M3_Direction_Active,
    M3_SpeedRefPct           := PRG_05_Translation.M3_SpeedRef_Active,
    M3_BrakeCmd              := GVL_Global.TranslationBrakeCmd,
    M3_TargetNum             := GVL_IHM.TranslationM3.Cmd.SelTarget,
    PowerKeepAlive_A         := PRG_06_Outputs_LD.PowerKeepAlive_A_RQ,
    PowerKeepAlive_B         := PRG_06_Outputs_LD.PowerKeepAlive_B_RQ,
    EmergencyArming_RQ       := PRG_06_Outputs_LD.EmergencyArming_RQ,
    SimEncoderSpeedFactor    := GVL_Simulation.SimEncoderSpeedFactor,
    SimSyncDeviationInjectM1 := GVL_Simulation.SimSyncDeviationInjectM1,
    SimSyncDeviationInjectM2 := GVL_Simulation.SimSyncDeviationInjectM2,
    SimSyncDeviationOffset_M := GVL_Simulation.SimSyncDeviationOffset_M,
    SimM3SensorsWordActive   := GVL_Simulation.SimM3SensorsWordActive,
    SimM3SensorsWord         := GVL_Simulation.SimM3SensorsWord,
    SimJoystickRawX          := GVL_Simulation.SimJoystickRawX,
    SimJoystickRawY          := GVL_Simulation.SimJoystickRawY,
    SimJoystickRawButton     := GVL_Simulation.SimJoystickRawButton,
    SimKoboldContactValue    := GVL_Simulation.SimKoboldContactValue,
    BtnEmergencyStop         := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff,
    HwReal                   := HwReal,
    RawPosM1                 := _SimEncoderRawPosM1,
    RawPosM2                 := _SimEncoderRawPosM2
);

HwSim.Winch       := instSimBench.Winch;
HwSim.Translation := instSimBench.Translation;
HwSim.Operator    := instSimBench.Operator;
HwSim.Machine     := instSimBench.Machine;

WinchInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
IF NOT WinchInputSourceInitialized THEN
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
    WinchInputSourceInitialized := TRUE;
    WinchInputSourceChanged := FALSE;
ELSE
    WinchInputSourceChanged := (WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated);
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

IF WinchInputSourceSimulated
    THEN HwIn.Winch := instSimBench.Winch;             ELSE HwIn.Winch := HwRealQualified.Winch;             END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive
    THEN HwIn.Translation := instSimBench.Translation; ELSE HwIn.Translation := HwRealQualified.Translation; END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive
    THEN HwIn.Operator := instSimBench.Operator;       ELSE HwIn.Operator := HwReal.Operator;       END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimMachineActive
    THEN HwIn.Machine := instSimBench.Machine;         ELSE HwIn.Machine := HwRealQualified.Machine;         END_IF;


// === 🕹️ §3 TRAITEMENT JOYSTICK ===

instJoystick(
    Enable                    := TRUE,
    Reset                     := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                      := PRG_03_Modes_Cycle.Auth.Mode,
    BenneBusy                 := PRG_04_Treuils_Benne.instBucket.Busy,
    PreserveArmingAfterBucket := PRG_04_Treuils_Benne.instExtractionSequence.Busy
                                 AND (PRG_04_Treuils_Benne.instExtractionSequence.ExtractionState = E_ExtractionSequenceState.CLOSING_BUCKET),
    BusCanOpenOP              := PRG_07_Supervision.instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP                := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick,
    RawX                      := HwIn.Operator.JoyXRaw_ANA1,
    RawY                      := HwIn.Operator.JoyYRaw_ANA2,
    RawButton                 := HwIn.Operator.JoyBtnRaw,
    BtnCalibrate              := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
    InvertX                   := _JoystickInvertX,
    InvertY                   := _JoystickInvertY,
    Deadband                  := _JoystickDeadband_Pct,
    FilterTime                := _JoystickFilterTime,
    DeadmanRearmTimeout       := T#10S,
    NeutralHoldTime           := T#500MS,
    DeadmanReconfEnable       := FALSE,
    NeutralXMem               := _JoystickNeutralX,
    NeutralYMem               := _JoystickNeutralY
);


// === 🧲 §4 CODEURS & HOMING (M1 / M2) ===

instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn            := HwIn.Winch.COD1_PosValue,
    AlarmsIn            := HwIn.Winch.COD1_Alarms,
    WarningsIn          := HwIn.Winch.COD1_Warnings,
    SlaveOperational    := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM1.Operational,
    PresetRequest       := instHomingM1.PresetRequest,
    PresetValue         := instHomingM1.PresetValue
);

instHomingM1(
    Enable               := TRUE,
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                 := PRG_03_Modes_Cycle.Auth.Mode,
    Home                 := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    UnitaryMode          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                            AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 3),
    WinchSelected        := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 1),
    CfgHomingTargetM        := _WinchM1CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    TopPositionSensor    := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM   := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback        := HwIn.Winch.M1_BrakeIsOpen_DI,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    Calib                := _CalibM1
);

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn            := HwIn.Winch.COD2_PosValue,
    AlarmsIn            := HwIn.Winch.COD2_Alarms,
    WarningsIn          := HwIn.Winch.COD2_Warnings,
    SlaveOperational    := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM2.Operational,
    PresetRequest       := instHomingM2.PresetRequest,
    PresetValue         := instHomingM2.PresetValue
);

instHomingM2(
    Enable               := TRUE,
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                 := PRG_03_Modes_Cycle.Auth.Mode,
    Home                 := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero,
    UnitaryMode          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                            AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 3),
    WinchSelected        := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2),
    CfgHomingTargetM        := _WinchM2CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence,
    TopPositionSensor    := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM   := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _WinchM2CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback        := HwIn.Winch.M2_BrakeIsOpen_DI,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M2TreuilBenne.Bypass.Global,
    Calib                := _CalibM2
);

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);


// === ↔️ §5 DÉCODAGE POSITION TRANSLATION (M3) ===

instPosDecoderM3(
    SensorTremie      := HwIn.Translation.M3_PosTremie_DI,
    SensorPV          := HwIn.Translation.M3_PosPV_DI,
    SensorP2          := HwIn.Translation.M3_PosP2_DI,
    SensorP1          := HwIn.Translation.M3_PosP1_DI,
    SensorMaintenance := HwIn.Translation.M3_PosMaintenance_DI
);

TranslationPosTremie      := instPosDecoderM3.TranslationPosTremie;
TranslationPosPV          := instPosDecoderM3.TranslationPosPV;
TranslationPosP2          := instPosDecoderM3.TranslationPosP2;
TranslationPosP1          := instPosDecoderM3.TranslationPosP1;
TranslationPosMaintenance := instPosDecoderM3.TranslationPosMaintenance;
M3_LimitSwitchFwd       := instPosDecoderM3.LimitSwitchFwd;
M3_LimitSwitchRev       := instPosDecoderM3.LimitSwitchRev;
M3_SensorWordIncoherent := instPosDecoderM3.Incoherent;
M3_SensorsWord          := instPosDecoderM3.SensorsWord;


// === 📊 §6 FILTRAGE PT1 RETOURS VARIATEUR (M3) ===

instCycleTimeAcq(DefaultValueS := 0.010);

instFilterM3StatusWord(
    ValueIn    := UINT_TO_REAL(WORD_TO_UINT(HwIn.Translation.M3_StatusWord)),
    TimeConst  := T#0MS,
    CycleTimeS := instCycleTimeAcq.CycleTimeS
);
M3_StatusWord_Filtered := REAL_TO_UINT(instFilterM3StatusWord.ValueOut);

instFilterM3ActualFreqHz(
    ValueIn    := UINT_TO_REAL(HwIn.Translation.M3_ActualFrequencyHz),
    TimeConst  := T#0MS,
    CycleTimeS := instCycleTimeAcq.CycleTimeS
);
M3_ActualFrequencyHz_Filtered := REAL_TO_UINT(instFilterM3ActualFreqHz.ValueOut);

END_PROGRAM

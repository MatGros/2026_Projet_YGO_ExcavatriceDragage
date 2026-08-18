(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_07_Supervision — Échanges IHM, Diagnostics et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   📄 Docs : DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_07_Supervision

VAR_OUTPUT
    FaultMachineReset_IHM : BOOL;
END_VAR

VAR
    instBlink1Hz : BLINK;
    instAckConfigRestored : R_TRIG;
    instCfgPersistBridgeSync : FB_CfgPersistBridge_SyncCfg;
    instCfgPersistBridgeCycle : FB_CfgPersistBridge_CycleCfg;
    instCfgPersistBridgeDredgingAssist : FB_CfgPersistBridge_DredgingAssistCfg;
    instCfgPersistBridgeCommun : FB_CfgPersistBridge_CommunCfg;
    instCfgPersistBridgeBucket : FB_CfgPersistBridge_BucketCfg;
    instCfgPersistBridgeWinchM1 : FB_CfgPersistBridge_WinchCfg;
    instCfgPersistBridgeWinchM2 : FB_CfgPersistBridge_WinchCfg;
    instCfgPersistBridgeTranslation : FB_CfgPersistBridge_TranslationCfg; // 🆕 2026-08-06 : Translation n'avait pas de slot Cfg
    instDiagCanOpen : FB_Diag_CanOpen;
    instDiagEthercat : FB_Diag_Ethercat;
    instDiagIhmHeartbeat : FB_Diag_IhmHeartbeat;
    instPreflight        : FB_Acquisition_Preflight;
    instHmiBannerFormatter : FB_Hmi_BannerFormatter;
    instTroubleshootingView : FB_TroubleshootingView;
END_VAR

{region "§1 Horloge et reset machine"}
// === 🧩 §1 HORLOGE & RESET MACHINE ===

instBlink1Hz(
    ENABLE   := TRUE,
    TIMEHIGH := _BlinkTimeOn,
    TIMELOW  := _BlinkTimeOff
);
GVL_Global.BlinkClock := instBlink1Hz.OUT;

instDiagCanOpen(
    Enable                 := TRUE,
    Reset                  := GVL_IHM.Modes.Cmd.BtnFaultReset,
    CANbusStateRaw         := PRG_02_Acquisition.HwReal.Operator.CanBusState,
    DeviceJoystickStateRaw := PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState,
    SimBypassActive        := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive,
    NetworkBypassActive    := GVL_IHM.Network.Bypass.Global
);

instDiagEthercat(
    Enable                   := TRUE,
    Reset                    := GVL_IHM.Modes.Cmd.BtnFaultReset,
    DeviceVariateurStateRaw  := PRG_02_Acquisition.HwReal.Translation.AC600_DeviceState,
    DeviceVariateurSimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive,
    DeviceEncoderM1StateRaw  := PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState,
    DeviceEncoderM1SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    DeviceEncoderM2StateRaw  := PRG_02_Acquisition.HwReal.Winch.COD2_DeviceState,
    DeviceEncoderM2SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    NetworkBypassActive      := GVL_IHM.Network.Bypass.Global
);

// 💓 T83 (décision CK6) : tant que l'IHM n'implémente pas le toggle réel
// (GVL_IHM.Network.Bypass.IhmHeartbeat := TRUE, défaut sécurisé), le front
// est simulé par le clignotant PLC 1 Hz pour ne jamais latcher un timeout
// artificiel. Repasser le bypass à FALSE côté IHM active la vraie surveillance.
instDiagIhmHeartbeat(
    Enable          := TRUE,
    TglHeartbeatIhm := SEL(GVL_IHM.Network.Bypass.IhmHeartbeat, GVL_IHM.Commun.TglHeartbeatIhm, GVL_Global.BlinkClock)
);

FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;


{endregion}

{region "§2 Persistance et restauration configuration"}
// === 🌉 §2 PERSISTANCE & RESTAURATION CONFIG ===

instCfgPersistBridgeWinchM1(Hmi := GVL_IHM.M1TreuilRetenue.Cfg, Persist := _WinchM1CfgPersist);
IF instCfgPersistBridgeWinchM1.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeWinchM2(Hmi := GVL_IHM.M2TreuilBenne.Cfg, Persist := _WinchM2CfgPersist);
IF instCfgPersistBridgeWinchM2.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeSync(Hmi := GVL_IHM.M1M2Sync.Cfg, Persist := _SyncCfgPersist);
IF instCfgPersistBridgeSync.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeTranslation(Hmi := GVL_IHM.TranslationM3.Cfg, Persist := _TranslationCfgPersist);
IF instCfgPersistBridgeTranslation.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeBucket(Hmi := GVL_IHM.M2TreuilBenne.Bucket.Cfg, Persist := _BucketCfgPersist);
IF instCfgPersistBridgeBucket.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);
IF instCfgPersistBridgeCommun.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCycle(Hmi := GVL_IHM.Cycle.Cfg, Persist := _CycleCfgPersist);
IF instCfgPersistBridgeCycle.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeDredgingAssist(Hmi := GVL_IHM.DredgingAssist.Cfg, Persist := _DredgingAssistCfgPersist);
IF instCfgPersistBridgeDredgingAssist.JustRestored THEN
    GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch         := GVL_IHM.DredgingAssist.Cfg.TglEnableDiveSearch;
    GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence := GVL_IHM.DredgingAssist.Cfg.TglEnableExtractionSequence;
    GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie       := GVL_IHM.DredgingAssist.Cfg.TglEnableDumpAtTremie;
    GVL_IHM.Commun.ConfigRestoredFromPersistent            := TRUE;
ELSE
    GVL_IHM.DredgingAssist.Cfg.TglEnableDiveSearch         := GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch;
    GVL_IHM.DredgingAssist.Cfg.TglEnableExtractionSequence := GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence;
    GVL_IHM.DredgingAssist.Cfg.TglEnableDumpAtTremie       := GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie;
END_IF;

IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
// 🆕 2026-08-06 (retour terrain, mise en service) : jusqu'ici _TranslationSetFreq_Hz
// n'était JAMAIS réécrit après sa déclaration — la restauration au boot rejouait donc
// toujours la valeur par défaut compilée (0.0), jamais le dernier réglage opérateur.
// Recopie continue (après restauration) : toute consigne changée en session survit au
// prochain boot/reset chaud, pas seulement le défaut d'usine.
_TranslationSetFreq_Hz := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;

instAckConfigRestored(CLK := GVL_IHM.Commun.BtnAckConfigRestored);
IF instAckConfigRestored.Q THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
END_IF;

IF NOT GVL_IHM.TranslationM3.Bypass.Initialized THEN
    IF BypassTranslationGlobal THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.TranslationM3.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
    IF BypassWinchM1Global THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
    IF BypassWinchM2Global THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
END_IF;

// 🔧 REX 2026-08 : GVL_BypassRetain.BypassSyncGlobal (RETAIN) et
// ST_BypassSync.Initialized existaient tous les deux, mais aucun bloc de
// restauration boot ne les reliait (contrairement à Translation/M1/M2 ci-dessus)
// — Initialized restait bloqué à FALSE indéfiniment, bypass synchro jamais
// restauré après redémarrage. Ajouté ici, même pattern que les 3 autres domaines.
IF NOT GVL_IHM.M1M2Sync.Bypass.Initialized THEN
    IF BypassSyncGlobal THEN
        GVL_IHM.M1M2Sync.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1M2Sync.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.Commun.Bypass.Initialized THEN
    IF BypassCommunGlobal THEN
        GVL_IHM.Commun.Bypass.Global := TRUE;
    END_IF;
    IF BypassLimitLegal THEN
        GVL_IHM.Commun.Bypass.LimitLegal := TRUE;
    END_IF;
    IF BypassTopLimitSwitch THEN
        GVL_IHM.Commun.Bypass.TopLimitSwitch := TRUE;
    END_IF;
    IF BypassTopLimitSoftware THEN
        GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE;
    END_IF;
    IF BypassCableLimitSwitch THEN
        GVL_IHM.Commun.Bypass.CableLimitSwitch := TRUE;
    END_IF;
    IF BypassSlackCable THEN
        GVL_IHM.Commun.Bypass.SlackCable := TRUE;
    END_IF;
    GVL_IHM.Commun.Bypass.Initialized := TRUE;
END_IF;

IF GVL_IHM.TranslationM3.Bypass.Global <> BypassTranslationGlobal THEN
    BypassTranslationGlobal := GVL_IHM.TranslationM3.Bypass.Global;
END_IF;
IF GVL_IHM.M1TreuilRetenue.Bypass.Global <> BypassWinchM1Global THEN
    BypassWinchM1Global := GVL_IHM.M1TreuilRetenue.Bypass.Global;
END_IF;
IF GVL_IHM.M2TreuilBenne.Bypass.Global <> BypassWinchM2Global THEN
    BypassWinchM2Global := GVL_IHM.M2TreuilBenne.Bypass.Global;
END_IF;
IF GVL_IHM.M1M2Sync.Bypass.Global <> BypassSyncGlobal THEN
    BypassSyncGlobal := GVL_IHM.M1M2Sync.Bypass.Global;
END_IF;
IF GVL_IHM.Commun.Bypass.Global <> BypassCommunGlobal THEN
    BypassCommunGlobal := GVL_IHM.Commun.Bypass.Global;
END_IF;
IF GVL_IHM.Commun.Bypass.LimitLegal <> BypassLimitLegal THEN
    BypassLimitLegal := GVL_IHM.Commun.Bypass.LimitLegal;
END_IF;
IF GVL_IHM.Commun.Bypass.TopLimitSwitch <> BypassTopLimitSwitch THEN
    BypassTopLimitSwitch := GVL_IHM.Commun.Bypass.TopLimitSwitch;
END_IF;
IF GVL_IHM.Commun.Bypass.TopLimitSoftware <> BypassTopLimitSoftware THEN
    BypassTopLimitSoftware := GVL_IHM.Commun.Bypass.TopLimitSoftware;
END_IF;
IF GVL_IHM.Commun.Bypass.CableLimitSwitch <> BypassCableLimitSwitch THEN
    BypassCableLimitSwitch := GVL_IHM.Commun.Bypass.CableLimitSwitch;
END_IF;
IF GVL_IHM.Commun.Bypass.SlackCable <> BypassSlackCable THEN
    BypassSlackCable := GVL_IHM.Commun.Bypass.SlackCable;
END_IF;

{endregion}

{region "§3 Projections IHM et mapping"}
// === 📊 §3 PROJECTIONS IHM ET MAPPING ===

GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
    AND ((PRG_02_Acquisition.CablePosM1 <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)
      OR (PRG_02_Acquisition.CablePosM2 <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_IHM.Commun.HydraulicThermalFault     := NOT PRG_02_Acquisition.HwIn.Machine.HydraulicThermalOk_DI;
GVL_IHM.Commun.BrakeThermalFault         := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI;
GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;

// 💓 Publication heartbeat IHM↔PLC (T83, LOT0_DIAG_IHM_HEARTBEAT 2026-08-05)
GVL_IHM.Commun.HeartbeatIhmOk            := instDiagIhmHeartbeat.HeartbeatIhmOk;
GVL_IHM.Commun.HeartbeatIhmTimeout       := instDiagIhmHeartbeat.HeartbeatIhmTimeout;
GVL_IHM.Commun.HeartbeatIhmElapsed       := instDiagIhmHeartbeat.TimeSinceIhmEdge;
GVL_IHM.Commun.TglHeartbeatPlc           := instDiagIhmHeartbeat.TglHeartbeatPlc;

// 🩺 Exécution du Preflight Machine à l'arrêt
instPreflight(
    Execute                   := GVL_IHM.Commun.Preflight.BtnRun,
    MachineIsStill            := (PRG_04_Treuils_Benne.WinchM1State.StepNumber = 0)
                                 AND (PRG_04_Treuils_Benne.WinchM2State.StepNumber = 0)
                                 AND (PRG_05_Translation.TranslationState.FBState = E_State.READY),
    M1BrakeApplied            := NOT PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    M2BrakeApplied            := NOT PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    M3BrakeApplied            := TRUE, // Pas de retour frein M3 direct sur ce lot
    M1ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    M2ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    M1ThermalOk               := PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    M2ThermalOk               := PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalOk            := PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    PhaseRotationOk           := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    SlackCableTensioned       := PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    M3SensorWordIncoherent    := PRG_02_Acquisition.M3_SensorWordIncoherent,
    EmergencyChainClosed      := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    EncoderM1Operational      := instDiagEthercat.DeviceEncoderM1.Operational,
    EncoderM2Operational      := instDiagEthercat.DeviceEncoderM2.Operational,
    HomedM1                   := PRG_04_Treuils_Benne.WinchM1State.Encoder.Homed,
    HomedM2                   := PRG_04_Treuils_Benne.WinchM2State.Encoder.Homed,
    M1PositionInBounds        := NOT PRG_02_Acquisition.M1_EncoderIncoherent,
    M2PositionInBounds        := NOT PRG_02_Acquisition.M2_EncoderIncoherent
);
GVL_IHM.Commun.Preflight.PreflightOk      := instPreflight.PreflightOk;
GVL_IHM.Commun.Preflight.PreflightDone    := instPreflight.PreflightDone;
GVL_IHM.Commun.Preflight.PreflightBusy    := instPreflight.PreflightBusy;
GVL_IHM.Commun.Preflight.PreflightErrorId := instPreflight.PreflightErrorId;

GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
GVL_IHM.Commun.SimSlackCableBypassActive         := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.SimTopSensorBypassActive          := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;

GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.WinchM1State;
GVL_IHM.M2TreuilBenne.State := PRG_04_Treuils_Benne.WinchM2State;
GVL_IHM.M1TreuilRetenue.Safety := PRG_04_Treuils_Benne.WinchM1Safety;
GVL_IHM.M2TreuilBenne.Safety := PRG_04_Treuils_Benne.WinchM2Safety;
GVL_IHM.M1M2Sync.State := PRG_04_Treuils_Benne.SyncState;
GVL_IHM.M2TreuilBenne.Bucket.State := PRG_04_Treuils_Benne.BucketState;
GVL_IHM.TranslationM3.State := PRG_05_Translation.TranslationState;
GVL_IHM.TranslationM3.Safety := PRG_05_Translation.TranslationSafety;

GVL_IHM.Modes.State.CurrentMode := PRG_03_Modes_Cycle.Auth.Mode;
GVL_IHM.Modes.State.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
GVL_IHM.Modes.State.PowerContactorOk := PRG_06_Outputs_LD.EmergencyState.ContactorOk;
GVL_IHM.Modes.State.EmergencyChainOk := PRG_06_Outputs_LD.EmergencyState.ChainOk;
GVL_IHM.Modes.State.EmergencyArmable := PRG_06_Outputs_LD.EmergencyState.Armable;
GVL_IHM.Modes.State.EmergencyArmingBusy := PRG_06_Outputs_LD.EmergencyState.ArmingBusy;
GVL_IHM.Modes.State.RedundancyTestFailed := PRG_06_Outputs_LD.EmergencyDiag.RedundancyTestFailed;
GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_06_Outputs_LD.EmergencyDiag.ArmFailed;
GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs_LD.EmergencyDiag.Error OR PRG_02_Acquisition.InputModuleFault;
GVL_IHM.Modes.State.PowerCutOffActive := PRG_06_Outputs_LD.PowerCutOffActive;

// 🕹️ Publication état Joystick IHM (GVL_IHM.JOY1Joystick.State)
GVL_IHM.JOY1Joystick.State.RawX := PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1;
GVL_IHM.JOY1Joystick.State.RawY := PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2;
GVL_IHM.JOY1Joystick.State.RawButton := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw;
GVL_IHM.JOY1Joystick.State.AxisCmdX := PRG_02_Acquisition.instJoystick.AxisCmdX;
GVL_IHM.JOY1Joystick.State.AxisCmdY := PRG_02_Acquisition.instJoystick.AxisCmdY;
GVL_IHM.JOY1Joystick.State.NeutralXAct := PRG_02_Acquisition.instJoystick.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct := PRG_02_Acquisition.instJoystick.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_02_Acquisition.JoystickDeadmanArmed;
GVL_IHM.JOY1Joystick.State.AtNeutral := PRG_02_Acquisition.instJoystick.AtNeutral;
GVL_IHM.JOY1Joystick.State.Online := instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JOY1Joystick.State.Operational := instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JOY1Joystick.State.Error := instDiagCanOpen.Error;
GVL_IHM.JOY1Joystick.State.ErrorId := instDiagCanOpen.ErrorId;

GVL_IHM.Network.CanError    := instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := instDiagCanOpen.ErrorId;
GVL_IHM.Network.Joystick    := instDiagCanOpen.DeviceJoystick;
GVL_IHM.Network.BusEthercat := instDiagEthercat.DeviceEthercatMaster;
GVL_IHM.Network.EncoderM1   := instDiagEthercat.DeviceEncoderM1;
GVL_IHM.Network.EncoderM2   := instDiagEthercat.DeviceEncoderM2;
GVL_IHM.Network.VariateurM3 := instDiagEthercat.DeviceVariateur;
GVL_IHM.Network.EcatError   := instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := instDiagEthercat.ErrorId;

// 🩺 Diagnostic carte des 3 modules DI TOR réelles (AF06 §3bis) — lecture seule, calculé
// dans PRG_02_Acquisition, simple recopie ici pour l'IHM (même patron que Network.*).
GVL_IHM.Network.InputModules.LocalDigitalIoOk := PRG_02_Acquisition.LocalDigitalIoOk;
GVL_IHM.Network.InputModules.Vh0800EndOk      := PRG_02_Acquisition.Vh0800EndOk;
GVL_IHM.Network.InputModules.Vh0808EtpOk      := PRG_02_Acquisition.Vh0808EtpOk;
// 🖥️ Bandeau IHM 4 champs (AF-07 §4)
// 🆕 Publication des états du cycle semi-auto (lecture seule) — alimente le bandeau (T115)
GVL_IHM.Cycle.State.Ready                  := PRG_03_Modes_Cycle.instCycleSemiAuto.Ready;
GVL_IHM.Cycle.State.Busy                   := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy;
GVL_IHM.Cycle.State.Done                   := PRG_03_Modes_Cycle.instCycleSemiAuto.Done;
GVL_IHM.Cycle.State.Error                  := PRG_03_Modes_Cycle.instCycleSemiAuto.Error;
GVL_IHM.Cycle.State.ErrorId                := PRG_03_Modes_Cycle.instCycleSemiAuto.ErrorId;
GVL_IHM.Cycle.State.CycleStep              := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep;
GVL_IHM.Cycle.State.CycleStateStr          := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStateStr;
GVL_IHM.Cycle.State.CycleStepAtError       := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStepAtError;
GVL_IHM.Cycle.State.SampleCount            := _CycleSampleCount;
GVL_IHM.Cycle.State.SelTarget              := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.State.KoboldContactFond      := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI;
GVL_IHM.Cycle.State.KoboldContactorCmd     := PRG_03_Modes_Cycle.instCycleSemiAuto.BucketCmd.KoboldContactorCmd;
GVL_IHM.Cycle.State.LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.State.LimitLegalDepth_M      := _CommunCfgPersist.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.State.WinchSyncError         := PRG_04_Treuils_Benne.instWinchSync.Error;
GVL_IHM.Cycle.State.WinchSyncDelta_M       := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM;
GVL_IHM.Cycle.State.SpeedMismatch_Mps      := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchMps;
GVL_IHM.Cycle.State.SpeedMismatchActive    := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchActive;
GVL_IHM.Cycle.State.SpeedMismatchConfirmed := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchConfirmed;
GVL_IHM.Cycle.State.M1Position_M           := PRG_02_Acquisition.CablePosM1;
GVL_IHM.Cycle.State.M2Position_M           := PRG_02_Acquisition.CablePosM2;
GVL_IHM.Cycle.State.DeadmanArmed           := PRG_02_Acquisition.JoystickDeadmanArmed;
GVL_IHM.Cycle.State.JoystickMotionActive   := NOT PRG_02_Acquisition.instJoystick.AtNeutral;
GVL_IHM.Cycle.State.MotionPermit           := NOT PRG_02_Acquisition.instJoystick.AtNeutral;

instHmiBannerFormatter(
    Enable                := TRUE,
    SimulationModeActive  := GVL_Simulation.SimulationModeActive,
    CurrentMode           := PRG_03_Modes_Cycle.Auth.Mode,
    BothAxesCoupled       := (GVL_IHM.Modes.Cmd.SelJoystickWinch = 0),
    WinchSelected         := GVL_IHM.Modes.Cmd.SelJoystickWinch,
    CycleStep             := GVL_IHM.Cycle.State.CycleStep,
    DiveState             := GVL_IHM.DredgingAssist.State.DiveState,
    ExtractionState       := GVL_IHM.DredgingAssist.State.ExtractionState,
    HomingActive          := (NOT PRG_04_Treuils_Benne.WinchM1State.Encoder.Homed) OR (NOT PRG_04_Treuils_Benne.WinchM2State.Encoder.Homed),
    HomingStepM1          := SEL(PRG_02_Acquisition.instHomingM1.Busy, 0, 1),
    HomingStepM2          := SEL(PRG_02_Acquisition.instHomingM2.Busy, 0, 1),
    BypassGlobalActive    := GVL_IHM.Network.Bypass.Global,
    BypassWinchM1Active   := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassWinchM2Active   := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassTranslation     := GVL_IHM.TranslationM3.Bypass.Global,
    BypassSyncActive      := GVL_IHM.M1M2Sync.Bypass.Global,
    SyncDegradedActive    := PRG_04_Treuils_Benne.SyncState.SyncDegradedStep1,
    LegalLimitReached     := GVL_IHM.Commun.LimitLegalReached,
    EmergencyChainClosed  := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffActiveAny        := PRG_06_Outputs_LD.PowerCutOffActive,
    SafeStopActive              := GVL_IHM.M1TreuilRetenue.Safety.SafeStop OR GVL_IHM.M2TreuilBenne.Safety.SafeStop,
    DescendPermit               := GVL_IHM.M1TreuilRetenue.Safety.DescendPermit AND GVL_IHM.M2TreuilBenne.Safety.DescendPermit,
    AscentPermit                := GVL_IHM.M1TreuilRetenue.Safety.AscentPermit AND GVL_IHM.M2TreuilBenne.Safety.AscentPermit,
    BucketIsOpen                := PRG_04_Treuils_Benne.BucketState.MechState.IsOpen,
    DiveActive                  := GVL_IHM.DredgingAssist.State.DiveBusy,
    TopLimitReached             := GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent OR GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    M1LogicRequestDirection     := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestDirection     := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CycleRequestDirection       := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.Direction,
    DeadmanArmed                := PRG_02_Acquisition.JoystickDeadmanArmed,
    JoystickAtNeutral           := PRG_02_Acquisition.instJoystick.AtNeutral,
    CycleAutoBusy               := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy
);
GVL_IHM.Banner := instHmiBannerFormatter.Banner;

{endregion}

{region "§4 Vue depannage lecture seule"}
// === 🕵️♂️ §4 VUE DÉPANNAGE (lecture seule stricte) ===

instTroubleshootingView(
    Enable               := TRUE,
    HwIn                 := PRG_02_Acquisition.HwIn,
    HwReal               := PRG_02_Acquisition.HwReal,
    InputModuleFault     := PRG_02_Acquisition.InputModuleFault,
    LocalDigitalIoOk     := PRG_02_Acquisition.LocalDigitalIoOk,
    Vh0800EndOk          := PRG_02_Acquisition.Vh0800EndOk,
    Vh0808EtpOk          := PRG_02_Acquisition.Vh0808EtpOk,
    Auth                 := PRG_03_Modes_Cycle.Auth,
    M1LogicRequestSpeedRef_Pct := PRG_04_Treuils_Benne.M1LogicRequestSpeedRef_Pct,
    M1LogicRequestDirection := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestSpeedRef_Pct := PRG_04_Treuils_Benne.M2LogicRequestSpeedRef_Pct,
    M2LogicRequestDirection := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    CoupledUserRequestActive := PRG_04_Treuils_Benne.CoupledUserRequestActive,
    CycleAutoBusy := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy,
    CycleM1SpeedRef_Pct := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.SpeedPct,
    CycleM2SpeedRef_Pct := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM2Cmd.SpeedPct,
    CycleBucketOpen := PRG_03_Modes_Cycle.instCycleSemiAuto.BucketCmd.Open,
    CycleTargetPosition := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Target,
    SimulationModeActive := GVL_Simulation.SimulationModeActive,
    SimWinchActive       := GVL_Simulation.SimWinchActive,
    SimTranslationActive := GVL_Simulation.SimTranslationActive,
    SimOperatorActive    := GVL_Simulation.SimOperatorActive,
    SimSafetyActive      := GVL_Simulation.SimSafetyActive,
    WinchM1              := GVL_IHM.M1TreuilRetenue,
    WinchM2              := GVL_IHM.M2TreuilBenne,
    Sync                 := GVL_IHM.M1M2Sync,
    Translation          := GVL_IHM.TranslationM3,
    Commun               := GVL_IHM.Commun,
    Network              := GVL_IHM.Network,
    DredgingAssist       := GVL_IHM.DredgingAssist,
    JoystickHMI          := GVL_IHM.JOY1Joystick,
    EmergencyState       := PRG_06_Outputs_LD.EmergencyState,
    EmergencyDiag        := PRG_06_Outputs_LD.EmergencyDiag,
    PowerCutOffActive    := PRG_06_Outputs_LD.PowerCutOffActive,
    ArmingPulseActive    := PRG_06_Outputs_LD.EmergencyArmingPulseActive,
    MaintainAActive      := PRG_06_Outputs_LD.PowerKeepAliveACmd,
    MaintainBActive      := PRG_06_Outputs_LD.PowerKeepAliveBCmd
);

{endregion}
END_PROGRAM

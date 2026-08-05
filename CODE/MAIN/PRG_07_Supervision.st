(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_07_Supervision — Échanges IHM, Diagnostics et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   📄 Docs : DOC/AF_Partie-07_Interface_IHM_v2.0.md
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
    instDiagCanOpen : FB_Diag_CanOpen;
    instDiagEthercat : FB_Diag_Ethercat;
    instDiagIhmHeartbeat : FB_Diag_IhmHeartbeat;
    instTroubleshootingView : FB_TroubleshootingView;
END_VAR

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

StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.Cmd.SelTarget;

FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;


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
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

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


// === 📊 §3 PROJECTIONS IHM ET MAPPING ===

GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled;
GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_IHM.Commun.HydraulicThermalFault     := NOT PRG_02_Acquisition.HwIn.Machine.HydraulicThermalOk_DI;
GVL_IHM.Commun.BrakeThermalFault         := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI;
GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;

// 💓 Publication heartbeat IHM↔PLC (T83, LOT0_DIAG_IHM_HEARTBEAT 2026-08-05)
GVL_IHM.Commun.HeartbeatIhmOk            := instDiagIhmHeartbeat.HeartbeatIhmOk;
GVL_IHM.Commun.HeartbeatIhmTimeout       := instDiagIhmHeartbeat.HeartbeatIhmTimeout;
GVL_IHM.Commun.HeartbeatIhmElapsed       := instDiagIhmHeartbeat.TimeSinceIhmEdge;
GVL_IHM.Commun.TglHeartbeatPlc           := instDiagIhmHeartbeat.TglHeartbeatPlc;

GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
GVL_IHM.Commun.Bypass.SlackCable                 := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.Bypass.TopPositionSensor          := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;

GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.WinchM1StateHMI;
GVL_IHM.M2TreuilBenne.State := PRG_04_Treuils_Benne.WinchM2StateHMI;
GVL_IHM.M1TreuilRetenue.Safety := PRG_04_Treuils_Benne.WinchM1SafetyHMI;
GVL_IHM.M2TreuilBenne.Safety := PRG_04_Treuils_Benne.WinchM2SafetyHMI;
GVL_IHM.M1M2Sync.State := PRG_04_Treuils_Benne.SyncStateHMI;
GVL_IHM.M2TreuilBenne.Bucket.State := PRG_04_Treuils_Benne.BucketStateHMI;
GVL_IHM.TranslationM3.State := PRG_05_Translation.TranslationStateHMI;
GVL_IHM.TranslationM3.Safety := PRG_05_Translation.TranslationSafetyHMI;

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
GVL_IHM.Network.InputModules.Fault            := PRG_02_Acquisition.InputModuleFault;


// === 🕵️♂️ §4 VUE DÉPANNAGE (lecture seule stricte) ===

instTroubleshootingView(
    Enable               := TRUE,
    HwIn                 := PRG_02_Acquisition.HwIn,
    HwReal               := PRG_02_Acquisition.HwReal,
    HwRealQualified      := PRG_02_Acquisition.HwRealQualified,
    InputModuleFault     := PRG_02_Acquisition.InputModuleFault,
    LocalDigitalIoOk     := PRG_02_Acquisition.LocalDigitalIoOk,
    Vh0800EndOk          := PRG_02_Acquisition.Vh0800EndOk,
    Vh0808EtpOk          := PRG_02_Acquisition.Vh0808EtpOk,
    Auth                 := PRG_03_Modes_Cycle.Auth,
    SimulationModeActive := GVL_Simulation.SimulationModeActive,
    SimWinchActive       := GVL_Simulation.SimWinchActive,
    SimTranslationActive := GVL_Simulation.SimTranslationActive,
    SimOperatorActive    := GVL_Simulation.SimOperatorActive,
    SimMachineActive     := GVL_Simulation.SimMachineActive,
    WinchM1              := GVL_IHM.M1TreuilRetenue,
    WinchM2              := GVL_IHM.M2TreuilBenne,
    Sync                 := GVL_IHM.M1M2Sync,
    Translation          := GVL_IHM.TranslationM3,
    Commun               := GVL_IHM.Commun,
    Network              := GVL_IHM.Network
);

END_PROGRAM

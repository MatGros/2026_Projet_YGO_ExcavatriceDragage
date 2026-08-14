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

StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.Cmd.SelTarget;

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
    MachineIsStill            := (PRG_04_Treuils_Benne.WinchM1StateHMI.StepNumber = 0)
                                 AND (PRG_04_Treuils_Benne.WinchM2StateHMI.StepNumber = 0)
                                 AND (PRG_05_Translation.TranslationStateHMI.FBState = E_State.READY),
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
    HomedM1                   := PRG_04_Treuils_Benne.WinchM1StateHMI.Encoder.Homed,
    HomedM2                   := PRG_04_Treuils_Benne.WinchM2StateHMI.Encoder.Homed,
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

// 🕹️ Publication état Joystick IHM (GVL_IHM.JOY1Joystick.State)
GVL_IHM.JOY1Joystick.State.RawX := PRG_02_Acquisition.HwReal.Operator.JoyXRaw_ANA1;
GVL_IHM.JOY1Joystick.State.RawY := PRG_02_Acquisition.HwReal.Operator.JoyYRaw_ANA2;
GVL_IHM.JOY1Joystick.State.RawButton := PRG_02_Acquisition.HwReal.Operator.JoyBtnRaw;
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
GVL_IHM.Network.InputModules.Fault            := PRG_02_Acquisition.InputModuleFault;


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
    DredgingAssist       := GVL_IHM.DredgingAssist
);

{endregion}
END_PROGRAM

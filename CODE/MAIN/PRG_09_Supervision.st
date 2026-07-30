(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_09_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   🔧 REX 2026-07-07 : séparation des resets — l'ancien MachineReset_IHM (unique, câblé sur
      TOUT y compris FB_Modes/FB_Cycle) est retiré. FaultMachineReset_IHM ne couvre plus que le
      domaine sécurité/métier (Winch, Safety, Encodeurs, Benne, Joystick, Translation) ;
      FB_Modes/FB_Cycle ont chacun leur propre Reset dédié (GVL_IHM.Modes.Cmd.BtnModeReset côté
      PRG_04_Modes, CmdResetCycle_IHM côté PRG_05_Cycle) — jamais mélangés.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-07_Interface_IHM_v2.0.md
*)

PROGRAM PRG_09_Supervision
VAR_OUTPUT
    FaultMachineReset_IHM : BOOL; // 🔔 Acquittement défauts domaine sécurité/métier (OR des boutons HMI) — jamais Modes/Cycle
END_VAR
VAR
    instBlink1Hz : BLINK; // 🧩 Réutilisation lib Util (Partie3 §0) — horloge clignotement système
    instAckConfigRestored : R_TRIG; // 🔔 Front acquittement opérateur restauration config PERSISTENT (§2bis)
    instCfgPersistBridgeSync : FB_CfgPersistBridge_SyncCfg; // 🌉 Pont persistance M1M2Sync.Cfg (Lot 3a, pilote)
    instCfgPersistBridgeCycle : FB_CfgPersistBridge_CycleCfg; // 🌉 Pont persistance Cycle.Cfg (Lot 3b)
    instCfgPersistBridgeDredgingAssist : FB_CfgPersistBridge_DredgingAssistCfg; // 🌉 Pont persistance assistants prélèvement
    instCfgPersistBridgeCommun : FB_CfgPersistBridge_CommunCfg; // 🌉 Pont persistance Commun.Cfg (Lot 3b)
    instCfgPersistBridgeBucket : FB_CfgPersistBridge_BucketCfg; // 🌉 Pont persistance M2TreuilBenne.Bucket.Cfg (Lot 3b)
    instCfgPersistBridgeWinchM1 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M1TreuilRetenue.Cfg (Lot 3d-2)
    instCfgPersistBridgeWinchM2 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M2TreuilBenne.Cfg (Lot 3d-2)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_09_Supervision) ===

// ── 0. HORLOGE CLIGNOTEMENT SYSTÈME (GVL_Global.BlinkClock) ───────────────
// 🧩 Réutilisation lib Util (Partie3 §0) : bloc standard BLINK, pas de TON maison —
// gère nativement un rythme allumé/éteint ASYMÉTRIQUE (TimeHigh ≠ TimeLow), contrairement
// au motif TON manuel de FB_Output.st (symétrique 500/500, propre à l'option relais).
// 🔧 REX 2026-07-16 : durées réglables sans recompiler (GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff,
// défaut 1s allumé / 800ms éteint) — un seul rythme partagé pour tous les voyants IHM/diag qui
// clignotent pareil.
// 💡 Un voyant a besoin d'un AUTRE rythme ? Instancier son propre BLINK localement (Util) avec
// ses propres TimeHigh/TimeLow — ne pas détourner ce bit partagé pour un rythme différent.
instBlink1Hz(
    ENABLE   := TRUE,
    TIMEHIGH := _BlinkTimeOn,
    TIMELOW  := _BlinkTimeOff
);
GVL_Global.BlinkClock := instBlink1Hz.OUT;


// ── 1. ACQUISITION DES DEMANDES / BOUTONS DE L'IHM ────────────────────────
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.Cmd.SelMode;
GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable; // 🔧 REX 2026-07-08 : renommé, polarité inversée
StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.Cmd.SelTarget;

// Signal d'acquittement défauts domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07)
FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;


// ── 2. BRIDGES ET PERSISTANCE CONFIG (Restauration automatique) ────────────
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

// 🎯 Translation M3 : persistance ciblée du seul réglage SetFreq_Hz.
// Aucun pont struct complet : BtnFwd/BtnRev restent impérativement non persistants.
IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

// ── 2bis. ACQUITTEMENT RESTAURATION CONFIG (front, doctrine reset=front) ───
// 🐛 FIX 2026-07-23 : `ConfigRestoredFromPersistent` ne doit JAMAIS disparaître tout seul —
// même doctrine que les défauts métier (cause disparue + appui reset conscient pour effacer).
// Tant que l'opérateur n'a pas vérifié/acquitté, le bit reste visible à l'IHM.
instAckConfigRestored(CLK := GVL_IHM.Commun.BtnAckConfigRestored);
IF instAckConfigRestored.Q THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
END_IF;

// 🌐 Restauration des bypass RETAIN au boot UNIQUEMENT — co-localisation flag Initialized
// Après ça, seule la sauvegarde IHM→RETAIN fonctionne (jamais l'inverse).
// Évite le bug où une écriture IHM était écrasée par la restauration.
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

// Sauvegarde synchrone vers les variables RETAIN si modifiées côté IHM
IF GVL_IHM.TranslationM3.Bypass.Global <> BypassTranslationGlobal THEN
    BypassTranslationGlobal := GVL_IHM.TranslationM3.Bypass.Global;
END_IF;
IF GVL_IHM.M1TreuilRetenue.Bypass.Global <> BypassWinchM1Global THEN
    BypassWinchM1Global := GVL_IHM.M1TreuilRetenue.Bypass.Global;
END_IF;
IF GVL_IHM.M2TreuilBenne.Bypass.Global <> BypassWinchM2Global THEN
    BypassWinchM2Global := GVL_IHM.M2TreuilBenne.Bypass.Global;
END_IF;


// ── 3. CALCULS ET ÉTATS COMMUNS POUR L'IHM ────────────────────────────────
// 🔧 REX 2026-07-07 : plus de garde Mode=SEMI_AUTO, cohérent avec PRG_06_WinchControl.st §5
// (la limite légale s'applique désormais dans tous les modes dès qu'elle est activée).
GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)));

GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_00_Inputs.TopPositionSensor;


// ── 4. BYPASS DE SIMULATION POUR L'IHM (état effectif par device, voir DOC/AF_Partie-13_Fonction_Simulation_v2.0.md) ──────
// 📄 Lot L6 : Ré-alimentation des miroirs IHM depuis l'état effectif de simulation (SimulationModeActive AND Sim<Domaine>Active)
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
GVL_IHM.Commun.Bypass.SlackCable                 := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.Bypass.TopPositionSensor          := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;


// ── 5. MAPPING ÉTATS TREUIL M1 → IHM ─────────────────────────────────────
GVL_IHM.M1TreuilRetenue.State.Position_M                 := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.Commun.Preflight.PreflightOk := PRG_11_Troubleshooting.instPreflight.PreflightOk;
GVL_IHM.Commun.Preflight.PreflightDone := PRG_11_Troubleshooting.instPreflight.PreflightDone;
GVL_IHM.Commun.Preflight.PreflightErrorId := PRG_11_Troubleshooting.instPreflight.PreflightErrorId;
GVL_IHM.Commun.WinchSymmetry.SymmetryOk := PRG_11_Troubleshooting.instWinchSymmetry.SymmetryOk;
GVL_IHM.Commun.WinchSymmetry.SymmetryValid := PRG_11_Troubleshooting.instWinchSymmetry.SymmetryValid;
GVL_IHM.Commun.WinchSymmetry.DeltaStartDelay_Ms := _WinchSymmetryDataPersist.DeltaStartDelay_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaBrakeReleaseTime_Ms := _WinchSymmetryDataPersist.DeltaBrakeReleaseTime_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaBrakeApplyTime_Ms := _WinchSymmetryDataPersist.DeltaBrakeApplyTime_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaStopDistance_M := UDINT_TO_REAL(_WinchSymmetryDataPersist.DeltaStopDistance_Mm) / 1000.0;
GVL_IHM.Commun.WinchSymmetry.DeltaStopTime_Ms := _WinchSymmetryDataPersist.DeltaStopTime_Ms;
GVL_IHM.Commun.WinchSymmetry.MaxSyncDeviation_M := _WinchSymmetryDataPersist.MaxSyncDeviation_M;
GVL_IHM.M1TreuilRetenue.State.MeasuredSpeed_Mps          := PRG_02_Encoders.M1MeasuredSpeed_Mps;
GVL_IHM.M1TreuilRetenue.State.SpeedDelta_Mps             := PRG_03_Safety.instSpeedMonitorM1.SpeedDeltaMps;
GVL_IHM.M1TreuilRetenue.State.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationDetected;
GVL_IHM.M1TreuilRetenue.State.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationConfirmed;
GVL_IHM.M1TreuilRetenue.State.SpeedStable             := PRG_03_Safety.instSpeedMonitorM1.SpeedStable;
GVL_IHM.M1TreuilRetenue.State.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM1.Error;
GVL_IHM.M1TreuilRetenue.State.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.EstimatedLoadPct          := PRG_03_Safety.instLoadEstimatorM1.EstimatedLoadPct;
GVL_IHM.M1TreuilRetenue.State.SpeedRef_Pct               := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current;
GVL_IHM.M1TreuilRetenue.State.StepNumber               := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_IHM.M1TreuilRetenue.State.FBState                  := PRG_06_WinchControl.instWinchM1.State;
GVL_IHM.M1TreuilRetenue.State.Ready                    := PRG_06_WinchControl.instWinchM1.Ready;
GVL_IHM.M1TreuilRetenue.State.Busy                     := PRG_06_WinchControl.instWinchM1.Busy;
GVL_IHM.M1TreuilRetenue.State.Done                     := PRG_06_WinchControl.instWinchM1.Done;
GVL_IHM.M1TreuilRetenue.State.Error                    := PRG_06_WinchControl.instWinchM1.Error;
GVL_IHM.M1TreuilRetenue.State.ErrorId                  := PRG_06_WinchControl.instWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.RelayFwd                 := PRG_06_WinchControl.instWinchM1.RelayFwd;
GVL_IHM.M1TreuilRetenue.State.RelayRev                 := PRG_06_WinchControl.instWinchM1.RelayRev;
GVL_IHM.M1TreuilRetenue.State.Contactor1               := PRG_06_WinchControl.instWinchM1.Contactor1;
GVL_IHM.M1TreuilRetenue.State.Contactor2               := PRG_06_WinchControl.instWinchM1.Contactor2;
GVL_IHM.M1TreuilRetenue.State.Contactor3               := PRG_06_WinchControl.instWinchM1.Contactor3;
GVL_IHM.M1TreuilRetenue.State.Contactor4               := PRG_06_WinchControl.instWinchM1.Contactor4;
GVL_IHM.M1TreuilRetenue.State.BrakeCmd                 := GVL_Global.instWinchOutputInterlockM1_LD.BrakeCmd;
GVL_IHM.M1TreuilRetenue.State.FinalInterlockState      := GVL_Global.instWinchOutputInterlockM1_LD.State;
GVL_IHM.M1TreuilRetenue.State.FinalInterlockReason     := GVL_Global.instWinchOutputInterlockM1_LD.Reason;
GVL_IHM.M1TreuilRetenue.State.FinalInterlockError      := GVL_Global.instWinchOutputInterlockM1_LD.Error;
GVL_IHM.M1TreuilRetenue.State.FinalInterlockErrorId    := GVL_Global.instWinchOutputInterlockM1_LD.ErrorId;
GVL_IHM.M1TreuilRetenue.State.FinalRestartInhibit      := GVL_Global.instWinchOutputInterlockM1_LD.RestartInhibit;
GVL_IHM.M1TreuilRetenue.State.BrakeCommandOpenConfirmed := PRG_00_Inputs.M1BrakeCommandOpenConfirmed;
GVL_IHM.M1TreuilRetenue.State.FinalRestartDelayElapsed := PRG_10_Outputs_LD.instWinchOutputInterlockM1_LD.RestartDelayElapsed;
GVL_IHM.M1TreuilRetenue.State.FinalStepDelayElapsed    := PRG_10_Outputs_LD.instWinchOutputInterlockM1_LD.StepDelayElapsed;
GVL_IHM.M1TreuilRetenue.State.Homed                    := PRG_02_Encoders.instHomingM1.Homed;
GVL_IHM.M1TreuilRetenue.State.HomingBusy              := PRG_02_Encoders.instHomingM1.Busy;
GVL_IHM.M1TreuilRetenue.State.HomingDone              := PRG_02_Encoders.instHomingM1.Done;
GVL_IHM.M1TreuilRetenue.State.HomingError             := PRG_02_Encoders.instHomingM1.Error;
GVL_IHM.M1TreuilRetenue.State.HomingErrorId           := PRG_02_Encoders.instHomingM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.HomingState             := PRG_02_Encoders.instHomingM1.State;
GVL_IHM.M1TreuilRetenue.State.HomingStateAtError      := PRG_02_Encoders.instHomingM1.StateAtError;
GVL_IHM.M1TreuilRetenue.State.HomingSuspect            := PRG_02_Encoders.instHomingM1.HomingSuspect;
GVL_IHM.M1TreuilRetenue.State.HomingRefRaw             := PRG_02_Encoders.instHomingM1.HomingRefRaw;
GVL_IHM.M1TreuilRetenue.Safety.SafeStop          := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_IHM.M1TreuilRetenue.Safety.ForbidDescent     := PRG_06_WinchControl.ForbidDescentM1_Active;
GVL_IHM.M1TreuilRetenue.Safety.ForbidAscent      := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_IHM.M1TreuilRetenue.Safety.SlackCable        := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M1TreuilRetenue.Safety.ThermalFault      := NOT PRG_00_Inputs.M1ThermalFeedback;
GVL_IHM.M1TreuilRetenue.Safety.EncoderFault      := (NOT PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM1.EncoderIncoherent)
                                                  AND NOT GVL_IHM.M1TreuilRetenue.Bypass.Global
                                                  AND NOT GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault;
GVL_IHM.M1TreuilRetenue.Safety.BypassActive      := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault
                                                     AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2);
GVL_IHM.M1TreuilRetenue.Safety.CableLimitDescent := (PRG_03_Safety.instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent  := PRG_06_WinchControl.CableLimitAscentM1Reached;
GVL_IHM.M1TreuilRetenue.State.ContactorsCheck          := PRG_06_WinchControl.instWinchM1.ContactorsCheck;
GVL_IHM.M1TreuilRetenue.State.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM1.BrakeContactorCheck;

GVL_IHM.M1TreuilRetenue.State.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM1.RawPos;
GVL_IHM.M1TreuilRetenue.State.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM1.AlarmsIn;
GVL_IHM.M1TreuilRetenue.State.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM1.WarningsIn;
GVL_IHM.M1TreuilRetenue.State.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM1.SlaveOperational;
GVL_IHM.M1TreuilRetenue.State.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.M1TreuilRetenue.State.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM1.PresetValueOut;
GVL_IHM.M1TreuilRetenue.State.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM1.Error;
GVL_IHM.M1TreuilRetenue.State.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM1.ErrorId;
GVL_IHM.M1TreuilRetenue.Safety.Error             := PRG_03_Safety.instSafetyWinchM1.Error;
GVL_IHM.M1TreuilRetenue.Safety.ErrorId           := PRG_03_Safety.instSafetyWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.Safety.MecaADrift_M      := PRG_03_Safety.instSafetyWinchM1.MecaADriftM;
GVL_IHM.M1TreuilRetenue.Safety.MecaCDrift_M      := PRG_03_Safety.instSafetyWinchM1.MecaCDriftM;
GVL_IHM.M1TreuilRetenue.Safety.MecaBElapsedTime  := PRG_03_Safety.instSafetyWinchM1.MecaBElapsedTime;
GVL_IHM.M1TreuilRetenue.State.InhibitActive            := PRG_04_Modes.instModes.InhibitM1; // 🆕 REX 2026-07-08


// ── 6. MAPPING ÉTATS TREUIL M2 → IHM ─────────────────────────────────────
GVL_IHM.M2TreuilBenne.State.Position_M                 := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.M2TreuilBenne.State.MeasuredSpeed_Mps          := PRG_02_Encoders.M2MeasuredSpeed_Mps;
GVL_IHM.M2TreuilBenne.State.SpeedDelta_Mps             := PRG_03_Safety.instSpeedMonitorM2.SpeedDeltaMps;
GVL_IHM.M2TreuilBenne.State.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationDetected;
GVL_IHM.M2TreuilBenne.State.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationConfirmed;
GVL_IHM.M2TreuilBenne.State.SpeedStable             := PRG_03_Safety.instSpeedMonitorM2.SpeedStable;
GVL_IHM.M2TreuilBenne.State.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM2.Error;
GVL_IHM.M2TreuilBenne.State.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.EstimatedLoadPct          := PRG_03_Safety.instLoadEstimatorM2.EstimatedLoadPct;
GVL_IHM.M2TreuilBenne.State.SpeedRef_Pct               := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current;
GVL_IHM.M2TreuilBenne.State.StepNumber               := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_IHM.M2TreuilBenne.State.FBState                  := PRG_06_WinchControl.instWinchM2.State;
GVL_IHM.M2TreuilBenne.State.Ready                    := PRG_06_WinchControl.instWinchM2.Ready;
GVL_IHM.M2TreuilBenne.State.Busy                     := PRG_06_WinchControl.instWinchM2.Busy;
GVL_IHM.M2TreuilBenne.State.Done                     := PRG_06_WinchControl.instWinchM2.Done;
GVL_IHM.M2TreuilBenne.State.Error                    := PRG_06_WinchControl.instWinchM2.Error;
GVL_IHM.M2TreuilBenne.State.ErrorId                  := PRG_06_WinchControl.instWinchM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.RelayFwd                 := PRG_06_WinchControl.instWinchM2.RelayFwd;
GVL_IHM.M2TreuilBenne.State.RelayRev                 := PRG_06_WinchControl.instWinchM2.RelayRev;
GVL_IHM.M2TreuilBenne.State.Contactor1               := PRG_06_WinchControl.instWinchM2.Contactor1;
GVL_IHM.M2TreuilBenne.State.Contactor2               := PRG_06_WinchControl.instWinchM2.Contactor2;
GVL_IHM.M2TreuilBenne.State.Contactor3               := PRG_06_WinchControl.instWinchM2.Contactor3;
GVL_IHM.M2TreuilBenne.State.Contactor4               := PRG_06_WinchControl.instWinchM2.Contactor4;
GVL_IHM.M2TreuilBenne.State.BrakeCmd                 := GVL_Global.instWinchOutputInterlockM2_LD.BrakeCmd;
GVL_IHM.M2TreuilBenne.State.FinalInterlockState      := GVL_Global.instWinchOutputInterlockM2_LD.State;
GVL_IHM.M2TreuilBenne.State.FinalInterlockReason     := GVL_Global.instWinchOutputInterlockM2_LD.Reason;
GVL_IHM.M2TreuilBenne.State.FinalInterlockError      := GVL_Global.instWinchOutputInterlockM2_LD.Error;
GVL_IHM.M2TreuilBenne.State.FinalInterlockErrorId    := GVL_Global.instWinchOutputInterlockM2_LD.ErrorId;
GVL_IHM.M2TreuilBenne.State.FinalRestartInhibit      := GVL_Global.instWinchOutputInterlockM2_LD.RestartInhibit;
GVL_IHM.M2TreuilBenne.State.BrakeCommandOpenConfirmed := PRG_00_Inputs.M2BrakeCommandOpenConfirmed;
GVL_IHM.M2TreuilBenne.State.FinalAuthorizedStep      := GVL_Global.instWinchOutputInterlockM2_LD.AuthorizedStep;
GVL_IHM.M2TreuilBenne.State.FinalBrakeTimeoutElapsed := GVL_Global.instWinchOutputInterlockM2_LD.BrakeTimeoutElapsed;
GVL_IHM.M2TreuilBenne.State.FinalRestartDelayElapsed := GVL_Global.instWinchOutputInterlockM2_LD.RestartDelayElapsed;
GVL_IHM.M2TreuilBenne.State.FinalStepDelayElapsed    := GVL_Global.instWinchOutputInterlockM2_LD.StepDelayElapsed;
GVL_IHM.M2TreuilBenne.State.Homed                    := PRG_02_Encoders.instHomingM2.Homed;
GVL_IHM.M2TreuilBenne.State.HomingBusy              := PRG_02_Encoders.instHomingM2.Busy;
GVL_IHM.M2TreuilBenne.State.HomingDone              := PRG_02_Encoders.instHomingM2.Done;
GVL_IHM.M2TreuilBenne.State.HomingError             := PRG_02_Encoders.instHomingM2.Error;
GVL_IHM.M2TreuilBenne.State.HomingErrorId           := PRG_02_Encoders.instHomingM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.HomingState             := PRG_02_Encoders.instHomingM2.State;
GVL_IHM.M2TreuilBenne.State.HomingStateAtError      := PRG_02_Encoders.instHomingM2.StateAtError;
GVL_IHM.M2TreuilBenne.State.HomingSuspect            := PRG_02_Encoders.instHomingM2.HomingSuspect;
GVL_IHM.M2TreuilBenne.State.HomingRefRaw             := PRG_02_Encoders.instHomingM2.HomingRefRaw;
GVL_IHM.M2TreuilBenne.Safety.SafeStop          := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_IHM.M2TreuilBenne.Safety.ForbidDescent     := PRG_06_WinchControl.ForbidDescentM2_Active;
GVL_IHM.M2TreuilBenne.Safety.ForbidAscent      := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_IHM.M2TreuilBenne.Safety.SlackCable        := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M2TreuilBenne.Safety.ThermalFault      := NOT PRG_00_Inputs.M2ThermalFeedback;
GVL_IHM.M2TreuilBenne.Safety.EncoderFault      := (NOT PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM2.EncoderIncoherent)
                                                  AND NOT GVL_IHM.M2TreuilBenne.Bypass.Global
                                                  AND NOT GVL_IHM.M2TreuilBenne.Bypass.EncoderFault;
GVL_IHM.M2TreuilBenne.Safety.BypassActive      := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault
                                                     AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2);
GVL_IHM.M2TreuilBenne.Safety.CableLimitDescent := (PRG_03_Safety.instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent  := PRG_06_WinchControl.CableLimitAscentM2Reached;
GVL_IHM.M2TreuilBenne.State.ContactorsCheck          := PRG_06_WinchControl.instWinchM2.ContactorsCheck;
GVL_IHM.M2TreuilBenne.State.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM2.BrakeContactorCheck;

GVL_IHM.M2TreuilBenne.State.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM2.RawPos;
GVL_IHM.M2TreuilBenne.State.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM2.AlarmsIn;
GVL_IHM.M2TreuilBenne.State.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM2.WarningsIn;
GVL_IHM.M2TreuilBenne.State.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM2.SlaveOperational;
GVL_IHM.M2TreuilBenne.State.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.M2TreuilBenne.State.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM2.PresetValueOut;
GVL_IHM.M2TreuilBenne.State.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM2.Error;
GVL_IHM.M2TreuilBenne.State.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM2.ErrorId;
GVL_IHM.M2TreuilBenne.Safety.Error             := PRG_03_Safety.instSafetyWinchM2.Error;
GVL_IHM.M2TreuilBenne.Safety.ErrorId           := PRG_03_Safety.instSafetyWinchM2.ErrorId;
GVL_IHM.M2TreuilBenne.Safety.MecaADrift_M      := PRG_03_Safety.instSafetyWinchM2.MecaADriftM;
GVL_IHM.M2TreuilBenne.Safety.MecaCDrift_M      := PRG_03_Safety.instSafetyWinchM2.MecaCDriftM;
GVL_IHM.M2TreuilBenne.Safety.MecaBElapsedTime  := PRG_03_Safety.instSafetyWinchM2.MecaBElapsedTime;
GVL_IHM.M2TreuilBenne.State.InhibitActive            := PRG_04_Modes.instModes.InhibitM2; // 🆕 REX 2026-07-08


// ── 7. MAPPING ÉTATS BENNE → IHM ───────────────────────────────────────
GVL_IHM.M2TreuilBenne.Bucket.State.FBState          := PRG_06_WinchControl.instBucket.State;
GVL_IHM.M2TreuilBenne.Bucket.State.ActiveOffset_M   := PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2TreuilBenne.Bucket.State.M2StartStop      := PRG_06_WinchControl.instBucket.M2_StartStop;
GVL_IHM.M2TreuilBenne.Bucket.State.M2Direction      := PRG_06_WinchControl.instBucket.M2_Direction;
GVL_IHM.M2TreuilBenne.Bucket.State.M2ForceSlowSpeed := PRG_06_WinchControl.instBucket.M2_ForceSlowSpeed;
GVL_IHM.M2TreuilBenne.Bucket.State.Ready            := PRG_06_WinchControl.instBucket.Ready;
GVL_IHM.M2TreuilBenne.Bucket.State.Busy             := PRG_06_WinchControl.instBucket.Busy;
GVL_IHM.M2TreuilBenne.Bucket.State.Done             := PRG_06_WinchControl.instBucket.Done;
GVL_IHM.M2TreuilBenne.Bucket.State.Error            := PRG_06_WinchControl.instBucket.Error;
GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId          := PRG_06_WinchControl.instBucket.ErrorId;
GVL_IHM.M2TreuilBenne.Bucket.State.RemainingTravel_M:= PRG_06_WinchControl.instBucket.RemainingTravelM;
GVL_IHM.M2TreuilBenne.Bucket.State.CloseActive      := PRG_06_WinchControl.instBucket.CloseReq; // 🆕 REX 2026-07-08
GVL_IHM.M2TreuilBenne.Bucket.State.OpenActive       := PRG_06_WinchControl.instBucket.OpenReq;  // 🆕 REX 2026-07-08
// 📊 REX 2026-07-07 : position M2 corrigée de l'offset actif — affichage bargraphe uniquement,
// doit être égale à GVL_IHM.M1TreuilRetenue.Position_M quand tout est nominal (voir bandeau ST_BucketHMI).
GVL_IHM.M2TreuilBenne.Bucket.State.M2PositionCorrected := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2TreuilBenne.Bucket.State.MechState        := _BucketState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.M1M2Sync.State.DeltaPos_M   := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.M1M2Sync.State.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
GVL_IHM.M1M2Sync.State.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.M1M2Sync.State.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
GVL_IHM.M1M2Sync.State.Error      := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.M1M2Sync.State.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
GVL_IHM.M1M2Sync.State.FBState    := PRG_06_WinchControl.instWinchSync.State;


// ── 9. MAPPING ÉTATS TRANSLATION M3 → IHM ────────────────────────────────────
GVL_IHM.TranslationM3.State.FBState              := PRG_07_TranslationControl.instTranslationM3.State;
GVL_IHM.TranslationM3.State.Ready                := PRG_07_TranslationControl.instTranslationM3.Ready;
GVL_IHM.TranslationM3.State.Busy                 := PRG_07_TranslationControl.instTranslationM3.Busy;
GVL_IHM.TranslationM3.State.Done                 := PRG_07_TranslationControl.instTranslationM3.Done;
GVL_IHM.TranslationM3.State.Error                := PRG_07_TranslationControl.instTranslationM3.Error;
GVL_IHM.TranslationM3.State.ErrorId              := PRG_07_TranslationControl.instTranslationM3.ErrorId;
GVL_IHM.TranslationM3.State.BrakeCmd             := GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd;
GVL_IHM.TranslationM3.State.FinalInterlockState  := GVL_Global.instTranslationOutputInterlock_LD.State;
GVL_IHM.TranslationM3.State.FinalInterlockReason := GVL_Global.instTranslationOutputInterlock_LD.Reason;
GVL_IHM.TranslationM3.State.FinalInterlockError  := GVL_Global.instTranslationOutputInterlock_LD.Error;
GVL_IHM.TranslationM3.State.FinalInterlockErrorId := GVL_Global.instTranslationOutputInterlock_LD.ErrorId;
GVL_IHM.TranslationM3.State.BrakeCommandOpenConfirmed := PRG_00_Inputs.M3BrakeCommandOpenConfirmed;
GVL_IHM.TranslationM3.State.FinalBrakeTimeoutElapsed := GVL_Global.instTranslationOutputInterlock_LD.BrakeTimeoutElapsed;
GVL_IHM.TranslationM3.State.BrakeFeedback        := PRG_00_Inputs.M3BrakeFeedback;
GVL_IHM.TranslationM3.State.PositionSensorTarget := PRG_07_TranslationControl.M3_PositionSensorTarget;
GVL_IHM.TranslationM3.State.PositionReached      := PRG_07_TranslationControl.M3_PositioningActive
                                                AND PRG_07_TranslationControl.instTranslationM3.TargetReached;
GVL_IHM.TranslationM3.State.JoystickDeflection_Pct := PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef;
// 🧭 Position validée IHM : masquée (forcée à FALSE) si le mot capteurs est incohérent (position indéterminée)
IF PRG_00_Inputs.instPositionDecoder.Incoherent THEN
    GVL_IHM.TranslationM3.State.PositionTremie      := FALSE;
    GVL_IHM.TranslationM3.State.PositionPV          := FALSE;
    GVL_IHM.TranslationM3.State.PositionP2          := FALSE;
    GVL_IHM.TranslationM3.State.PositionP1          := FALSE;
    GVL_IHM.TranslationM3.State.PositionMaintenance := FALSE;
ELSE
    GVL_IHM.TranslationM3.State.PositionTremie      := PRG_00_Inputs.TranslationPosTremie;
    GVL_IHM.TranslationM3.State.PositionPV          := PRG_00_Inputs.TranslationPosPV;
    GVL_IHM.TranslationM3.State.PositionP2          := PRG_00_Inputs.TranslationPosP2;
    GVL_IHM.TranslationM3.State.PositionP1          := PRG_00_Inputs.TranslationPosP1;
    GVL_IHM.TranslationM3.State.PositionMaintenance := PRG_00_Inputs.TranslationPosMaintenance;
END_IF;
GVL_IHM.TranslationM3.State.SensorsWord         := PRG_00_Inputs.instPositionDecoder.SensorsWord;
GVL_IHM.TranslationM3.State.SensorWordIncoherent:= PRG_00_Inputs.instPositionDecoder.Incoherent;
GVL_IHM.TranslationM3.State.LimitSwitchFwd     := PRG_00_Inputs.instPositionDecoder.LimitSwitchFwd;
GVL_IHM.TranslationM3.State.LimitSwitchRev     := PRG_00_Inputs.instPositionDecoder.LimitSwitchRev;
GVL_IHM.TranslationM3.State.MaintenanceTargetEnable := PRG_04_Modes.instModes.MaintenanceM3TargetEnable;
GVL_IHM.TranslationM3.State.SimulationModeActive := GVL_Simulation.SimulationModeActive;

GVL_IHM.TranslationM3.Safety.Error             := PRG_03_Safety.instSafetyTranslationM3.Error;
GVL_IHM.TranslationM3.Safety.ErrorId           := PRG_03_Safety.instSafetyTranslationM3.ErrorId;
GVL_IHM.TranslationM3.Safety.ErrorOperatorComm := PRG_03_Safety.instSafetyTranslationM3.ErrorOperatorComm;
GVL_IHM.TranslationM3.Safety.ErrorDriveComm      := PRG_03_Safety.instSafetyTranslationM3.ErrorDriveComm;
GVL_IHM.TranslationM3.Safety.ErrorPhaseRotation  := PRG_03_Safety.instSafetyTranslationM3.ErrorPhaseRotation;
GVL_IHM.TranslationM3.Safety.ErrorBrakeThermal   := PRG_03_Safety.instSafetyTranslationM3.ErrorBrakeThermal;
GVL_IHM.TranslationM3.Safety.ErrorMecaB          := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaB;
GVL_IHM.TranslationM3.Safety.ErrorMecaA          := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaA;
GVL_IHM.TranslationM3.Safety.ErrorLimitSwitch    := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_IHM.TranslationM3.Safety.ErrorSensorIncoherent:= PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;
GVL_IHM.TranslationM3.Safety.SafeStop          := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_IHM.TranslationM3.Safety.PowerCutOff       := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;

GVL_IHM.TranslationM3.State.DriveCommReady       := PRG_00_Inputs.M3_StatusWord_Filtered.7;
GVL_IHM.TranslationM3.State.DrivePowerReady      := PRG_00_Inputs.M3_StatusWord_Filtered.0;
// 🔧 Source unique (PRG_00_Inputs), valable Auto ET Manu — remplace l'ex-doublon IHM_MANU.M3_FreqActual
GVL_IHM.TranslationM3.State.DriveActualFreq_Hz     := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_IHM.TranslationM3.State.DriveFreqRef_Hz        := GVL_Global.instTranslationOutputInterlock_LD.DriveFreqRefHz;
GVL_IHM.TranslationM3.State.DriveControlWord       := GVL_Global.instTranslationOutputInterlock_LD.DriveControlWord;
GVL_IHM.TranslationM3.State.ActiveDirection      := PRG_07_TranslationControl.M3_Direction_Active;
GVL_IHM.TranslationM3.State.ActiveSpeedRef_Pct     := PRG_07_TranslationControl.M3_SpeedRef_Active;

// ── 9bis. MAPPING ASSISTANCE PRÉLÈVEMENT → IHM ─────────────────────────────
GVL_IHM.DredgingAssist.State.DiveReady := PRG_06_WinchControl.instDiveSearch.Ready;
GVL_IHM.DredgingAssist.State.DiveBusy := PRG_06_WinchControl.instDiveSearch.Busy;
GVL_IHM.DredgingAssist.State.DiveDone := PRG_06_WinchControl.instDiveSearch.Done;
GVL_IHM.DredgingAssist.State.DiveError := PRG_06_WinchControl.instDiveSearch.Error;
GVL_IHM.DredgingAssist.State.DiveErrorId := PRG_06_WinchControl.instDiveSearch.ErrorId;
GVL_IHM.DredgingAssist.State.DiveState := PRG_06_WinchControl.instDiveSearch.DiveState;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed := PRG_06_WinchControl.instDiveSearch.BottomTouchConfirmed;
GVL_IHM.DredgingAssist.State.ExtractionReady := PRG_06_WinchControl.instExtractionSequence.Ready;
GVL_IHM.DredgingAssist.State.ExtractionBusy := PRG_06_WinchControl.instExtractionSequence.Busy;
GVL_IHM.DredgingAssist.State.ExtractionDone := PRG_06_WinchControl.instExtractionSequence.Done;
GVL_IHM.DredgingAssist.State.ExtractionError := PRG_06_WinchControl.instExtractionSequence.Error;
GVL_IHM.DredgingAssist.State.ExtractionErrorId := PRG_06_WinchControl.instExtractionSequence.ErrorId;
GVL_IHM.DredgingAssist.State.ExtractionState := PRG_06_WinchControl.instExtractionSequence.ExtractionState;

// 🎮 Une seule consigne opérateur : l'assistant qui attend/agit a priorité sur le cycle.
IF PRG_06_WinchControl.instExtractionSequence.Busy
   OR PRG_06_WinchControl.instExtractionSequence.Ready
   OR (NOT GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence) THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := PRG_06_WinchControl.instExtractionSequence.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction := PRG_06_WinchControl.instExtractionSequence.OperatorAction;
ELSIF PRG_06_WinchControl.instDiveSearch.Busy
   OR PRG_06_WinchControl.instDiveSearch.Ready
   OR GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := PRG_06_WinchControl.instDiveSearch.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction := PRG_06_WinchControl.instDiveSearch.OperatorAction;
ELSE
    GVL_IHM.DredgingAssist.State.OperatorActionId := 0;
    GVL_IHM.DredgingAssist.State.OperatorAction := '';
END_IF;

// 🎮 Publication de l'unique consigne de conduite. Aucun FB n'écrit directement ce champ IHM.
GVL_IHM.OperatorAction.ActionId := GVL_IHM.DredgingAssist.State.OperatorActionId;
GVL_IHM.OperatorAction.Text := GVL_IHM.DredgingAssist.State.OperatorAction;

// ── 9ter. MAPPING CYCLE SEMI-AUTOMATIQUE → IHM ─────────────────────────────
GVL_IHM.Cycle.State.Ready                := PRG_05_Cycle.instCycle.Ready;
GVL_IHM.Cycle.State.Busy                 := PRG_05_Cycle.instCycle.Busy;
GVL_IHM.Cycle.State.Done                 := PRG_05_Cycle.instCycle.Done;
GVL_IHM.Cycle.State.Error                := PRG_05_Cycle.instCycle.Error;
GVL_IHM.Cycle.State.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
GVL_IHM.Cycle.State.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
GVL_IHM.Cycle.State.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
GVL_IHM.Cycle.State.SelTarget            := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.State.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
GVL_IHM.Cycle.State.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
GVL_IHM.Cycle.State.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.State.LimitLegalDepth_M    := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.State.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Cycle.State.WinchSyncDelta_M     := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Cycle.State.M1Position_M         := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.Cycle.State.M2Position_M         := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.Cycle.State.DeadmanArmed         := PRG_01_Diagnostics.instJoystick.DeadmanArmed;
GVL_IHM.Cycle.State.JoystickMotionActive := PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop;
GVL_IHM.Cycle.State.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.JOY1Joystick.State.RawX         := PRG_01_Diagnostics.instJoystick.RawX;
GVL_IHM.JOY1Joystick.State.RawY         := PRG_01_Diagnostics.instJoystick.RawY;
GVL_IHM.JOY1Joystick.State.RawButton    := PRG_01_Diagnostics.instJoystick.RawButton;
GVL_IHM.JOY1Joystick.State.AxisCmdX     := PRG_01_Diagnostics.instJoystick.AxisCmdX;
GVL_IHM.JOY1Joystick.State.AxisCmdY     := PRG_01_Diagnostics.instJoystick.AxisCmdY;
GVL_IHM.JOY1Joystick.State.NeutralXAct  := PRG_01_Diagnostics.instJoystick.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct  := PRG_01_Diagnostics.instJoystick.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_01_Diagnostics.instJoystick.DeadmanArmed;
GVL_IHM.JOY1Joystick.State.Online       := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JOY1Joystick.State.Operational  := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JOY1Joystick.State.Error        := PRG_01_Diagnostics.instJoystick.Error;
GVL_IHM.JOY1Joystick.State.ErrorId      := PRG_01_Diagnostics.instJoystick.ErrorId;


// ── 11. MAPPING SYSTEM / MODE → IHM ──────────────────────────────────────
GVL_IHM.Modes.State.CurrentMode     := PRG_04_Modes.instModes.Mode;
GVL_IHM.Modes.State.PowerContactorEngaged := PRG_00_Inputs.PowerContactorEngaged;

// 🆕 Bus State/Diag Emergency → ST_ModesState (AF01 §6)
GVL_IHM.Modes.State.EmergencyChainOk      := PRG_10_Outputs_LD.instSafetyEmergencyManagement.State.ChainOk;
GVL_IHM.Modes.State.PowerContactorOk      := PRG_10_Outputs_LD.instSafetyEmergencyManagement.State.ContactorOk;
GVL_IHM.Modes.State.EmergencyArmable      := PRG_10_Outputs_LD.instSafetyEmergencyManagement.State.Armable;
GVL_IHM.Modes.State.EmergencyArmingBusy   := PRG_10_Outputs_LD.instSafetyEmergencyManagement.State.ArmingBusy;
GVL_IHM.Modes.State.RedundancyTestFailed  := PRG_10_Outputs_LD.instSafetyEmergencyManagement.Diag.RedundancyTestFailed;
GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_10_Outputs_LD.instSafetyEmergencyManagement.Diag.ArmFailed;
GVL_IHM.Modes.State.PowerCutOffActive     := (PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                                               OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                                               OR PRG_03_Safety.instSafetyTranslationM3.PowerCutOff);


// ── 12. MAPPING DIAGNOSTICS BUS → IHM ────────────────────────────────────
GVL_IHM.Network.BusCanOpen  := PRG_01_Diagnostics.instDiagCanOpen.DeviceCanOpenMaster;
GVL_IHM.Network.Joystick    := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick;
GVL_IHM.Network.CanError    := PRG_01_Diagnostics.instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := PRG_01_Diagnostics.instDiagCanOpen.ErrorId;

GVL_IHM.Network.BusEthercat := PRG_01_Diagnostics.instDiagEthercat.DeviceEthercatMaster;
GVL_IHM.Network.EncoderM1   := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1;
GVL_IHM.Network.EncoderM2   := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2;
GVL_IHM.Network.VariateurM3 := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur;
GVL_IHM.Network.EcatError   := PRG_01_Diagnostics.instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := PRG_01_Diagnostics.instDiagEthercat.ErrorId;

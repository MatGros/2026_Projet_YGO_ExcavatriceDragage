# Carte de flux M1

> Généré depuis `CODE/`. Chaîne, `fichier:ligne` et code cité : extraction mécanique. Colonnes de lecture : rédigées puis à relire. Aucune preuve sur automate.

**Couverture :** 1171 variables dans le graphe, 821 maillons d'interface annotés, 166 points d'entrée reliés à une sortie, 0 maillon de chemin non annoté.

**Statuts :** {'A CONTROLER': 49, 'LISIBLE?': 594, 'VISIBLE': 178}. `VISIBLE` = chemin du snapshot ou copie directe. `LISIBLE?` = variable existante, lecture directe à confirmer sur automate.

## 1. Référentiel

### Actionneurs (7)

- `PRG_06_Outputs.M1_BrakeRelease_RQ`
- `PRG_06_Outputs.M1_RelayAscent_RQ`
- `PRG_06_Outputs.M1_RelayDescent_RQ`
- `PRG_06_Outputs.M1_SpeedContactor_1_DQ`
- `PRG_06_Outputs.M1_SpeedContactor_2_DQ`
- `PRG_06_Outputs.M1_SpeedContactor_3_DQ`
- `PRG_06_Outputs.M1_SpeedContactor_4_DQ`

### Commandes atteintes (17)

- `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — non visible
- `GVL_IHM.JOY1Joystick.Cmd.Calibrate` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent` — VISIBLE
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent` — VISIBLE
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnHome` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose` — VISIBLE
- `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen` — VISIBLE
- `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — non visible
- `GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease` — non visible
- `GVL_IHM.MaintenanceN2.Cmd.BtnM1BrakeRelease` — non visible
- `GVL_IHM.Modes.Cmd.BtnFaultReset` — non visible
- `GVL_IHM.Modes.Cmd.TglJoystickMaster` — VISIBLE

### Réglages (75)

- `GVL_IHM.Commun.Cfg.Initialized`
- `GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M`
- `GVL_IHM.Commun.Cfg.LimitLegalEnabled`
- `GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent`
- `GVL_IHM.Commun.TglHeartbeatIhm`
- `GVL_IHM.CycleSemiAuto.Cfg.ExtractionControlDistance_M`
- `GVL_IHM.CycleSemiAuto.Cfg.ImmersionLower_M`
- `GVL_IHM.CycleSemiAuto.Cfg.ImmersionUpper_M`
- `GVL_IHM.CycleSemiAuto.Cfg.Initialized`
- `GVL_PERSISTENT._JoystickCfgPersist.DeadbandRaw`
- `GVL_PERSISTENT._JoystickCfgPersist.DeadmanArmHoldTime`
- `GVL_PERSISTENT._JoystickCfgPersist.RawOutOfRangeMargin`
- `PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M`
- `PRG_02_Acquisition.instEncoderM1.Cfg.PresetConfirmMode`
- `PRG_02_Acquisition.instEncoderM1.CfgHomingTargetM`
- `PRG_02_Acquisition.instEncoderM1.CfgTopSensorPosM`
- `PRG_02_Acquisition.instEncoderM1.instHoming.Cfg.PresetConfirmMode`
- `PRG_02_Acquisition.instEncoderM1.instHoming.CfgHomingTargetM`
- `PRG_02_Acquisition.instEncoderM1.instHoming.CfgTopSensorPosM`
- `PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw`
- `PRG_02_Acquisition.instJoystick.Cfg.DeadmanArmHoldTime`
- `PRG_02_Acquisition.instJoystick.Cfg.RawOutOfRangeMargin`
- `PRG_04_Treuils_Benne._CommunCfgPersist.CfgCableLimitAscent_M`
- `PRG_04_Treuils_Benne._CommunCfgPersist.LimitLegalDepthMinAllowed_M`
- `PRG_04_Treuils_Benne._CommunCfgPersist.LimitLegalEnabled`
- `PRG_04_Treuils_Benne._CommunCfgPersist.WinchMaxStepAscent`
- `PRG_04_Treuils_Benne._CommunCfgPersist.WinchMaxStepDescent`
- `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownDistanceBottom_M`
- `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownDistanceTop_M`
- `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownMaxStep`
- `PRG_04_Treuils_Benne._SyncCfgPersist.CfgSyncTolerance_M`
- `PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgCableLimitDescent_M`
- `PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgTopSensorPos_M`
- `PRG_04_Treuils_Benne.instArbM1.TglJoystickMaster`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.CfgCableLimitDescentM`
- `PRG_04_Treuils_Benne.instWinchSync.CfgSyncToleranceM`
- `PRG_04_Treuils_Benne.instWinchSync.instDeviation.CfgSyncToleranceM`
- `PRG_06_Outputs.instM1FwdProtector.Cfg_MinInterval`
- `PRG_06_Outputs.instM1RevProtector.Cfg_MinInterval`
- `PRG_06_Outputs.instM1Sc1Protector.Cfg_MinInterval`
- `PRG_06_Outputs.instM1Sc2Protector.Cfg_MinInterval`
- `PRG_06_Outputs.instM1Sc3Protector.Cfg_MinInterval`
- `PRG_06_Outputs.instM1Sc4Protector.Cfg_MinInterval`
- `PRG_07_Supervision._CommunCfgPersist.Initialized`
- `PRG_07_Supervision._CommunCfgPersist.LimitLegalDepthMinAllowed_M`
- `PRG_07_Supervision._CommunCfgPersist.LimitLegalEnabled`
- `PRG_07_Supervision._CommunCfgPersist.TglEnableKoboldAutoStopDescent`
- `PRG_07_Supervision._CycleCfgPersist.ExtractionControlDistance_M`
- `PRG_07_Supervision._CycleCfgPersist.ImmersionLower_M`
- `PRG_07_Supervision._CycleCfgPersist.ImmersionUpper_M`
- `PRG_07_Supervision._CycleCfgPersist.Initialized`
- `PRG_07_Supervision._EncoderCfgPersist.Initialized`
- `PRG_07_Supervision._EncoderCfgPersist.PresetConfirmMode`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.LimitLegalDepthMinAllowed_M`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.LimitLegalEnabled`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.TglEnableKoboldAutoStopDescent`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.LimitLegalDepthMinAllowed_M`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.LimitLegalEnabled`
- `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.TglEnableKoboldAutoStopDescent`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ExtractionControlDistance_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ImmersionLower_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ImmersionUpper_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ExtractionControlDistance_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ImmersionLower_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ImmersionUpper_M`
- `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.PresetConfirmMode`
- `PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.Initialized`
- `PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.PresetConfirmMode`
- `PRG_07_Supervision.instCfgT330Normalizer.CommunCfg.TglEnableKoboldAutoStopDescent`
- `PRG_07_Supervision.instDiagIhmHeartbeat.TglHeartbeatIhm`

### Bypass (77)

- `GVL_IHM.Commun.Bypass.CableLimitSwitch`
- `GVL_IHM.Commun.Bypass.Initialized`
- `GVL_IHM.Commun.Bypass.LimitLegal`
- `GVL_IHM.Commun.Bypass.SlackCable`
- `GVL_IHM.Commun.Bypass.TopLimitSoftware`
- `GVL_IHM.Commun.Bypass.TopLimitSwitch`
- `GVL_IHM.M1M2Sync.Bypass.Global`
- `GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal`
- `GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch`
- `GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback`
- `GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault`
- `GVL_IHM.M1TreuilRetenue.Bypass.Global`
- `GVL_IHM.M1TreuilRetenue.Bypass.Initialized`
- `GVL_IHM.M1TreuilRetenue.Bypass.LimitLegal`
- `GVL_IHM.M1TreuilRetenue.Bypass.MecaB`
- `GVL_IHM.M1TreuilRetenue.Bypass.MecaD`
- `GVL_IHM.M1TreuilRetenue.Bypass.MecaE`
- `GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal`
- `GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm`
- `GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation`
- `GVL_IHM.M1TreuilRetenue.Bypass.Process`
- `GVL_IHM.M1TreuilRetenue.Bypass.Safety`
- `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware`
- `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch`
- `GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback`
- `GVL_IHM.M2TreuilBenne.Bypass.Global`
- `GVL_IHM.M2TreuilBenne.Bypass.Process`
- `GVL_IHM.M2TreuilBenne.Bypass.Safety`
- `GVL_IHM.Network.Bypass.BusCanOpen`
- `GVL_IHM.Network.Bypass.EncoderM1`
- `GVL_IHM.Network.Bypass.Global`
- `GVL_IHM.Network.Bypass.IhmHeartbeat`
- `GVL_IHM.Network.Bypass.Initialized`
- `GVL_IHM.Network.Bypass.InputModules`
- `GVL_IHM.Network.Bypass.Joystick`
- `PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.NetworkBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.SimBypassActive`
- `PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1SimBypass`
- `PRG_02_Acquisition.instDiagEthercat.EncoderM1Bypass`
- `PRG_02_Acquisition.instDiagEthercat.EncoderM1BypassActive`
- `PRG_02_Acquisition.instDiagEthercat.NetworkBypassActive`
- `PRG_04_Treuils_Benne.BypassKoboldBottomTouched`
- `PRG_04_Treuils_Benne.BypassM1CableLimitSwitchEff`
- `PRG_04_Treuils_Benne.BypassM1LimitLegalEff`
- `PRG_04_Treuils_Benne.BypassM1MecaDEff`
- `PRG_04_Treuils_Benne.BypassM1TopLimitSoftwareEff`
- `PRG_04_Treuils_Benne.BypassM1TopLimitSwitchEff`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassBrakeThermal`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassCableLimitSwitch`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassGlobal`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassLimitLegal`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaB`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaD`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaE`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMotorThermal`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassOperatorComm`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassPhaseRotation`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassProcess`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassSafety`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassTopLimitSoftware`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassTopLimitSwitch`
- `PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderFaultBypass`
- `PRG_04_Treuils_Benne.instWinchSync.BypassGlobal`
- `PRG_04_Treuils_Benne.instWinchSync.instContactor.BypassGlobal`
- `PRG_04_Treuils_Benne.instWinchSync.instDeviation.BypassGlobal`
- `PRG_06_Outputs.instSyncContactorFinal.BypassGlobal`
- `PRG_07_Supervision.BypassCableLimitSwitch`
- `PRG_07_Supervision.BypassLimitLegal`
- `PRG_07_Supervision.BypassNetworkGlobal`
- `PRG_07_Supervision.BypassSlackCable`
- `PRG_07_Supervision.BypassTopLimitSoftware`
- `PRG_07_Supervision.BypassTopLimitSwitch`
- `PRG_07_Supervision.BypassWinchM1Global`
- `PRG_07_Supervision.PrevM1Bypass`
- `PRG_07_Supervision.PrevNetworkBypass`

### Mesures et retours physiques (43)

- `PRG_02_Acquisition.ConveyorInfeedReady_DI` — VISIBLE
- `PRG_02_Acquisition.EmergencyChainClosed_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` — VISIBLE
- `PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI` — VISIBLE
- `PRG_02_Acquisition.HwInM1.PresetStatusBit` — LISIBLE?
- `PRG_02_Acquisition.HwInM1.RawPosIn` — LISIBLE?
- `PRG_02_Acquisition.HwInM1.SpdValueIn` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Machine` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Operator.CanBusState` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Winch` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState` — LISIBLE?
- `PRG_02_Acquisition.HydraulicThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M1M2_TopPositionFree_DI` — VISIBLE
- `PRG_02_Acquisition.M1_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.M1_ContactorsReleased_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M1_ThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M2_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.M2_ContactorsReleased_DI` — VISIBLE
- `PRG_02_Acquisition.M2_TensionedCable_DI` — VISIBLE
- `PRG_02_Acquisition.M2_ThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.PhaseRotationOk_DI` — VISIBLE
- `PRG_02_Acquisition.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` — VISIBLE
- `PRG_02_Acquisition.instEncoderM1.HwIn.AlarmsIn` — LISIBLE?
- `PRG_02_Acquisition.instEncoderM1.HwIn.PresetStatusBit` — LISIBLE?
- `PRG_02_Acquisition.instEncoderM1.HwIn.RawPosIn` — LISIBLE?
- `PRG_02_Acquisition.instEncoderM1.HwIn.SlaveOperational` — LISIBLE?
- `PRG_02_Acquisition.instEncoderM1.HwIn.SpdValueIn` — LISIBLE?

## 2. Maillons par étage (de la source vers l'actionneur)

### SOURCE (53)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.ConfirmCoherence |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnHome` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.HomingAtTargetM |
| `PRG_02_Acquisition.instJoystick.ArmingPermit` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.ArmingPermit` | Entree recue depuis : PRG_04_Treuils_Benne.Data.ArmingPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.DeadmanArmTimer.Q` | LISIBLE? | `FB_Joystick.st:173 = DeadmanArmTimer(IN := FALSE, PT := Cfg.DeadmanArmHoldTime); ;; FB_Joystick.st:230 = DeadmanArmTimer(IN := DeadmanArmPending AND N` | DeadmanArmTimer actif si DeadmanArmPending et pas DeadmanArmed et ArmingPermit et pas InversionLockActive | Verifier en aval : PRG_02_Acquisition.instJoystick.DeadmanArmed, PRG_02_Acquisition.instJoystick.DeadmanArmPending |
| `PRG_02_Acquisition.instJoystick.DirectInversionPermit` | LISIBLE? | `entree liee a : GVL_IHM.CycleSemiAuto.State.CycleStep` | Entree recue depuis : GVL_IHM.CycleSemiAuto.State.CycleStep | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_Global.BlinkClock` | LISIBLE? | `PRG_07_Supervision.st:122 = GVL_Global.BlinkClock := instBlink1Hz.OUT;` | BlinkClock affecte par instBlink1Hz.OUT | verifier instBlink1Hz et ses consommateurs |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArbIHM.BtnAscentM1 |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArbIHM.BtnDescentM1 |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.CfgHomingTargetM, PRG_02_Acquisition.instEncoderM1.HomingAtZero |
| `PRG_02_Acquisition.instJoystick.DeadmanArmed` | VISIBLE | `FB_Joystick.st:165 = DeadmanArmed := FALSE; ;; FB_Joystick.st:218 = DeadmanArmed := FALSE;` | DeadmanArmed force a FALSE dans FB_Joystick | verifier les branches qui forcent FALSE et la condition d armement en aval |
| `PRG_02_Acquisition.instJoystick.RawOutOfRange` | LISIBLE? | `FB_Joystick.st:112 = RawOutOfRange := (RawX < (0 - Cfg.RawOutOfRangeMargin)) OR (RawX > (10000 + Cfg.RawOutOfRangeMargin)) OR (RawY < (0 - Cfg.RawOutO` | RawOutOfRange vrai si RawX ou RawY hors plage avec marge | verifier Cfg.RawOutOfRangeMargin et les consommateurs en aval |
| `GVL_IHM.JOY1Joystick.Cmd.Calibrate` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instJoystick.Calibrate |
| `GVL_IHM.Modes.Cmd.TglJoystickMaster` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.TglJoystickMaster |
| `PRG_02_Acquisition.instJoystick.CmdYVal` | LISIBLE? | `FB_Joystick.st:272 = CmdYVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleY.OutPct);` | CmdYVal joystick mis a 0 sauf si deadman arme et brut dans plage | Verifier en aval : PRG_02_Acquisition.instJoystick.AxisCmdY.DirectionNegative, PRG_02_Acquisition.instJoystick.AxisCmdY.DirectionPositive |
| `PRG_04_Treuils_Benne.TRUE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.Enable |
| `PRG_02_Acquisition.instJoystick.AxisCmdY.DirectionNegative` | LISIBLE? | `FB_Joystick.st:161 = AxisCmdY.DirectionPositive := FALSE; AxisCmdY.DirectionNegative := FALSE; AxisCmdY.AtNeutral := TRUE; ;; FB_Joystick.st:279 = Axi` | CmdYVal inferieur au seuil negatif de qualification | verifier AxisCmdY.DirectionNegative vers l arbitrage |
| `PRG_02_Acquisition.instJoystick.Calibrate` | LISIBLE? | `entree liee a : GVL_IHM.JOY1Joystick.Cmd.Calibrate` | Entree recue depuis : GVL_IHM.JOY1Joystick.Cmd.Calibrate | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.AxisCmdY.Direction` | VISIBLE | `FB_Joystick.st:163 = AxisCmdY.Direction := 0; AxisCmdY.Deflection := 0; ;; FB_Joystick.st:305 = IF AxisCmdY.DirectionPositive THEN AxisCmdY.Direction ` | AxisCmdY.Direction depend de DirectionPositive sinon 0 | verifier DirectionPositive et la lecture raw Y du joystick |
| `PRG_02_Acquisition.instJoystick.NeutralXMem` | LISIBLE? | `FB_Joystick.st:123 = NeutralXMem := RawX;` | NeutralXMem affecte a RawX | verifier RawX du joystick |
| `PRG_02_Acquisition.instJoystick.NeutralYMem` | LISIBLE? | `FB_Joystick.st:124 = NeutralYMem := RawY;` | NeutralYMem affecte a RawY | verifier RawY du joystick |
| `PRG_02_Acquisition.instJoystick.RawX` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` | Entree recue depuis : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.RawY` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` | Entree recue depuis : PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.TRUE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.instDiagIhmHeartbeat.Enable |
| `PRG_07_Supervision.instCfgT330Normalizer.CommunCfg.Initialized` | LISIBLE? | `entree liee a : GVL_IHM.Commun.Cfg.Initialized` | Entree recue depuis : GVL_IHM.Commun.Cfg.Initialized | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.instMirrorBypassCableLimitSwitch.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev de instMirrorBypassCableLimitSwitch lie a Hmi | Verifier RetainVal de instMirrorBypassCableLimitSwitch |
| `PRG_07_Supervision.instMirrorBypassCableLimitSwitch.RetainVal` | LISIBLE? | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal de instMirrorBypassCableLimitSwitch lie a Hmi | Verifier Prev de instMirrorBypassCableLimitSwitch |
| `PRG_07_Supervision.instMirrorBypassLimitLegal.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev de instMirrorBypassLimitLegal lie a Hmi | Verifier RetainVal de instMirrorBypassLimitLegal |
| `PRG_07_Supervision.instMirrorBypassLimitLegal.RetainVal` | LISIBLE? | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal de instMirrorBypassLimitLegal lie a Hmi | Verifier Prev de instMirrorBypassLimitLegal |
| `PRG_07_Supervision.instMirrorBypassTopLimitSoftware.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev de instMirrorBypassTopLimitSoftware lie a Hmi | Verifier RetainVal de instMirrorBypassTopLimitSoftware |
| `PRG_07_Supervision.instMirrorBypassTopLimitSoftware.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal de instMirrorBypassTopLimitSoftware lie a Hmi | Verifier Prev de instMirrorBypassTopLimitSoftware |
| `PRG_07_Supervision.instMirrorBypassTopLimitSwitch.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev de instMirrorBypassTopLimitSwitch lie a Hmi | Verifier RetainVal de instMirrorBypassTopLimitSwitch |
| `PRG_07_Supervision.instMirrorBypassTopLimitSwitch.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal de instMirrorBypassTopLimitSwitch lie a Hmi | Verifier Prev de instMirrorBypassTopLimitSwitch |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.OverrideTopSoftwareN1M1 |
| `PRG_02_Acquisition.TRUE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.Enable, PRG_02_Acquisition.instJoystick.Enable |
| `PRG_02_Acquisition.instDiagCanOpen.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.BusCanOpenOP.Operational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational` | Entree recue depuis : PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.JoystickOP.Operational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational` | Entree recue depuis : PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleX.DeadbandRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw` | Entree recue depuis : PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleY.Neutral` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instJoystick.NeutralYMem` | Entree recue depuis : PRG_02_Acquisition.instJoystick.NeutralYMem | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleY.RawIn` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instJoystick.RawY` | Entree recue depuis : PRG_02_Acquisition.instJoystick.RawY | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleX.OutPct` | LISIBLE? | `FB_AxisScale.st:29 = OutPct := (INT_TO_REAL(RawIn - Neutral) / Delta) * 100.0; ;; FB_AxisScale.st:31 = OutPct := 0.0;` | instJoystick.ScaleX.OutPct calculé depuis RawIn Neutral Delta | vérifier RawIn Neutral Delta et branche Delta nulle |
| `PRG_02_Acquisition.instJoystick.ScaleY.OutPct` | LISIBLE? | `FB_AxisScale.st:29 = OutPct := (INT_TO_REAL(RawIn - Neutral) / Delta) * 100.0; ;; FB_AxisScale.st:31 = OutPct := 0.0;` | instJoystick.ScaleY.OutPct calculé depuis RawIn Neutral Delta | vérifier RawIn Neutral Delta et branche Delta nulle |
| `PRG_02_Acquisition.instJoystick.AtNeutralXY` | VISIBLE | `FB_Joystick.st:164 = AtNeutralXY := TRUE; ;; FB_Joystick.st:185 = AtNeutralXY := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);` | AtNeutralXY vrai si ScaleX et ScaleY à 0 pourcent | vérifier ScaleX.OutPct et ScaleY.OutPct |
| `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.Modes.Cmd.BtnFaultReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.MaintenanceN2BrakeForceM1 |
| `GVL_IHM.MaintenanceN2.Cmd.BtnM1BrakeRelease` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.MaintenanceN2BrakeForceM1 |

### MODE (42)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.ArmModeDisabled` | LISIBLE? | `PRG_04_Treuils_Benne.st:1186 = ArmModeDisabled := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.DISABLE);` | mode Auth.Mode egal a E_Mode.DISABLE | verifier la valeur de PRG_03_Modes_Cycle.Data.Auth.Mode en amont |
| `GVL_IHM.CycleSemiAuto.State.CycleStep` | LISIBLE? | `PRG_07_Supervision.st:687 = GVL_IHM.CycleSemiAuto.State.CycleStep := PRG_03_Modes_Cycle.Data.SequenceState.Step;` | CycleStep IHM copie depuis SequenceState.Step | Verifier en aval : PRG_02_Acquisition.instJoystick.DirectInversionPermit |
| `GVL_Simulation.SimOperatorActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.OperatorInputSourceSimulated |
| `PRG_02_Acquisition.FALSE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.UseDynamicTarget |
| `PRG_02_Acquisition.instSimBench.Operator` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Operator |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqAscent` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.ReqWinch.ReqAscent |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDescend` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.ReqWinch.ReqDescend |
| `PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothReqAscent, PRG_04_Treuils_Benne.instArbM1.BothIntent.ReqAscent |
| `PRG_04_Treuils_Benne.Data.AutoDiveM1Step4M2Step5Active` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.DescentStep45Permit |
| `PRG_04_Treuils_Benne.Data.SyncState.SyncActive` | LISIBLE? | `PRG_04_Treuils_Benne.st:1945 = Data.SyncState := SyncState;` | SyncState assigne a Data.SyncState | verifier Data.SyncState.SyncActive en aval |
| `PRG_03_Modes_Cycle.Data.Auth.WinchSelTransitionHold` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.M1LogicReqAscent, PRG_04_Treuils_Benne.M1LogicReqDescend |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ExtractionControlActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.CommonMaxStepAscent |
| `PRG_04_Treuils_Benne.ExtractionControlActive` | VISIBLE | `PRG_04_Treuils_Benne.st:596 = ExtractionControlActive := TRUE; ;; PRG_04_Treuils_Benne.st:603 = ExtractionControlActive := FALSE;` | ExtractionControlActive mis a TRUE ou FALSE selon condition | verifier la condition d activation dans PRG_04_Treuils_Benne |
| `PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ReqM1Winch.HomingApproachActive |
| `PRG_04_Treuils_Benne.MaintN1` | LISIBLE? | `PRG_04_Treuils_Benne.st:296 = MaintN1 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1);` | MaintN1 est vrai si Data.Auth.Mode vaut E_Mode.MAINT_N1 | Vérifier la valeur du mode Auth en amont |
| `PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothReqDescend, PRG_04_Treuils_Benne.instArbM1.BothIntent.ReqDescend |
| `PRG_04_Treuils_Benne.ReqM1Winch.HomingApproachActive` | LISIBLE? | `PRG_04_Treuils_Benne.st:1415 = ReqM1Winch.HomingApproachActive := PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable;` | Auth.HomingApproachEnable actif dans PRG_03_Modes_Cycle | Chercher dans ReqM1Winch.HomingApproachActive les consommateurs en aval de l'affectation a la ligne 1415 |
| `PRG_07_Supervision.instMirrorBypassM1.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | instMirrorBypassM1.Hmi reçoit RetainVal | vérifier la valeur RetainVal de BypassM1 |
| `PRG_07_Supervision.instMirrorBypassNetwork.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | instMirrorBypassNetwork.Prev reçoit Hmi | vérifier la propagation Prev dans le miroir réseau Bypass |
| `PRG_07_Supervision.instMirrorBypassNetwork.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | instMirrorBypassNetwork.RetainVal reçoit Hmi | vérifier la cohérence RetainVal de BypassNetwork |
| `PRG_07_Supervision.instMirrorBypassSlackCable.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | instMirrorBypassSlackCable.Hmi reçoit RetainVal | vérifier la valeur RetainVal SlackCable |
| `PRG_02_Acquisition.Data.MachineHoming.Active` | VISIBLE | `PRG_02_Acquisition.st:626 = Data.MachineHoming.Active := instCycleMachineHoming.MachineHomingActive;` | recopie de instCycleMachineHoming.MachineHomingActive | Data.MachineHoming.Active |
| `PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit, PRG_04_Treuils_Benne.instArbM1.Auth.JoystickWinchSelectArbitrated |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_03_Modes_Cycle.Data.SequenceState.Step` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit, GVL_IHM.CycleSemiAuto.State.CycleStep |
| `PRG_04_Treuils_Benne.ManualBucketJogActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `GVL_Simulation.SimWinchActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.WinchInputSourceSimulated, GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback |
| `PRG_03_Modes_Cycle.Data.Auth.InhibitM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.Enable, PRG_04_Treuils_Benne.instSafetyWinchM1.OtherWinchInhibited |
| `PRG_03_Modes_Cycle.Data.Auth.SyncEnable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.SyncEnable, PRG_04_Treuils_Benne.instWinchSync.SyncEnable |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ProcessPermitM1_Ascent |
| `PRG_02_Acquisition.WinchInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:135 = WinchInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;` | SimulationModeActive et SimWinchActive actifs dans GVL_Simulation | verifier les flags de simulation treuil |
| `PRG_03_Modes_Cycle.Data.SequenceState.WinchDescentAuth_M3` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Descend |
| `PRG_03_Modes_Cycle.Data.Auth.InhibitM1` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchM1.Enable, PRG_04_Treuils_Benne.instSafetyWinchM1.Enable |
| `PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent, PRG_04_Treuils_Benne.instWinchSync.DescentStep45Permit |
| `PRG_03_Modes_Cycle.Data.WinchBothIntent.Active` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothMotionActive, PRG_06_Outputs.WinchOutputCoupled |
| `PRG_04_Treuils_Benne.WinchBothMotionActive` | VISIBLE | `PRG_04_Treuils_Benne.st:284 = WinchBothMotionActive := PRG_03_Modes_Cycle.Data.WinchBothIntent.Active;` | WinchBothMotionActive copie depuis Data.WinchBothIntent.Active | verifier WinchBothIntent.Active en PRG_03 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedStep` | LISIBLE? | `PRG_04_Treuils_Benne.st:1609 = WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber; ;; PRG_04_Treuils_Benne.st:1670 = WinchM1FinalInt` | RequestedStep copie depuis instWinchM1.StepNumber sauf remise a 0 en ligne 1670 | verifier StepNumber de instWinchM1 et la condition de reset 1670 |
| `GVL_Simulation.SimSafetyActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineInputSourceSimulated |
| `GVL_Simulation.SimulationModeActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineInputSourceSimulated, PRG_02_Acquisition.WinchInputSourceSimulated |
| `PRG_02_Acquisition.MachineInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:138 = MachineInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimSafetyActive;` | SimulationModeActive ET SimSafetyActive vrais | verifier GVL_Simulation.SimulationModeActive et GVL_Simulation.SimSafetyActive |
| `PRG_03_Modes_Cycle.Data.Auth.Mode` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.MaintenanceN2BrakeForceM1, PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor1 |

### REGLAGE (103)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_07_Supervision._EncoderCfgPersist.Initialized` | A CONTROLER | `PRG_07_Supervision.st:231 = instCfgPersistBridgeEncoder(Hmi := GVL_IHM.Commun.EncoderCfg, Persist := _EncoderCfgPersist);` | Initialized du Persist du bridge apres appel avec EncoderCfg | verifier l'initialisation du Persist dans le bridge en 804 |
| `GVL_IHM.Commun.EncoderCfg.Initialized` | LISIBLE? | `PRG_07_Supervision.st:231 = instCfgPersistBridgeEncoder(Hmi := GVL_IHM.Commun.EncoderCfg, Persist := _EncoderCfgPersist);` | EncoderCfg.Initialized via instCfgPersistBridgeEncoder avec Hmi Commun.EncoderCfg | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.Initialized |
| `GVL_PERSISTENT._JoystickCfgPersist.DeadmanArmHoldTime` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime |
| `PRG_07_Supervision._EncoderCfgPersist.PresetConfirmMode` | A CONTROLER | `PRG_07_Supervision.st:231 = instCfgPersistBridgeEncoder(Hmi := GVL_IHM.Commun.EncoderCfg, Persist := _EncoderCfgPersist);` | appel du bridge avec Hmi GVL_IHM.Commun.EncoderCfg et Persist _EncoderCfgPersist | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.PresetConfirmMode |
| `PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.Initialized` | LISIBLE? | `FB_CfgPersistBridge_fbEncoder_Cfg.st:25 = Persist := Hmi;` | Persist est connecte a Hmi par VAR_IN_OUT | verifier l'affectation Hmi dans l'appel du bridge |
| `GVL_PERSISTENT._JoystickCfgPersist.RawOutOfRangeMargin` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin |
| `PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | JoystickCfgEffective.DeadmanArmHoldTime copie depuis _JoystickCfgPersist | Verifier en aval : PRG_02_Acquisition.instJoystick.Cfg.DeadmanArmHoldTime |
| `PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.Initialized` | LISIBLE? | `FB_CfgPersistBridge_fbEncoder_Cfg.st:21 = Hmi := Persist; ;; FB_CfgPersistBridge_fbEncoder_Cfg.st:22 = Hmi.Initialized := TRUE;` | Hmi.Initialized mis a TRUE via bridge | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.PresetConfirmMode, PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.Initialized |
| `PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.PresetConfirmMode` | LISIBLE? | `FB_CfgPersistBridge_fbEncoder_Cfg.st:25 = Persist := Hmi;` | Persist.PresetConfirmMode via bridge copie depuis Hmi | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.PresetConfirmMode, PRG_07_Supervision._EncoderCfgPersist.PresetConfirmMode |
| `PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | JoystickCfgEffective copie depuis _JoystickCfgPersist | Verifier en aval : PRG_02_Acquisition.instJoystick.Cfg.RawOutOfRangeMargin |
| `PRG_02_Acquisition.instJoystick.Cfg.DeadmanArmHoldTime` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne._SyncCfgPersist.CfgSyncTolerance_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.CfgSyncToleranceM |
| `PRG_07_Supervision._BlinkTimeOff` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.instBlink1Hz.OUT |
| `PRG_07_Supervision._BlinkTimeOn` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.instBlink1Hz.OUT |
| `PRG_07_Supervision.instCfgPersistBridgeEncoder.Hmi.PresetConfirmMode` | LISIBLE? | `FB_CfgPersistBridge_fbEncoder_Cfg.st:21 = Hmi := Persist;` | PresetConfirmMode via bridge Hmi copie depuis Persist | Verifier en aval : GVL_IHM.Commun.EncoderCfg.PresetConfirmMode, PRG_07_Supervision.instCfgPersistBridgeEncoder.Persist.PresetConfirmMode |
| `PRG_02_Acquisition.instJoystick.Cfg.RawOutOfRangeMargin` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.CfgSyncToleranceM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._SyncCfgPersist.CfgSyncTolerance_M` | Entree recue depuis : PRG_04_Treuils_Benne._SyncCfgPersist.CfgSyncTolerance_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision._CycleCfgPersist.ExtractionControlDistance_M` | A CONTROLER | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ExtractionControlDistance_M via instCfgPersistBridgeCycle avec Hmi CycleSemiAuto.Cfg | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ExtractionControlDistance_M |
| `GVL_IHM.Commun.TglHeartbeatIhm` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.instDiagIhmHeartbeat.TglHeartbeatIhm |
| `PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.CfgHomingTargetM, PRG_02_Acquisition.instEncoderM1.CfgTopSensorPosM |
| `PRG_02_Acquisition.instEncoderM1.Cfg.PresetConfirmMode` | LISIBLE? | `entree liee a : GVL_IHM.Commun.EncoderCfg.PresetConfirmMode` | Entree recue depuis : GVL_IHM.Commun.EncoderCfg.PresetConfirmMode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.CfgSyncToleranceM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchSync.CfgSyncToleranceM` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchSync.CfgSyncToleranceM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ExtractionControlDistance_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:25 = Persist := Hmi;` | liaison Persist vers Hmi pour ExtractionControlDistance_M | verifier le bridge cycle et la persistance en aval |
| `GVL_PERSISTENT._JoystickCfgPersist.DeadbandRaw` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw |
| `PRG_02_Acquisition.WINCH_CABLE_M_PER_REV` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.CableM_PerRev |
| `PRG_02_Acquisition.instEncoderM1.CfgHomingTargetM` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.CfgTopSensorPosM` | LISIBLE? | `entree liee a : PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M` | Entree recue depuis : PRG_02_Acquisition._WinchM1CfgPersist.CfgTopSensorPos_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs._WinchSpeedStepTable.P4R1` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R1 |
| `PRG_06_Outputs._WinchSpeedStepTable.P4R2` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R2 |
| `PRG_06_Outputs._WinchSpeedStepTable.P4R3` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R3 |
| `PRG_06_Outputs._WinchSpeedStepTable.P4R4` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R4 |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ExtractionControlDistance_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:21 = Hmi := Persist;` | liaison Hmi vers Persist pour ExtractionControlDistance_M | verifier le binding inverse Persist vers Hmi en aval |
| `PRG_07_Supervision.instDiagIhmHeartbeat.TglHeartbeatIhm` | LISIBLE? | `entree liee a : GVL_Global.BlinkClock, GVL_IHM.Commun.TglHeartbeatIhm, GVL_IHM.Network.Bypass.IhmHeartbeat` | Entree recue depuis : GVL_Global.BlinkClock, GVL_IHM.Commun.TglHeartbeatIhm, GVL_IHM.Network.Bypass.IhmHeartbeat | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M` | LISIBLE? | `PRG_07_Supervision.st:191 = instCfgT330Normalizer( Enable := GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.Commun.Cfg.Initialized, InHoming := T` | LimitLegalDepthMinAllowed_M lu par instCfgT330Normalizer et instCfgPersistBridgeCommun | Verifier les consommateurs de GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M |
| `GVL_IHM.Commun.Cfg.LimitLegalEnabled` | LISIBLE? | `PRG_07_Supervision.st:191 = instCfgT330Normalizer( Enable := GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.Commun.Cfg.Initialized, InHoming := T` | LimitLegalEnabled lu par instCfgT330Normalizer et instCfgPersistBridgeCommun | Verifier les consommateurs de GVL_IHM.Commun.Cfg.LimitLegalEnabled |
| `GVL_IHM.CycleSemiAuto.Cfg.ExtractionControlDistance_M` | LISIBLE? | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ExtractionControlDistance_M lu par instCfgPersistBridgeCycle | Verifier les consommateurs de GVL_IHM.CycleSemiAuto.Cfg.ExtractionControlDistance_M |
| `PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | DeadbandRaw affecte depuis _JoystickCfgPersist | Verifier les consommateurs de JoystickCfgEffective.DeadbandRaw |
| `PRG_02_Acquisition.instEncoderM1.instHoming.CfgTopSensorPosM` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instEncoderM1.CfgTopSensorPosM, PRG_02_Acquisition.instEncoderM1.HomingAtZero` | Entree recue depuis : PRG_02_Acquisition.instEncoderM1.CfgTopSensorPosM, PRG_02_Acquisition.instEncoderM1.HomingAtZero | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne._CommunCfgPersist.LimitLegalDepthMinAllowed_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BottomLimitM1_Active |
| `PRG_04_Treuils_Benne._CommunCfgPersist.LimitLegalEnabled` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BottomLimitM1_Active |
| `PRG_04_Treuils_Benne._CommunCfgPersist.WinchMaxStepAscent` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.EffectiveMaxStepAscent |
| `PRG_04_Treuils_Benne._CommunCfgPersist.WinchMaxStepDescent` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.EffectiveMaxStepDescent |
| `PRG_04_Treuils_Benne.instArbM1.TglJoystickMaster` | LISIBLE? | `entree liee a : GVL_IHM.Modes.Cmd.TglJoystickMaster` | Entree recue depuis : GVL_IHM.Modes.Cmd.TglJoystickMaster | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision._CycleCfgPersist.Initialized` | A CONTROLER | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | Initialized du bridge de configuration persistante dans PRG_07_Supervision | Verifier en aval : PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.Initialized |
| `GVL_IHM.CycleSemiAuto.Cfg.Initialized` | LISIBLE? | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | Cfg.Initialized est une VAR_GLOBAL initialisee par instCfgPersistBridgeCycle | verifier _CycleCfgPersist et le bridge |
| `PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.EffectiveMaxStepAscent` | VISIBLE | `PRG_04_Treuils_Benne.st:469 = EffectiveMaxStepAscent := 5; ;; PRG_04_Treuils_Benne.st:471 = EffectiveMaxStepAscent := _CommunCfgPersist.WinchMaxStepAs` | EffectiveMaxStepAscent vaut 5 ou _CommunCfgPersist.WinchMaxStepAscent | verifier _CommunCfgPersist.WinchMaxStepAscent |
| `PRG_04_Treuils_Benne.EffectiveMaxStepDescent` | VISIBLE | `PRG_04_Treuils_Benne.st:475 = EffectiveMaxStepDescent := 5; ;; PRG_04_Treuils_Benne.st:477 = EffectiveMaxStepDescent := _CommunCfgPersist.WinchMaxStep` | EffectiveMaxStepDescent vaut 5 ou _CommunCfgPersist.WinchMaxStepDescent | verifier _CommunCfgPersist.WinchMaxStepDescent |
| `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownDistanceBottom_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceBottom_M |
| `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownDistanceTop_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.CommonMaxStepAscent, PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceTop_M |
| `PRG_07_Supervision._CommunCfgPersist.Initialized` | A CONTROLER | `PRG_07_Supervision.st:241 = instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);` | Initialized de _CommunCfgPersist apres appel instCfgPersistBridgeCommun | Verifier Persist cote HMI de Commun.Cfg |
| `PRG_07_Supervision._CycleCfgPersist.ImmersionLower_M` | A CONTROLER | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ImmersionLower_M de _CycleCfgPersist apres instCfgPersistBridgeCycle | Verifier la persistance de ImmersionLower_M cote CycleSemiAuto.Cfg |
| `PRG_07_Supervision._CycleCfgPersist.ImmersionUpper_M` | A CONTROLER | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ImmersionUpper_M de _CycleCfgPersist apres instCfgPersistBridgeCycle | Verifier la persistance de ImmersionUpper_M cote CycleSemiAuto.Cfg |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.LimitLegalDepthMinAllowed_M` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:21 = Hmi := Persist;` | Limite legale profondeur min activee dans HMI Commun | Verifier la valeur de LimitLegalDepthMinAllowed_M dans FB_CfgPersistBridge_CommunCfg |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.LimitLegalEnabled` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:21 = Hmi := Persist;` | LimitLegalEnabled actif dans HMI Commun | Verifier l'usage de LimitLegalEnabled dans FB_CfgPersistBridge_CommunCfg |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.Initialized` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:25 = Persist := Hmi;` | Initialized de Persist dans instCfgPersistBridgeCycle | Verifier l'echange Persist/Hmi dans FB_CfgPersistBridge_CycleCfg |
| `GVL_IHM.Commun.Cfg.Initialized` | LISIBLE? | `PRG_07_Supervision.st:191 = instCfgT330Normalizer( Enable := GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.Commun.Cfg.Initialized, InHoming := T` | Cfg.Initialized est utilisé par le normaliseur si Initialized de M1TreuilRetenue et Commun sont vrais | Vérifier le pont de persistance Commun et l'état Initialized |
| `PRG_04_Treuils_Benne.CommonMaxStepAscent` | VISIBLE | `PRG_04_Treuils_Benne.st:1226 = CommonMaxStepAscent := EffectiveMaxStepAscent; ;; PRG_04_Treuils_Benne.st:1244 = CommonMaxStepAscent := 1;` | CommonMaxStepAscent prend EffectiveMaxStepAscent puis est forcé à 1 | Vérifier EffectiveMaxStepAscent et la condition de forçage à 1 |
| `PRG_04_Treuils_Benne.CommonMaxStepDescent` | VISIBLE | `PRG_04_Treuils_Benne.st:1227 = CommonMaxStepDescent := EffectiveMaxStepDescent; ;; PRG_04_Treuils_Benne.st:1245 = CommonMaxStepDescent := 1;` | CommonMaxStepDescent prend EffectiveMaxStepDescent puis est forcé à 1 | Vérifier EffectiveMaxStepDescent et la condition de forçage à 1 |
| `PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayAscent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1452 = M1WinchCfg.DirectionInterlockDelayAscent := T#800ms;` | DirectionInterlockDelayAscent est fixé à T#800ms | Vérifier l'usage de ce délai dans l'interlock de direction |
| `PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayDescent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1453 = M1WinchCfg.DirectionInterlockDelayDescent := T#500ms;` | DirectionInterlockDelayDescent est fixé à T#500ms | Vérifier l'usage de ce délai dans l'interlock de direction |
| `PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceBottom_M` | LISIBLE? | `PRG_04_Treuils_Benne.st:1446 = M1WinchCfg.SlowdownDistanceBottom_M := _CommunCfgPersist.WinchSlowdownDistanceBottom_M;` | SlowdownDistanceBottom_M vient de _CommunCfgPersist | Vérifier la valeur persistée WinchSlowdownDistanceBottom_M |
| `PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceTop_M` | LISIBLE? | `PRG_04_Treuils_Benne.st:1445 = M1WinchCfg.SlowdownDistanceTop_M := _CommunCfgPersist.WinchSlowdownDistanceTop_M;` | SlowdownDistanceTop_M vient de _CommunCfgPersist | Vérifier la valeur persistée WinchSlowdownDistanceTop_M |
| `PRG_04_Treuils_Benne._CommunCfgPersist.WinchSlowdownMaxStep` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownMaxStep, PRG_04_Treuils_Benne.CommonMaxStepAscent |
| `PRG_07_Supervision._CommunCfgPersist.TglEnableKoboldAutoStopDescent` | A CONTROLER | `PRG_07_Supervision.st:241 = instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);` | instCfgPersistBridgeCommun actif selon GVL_IHM.Commun.Cfg et _CommunCfgPersist | verifier _CommunCfgPersist et GVL_IHM.Commun.Cfg |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.Initialized` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:25 = Persist := Hmi;` | Persist affecte a Hmi pour Initialized | verifier la persistance Initialized dans _CommunCfgPersist |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.LimitLegalDepthMinAllowed_M` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:25 = Persist := Hmi;` | Persist affecte a Hmi pour LimitLegalDepthMinAllowed_M | verifier la persistance LimitLegalDepthMinAllowed_M dans _CommunCfgPersist |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.LimitLegalEnabled` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:25 = Persist := Hmi;` | Persist affecte a Hmi pour LimitLegalEnabled | verifier la persistance LimitLegalEnabled dans _CommunCfgPersist |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.Initialized` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:21 = Hmi := Persist; ;; FB_CfgPersistBridge_CycleCfg.st:22 = Hmi.Initialized := TRUE;` | Hmi affecte a Persist puis Initialized mis a TRUE | verifier Initialized dans instCfgPersistBridgeCycle |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ImmersionLower_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:25 = Persist := Hmi;` | Persist affecte a Hmi pour ImmersionLower_M | verifier la persistance ImmersionLower_M dans instCfgPersistBridgeCycle |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Persist.ImmersionUpper_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:25 = Persist := Hmi;` | Persist affecte a Hmi pour ImmersionUpper_M | verifier la persistance ImmersionUpper_M dans instCfgPersistBridgeCycle |
| `PRG_04_Treuils_Benne.M1WinchCfg.SlowdownMaxStep` | LISIBLE? | `PRG_04_Treuils_Benne.st:1447 = M1WinchCfg.SlowdownMaxStep := _CommunCfgPersist.WinchSlowdownMaxStep;` | M1WinchCfg.SlowdownMaxStep = WinchSlowdownMaxStep persisté | vérifier _CommunCfgPersist.WinchSlowdownMaxStep |
| `PRG_04_Treuils_Benne.ReqM1Winch.MaxStepDown` | VISIBLE | `PRG_04_Treuils_Benne.st:1411 = ReqM1Winch.MaxStepDown := CommonMaxStepDescent;` | CommonMaxStepDescent affecte a MaxStepDown ligne 1411 | Chercher dans ReqM1Winch.MaxStepDown les consommateurs en aval de la ligne 1411 |
| `PRG_04_Treuils_Benne.ReqM1Winch.MaxStepUp` | VISIBLE | `PRG_04_Treuils_Benne.st:1410 = ReqM1Winch.MaxStepUp := CommonMaxStepAscent;` | CommonMaxStepAscent affecte a MaxStepUp ligne 1410 | Chercher dans ReqM1Winch.MaxStepUp les consommateurs en aval de la ligne 1410 |
| `PRG_04_Treuils_Benne._CommunCfgPersist.CfgCableLimitAscent_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.TopLimitM1_M |
| `PRG_04_Treuils_Benne._WinchCriticalSyncTolerance_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.CriticalSyncToleranceM |
| `PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgTopSensorPos_M` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.TopLimitM1_M |
| `PRG_07_Supervision._CommunCfgPersist.LimitLegalDepthMinAllowed_M` | A CONTROLER | `PRG_07_Supervision.st:241 = instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);` | instCfgPersistBridgeCommun Hmi GVL_IHM.Commun.Cfg ligne 241 | Chercher dans _CommunCfgPersist.LimitLegalDepthMinAllowed_M les consommateurs en aval |
| `PRG_07_Supervision._CommunCfgPersist.LimitLegalEnabled` | A CONTROLER | `PRG_07_Supervision.st:241 = instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);` | instCfgPersistBridgeCommun Hmi GVL_IHM.Commun.Cfg ligne 241 | Chercher dans _CommunCfgPersist.LimitLegalEnabled les consommateurs en aval |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.Initialized` | LISIBLE? | `FB_CfgPersistBridge_CommunCfg.st:21 = Hmi := Persist; ;; FB_CfgPersistBridge_CommunCfg.st:22 = Hmi.Initialized := TRUE;` | Hmi assigne a Persist ligne 21 et Hmi.Initialized mis vrai ligne 22 | Chercher dans instCfgPersistBridgeCommun.Hmi.Initialized les consommateurs en aval |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Persist.TglEnableKoboldAutoStopDescent` | VISIBLE | `FB_CfgPersistBridge_CommunCfg.st:25 = Persist := Hmi;` | Persist assigne a Hmi ligne 25 | Chercher dans instCfgPersistBridgeCommun.Persist.TglEnableKoboldAutoStopDescent les consommateurs en aval |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ImmersionLower_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:21 = Hmi := Persist;` | Hmi est relié à Persist pour ImmersionLower_M | Vérifier le pont de persistance côté HMI pour ImmersionLower_M |
| `PRG_07_Supervision.instCfgPersistBridgeCycle.Hmi.ImmersionUpper_M` | LISIBLE? | `FB_CfgPersistBridge_CycleCfg.st:21 = Hmi := Persist;` | Hmi est relié à Persist pour ImmersionUpper_M | Vérifier le pont de persistance côté HMI pour ImmersionUpper_M |
| `GVL_IHM.CycleSemiAuto.Cfg.ImmersionLower_M` | LISIBLE? | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ImmersionLower_M via instCfgPersistBridgeCycle | vérifier _CycleCfgPersist |
| `GVL_IHM.CycleSemiAuto.Cfg.ImmersionUpper_M` | LISIBLE? | `PRG_07_Supervision.st:261 = instCfgPersistBridgeCycle(Hmi := GVL_IHM.CycleSemiAuto.Cfg, Persist := _CycleCfgPersist);` | ImmersionUpper_M via instCfgPersistBridgeCycle | vérifier _CycleCfgPersist |
| `PRG_04_Treuils_Benne.M1WinchCfg.StepRampDelayAscent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1454 = M1WinchCfg.StepRampDelayAscent := T#700ms;` | affectation directe du delai de rampe de montee a 700ms | chercher qui lit M1WinchCfg.StepRampDelayAscent |
| `PRG_04_Treuils_Benne.TopLimitM1_M` | LISIBLE? | `PRG_04_Treuils_Benne.st:883 = TopLimitM1_M := SEL(OverrideTopSoftwareN1M1 OR BypassM1TopLimitSoftwareEff, _CommunCfgPersist.CfgCableLimitAscent_M, _Wi` | calcul selon OverrideTopSoftwareN1M1 ou bypass top limit software | verifier _CommunCfgPersist.CfgCableLimitAscent_M et _WinchM1CfgPersist.CfgTopSensorPos_M |
| `PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgCableLimitDescent_M` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.CfgCableLimitDescentM, PRG_04_Treuils_Benne.BottomLimitM1_Active |
| `PRG_07_Supervision.instCfgPersistBridgeCommun.Hmi.TglEnableKoboldAutoStopDescent` | VISIBLE | `FB_CfgPersistBridge_CommunCfg.st:21 = Hmi := Persist;` | TglEnableKoboldAutoStopDescent copié de Persist vers Hmi | vérifier la cohérence de la config persistée KoboldAutoStopDescent |
| `PRG_07_Supervision.instCfgT330Normalizer.CommunCfg.TglEnableKoboldAutoStopDescent` | VISIBLE | `entree liee a : GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent` | Entree recue depuis : GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent` | VISIBLE | `PRG_07_Supervision.st:191 = instCfgT330Normalizer( Enable := GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.Commun.Cfg.Initialized, InHoming := T` | TglEnableKoboldAutoStopDescent normalisé si Cfg Initialized et persisté par bridge Commun | vérifier T330InHoming et _CommunCfgPersist |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.StepThreshold_Pct` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | affectation de SpeedStepTable depuis _WinchSpeedStepTable | verifier les seuils StepThreshold_Pct consommes dans la regulation M1 |
| `PRG_04_Treuils_Benne._WinchSpeedConfig.SpeedBandMaxMps` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.SpeedBandMaxMps |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CfgCableLimitDescentM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgCableLimitDescent_M` | Entree recue depuis : PRG_04_Treuils_Benne._WinchM1CfgPersist.CfgCableLimitDescent_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R1` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecte par _WinchSpeedStepTable ligne 1444 | Verifier _WinchSpeedStepTable et l affectation ligne 1444 |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecte par _WinchSpeedStepTable ligne 1444 | Verifier _WinchSpeedStepTable et l affectation ligne 1444 |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecte par _WinchSpeedStepTable ligne 1444 | Verifier _WinchSpeedStepTable et l affectation ligne 1444 |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R4` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecte par _WinchSpeedStepTable ligne 1444 | Verifier _WinchSpeedStepTable et l affectation ligne 1444 |
| `PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R1` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent, PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R1 |
| `PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R2` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent, PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R2 |
| `PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R3` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent, PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R3 |
| `PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R4` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent, PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R4 |
| `PRG_06_Outputs.CST_ContactorMinInterval` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instM1FwdProtector.Cfg_MinInterval, PRG_06_Outputs.instM1RevProtector.Cfg_MinInterval |

### BYPASS (89)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_IHM.Network.Bypass.EncoderM1` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagEthercat.EncoderM1BypassActive |
| `PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1SimBypass` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagEthercat.EncoderM1Bypass |
| `PRG_02_Acquisition.instDiagEthercat.EncoderM1BypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.EncoderM1` | Entree recue depuis : GVL_IHM.Network.Bypass.EncoderM1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagEthercat.NetworkBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.Global` | Entree recue depuis : GVL_IHM.Network.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagEthercat.EncoderM1Bypass` | LISIBLE? | `FB_Diag_Ethercat.st:96 = EncoderM1Bypass := DeviceEncoderM1SimBypass OR NetworkBypassActive OR EncoderM1BypassActive;` | EncoderM1Bypass vrai si DeviceEncoderM1SimBypass ou NetworkBypassActive ou EncoderM1BypassActive | Verifier en aval : PRG_02_Acquisition.instDiagEthercat.EncoderM1OnlineEff |
| `GVL_IHM.Network.Bypass.IhmHeartbeat` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.instDiagIhmHeartbeat.TglHeartbeatIhm |
| `GVL_IHM.Network.Bypass.BusCanOpen` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive |
| `GVL_IHM.Network.Bypass.Joystick` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive |
| `PRG_07_Supervision.PrevCableLimitSwitch` | LISIBLE? | `PRG_07_Supervision.st:368 = instMirrorBypassCableLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.CableLimitSwitch, RetainVal := BypassCableLimitSwitch, Prev ` | Hmi CableLimitSwitch avec RetainVal et Prev | verifier PrevCableLimitSwitch vers la logique bypass |
| `PRG_07_Supervision.PrevLimitLegal` | LISIBLE? | `PRG_07_Supervision.st:365 = instMirrorBypassLimitLegal(Hmi := GVL_IHM.Commun.Bypass.LimitLegal, RetainVal := BypassLimitLegal, Prev := PrevLimitLegal)` | Hmi LimitLegal avec RetainVal et Prev | verifier PrevLimitLegal vers la logique bypass |
| `PRG_07_Supervision.PrevTopLimitSoftware` | LISIBLE? | `PRG_07_Supervision.st:367 = instMirrorBypassTopLimitSoftware(Hmi := GVL_IHM.Commun.Bypass.TopLimitSoftware, RetainVal := BypassTopLimitSoftware, Prev ` | Hmi TopLimitSoftware avec RetainVal et Prev | verifier PrevTopLimitSoftware vers la logique bypass |
| `PRG_07_Supervision.PrevTopLimitSwitch` | LISIBLE? | `PRG_07_Supervision.st:366 = instMirrorBypassTopLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.TopLimitSwitch, RetainVal := BypassTopLimitSwitch, Prev := Pre` | Hmi TopLimitSwitch avec RetainVal et Prev | verifier PrevTopLimitSwitch vers la logique bypass |
| `PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.BusCanOpen` | Entree recue depuis : GVL_IHM.Network.Bypass.BusCanOpen | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.Joystick` | Entree recue depuis : GVL_IHM.Network.Bypass.Joystick | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.NetworkBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.Global` | Entree recue depuis : GVL_IHM.Network.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.SimBypassActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.CANbusOnlineEff, PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickOnlineEff |
| `GVL_IHM.M1TreuilRetenue.Bypass.MecaD` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BypassM1MecaDEff |
| `PRG_07_Supervision.BypassCableLimitSwitch` | A CONTROLER | `PRG_07_Supervision.st:368 = instMirrorBypassCableLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.CableLimitSwitch, RetainVal := BypassCableLimitSwitch, Prev ` | instMirrorBypassCableLimitSwitch actif selon HMI CableLimitSwitch et RetainVal BypassCableLimitSwitch | verifier BypassCableLimitSwitch et GVL_IHM.Commun.Bypass.CableLimitSwitch |
| `PRG_07_Supervision.BypassLimitLegal` | A CONTROLER | `PRG_07_Supervision.st:365 = instMirrorBypassLimitLegal(Hmi := GVL_IHM.Commun.Bypass.LimitLegal, RetainVal := BypassLimitLegal, Prev := PrevLimitLegal)` | instMirrorBypassLimitLegal actif selon HMI LimitLegal et RetainVal BypassLimitLegal | verifier BypassLimitLegal et GVL_IHM.Commun.Bypass.LimitLegal |
| `PRG_07_Supervision.BypassTopLimitSoftware` | A CONTROLER | `PRG_07_Supervision.st:367 = instMirrorBypassTopLimitSoftware(Hmi := GVL_IHM.Commun.Bypass.TopLimitSoftware, RetainVal := BypassTopLimitSoftware, Prev ` | instMirrorBypassTopLimitSoftware actif selon HMI TopLimitSoftware et RetainVal BypassTopLimitSoftware | verifier BypassTopLimitSoftware et GVL_IHM.Commun.Bypass.TopLimitSoftware |
| `PRG_07_Supervision.BypassTopLimitSwitch` | A CONTROLER | `PRG_07_Supervision.st:366 = instMirrorBypassTopLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.TopLimitSwitch, RetainVal := BypassTopLimitSwitch, Prev := Pre` | instMirrorBypassTopLimitSwitch actif selon HMI TopLimitSwitch et RetainVal BypassTopLimitSwitch | verifier BypassTopLimitSwitch et GVL_IHM.Commun.Bypass.TopLimitSwitch |
| `PRG_07_Supervision.PrevM1Bypass` | LISIBLE? | `PRG_07_Supervision.st:361 = instMirrorBypassM1(Hmi := GVL_IHM.M1TreuilRetenue.Bypass.Global, RetainVal := BypassWinchM1Global, Prev := PrevM1Bypass);` | instMirrorBypassM1 actif selon HMI Global et RetainVal BypassWinchM1Global | verifier BypassWinchM1Global et GVL_IHM.M1TreuilRetenue.Bypass.Global |
| `PRG_07_Supervision.PrevSlackCable` | LISIBLE? | `PRG_07_Supervision.st:369 = instMirrorBypassSlackCable(Hmi := GVL_IHM.Commun.Bypass.SlackCable, RetainVal := BypassSlackCable, Prev := PrevSlackCable)` | instMirrorBypassSlackCable actif selon HMI SlackCable et RetainVal BypassSlackCable | verifier BypassSlackCable et GVL_IHM.Commun.Bypass.SlackCable |
| `PRG_07_Supervision.instMirrorBypassCableLimitSwitch.Hmi` | LISIBLE? | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi affecte a RetainVal dans instMirrorBypassCableLimitSwitch | verifier RetainVal BypassCableLimitSwitch |
| `PRG_07_Supervision.instMirrorBypassLimitLegal.Hmi` | LISIBLE? | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi affecte a RetainVal dans instMirrorBypassLimitLegal | verifier RetainVal BypassLimitLegal |
| `PRG_07_Supervision.instMirrorBypassTopLimitSoftware.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi affecte a RetainVal dans instMirrorBypassTopLimitSoftware | verifier RetainVal BypassTopLimitSoftware |
| `PRG_07_Supervision.instMirrorBypassTopLimitSwitch.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi est une entree VAR_IN_OUT du FB MirrorBypassRetain affectee a RetainVal | verifier le FB appelant qui ecrit RetainVal |
| `GVL_IHM.Commun.Bypass.CableLimitSwitch` | LISIBLE? | `PRG_07_Supervision.st:338 = GVL_IHM.Commun.Bypass.CableLimitSwitch := TRUE; ;; PRG_07_Supervision.st:368 = instMirrorBypassCableLimitSwitch(Hmi := GVL` | CableLimitSwitch forcé TRUE puis mirroir Hmi/RetainVal/Prev | vérifier l'appel instMirrorBypassCableLimitSwitch et la valeur BypassCableLimitSwitch |
| `GVL_IHM.Commun.Bypass.LimitLegal` | LISIBLE? | `PRG_07_Supervision.st:329 = GVL_IHM.Commun.Bypass.LimitLegal := TRUE; ;; PRG_07_Supervision.st:365 = instMirrorBypassLimitLegal(Hmi := GVL_IHM.Commun.` | LimitLegal forcé TRUE puis mirroir Hmi/RetainVal/Prev | vérifier l'appel instMirrorBypassLimitLegal et la valeur BypassLimitLegal |
| `GVL_IHM.Commun.Bypass.TopLimitSoftware` | VISIBLE | `PRG_07_Supervision.st:335 = GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE; ;; PRG_07_Supervision.st:367 = instMirrorBypassTopLimitSoftware(Hmi := GVL` | TopLimitSoftware forcé TRUE puis mirroir Hmi/RetainVal/Prev | vérifier l'appel instMirrorBypassTopLimitSoftware et la valeur BypassTopLimitSoftware |
| `GVL_IHM.Commun.Bypass.TopLimitSwitch` | VISIBLE | `PRG_07_Supervision.st:332 = GVL_IHM.Commun.Bypass.TopLimitSwitch := TRUE; ;; PRG_07_Supervision.st:366 = instMirrorBypassTopLimitSwitch(Hmi := GVL_IHM` | TopLimitSwitch forcé TRUE puis mirroir Hmi/RetainVal/Prev | vérifier l'appel instMirrorBypassTopLimitSwitch et la valeur BypassTopLimitSwitch |
| `GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassBrakeThermal |
| `GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BypassM1CableLimitSwitchEff |
| `GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderFaultBypass |
| `GVL_IHM.M1TreuilRetenue.Bypass.LimitLegal` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BypassM1LimitLegalEff |
| `GVL_IHM.M1TreuilRetenue.Bypass.MecaB` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaB |
| `GVL_IHM.M1TreuilRetenue.Bypass.MecaE` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaE |
| `GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMotorThermal |
| `GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassPhaseRotation |
| `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BypassM1TopLimitSoftwareEff |
| `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.BypassM1TopLimitSwitchEff |
| `PRG_04_Treuils_Benne.BypassM1MecaDEff` | LISIBLE? | `PRG_04_Treuils_Benne.st:870 = BypassM1MecaDEff := GVL_IHM.M1TreuilRetenue.Bypass.MecaD;` | BypassM1MecaDEff = Bypass.MecaD M1TreuilRetenue | vérifier GVL_IHM.M1TreuilRetenue.Bypass.MecaD |
| `PRG_04_Treuils_Benne.OverrideTopSoftwareN1M1` | LISIBLE? | `PRG_04_Treuils_Benne.st:856 = OverrideTopSoftwareN1M1 := MaintN1 AND PRG_02_Acquisition.Data.EncoderM1.Homed AND NOT PRG_02_Acquisition.Data.EncoderM1` | OverrideTopSoftwareN1M1 vrai si MaintN1 et encodeur homed non suspect et BtnOverrideTopSoftware | vérifier MaintN1, instEncoderM1 Homed/HomingSuspect et BtnOverrideTopSoftware |
| `PRG_07_Supervision.PrevNetworkBypass` | LISIBLE? | `PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypass.Global, RetainVal := BypassNetworkGlobal, Prev := PrevNetworkBypass)` | instMirrorBypassNetwork Hmi Global et RetainVal BypassNetworkGlobal ligne 370 | Chercher dans PrevNetworkBypass les consommateurs en aval |
| `PRG_07_Supervision.instMirrorBypassM1.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev est relié à Hmi pour instMirrorBypassM1 | Vérifier le miroir bypass M1 côté HMI |
| `PRG_07_Supervision.instMirrorBypassM1.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal est relié à Hmi pour instMirrorBypassM1 | Vérifier la valeur retenue du bypass M1 |
| `PRG_07_Supervision.instMirrorBypassSlackCable.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev est relié à Hmi pour instMirrorBypassSlackCable | Vérifier le miroir bypass slack câble côté HMI |
| `PRG_07_Supervision.instMirrorBypassSlackCable.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal est relié à Hmi pour instMirrorBypassSlackCable | Vérifier la valeur retenue du bypass slack câble |
| `GVL_IHM.M1M2Sync.Bypass.Global` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.BypassGlobal, PRG_04_Treuils_Benne.instWinchSync.BypassGlobal |
| `GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback` | LISIBLE? | `PRG_07_Supervision.st:494 = GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;` | ContactorFeedback vrai si SimulationModeActive et SimWinchActive | vérifier GVL_Simulation.SimulationModeActive et SimWinchActive |
| `GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BypassOperatorComm |
| `GVL_IHM.M1TreuilRetenue.Bypass.Safety` | LISIBLE? | `PRG_07_Supervision.st:389 = GVL_IHM.M1TreuilRetenue.Bypass.Safety := TRUE; ;; PRG_07_Supervision.st:402 = GVL_IHM.M1TreuilRetenue.Bypass.Safety := FAL` | Safety forcé TRUE ou FALSE selon supervision | vérifier les lignes 389 et 402 de PRG_07_Supervision |
| `GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.BypassGlobal, PRG_04_Treuils_Benne.instWinchSync.BypassGlobal |
| `GVL_IHM.M2TreuilBenne.Bypass.Global` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.BypassGlobal, PRG_04_Treuils_Benne.instWinchSync.BypassGlobal |
| `GVL_IHM.M2TreuilBenne.Bypass.Process` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.BypassGlobal, PRG_04_Treuils_Benne.instWinchSync.BypassGlobal |
| `GVL_IHM.M2TreuilBenne.Bypass.Safety` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.BypassGlobal, PRG_04_Treuils_Benne.instWinchSync.BypassGlobal |
| `PRG_04_Treuils_Benne.BypassM1CableLimitSwitchEff` | LISIBLE? | `PRG_04_Treuils_Benne.st:868 = BypassM1CableLimitSwitchEff := (GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch OR GVL_IHM.Commun.Bypass.CableLimitSwitc` | actif si bypass CableLimitSwitch M1 retenue ou commun est vrai | chercher ce qui consomme BypassM1CableLimitSwitchEff en aval |
| `PRG_04_Treuils_Benne.BypassM1LimitLegalEff` | LISIBLE? | `PRG_04_Treuils_Benne.st:869 = BypassM1LimitLegalEff := (GVL_IHM.M1TreuilRetenue.Bypass.LimitLegal OR GVL_IHM.Commun.Bypass.LimitLegal);` | actif si bypass LimitLegal M1 retenue ou commun est vrai | chercher ce qui consomme BypassM1LimitLegalEff en aval |
| `PRG_04_Treuils_Benne.BypassM1TopLimitSoftwareEff` | LISIBLE? | `PRG_04_Treuils_Benne.st:867 = BypassM1TopLimitSoftwareEff := (GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware OR GVL_IHM.Commun.Bypass.TopLimitSoftwar` | actif si bypass TopLimitSoftware M1 retenue ou commun est vrai | chercher ce qui consomme BypassM1TopLimitSoftwareEff en aval |
| `PRG_04_Treuils_Benne.BypassM1TopLimitSwitchEff` | LISIBLE? | `PRG_04_Treuils_Benne.st:866 = BypassM1TopLimitSwitchEff := (GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch OR GVL_IHM.Commun.Bypass.TopLimitSwitch);` | actif si bypass TopLimitSwitch M1 retenue ou commun est vrai | chercher ce qui consomme BypassM1TopLimitSwitchEff en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassBrakeThermal` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaB` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.MecaB` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.MecaB | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaD` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.BypassM1MecaDEff` | Entree recue depuis : PRG_04_Treuils_Benne.BypassM1MecaDEff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMecaE` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.MecaE` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.MecaE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassMotorThermal` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassPhaseRotation` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassSafety` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.Safety` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.Safety | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderFaultBypass` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.BypassGlobal` | LISIBLE? | `entree liee a : GVL_IHM.M1M2Sync.Bypass.Global, GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback, GVL_IHM.M1TreuilRetenue.Bypass.Global` | Entree recue depuis : GVL_IHM.M1M2Sync.Bypass.Global, GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback, GVL_IHM.M1TreuilRetenue.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.BypassSlackCable` | A CONTROLER | `PRG_07_Supervision.st:369 = instMirrorBypassSlackCable(Hmi := GVL_IHM.Commun.Bypass.SlackCable, RetainVal := BypassSlackCable, Prev := PrevSlackCable)` | actif si bypass SlackCable commun miroite vers RetainVal | verifier instMirrorBypassSlackCable et PrevSlackCable |
| `PRG_07_Supervision.BypassWinchM1Global` | A CONTROLER | `PRG_07_Supervision.st:361 = instMirrorBypassM1(Hmi := GVL_IHM.M1TreuilRetenue.Bypass.Global, RetainVal := BypassWinchM1Global, Prev := PrevM1Bypass);` | actif si bypass Global M1 retenue miroite vers RetainVal | verifier instMirrorBypassM1 et PrevM1Bypass |
| `PRG_07_Supervision.SimBypassFall.Q` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : GVL_IHM.M1TreuilRetenue.Bypass.Process, GVL_IHM.M1TreuilRetenue.Bypass.Safety |
| `PRG_07_Supervision.SimBypassRise.Q` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : GVL_IHM.M1TreuilRetenue.Bypass.Process, GVL_IHM.M1TreuilRetenue.Bypass.Safety |
| `GVL_IHM.Commun.Bypass.SlackCable` | VISIBLE | `PRG_07_Supervision.st:341 = GVL_IHM.Commun.Bypass.SlackCable := TRUE; ;; PRG_07_Supervision.st:369 = instMirrorBypassSlackCable(Hmi := GVL_IHM.Commun.` | SlackCable mis à TRUE puis mirroir avec RetainVal et Prev | vérifier BypassSlackCable et PrevSlackCable |
| `GVL_IHM.M1TreuilRetenue.Bypass.Global` | VISIBLE | `PRG_07_Supervision.st:304 = GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE; ;; PRG_07_Supervision.st:361 = instMirrorBypassM1(Hmi := GVL_IHM.M1TreuilRe` | Bypass.Global mis à TRUE puis mirroir avec RetainVal et Prev | vérifier BypassWinchM1Global et PrevM1Bypass |
| `GVL_IHM.M1TreuilRetenue.Bypass.Process` | LISIBLE? | `PRG_07_Supervision.st:390 = GVL_IHM.M1TreuilRetenue.Bypass.Process := TRUE; ;; PRG_07_Supervision.st:403 = GVL_IHM.M1TreuilRetenue.Bypass.Process := F` | Bypass.Process mis à TRUE puis à FALSE dans supervision | vérifier l'ordre des affectations dans PRG_07_Supervision |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassCableLimitSwitch` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.BypassM1CableLimitSwitchEff` | Entree recue depuis : PRG_04_Treuils_Benne.BypassM1CableLimitSwitchEff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassLimitLegal` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.BypassM1LimitLegalEff` | Entree recue depuis : PRG_04_Treuils_Benne.BypassM1LimitLegalEff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassOperatorComm` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassTopLimitSoftware` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.BypassM1TopLimitSoftwareEff` | Entree recue depuis : PRG_04_Treuils_Benne.BypassM1TopLimitSoftwareEff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassTopLimitSwitch` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.BypassM1TopLimitSwitchEff` | Entree recue depuis : PRG_04_Treuils_Benne.BypassM1TopLimitSwitchEff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.BypassGlobal` | LISIBLE? | `entree liee a : GVL_IHM.M1M2Sync.Bypass.Global, GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback, GVL_IHM.M1TreuilRetenue.Bypass.Global` | Entree recue depuis : GVL_IHM.M1M2Sync.Bypass.Global, GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback, GVL_IHM.M1TreuilRetenue.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.BypassNetworkGlobal` | A CONTROLER | `PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypass.Global, RetainVal := BypassNetworkGlobal, Prev := PrevNetworkBypass)` | instMirrorBypassNetwork avec Hmi GVL_IHM.Network.Bypass.Global | vérifier BypassNetworkGlobal et PrevNetworkBypass |
| `PRG_07_Supervision.instMirrorBypassNetwork.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi affecté depuis RetainVal | vérifier RetainVal dans FB_MirrorBypassRetain |
| `GVL_IHM.Network.Bypass.Global` | VISIBLE | `PRG_07_Supervision.st:352 = GVL_IHM.Network.Bypass.Global := TRUE; ;; PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypas` | GVL_IHM.Network.Bypass.Global est force TRUE puis passe par instMirrorBypassNetwork avec RetainVal BypassNetworkGlobal | Verifier instMirrorBypassNetwork PrevNetworkBypass et BypassNetworkGlobal |
| `GVL_IHM.Network.Bypass.InputModules` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk, PRG_02_Acquisition.Data.InputModules.Vh0008Er1Ok |
| `PRG_04_Treuils_Benne.BypassKoboldBottomTouched` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ProcessPermitM1_Descend |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassGlobal` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Bypass.Global` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BypassProcess` | LISIBLE? | `entree liee a : GVL_IHM.Commun.Bypass.SlackCable, GVL_IHM.M1TreuilRetenue.Bypass.Process` | Entree recue depuis : GVL_IHM.Commun.Bypass.SlackCable, GVL_IHM.M1TreuilRetenue.Bypass.Process | Comparer avec la source : un ecart indique un probleme de liaison |

### ARBITRAGE (56)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.OperatorInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:137 = OperatorInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive;` | OperatorInputSourceSimulated vrai si mode simulation et simulation operateur actifs | Verifier en aval : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1, PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2 |
| `PRG_04_Treuils_Benne.SyncState.SyncActive` | LISIBLE? | `PRG_04_Treuils_Benne.st:1733 = SyncState.SyncActive := instWinchSync.SyncActive;` | SyncActive de SyncState depuis instWinchSync.SyncActive | Verifier en aval : PRG_04_Treuils_Benne.Data.SyncState.SyncActive |
| `PRG_04_Treuils_Benne.ControlAscentArmedForThisClose` | LISIBLE? | `PRG_04_Treuils_Benne.st:593 = ControlAscentArmedForThisClose := WinchBothAscentBucketCloseArmed;` | WinchBothAscentBucketCloseArmed vrai | verifier ControlAscentArmedForThisClose vers le demarrage de montee |
| `PRG_04_Treuils_Benne.instArbM1.Auth.JoystickWinchSelectArbitrated` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.Auth.Mode` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.BothIntent.Active` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.WinchBothIntent.Active` | Entree recue depuis : PRG_03_Modes_Cycle.Data.WinchBothIntent.Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.BothIntent.ReqAscent` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent` | Entree recue depuis : PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.BothIntent.ReqDescend` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend` | Entree recue depuis : PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.Enable` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.TRUE` | Entree recue depuis : PRG_04_Treuils_Benne.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.IHM.BtnAscentM1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ArbIHM.BtnAscentM1` | Entree recue depuis : PRG_04_Treuils_Benne.ArbIHM.BtnAscentM1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.IHM.BtnDescentM1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ArbIHM.BtnDescentM1` | Entree recue depuis : PRG_04_Treuils_Benne.ArbIHM.BtnDescentM1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.Joystick.AxisY.Direction` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisY.Direction` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisY.Direction | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.ReqWinch.ReqAscent` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqAscent` | Entree recue depuis : PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqAscent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.ReqWinch.ReqDescend` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDescend` | Entree recue depuis : PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDescend | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instArbM1.ReqAscent` | LISIBLE? | `FB_WinchCmdArbitrationM1.st:100 = ReqAscent := FALSE; ;; FB_WinchCmdArbitrationM1.st:51 = ReqAscent := FALSE;` | instArbM1.ReqAscent force a FALSE sinon condition d arbitrage | verifier les entrees d arbitrage M1 montée |
| `PRG_04_Treuils_Benne.instArbM1.ReqDescend` | LISIBLE? | `FB_WinchCmdArbitrationM1.st:101 = ReqDescend := FALSE; ;; FB_WinchCmdArbitrationM1.st:52 = ReqDescend := FALSE;` | instArbM1.ReqDescend force a FALSE sinon condition d arbitrage | verifier les entrees d arbitrage M1 descente |
| `PRG_06_Outputs.Data.ContactorMismatchEscalated` | LISIBLE? | `PRG_06_Outputs.st:364 = Data.ContactorMismatchEscalated := instSyncContactorFinal.ContactorMismatchEscalated;` | ContactorMismatchEscalated affecte depuis instSyncContactorFinal ligne 364 | Chercher dans Data.ContactorMismatchEscalated les consommateurs en aval |
| `PRG_02_Acquisition.Data.Joystick.AtNeutralXY` | VISIBLE | `PRG_02_Acquisition.st:532 = Data.Joystick.AtNeutralXY := instJoystick.AtNeutralXY;` | recopie de instJoystick.AtNeutralXY | Data.Joystick.AtNeutralXY |
| `PRG_04_Treuils_Benne.instArbBucket.CmdClose_IHM` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_04_Treuils_Benne.instArbBucket.CmdOpen_IHM` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_04_Treuils_Benne.CoupledBoth` | LISIBLE? | `PRG_04_Treuils_Benne.st:1103 = CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive;` | CoupledBoth vrai si SyncActive ou WinchBothMotionActive | Vérifier instWinchSync.SyncActive et WinchBothMotionActive |
| `PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1631 = WinchBothFinalStep45Coherent := PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active AND NOT WinchM1FinalInterlockReque` | Cohérence step 4 M1 et step 5 M2 en AutoDive selon l'expression tronquée | Lire la fin de l'expression tronquée et les RequestedStep des interlocks |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor1` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor3` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor4` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayFwd` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayRev` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedStep` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent, PRG_04_Treuils_Benne.WinchBothFinalStep45Coherent |
| `PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1648 = WinchBothFinalRequestsCoherent := WinchBothFinalStep45Coherent OR ((WinchM1FinalInterlockRequest.RequestedRelayFwd = Wi` | coherence des demandes des deux treuils via etape 45 ou egalite des relais et contacteurs | verifier WinchBothFinalStep45Coherent et les demandes M2 |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie AscentPermit copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de AscentPermit en amont |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.DescendPermit` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie DescendPermit copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de DescendPermit en amont |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.Enable` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie Enable copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de Enable en amont |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff` | VISIBLE | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie PowerCutOff copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de PowerCutOff en amont |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedStep` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie RequestedStep copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de RequestedStep en amont |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor1` | LISIBLE? | `PRG_04_Treuils_Benne.st:1605 = WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1; ;; PRG_04_Treuils_Benne.st:1666 = WinchM1Fi` | RequestedContactor1 copie depuis instWinchM1.Contactor1 sauf remise a FALSE en ligne 1666 | verifier la logique de Contactor1 de instWinchM1 et la condition de reset 1666 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1606 = WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2; ;; PRG_04_Treuils_Benne.st:1667 = WinchM1Fi` | RequestedContactor2 copie depuis instWinchM1.Contactor2 sauf remise a FALSE en ligne 1667 | verifier la logique de Contactor2 de instWinchM1 et la condition de reset 1667 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1607 = WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3; ;; PRG_04_Treuils_Benne.st:1668 = WinchM1Fi` | RequestedContactor3 copie depuis instWinchM1.Contactor3 sauf remise a FALSE en ligne 1668 | verifier la logique de Contactor3 de instWinchM1 et la condition de reset 1668 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4` | LISIBLE? | `PRG_04_Treuils_Benne.st:1608 = WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4; ;; PRG_04_Treuils_Benne.st:1669 = WinchM1Fi` | RequestedContactor4 copie depuis instWinchM1.Contactor4 sauf remise a FALSE en ligne 1669 | verifier la logique de Contactor4 de instWinchM1 et la condition de reset 1669 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayFwd` | LISIBLE? | `PRG_04_Treuils_Benne.st:1603 = WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd; ;; PRG_04_Treuils_Benne.st:1664 = WinchM1FinalI` | RequestedRelayFwd copie depuis instWinchM1.RelayFwd sauf remise a FALSE en ligne 1664 | verifier la logique de RelayFwd de instWinchM1 et la condition de reset 1664 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayRev` | LISIBLE? | `PRG_04_Treuils_Benne.st:1604 = WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev; ;; PRG_04_Treuils_Benne.st:1665 = WinchM1FinalI` | RequestedRelayRev copie depuis instWinchM1.RelayRev sauf remise a FALSE en ligne 1665 | verifier la logique de RelayRev de instWinchM1 et la condition de reset 1665 |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerContactorEngaged` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor1` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayRev` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | WinchM1FinalInterlockRequest affecte a Data.WinchM1FinalInterlockRequest | verifier la construction de WinchM1FinalInterlockRequest |
| `PRG_06_Outputs.M1BrakeCmd` | LISIBLE? | `PRG_06_Outputs.st:174 = M1BrakeCmd := M1RelayFwd OR M1RelayRev; ;; PRG_06_Outputs.st:261 = M1BrakeCmd := M1RelayFwd OR M1RelayRev;` | M1RelayFwd ou M1RelayRev actif | verifier les deux affectations precedentes de M1BrakeCmd |
| `PRG_06_Outputs.M1RelayFwd` | LISIBLE? | `PRG_06_Outputs.st:167 = M1RelayFwd := instWinchOutputInterlockM1.RelayFwd; ;; PRG_06_Outputs.st:286 = M1RelayFwd := instM1FwdProtector.Cmd;` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |
| `PRG_06_Outputs.M1RelayRev` | LISIBLE? | `PRG_06_Outputs.st:168 = M1RelayRev := instWinchOutputInterlockM1.RelayRev; ;; PRG_06_Outputs.st:287 = M1RelayRev := instM1RevProtector.Cmd;` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |
| `PRG_06_Outputs.M1SpeedContactor1` | LISIBLE? | `PRG_06_Outputs.st:169 = M1SpeedContactor1 := instWinchOutputInterlockM1.Contactor1; ;; PRG_06_Outputs.st:288 = M1SpeedContactor1 := instM1Sc1Protector` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |
| `PRG_06_Outputs.M1SpeedContactor2` | LISIBLE? | `PRG_06_Outputs.st:170 = M1SpeedContactor2 := instWinchOutputInterlockM1.Contactor2; ;; PRG_06_Outputs.st:289 = M1SpeedContactor2 := instM1Sc2Protector` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |
| `PRG_06_Outputs.M1SpeedContactor3` | LISIBLE? | `PRG_06_Outputs.st:171 = M1SpeedContactor3 := instWinchOutputInterlockM1.Contactor3; ;; PRG_06_Outputs.st:290 = M1SpeedContactor3 := instM1Sc3Protector` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |
| `PRG_06_Outputs.M1SpeedContactor4` | LISIBLE? | `PRG_06_Outputs.st:172 = M1SpeedContactor4 := instWinchOutputInterlockM1.Contactor4; ;; PRG_06_Outputs.st:291 = M1SpeedContactor4 := instM1Sc4Protector` | Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi | Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique |

### DEMANDE (71)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.instCycleMachineHoming.M1Demand.HomeReq` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.HomingPermit, PRG_02_Acquisition.instEncoderM1.HomingAtTargetM |
| `PRG_04_Treuils_Benne.ArbIHM.BtnAscentM1` | LISIBLE? | `PRG_04_Treuils_Benne.st:492 = ArbIHM.BtnAscentM1 := GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent;` | BtnAscentM1 de ArbIHM depuis BtnAscent IHM M1 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.IHM.BtnAscentM1 |
| `PRG_04_Treuils_Benne.ArbIHM.BtnDescentM1` | LISIBLE? | `PRG_04_Treuils_Benne.st:493 = ArbIHM.BtnDescentM1 := GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent;` | BtnDescentM1 de ArbIHM depuis BtnDescent IHM M1 | Verifier en aval : PRG_04_Treuils_Benne.instArbM1.IHM.BtnDescentM1 |
| `PRG_04_Treuils_Benne.WinchBothReqAscent` | LISIBLE? | `PRG_04_Treuils_Benne.st:285 = WinchBothReqAscent := PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent;` | WinchBothIntent.ReqAscent vrai depuis PRG_03_Modes_Cycle | verifier WinchBothReqAscent vers l arbitrage |
| `PRG_04_Treuils_Benne.M1LogicReqAscent` | LISIBLE? | `PRG_04_Treuils_Benne.st:542 = M1LogicReqAscent := instArbM1.ReqAscent; ;; PRG_04_Treuils_Benne.st:573 = M1LogicRunRequest := FALSE; M1LogicReqAscent :` | M1LogicReqAscent vient de instArbM1.ReqAscent et est remis à FALSE en fin | Vérifier instArbM1.ReqAscent et la condition de reset |
| `PRG_04_Treuils_Benne.M1LogicReqDescend` | LISIBLE? | `PRG_04_Treuils_Benne.st:543 = M1LogicReqDescend := instArbM1.ReqDescend; ;; PRG_04_Treuils_Benne.st:573 = M1LogicRunRequest := FALSE; M1LogicReqAscent` | M1LogicReqDescend vient de instArbM1.ReqDescend et est remis à FALSE en fin | Vérifier instArbM1.ReqDescend et la condition de reset |
| `PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1387 = ReqM1Winch.ReqAscent := M1LogicReqAscent; ;; PRG_04_Treuils_Benne.st:1408 = ReqM1Winch.RunRequest := FALSE; ReqM1Winch.` | M1LogicReqAscent vrai ligne 1387 et pas de reset ligne 1408 | Chercher dans ReqM1Winch.ReqAscent les consommateurs en aval des lignes 1387 et 1408 |
| `PRG_04_Treuils_Benne.ReqM1Winch.ReqDescend` | LISIBLE? | `PRG_04_Treuils_Benne.st:1388 = ReqM1Winch.ReqDescend := M1LogicReqDescend; ;; PRG_04_Treuils_Benne.st:1408 = ReqM1Winch.RunRequest := FALSE; ReqM1Winc` | M1LogicReqDescend vrai ligne 1388 et pas de reset ligne 1408 | Chercher dans ReqM1Winch.ReqDescend les consommateurs en aval des lignes 1388 et 1408 |
| `PRG_04_Treuils_Benne.instBucket.ActiveOffsetM` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.ExpectedOtherWinchPosM, PRG_04_Treuils_Benne.instWinchSync.ActiveOffsetM |
| `PRG_04_Treuils_Benne.instWinchM1.Config.DirectionInterlockDelayAscent` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayAscent` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayAscent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.DirectionInterlockDelayDescent` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayDescent` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.DirectionInterlockDelayDescent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SlowdownDistanceBottom_M` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceBottom_M` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceBottom_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SlowdownDistanceTop_M` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceTop_M` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownDistanceTop_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Sensors.CablePosM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchSensors.CablePosM` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchSensors.CablePosM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Sensors.Homed` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchSensors.Homed` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchSensors.Homed | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Sensors.HomingSuspect` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchSensors.HomingSuspect` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchSensors.HomingSuspect | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.BottomLimitM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.BottomLimitM` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.BottomLimitM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.TopLimitM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.TopLimitM` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.TopLimitM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.WinchBothReqDescend` | LISIBLE? | `PRG_04_Treuils_Benne.st:286 = WinchBothReqDescend := PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend;` | actif si WinchBothIntent.ReqDescend vrai dans PRG_03_Modes_Cycle | chercher ce qui consomme WinchBothReqDescend |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SlowdownMaxStep` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownMaxStep` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SlowdownMaxStep | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.InBottomSlowdownZone` | VISIBLE | `FB_Winch.st:154 = InBottomSlowdownZone := FALSE; ;; FB_Winch.st:174 = InBottomSlowdownZone := Sensors.Homed AND NOT Sensors.HomingSuspect AND (Sensors` | actif si homed sans suspicion et position sous zone basse | verifier WinchRequest.BottomLimitM et Config.SlowdownDistanceBottom_M |
| `PRG_04_Treuils_Benne.instWinchM1.InTopSlowdownZone` | VISIBLE | `FB_Winch.st:153 = InTopSlowdownZone := FALSE; ;; FB_Winch.st:173 = InTopSlowdownZone := Sensors.Homed AND NOT Sensors.HomingSuspect AND (Sensors.Cable` | actif si homed sans suspicion et position au-dessus zone haute | verifier WinchRequest.TopLimitM et Config.SlowdownDistanceTop_M |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.HomingApproachActive` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.HomingApproachActive` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.HomingApproachActive | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.MaxStepDown` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.MaxStepDown` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.MaxStepDown | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.MaxStepUp` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.MaxStepUp` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.MaxStepUp | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.ReqAscent` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.ReqDescend` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.ReqM1Winch.ReqDescend` | Entree recue depuis : PRG_04_Treuils_Benne.ReqM1Winch.ReqDescend | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instBucket.ActiveOffsetValid` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep` | VISIBLE | `FB_Winch.st:177 = ActiveMaxStep := WinchRequest.MaxStepUp; ;; FB_Winch.st:179 = ActiveMaxStep := MIN(ActiveMaxStep, Config.SlowdownMaxStep);` | ActiveMaxStep limité par MaxStepUp et SlowdownMaxStep | vérifier Config.SlowdownMaxStep et WinchRequest.MaxStepUp |
| `PRG_04_Treuils_Benne.instWinchM1.Config.StepRampDelayAscent` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.StepRampDelayAscent` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.StepRampDelayAscent | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instBucket.ActiveOffsetSettled` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.Enable |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.StepThreshold_Pct` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.StepThreshold_Pct` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.StepThreshold_Pct | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.MaxStepNumber` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P1R1` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R1` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P1R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R2` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P1R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R3` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P1R4` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R4` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P1R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P2R1` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R1` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P2R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R2` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P2R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R3` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P2R4` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R4` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P3R1` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R1` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P3R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R2` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P3R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R3` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P3R4` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R4` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P4R1` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R1` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P4R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R2` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P4R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R3` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P4R4` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R4` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P5R1` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R1` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P5R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R2` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P5R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R3` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Config.SpeedStepTable.P5R4` | VISIBLE | `entree liee a : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R4` | Entree recue depuis : PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.SpeedStep._MaxStepClamped` | LISIBLE? | `FB_SpeedStep.st:37 = _MaxStepClamped := LIMIT(1, MaxStepNumber, 5);` | _MaxStepClamped est calcule par LIMIT de 1 a 5 sur MaxStepNumber | Verifier MaxStepNumber et la valeur de _MaxStepClamped en ligne 37 du FB_SpeedStep |
| `PRG_04_Treuils_Benne.instBucket.M1SlipDetected` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SafeStopM1_Raw |
| `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.StepNumber` | VISIBLE | `FB_SpeedStep.st:62 = StepNumber := 0; ;; FB_SpeedStep.st:71 = StepNumber := LIMIT(_MinStepClamped, SpeedStepReq, _MaxStepClamped);` | StepNumber a 0 ou LIMIT entre min et max selon SpeedStepReq | verifier SpeedStepReq et les bornes de pas |
| `PRG_04_Treuils_Benne.instWinchM1.DirectionChangePending` | VISIBLE | `FB_Winch.st:149 = DirectionChangePending := DirectionInterlock.DirectionChangePending; ;; FB_Winch.st:209 = DirectionChangePending := DirectionInterlo` | DirectionChangePending vient de DirectionInterlock.DirectionChangePending | Vérifier l'interlock de direction dans FB_Winch |
| `PRG_04_Treuils_Benne.instWinchM1.Enable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchM1.Fault.Latched` | LISIBLE? | `FB_Winch.st:130 = Fault := instFault.Fault;` | Fault.Latched suit instFault.Fault | Vérifier instFault et ses causes dans FB_Winch |
| `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.Contactor4` | VISIBLE | `FB_SpeedStep.st:63 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_SpeedStep.st:74 = 1: Contactor1 := Tabl` | Contactor4 selon Table.P1R4 en step 1 sinon faux | Vérifier la table de speed step et le step courant |
| `PRG_04_Treuils_Benne.instWinchM1.StepNumber` | VISIBLE | `FB_Winch.st:145 = StepNumber := StepShaper.ShapedStep; ;; FB_Winch.st:281 = StepNumber := StepShaper.ShapedStep;` | StepNumber égal à StepShaper.ShapedStep | Vérifier StepShaper et ses entrées |
| `PRG_04_Treuils_Benne.instWinchM2.DirectionChangePending` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothMotionReady, PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent |
| `PRG_04_Treuils_Benne.instWinchM2.Fault.Latched` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchBothMotionReady, PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent |
| `PRG_04_Treuils_Benne.instWinchM1.Contactor1` | VISIBLE | `FB_Winch.st:143 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_Winch.st:306 = Contactor1 := SpeedStep.Con` | Contactor1 sortie de FB_Winch mise a FALSE sauf affectation SpeedStep.Contactor1 ligne 306 | verifier SpeedStep.Contactor1 et les conditions de reset ligne 143 |
| `PRG_04_Treuils_Benne.instWinchM1.Contactor2` | LISIBLE? | `FB_Winch.st:143 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_Winch.st:307 = Contactor2 := SpeedStep.Con` | Contactor2 sortie de FB_Winch mise a FALSE sauf affectation SpeedStep.Contactor2 ligne 307 | verifier SpeedStep.Contactor2 et les conditions de reset ligne 143 |
| `PRG_04_Treuils_Benne.instWinchM1.Contactor3` | LISIBLE? | `FB_Winch.st:143 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_Winch.st:308 = Contactor3 := SpeedStep.Con` | Contactor3 sortie de FB_Winch mise a FALSE sauf affectation SpeedStep.Contactor3 ligne 308 | verifier SpeedStep.Contactor3 et les conditions de reset ligne 143 |
| `PRG_04_Treuils_Benne.instWinchM1.Contactor4` | VISIBLE | `FB_Winch.st:143 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_Winch.st:309 = Contactor4 := SpeedStep.Con` | Contactor4 sortie de FB_Winch mise a FALSE sauf affectation SpeedStep.Contactor4 ligne 309 | verifier SpeedStep.Contactor4 et les conditions de reset ligne 143 |
| `PRG_04_Treuils_Benne.instWinchM1.RelayFwd` | VISIBLE | `FB_Winch.st:141 = RelayFwd := FALSE; ;; FB_Winch.st:285 = RelayFwd := TRUE;` | RelayFwd sortie de FB_Winch mise a FALSE sauf mise a TRUE ligne 285 | verifier la condition de la ligne 285 de FB_Winch |
| `PRG_04_Treuils_Benne.instWinchM1.RelayRev` | VISIBLE | `FB_Winch.st:142 = RelayRev := FALSE; ;; FB_Winch.st:286 = RelayRev := FALSE;` | RelayRev sortie de FB_Winch mise a FALSE lignes 142 et 286 | verifier si RelayRev doit rester FALSE dans FB_Winch |

### PERMIS (27)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.ArmM1AscentAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1164 = ArmM1AscentAvail := EffectivePermitM1_Ascent AND NOT instSafetyWinchM1.Fault.Latched;` | EffectivePermitM1_Ascent vrai et Fault.Latched de SafetyWinchM1 faux | verifier EffectivePermitM1_Ascent et Fault.Latched de instSafetyWinchM1 en 820 |
| `PRG_04_Treuils_Benne.ArmM1DescendAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1165 = ArmM1DescendAvail := EffectivePermitM1_Descend AND NOT instSafetyWinchM1.Fault.Latched;` | EffectivePermitM1_Descend vrai et Fault.Latched de SafetyWinchM1 faux | verifier EffectivePermitM1_Descend et Fault.Latched de instSafetyWinchM1 en 820 |
| `PRG_04_Treuils_Benne.ArmM2AscentAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM2DescendAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM3MaintenanceAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM3TremieAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmAnyAxisAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1175 = ArmAnyAxisAvail := ArmM1AscentAvail OR ArmM1DescendAvail OR ArmM2AscentAvail OR ArmM2DescendAvail OR ArmM3TremieAvail O` | ArmAnyAxisAvail vrai si au moins un Arm des axes est vrai | Verifier en aval : PRG_04_Treuils_Benne.ArmingPermit |
| `PRG_04_Treuils_Benne.ArmBucketBusy` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmingPermit |
| `PRG_04_Treuils_Benne.ArmingPermit` | VISIBLE | `PRG_04_Treuils_Benne.st:1205 = ArmingPermit := NOT ArmModeDisabled AND NOT ArmContactorOff AND NOT ArmPowerCutOff AND NOT ArmBucketBusy AND ArmAnyAxis` | ArmingPermit vrai si pas ArmModeDisabled ni ArmContactorOff ni ArmPowerCutOff ni ArmBucketBusy et ArmAnyAxisAvail | Verifier en aval : PRG_04_Treuils_Benne.Data.ArmingPermit |
| `PRG_04_Treuils_Benne.Data.ArmingPermit` | VISIBLE | `PRG_04_Treuils_Benne.st:1962 = Data.ArmingPermit := ArmingPermit;` | Data.ArmingPermit affecte depuis ArmingPermit | Verifier en aval : PRG_02_Acquisition.instJoystick.ArmingPermit |
| `PRG_04_Treuils_Benne.WinchBothAscentBucketCloseArmed` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ControlAscentArmedForThisClose |
| `PRG_04_Treuils_Benne.BucketActivityHold.Q` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.Enable |
| `PRG_04_Treuils_Benne.DescendPermitDiveBucketOpen` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ProcessPermitM1_Descend |
| `PRG_04_Treuils_Benne.SyncOperationPermit` | LISIBLE? | `PRG_04_Treuils_Benne.st:426 = SyncOperationPermit := PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbi` | SyncEnable et JoystickWinchSelectArbitrated égal 0 et pas de homing actif et pas de busy homing M1 M2 et pas instBucket busy et pas ManualBucketJogActive et pas GVL_IHM.M2Tre | vérifier les conditions aval de SyncOperationPermit |
| `PRG_04_Treuils_Benne.ProcessPermitM1_Ascent` | VISIBLE | `PRG_04_Treuils_Benne.st:794 = ProcessPermitM1_Ascent := NOT ExtractionAssistActive OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit;` | NOT ExtractionAssistActive ou ReqBucket.AscentPermit | verifier ExtractionAssistActive et ReqBucket.AscentPermit |
| `PRG_04_Treuils_Benne.ProcessPermitM1_Descend` | VISIBLE | `PRG_04_Treuils_Benne.st:771 = ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;` | ni KoboldBottomTouchLatched ni BypassKoboldBottomTouched et DescendPermitDiveBucketOpen | verifier les latchs Kobold et l ouverture benne |
| `PRG_04_Treuils_Benne.SafetyPermitM1_Ascent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1067 = SafetyPermitM1_Ascent := instSafetyWinchM1.AscentPermit;` | AscentPermit de instSafetyWinchM1 | verifier instSafetyWinchM1.AscentPermit en amont |
| `PRG_04_Treuils_Benne.SafetyPermitM1_Descend` | LISIBLE? | `PRG_04_Treuils_Benne.st:1065 = SafetyPermitM1_Descend := instSafetyWinchM1.DescendPermit;` | DescendPermit de instSafetyWinchM1 | verifier instSafetyWinchM1.DescendPermit en amont |
| `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Ascent` | LISIBLE? | `PRG_04_Treuils_Benne.st:1095 = ProcessAndSafetyPermitM1_Ascent := ProcessPermitM1_Ascent AND SafetyPermitM1_Ascent;` | Permit M1 montée égale ProcessPermit AND SafetyPermit | Vérifier ProcessPermitM1_Ascent et SafetyPermitM1_Ascent |
| `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Descend` | LISIBLE? | `PRG_04_Treuils_Benne.st:1070 = ProcessAndSafetyPermitM1_Descend := ProcessPermitM1_Descend AND SafetyPermitM1_Descend; ;; PRG_04_Treuils_Benne.st:1084` | Permit M1 descente égale ProcessPermit AND SafetyPermit sinon faux | Vérifier ProcessPermitM1_Descend et SafetyPermitM1_Descend |
| `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM2_Ascent` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.EffectivePermitM1_Ascent |
| `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM2_Descend` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.EffectivePermitM1_Descend |
| `PRG_04_Treuils_Benne.EffectivePermitM1_Ascent` | VISIBLE | `PRG_04_Treuils_Benne.st:1113 = EffectivePermitM1_Ascent := ProcessAndSafetyPermitM1_Ascent AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR ProcessAn` | Permit M1 montée avec safety, sans SafeStopM1 et cohérence M2 si couplé | Vérifier ProcessAndSafetyPermitM1_Ascent puis SafeStopM1_Active puis M2 si CoupledBoth |
| `PRG_04_Treuils_Benne.EffectivePermitM1_Descend` | VISIBLE | `PRG_04_Treuils_Benne.st:1111 = EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR Process` | Permit M1 descente avec safety, sans SafeStopM1 et cohérence M2 si couplé | Vérifier ProcessAndSafetyPermitM1_Descend puis SafeStopM1_Active puis M2 si CoupledBoth |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.AscentPermit` | LISIBLE? | `PRG_04_Treuils_Benne.st:1611 = WinchM1FinalInterlockRequest.AscentPermit := EffectivePermitM1_Ascent;` | AscentPermit copie depuis EffectivePermitM1_Ascent | verifier le calcul de EffectivePermitM1_Ascent |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.DescendPermit` | LISIBLE? | `PRG_04_Treuils_Benne.st:1612 = WinchM1FinalInterlockRequest.DescendPermit := EffectivePermitM1_Descend;` | DescendPermit copie depuis EffectivePermitM1_Descend | verifier le calcul de EffectivePermitM1_Descend |
| `PRG_06_Outputs.M1InterlockEnable` | LISIBLE? | `PRG_06_Outputs.st:128 = M1InterlockEnable := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.Enable AND NOT PRG_04_Treuils_Benne.Data.WinchM1Fi` | Enable vrai ET PowerCutOff faux | verifier la construction de WinchM1FinalInterlockRequest.Enable et PowerCutOff |

### SECURITE (129)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.instSafetyWinchM1.Fault.Latched` | LISIBLE? | `FB_Safety_Winch.st:489 = Fault := instFault.Fault;` | Fault.Latched affecte par instFault.Fault dans FB_Safety_Winch | verifier la logique de instFault.Fault dans FB_Safety_Winch |
| `PRG_04_Treuils_Benne.instSafetyWinchM2.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmPowerCutOff |
| `PRG_05_Translation.Data.TranslationSafety.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmPowerCutOff |
| `PRG_04_Treuils_Benne.ArmContactorOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1187 = ArmContactorOff := NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;` | ArmContactorOff vrai si le contacteur puissance n'est pas engage | verifier la source de PowerContactorEngaged_DI dans PRG_02_Acquisition.HwIn.Machine |
| `PRG_04_Treuils_Benne.ArmPowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1188 = ArmPowerCutOff := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff OR PRG_05_Translation.Data.Translation` | au moins un PowerCutOff actif parmi SafetyWinchM1, SafetyWinchM2 ou TranslationSafety | verifier les sorties PowerCutOff des deux treuils et de la translation |
| `PRG_04_Treuils_Benne.instWinchSync.ActiveOffsetM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instBucket.ActiveOffsetM` | Entree recue depuis : PRG_04_Treuils_Benne.instBucket.ActiveOffsetM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.CablePosM1` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.CablePosM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instDeviation.SignedDeltaPosM |
| `PRG_02_Acquisition.HwInM1.AlarmsIn` | LISIBLE? | `PRG_02_Acquisition.st:640 = HwInM1.AlarmsIn := HwIn.Winch.COD1_Alarms;` | AlarmsIn affecte par HwIn.Winch.COD1_Alarms | verifier COD1_Alarms et l usage alarmes en aval |
| `PRG_02_Acquisition.HwInM1.SlaveOperational` | LISIBLE? | `PRG_02_Acquisition.st:642 = HwInM1.SlaveOperational := instDiagEthercat.DeviceEncoderM1.Operational;` | SlaveOperational affecte par instDiagEthercat.DeviceEncoderM1.Operational | verifier la diag EtherCAT et l usage en aval |
| `PRG_04_Treuils_Benne.instWinchSync.HomedAndReliableM1` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.SignedDeltaPosM` | VISIBLE | `FB_SyncDeviation.st:56 = DeltaPosM := 0.0; SignedDeltaPosM := 0.0; ;; FB_SyncDeviation.st:67 = SignedDeltaPosM := CablePosM1 - CablePosM2 + ActiveOffs` | SignedDeltaPosM calcule si instDeviation actif | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instDeviation.DeltaPosM |
| `PRG_02_Acquisition.MachineHomingMechanicalStopOk` | LISIBLE? | `PRG_02_Acquisition.st:557 = MachineHomingMechanicalStopOk := HwIn.Winch.M1_ContactorsReleased_DI AND NOT HwIn.Winch.M1_BrakeIsOpen_DI AND (ABS(Data.En` | contacteurs M1 et M2 ouverts freins non ouverts et vitesses sous 0.02 | verifier MachineHomingMechanicalStopOk en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.DeltaPosM` | LISIBLE? | `FB_SyncDeviation.st:56 = DeltaPosM := 0.0; SignedDeltaPosM := 0.0; ;; FB_SyncDeviation.st:68 = DeltaPosM := ABS(SignedDeltaPosM);` | DeltaPosM et SignedDeltaPosM calcules ou remis a zero | verifier le calcul de SignedDeltaPosM et l usage en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.HomedAndReliableM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instDeviation.WarnActive, PRG_04_Treuils_Benne.instWinchSync.instDeviation.WarnLatched |
| `PRG_04_Treuils_Benne.instWinchSync.SpeedStepTable.P4R1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R1` | Entree recue depuis : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.SpeedStepTable.P4R2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R2` | Entree recue depuis : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.SpeedStepTable.P4R3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R3` | Entree recue depuis : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.SpeedStepTable.P4R4` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R4` | Entree recue depuis : PRG_04_Treuils_Benne._WinchSpeedStepTable.P4R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.WarnActive` | LISIBLE? | `FB_SyncDeviation.st:81 = WarnActive := SyncEnable AND HomedAndReliableM1 AND HomedAndReliableM2 AND (DeltaPosM > CfgSyncToleranceM);` | WarnActive si sync active, deux treuils homes fiables et delta position superieur tolerance | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instDeviation.SyncDeviationWarn, PRG_04_Treuils_Benne.instWinchSync.instDeviation.WarnLatched |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.WarnLatched` | LISIBLE? | `FB_SyncDeviation.st:100 = WarnLatched := FALSE; ;; FB_SyncDeviation.st:58 = WarnLatched := FALSE;` | WarnLatched force a FALSE | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instDeviation.SyncDeviationWarn |
| `PRG_04_Treuils_Benne.BucketBusyFallEdge.Q` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ExtractionControlActive, PRG_04_Treuils_Benne.ControlAscentStartM1PosM |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.Fault.ErrorId` | LISIBLE? | `FB_Safety_Winch.st:489 = Fault := instFault.Fault;` | Fault assigne depuis instFault.Fault | verifier Fault.ErrorId vers la supervision |
| `PRG_04_Treuils_Benne.instSafetyWinchM2.Fault.ErrorId` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SlackCableAscentCapStep1 |
| `PRG_04_Treuils_Benne.instWinchSync.DescentStep45Permit` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active` | Entree recue depuis : PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instDeviation.SyncDeviationWarn` | LISIBLE? | `FB_SyncDeviation.st:57 = SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE; ;; FB_SyncDeviation.st:93 = SyncDeviationWarn := WarnActive OR WarnL` | WarnActive ou WarnLatched vrai | verifier SyncDeviationWarn vers la supervision |
| `PRG_04_Treuils_Benne.BottomLimitM1_Active` | VISIBLE | `PRG_04_Treuils_Benne.st:695 = BottomLimitM1_Active := MAX(_WinchM1CfgPersist.CfgCableLimitDescent_M, _CommunCfgPersist.LimitLegalDepthMinAllowed_M); ;` | BottomLimitM1_Active vaut MAX de CfgCableLimitDescent_M et LimitLegalDepthMinAllowed_M ou CfgCableLimitDescent_M | verifier _WinchM1CfgPersist et _CommunCfgPersist |
| `PRG_04_Treuils_Benne.BucketNotClosedAscentCapStep1` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.CommonMaxStepAscent |
| `PRG_04_Treuils_Benne.SlackCableAscentCapStep1` | LISIBLE? | `PRG_04_Treuils_Benne.st:452 = SlackCableAscentCapStep1 := NOT GVL_IHM.Commun.Bypass.SlackCable AND NOT PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND ( (` | SlackCableAscentCapStep1 selon bypass SlackCable SyncEnable et bits Fault ErrorId tension M2 | verifier GVL_IHM.Commun.Bypass.SlackCable et instSafetyWinch fault |
| `PRG_04_Treuils_Benne.instWinchSync.Contactor1_M1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.Contactor1` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.Contactor1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.Contactor2_M1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.Contactor2` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.Contactor2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.Contactor3_M1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.Contactor3` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.Contactor3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.Contactor4_M1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.Contactor4` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.Contactor4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.RelayFwdM1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.RelayFwd` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.RelayFwd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.RelayRevM1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.RelayRev` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.RelayRev | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.SyncDeviationWarn` | LISIBLE? | `FB_WinchSync.st:144 = SyncDeviationWarn := instDeviation.SyncDeviationWarn; ;; FB_WinchSync.st:98 = SyncWarn := FALSE; SyncDeviationWarn := FALSE; Syn` | SyncDeviationWarn reflete instDeviation.SyncDeviationWarn sinon FALSE | verifier instDeviation du FB_WinchSync |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.DescentStep5M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.DescentStep45Matched |
| `PRG_04_Treuils_Benne.ReqM1Winch.BottomLimitM` | LISIBLE? | `PRG_04_Treuils_Benne.st:1418 = ReqM1Winch.BottomLimitM := BottomLimitM1_Active;` | BottomLimitM vient de BottomLimitM1_Active | Vérifier le calcul de BottomLimitM1_Active |
| `PRG_04_Treuils_Benne.ReqM1Winch.TopLimitM` | LISIBLE? | `PRG_04_Treuils_Benne.st:1417 = ReqM1Winch.TopLimitM := TopLimitM1_M;` | TopLimitM vient de TopLimitM1_M | Vérifier le calcul de TopLimitM1_M |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Contactor1_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step1Mismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Contactor2_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step2Mismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Contactor3_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step3Mismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Contactor4_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step4Mismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.DescentStep45Matched` | LISIBLE? | `FB_SyncContactor.st:121 = DescentStep45Matched := DescentStep45Permit AND NOT RelayFwdM2 AND NOT RelayFwdM1 AND DescentStep4M1 AND DescentStep5M2; ;; ` | DescentStep45Permit actif et pas RelayFwdM2 ni RelayFwdM1 et DescentStep4M1 et DescentStep5M2 | verifier DescentStep45Permit RelayFwdM2 RelayFwdM1 DescentStep4M1 DescentStep5M2 en amont |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.RelayFwdM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.RelayFwdMismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.RelayRevM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.RelayRevMismatch, PRG_04_Treuils_Benne.instWinchSync.instContactor.BothCommanded |
| `PRG_07_Supervision.instDiagIhmHeartbeat.Enable` | LISIBLE? | `entree liee a : PRG_07_Supervision.TRUE` | Entree recue depuis : PRG_07_Supervision.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.instDiagIhmHeartbeat.HeartbeatIhmTimeout` | VISIBLE | `FB_Diag_IhmHeartbeat.st:40 = HeartbeatIhmTimeout := TRUE; ;; FB_Diag_IhmHeartbeat.st:65 = HeartbeatIhmTimeout := IhmTimeoutTon.Q;` | IhmTimeoutTon.Q vrai apres timeout heartbeat IHM | verifier IhmTimeoutTon et la source du heartbeat IHM |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BrakeFeedback` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.FwdRevSpeedFeedbackOff` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.JoystickYNeutral` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisY.Direction` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisY.Direction | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MovementCommanded` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.instWinchM1.RelayFwd, PRG_04_Treuils_Benne.instWinchM1.RelayRev` | Entree recue depuis : PRG_04_Treuils_Benne.instWinchM1.RelayFwd, PRG_04_Treuils_Benne.instWinchM1.RelayRev | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.RelayFwdMismatch` | LISIBLE? | `FB_SyncContactor.st:104 = Diag.RelayFwdMismatch := (BothCommanded OR SyncEnable) AND (RelayFwdM1 <> RelayFwdM2); ;; FB_SyncContactor.st:82 = Diag.Rela` | BothCommanded ou SyncEnable et RelayFwdM1 different de RelayFwdM2 ligne 104 sinon faux ligne 82 | Chercher dans Diag.RelayFwdMismatch les consommateurs en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.RelayRevMismatch` | LISIBLE? | `FB_SyncContactor.st:105 = Diag.RelayRevMismatch := (BothCommanded OR SyncEnable) AND (RelayRevM1 <> RelayRevM2); ;; FB_SyncContactor.st:83 = Diag.Rela` | BothCommanded ou SyncEnable et RelayRevM1 different de RelayRevM2 ligne 105 sinon faux ligne 83 | Chercher dans Diag.RelayRevMismatch les consommateurs en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step1Mismatch` | LISIBLE? | `FB_SyncContactor.st:106 = Diag.Step1Mismatch := (BothCommanded OR SyncEnable) AND (Contactor1_M1 <> Contactor1_M2); ;; FB_SyncContactor.st:128 = Diag.` | BothCommanded ou SyncEnable et Contactor1_M1 different de Contactor1_M2 ligne 106 sinon faux ligne 128 | Chercher dans Diag.Step1Mismatch les consommateurs en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step2Mismatch` | LISIBLE? | `FB_SyncContactor.st:107 = Diag.Step2Mismatch := (BothCommanded OR SyncEnable) AND (Contactor2_M1 <> Contactor2_M2); ;; FB_SyncContactor.st:129 = Diag.` | BothCommanded ou SyncEnable et Contactor2_M1 different de Contactor2_M2 ligne 107 sinon faux ligne 129 | Chercher dans Diag.Step2Mismatch les consommateurs en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step3Mismatch` | LISIBLE? | `FB_SyncContactor.st:108 = Diag.Step3Mismatch := (BothCommanded OR SyncEnable) AND (Contactor3_M1 <> Contactor3_M2); ;; FB_SyncContactor.st:130 = Diag.` | BothCommanded ou SyncEnable et Contactor3_M1 different de Contactor3_M2 ligne 108 sinon faux ligne 130 | Chercher dans Diag.Step3Mismatch les consommateurs en aval |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.Diag.Step4Mismatch` | LISIBLE? | `FB_SyncContactor.st:109 = Diag.Step4Mismatch := (BothCommanded OR SyncEnable) AND (Contactor4_M1 <> Contactor4_M2); ;; FB_SyncContactor.st:131 = Diag.` | BothCommanded ou SyncEnable et Contactor4_M1 different de Contactor4_M2 ligne 109 sinon faux ligne 131 | Chercher dans Diag.Step4Mismatch les consommateurs en aval |
| `GVL_IHM.Commun.LimitLegalReached` | VISIBLE | `PRG_07_Supervision.st:416 = GVL_IHM.Commun.LimitLegalReached := _CommunCfgPersist.LimitLegalEnabled AND ((PRG_02_Acquisition.Data.EncoderM1.Measuremen` | LimitLegalReached si LimitLegalEnabled et CablePosM sous limite profondeur | vérifier _CommunCfgPersist.LimitLegalDepthMinAllowed_M |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BrakeThermalFeedback` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CriticalSyncToleranceM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchCriticalSyncTolerance_M` | Entree recue depuis : PRG_04_Treuils_Benne._WinchCriticalSyncTolerance_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderAvailable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.ExpectedOtherWinchPosM` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM, PRG_04_Treuils_Benne.instBucket.ActiveOffsetM` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM, PRG_04_Treuils_Benne.instBucket.ActiveOffsetM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.ExternalSyncEscalation` | LISIBLE? | `entree liee a : PRG_06_Outputs.Data.ContactorMismatchEscalated` | Entree recue depuis : PRG_06_Outputs.Data.ContactorMismatchEscalated | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.OtherWinchInhibited` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.InhibitM2` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.InhibitM2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PhaseRotationOk` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.ThermalFeedback` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.WinchStandstill` | LISIBLE? | `FB_Safety_Winch.st:263 = WinchStandstill := FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND JoystickYNeutral AND NOT MovementCommanded AND (NOT Measu` | actif si vitesses off et frein off et joystick neutre et pas de commande et vitesse mesuree faible | verifier les entrees FwdRevSpeedFeedbackOff BrakeFeedback JoystickYNeutral MovementCommanded MeasuredSpeedValid |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.MismatchActive` | LISIBLE? | `FB_SyncContactor.st:134 = MismatchActive := Diag.RelayFwdMismatch OR Diag.RelayRevMismatch OR Diag.Step1Mismatch OR Diag.Step2Mismatch OR Diag.Step3Mi` | actif si un mismatch relay ou step est vrai | verifier Diag.RelayFwdMismatch RelayRevMismatch Step1Mismatch Step2Mismatch Step3Mismatch Step4Mismatch |
| `PRG_04_Treuils_Benne.KoboldAutoStopFallEdge.Q` | LISIBLE? | `PRG_04_Treuils_Benne.st:721 = KoboldAutoStopFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);` | front descendant sur M1_M2_KoboldBottomTouch_DI via KoboldAutoStopFallEdge | verifier l usage de KoboldAutoStopFallEdge.Q en aval dans PRG_04_Treuils_Benne |
| `PRG_04_Treuils_Benne.KoboldImmersionConfirmed` | VISIBLE | `PRG_04_Treuils_Benne.st:725 = KoboldImmersionConfirmed := FALSE; ;; PRG_04_Treuils_Benne.st:742 = KoboldImmersionConfirmed := TRUE;` | KoboldImmersionConfirmed mis a FALSE puis TRUE selon le code | verifier ce qui consomme KoboldImmersionConfirmed en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BenneBusy` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.RefWindowActive, PRG_04_Treuils_Benne.instSafetyWinchM1.TonRefSettle.Q |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.BrakeThermalFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:190 = BrakeThermalFaultLatched := FALSE; ;; FB_Safety_Winch.st:209 = BrakeThermalFaultLatched := FALSE;` | BrakeThermalFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch de defaut thermique frein en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CablePosM` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CrossCheckEnable` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.SyncOperationPermit` | Entree recue depuis : PRG_04_Treuils_Benne.SyncOperationPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:184 = EncoderFaultLatched := FALSE; ;; FB_Safety_Winch.st:203 = EncoderFaultLatched := FALSE;` | EncoderFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch defaut encodeur en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.HeartbeatIhmOk` | LISIBLE? | `entree liee a : GVL_IHM.Commun.HeartbeatIhmOk` | Entree recue depuis : GVL_IHM.Commun.HeartbeatIhmOk | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.Homed` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Homed` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Homed | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.HomingSuspect` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.HomingSuspect` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.HomingSuspect | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.InReferencingMode` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.JoystickOnline` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Network.Joystick.Online` | Entree recue depuis : PRG_02_Acquisition.Data.Network.Joystick.Online | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.JoystickOperational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Network.Joystick.Operational` | Entree recue depuis : PRG_02_Acquisition.Data.Network.Joystick.Operational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.LimitLegalReached` | LISIBLE? | `entree liee a : GVL_IHM.Commun.LimitLegalReached` | Entree recue depuis : GVL_IHM.Commun.LimitLegalReached | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MecaBFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:188 = MecaBFaultLatched := FALSE; ;; FB_Safety_Winch.st:207 = MecaBFaultLatched := FALSE;` | MecaBFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch MecaB en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MecaDFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:191 = MecaDFaultLatched := FALSE; ;; FB_Safety_Winch.st:210 = MecaDFaultLatched := FALSE;` | MecaDFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch MecaD en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MecaEEscaladeFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:193 = MecaEEscaladeFaultLatched := FALSE; ;; FB_Safety_Winch.st:212 = MecaEEscaladeFaultLatched := FALSE;` | MecaEEscaladeFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch MecaEEscalade en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MecaEFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:192 = MecaEFaultLatched := FALSE; ;; FB_Safety_Winch.st:211 = MecaEFaultLatched := FALSE;` | MecaEFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch MecaE en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MotorThermalFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:185 = MotorThermalFaultLatched := FALSE; ;; FB_Safety_Winch.st:204 = MotorThermalFaultLatched := FALSE;` | MotorThermalFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch thermique moteur en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PhaseRotationFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:186 = PhaseRotationFaultLatched := FALSE; ;; FB_Safety_Winch.st:205 = PhaseRotationFaultLatched := FALSE;` | PhaseRotationFaultLatched remis a FALSE dans FB_Safety_Winch | verifier les conditions de latch rotation de phase en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PosStepDetected` | LISIBLE? | `FB_Safety_Winch.st:230 = PosStepDetected := (ABS(CablePosM - CablePosMPrev) > CST_RefPosStepM) OR (ABS(ExpectedOtherWinchPosM - ExpectedOtherWinchPosM` | PosStepDetected vrai si variation CablePosM ou ExpectedOtherWinchPosM dépasse CST_RefPosStepM | vérifier le calcul de CablePosMPrev et ExpectedOtherWinchPosMPrev |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.SlackCableDetected` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.TopLimitM` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.TopLimitM1_M` | Entree recue depuis : PRG_04_Treuils_Benne.TopLimitM1_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.TopPositionSensor` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.MismatchTimer.Q` | LISIBLE? | `FB_SyncContactor.st:140 = MismatchTimer(IN := MismatchActive, PT := MismatchDebounce); ;; FB_SyncContactor.st:80 = MismatchTimer(IN := FALSE);` | MismatchTimer.Q vrai après MismatchDebounce si MismatchActive | vérifier MismatchActive et MismatchDebounce |
| `PRG_04_Treuils_Benne.KoboldBottomTouchLatched` | VISIBLE | `PRG_04_Treuils_Benne.st:726 = KoboldBottomTouchLatched := FALSE; ;; PRG_04_Treuils_Benne.st:748 = KoboldBottomTouchLatched := TRUE;` | KoboldBottomTouchLatched est mis a FALSE ou TRUE selon la logique des lignes 726 et 748 | Verifier les conditions des lignes 726 et 748 de PRG_04_Treuils_Benne |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.AscentPermit` | LISIBLE? | `FB_Safety_Winch.st:533 = AscentPermit := FALSE; ;; FB_Safety_Winch.st:574 = AscentPermit := NOT ( ((CauseTopLimitSwitchActive OR (NOT TopPositionSenso` | AscentPermit dépend des fins de course haut et capteur de position et mode referencing et bypass | vérifier CauseTopLimitSwitchActive et TopPositionSensor et InReferencingMode |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.DescendPermit` | LISIBLE? | `FB_Safety_Winch.st:532 = DescendPermit := FALSE; ;; FB_Safety_Winch.st:563 = DescendPermit := NOT ( ((CauseCableLimitActive OR NOT PowerContactorEngag` | DescendPermit dépend des limites câble contacteur position referencing slack et bypass | vérifier CauseCableLimitActive et PowerContactorEngaged et CablePosM et InReferencingMode |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MeasuredSpeedMps` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.MeasuredSpeedValid` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid` | Entree recue depuis : PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.RefWindowActive` | LISIBLE? | `FB_Safety_Winch.st:248 = RefWindowActive := InReferencingMode OR BenneBusy OR PosStepDetected OR NOT TonRefSettle.Q OR NOT CrossCheckEnable; ;; FB_Saf` | RefWindowActive dépend de InReferencingMode ou BenneBusy ou PosStepDetected ou TonRefSettle ou CrossCheckEnable | vérifier ces entrées de fenêtre de référence |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.SpeedBandMaxMps` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne._WinchSpeedConfig.SpeedBandMaxMps` | Entree recue depuis : PRG_04_Treuils_Benne._WinchSpeedConfig.SpeedBandMaxMps | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.instCauses.Active` | LISIBLE? | `FB_Safety_Winch.st:269 = instCauses[0].Active := (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk); ;; FB_Safety_Winch.st:271 = in` | Active cause 0 si JoystickOnline ou JoystickOperational ou HeartbeatIhmOk est faux | vérifier ces trois signaux joystick et heartbeat |
| `PRG_04_Treuils_Benne.instWinchSync.instContactor.ContactorMismatch` | LISIBLE? | `FB_SyncContactor.st:141 = ContactorMismatch := MismatchTimer.Q; ;; FB_SyncContactor.st:72 = ContactorMismatch := FALSE;` | ContactorMismatch est MismatchTimer.Q | vérifier MismatchTimer et les entrées du contacteur sync |
| `PRG_02_Acquisition.instCycleMachineHoming.MachineHomingLossSafeStop` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.Data.MachineHoming.HomingLoss |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CauseMecaEEscaladeActive` | LISIBLE? | `FB_Safety_Winch.st:507 = CauseMecaEEscaladeActive := instCauses[13].Active;` | instCauses index 13 Active | verifier la cause 13 dans instCauses |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.OverspeedFaultLatched` | LISIBLE? | `FB_Safety_Winch.st:196 = OverspeedFaultLatched := FALSE; ;; FB_Safety_Winch.st:215 = OverspeedFaultLatched := FALSE;` | OverspeedFaultLatched mis a FALSE selon le code | verifier la logique de latch survitesse dans FB_Safety_Winch |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PowerContactorEngaged` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.SyncEnable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.SyncEnable` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.SyncEnable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.ContactorMismatch` | LISIBLE? | `FB_WinchSync.st:197 = ContactorMismatch := instContactor.ContactorMismatch; ;; FB_WinchSync.st:99 = ContactorMismatch := FALSE;` | ContactorMismatch sort TRUE si instContactor.ContactorMismatch est TRUE sinon mise a FALSE | Verifier instContactor.ContactorMismatch et la logique de mismatch des contacteurs dans FB_WinchSync |
| `PRG_04_Treuils_Benne.instWinchSync.Enable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.InhibitM2, PRG_04_Treuils_Benne.BucketActivityHold.Q` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.InhibitM2, PRG_04_Treuils_Benne.BucketActivityHold.Q | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.Mode` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instWinchSync.SyncEnable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.SyncEnable` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.SyncEnable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.Data.ContactorMismatch` | VISIBLE | `PRG_06_Outputs.st:363 = Data.ContactorMismatch := instSyncContactorFinal.ContactorMismatch;` | Data.ContactorMismatch recoit instSyncContactorFinal.ContactorMismatch | Verifier instSyncContactorFinal.ContactorMismatch en amont de PRG_06_Outputs |
| `PRG_02_Acquisition.Data.InputModules.Fault` | VISIBLE | `PRG_02_Acquisition.st:217 = Data.InputModules.Fault := NOT (Data.InputModules.LocalDigitalIoOk AND Data.InputModules.Vh0800EndOk AND Data.InputModules` | Fault si un des modules IO listés n'est pas Ok | Vérifier LocalDigitalIoOk Vh0800EndOk Vh0808EtpOk Vh0008ErOk Vh0008Er1Ok |
| `PRG_02_Acquisition.Data.MachineHoming.HomingLoss` | VISIBLE | `PRG_02_Acquisition.st:627 = Data.MachineHoming.HomingLoss := instCycleMachineHoming.MachineHomingLossSafeStop;` | HomingLoss depuis instCycleMachineHoming.MachineHomingLossSafeStop | Vérifier instCycleMachineHoming et son signal safe stop |
| `PRG_04_Treuils_Benne.WinchContactorMismatchLvl1` | LISIBLE? | `PRG_04_Treuils_Benne.st:712 = WinchContactorMismatchLvl1 := instWinchSync.ContactorMismatch OR PRG_06_Outputs.Data.ContactorMismatch;` | ContactorMismatch de instWinchSync ou ContactorMismatch de PRG_06_Outputs.Data | verifier les contacteurs et la synchro treuil en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.CausesPowerCutOffActive` | VISIBLE | `FB_Safety_Winch.st:523 = CausesPowerCutOffActive := CauseMotorThermalActive OR CauseMecaAActive OR CauseMecaBActive OR CauseMecaCActive OR CauseBrakeT` | une des causes thermique moteur meca A B C frein meca D ou escalade E active | verifier chaque cause active dans instCauses |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.Enable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.InhibitM1, PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.SafeStop` | VISIBLE | `FB_Safety_Winch.st:531 = SafeStop := FALSE; ;; FB_Safety_Winch.st:553 = SafeStop := TRUE;` | SafeStop mis a FALSE ou TRUE selon le code FB_Safety_Winch | verifier la logique de SafeStop dans FB_Safety_Winch |
| `PRG_04_Treuils_Benne.instWinchSync.SyncActive` | LISIBLE? | `FB_WinchSync.st:119 = SyncActive := TRUE; ;; FB_WinchSync.st:121 = SyncActive := SyncEnable;` | SyncActive mis a TRUE ou egal a SyncEnable selon le code | verifier SyncEnable et la logique de synchro |
| `PRG_04_Treuils_Benne.SafeStopM1_Raw` | LISIBLE? | `PRG_04_Treuils_Benne.st:1062 = SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop; ;; PRG_04_Treuils_Benne.st:713 = SafeStopM1_Raw := Winc` | SafeStopM1_Raw cumulé avec instSafetyWinchM1.SafeStop et les défauts listés | Vérifier WinchContactorMismatchLvl1 M1SlipDetected Fault HomingLoss et instSafetyWinchM1 |
| `PRG_04_Treuils_Benne.SafeStopM2_Raw` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SafeStopM1_Active |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PowerCutOff` | VISIBLE | `FB_Safety_Winch.st:534 = PowerCutOff := FALSE; ;; FB_Safety_Winch.st:584 = PowerCutOff := CausesPowerCutOffActive;` | PowerCutOff selon CausesPowerCutOffActive sinon faux | Vérifier CausesPowerCutOffActive dans FB_Safety_Winch |
| `PRG_04_Treuils_Benne.SafeStopM1_Active` | VISIBLE | `PRG_04_Treuils_Benne.st:1105 = SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw);` | SafeStopM1_Active vrai si SafeStopM1_Raw ou CoupledBoth avec SafeStopM2_Raw | verifier SafeStopM1_Raw et SafeStopM2_Raw et CoupledBoth |
| `PRG_04_Treuils_Benne.WinchBothMotionReady` | LISIBLE? | `PRG_04_Treuils_Benne.st:1405 = WinchBothMotionReady := NOT (instWinchM1.DirectionChangePending OR instWinchM2.DirectionChangePending) AND NOT instWinc` | WinchBothMotionReady vrai si pas de changement de sens et pas de defaut verrouille sur M1 et M2 | verifier DirectionChangePending et Fault.Latched de instWinchM1 et instWinchM2 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1610 = WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;` | PowerCutOff copie depuis instSafetyWinchM1.PowerCutOff | verifier la sortie PowerCutOff de instSafetyWinchM1 |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop` | LISIBLE? | `PRG_04_Treuils_Benne.st:1596 = WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;` | SafeStop copie depuis SafeStopM1_Active | verifier le calcul de SafeStopM1_Active en amont |
| `PRG_06_Outputs.MaintenanceN2BrakeForceM1` | LISIBLE? | `PRG_06_Outputs.st:320 = MaintenanceN2BrakeForceM1 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2) AND PRG_02_Acquisition.HwIn.Machine.Emergen` | Mode MAINT_N2 et chaine urgence fermee et power contactor engage et bouton brake release M1 | verifier les entrees GVL_IHM et PRG_02_Acquisition en amont |

### BARRIERE (57)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R1` | LISIBLE? | `entree liee a : PRG_06_Outputs._WinchSpeedStepTable.P4R1` | Entree recue depuis : PRG_06_Outputs._WinchSpeedStepTable.P4R1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R2` | LISIBLE? | `entree liee a : PRG_06_Outputs._WinchSpeedStepTable.P4R2` | Entree recue depuis : PRG_06_Outputs._WinchSpeedStepTable.P4R2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R3` | LISIBLE? | `entree liee a : PRG_06_Outputs._WinchSpeedStepTable.P4R3` | Entree recue depuis : PRG_06_Outputs._WinchSpeedStepTable.P4R3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.SpeedStepTable.P4R4` | LISIBLE? | `entree liee a : PRG_06_Outputs._WinchSpeedStepTable.P4R4` | Entree recue depuis : PRG_06_Outputs._WinchSpeedStepTable.P4R4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.DescentStep45Permit` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.AutoDiveM1Step4M2Step5Active` | Entree recue depuis : PRG_04_Treuils_Benne.Data.AutoDiveM1Step4M2Step5Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.DescentStep5M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.DescentStep45Matched |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor1_M1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor1` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor1_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.Step1Mismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor2_M1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor2` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor2_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.Step2Mismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor3_M1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor3` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor3_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.Step3Mismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor4_M1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor4` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.Contactor4_M2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.Step4Mismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.ContactorMismatchEscalated` | LISIBLE? | `FB_SyncContactor.st:145 = ContactorMismatchEscalated := EscalationTimer.Q; ;; FB_SyncContactor.st:73 = ContactorMismatchEscalated := FALSE;` | EscalationTimer.Q vrai apres mismatch contacteurs | verifier EscalationTimer et la logique de mismatch en amont |
| `PRG_06_Outputs.instSyncContactorFinal.DescentStep45Matched` | LISIBLE? | `FB_SyncContactor.st:121 = DescentStep45Matched := DescentStep45Permit AND NOT RelayFwdM2 AND NOT RelayFwdM1 AND DescentStep4M1 AND DescentStep5M2; ;; ` | DescentStep45Permit actif et pas RelayFwdM2 ni RelayFwdM1 et DescentStep4M1 et DescentStep5M2 | verifier DescentStep45Permit RelayFwdM2 RelayFwdM1 DescentStep4M1 DescentStep5M2 en amont |
| `PRG_06_Outputs.instSyncContactorFinal.RelayFwdM1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1RelayFwd` | Entree recue depuis : PRG_06_Outputs.M1RelayFwd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.RelayFwdM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.RelayFwdMismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.RelayRevM1` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1RelayRev` | Entree recue depuis : PRG_06_Outputs.M1RelayRev | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.RelayRevM2` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSyncContactorFinal.Diag.RelayRevMismatch, PRG_06_Outputs.instSyncContactorFinal.BothCommanded |
| `PRG_06_Outputs.instSyncContactorFinal.SyncEnable` | LISIBLE? | `entree liee a : PRG_06_Outputs.WinchOutputCoupled` | Entree recue depuis : PRG_06_Outputs.WinchOutputCoupled | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.RelayFwdMismatch` | LISIBLE? | `FB_SyncContactor.st:104 = Diag.RelayFwdMismatch := (BothCommanded OR SyncEnable) AND (RelayFwdM1 <> RelayFwdM2); ;; FB_SyncContactor.st:82 = Diag.Rela` | BothCommanded ou SyncEnable et RelayFwdM1 different de RelayFwdM2 ligne 104 sinon faux ligne 82 | Chercher dans Diag.RelayFwdMismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.RelayRevMismatch` | LISIBLE? | `FB_SyncContactor.st:105 = Diag.RelayRevMismatch := (BothCommanded OR SyncEnable) AND (RelayRevM1 <> RelayRevM2); ;; FB_SyncContactor.st:83 = Diag.Rela` | BothCommanded ou SyncEnable et RelayRevM1 different de RelayRevM2 ligne 105 sinon faux ligne 83 | Chercher dans Diag.RelayRevMismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.Step1Mismatch` | LISIBLE? | `FB_SyncContactor.st:106 = Diag.Step1Mismatch := (BothCommanded OR SyncEnable) AND (Contactor1_M1 <> Contactor1_M2); ;; FB_SyncContactor.st:128 = Diag.` | BothCommanded ou SyncEnable et Contactor1_M1 different de Contactor1_M2 ligne 106 sinon faux ligne 128 | Chercher dans Diag.Step1Mismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.Step2Mismatch` | LISIBLE? | `FB_SyncContactor.st:107 = Diag.Step2Mismatch := (BothCommanded OR SyncEnable) AND (Contactor2_M1 <> Contactor2_M2); ;; FB_SyncContactor.st:129 = Diag.` | BothCommanded ou SyncEnable et Contactor2_M1 different de Contactor2_M2 ligne 107 sinon faux ligne 129 | Chercher dans Diag.Step2Mismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.Step3Mismatch` | LISIBLE? | `FB_SyncContactor.st:108 = Diag.Step3Mismatch := (BothCommanded OR SyncEnable) AND (Contactor3_M1 <> Contactor3_M2); ;; FB_SyncContactor.st:130 = Diag.` | BothCommanded ou SyncEnable et Contactor3_M1 different de Contactor3_M2 ligne 108 sinon faux ligne 130 | Chercher dans Diag.Step3Mismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.Diag.Step4Mismatch` | LISIBLE? | `FB_SyncContactor.st:109 = Diag.Step4Mismatch := (BothCommanded OR SyncEnable) AND (Contactor4_M1 <> Contactor4_M2); ;; FB_SyncContactor.st:131 = Diag.` | BothCommanded ou SyncEnable et Contactor4_M1 different de Contactor4_M2 ligne 109 sinon faux ligne 131 | Chercher dans Diag.Step4Mismatch les consommateurs en aval |
| `PRG_06_Outputs.instSyncContactorFinal.MismatchActive` | LISIBLE? | `FB_SyncContactor.st:134 = MismatchActive := Diag.RelayFwdMismatch OR Diag.RelayRevMismatch OR Diag.Step1Mismatch OR Diag.Step2Mismatch OR Diag.Step3Mi` | actif si un mismatch relay ou step est vrai | verifier Diag.RelayFwdMismatch RelayRevMismatch Step1Mismatch Step2Mismatch Step3Mismatch Step4Mismatch |
| `PRG_06_Outputs.instSyncContactorFinal.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSyncContactorFinal.MismatchTimer.Q` | VISIBLE | `FB_SyncContactor.st:140 = MismatchTimer(IN := MismatchActive, PT := MismatchDebounce); ;; FB_SyncContactor.st:80 = MismatchTimer(IN := FALSE);` | MismatchTimer.Q vrai après MismatchDebounce si MismatchActive | vérifier MismatchActive et MismatchDebounce |
| `PRG_06_Outputs.instSyncContactorFinal.ContactorMismatch` | VISIBLE | `FB_SyncContactor.st:141 = ContactorMismatch := MismatchTimer.Q; ;; FB_SyncContactor.st:72 = ContactorMismatch := FALSE;` | ContactorMismatch est MismatchTimer.Q | vérifier MismatchTimer du contacteur sync final |
| `PRG_06_Outputs.instWinchOutputInterlockM1.BrakeFeedback` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.BrakeFeedback` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.BrakeFeedback | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.FwdRevSpeedFeedbackOff` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.AscentPermit` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.DescendPermit` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.DescendPermit` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.DescendPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedStep` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedStep` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedStep | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` | LISIBLE? | `FB_WinchOutputInterlock.st:142 = ResetEdge(CLK := Reset);` | ResetEdge(CLK := Reset) | verifier la variable Reset et le front dans FB_WinchOutputInterlock |
| `PRG_06_Outputs.instWinchOutputInterlockM1.SenseHoldFeedbackTimer.Q` | LISIBLE? | `FB_WinchOutputInterlock.st:157 = SenseHoldTimer(IN := FALSE); SenseHoldFeedbackTimer(IN := FALSE); ;; FB_WinchOutputInterlock.st:290 = SenseHoldFeedba` | SenseHoldTimer et SenseHoldFeedbackTimer remis a FALSE | verifier le declenchement de Reset et DropConfirmDelay dans FB_WinchOutputInterlock |
| `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` | LISIBLE? | `FB_WinchOutputInterlock.st:317 = ContactorStuckLatched := TRUE; ;; FB_WinchOutputInterlock.st:513 = ContactorStuckLatched := FALSE;` | ContactorStuckLatched vrai ou faux selon logique FB | Verifier en aval : PRG_06_Outputs.instWinchOutputInterlockM1.Contactor1, PRG_06_Outputs.instWinchOutputInterlockM1.Contactor2 |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1InterlockEnable` | Entree recue depuis : PRG_06_Outputs.M1InterlockEnable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.PermitFinalBlocked` | LISIBLE? | `FB_WinchOutputInterlock.st:186 = PermitFinalBlocked := (RequestedRelayFwd AND NOT AscentPermit) OR (RequestedRelayRev AND NOT DescendPermit);` | relais demande sans permis correspondant | verifier AscentPermit et DescendPermit dans FB_WinchOutputInterlock |
| `PRG_06_Outputs.instWinchOutputInterlockM1.PowerContactorEngaged` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerContactorEngaged` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerContactorEngaged | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor1` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor1` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor2` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor2` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor3` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor3` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor4` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedRelayFwd` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedRelayRev` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayRev` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayRev | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.SafeStop` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` | Entree recue depuis : PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instWinchOutputInterlockM1.SenseHoldActive` | LISIBLE? | `FB_WinchOutputInterlock.st:156 = SenseHoldActive := FALSE; SenseHoldDone := FALSE; ;; FB_WinchOutputInterlock.st:288 = SenseHoldActive := FALSE; Sense` | SenseHoldActive et SenseHoldDone forces a FALSE | verifier le declenchement de Reset et SenseHoldTimer dans FB_WinchOutputInterlock |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor1` | LISIBLE? | `FB_WinchOutputInterlock.st:164 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_WinchOutputInterlock.st:348` | Contactor1 non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1SpeedContactor1 |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor2` | LISIBLE? | `FB_WinchOutputInterlock.st:164 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_WinchOutputInterlock.st:348` | Contactor2 non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1SpeedContactor2 |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor3` | LISIBLE? | `FB_WinchOutputInterlock.st:164 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_WinchOutputInterlock.st:348` | Contactor3 non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1SpeedContactor3 |
| `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor4` | LISIBLE? | `FB_WinchOutputInterlock.st:164 = Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE; ;; FB_WinchOutputInterlock.st:348` | Contactor4 non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1SpeedContactor4 |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RelayFwd` | LISIBLE? | `FB_WinchOutputInterlock.st:163 = RelayFwd := FALSE; RelayRev := FALSE; ;; FB_WinchOutputInterlock.st:347 = RelayFwd := FALSE; RelayRev := FALSE;` | RelayFwd non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1RelayFwd, PRG_06_Outputs.instWinchOutputInterlockM1.BrakeCmd |
| `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` | LISIBLE? | `FB_WinchOutputInterlock.st:163 = RelayFwd := FALSE; RelayRev := FALSE; ;; FB_WinchOutputInterlock.st:347 = RelayFwd := FALSE; RelayRev := FALSE;` | RelayRev non force a FALSE dans FB_WinchOutputInterlock | Verifier en aval : PRG_06_Outputs.M1RelayRev, PRG_06_Outputs.instWinchOutputInterlockM1.BrakeCmd |

### SORTIE (32)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_07_Supervision.instBlink1Hz.OUT` | LISIBLE? | `PRG_07_Supervision.st:117 = instBlink1Hz( ENABLE := TRUE, TIMEHIGH := _BlinkTimeOn, TIMELOW := _BlinkTimeOff );` | instBlink1Hz.OUT actif si instBlink1Hz ENABLE TRUE | Verifier en aval : GVL_Global.BlinkClock |
| `PRG_06_Outputs.WinchOutputCoupled` | LISIBLE? | `PRG_06_Outputs.st:256 = WinchOutputCoupled := (PRG_04_Treuils_Benne.Data.SyncState.SyncActive OR PRG_03_Modes_Cycle.Data.WinchBothIntent.Active) AND N` | SyncActive ou WinchBothIntent actif et MachineHoming inactif | Verifier la logique de WinchOutputCoupled et ses consommateurs |
| `PRG_06_Outputs.instM1FwdProtector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1RevProtector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc1Protector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc2Protector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc3Protector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc4Protector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.CST_ContactorMinInterval` | Entree recue depuis : PRG_06_Outputs.CST_ContactorMinInterval | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.TRUE` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instM1FwdProtector.Enable, PRG_06_Outputs.instM1RevProtector.Enable |
| `PRG_06_Outputs.instM1FwdProtector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1RelayFwd` | Entree recue depuis : PRG_06_Outputs.M1RelayFwd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1RevProtector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1RelayRev` | Entree recue depuis : PRG_06_Outputs.M1RelayRev | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc1Protector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor1` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc2Protector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor2` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc3Protector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor3` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor3 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc4Protector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.M1SpeedContactor4` | Entree recue depuis : PRG_06_Outputs.M1SpeedContactor4 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1FwdProtector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1RevProtector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc1Protector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc2Protector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc3Protector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1Sc4Protector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instM1FwdProtector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.instM1RevProtector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.instM1Sc1Protector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.instM1Sc2Protector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.instM1Sc3Protector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.instM1Sc4Protector.Cmd` | LISIBLE? | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | ActivationLatched vrai | chercher pourquoi ActivationLatched est faux dans FB_ContactorProtector |
| `PRG_06_Outputs.M1_BrakeRelease_RQ` | A CONTROLER | `PRG_06_Outputs.st:375 = M1_BrakeRelease_RQ := M1BrakeCmd;` | M1BrakeCmd actif | chercher la logique de M1BrakeCmd en amont |
| `PRG_06_Outputs.M1_RelayAscent_RQ` | A CONTROLER | `PRG_06_Outputs.st:369 = M1_RelayAscent_RQ := M1RelayFwd;` | M1RelayFwd actif | chercher la logique de M1RelayFwd en amont |
| `PRG_06_Outputs.M1_RelayDescent_RQ` | A CONTROLER | `PRG_06_Outputs.st:370 = M1_RelayDescent_RQ := M1RelayRev;` | M1RelayRev actif | chercher la logique de M1RelayRev en amont |
| `PRG_06_Outputs.M1_SpeedContactor_1_DQ` | A CONTROLER | `PRG_06_Outputs.st:371 = M1_SpeedContactor_1_DQ := M1SpeedContactor1;` | M1SpeedContactor1 actif | chercher la logique de M1SpeedContactor1 en amont |
| `PRG_06_Outputs.M1_SpeedContactor_4_DQ` | A CONTROLER | `PRG_06_Outputs.st:374 = M1_SpeedContactor_4_DQ := M1SpeedContactor4;` | M1SpeedContactor4 actif | chercher la logique de M1SpeedContactor4 en amont |

### MESURE (145)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState` | LISIBLE? | `PRG_02_Acquisition.st:161 = HwReal.Winch.COD1_DeviceState := COD1_CODEUR.GetDeviceState();` | HwReal.Winch.COD1_DeviceState affecte par COD1_CODEUR.GetDeviceState | verifier la valeur retournee par COD1_CODEUR.GetDeviceState |
| `PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1StateRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState` | Entree recue depuis : PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition._CalibM1.HomingRefRaw` | A CONTROLER | `PRG_02_Acquisition.st:644 = instEncoderM1( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, HomingPermit := (((PRG_03_Modes_Cycle.Da` | HomingRefRaw de _CalibM1 via instEncoderM1 avec HomingPermit conditionnel | Verifier en aval : PRG_02_Acquisition.instEncoderM1.Calib.HomingRefRaw |
| `PRG_02_Acquisition.HwInM1.RawPosIn` | LISIBLE? | `PRG_02_Acquisition.st:638 = HwInM1.RawPosIn := HwIn.Winch.COD1_PosValue;` | HwInM1.RawPosIn copie depuis HwIn.Winch.COD1_PosValue | Verifier en aval : PRG_02_Acquisition.instEncoderM1.HwIn.RawPosIn |
| `PRG_02_Acquisition.instDiagEthercat.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagEthercat.EncoderM1OnlineEff` | LISIBLE? | `FB_Diag_Ethercat.st:100 = EncoderM1OnlineEff := EncoderM1OnlineReal OR EncoderM1Bypass;` | EncoderM1OnlineEff calcule depuis EncoderM1OnlineReal ou EncoderM1Bypass | Verifier en aval : PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational |
| `PRG_02_Acquisition.instEncoderM1.Calib.HomingRefRaw` | LISIBLE? | `FB_Encoder.st:131 = instHoming( Enable := Enable, Reset := Reset, Home := HomingAtTargetM, HomingPermit := HomingPermit, BtnConfirmCoherence := Confir` | HomingRefRaw via instHoming dans FB_Encoder | Verifier en aval : PRG_02_Acquisition.instEncoderM1.instHoming.Calib.HomingRefRaw, PRG_02_Acquisition._CalibM1.HomingRefRaw |
| `PRG_02_Acquisition.HwInM1.PresetStatusBit` | LISIBLE? | `PRG_02_Acquisition.st:643 = HwInM1.PresetStatusBit := FALSE;` | HwInM1.PresetStatusBit affecte a FALSE | Verifier en aval : PRG_02_Acquisition.instEncoderM1.HwIn.PresetStatusBit |
| `PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational` | LISIBLE? | `FB_Diag_Ethercat.st:136 = DeviceEncoderM1.Operational := EncoderM1OnlineEff; ;; FB_Diag_Ethercat.st:72 = DeviceEncoderM1.Operational := FALSE;` | DeviceEncoderM1.Operational suit EncoderM1OnlineEff | Verifier en aval : PRG_02_Acquisition.HwInM1.SlaveOperational |
| `PRG_02_Acquisition.instEncoderM1.HwIn.RawPosIn` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwInM1.RawPosIn` | Entree recue depuis : PRG_02_Acquisition.HwInM1.RawPosIn | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_IHM.Commun.EncoderCfg.PresetConfirmMode` | LISIBLE? | `PRG_07_Supervision.st:231 = instCfgPersistBridgeEncoder(Hmi := GVL_IHM.Commun.EncoderCfg, Persist := _EncoderCfgPersist);` | PresetConfirmMode alimente par instCfgPersistBridgeEncoder | verifier _EncoderCfgPersist et le bridge en aval |
| `PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineHomingMechanicalStopOk |
| `PRG_02_Acquisition.ENCODER_POINTS_PER_REV` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instEncoderM1.PointsPerRev |
| `PRG_02_Acquisition._CalibM1.LastKnownRawPos` | A CONTROLER | `PRG_02_Acquisition.st:644 = instEncoderM1( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, HomingPermit := (((PRG_03_Modes_Cycle.Da` | instEncoderM1 appele avec Enable TRUE et Reset FaultMachineReset_IHM | Verifier en aval : PRG_02_Acquisition.instEncoderM1.Calib.LastKnownRawPos |
| `PRG_02_Acquisition.instEncoderM1.HwIn.PresetStatusBit` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwInM1.PresetStatusBit` | Entree recue depuis : PRG_02_Acquisition.HwInM1.PresetStatusBit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition._CalibM1.RestartCoherenceTolerancePts` | A CONTROLER | `PRG_02_Acquisition.st:644 = instEncoderM1( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, HomingPermit := (((PRG_03_Modes_Cycle.Da` | instEncoderM1 active avec Reset HomingPermit et tolerance de coherence | verifier les sorties de instEncoderM1 en aval |
| `PRG_02_Acquisition.instEncoderM1.Calib.LastKnownRawPos` | LISIBLE? | `FB_Encoder.st:131 = instHoming( Enable := Enable, Reset := Reset, Home := HomingAtTargetM, HomingPermit := HomingPermit, BtnConfirmCoherence := Confir` | LastKnownRawPos alimente par instHoming avec cible SEL | verifier instHoming et la selection de cible en aval |
| `PRG_02_Acquisition.instEncoderM1.ConfirmCoherence` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.HomingAtTargetM` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Cmd.BtnHome, GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition.instCycleMachineHoming.M1Demand.H` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Cmd.BtnHome, GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition.instCycleMachineHoming.M1Demand.HomeReq | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.HwIn.AlarmsIn` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwInM1.AlarmsIn` | Entree recue depuis : PRG_02_Acquisition.HwInM1.AlarmsIn | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.HwIn.SlaveOperational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwInM1.SlaveOperational` | Entree recue depuis : PRG_02_Acquisition.HwInM1.SlaveOperational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.PointsPerRev` | LISIBLE? | `entree liee a : PRG_02_Acquisition.ENCODER_POINTS_PER_REV` | Entree recue depuis : PRG_02_Acquisition.ENCODER_POINTS_PER_REV | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.TopPositionSensor` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.HwInM1.SpdValueIn` | LISIBLE? | `PRG_02_Acquisition.st:639 = HwInM1.SpdValueIn := HwIn.Winch.COD1_SpdValue;` | SpdValueIn de HwInM1 affecte depuis HwIn.Winch.COD1_SpdValue | Verifier en aval : PRG_02_Acquisition.instEncoderM1.HwIn.SpdValueIn |
| `PRG_02_Acquisition.HwReal.Operator.CanBusState` | LISIBLE? | `PRG_02_Acquisition.st:185 = HwReal.Operator.CanBusState := CANbus.GetBusState();` | CanBusState de HwReal.Operator affecte depuis CANbus.GetBusState | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.CANbusStateRaw |
| `PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` | LISIBLE? | `PRG_02_Acquisition.st:186 = HwReal.Operator.JOY1_DeviceState := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();` | JOY1_DeviceState affecte depuis GetDeviceState du joystick MCB560 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickStateRaw |
| `PRG_02_Acquisition.HwSim.Operator` | LISIBLE? | `PRG_02_Acquisition.st:436 = HwSim.Operator := instSimBench.Operator;` | HwSim.Operator affecte depuis instSimBench.Operator | Verifier en aval : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1, PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2 |
| `PRG_02_Acquisition.instEncoderM1.Calib.RestartCoherenceTolerancePts` | LISIBLE? | `FB_Encoder.st:131 = instHoming( Enable := Enable, Reset := Reset, Home := HomingAtTargetM, HomingPermit := HomingPermit, BtnConfirmCoherence := Confir` | Calib.RestartCoherenceTolerancePts de instEncoderM1 lie au homing | Verifier en aval : PRG_02_Acquisition.instEncoderM1.instHoming.Calib.RestartCoherenceTolerancePts, PRG_02_Acquisition._CalibM1.RestartCoherenceTolerancePts |
| `PRG_02_Acquisition.instEncoderM1.HomingAtZero` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.HomingPermit` | LISIBLE? | `entree liee a : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI, PRG_02_Acquisition.MachineHomingMe` | Entree recue depuis : GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI, PRG_02_Acquisition.MachineHomingMechanicalStopOk | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.UseDynamicTarget` | LISIBLE? | `entree liee a : PRG_02_Acquisition.FALSE` | Entree recue depuis : PRG_02_Acquisition.FALSE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.instAbs.SlaveOperational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instEncoderM1.HwIn.SlaveOperational` | Entree recue depuis : PRG_02_Acquisition.instEncoderM1.HwIn.SlaveOperational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.instHoming.BtnConfirmCoherence` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instEncoderM1.ConfirmCoherence` | Entree recue depuis : PRG_02_Acquisition.instEncoderM1.ConfirmCoherence | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.instHoming.Home` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instEncoderM1.HomingAtTargetM` | Entree recue depuis : PRG_02_Acquisition.instEncoderM1.HomingAtTargetM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_04_Treuils_Benne.BucketBusyRiseEdge.Q` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ControlAscentArmedForThisClose |
| `PRG_07_Supervision.instCfgT330Normalizer.CommunCfg.LimitLegalDepthMinAllowed_M` | LISIBLE? | `entree liee a : GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M` | Entree recue depuis : GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.instCfgT330Normalizer.CommunCfg.LimitLegalEnabled` | LISIBLE? | `entree liee a : GVL_IHM.Commun.Cfg.LimitLegalEnabled` | Entree recue depuis : GVL_IHM.Commun.Cfg.LimitLegalEnabled | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` | VISIBLE | `PRG_02_Acquisition.st:483 = HwIn.Operator := SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator);` | JoyXRaw_ANA1 affecte par SEL selon OperatorInputSourceSimulated | Verifier les consommateurs de HwIn.Operator.JoyXRaw_ANA1 |
| `PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` | VISIBLE | `PRG_02_Acquisition.st:483 = HwIn.Operator := SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator);` | JoyYRaw_ANA2 affecte par SEL selon OperatorInputSourceSimulated | Verifier les consommateurs de HwIn.Operator.JoyYRaw_ANA2 |
| `PRG_02_Acquisition._JoystickNeutralX` | A CONTROLER | `PRG_02_Acquisition.st:496 = instJoystick( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, ArmingPermit := PRG_04_Treuils_Benne.Data` | _JoystickNeutralX issu de instJoystick avec Enable TRUE | Verifier les consommateurs de _JoystickNeutralX |
| `PRG_02_Acquisition._JoystickNeutralY` | A CONTROLER | `PRG_02_Acquisition.st:496 = instJoystick( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, ArmingPermit := PRG_04_Treuils_Benne.Data` | _JoystickNeutralY issu de instJoystick avec Enable TRUE | Verifier les consommateurs de _JoystickNeutralY |
| `PRG_02_Acquisition.instDiagCanOpen.CANbusStateRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwReal.Operator.CanBusState` | Entree recue depuis : PRG_02_Acquisition.HwReal.Operator.CanBusState | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickStateRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` | Entree recue depuis : PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.CableM_PerRev` | LISIBLE? | `entree liee a : PRG_02_Acquisition.WINCH_CABLE_M_PER_REV` | Entree recue depuis : PRG_02_Acquisition.WINCH_CABLE_M_PER_REV | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.HomedAndReliable` | LISIBLE? | `FB_Encoder.st:216 = HomedAndReliable := instRel.HomedAndReliable; ;; FB_Encoder.st:95 = HomedAndReliable := FALSE;` | HomedAndReliable issu de instRel.HomedAndReliable | Verifier les consommateurs de HomedAndReliable de instEncoderM1 |
| `PRG_02_Acquisition.instEncoderM1.HwIn.SpdValueIn` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwInM1.SpdValueIn` | Entree recue depuis : PRG_02_Acquisition.HwInM1.SpdValueIn | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.instAbs.instCauses.Active` | LISIBLE? | `FB_Encoder_Abs.st:75 = instCauses[0].Active := (AlarmsIn <> 0) OR NOT SlaveOperational; ;; FB_Encoder_Abs.st:83 = instCauses[1].Active := PresetTimeou` | Active des causes issu de AlarmsIn ou SlaveOperational ou PresetTimeoutError | Verifier les consommateurs de instCauses.Active dans instAbs |
| `PRG_02_Acquisition.instEncoderM1.instHoming.ConfirmCoherenceEdge.Q` | LISIBLE? | `FB_Encoder_Homing.st:119 = ConfirmCoherenceEdge(CLK := BtnConfirmCoherence);` | BtnConfirmCoherence front montant | verifier ConfirmCoherenceEdge.Q vers le homing |
| `PRG_02_Acquisition.instEncoderM1.instHoming.HomingPermit` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instEncoderM1.HomingPermit` | Entree recue depuis : PRG_02_Acquisition.instEncoderM1.HomingPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.instHoming.NominalHomingTrigger` | LISIBLE? | `FB_Encoder_Homing.st:206 = NominalHomingTrigger := HomingModeOk AND NOT UseDynamicTarget AND ((Home AND TopSensorEdge.Q) OR (HomeEdge.Q AND TopPositio` | HomingModeOk et pas UseDynamicTarget et Home avec TopSensorEdge ou HomeEdge avec TopPositionSensor | verifier NominalHomingTrigger vers la sequence de homing |
| `PRG_04_Treuils_Benne.ControlAscentStartM1PosM` | LISIBLE? | `PRG_04_Treuils_Benne.st:597 = ControlAscentStartM1PosM := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM;` | lecture CablePosM de EncoderM1 | verifier ControlAscentStartM1PosM vers la regulation |
| `PRG_04_Treuils_Benne.ControlAscentStartM2PosM` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ExtractionControlActive |
| `PRG_07_Supervision.instDiagIhmHeartbeat.IhmEdgeDetected` | LISIBLE? | `FB_Diag_IhmHeartbeat.st:53 = IhmEdgeDetected := (TglHeartbeatIhm <> LastIhmToggle);` | detection de front sur le toggle heartbeat IHM | Verifier en aval : PRG_07_Supervision.instDiagIhmHeartbeat.IhmTimeoutTon.Q |
| `PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable` | LISIBLE? | `PRG_02_Acquisition.st:682 = Data.EncoderM1.HomedAndReliable := instEncoderM1.HomedAndReliable;` | HomedAndReliable reflete instEncoderM1.HomedAndReliable | verifier instEncoderM1.HomedAndReliable en amont |
| `PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.CommonMaxStepAscent, PRG_04_Treuils_Benne.CommonMaxStepDescent |
| `PRG_02_Acquisition._CalibM1.Homed` | A CONTROLER | `PRG_02_Acquisition.st:644 = instEncoderM1( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, HomingPermit := (((PRG_03_Modes_Cycle.Da` | _CalibM1.Homed issu de instEncoderM1 avec Enable TRUE et HomingPermit calcule | verifier HomingPermit et la sequence de homing M1 |
| `PRG_02_Acquisition._CalibM1.HomingSuspect` | A CONTROLER | `PRG_02_Acquisition.st:644 = instEncoderM1( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, HomingPermit := (((PRG_03_Modes_Cycle.Da` | _CalibM1.HomingSuspect issu de instEncoderM1 avec Enable TRUE et HomingPermit calcule | verifier HomingPermit et la sequence de homing M1 |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational` | VISIBLE | `FB_Diag_CanOpen.st:130 = DeviceCanOpenMaster.Operational := CANbusOnlineEff; ;; FB_Diag_CanOpen.st:56 = DeviceCanOpenMaster.Operational := FALSE;` | DeviceCanOpenMaster.Operational depend de CANbusOnlineEff ou force a FALSE | verifier CANbusOnlineEff et la logique de diagnostic CANopen |
| `PRG_02_Acquisition.instEncoderM1.instAbs.EncoderAvailable` | LISIBLE? | `FB_Encoder_Abs.st:91 = EncoderAvailable := NOT instCauses[0].Active; ;; FB_Encoder_Abs.st:97 = EncoderAvailable := FALSE;` | EncoderAvailable resulte de NOT instCauses[0].Active sinon FALSE | verifier instCauses du FB_Encoder_Abs |
| `PRG_02_Acquisition.instEncoderM1.instHoming.Calib.HomingSuspect` | VISIBLE | `FB_Encoder_Homing.st:131 = Calib.HomingSuspect := FALSE; ;; FB_Encoder_Homing.st:185 = Calib.HomingSuspect := TRUE;` | HomingSuspect mis a TRUE ou FALSE selon sequence de homing | verifier la sequence instHoming du FB_Encoder_Homing |
| `PRG_02_Acquisition.instEncoderM1.instHoming.HomingTrigger` | LISIBLE? | `FB_Encoder_Homing.st:213 = HomingTrigger := (NominalHomingTrigger OR UnitaryHomingTrigger OR DynamicHomingTrigger) AND NOT PresetVerificationActive;` | HomingTrigger combine triggers nominal unitaire dynamique et non PresetVerificationActive | verifier les triggers et PresetVerificationActive |
| `PRG_02_Acquisition.instEncoderM1.instHoming.TargetPositionM` | LISIBLE? | `FB_Encoder_Homing.st:218 = TargetPositionM := DynamicHomingTargetM; ;; FB_Encoder_Homing.st:220 = TargetPositionM := CfgTopSensorPosM;` | TargetPositionM vaut DynamicHomingTargetM ou CfgTopSensorPosM | verifier DynamicHomingTargetM et CfgTopSensorPosM |
| `PRG_05_Translation.Data.M3_AtMaintenanceStable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.CommonMaxStepAscent, PRG_04_Treuils_Benne.CommonMaxStepDescent |
| `PRG_07_Supervision.instDiagIhmHeartbeat.IhmTimeoutTon.Q` | VISIBLE | `FB_Diag_IhmHeartbeat.st:45 = IhmTimeoutTon(IN := FALSE, PT := IhmTimeout); ;; FB_Diag_IhmHeartbeat.st:63 = IhmTimeoutTon(IN := NOT IhmEdgeDetected, PT` | IhmTimeoutTon.Q selon IN et IhmTimeout | Verifier les consommateurs de IhmTimeoutTon.Q dans PRG_07_Supervision |
| `PRG_02_Acquisition.Data.Joystick.AxisY.Direction` | VISIBLE | `PRG_02_Acquisition.st:530 = Data.Joystick.AxisY := instJoystick.AxisCmdY;` | Direction de l'axe Y joystick est affectée depuis AxisCmdY | Vérifier le calcul de AxisCmdY dans instJoystick |
| `PRG_02_Acquisition.instDiagCanOpen.CANbusOnlineEff` | VISIBLE | `FB_Diag_CanOpen.st:70 = CANbusOnlineEff := CANbusOnlineReal OR SimBypassActive OR NetworkBypassActive OR CanBusBypassActive;` | CANbusOnlineEff est vrai si CANbusOnlineReal ou un bypass est actif | Vérifier les sources de bypass et CANbusOnlineReal |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickOnlineEff` | LISIBLE? | `FB_Diag_CanOpen.st:71 = DeviceJoystickOnlineEff := DeviceJoystickOnlineReal OR SimBypassActive OR NetworkBypassActive OR JoystickBypassActive;` | DeviceJoystickOnlineEff est vrai si le réel ou un bypass est actif | Vérifier JoystickBypassActive et les autres bypass |
| `PRG_02_Acquisition.instEncoderM1.Calib.Homed` | VISIBLE | `FB_Encoder.st:131 = instHoming( Enable := Enable, Reset := Reset, Home := HomingAtTargetM, HomingPermit := HomingPermit, BtnConfirmCoherence := Confir` | Homed est calculé par instHoming avec Enable et les paramètres de homing | Vérifier le retour de instHoming et HomingPermit |
| `PRG_02_Acquisition.instEncoderM1.Calib.HomingSuspect` | VISIBLE | `FB_Encoder.st:131 = instHoming( Enable := Enable, Reset := Reset, Home := HomingAtTargetM, HomingPermit := HomingPermit, BtnConfirmCoherence := Confir` | HomingSuspect est calculé par instHoming avec Enable et les paramètres de homing | Vérifier le retour de instHoming et ConfirmCoherence |
| `PRG_02_Acquisition.instEncoderM1.Measurement.EncoderAvailable` | LISIBLE? | `FB_Encoder.st:195 = Measurement.EncoderAvailable := instAbs.EncoderAvailable; ;; FB_Encoder.st:88 = Measurement.RawPos := 0; Measurement.EncoderAvaila` | EncoderAvailable vient de instAbs.EncoderAvailable et est forcé FALSE si non dispo | Vérifier instAbs.EncoderAvailable en amont |
| `PRG_02_Acquisition.instEncoderM1.instHoming.PresetVerificationActive` | VISIBLE | `FB_Encoder_Homing.st:167 = PresetVerificationActive := FALSE; ;; FB_Encoder_Homing.st:233 = PresetVerificationActive := TRUE;` | PresetVerificationActive est FALSE par défaut puis TRUE selon la logique de homing | Vérifier la condition de passage à TRUE dans FB_Encoder_Homing |
| `PRG_04_Treuils_Benne.M1WinchSensors.CablePosM` | LISIBLE? | `PRG_04_Treuils_Benne.st:1421 = M1WinchSensors.CablePosM := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM;` | CablePosM vient de Data.EncoderM1.Measurement.CablePosM | Vérifier la mesure CablePosM de l'encodeur M1 |
| `PRG_04_Treuils_Benne.M1WinchSensors.Homed` | LISIBLE? | `PRG_04_Treuils_Benne.st:1422 = M1WinchSensors.Homed := PRG_02_Acquisition.Data.EncoderM1.Homed;` | Homed vient de Data.EncoderM1.Homed | Vérifier l'état Homed de l'encodeur M1 |
| `PRG_04_Treuils_Benne.M1WinchSensors.HomingSuspect` | LISIBLE? | `PRG_04_Treuils_Benne.st:1423 = M1WinchSensors.HomingSuspect := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect;` | HomingSuspect vient de Data.EncoderM1.HomingSuspect | Vérifier l'état HomingSuspect de l'encodeur M1 |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable` | LISIBLE? | `PRG_02_Acquisition.st:676 = Data.EncoderM1.Measurement := instEncoderM1.Measurement;` | EncoderM1.Measurement copié depuis instEncoderM1.Measurement | vérifier instEncoderM1, notamment CablePosM et EncoderIncoherent |
| `PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | HwIn.Machine = SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine) | vérifier MachineInputSourceSimulated et HwReal/HwSim Machine |
| `PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI` | VISIBLE | `PRG_02_Acquisition.st:481 = HwIn.Winch := SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch);` | HwIn.Winch = SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch) | vérifier WinchInputSourceSimulated et HwReal/HwSim Winch |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Online` | LISIBLE? | `FB_Diag_CanOpen.st:50 = DeviceJoystick.Online := FALSE; ;; FB_Diag_CanOpen.st:99 = DeviceJoystick.Online := TRUE;` | DeviceJoystick.Online selon diagnostic CanOpen | vérifier FB_Diag_CanOpen DeviceJoystick Online |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational` | VISIBLE | `FB_Diag_CanOpen.st:106 = DeviceJoystick.Operational := FALSE; ;; FB_Diag_CanOpen.st:108 = DeviceJoystick.Operational := TRUE;` | DeviceJoystick.Operational selon diagnostic CanOpen | vérifier FB_Diag_CanOpen DeviceJoystick Operational |
| `PRG_02_Acquisition.instEncoderM1.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instEncoderM1.Homed` | VISIBLE | `FB_Encoder.st:101 = Homed := Calib.Homed; ;; FB_Encoder.st:213 = Homed := instHoming.Homed;` | instEncoderM1.Homed depuis Calib.Homed ou instHoming.Homed | vérifier Calib et instHoming de FB_Encoder |
| `PRG_02_Acquisition.instEncoderM1.HomingSuspect` | VISIBLE | `FB_Encoder.st:102 = HomingSuspect := Calib.HomingSuspect; ;; FB_Encoder.st:214 = HomingSuspect := instHoming.HomingSuspect;` | instEncoderM1.HomingSuspect depuis Calib ou instHoming | vérifier Calib et instHoming de FB_Encoder |
| `PRG_02_Acquisition.instEncoderM1.Measurement.CablePosM` | VISIBLE | `FB_Encoder.st:196 = Measurement.CablePosM := instSafety.CablePosMSafe; ;; FB_Encoder.st:89 = Measurement.CablePosM := 0.0; Measurement.CablePosMSafe :` | instEncoderM1.Measurement.CablePosM depuis instSafety.CablePosMSafe | vérifier instSafety.CablePosMSafe et EncoderIncoherent |
| `PRG_02_Acquisition.instEncoderM1.instHoming.Lifecycle.Busy` | VISIBLE | `FB_Encoder_Homing.st:164 = Lifecycle.Busy := FALSE; ;; FB_Encoder_Homing.st:289 = Lifecycle.Busy := PresetVerificationActive;` | instEncoderM1.instHoming.Lifecycle.Busy selon PresetVerificationActive | vérifier PresetVerificationActive de FB_Encoder_Homing |
| `PRG_07_Supervision.instDiagIhmHeartbeat.HeartbeatIhmOk` | VISIBLE | `FB_Diag_IhmHeartbeat.st:39 = HeartbeatIhmOk := FALSE; ;; FB_Diag_IhmHeartbeat.st:66 = HeartbeatIhmOk := NOT HeartbeatIhmTimeout;` | HeartbeatIhmOk est FALSE par défaut puis calculé par NOT HeartbeatIhmTimeout | Vérifier le calcul de HeartbeatIhmTimeout en amont |
| `GVL_IHM.Commun.HeartbeatIhmOk` | VISIBLE | `PRG_07_Supervision.st:425 = GVL_IHM.Commun.HeartbeatIhmOk := instDiagIhmHeartbeat.HeartbeatIhmOk;` | HeartbeatIhmOk depuis instDiagIhmHeartbeat | vérifier instDiagIhmHeartbeat.HeartbeatIhmOk |
| `PRG_02_Acquisition.Data.EncoderM1.Homed` | VISIBLE | `PRG_02_Acquisition.st:679 = Data.EncoderM1.Homed := instEncoderM1.Homed;` | Homed depuis instEncoderM1.Homed | vérifier instEncoderM1.Homed |
| `PRG_02_Acquisition.Data.EncoderM1.HomingSuspect` | VISIBLE | `PRG_02_Acquisition.st:680 = Data.EncoderM1.HomingSuspect := instEncoderM1.HomingSuspect;` | HomingSuspect depuis instEncoderM1.HomingSuspect | vérifier instEncoderM1.HomingSuspect |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM` | VISIBLE | `PRG_02_Acquisition.st:676 = Data.EncoderM1.Measurement := instEncoderM1.Measurement;` | CablePosM depuis instEncoderM1.Measurement | vérifier instEncoderM1.Measurement |
| `PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.KoboldImmersionConfirmed, GVL_IHM.Commun.LimitLegalReached |
| `PRG_02_Acquisition.Data.Network.Joystick.Online` | LISIBLE? | `PRG_02_Acquisition.st:279 = Data.Network.Joystick := instDiagCanOpen.DeviceJoystick;` | Joystick Online depuis instDiagCanOpen.DeviceJoystick | vérifier instDiagCanOpen.DeviceJoystick |
| `PRG_02_Acquisition.Data.Network.Joystick.Operational` | VISIBLE | `PRG_02_Acquisition.st:279 = Data.Network.Joystick := instDiagCanOpen.DeviceJoystick;` | Joystick Operational depuis instDiagCanOpen.DeviceJoystick | vérifier instDiagCanOpen.DeviceJoystick |
| `PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.KoboldAutoStopFallEdge.Q, PRG_04_Treuils_Benne.KoboldAutoStopRiseEdge.Q |
| `PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.TopPositionSensor, PRG_02_Acquisition.instEncoderM1.HomingPermit |
| `PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.SlackCableDetected, PRG_04_Treuils_Benne.SlackCableAscentCapStep1 |
| `PRG_02_Acquisition.instCycleMachineHoming.MachineHomingActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.Data.MachineHoming.Active |
| `PRG_02_Acquisition.instEncoderM1.Measurement.HomingLifecycle.Busy` | VISIBLE | `FB_Encoder.st:203 = Measurement.HomingLifecycle := instHoming.Lifecycle; ;; FB_Encoder.st:92 = Measurement.HomingLifecycle.Busy := FALSE; Measurement.` | Busy depuis instHoming.Lifecycle | vérifier instHoming.Lifecycle |
| `PRG_02_Acquisition.instEncoderM1.Measurement.SpeedValid` | LISIBLE? | `FB_Encoder.st:201 = Measurement.SpeedValid := instSpeed.Valid; ;; FB_Encoder.st:90 = Measurement.Speed_Mps := 0.0; Measurement.SignedSpeed_Mps := 0.0;` | SpeedValid depuis instSpeed.Valid | vérifier instSpeed.Valid |
| `PRG_02_Acquisition.instEncoderM1.Measurement.Speed_Mps` | LISIBLE? | `FB_Encoder.st:199 = Measurement.Speed_Mps := instSpeed.Speed_Mps; ;; FB_Encoder.st:90 = Measurement.Speed_Mps := 0.0; Measurement.SignedSpeed_Mps := 0` | Speed_Mps depuis instSpeed.Speed_Mps | vérifier instSpeed.Speed_Mps |
| `PRG_04_Treuils_Benne.KoboldAutoStopRiseEdge.Q` | LISIBLE? | `PRG_04_Treuils_Benne.st:720 = KoboldAutoStopRiseEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);` | front montant sur entree DI KoboldBottomTouch M1_M2 | verifier la source de PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI |
| `PRG_04_Treuils_Benne._BucketState.IsOpen` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.KoboldImmersionConfirmed |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy` | VISIBLE | `PRG_02_Acquisition.st:676 = Data.EncoderM1.Measurement := instEncoderM1.Measurement;` | HomingLifecycle.Busy copié depuis instEncoderM1.Measurement | vérifier instEncoderM1.Measurement.HomingLifecycle.Busy |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid` | LISIBLE? | `PRG_02_Acquisition.st:676 = Data.EncoderM1.Measurement := instEncoderM1.Measurement;` | SpeedValid copié depuis instEncoderM1.Measurement | vérifier instEncoderM1.Measurement.SpeedValid |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps` | LISIBLE? | `PRG_02_Acquisition.st:676 = Data.EncoderM1.Measurement := instEncoderM1.Measurement;` | Speed_Mps copié depuis instEncoderM1.Measurement | vérifier instEncoderM1.Measurement.Speed_Mps |
| `PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.SyncOperationPermit |
| `PRG_02_Acquisition.M1M2_TopPositionFree_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M1_ThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M2_TensionedCable_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M2_ThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.instSimBench.Winch` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Winch |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R1` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P2R2 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P2R3 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P2R4 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P2R4` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P3R1 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R1` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P3R2 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P3R3 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P3R4 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P3R4` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P4R1 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R1` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P4R2 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P4R3 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P4R4 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P4R4` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P5R1 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R1` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P5R2 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R2` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P5R3 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R3` | LISIBLE? | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier P5R4 et la cohérence de _WinchSpeedStepTable |
| `PRG_04_Treuils_Benne.M1WinchCfg.SpeedStepTable.P5R4` | VISIBLE | `PRG_04_Treuils_Benne.st:1444 = M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable;` | M1WinchCfg.SpeedStepTable est affecté par _WinchSpeedStepTable | vérifier la fin de _WinchSpeedStepTable |
| `PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk` | LISIBLE? | `PRG_02_Acquisition.st:205 = Data.InputModules.LocalDigitalIoOk := TRUE; ;; PRG_02_Acquisition.st:211 = Data.InputModules.LocalDigitalIoOk := (Local_Di` | Local_Digital_IO en etat RUNNING ou TRUE selon le code | verifier l etat du device Local_Digital_IO |
| `PRG_02_Acquisition.Data.InputModules.Vh0008Er1Ok` | LISIBLE? | `PRG_02_Acquisition.st:209 = Data.InputModules.Vh0008Er1Ok := TRUE; ;; PRG_02_Acquisition.st:215 = Data.InputModules.Vh0008Er1Ok := (VH_0008ER_1.GetDev` | VH_0008ER_1 en etat RUNNING ou TRUE selon le code | verifier l etat du device VH_0008ER_1 |
| `PRG_02_Acquisition.Data.InputModules.Vh0008ErOk` | LISIBLE? | `PRG_02_Acquisition.st:208 = Data.InputModules.Vh0008ErOk := TRUE; ;; PRG_02_Acquisition.st:214 = Data.InputModules.Vh0008ErOk := (VH_0008ER.GetDeviceS` | VH_0008ER en etat RUNNING ou TRUE selon le code | verifier l etat du device VH_0008ER |
| `PRG_02_Acquisition.Data.InputModules.Vh0800EndOk` | LISIBLE? | `PRG_02_Acquisition.st:206 = Data.InputModules.Vh0800EndOk := TRUE; ;; PRG_02_Acquisition.st:212 = Data.InputModules.Vh0800EndOk := (VH_0800END.GetDevi` | VH_0800END en etat RUNNING ou TRUE selon le code | verifier l etat du device VH_0800END |
| `PRG_02_Acquisition.Data.InputModules.Vh0808EtpOk` | LISIBLE? | `PRG_02_Acquisition.st:207 = Data.InputModules.Vh0808EtpOk := TRUE; ;; PRG_02_Acquisition.st:213 = Data.InputModules.Vh0808EtpOk := (VH_0808ETP.GetDevi` | VH_0808ETP en etat RUNNING ou TRUE selon le code | verifier l etat du device VH_0808ETP |
| `PRG_02_Acquisition.HwReal.Winch` | LISIBLE? | `PRG_02_Acquisition.st:146 = HwReal.Winch.M1_ContactorsReleased_DI := M2_ContactorsReleased_DI; ;; PRG_02_Acquisition.st:147 = HwReal.Winch.M1_ThermalO` | affectation de M2_ContactorsReleased_DI et M1_ThermalOk_DI dans HwReal.Winch | verifier le cablage des entrees treuil |
| `PRG_02_Acquisition.HwSim.Winch` | LISIBLE? | `PRG_02_Acquisition.st:420 = HwSim.Winch := instSimBench.Winch;` | HwSim.Winch copie de instSimBench.Winch | verifier instSimBench.Winch en simulation |
| `PRG_02_Acquisition.ConveyorInfeedReady_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.EmergencyChainClosed_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HydraulicThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PhaseRotationOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.instSimBench.Machine` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Machine |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerContactorEngaged` | LISIBLE? | `PRG_04_Treuils_Benne.st:1595 = WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;` | PowerContactorEngaged lu depuis HwIn.Machine.PowerContactorEngaged_DI | verifier la valeur de l entree DI PowerContactorEngaged |
| `PRG_02_Acquisition.HwReal.Machine` | LISIBLE? | `PRG_02_Acquisition.st:189 = HwReal.Machine.PowerContactorEngaged_DI := PowerContactorEngaged_DI; ;; PRG_02_Acquisition.st:190 = HwReal.Machine.Emergen` | PowerContactorEngaged_DI et EmergencyChainClosed_DI affectes a HwReal.Machine | verifier les entrees PowerContactorEngaged_DI et EmergencyChainClosed_DI |
| `PRG_02_Acquisition.HwSim.Machine` | LISIBLE? | `PRG_02_Acquisition.st:437 = HwSim.Machine := instSimBench.Machine;` | HwSim.Machine affecte depuis instSimBench.Machine | verifier instSimBench.Machine |
| `PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | MachineInputSourceSimulated choisit HwReal ou HwSim | verifier HwReal.Machine et HwSim.Machine en amont |

### RETOUR (17)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineHomingMechanicalStopOk |
| `PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineHomingMechanicalStopOk |
| `PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.instSafetyWinchM1.BrakeThermalFeedback |
| `PRG_02_Acquisition.M1_BrakeIsOpen_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M1_ContactorsReleased_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M2_BrakeIsOpen_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.M2_ContactorsReleased_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Winch |
| `PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI` | VISIBLE | `PRG_02_Acquisition.st:481 = HwIn.Winch := SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch);` | Brake M1 selon SEL entre HwReal et HwSim | Vérifier WinchInputSourceSimulated et la source réelle |
| `PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI` | VISIBLE | `PRG_02_Acquisition.st:481 = HwIn.Winch := SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch);` | ContactorsReleased M1 selon SEL entre HwReal et HwSim | Vérifier WinchInputSourceSimulated et la source réelle |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeFeedback` | LISIBLE? | `PRG_04_Treuils_Benne.st:1601 = WinchM1FinalInterlockRequest.BrakeFeedback := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI;` | BrakeFeedback M1 depuis M1_BrakeIsOpen_DI | Vérifier la source simulée ou réelle du HwIn.Winch |
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1602 = WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI;` | FwdRevSpeedFeedbackOff M1 depuis M1_ContactorsReleased_DI | Vérifier la source simulée ou réelle du HwIn.Winch |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.BrakeFeedback` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie BrakeFeedback copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de BrakeFeedback en amont |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | sortie FwdRevSpeedFeedbackOff copiee depuis WinchM1FinalInterlockRequest | verifier la valeur source de FwdRevSpeedFeedbackOff en amont |
| `PRG_07_Supervision.FaultMachineReset_IHM` | LISIBLE? | `PRG_07_Supervision.st:138 = FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset OR GVL_IHM.M2TreuilBenne.` | FaultMachineReset_IHM vrai si un des cinq boutons reset IHM est vrai | Vérifier les cinq entrées GVL_IHM citées dans l'expression |
| `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PowerContactorEngaged_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | MachineInputSourceSimulated choisit HwReal ou HwSim | verifier HwReal.Machine et HwSim.Machine en amont |

## 3. Arbre par commande (chemin le plus court vers une sortie)

Parcours de haut en bas : si la valeur attendue s'arrête à un maillon, chercher dans la colonne `Si dernier vrai` du maillon. Les autres branches sont dans `edges` du graphe.

### `GVL_IHM.CycleSemiAuto.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — LISIBLE?
2. **RETOUR** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.JOY1Joystick.Cmd.Calibrate`

1. **SOURCE** `GVL_IHM.JOY1Joystick.Cmd.Calibrate` — LISIBLE?
2. **SOURCE** `PRG_02_Acquisition.instJoystick.Calibrate` — LISIBLE?
3. **SOURCE** `PRG_02_Acquisition.instJoystick.NeutralYMem` — LISIBLE?
4. **SOURCE** `PRG_02_Acquisition.instJoystick.ScaleY.Neutral` — LISIBLE?
5. **SOURCE** `PRG_02_Acquisition.instJoystick.ScaleY.OutPct` — LISIBLE?
6. **SOURCE** `PRG_02_Acquisition.instJoystick.AtNeutralXY` — VISIBLE
7. **ARBITRAGE** `PRG_02_Acquisition.Data.Joystick.AtNeutralXY` — VISIBLE
8. **SECURITE** `PRG_04_Treuils_Benne.KoboldBottomTouchLatched` — VISIBLE
9. **PERMIS** `PRG_04_Treuils_Benne.ProcessPermitM1_Descend` — VISIBLE
10. **PERMIS** `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Descend` — LISIBLE?
11. **PERMIS** `PRG_04_Treuils_Benne.EffectivePermitM1_Descend` — VISIBLE
12. **PERMIS** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.DescendPermit` — LISIBLE?
13. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.DescendPermit` — LISIBLE?
14. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.DescendPermit` — LISIBLE?
15. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.PermitFinalBlocked` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor1` — LISIBLE?
17. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor1` — LISIBLE?
18. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_1_DQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent` — VISIBLE
2. **DEMANDE** `PRG_04_Treuils_Benne.ArbIHM.BtnAscentM1` — LISIBLE?
3. **ARBITRAGE** `PRG_04_Treuils_Benne.instArbM1.IHM.BtnAscentM1` — LISIBLE?
4. **ARBITRAGE** `PRG_04_Treuils_Benne.instArbM1.ReqAscent` — LISIBLE?
5. **DEMANDE** `PRG_04_Treuils_Benne.M1LogicReqAscent` — LISIBLE?
6. **DEMANDE** `PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent` — LISIBLE?
7. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.ReqAscent` — LISIBLE?
8. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep` — VISIBLE
9. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.MaxStepNumber` — LISIBLE?
10. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep._MaxStepClamped` — LISIBLE?
11. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.StepNumber` — VISIBLE
12. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.Contactor4` — VISIBLE
13. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.Contactor4` — VISIBLE
14. **ARBITRAGE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
15. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor4` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor4` — LISIBLE?
18. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor4` — LISIBLE?
19. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_4_DQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence` — LISIBLE?
2. **MESURE** `PRG_02_Acquisition.instEncoderM1.ConfirmCoherence` — LISIBLE?
3. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.BtnConfirmCoherence` — LISIBLE?
4. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.ConfirmCoherenceEdge.Q` — LISIBLE?
5. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.Calib.HomingSuspect` — VISIBLE
6. **MESURE** `PRG_02_Acquisition.instEncoderM1.Calib.HomingSuspect` — VISIBLE
7. **MESURE** `PRG_02_Acquisition.instEncoderM1.HomingSuspect` — VISIBLE
8. **MESURE** `PRG_02_Acquisition.Data.EncoderM1.HomingSuspect` — VISIBLE
9. **SECURITE** `PRG_04_Treuils_Benne.instSafetyWinchM1.HomingSuspect` — LISIBLE?
10. **SECURITE** `PRG_04_Treuils_Benne.instSafetyWinchM1.AscentPermit` — LISIBLE?
11. **PERMIS** `PRG_04_Treuils_Benne.SafetyPermitM1_Ascent` — LISIBLE?
12. **PERMIS** `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Ascent` — LISIBLE?
13. **PERMIS** `PRG_04_Treuils_Benne.EffectivePermitM1_Ascent` — VISIBLE
14. **PERMIS** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.AscentPermit` — LISIBLE?
15. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.AscentPermit` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.PermitFinalBlocked` — LISIBLE?
18. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor1` — LISIBLE?
19. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor1` — LISIBLE?
20. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_1_DQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent` — VISIBLE
2. **DEMANDE** `PRG_04_Treuils_Benne.ArbIHM.BtnDescentM1` — LISIBLE?
3. **ARBITRAGE** `PRG_04_Treuils_Benne.instArbM1.IHM.BtnDescentM1` — LISIBLE?
4. **ARBITRAGE** `PRG_04_Treuils_Benne.instArbM1.ReqAscent` — LISIBLE?
5. **DEMANDE** `PRG_04_Treuils_Benne.M1LogicReqAscent` — LISIBLE?
6. **DEMANDE** `PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent` — LISIBLE?
7. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.ReqAscent` — LISIBLE?
8. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep` — VISIBLE
9. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.MaxStepNumber` — LISIBLE?
10. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep._MaxStepClamped` — LISIBLE?
11. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.StepNumber` — VISIBLE
12. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.Contactor4` — VISIBLE
13. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.Contactor4` — VISIBLE
14. **ARBITRAGE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
15. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor4` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor4` — LISIBLE?
18. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor4` — LISIBLE?
19. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_4_DQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnHome`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnHome` — LISIBLE?
2. **MESURE** `PRG_02_Acquisition.instEncoderM1.HomingAtTargetM` — LISIBLE?
3. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.Home` — LISIBLE?
4. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.NominalHomingTrigger` — LISIBLE?
5. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.HomingTrigger` — LISIBLE?
6. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.PresetVerificationActive` — VISIBLE
7. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.Lifecycle.Busy` — VISIBLE
8. **MESURE** `PRG_02_Acquisition.instEncoderM1.Measurement.HomingLifecycle.Busy` — VISIBLE
9. **MESURE** `PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy` — VISIBLE
10. **PERMIS** `PRG_04_Treuils_Benne.SyncOperationPermit` — LISIBLE?
11. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.Enable` — LISIBLE?
12. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.SyncActive` — LISIBLE?
13. **ARBITRAGE** `PRG_04_Treuils_Benne.CoupledBoth` — LISIBLE?
14. **SECURITE** `PRG_04_Treuils_Benne.SafeStopM1_Active` — VISIBLE
15. **SECURITE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
16. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.SafeStop` — LISIBLE?
18. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
19. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
20. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero` — LISIBLE?
2. **MESURE** `PRG_02_Acquisition.instEncoderM1.HomingAtZero` — LISIBLE?
3. **REGLAGE** `PRG_02_Acquisition.instEncoderM1.instHoming.CfgTopSensorPosM` — LISIBLE?
4. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.TargetPositionM` — LISIBLE?
5. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.PresetVerificationActive` — VISIBLE
6. **MESURE** `PRG_02_Acquisition.instEncoderM1.instHoming.Lifecycle.Busy` — VISIBLE
7. **MESURE** `PRG_02_Acquisition.instEncoderM1.Measurement.HomingLifecycle.Busy` — VISIBLE
8. **MESURE** `PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy` — VISIBLE
9. **PERMIS** `PRG_04_Treuils_Benne.SyncOperationPermit` — LISIBLE?
10. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.Enable` — LISIBLE?
11. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.SyncActive` — LISIBLE?
12. **ARBITRAGE** `PRG_04_Treuils_Benne.CoupledBoth` — LISIBLE?
13. **SECURITE** `PRG_04_Treuils_Benne.SafeStopM1_Active` — VISIBLE
14. **SECURITE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
15. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.SafeStop` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
18. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
19. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware` — LISIBLE?
2. **BYPASS** `PRG_04_Treuils_Benne.OverrideTopSoftwareN1M1` — LISIBLE?
3. **REGLAGE** `PRG_04_Treuils_Benne.TopLimitM1_M` — LISIBLE?
4. **SECURITE** `PRG_04_Treuils_Benne.instSafetyWinchM1.TopLimitM` — LISIBLE?
5. **SECURITE** `PRG_04_Treuils_Benne.instSafetyWinchM1.AscentPermit` — LISIBLE?
6. **PERMIS** `PRG_04_Treuils_Benne.SafetyPermitM1_Ascent` — LISIBLE?
7. **PERMIS** `PRG_04_Treuils_Benne.ProcessAndSafetyPermitM1_Ascent` — LISIBLE?
8. **PERMIS** `PRG_04_Treuils_Benne.EffectivePermitM1_Ascent` — VISIBLE
9. **PERMIS** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.AscentPermit` — LISIBLE?
10. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit` — LISIBLE?
11. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.AscentPermit` — LISIBLE?
12. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.PermitFinalBlocked` — LISIBLE?
13. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor1` — LISIBLE?
14. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor1` — LISIBLE?
15. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_1_DQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — LISIBLE?
2. **RETOUR** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose` — VISIBLE
2. **PERMIS** `PRG_04_Treuils_Benne.SyncOperationPermit` — LISIBLE?
3. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.Enable` — LISIBLE?
4. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.SyncActive` — LISIBLE?
5. **ARBITRAGE** `PRG_04_Treuils_Benne.CoupledBoth` — LISIBLE?
6. **SECURITE** `PRG_04_Treuils_Benne.SafeStopM1_Active` — VISIBLE
7. **SECURITE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
8. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
9. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.SafeStop` — LISIBLE?
10. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
11. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
12. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen` — VISIBLE
2. **PERMIS** `PRG_04_Treuils_Benne.SyncOperationPermit` — LISIBLE?
3. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.Enable` — LISIBLE?
4. **SECURITE** `PRG_04_Treuils_Benne.instWinchSync.SyncActive` — LISIBLE?
5. **ARBITRAGE** `PRG_04_Treuils_Benne.CoupledBoth` — LISIBLE?
6. **SECURITE** `PRG_04_Treuils_Benne.SafeStopM1_Active` — VISIBLE
7. **SECURITE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
8. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop` — LISIBLE?
9. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.SafeStop` — LISIBLE?
10. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
11. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
12. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — LISIBLE?
2. **RETOUR** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — LISIBLE?
2. **RETOUR** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease`

1. **SOURCE** `GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease` — LISIBLE?
2. **SECURITE** `PRG_06_Outputs.MaintenanceN2BrakeForceM1` — LISIBLE?
3. **ARBITRAGE** `PRG_06_Outputs.M1BrakeCmd` — LISIBLE?
4. **SORTIE** `PRG_06_Outputs.M1_BrakeRelease_RQ` — A CONTROLER

### `GVL_IHM.MaintenanceN2.Cmd.BtnM1BrakeRelease`

1. **SOURCE** `GVL_IHM.MaintenanceN2.Cmd.BtnM1BrakeRelease` — LISIBLE?
2. **SECURITE** `PRG_06_Outputs.MaintenanceN2BrakeForceM1` — LISIBLE?
3. **ARBITRAGE** `PRG_06_Outputs.M1BrakeCmd` — LISIBLE?
4. **SORTIE** `PRG_06_Outputs.M1_BrakeRelease_RQ` — A CONTROLER

### `GVL_IHM.Modes.Cmd.BtnFaultReset`

1. **SOURCE** `GVL_IHM.Modes.Cmd.BtnFaultReset` — LISIBLE?
2. **RETOUR** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuckLatched` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RelayRev` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M1RelayRev` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.M1_RelayDescent_RQ` — A CONTROLER

### `GVL_IHM.Modes.Cmd.TglJoystickMaster`

1. **SOURCE** `GVL_IHM.Modes.Cmd.TglJoystickMaster` — VISIBLE
2. **REGLAGE** `PRG_04_Treuils_Benne.instArbM1.TglJoystickMaster` — LISIBLE?
3. **ARBITRAGE** `PRG_04_Treuils_Benne.instArbM1.ReqAscent` — LISIBLE?
4. **DEMANDE** `PRG_04_Treuils_Benne.M1LogicReqAscent` — LISIBLE?
5. **DEMANDE** `PRG_04_Treuils_Benne.ReqM1Winch.ReqAscent` — LISIBLE?
6. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.WinchRequest.ReqAscent` — LISIBLE?
7. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.ActiveMaxStep` — VISIBLE
8. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.MaxStepNumber` — LISIBLE?
9. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep._MaxStepClamped` — LISIBLE?
10. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.StepNumber` — VISIBLE
11. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.SpeedStep.Contactor4` — VISIBLE
12. **DEMANDE** `PRG_04_Treuils_Benne.instWinchM1.Contactor4` — VISIBLE
13. **ARBITRAGE** `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
14. **ARBITRAGE** `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4` — LISIBLE?
15. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.RequestedContactor4` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instWinchOutputInterlockM1.Contactor4` — LISIBLE?
17. **ARBITRAGE** `PRG_06_Outputs.M1SpeedContactor4` — LISIBLE?
18. **SORTIE** `PRG_06_Outputs.M1_SpeedContactor_4_DQ` — A CONTROLER

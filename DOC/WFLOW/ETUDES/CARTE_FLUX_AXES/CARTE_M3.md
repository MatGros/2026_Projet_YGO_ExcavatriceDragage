# Carte de flux M3

> Généré depuis `CODE/`. Chaîne, `fichier:ligne` et code cité : extraction mécanique. Colonnes de lecture : rédigées puis à relire. Aucune preuve sur automate.

**Couverture :** 475 variables dans le graphe, 351 maillons d'interface annotés, 66 points d'entrée reliés à une sortie, 0 maillon de chemin non annoté.

**Statuts :** {'A CONTROLER': 11, 'LISIBLE?': 254, 'VISIBLE': 86}. `VISIBLE` = chemin du snapshot ou copie directe. `LISIBLE?` = variable existante, lecture directe à confirmer sur automate.

## 1. Référentiel

### Actionneurs (3)

- `PRG_06_Outputs.M3_BrakeRelease_RQ`
- `PRG_06_Outputs.M3_CommandWord`
- `PRG_06_Outputs.M3_SetpointFrequencyHz`

### Commandes atteintes (12)

- `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — non visible
- `GVL_IHM.JOY1Joystick.Cmd.Calibrate` — non visible
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — non visible
- `GVL_IHM.M3Translation.Cmd.BtnMaintenance` — VISIBLE
- `GVL_IHM.M3Translation.Cmd.BtnTremie` — VISIBLE
- `GVL_IHM.M3Translation.Cmd.Initialized` — non visible
- `GVL_IHM.M3Translation.Cmd.InvertDirection` — non visible
- `GVL_IHM.M3Translation.Cmd.SetFreq_Hz` — non visible
- `GVL_IHM.Modes.Cmd.BtnFaultReset` — non visible
- `GVL_IHM.Modes.Cmd.TglJoystickMaster` — VISIBLE

### Réglages (25)

- `GVL_PERSISTENT._JoystickCfgPersist.DeadbandRaw`
- `GVL_PERSISTENT._JoystickCfgPersist.DeadmanArmHoldTime`
- `GVL_PERSISTENT._JoystickCfgPersist.RawOutOfRangeMargin`
- `GVL_PERSISTENT._TranslationAtMaintenancePersisted`
- `GVL_PERSISTENT._TranslationAtP1Persisted`
- `GVL_PERSISTENT._TranslationAtP2Persisted`
- `GVL_PERSISTENT._TranslationAtTremiePersisted`
- `GVL_PERSISTENT._TranslationMaxFreq_Hz`
- `GVL_PERSISTENT._TranslationMinHeightM1M2_M`
- `PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw`
- `PRG_02_Acquisition.instJoystick.Cfg.DeadmanArmHoldTime`
- `PRG_02_Acquisition.instJoystick.Cfg.RawOutOfRangeMargin`
- `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz`
- `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedP1_Hz`
- `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedTremie_Hz`
- `PRG_05_Translation.instArbM3.Cfg.MaxFreq_Hz`
- `PRG_05_Translation.instArbM3.TglJoystickMaster`
- `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedMaintenanceHz`
- `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedP1Hz`
- `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedTremieHz`
- `PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayContactClose`
- `PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayMagnetise`
- `PRG_05_Translation.instTranslationM3.Cfg.CaptorDebounce`
- `PRG_05_Translation.instTranslationM3.Cfg.DirectionInterlockDelay`
- `PRG_05_Translation.instTranslationM3.Cfg.DriveFreqScaleMaxHz`

### Bypass (23)

- `GVL_IHM.M3Translation.Bypass.ContactorFeedback`
- `GVL_IHM.M3Translation.Bypass.Global`
- `GVL_IHM.M3Translation.Bypass.Initialized`
- `GVL_IHM.M3Translation.Bypass.LimitSwitch`
- `GVL_IHM.M3Translation.Bypass.MinHeight`
- `GVL_IHM.Network.Bypass.BusCanOpen`
- `GVL_IHM.Network.Bypass.Global`
- `GVL_IHM.Network.Bypass.Initialized`
- `GVL_IHM.Network.Bypass.InputModules`
- `GVL_IHM.Network.Bypass.Joystick`
- `PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.NetworkBypassActive`
- `PRG_02_Acquisition.instDiagCanOpen.SimBypassActive`
- `PRG_05_Translation.ArbM3_IHM.BypassGlobal`
- `PRG_05_Translation.instArbM3.IHM.BypassGlobal`
- `PRG_05_Translation.instTranslationM3.Brake.BypassContactorCheck`
- `PRG_05_Translation.instTranslationM3.BypassContactorCheck`
- `PRG_05_Translation.instTranslationM3.BypassLimitSwitch`
- `PRG_07_Supervision.BypassNetworkGlobal`
- `PRG_07_Supervision.BypassTranslationGlobal`
- `PRG_07_Supervision.PrevNetworkBypass`
- `PRG_07_Supervision.PrevTranslationBypass`

### Mesures et retours physiques (29)

- `PRG_02_Acquisition.ConveyorInfeedReady_DI` — VISIBLE
- `PRG_02_Acquisition.EmergencyChainClosed_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.TremieFull_OR_GateRaised_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` — VISIBLE
- `PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI` — VISIBLE
- `PRG_02_Acquisition.HwReal.Machine` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Operator.CanBusState` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` — LISIBLE?
- `PRG_02_Acquisition.HwReal.Translation` — LISIBLE?
- `PRG_02_Acquisition.HydraulicThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M3_BrakeIsOpen_DI` — VISIBLE
- `PRG_02_Acquisition.M3_PosMaintenance_DI` — VISIBLE
- `PRG_02_Acquisition.M3_PosP1_DI` — VISIBLE
- `PRG_02_Acquisition.M3_PosPVP2_DI` — VISIBLE
- `PRG_02_Acquisition.M3_PosPV_DI` — VISIBLE
- `PRG_02_Acquisition.M3_PosTremie_DI` — VISIBLE
- `PRG_02_Acquisition.M3_ThermalOK_DI` — VISIBLE
- `PRG_02_Acquisition.PhaseRotationOk_DI` — VISIBLE
- `PRG_02_Acquisition.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` — VISIBLE

## 2. Maillons par étage (de la source vers l'actionneur)

### SOURCE (52)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_IHM.M3Translation.Cmd.Initialized` | LISIBLE? | `PRG_07_Supervision.st:277 = GVL_IHM.M3Translation.Cmd.Initialized := TRUE;` | Initialized est mis a TRUE par la supervision | verifier la consommation de Cmd.Initialized en aval |
| `PRG_07_Supervision._TranslationSetFreq_Hz` | A CONTROLER | `PRG_07_Supervision.st:282 = _TranslationSetFreq_Hz := GVL_IHM.M3Translation.Cmd.SetFreq_Hz;` | la consigne de frequence est relue depuis l IHM | verifier l usage de _TranslationSetFreq_Hz en aval |
| `GVL_IHM.M3Translation.Cmd.SetFreq_Hz` | LISIBLE? | `PRG_07_Supervision.st:276 = GVL_IHM.M3Translation.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;` | la commande de consigne de frequence est ecrite par la supervision | verifier la lecture de _TranslationSetFreq_Hz en aval |
| `GVL_IHM.JOY1Joystick.Cmd.Calibrate` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instJoystick.Calibrate |
| `GVL_Simulation.SimOperatorActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.OperatorInputSourceSimulated |
| `PRG_02_Acquisition.instJoystick.AxisCmdX.SpeedTgt` | LISIBLE? | `FB_Joystick.st:158 = AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedTgt := 0.0; AxisCmdX.StepTgt := 0; ;; FB_Joystick.st:256 = A` | SpeedTgt mis a zero en defaut puis ABS CmdXVal | verifier CmdXVal et la sortie AxisCmdX.SpeedTgt |
| `PRG_02_Acquisition.instJoystick.NeutralYMem` | LISIBLE? | `FB_Joystick.st:124 = NeutralYMem := RawY;` | NeutralYMem recoit RawY | verifier RawY et NeutralYMem |
| `PRG_02_Acquisition.HwSim.Operator` | LISIBLE? | `PRG_02_Acquisition.st:436 = HwSim.Operator := instSimBench.Operator;` | HwSim.Operator issu de instSimBench.Operator | verifier instSimBench.Operator |
| `PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | JoystickCfgEffective affecte depuis GVL_PERSISTENT._JoystickCfgPersist | verifier la valeur de DeadbandRaw dans GVL_PERSISTENT._JoystickCfgPersist |
| `PRG_02_Acquisition.OperatorInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:137 = OperatorInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive;` | SimulationModeActive et SimOperatorActive actifs dans GVL_Simulation | verifier GVL_Simulation.SimulationModeActive et GVL_Simulation.SimOperatorActive |
| `PRG_02_Acquisition._JoystickNeutralX` | A CONTROLER | `PRG_02_Acquisition.st:496 = instJoystick( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, ArmingPermit := PRG_04_Treuils_Benne.Data` | instJoystick appele avec Enable TRUE et Reset depuis FaultMachineReset_IHM | Verifier en aval : PRG_02_Acquisition.instJoystick.NeutralXMem |
| `PRG_02_Acquisition.instJoystick.Calibrate` | LISIBLE? | `entree liee a : GVL_IHM.JOY1Joystick.Cmd.Calibrate` | Entree recue depuis : GVL_IHM.JOY1Joystick.Cmd.Calibrate | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.NeutralXMem` | LISIBLE? | `FB_Joystick.st:123 = NeutralXMem := RawX;` | NeutralXMem assigne a RawX dans FB_Joystick | verifier RawX amont |
| `PRG_02_Acquisition.instJoystick.RawX` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` | Entree recue depuis : PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.RawY` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` | Entree recue depuis : PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleX.DeadbandRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw` | Entree recue depuis : PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.ScaleX.Neutral` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instJoystick.NeutralXMem` | Entree recue depuis : PRG_02_Acquisition.instJoystick.NeutralXMem | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.TRUE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instJoystick.Enable, PRG_02_Acquisition.instDiagCanOpen.Enable |
| `PRG_02_Acquisition.instJoystick.ArmingPermit` | LISIBLE? | `entree liee a : PRG_04_Treuils_Benne.Data.ArmingPermit` | Entree recue depuis : PRG_04_Treuils_Benne.Data.ArmingPermit | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.AxisCmdX.DirectionNegative` | LISIBLE? | `FB_Joystick.st:159 = AxisCmdX.DirectionPositive := FALSE; AxisCmdX.DirectionNegative := FALSE; AxisCmdX.AtNeutral := TRUE; ;; FB_Joystick.st:260 = Axi` | AxisCmdX.DirectionNegative recalculé selon CmdXVal inférieur au seuil négatif | Vérifier CmdXVal et CST_DirectionQualificationThreshold_Pct |
| `PRG_02_Acquisition.instJoystick.AxisCmdY.AtNeutral` | LISIBLE? | `FB_Joystick.st:161 = AxisCmdY.DirectionPositive := FALSE; AxisCmdY.DirectionNegative := FALSE; AxisCmdY.AtNeutral := TRUE; ;; FB_Joystick.st:280 = Axi` | AxisCmdY.AtNeutral vrai si ni DirectionPositive ni DirectionNegative | Vérifier DirectionPositive et DirectionNegative de AxisCmdY en amont |
| `PRG_02_Acquisition.instJoystick.BusCanOpenOP.Operational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational` | Entree recue depuis : PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.DeadmanArmTimer.Q` | LISIBLE? | `FB_Joystick.st:173 = DeadmanArmTimer(IN := FALSE, PT := Cfg.DeadmanArmHoldTime); ;; FB_Joystick.st:230 = DeadmanArmTimer(IN := DeadmanArmPending AND N` | DeadmanArmTimer relancé selon DeadmanArmPending, DeadmanArmed, ArmingPermit et InversionLockActive | Vérifier Q de DeadmanArmTimer et la condition de relance en aval |
| `PRG_02_Acquisition.instJoystick.DirectInversionPermit` | LISIBLE? | `entree liee a : GVL_IHM.CycleSemiAuto.State.CycleStep` | Entree recue depuis : GVL_IHM.CycleSemiAuto.State.CycleStep | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.JoystickOP.Operational` | LISIBLE? | `entree liee a : PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational` | Entree recue depuis : PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.RawOutOfRange` | LISIBLE? | `FB_Joystick.st:112 = RawOutOfRange := (RawX < (0 - Cfg.RawOutOfRangeMargin)) OR (RawX > (10000 + Cfg.RawOutOfRangeMargin)) OR (RawY < (0 - Cfg.RawOutO` | RawOutOfRange vrai si RawX ou RawY dépasse la marge autour de 0-10000 | Vérifier RawX, RawY et Cfg.RawOutOfRangeMargin |
| `PRG_02_Acquisition.instJoystick.ScaleX.OutPct` | LISIBLE? | `FB_AxisScale.st:29 = OutPct := (INT_TO_REAL(RawIn - Neutral) / Delta) * 100.0; ;; FB_AxisScale.st:31 = OutPct := 0.0;` | ScaleX.OutPct calculé depuis RawIn Neutral et Delta ou forcé 0 | Vérifier RawIn, Neutral et Delta dans FB_AxisScale |
| `PRG_02_Acquisition.instJoystick.AxisCmdY.Direction` | VISIBLE | `FB_Joystick.st:163 = AxisCmdY.Direction := 0; AxisCmdY.Deflection := 0; ;; FB_Joystick.st:305 = IF AxisCmdY.DirectionPositive THEN AxisCmdY.Direction ` | AxisCmdY.Direction mis à 0 ou 1 selon DirectionPositive | Vérifier DirectionPositive et AxisCmdY.Deflection résultants |
| `PRG_02_Acquisition.instJoystick.BusLost` | LISIBLE? | `FB_Joystick.st:116 = BusLost := (NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational);` | BusLost vrai si BusCanOpenOP ou JoystickOP non opérationnels | Vérifier Operational de DeviceCanOpenMaster et DeviceJoystick |
| `PRG_02_Acquisition.instJoystick.CmdXVal` | LISIBLE? | `FB_Joystick.st:253 = CmdXVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleX.OutPct);` | CmdXVal = 0 sauf si DeadmanArmed et pas RawOutOfRange, sinon ScaleX.OutPct | Vérifier ScaleX.OutPct et la chaîne DeadmanArmed et RawOutOfRange |
| `PRG_02_Acquisition.instJoystick.DeadmanArmed` | VISIBLE | `FB_Joystick.st:165 = DeadmanArmed := FALSE; ;; FB_Joystick.st:218 = DeadmanArmed := FALSE;` | DeadmanArmed initialisé FALSE puis recalculé en aval | Vérifier la condition d'armement dans FB_Joystick.st:218 et suivantes |
| `PRG_02_Acquisition.instJoystick.Enable` | LISIBLE? | `entree liee a : PRG_02_Acquisition.TRUE` | Entree recue depuis : PRG_02_Acquisition.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_IHM.M3Translation.Cmd.BtnMaintenance` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_IHM.BtnMaintenance |
| `GVL_IHM.M3Translation.Cmd.BtnTremie` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_IHM.BtnTremie |
| `PRG_02_Acquisition.instJoystick.AxisCmdX.DirectionPositive` | LISIBLE? | `FB_Joystick.st:159 = AxisCmdX.DirectionPositive := FALSE; AxisCmdX.DirectionNegative := FALSE; AxisCmdX.AtNeutral := TRUE; ;; FB_Joystick.st:259 = Axi` | DirectionPositive vrai si CmdXVal depasse le seuil de qualification apres init FALSE | verifier CmdXVal et CST_DirectionQualificationThreshold_Pct dans FB_Joystick |
| `GVL_IHM.Modes.Cmd.TglJoystickMaster` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instArbM3.TglJoystickMaster |
| `PRG_05_Translation.TRUE` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instArbM3.Enable |
| `GVL_IHM.M3Translation.Cmd.InvertDirection` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.InvertDriveDirection |
| `GVL_Simulation.SimSafetyActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineInputSourceSimulated |
| `PRG_02_Acquisition.instSimBench.Machine` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Machine |
| `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.Modes.Cmd.BtnFaultReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_Simulation.SimTranslationActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.TranslationInputSourceSimulated, GVL_IHM.M3Translation.Bypass.ContactorFeedback |
| `GVL_Simulation.SimulationModeActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.TranslationInputSourceSimulated, PRG_02_Acquisition.MachineInputSourceSimulated |
| `PRG_02_Acquisition.MachineInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:138 = MachineInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimSafetyActive;` | SimulationModeActive et SimSafetyActive vrais | PRG_02_Acquisition.st:138 verifier GVL_Simulation ou la source simulee est utilisee en aval |
| `PRG_02_Acquisition.HwSim.Translation` | LISIBLE? | `PRG_02_Acquisition.st:421 = HwSim.Translation := instSimBench.Translation;` | HwSim.Translation recoit instSimBench.Translation | verifier instSimBench.Translation dans le banc de simulation |
| `PRG_02_Acquisition.TranslationInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:136 = TranslationInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;` | SimulationModeActive et SimTranslationActive vrais | PRG_02_Acquisition.st:136 verifier GVL_Simulation ou la source simulee est utilisee en aval |
| `PRG_06_Outputs.WORD` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveControlWord |

### MODE (7)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.ArmModeDisabled` | LISIBLE? | `PRG_04_Treuils_Benne.st:1186 = ArmModeDisabled := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.DISABLE);` | ArmModeDisabled vrai si Auth.Mode egale E_Mode.DISABLE | verifier PRG_03_Modes_Cycle.Data.Auth.Mode |
| `PRG_05_Translation.M3_MaintN2` | LISIBLE? | `PRG_05_Translation.st:475 = M3_MaintN2 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2);` | M3_MaintN2 vrai si Data.Auth.Mode egale E_Mode.MAINT_N2 | verifier Data.Auth.Mode dans PRG_03_Modes_Cycle |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instArbM3.ReqTranslation.PositionTgt |
| `PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instArbM3.ReqTranslation.ReqStart |
| `PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.SlowdownSensorP1, PRG_05_Translation.M3_LimitSwitchMaintenanceStable |
| `PRG_03_Modes_Cycle.Data.SequenceState.Step` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_CycleTranslationStepAuthorized, GVL_IHM.CycleSemiAuto.State.CycleStep |
| `PRG_03_Modes_Cycle.Data.Auth.Mode` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TranslationFinalInterlockRequest.BrakeReleaseRequest, PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord |

### REGLAGE (36)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_PERSISTENT._TranslationAtMaintenancePersisted` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_AtMaintenanceStable |
| `GVL_PERSISTENT._TranslationAtP1Persisted` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_AtP1Stable |
| `GVL_PERSISTENT._TranslationAtP2Persisted` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_AtP2Stable |
| `GVL_PERSISTENT._TranslationAtTremiePersisted` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_AtTremieStable |
| `GVL_PERSISTENT._TranslationMaxFreq_Hz` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_Cfg.MaxFreq_Hz |
| `GVL_PERSISTENT._JoystickCfgPersist.DeadbandRaw` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw |
| `PRG_05_Translation.ArbM3_Cfg.MaxFreq_Hz` | LISIBLE? | `PRG_05_Translation.st:376 = ArbM3_Cfg.MaxFreq_Hz := GVL_PERSISTENT._TranslationMaxFreq_Hz;` | MaxFreq_Hz affecte depuis GVL_PERSISTENT._TranslationMaxFreq_Hz | verifier GVL_PERSISTENT._TranslationMaxFreq_Hz |
| `PRG_05_Translation.TranslationCfg.CaptorDebounce` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.Cfg.CaptorDebounce |
| `GVL_PERSISTENT._JoystickCfgPersist.DeadmanArmHoldTime` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime |
| `GVL_PERSISTENT._JoystickCfgPersist.RawOutOfRangeMargin` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin |
| `PRG_05_Translation.instArbM3.Cfg.MaxFreq_Hz` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_Cfg.MaxFreq_Hz` | Entree recue depuis : PRG_05_Translation.ArbM3_Cfg.MaxFreq_Hz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.CaptorDebounce` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.CaptorDebounce` | Entree recue depuis : PRG_05_Translation.TranslationCfg.CaptorDebounce | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | JoystickCfgEffective copie depuis GVL_PERSISTENT._JoystickCfgPersist | verifier DeadmanArmHoldTime dans la structure persistante |
| `PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin` | LISIBLE? | `PRG_02_Acquisition.st:493 = JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;` | JoystickCfgEffective copie depuis GVL_PERSISTENT._JoystickCfgPersist | verifier RawOutOfRangeMargin dans la structure persistante |
| `PRG_02_Acquisition.instJoystick.Cfg.DeadbandRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.DeadbandRaw | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.Cfg.DeadmanArmHoldTime` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.DeadmanArmHoldTime | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instJoystick.Cfg.RawOutOfRangeMargin` | LISIBLE? | `entree liee a : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin` | Entree recue depuis : PRG_02_Acquisition.JoystickCfgEffective.RawOutOfRangeMargin | Comparer avec la source : un ecart indique un probleme de liaison |
| `GVL_PERSISTENT._TranslationMinHeightM1M2_M` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_05_Translation.TranslationCfg.BrakeDelayContactClose` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayContactClose |
| `PRG_05_Translation.TranslationCfg.BrakeDelayMagnetise` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayMagnetise |
| `PRG_05_Translation.TranslationCfg.DirectionInterlockDelay` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.instTranslationM3.Cfg.DirectionInterlockDelay |
| `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TranslationCfg.ApproachSpeedMaintenanceHz |
| `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedP1_Hz` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TranslationCfg.ApproachSpeedP1Hz |
| `PRG_05_Translation._TranslationCfgPersist.CfgApproachSpeedTremie_Hz` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TranslationCfg.ApproachSpeedTremieHz |
| `PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayContactClose` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.BrakeDelayContactClose` | Entree recue depuis : PRG_05_Translation.TranslationCfg.BrakeDelayContactClose | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.BrakeDelayMagnetise` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.BrakeDelayMagnetise` | Entree recue depuis : PRG_05_Translation.TranslationCfg.BrakeDelayMagnetise | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.DirectionInterlockDelay` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.DirectionInterlockDelay` | Entree recue depuis : PRG_05_Translation.TranslationCfg.DirectionInterlockDelay | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.TranslationCfg.ApproachSpeedMaintenanceHz` | LISIBLE? | `PRG_05_Translation.st:579 = TranslationCfg.ApproachSpeedMaintenanceHz := _TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz;` | ApproachSpeedMaintenanceHz charge depuis _TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz | verifier la persistance _TranslationCfgPersist en amont |
| `PRG_05_Translation.TranslationCfg.ApproachSpeedP1Hz` | LISIBLE? | `PRG_05_Translation.st:580 = TranslationCfg.ApproachSpeedP1Hz := _TranslationCfgPersist.CfgApproachSpeedP1_Hz;` | ApproachSpeedP1Hz charge depuis _TranslationCfgPersist.CfgApproachSpeedP1_Hz | verifier la persistance _TranslationCfgPersist en amont |
| `PRG_05_Translation.TranslationCfg.ApproachSpeedTremieHz` | LISIBLE? | `PRG_05_Translation.st:578 = TranslationCfg.ApproachSpeedTremieHz := _TranslationCfgPersist.CfgApproachSpeedTremie_Hz;` | ApproachSpeedTremieHz charge depuis _TranslationCfgPersist.CfgApproachSpeedTremie_Hz | verifier la persistance _TranslationCfgPersist en amont |
| `PRG_05_Translation.TranslationCfg.DriveFreqScaleMaxHz` | LISIBLE? | `PRG_05_Translation.st:577 = TranslationCfg.DriveFreqScaleMaxHz := _TranslationMaxFreq_Hz;` | DriveFreqScaleMaxHz charge depuis _TranslationMaxFreq_Hz | verifier _TranslationMaxFreq_Hz en amont |
| `PRG_05_Translation.instArbM3.TglJoystickMaster` | LISIBLE? | `entree liee a : GVL_IHM.Modes.Cmd.TglJoystickMaster` | Entree recue depuis : GVL_IHM.Modes.Cmd.TglJoystickMaster | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedMaintenanceHz` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.ApproachSpeedMaintenanceHz` | Entree recue depuis : PRG_05_Translation.TranslationCfg.ApproachSpeedMaintenanceHz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedP1Hz` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.ApproachSpeedP1Hz` | Entree recue depuis : PRG_05_Translation.TranslationCfg.ApproachSpeedP1Hz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.ApproachSpeedTremieHz` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.ApproachSpeedTremieHz` | Entree recue depuis : PRG_05_Translation.TranslationCfg.ApproachSpeedTremieHz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Cfg.DriveFreqScaleMaxHz` | LISIBLE? | `entree liee a : PRG_05_Translation.TranslationCfg.DriveFreqScaleMaxHz` | Entree recue depuis : PRG_05_Translation.TranslationCfg.DriveFreqScaleMaxHz | Comparer avec la source : un ecart indique un probleme de liaison |

### BYPASS (28)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_IHM.Network.Bypass.BusCanOpen` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive |
| `GVL_IHM.Network.Bypass.Joystick` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive |
| `PRG_02_Acquisition.instDiagCanOpen.CanBusBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.BusCanOpen` | Entree recue depuis : GVL_IHM.Network.Bypass.BusCanOpen | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.JoystickBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.Joystick` | Entree recue depuis : GVL_IHM.Network.Bypass.Joystick | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.NetworkBypassActive` | LISIBLE? | `entree liee a : GVL_IHM.Network.Bypass.Global` | Entree recue depuis : GVL_IHM.Network.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.SimBypassActive` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.instDiagCanOpen.CANbusOnlineEff, PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickOnlineEff |
| `PRG_02_Acquisition.instDiagCanOpen.CANbusOnlineEff` | VISIBLE | `FB_Diag_CanOpen.st:70 = CANbusOnlineEff := CANbusOnlineReal OR SimBypassActive OR NetworkBypassActive OR CanBusBypassActive;` | CANbusOnlineEff vrai si online reel ou un bypass actif | verifier SimBypassActive NetworkBypassActive CanBusBypassActive |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickOnlineEff` | LISIBLE? | `FB_Diag_CanOpen.st:71 = DeviceJoystickOnlineEff := DeviceJoystickOnlineReal OR SimBypassActive OR NetworkBypassActive OR JoystickBypassActive;` | DeviceJoystickOnlineEff vrai si online reel ou un bypass actif | verifier SimBypassActive NetworkBypassActive JoystickBypassActive |
| `PRG_07_Supervision.PrevNetworkBypass` | LISIBLE? | `PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypass.Global, RetainVal := BypassNetworkGlobal, Prev := PrevNetworkBypass)` | PrevNetworkBypass passe en Prev de instMirrorBypassNetwork | verifier instMirrorBypassNetwork et BypassNetworkGlobal |
| `PRG_07_Supervision.instMirrorBypassNetwork.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev assigne a Hmi dans FB_MirrorBypassRetain | verifier Hmi amont |
| `PRG_07_Supervision.instMirrorBypassNetwork.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal assigne a Hmi dans FB_MirrorBypassRetain | verifier Hmi amont |
| `GVL_IHM.M3Translation.Bypass.MinHeight` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_05_Translation.instTranslationM3.BypassLimitSwitch` | LISIBLE? | `entree liee a : GVL_IHM.M3Translation.Bypass.Global, GVL_IHM.M3Translation.Bypass.LimitSwitch, PRG_05_Translation.M3_MaintN2` | Entree recue depuis : GVL_IHM.M3Translation.Bypass.Global, GVL_IHM.M3Translation.Bypass.LimitSwitch, PRG_05_Translation.M3_MaintN2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_07_Supervision.BypassNetworkGlobal` | A CONTROLER | `PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypass.Global, RetainVal := BypassNetworkGlobal, Prev := PrevNetworkBypass)` | instMirrorBypassNetwork appele avec Hmi Global et RetainVal BypassNetworkGlobal | verifier RetainVal et Prev dans FB_MirrorBypassRetain |
| `PRG_07_Supervision.PrevTranslationBypass` | LISIBLE? | `PRG_07_Supervision.st:360 = instMirrorBypassTranslation(Hmi := GVL_IHM.M3Translation.Bypass.Global, RetainVal := BypassTranslationGlobal, Prev := Prev` | instMirrorBypassTranslation appele avec Hmi Global et RetainVal BypassTranslationGlobal | verifier RetainVal et Prev dans FB_MirrorBypassRetain |
| `PRG_07_Supervision.instMirrorBypassNetwork.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi assigne a RetainVal dans FB_MirrorBypassRetain | verifier RetainVal en amont |
| `GVL_IHM.Network.Bypass.Global` | VISIBLE | `PRG_07_Supervision.st:352 = GVL_IHM.Network.Bypass.Global := TRUE; ;; PRG_07_Supervision.st:370 = instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypas` | Bypass.Global réseau forcé TRUE puis mirroré par instMirrorBypassNetwork | Vérifier BypassNetworkGlobal et PrevNetworkBypass après l'appel ligne 370 |
| `GVL_IHM.Network.Bypass.InputModules` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk, PRG_02_Acquisition.Data.InputModules.Vh0008Er1Ok |
| `PRG_07_Supervision.instMirrorBypassTranslation.Prev` | LISIBLE? | `FB_MirrorBypassRetain.st:26 = Prev := Hmi;` | Prev reçoit Hmi dans FB_MirrorBypassRetain | Vérifier la logique de détection de front dans FB_MirrorBypassRetain.st:26 |
| `PRG_07_Supervision.instMirrorBypassTranslation.RetainVal` | VISIBLE | `FB_MirrorBypassRetain.st:22 = RetainVal := Hmi;` | RetainVal reçoit Hmi dans FB_MirrorBypassRetain | Vérifier la logique de rétention dans FB_MirrorBypassRetain.st:22 |
| `PRG_05_Translation.ArbM3_IHM.BypassGlobal` | LISIBLE? | `PRG_05_Translation.st:373 = ArbM3_IHM.BypassGlobal := GVL_IHM.M3Translation.Bypass.Global;` | BypassGlobal copie de GVL_IHM.M3Translation.Bypass.Global | verifier la commande IHM Bypass.Global |
| `PRG_07_Supervision.BypassTranslationGlobal` | A CONTROLER | `PRG_07_Supervision.st:360 = instMirrorBypassTranslation(Hmi := GVL_IHM.M3Translation.Bypass.Global, RetainVal := BypassTranslationGlobal, Prev := Prev` | instMirrorBypassTranslation appelé avec Hmi GVL_IHM.M3Translation.Bypass.Global et RetainVal BypassTranslationGlobal | Vérifier l'état de BypassTranslationGlobal et PrevTranslationBypass après l'appel |
| `PRG_07_Supervision.instMirrorBypassTranslation.Hmi` | VISIBLE | `FB_MirrorBypassRetain.st:24 = Hmi := RetainVal;` | Hmi reçoit RetainVal dans FB_MirrorBypassRetain | Vérifier la logique de mirroring dans FB_MirrorBypassRetain.st:24 |
| `GVL_IHM.M3Translation.Bypass.ContactorFeedback` | LISIBLE? | `PRG_07_Supervision.st:496 = GVL_IHM.M3Translation.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationAct` | ContactorFeedback vrai si SimulationModeActive et SimTranslationActive | verifier ces deux drapeaux simulation |
| `GVL_IHM.M3Translation.Bypass.Global` | VISIBLE | `PRG_07_Supervision.st:297 = GVL_IHM.M3Translation.Bypass.Global := TRUE; ;; PRG_07_Supervision.st:360 = instMirrorBypassTranslation(Hmi := GVL_IHM.M3T` | Global force a TRUE puis miroir instMirrorBypassTranslation | verifier instMirrorBypassTranslation et BypassTranslationGlobal |
| `GVL_IHM.M3Translation.Bypass.LimitSwitch` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TonTremieProcessBlock.Q, PRG_05_Translation.instTranslationM3.BypassLimitSwitch |
| `PRG_05_Translation.instArbM3.IHM.BypassGlobal` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_IHM.BypassGlobal` | Entree recue depuis : PRG_05_Translation.ArbM3_IHM.BypassGlobal | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.BypassContactorCheck` | LISIBLE? | `entree liee a : GVL_IHM.M3Translation.Bypass.ContactorFeedback, GVL_IHM.M3Translation.Bypass.Global` | Entree recue depuis : GVL_IHM.M3Translation.Bypass.ContactorFeedback, GVL_IHM.M3Translation.Bypass.Global | Comparer avec la source : un ecart indique un probleme de liaison |

### ARBITRAGE (33)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_05_Translation.SelTarget` | LISIBLE? | `PRG_05_Translation.st:389 = SelTarget := instArbM3.SelTarget;` | SelTarget est copie depuis instArbM3.SelTarget | verifier l usage de SelTarget en aval |
| `PRG_05_Translation.M3_TargetCodeSel` | LISIBLE? | `PRG_05_Translation.st:434 = 1: M3_TargetCodeSel := 1; ;; PRG_05_Translation.st:435 = 2: M3_TargetCodeSel := 2;` | M3_TargetCodeSel est force a 1 ou 2 selon le cas | verifier l usage de M3_TargetCodeSel en aval |
| `PRG_05_Translation.instArbM3.IHM.SetFreq_Hz` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_IHM.SetFreq_Hz` | Entree recue depuis : PRG_05_Translation.ArbM3_IHM.SetFreq_Hz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.FreqPct` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:108 = FreqPct := SEL(IHM.SetFreq_Hz > 0.0, 100.0, (IHM.SetFreq_Hz / SEL(Cfg.MaxFreq_Hz > 0.0, 50.0, Cfg.MaxFreq_Hz))` | FreqPct calcule selon IHM.SetFreq_Hz et Cfg.MaxFreq_Hz | verifier IHM.SetFreq_Hz et Cfg.MaxFreq_Hz |
| `PRG_05_Translation.instArbM3.Joystick.AxisX.SpeedTgt` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisX.SpeedTgt` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisX.SpeedTgt | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.SpeedPct` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:111 = SpeedPct := SEL(TglJoystickMaster, FreqPct, (ABS(Joystick.AxisX.SpeedTgt) / 100.0) * FreqPct); ;; FB_Translati` | SpeedPct calcule selon TglJoystickMaster FreqPct et AxisX.SpeedTgt | verifier TglJoystickMaster FreqPct et Joystick.AxisX.SpeedTgt |
| `GVL_Simulation.SimBtnMaintenance` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_IHM.BtnMaintenance |
| `GVL_Simulation.SimBtnTremie` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_IHM.BtnTremie |
| `PRG_05_Translation.ArbM3_Context.HeightInterlockOk` | LISIBLE? | `PRG_05_Translation.st:375 = ArbM3_Context.HeightInterlockOk := M3_HeightInterlockOk;` | HeightInterlockOk copie de M3_HeightInterlockOk | verifier le calcul de M3_HeightInterlockOk en amont |
| `PRG_05_Translation.SimBtnIHM_Active` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.ArbM3_IHM.BtnMaintenance, PRG_05_Translation.ArbM3_IHM.BtnTremie |
| `PRG_05_Translation.instArbM3.Joystick.AxisX.DirectionNegative` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Joystick.AxisY.AtNeutral` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisY.AtNeutral` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisY.AtNeutral | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.ArbM3_IHM.BtnMaintenance` | LISIBLE? | `PRG_05_Translation.st:370 = ArbM3_IHM.BtnMaintenance := SEL(SimBtnIHM_Active, GVL_IHM.M3Translation.Cmd.BtnMaintenance, GVL_Simulation.SimBtnMaintenan` | BtnMaintenance selectionne IHM ou simulation selon SimBtnIHM_Active | verifier SimBtnIHM_Active et SimBtnMaintenance |
| `PRG_05_Translation.ArbM3_IHM.BtnTremie` | LISIBLE? | `PRG_05_Translation.st:369 = ArbM3_IHM.BtnTremie := SEL(SimBtnIHM_Active, GVL_IHM.M3Translation.Cmd.BtnTremie, GVL_Simulation.SimBtnTremie);` | BtnTremie selectionne IHM ou simulation selon SimBtnIHM_Active | verifier SimBtnIHM_Active et SimBtnTremie |
| `PRG_05_Translation.instArbM3.Auth.MaintenanceM3TargetEnable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Context.HeightInterlockOk` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_Context.HeightInterlockOk` | Entree recue depuis : PRG_05_Translation.ArbM3_Context.HeightInterlockOk | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Joystick.AxisY.Direction` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisY.Direction` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisY.Direction | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Joystick.DeadmanArmed` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.DeadmanArmed` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.DeadmanArmed | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.ReqMaintenance` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:128 = ReqMaintenance := FALSE; ;; FB_TranslationCmdArbitrationM3.st:50 = ReqMaintenance := FALSE;` | ReqMaintenance mis a FALSE dans les deux branches | chercher comment ReqMaintenance est reellement mis a TRUE en amont |
| `PRG_05_Translation.instArbM3.ReqTranslation.PositionTgt` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt` | Entree recue depuis : PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.ReqTranslation.ReqStart` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart` | Entree recue depuis : PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Auth.Mode` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Enable` | LISIBLE? | `entree liee a : PRG_05_Translation.TRUE` | Entree recue depuis : PRG_05_Translation.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.IHM.BtnMaintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_IHM.BtnMaintenance` | Entree recue depuis : PRG_05_Translation.ArbM3_IHM.BtnMaintenance | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.IHM.BtnTremie` | LISIBLE? | `entree liee a : PRG_05_Translation.ArbM3_IHM.BtnTremie` | Entree recue depuis : PRG_05_Translation.ArbM3_IHM.BtnTremie | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.Joystick.AxisX.DirectionPositive` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive` | Entree recue depuis : PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instArbM3.RunRequest` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:100 = RunRequest := (ReqTremie OR ReqMaintenance) AND (IHM.BypassGlobal OR NOT TglJoystickMaster OR TglJoystickMaste` | RunRequest vrai si demande et deadman arme et conditions joystick hauteur | verifier Joystick.DeadmanArmed AxisY Context.HeightInterlockOk et TglJoystickMaster en amont |
| `PRG_05_Translation.instArbM3.SelTarget` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:117 = SelTarget := 0; ;; FB_TranslationCmdArbitrationM3.st:136 = SelTarget := 0;` | SelTarget force a 0 dans le FB | verifier si SelTarget est ecrit ailleurs en aval ou en amont |
| `PRG_05_Translation.instArbM3.ReqTremie` | LISIBLE? | `FB_TranslationCmdArbitrationM3.st:127 = ReqTremie := FALSE; ;; FB_TranslationCmdArbitrationM3.st:49 = ReqTremie := FALSE;` | ReqTremie force a FALSE dans le FB | chercher un autre chemin qui remet ReqTremie a vrai |
| `PRG_05_Translation.M3_ReqTremie_Active` | LISIBLE? | `PRG_05_Translation.st:391 = M3_ReqTremie_Active := instArbM3.ReqTremie; ;; PRG_05_Translation.st:407 = M3_ReqTremie_Active := FALSE;` | instArbM3.ReqTremie vrai puis remis a FALSE | PRG_05_Translation.st:391 et 407 verifier arbitrage instArbM3 |
| `PRG_05_Translation.M3_CycleTranslationStepAuthorized` | LISIBLE? | `PRG_05_Translation.st:400 = M3_CycleTranslationStepAuthorized := (PRG_03_Modes_Cycle.Data.SequenceState.Step = E_AutoCycleStep.AX2_TRANSLATE_P1) OR (P` | etape cycle egale AX2_TRANSLATE_P1 ou AX14_TRANSLATE_DUMP | PRG_05_Translation.st:400 verifier SequenceState.Step en amont |
| `PRG_06_Outputs.M3InterlockEnable` | LISIBLE? | `PRG_06_Outputs.st:410 = M3InterlockEnable := PRG_05_Translation.Data.TranslationFinalInterlockRequest.Enable AND NOT PRG_05_Translation.Data.Translati` | M3InterlockEnable vrai si Enable ET NOT PowerCutOff | verifier Enable noeud 28 et PowerCutOff noeud 29 |
| `PRG_06_Outputs.M3_TremieHardStopActive` | LISIBLE? | `PRG_06_Outputs.st:431 = M3_TremieHardStopActive := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI AND PRG_05_Translation.Data.TranslationFinalInt` | M3_TremieHardStopActive vrai si M3_PosTremie_DI ET ReqTremieSemantic | verifier M3_PosTremie_DI noeud 25 et ReqTremieSemantic noeud 30 |

### DEMANDE (41)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_05_Translation.ArbM3_IHM.SetFreq_Hz` | LISIBLE? | `PRG_05_Translation.st:372 = ArbM3_IHM.SetFreq_Hz := GVL_IHM.M3Translation.Cmd.SetFreq_Hz;` | SetFreq_Hz affecte depuis GVL_IHM.M3Translation.Cmd.SetFreq_Hz | verifier la consigne SetFreq_Hz cote IHM |
| `PRG_05_Translation.instTranslationM3.PositionSensorTarget` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_PositionSensorTarget` | Entree recue depuis : PRG_05_Translation.M3_PositionSensorTarget | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.CaptorDebounceTon.Q` | LISIBLE? | `FB_Translation.st:172 = CaptorDebounceTon(IN := FALSE); ;; FB_Translation.st:192 = CaptorDebounceTon(IN := PositionSensorTarget, PT := Cfg.CaptorDebou` | CaptorDebounceTon.Q selon PositionSensorTarget et CaptorDebounce | verifier PositionSensorTarget et Cfg.CaptorDebounce |
| `PRG_05_Translation.instTranslationM3.TargetReached` | LISIBLE? | `FB_Translation.st:170 = TargetReached := FALSE; ;; FB_Translation.st:193 = TargetReached := CaptorDebounceTon.Q;` | TargetReached suit CaptorDebounceTon.Q | verifier CaptorDebounceTon et PositionSensorTarget |
| `PRG_05_Translation.M3_RunRequest_Active` | LISIBLE? | `PRG_05_Translation.st:390 = M3_RunRequest_Active := instArbM3.RunRequest; ;; PRG_05_Translation.st:406 = M3_RunRequest_Active := FALSE;` | M3_RunRequest_Active affecté par instArbM3.RunRequest ou forcé FALSE | Vérifier instArbM3.RunRequest et la condition de forçage en aval |
| `PRG_05_Translation.M3_SpeedCmd_Active` | LISIBLE? | `PRG_05_Translation.st:394 = M3_SpeedCmd_Active := instArbM3.SpeedPct; ;; PRG_05_Translation.st:409 = M3_SpeedCmd_Active := 0.0;` | M3_SpeedCmd_Active affecté par instArbM3.SpeedPct ou forcé 0 | Vérifier instArbM3.SpeedPct et la condition de forçage en aval |
| `PRG_05_Translation.instTranslationM3.ArrivalEdge.Q` | LISIBLE? | `FB_Translation.st:194 = ArrivalEdge(CLK := TargetReached);` | ArrivalEdge déclenché par front de TargetReached | Vérifier TargetReached et Q de ArrivalEdge en aval |
| `PRG_05_Translation.instTranslationM3.EffectivePermitM3_Maintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.EffectivePermitM3_Maintenance` | Entree recue depuis : PRG_05_Translation.EffectivePermitM3_Maintenance | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.EffectivePermitM3_Tremie` | LISIBLE? | `entree liee a : PRG_05_Translation.EffectivePermitM3_Tremie` | Entree recue depuis : PRG_05_Translation.EffectivePermitM3_Tremie | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.LimitSwitchMaintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_LimitSwitchMaintenanceStable` | Entree recue depuis : PRG_05_Translation.M3_LimitSwitchMaintenanceStable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.LimitSwitchTremie` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_LimitSwitchTremieStable` | Entree recue depuis : PRG_05_Translation.M3_LimitSwitchTremieStable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.SafeStop` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_SafeStop_Aggregate` | Entree recue depuis : PRG_05_Translation.M3_SafeStop_Aggregate | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.ArrivalLock` | LISIBLE? | `FB_Translation.st:164 = ArrivalLock := FALSE; ;; FB_Translation.st:215 = ArrivalLock := TRUE;` | ArrivalLock initialisé FALSE puis forcé TRUE en aval | Vérifier la condition de vérouillage arrivée dans FB_Translation.st:215 |
| `PRG_05_Translation.instTranslationM3.RunRequest` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_RunRequest_Active` | Entree recue depuis : PRG_05_Translation.M3_RunRequest_Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.SpeedTgt_Pct` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_SpeedCmd_Active` | Entree recue depuis : PRG_05_Translation.M3_SpeedCmd_Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.RampTargetPct` | LISIBLE? | `FB_Translation.st:298 = RampTargetPct := 0.0; ;; FB_Translation.st:300 = RampTargetPct := LIMIT(0.0, SpeedTgt_Pct, 100.0);` | RampTargetPct est calculé dans FB_Translation à partir de SpeedTgt_Pct limité 0 à 100 | Vérifier la source de SpeedTgt_Pct et le calcul de rampe dans FB_Translation.st:298-300 |
| `PRG_05_Translation.M3_ReqMaintenance_Active` | LISIBLE? | `PRG_05_Translation.st:392 = M3_ReqMaintenance_Active := instArbM3.ReqMaintenance; ;; PRG_05_Translation.st:408 = M3_ReqMaintenance_Active := FALSE;` | M3_ReqMaintenance_Active suit instArbM3.ReqMaintenance ou force FALSE | verifier instArbM3.ReqMaintenance et la branche ligne 408 |
| `PRG_05_Translation.instTranslationM3.DriveActualFreqHz` | LISIBLE? | `entree liee a : PRG_02_Acquisition.Data.M3.ActualFrequencyHz` | Entree recue depuis : PRG_02_Acquisition.Data.M3.ActualFrequencyHz | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.TonBrakeRealFreqTimeout.Q` | LISIBLE? | `FB_Translation.st:173 = TonBrakeRealFreqTimeout(IN := FALSE); ;; FB_Translation.st:312 = TonBrakeRealFreqTimeout( IN := (RampTargetPct <= 0.1) AND (AB` | TonBrakeRealFreqTimeout actif si RampTargetPct <= 0.1 et ABS de SpeedRamp.Current <= 0.1 avec PT 2S | verifier les consommateurs de TonBrakeRealFreqTimeout.Q en aval dans FB_Translation |
| `PRG_05_Translation.instTranslationM3.BrakeFeedback` | LISIBLE? | `entree liee a : GVL_IHM.M3Translation.Bypass.ContactorFeedback, GVL_IHM.M3Translation.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpe` | Entree recue depuis : GVL_IHM.M3Translation.Bypass.ContactorFeedback, GVL_IHM.M3Translation.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.MovementRequested` | LISIBLE? | `FB_Translation.st:317 = MovementRequested := (ABS(SpeedRamp.Current) > 0.1) OR ((ABS(DriveActualFreqHz) > 0.5) AND NOT TonBrakeRealFreqTimeout.Q);` | MovementRequested vrai si vitesse rampe ou frequence depasse seuil sans timeout | verifier SpeedRamp.Current et DriveActualFreqHz |
| `PRG_05_Translation.instTranslationM3.ReqMaintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_ReqMaintenance_Active` | Entree recue depuis : PRG_05_Translation.M3_ReqMaintenance_Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.ReqTremie` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_ReqTremie_Active` | Entree recue depuis : PRG_05_Translation.M3_ReqTremie_Active | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Brake.MovementRequested` | LISIBLE? | `entree liee a : PRG_05_Translation.instTranslationM3.MovementRequested` | Entree recue depuis : PRG_05_Translation.instTranslationM3.MovementRequested | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.InvertDriveDirection` | LISIBLE? | `entree liee a : GVL_IHM.M3Translation.Cmd.InvertDirection` | Entree recue depuis : GVL_IHM.M3Translation.Cmd.InvertDirection | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.SlowdownSensorMaintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.instPosDecoderM3.TranslationPosMaintenance, PRG_05_Translation.instPosDecoderM3.TranslationPosP1` | Entree recue depuis : PRG_05_Translation.instPosDecoderM3.TranslationPosMaintenance, PRG_05_Translation.instPosDecoderM3.TranslationPosP1 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.SlowdownSensorP1` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable, PRG_05_Translation.instPosDecoderM3.TranslationPosP1, PRG_05_Translation.instP` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable, PRG_05_Translation.instPosDecoderM3.TranslationPosP1, PRG_05_Translation.instPosDecoderM3.TranslationPosP2 | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.SlowdownSensorTremie` | LISIBLE? | `entree liee a : PRG_05_Translation.instPosDecoderM3.TranslationPosPV` | Entree recue depuis : PRG_05_Translation.instPosDecoderM3.TranslationPosPV | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.Brake.BrakeCmd` | VISIBLE | `FB_Brake.st:104 = BrakeCmd := FALSE; ;; FB_Brake.st:137 = BrakeCmd := FALSE;` | BrakeCmd faux dans les deux branches | FB_Brake.st:104 et 137 verifier logique interne FB_Brake |
| `PRG_05_Translation.instTranslationM3.Enable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instTranslationM3.PhysicalMaintenance` | LISIBLE? | `FB_Translation.st:337 = PhysicalMaintenance := CommandedMaintenance; ;; FB_Translation.st:340 = PhysicalMaintenance := CommandedTremie;` | PhysicalMaintenance reflete CommandedMaintenance puis CommandedTremie | FB_Translation.st:337 et 340 verifier CommandedMaintenance et CommandedTremie |
| `PRG_05_Translation.instTranslationM3.RequestedDriveFreqHz` | VISIBLE | `FB_Translation.st:156 = RequestedDriveFreqHz := 0.0; ;; FB_Translation.st:351 = RequestedDriveFreqHz := (SpeedRamp.Current / 100.0) * Cfg.DriveFreqSca` | RequestedDriveFreqHz 0 puis calcule depuis SpeedRamp et Cfg.DriveFreqScaleMaxHz | FB_Translation.st:156 et 351 verifier SpeedRamp et Cfg.DriveFreqScaleMaxHz |
| `PRG_05_Translation.TranslationFinalInterlockRequest.ReqTremieSemantic` | LISIBLE? | `PRG_05_Translation.st:709 = TranslationFinalInterlockRequest.ReqTremieSemantic := M3_ReqTremie_Active; ;; PRG_05_Translation.st:720 = TranslationFinal` | M3_ReqTremie_Active vrai puis remis a FALSE | PRG_05_Translation.st:709 et 720 verifier arbitrage M3_ReqTremie_Active |
| `PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveFreqHz` | LISIBLE? | `PRG_05_Translation.st:708 = TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz; ;; PRG_05_Translation.st:` | RequestedDriveFreqHz repris de instTranslationM3 puis remis a 0 | PRG_05_Translation.st:708 et 719 verifier sortie instTranslationM3 |
| `PRG_05_Translation.instTranslationM3.BrakeCommandOpenConfirmed` | VISIBLE | `FB_Translation.st:158 = BrakeCommandOpenConfirmed := FALSE; ;; FB_Translation.st:333 = BrakeCommandOpenConfirmed := Brake.BrakeCommandOpenConfirmed;` | BrakeCommandOpenConfirmed faux puis reflete Brake | FB_Translation.st:158 et 333 verifier retour Brake.BrakeCommandOpenConfirmed |
| `PRG_05_Translation.instTranslationM3.BrakeReleaseRequest` | VISIBLE | `FB_Translation.st:157 = BrakeReleaseRequest := FALSE; ;; FB_Translation.st:332 = BrakeReleaseRequest := Brake.BrakeCmd;` | BrakeReleaseRequest faux puis reflete Brake.BrakeCmd | FB_Translation.st:157 et 332 verifier Brake.BrakeCmd |
| `PRG_05_Translation.instTranslationM3.RequestedDriveControlWord` | VISIBLE | `FB_Translation.st:155 = RequestedDriveControlWord := 0; ;; FB_Translation.st:344 = RequestedDriveControlWord := 1;` | RequestedDriveControlWord 0 puis 1 | FB_Translation.st:155 et 344 verifier etat interne du FB |
| `PRG_07_Supervision.FaultMachineReset_IHM` | LISIBLE? | `PRG_07_Supervision.st:138 = FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset OR GVL_IHM.M2TreuilBenne.` | un des BtnReset IHM vrai | PRG_07_Supervision.st:138 verifier les cinq bits IHM de reset |
| `PRG_05_Translation.TranslationFinalInterlockRequest.BrakeReleaseRequest` | LISIBLE? | `PRG_05_Translation.st:705 = TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest; ;; PRG_05_Translation.st:71` | BrakeReleaseRequest copie depuis instTranslationM3 puis forcee FALSE | verifier instTranslationM3.BrakeReleaseRequest et la condition de forcage a FALSE |
| `PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord` | LISIBLE? | `PRG_05_Translation.st:707 = TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord; ;; PRG_05_Trans` | RequestedDriveControlWord copie depuis instTranslationM3 puis force a 0 | verifier instTranslationM3.RequestedDriveControlWord et la condition de forcage a 0 |

### PERMIS (15)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.ArmM1AscentAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM1DescendAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM2AscentAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM2DescendAvail` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.ArmM3MaintenanceAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1171 = ArmM3MaintenanceAvail := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance AND NOT` | MaintenanceAvail vrai si EffectivePermitM3_Maintenance et pas SafeStop ni PowerCutOff | verifier EffectivePermitM3_Maintenance et TranslationSafety |
| `PRG_04_Treuils_Benne.ArmM3TremieAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1168 = ArmM3TremieAvail := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie AND NOT PRG_05_Tr` | TremieAvail vrai si EffectivePermitM3_Tremie et pas SafeStop ni PowerCutOff | verifier EffectivePermitM3_Tremie et TranslationSafety |
| `PRG_04_Treuils_Benne.ArmAnyAxisAvail` | LISIBLE? | `PRG_04_Treuils_Benne.st:1175 = ArmAnyAxisAvail := ArmM1AscentAvail OR ArmM1DescendAvail OR ArmM2AscentAvail OR ArmM2DescendAvail OR ArmM3TremieAvail O` | ArmAnyAxisAvail vrai si un des Arm M1 M2 M3 est disponible | verifier chaque ArmDisponible en aval |
| `PRG_04_Treuils_Benne.ArmBucketBusy` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmingPermit |
| `PRG_04_Treuils_Benne.ArmContactorOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1187 = ArmContactorOff := NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;` | ArmContactorOff vrai si PowerContactorEngaged_DI absent | verifier PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI |
| `PRG_04_Treuils_Benne.ArmingPermit` | VISIBLE | `PRG_04_Treuils_Benne.st:1205 = ArmingPermit := NOT ArmModeDisabled AND NOT ArmContactorOff AND NOT ArmPowerCutOff AND NOT ArmBucketBusy AND ArmAnyAxis` | ArmingPermit calcule par conditions Arm et disponibilite axe | verifier ArmModeDisabled ArmContactorOff ArmPowerCutOff ArmBucketBusy ArmAnyAxisAvail |
| `PRG_04_Treuils_Benne.Data.ArmingPermit` | VISIBLE | `PRG_04_Treuils_Benne.st:1962 = Data.ArmingPermit := ArmingPermit;` | ArmingPermit affecte a Data.ArmingPermit | verifier ArmingPermit et ses conditions de calcul |
| `PRG_05_Translation.EffectivePermitM3_Maintenance` | VISIBLE | `PRG_05_Translation.st:558 = EffectivePermitM3_Maintenance := instSafetyTranslationM3.MaintenanceLimitClear AND NOT M3_SafeStop_Aggregate AND NOT instS` | MaintenanceLimitClear vrai et SafeStop_Aggregate faux et PowerCutOff faux | PRG_05_Translation.st:558 verifier safety translation et M3_SafeStop_Aggregate |
| `PRG_05_Translation.EffectivePermitM3_Tremie` | VISIBLE | `PRG_05_Translation.st:554 = EffectivePermitM3_Tremie := instSafetyTranslationM3.TremieLimitClear AND NOT M3_SafeStop_Aggregate AND NOT instSafetyTrans` | TremieLimitClear vrai et SafeStop_Aggregate faux et PowerCutOff faux et TremieProcessBlock faux | PRG_05_Translation.st:554 verifier safety translation et blocage process tremie |
| `PRG_05_Translation.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie` | LISIBLE? | `PRG_05_Translation.st:703 = TranslationFinalInterlockRequest.EffectivePermitM3_Tremie := EffectivePermitM3_Tremie;` | EffectivePermitM3_Tremie vrai | PRG_05_Translation.st:703 verifier calcul de EffectivePermitM3_Tremie |
| `PRG_05_Translation.TranslationFinalInterlockRequest.Enable` | LISIBLE? | `PRG_05_Translation.st:698 = TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE);` | Auth.Mode different de DISABLE | PRG_05_Translation.st:698 verifier Auth.Mode en amont |

### SECURITE (22)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_05_Translation.Data.TranslationSafety.SafeStop` | VISIBLE | `PRG_05_Translation.st:882 = Data.TranslationSafety := TranslationSafety;` | SafeStop est affecte depuis TranslationSafety | verifier la consommation de Data.TranslationSafety.SafeStop |
| `PRG_05_Translation.TranslationSafety.PowerCutOff` | VISIBLE | `PRG_05_Translation.st:806 = TranslationSafety.PowerCutOff := instSafetyTranslationM3.PowerCutOff;` | PowerCutOff est copie depuis instSafetyTranslationM3 | verifier l usage de TranslationSafety.PowerCutOff en aval |
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmPowerCutOff |
| `PRG_04_Treuils_Benne.instSafetyWinchM2.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.ArmPowerCutOff |
| `PRG_04_Treuils_Benne.ArmPowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1188 = ArmPowerCutOff := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff OR PRG_05_Translation.Data.Translation` | ArmPowerCutOff vrai si PowerCutOff d un winch M1 M2 ou translation | verifier PowerCutOff des securites winch et translation |
| `PRG_05_Translation.M3_HeightInterlockOk` | VISIBLE | `PRG_05_Translation.st:137 = M3_HeightInterlockOk := GVL_IHM.M3Translation.Bypass.MinHeight OR (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable AND ` | Interlock hauteur vrai si Bypass.MinHeight ou M1 et M2 homed fiables et positions supérieures au minimum | Vérifier Bypass.MinHeight, HomedAndReliable et CablePosM des encodeurs M1 et M2 |
| `PRG_05_Translation.M3_LimitSwitchMaintenanceEffective` | LISIBLE? | `PRG_05_Translation.st:155 = M3_LimitSwitchMaintenanceEffective := SEL(PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable, NOT instPosDecoderM3.Tra` | M3_LimitSwitchMaintenanceEffective selon Auth.MaintenanceM3TargetEnable et etat decodeur | verifier les consommateurs de M3_LimitSwitchMaintenanceEffective en aval |
| `PRG_02_Acquisition.Data.InputModules.Fault` | VISIBLE | `PRG_02_Acquisition.st:217 = Data.InputModules.Fault := NOT (Data.InputModules.LocalDigitalIoOk AND Data.InputModules.Vh0800EndOk AND Data.InputModules` | Fault si un des modules IO n'est pas OK | verifier chaque flag Ok des modules IO |
| `PRG_02_Acquisition.instCycleMachineHoming.M3Locked` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.Data.MachineHoming.M3Locked |
| `PRG_05_Translation.M3_LimitSwitchMaintenanceStable` | VISIBLE | `PRG_05_Translation.st:190 = M3_LimitSwitchMaintenanceStable := TRUE; ;; PRG_05_Translation.st:192 = M3_LimitSwitchMaintenanceStable := FALSE;` | M3_LimitSwitchMaintenanceStable mis a TRUE ou FALSE selon branche | verifier la condition des lignes 190 et 192 |
| `PRG_05_Translation.M3_LimitSwitchTremieStable` | VISIBLE | `PRG_05_Translation.st:166 = M3_LimitSwitchTremieStable := TRUE; ;; PRG_05_Translation.st:168 = M3_LimitSwitchTremieStable := FALSE;` | M3_LimitSwitchTremieStable mis a TRUE ou FALSE selon branche | verifier la condition des lignes 166 et 168 |
| `PRG_05_Translation.instSafetyTranslationM3.PowerContactorEngaged` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.M3_SafeStop_Active` | VISIBLE | `PRG_05_Translation.st:417 = M3_SafeStop_Active := PRG_02_Acquisition.Data.InputModules.Fault;` | M3_SafeStop_Active vrai si Data.InputModules.Fault vrai | verifier Data.InputModules.Fault en amont |
| `PRG_05_Translation.instSafetyTranslationM3.LimitSwitchMaintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_LimitSwitchMaintenanceStable` | Entree recue depuis : PRG_05_Translation.M3_LimitSwitchMaintenanceStable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instSafetyTranslationM3.LimitSwitchTremie` | LISIBLE? | `entree liee a : PRG_05_Translation.M3_LimitSwitchTremieStable` | Entree recue depuis : PRG_05_Translation.M3_LimitSwitchTremieStable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instSafetyTranslationM3.SafeStop` | VISIBLE | `FB_Safety_Translation.st:241 = SafeStop := FALSE; ;; FB_Safety_Translation.st:266 = SafeStop := Fault.Error OR NOT PowerContactorEngaged;` | SafeStop faux sauf defaut ou power contactor non engage | verifier Fault.Error et PowerContactorEngaged |
| `PRG_05_Translation.M3_SafeStop_Aggregate` | VISIBLE | `PRG_05_Translation.st:524 = M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop OR PRG_02_Acquisition.Data.MachineHoming.M` | M3_SafeStop_Active vrai ou instSafetyTranslationM3.SafeStop vrai ou MachineHoming.M3Locked vrai | verifier M3_SafeStop_Active instSafetyTranslationM3.SafeStop et MachineHoming.M3Locked en amont |
| `PRG_05_Translation.instSafetyTranslationM3.Enable` | LISIBLE? | `entree liee a : PRG_03_Modes_Cycle.Data.Auth.Mode` | Entree recue depuis : PRG_03_Modes_Cycle.Data.Auth.Mode | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instSafetyTranslationM3.MaintenanceLimitClear` | LISIBLE? | `FB_Safety_Translation.st:252 = MaintenanceLimitClear := FALSE; ;; FB_Safety_Translation.st:291 = MaintenanceLimitClear := NOT LimitSwitchMaintenance;` | MaintenanceLimitClear vrai si pas LimitSwitchMaintenance | verifier LimitSwitchMaintenance en amont |
| `PRG_05_Translation.instSafetyTranslationM3.TremieLimitClear` | LISIBLE? | `FB_Safety_Translation.st:251 = TremieLimitClear := FALSE; ;; FB_Safety_Translation.st:290 = TremieLimitClear := NOT LimitSwitchTremie;` | TremieLimitClear vrai si pas LimitSwitchTremie | verifier LimitSwitchTremie en amont |
| `PRG_05_Translation.instSafetyTranslationM3.PowerCutOff` | VISIBLE | `FB_Safety_Translation.st:242 = PowerCutOff := FALSE; ;; FB_Safety_Translation.st:269 = PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` | PowerCutOff faux puis calcule sur Fault.ErrorId masque 00F8 | FB_Safety_Translation.st:242 et 269 verifier Fault.ErrorId du safety |
| `PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_05_Translation.st:702 = TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;` | instSafetyTranslationM3.PowerCutOff vrai | PRG_05_Translation.st:702 verifier sortie PowerCutOff du safety |

### BARRIERE (19)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_05_Translation.TonTremieProcessBlock.Q` | VISIBLE | `PRG_05_Translation.st:179 = TonTremieProcessBlock( IN := PRG_02_Acquisition.HwIn.Machine.TremieFull_OR_GateRaised_DI AND NOT GVL_IHM.M3Translation.Byp` | TonTremieProcessBlock.Q vrai apres 200ms si TremieFull_OR_GateRaised_DI et pas Bypass.LimitSwitch ni Bypass.Global | verifier TremieFull_OR_GateRaised_DI et les deux Bypass en amont |
| `PRG_05_Translation.M3_TremieProcessBlock` | VISIBLE | `PRG_05_Translation.st:184 = M3_TremieProcessBlock := TonTremieProcessBlock.Q;` | TonTremieProcessBlock.Q vrai | verifier la temporisation TonTremieProcessBlock et son IN en amont |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.EffectivePermitM3_Maintenance` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.EffectivePermitM3_Tremie` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI, PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI, PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveFreqHz` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz, PRG_06_Outputs.M3_TremieHardStopActive` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz, PRG_06_Outputs.M3_TremieHardStopActive | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` | LISIBLE? | `FB_TranslationOutputInterlock.st:70 = ResetEdge(CLK := Reset);` | ResetEdge capture le front de Reset | verifier Reset noeud 36 et la logique de front dans le FB |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCmd` | LISIBLE? | `FB_TranslationOutputInterlock.st:137 = BrakeCmd := BrakeReleaseRequest AND NOT Fault.Error AND NOT RestartInhibit; ;; FB_TranslationOutputInterlock.st` | BrakeCmd actif si BrakeReleaseRequest ET NOT Fault.Error ET NOT RestartInhibit | verifier BrakeReleaseRequest noeud 7 et RestartInhibit noeud 13 |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCommandOpenConfirmed` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeReleaseRequest` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, PRG_06_Outputs.M3_TremieHardStopActive` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, PRG_06_Outputs.M3_TremieHardStopActive | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmd_Hz` | LISIBLE? | `FB_TranslationOutputInterlock.st:134 = DriveFreqCmd_Hz := 0.0; ;; FB_TranslationOutputInterlock.st:150 = DriveFreqCmd_Hz := MAX(0.0, RequestedDriveFre` | DriveFreqCmd_Hz vaut 0 ou MAX de RequestedDriveFreqHz | verifier RequestedDriveFreqHz noeud 23 |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.M3InterlockEnable` | Entree recue depuis : PRG_06_Outputs.M3InterlockEnable | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.PermitFinalBlocked` | LISIBLE? | `FB_TranslationOutputInterlock.st:85 = PermitFinalBlocked := ((RequestedDriveControlWord = 1) AND NOT EffectivePermitM3_Tremie) OR ((RequestedDriveCont` | PermitFinalBlocked vrai si demande 1 sans permit tremie ou demande 2 sans permit maintenance | verifier EffectivePermitM3_Tremie noeud 22 et EffectivePermitM3_Maintenance noeud 21 |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.PowerContactorEngaged` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveControlWord` | LISIBLE? | `entree liee a : PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord, PRG_06_Outputs.M3_TremieHardStopActive, PRG_06_Out` | Entree recue depuis : PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord, PRG_06_Outputs.M3_TremieHardStopActive, PRG_06_Outputs.WORD | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` | LISIBLE? | `FB_TranslationOutputInterlock.st:104 = RestartInhibit := TRUE; ;; FB_TranslationOutputInterlock.st:127 = RestartInhibit := FALSE;` | RestartInhibit vrai puis faux selon le chemin du FB | chercher la condition qui remet RestartInhibit a FALSE |
| `PRG_06_Outputs.TranslationBrakeCmd` | LISIBLE? | `PRG_06_Outputs.st:453 = TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;` | la ligne affecte TranslationBrakeCmd depuis BrakeCmd | verifier le calcul de instTranslationOutputInterlockM3.BrakeCmd noeud 5 |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` | LISIBLE? | `FB_TranslationOutputInterlock.st:133 = DriveControlWord := 0; ;; FB_TranslationOutputInterlock.st:142 = DriveControlWord := 7;` | DriveControlWord affecte a 0 ou a 7 selon le chemin du FB | chercher pourquoi le FB choisit 0 plutot que 7 |
| `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmdWord` | LISIBLE? | `FB_TranslationOutputInterlock.st:135 = DriveFreqCmdWord := 0; ;; FB_TranslationOutputInterlock.st:155 = DriveFreqCmdWord := REAL_TO_WORD(LIMIT(0.0, Dr` | DriveFreqCmdWord calcule depuis DriveFreqCmd_Hz limite et mis a l echelle | verifier la valeur de DriveFreqCmd_Hz noeud 8 et les bornes DriveFreqWordMaxHz DriveFreqWordScale |

### SORTIE (4)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.instSimBench.Operator` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Operator |
| `PRG_05_Translation.Data.TranslationSafety.PowerCutOff` | VISIBLE | `PRG_05_Translation.st:882 = Data.TranslationSafety := TranslationSafety;` | TranslationSafety copie vers Data.TranslationSafety | verifier Data.TranslationSafety en aval |
| `PRG_06_Outputs.M3_CommandWord` | A CONTROLER | `PRG_06_Outputs.st:458 = M3_CommandWord := instTranslationOutputInterlockM3.DriveControlWord;` | la ligne affecte M3_CommandWord depuis DriveControlWord | verifier le calcul de instTranslationOutputInterlockM3.DriveControlWord noeud 3 |
| `PRG_06_Outputs.M3_SetpointFrequencyHz` | A CONTROLER | `PRG_06_Outputs.st:459 = M3_SetpointFrequencyHz := instTranslationOutputInterlockM3.DriveFreqCmdWord;` | la ligne affecte M3_SetpointFrequencyHz depuis DriveFreqCmdWord | verifier le calcul de instTranslationOutputInterlockM3.DriveFreqCmdWord noeud 4 |

### MESURE (89)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_05_Translation.M3_BootSensorsWordCandidate` | LISIBLE? | `PRG_05_Translation.st:230 = M3_BootSensorsWordCandidate := instPosDecoderM3.SensorsWord;` | M3_BootSensorsWordCandidate copie SensorsWord du decodeur | verifier l usage de M3_BootSensorsWordCandidate en aval |
| `PRG_05_Translation.M3_SensorsWordPrev` | LISIBLE? | `PRG_05_Translation.st:213 = M3_SensorsWordPrev := instPosDecoderM3.SensorsWord; ;; PRG_05_Translation.st:216 = M3_SensorsWordPrev := instPosDecoderM3.` | M3_SensorsWordPrev est mis a jour avec SensorsWord | verifier l usage de M3_SensorsWordPrev en aval |
| `PRG_05_Translation.instPosDecoderM3.SensorTremie` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.M3_BootSensorsStableTimer.Q` | LISIBLE? | `PRG_05_Translation.st:231 = M3_BootSensorsStableTimer(IN := FALSE, PT := T#500ms); ;; PRG_05_Translation.st:233 = M3_BootSensorsStableTimer(IN := TRUE` | le timer de stabilite capteurs est arme a FALSE puis TRUE avec 500ms | verifier la lecture de M3_BootSensorsStableTimer.Q en aval |
| `PRG_05_Translation.M3_ConfirmedMoving` | LISIBLE? | `PRG_05_Translation.st:203 = M3_ConfirmedMoving := (UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0) > 0.5;` | M3_ConfirmedMoving est vrai si la frequence reelle depasse 0.5 | verifier l usage de M3_ConfirmedMoving en aval |
| `PRG_05_Translation.M3_SensorsWordChanged` | LISIBLE? | `PRG_05_Translation.st:215 = M3_SensorsWordChanged := (instPosDecoderM3.SensorsWord <> M3_SensorsWordPrev);` | M3_SensorsWordChanged compare SensorsWord au precedent | verifier l usage de M3_SensorsWordChanged en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtMaintenance` | LISIBLE? | `FB_Translation_PositionDecoder.st:117 = TranslationAtMaintenance := EdgeDnMaintenance.Q;` | TranslationAtMaintenance suit le front descendant maintenance | verifier l usage de TranslationAtMaintenance en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtP1` | LISIBLE? | `FB_Translation_PositionDecoder.st:116 = TranslationAtP1 := EdgeUpP1.Q OR EdgeDnP1.Q;` | TranslationAtP1 suit les fronts haut ou bas P1 | verifier l usage de TranslationAtP1 en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtP2` | LISIBLE? | `FB_Translation_PositionDecoder.st:115 = TranslationAtP2 := EdgeUpP2.Q OR EdgeDnP2.Q;` | TranslationAtP2 suit les fronts haut ou bas P2 | verifier l usage de TranslationAtP2 en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtPV` | LISIBLE? | `FB_Translation_PositionDecoder.st:114 = TranslationAtPV := EdgeUpPV.Q OR EdgeDnPV.Q;` | TranslationAtPV suit les fronts haut ou bas PV | verifier l usage de TranslationAtPV en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationAtTremie` | LISIBLE? | `FB_Translation_PositionDecoder.st:113 = TranslationAtTremie := EdgeUpTremie.Q;` | TranslationAtTremie suit le front montant Tremie | verifier l usage de TranslationAtTremie en aval |
| `PRG_05_Translation.instPosDecoderM3.TranslationPosTremie` | VISIBLE | `FB_Translation_PositionDecoder.st:94 = TranslationPosTremie := SensorTremie;` | TranslationPosTremie reflete SensorTremie | verifier l usage de TranslationPosTremie en aval |
| `PRG_02_Acquisition.HwReal.Operator.CanBusState` | LISIBLE? | `PRG_02_Acquisition.st:185 = HwReal.Operator.CanBusState := CANbus.GetBusState();` | l etat du bus CAN est lu via GetBusState | verifier l usage de CanBusState en aval |
| `PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` | LISIBLE? | `PRG_02_Acquisition.st:186 = HwReal.Operator.JOY1_DeviceState := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();` | l etat du joystick est lu via GetDeviceState | verifier l usage de JOY1_DeviceState en aval |
| `PRG_02_Acquisition._JoystickNeutralY` | A CONTROLER | `PRG_02_Acquisition.st:496 = instJoystick( Enable := TRUE, Reset := PRG_07_Supervision.FaultMachineReset_IHM, ArmingPermit := PRG_04_Treuils_Benne.Data` | instJoystick est appele avec Enable TRUE et Reset IHM | Verifier en aval : PRG_02_Acquisition.instJoystick.NeutralYMem |
| `PRG_05_Translation.M3_AtMaintenanceStable` | LISIBLE? | `PRG_05_Translation.st:249 = M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE; ;; PRG_05_Transla` | M3_AtMaintenanceStable est mis a FALSE sur les lignes citees | Verifier en aval : PRG_05_Translation.M3_PositionSensorTarget |
| `PRG_05_Translation.M3_AtP1Stable` | LISIBLE? | `PRG_05_Translation.st:249 = M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE; ;; PRG_05_Transla` | M3_AtP1Stable est mis a FALSE sur les lignes citees | Verifier en aval : PRG_05_Translation.M3_PositionSensorTarget |
| `PRG_05_Translation.M3_AtP2Stable` | LISIBLE? | `PRG_05_Translation.st:249 = M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE; ;; PRG_05_Transla` | M3_AtP2Stable est mis a FALSE sur les lignes citees | Verifier en aval : PRG_05_Translation.M3_PositionSensorTarget |
| `PRG_05_Translation.M3_AtTremieStable` | LISIBLE? | `PRG_05_Translation.st:248 = M3_AtTremieStable := GVL_PERSISTENT._TranslationAtTremiePersisted OR instPosDecoderM3.TranslationPosTremie; ;; PRG_05_Tran` | M3_AtTremieStable vaut persistance ou TranslationPosTremie selon la ligne citee | verifier la coherence avec le reset a FALSE |
| `PRG_02_Acquisition.instDiagCanOpen.CANbusStateRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwReal.Operator.CanBusState` | Entree recue depuis : PRG_02_Acquisition.HwReal.Operator.CanBusState | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystickStateRaw` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState` | Entree recue depuis : PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.M3_PositionSensorTarget` | LISIBLE? | `PRG_05_Translation.st:455 = 1: M3_PositionSensorTarget := M3_AtTremieStable; ;; PRG_05_Translation.st:456 = 2: M3_PositionSensorTarget := M3_AtP2Stabl` | PositionSensorTarget selon M3_AtTremieStable ou M3_AtP2Stable | verifier M3_AtTremieStable et M3_AtP2Stable |
| `PRG_02_Acquisition.Data.Joystick.AxisX.SpeedTgt` | LISIBLE? | `PRG_02_Acquisition.st:529 = Data.Joystick.AxisX := instJoystick.AxisCmdX;` | SpeedTgt issu de instJoystick.AxisCmdX | verifier instJoystick.AxisCmdX dans FB_Joystick |
| `PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1` | VISIBLE | `PRG_02_Acquisition.st:483 = HwIn.Operator := SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator);` | HwIn.Operator est affecté par SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator) ligne 483 | VRAI |
| `PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2` | VISIBLE | `PRG_02_Acquisition.st:483 = HwIn.Operator := SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator);` | HwIn.Operator est affecté par SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator) ligne 483 | VRAI |
| `GVL_IHM.CycleSemiAuto.State.CycleStep` | LISIBLE? | `PRG_07_Supervision.st:687 = GVL_IHM.CycleSemiAuto.State.CycleStep := PRG_03_Modes_Cycle.Data.SequenceState.Step;` | CycleStep recopie depuis SequenceState.Step | verifier SequenceState.Step dans PRG_03_Modes_Cycle |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational` | VISIBLE | `FB_Diag_CanOpen.st:130 = DeviceCanOpenMaster.Operational := CANbusOnlineEff; ;; FB_Diag_CanOpen.st:56 = DeviceCanOpenMaster.Operational := FALSE;` | Operational de DeviceCanOpenMaster suit CANbusOnlineEff | verifier CANbusOnlineEff et la branche FALSE |
| `PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational` | VISIBLE | `FB_Diag_CanOpen.st:106 = DeviceJoystick.Operational := FALSE; ;; FB_Diag_CanOpen.st:108 = DeviceJoystick.Operational := TRUE;` | Operational de DeviceJoystick suit les branches FALSE et TRUE | Verifier en aval : PRG_02_Acquisition.instJoystick.JoystickOP.Operational |
| `PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.M3_HeightInterlockOk |
| `PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative` | LISIBLE? | `PRG_02_Acquisition.st:529 = Data.Joystick.AxisX := instJoystick.AxisCmdX;` | DirectionNegative joystick X affecté depuis instJoystick.AxisCmdX | Vérifier instJoystick.AxisCmdX et la qualification de direction en amont |
| `PRG_02_Acquisition.Data.Joystick.AxisY.AtNeutral` | LISIBLE? | `PRG_02_Acquisition.st:530 = Data.Joystick.AxisY := instJoystick.AxisCmdY;` | AtNeutral joystick Y affecté depuis instJoystick.AxisCmdY | Vérifier instJoystick.AxisCmdY et la qualification en amont |
| `PRG_05_Translation.instPosDecoderM3.SensorsWord` | LISIBLE? | `FB_Translation_PositionDecoder.st:71 = SensorsWord := 0; ;; FB_Translation_PositionDecoder.st:72 = IF SensorTremie THEN SensorsWord := SensorsWord OR ` | SensorsWord remis à 0 puis bit 16#10 si SensorTremie | Vérifier SensorTremie et les autres bits ajoutés à SensorsWord |
| `PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk` | LISIBLE? | `PRG_02_Acquisition.st:205 = Data.InputModules.LocalDigitalIoOk := TRUE; ;; PRG_02_Acquisition.st:211 = Data.InputModules.LocalDigitalIoOk := (Local_Di` | LocalDigitalIoOk vrai si device RUNNING apres init TRUE | verifier les consommateurs de Data.InputModules.LocalDigitalIoOk |
| `PRG_02_Acquisition.Data.InputModules.Vh0008Er1Ok` | LISIBLE? | `PRG_02_Acquisition.st:209 = Data.InputModules.Vh0008Er1Ok := TRUE; ;; PRG_02_Acquisition.st:215 = Data.InputModules.Vh0008Er1Ok := (VH_0008ER_1.GetDev` | Vh0008Er1Ok vrai si VH_0008ER_1 RUNNING apres init TRUE | verifier les consommateurs de Data.InputModules.Vh0008Er1Ok |
| `PRG_02_Acquisition.Data.InputModules.Vh0008ErOk` | LISIBLE? | `PRG_02_Acquisition.st:208 = Data.InputModules.Vh0008ErOk := TRUE; ;; PRG_02_Acquisition.st:214 = Data.InputModules.Vh0008ErOk := (VH_0008ER.GetDeviceS` | Vh0008ErOk vrai si VH_0008ER RUNNING apres init TRUE | verifier les consommateurs de Data.InputModules.Vh0008ErOk |
| `PRG_02_Acquisition.Data.InputModules.Vh0800EndOk` | LISIBLE? | `PRG_02_Acquisition.st:206 = Data.InputModules.Vh0800EndOk := TRUE; ;; PRG_02_Acquisition.st:212 = Data.InputModules.Vh0800EndOk := (VH_0800END.GetDevi` | Vh0800EndOk vrai si VH_0800END RUNNING apres init TRUE | verifier les consommateurs de Data.InputModules.Vh0800EndOk |
| `PRG_02_Acquisition.Data.InputModules.Vh0808EtpOk` | LISIBLE? | `PRG_02_Acquisition.st:207 = Data.InputModules.Vh0808EtpOk := TRUE; ;; PRG_02_Acquisition.st:213 = Data.InputModules.Vh0808EtpOk := (VH_0808ETP.GetDevi` | Vh0808EtpOk vrai si VH_0808ETP RUNNING apres init TRUE | verifier les consommateurs de Data.InputModules.Vh0808EtpOk |
| `PRG_02_Acquisition.Data.Joystick.AxisY.Direction` | VISIBLE | `PRG_02_Acquisition.st:530 = Data.Joystick.AxisY := instJoystick.AxisCmdY;` | Data.Joystick.AxisY copie de instJoystick.AxisCmdY | verifier le calcul de instJoystick.AxisCmdY dans FB_Joystick |
| `PRG_02_Acquisition.Data.Joystick.DeadmanArmed` | VISIBLE | `PRG_02_Acquisition.st:531 = Data.Joystick.DeadmanArmed := instJoystick.DeadmanArmed;` | Data.Joystick.DeadmanArmed copie de instJoystick.DeadmanArmed | verifier le calcul de instJoystick.DeadmanArmed dans FB_Joystick |
| `PRG_02_Acquisition.Data.M3.ActualFrequencyHz` | VISIBLE | `PRG_02_Acquisition.st:750 = Data.M3.ActualFrequencyHz := HwIn.Translation.M3_ActualFrequencyHz;` | Data.M3.ActualFrequencyHz copie de HwIn.Translation.M3_ActualFrequencyHz | verifier la source de HwIn.Translation.M3_ActualFrequencyHz |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | HwIn.Translation selectionne entre HwReal et HwSim selon TranslationInputSourceSimulated | verifier TranslationInputSourceSimulated et la valeur simulee ou reelle |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | HwIn.Translation est affecté par SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation) ligne 482 | VRAI |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | HwIn.Translation est affecté par SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation) ligne 482 | VRAI |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | HwIn.Translation est affecté par SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation) ligne 482 | VRAI |
| `PRG_05_Translation.instPosDecoderM3.LimitSwitchMaintenance` | LISIBLE? | `FB_Translation_PositionDecoder.st:88 = LimitSwitchMaintenance := (NOT Incoherent) AND (SensorsWord = 2#00000);` | LimitSwitchMaintenance vrai si NOT Incoherent et SensorsWord egal 2#00000 | verifier les consommateurs de instPosDecoderM3.LimitSwitchMaintenance |
| `PRG_05_Translation.instPosDecoderM3.LimitSwitchTremie` | LISIBLE? | `FB_Translation_PositionDecoder.st:87 = LimitSwitchTremie := (NOT Incoherent) AND (SensorsWord = 2#11111);` | LimitSwitchTremie vrai si NOT Incoherent et SensorsWord egal 2#11111 | verifier les consommateurs de instPosDecoderM3.LimitSwitchTremie |
| `PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive` | LISIBLE? | `PRG_02_Acquisition.st:529 = Data.Joystick.AxisX := instJoystick.AxisCmdX;` | AxisX affecte depuis instJoystick.AxisCmdX | verifier instJoystick.AxisCmdX |
| `PRG_02_Acquisition.HwIn.Machine.TremieFull_OR_GateRaised_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | HwIn.Machine est affecté par SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine) ligne 484 | VRAI |
| `PRG_05_Translation.instPosDecoderM3.SensorMaintenance` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instPosDecoderM3.SensorP1` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instPosDecoderM3.SensorP2` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_05_Translation.instPosDecoderM3.SensorPV` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_02_Acquisition.Data.MachineHoming.M3Locked` | LISIBLE? | `PRG_02_Acquisition.st:632 = Data.MachineHoming.M3Locked := instCycleMachineHoming.M3Locked;` | M3Locked copie depuis instCycleMachineHoming.M3Locked | verifier instCycleMachineHoming.M3Locked en amont |
| `PRG_05_Translation.instPosDecoderM3.TranslationPosMaintenance` | VISIBLE | `FB_Translation_PositionDecoder.st:98 = TranslationPosMaintenance := SensorMaintenance;` | TranslationPosMaintenance reflete SensorMaintenance | verifier SensorMaintenance en amont du PositionDecoder |
| `PRG_05_Translation.instPosDecoderM3.TranslationPosP1` | VISIBLE | `FB_Translation_PositionDecoder.st:97 = TranslationPosP1 := SensorP1;` | TranslationPosP1 reflete SensorP1 | verifier SensorP1 en amont du PositionDecoder |
| `PRG_05_Translation.instPosDecoderM3.TranslationPosP2` | VISIBLE | `FB_Translation_PositionDecoder.st:96 = TranslationPosP2 := SensorP2;` | TranslationPosP2 reflete SensorP2 | verifier SensorP2 en amont du PositionDecoder |
| `PRG_05_Translation.instPosDecoderM3.TranslationPosPV` | VISIBLE | `FB_Translation_PositionDecoder.st:95 = TranslationPosPV := SensorPV;` | TranslationPosPV reflete SensorPV | verifier SensorPV en amont du PositionDecoder |
| `PRG_02_Acquisition.ConveyorInfeedReady_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.EmergencyChainClosed_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HydraulicThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PhaseRotationOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HwReal.Machine` | LISIBLE? | `PRG_02_Acquisition.st:189 = HwReal.Machine.PowerContactorEngaged_DI := PowerContactorEngaged_DI; ;; PRG_02_Acquisition.st:190 = HwReal.Machine.Emergen` | PowerContactorEngaged_DI et EmergencyChainClosed_DI lus | PRG_02_Acquisition.st:189 et 190 verifier les entrees DI machine |
| `PRG_02_Acquisition.HwSim.Machine` | LISIBLE? | `PRG_02_Acquisition.st:437 = HwSim.Machine := instSimBench.Machine;` | instSimBench.Machine copie | PRG_02_Acquisition.st:437 verifier sortie instSimBench.Machine |
| `PRG_02_Acquisition.M3_PosMaintenance_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.M3_PosP1_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.M3_PosPVP2_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.M3_PosPV_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.M3_PosTremie_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.M3_ThermalOK_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.instSimBench.Translation` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Translation |
| `PRG_02_Acquisition.HwReal.Translation` | LISIBLE? | `PRG_02_Acquisition.st:170 = HwReal.Translation.M3_PosTremie_DI := M3_PosTremie_DI; ;; PRG_02_Acquisition.st:171 = HwReal.Translation.M3_PosPV_DI := M3` | HwReal.Translation recoit M3_PosTremie_DI et M3_PosPV_DI | verifier M3_PosTremie_DI et M3_PosPV_DI en entree acquisition |
| `PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | M3_PosTremie_DI vient de HwReal ou HwSim selon TranslationInputSourceSimulated | verifier HwReal.Translation noeud 38 et HwSim.Translation noeud 39 |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source EffectivePermitM3_Maintenance dans PRG_05_Translation |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source EffectivePermitM3_Tremie dans PRG_05_Translation |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.Enable` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source Enable dans PRG_05_Translation |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source PowerCutOff dans PRG_05_Translation |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source ReqTremieSemantic dans PRG_05_Translation |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source RequestedDriveFreqHz dans PRG_05_Translation |
| `PRG_05_Translation.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed` | LISIBLE? | `PRG_05_Translation.st:706 = TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;` | BrakeCommandOpenConfirmed copie depuis instTranslationM3 | verifier instTranslationM3.BrakeCommandOpenConfirmed dans PRG_05_Translation |
| `PRG_05_Translation.TranslationFinalInterlockRequest.PowerContactorEngaged` | LISIBLE? | `PRG_05_Translation.st:700 = TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;` | PowerContactorEngaged copie depuis PowerContactorEngaged_DI | verifier PowerContactorEngaged_DI noeud 37 |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source noeud 32 |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source noeud 33 |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source noeud 34 |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | la ligne copie TranslationFinalInterlockRequest dans Data | verifier la source noeud 35 |

### RETOUR (5)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI` | VISIBLE | `PRG_02_Acquisition.st:482 = HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);` | HwIn.Translation selectionne reel ou simule selon TranslationInputSourceSimulated | verifier TranslationInputSourceSimulated et HwSim.Translation |
| `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PowerContactorEngaged_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.M3_BrakeIsOpen_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Translation |
| `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | PowerContactorEngaged_DI vient de HwReal ou HwSim selon MachineInputSourceSimulated | verifier HwReal.Machine et HwSim.Machine dans PRG_02_Acquisition |

## 3. Arbre par commande (chemin le plus court vers une sortie)

Parcours de haut en bas : si la valeur attendue s'arrête à un maillon, chercher dans la colonne `Si dernier vrai` du maillon. Les autres branches sont dans `edges` du graphe.

### `GVL_IHM.CycleSemiAuto.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — LISIBLE?
2. **DEMANDE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
7. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.JOY1Joystick.Cmd.Calibrate`

1. **SOURCE** `GVL_IHM.JOY1Joystick.Cmd.Calibrate` — LISIBLE?
2. **SOURCE** `PRG_02_Acquisition.instJoystick.Calibrate` — LISIBLE?
3. **SOURCE** `PRG_02_Acquisition.instJoystick.NeutralXMem` — LISIBLE?
4. **SOURCE** `PRG_02_Acquisition.instJoystick.ScaleX.Neutral` — LISIBLE?
5. **SOURCE** `PRG_02_Acquisition.instJoystick.ScaleX.OutPct` — LISIBLE?
6. **SOURCE** `PRG_02_Acquisition.instJoystick.CmdXVal` — LISIBLE?
7. **SOURCE** `PRG_02_Acquisition.instJoystick.AxisCmdX.DirectionPositive` — LISIBLE?
8. **MESURE** `PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive` — LISIBLE?
9. **ARBITRAGE** `PRG_05_Translation.instArbM3.Joystick.AxisX.DirectionPositive` — LISIBLE?
10. **ARBITRAGE** `PRG_05_Translation.instArbM3.ReqTremie` — LISIBLE?
11. **ARBITRAGE** `PRG_05_Translation.M3_ReqTremie_Active` — LISIBLE?
12. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
13. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
14. **ARBITRAGE** `PRG_06_Outputs.M3_TremieHardStopActive` — LISIBLE?
15. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeReleaseRequest` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
17. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — LISIBLE?
2. **DEMANDE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
7. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — LISIBLE?
2. **DEMANDE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
7. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — LISIBLE?
2. **DEMANDE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
7. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M3Translation.Cmd.BtnMaintenance`

1. **SOURCE** `GVL_IHM.M3Translation.Cmd.BtnMaintenance` — VISIBLE
2. **ARBITRAGE** `PRG_05_Translation.ArbM3_IHM.BtnMaintenance` — LISIBLE?
3. **ARBITRAGE** `PRG_05_Translation.instArbM3.IHM.BtnMaintenance` — LISIBLE?
4. **ARBITRAGE** `PRG_05_Translation.instArbM3.ReqTremie` — LISIBLE?
5. **ARBITRAGE** `PRG_05_Translation.M3_ReqTremie_Active` — LISIBLE?
6. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
7. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
8. **ARBITRAGE** `PRG_06_Outputs.M3_TremieHardStopActive` — LISIBLE?
9. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeReleaseRequest` — LISIBLE?
10. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
11. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M3Translation.Cmd.BtnTremie`

1. **SOURCE** `GVL_IHM.M3Translation.Cmd.BtnTremie` — VISIBLE
2. **ARBITRAGE** `PRG_05_Translation.ArbM3_IHM.BtnTremie` — LISIBLE?
3. **ARBITRAGE** `PRG_05_Translation.instArbM3.IHM.BtnTremie` — LISIBLE?
4. **ARBITRAGE** `PRG_05_Translation.instArbM3.ReqTremie` — LISIBLE?
5. **ARBITRAGE** `PRG_05_Translation.M3_ReqTremie_Active` — LISIBLE?
6. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
7. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
8. **ARBITRAGE** `PRG_06_Outputs.M3_TremieHardStopActive` — LISIBLE?
9. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeReleaseRequest` — LISIBLE?
10. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
11. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M3Translation.Cmd.Initialized`

1. **SOURCE** `GVL_IHM.M3Translation.Cmd.Initialized` — LISIBLE?
2. **SOURCE** `GVL_IHM.M3Translation.Cmd.SetFreq_Hz` — LISIBLE?
3. **DEMANDE** `PRG_05_Translation.ArbM3_IHM.SetFreq_Hz` — LISIBLE?
4. **ARBITRAGE** `PRG_05_Translation.instArbM3.IHM.SetFreq_Hz` — LISIBLE?
5. **ARBITRAGE** `PRG_05_Translation.instArbM3.FreqPct` — LISIBLE?
6. **ARBITRAGE** `PRG_05_Translation.instArbM3.SpeedPct` — LISIBLE?
7. **DEMANDE** `PRG_05_Translation.M3_SpeedCmd_Active` — LISIBLE?
8. **DEMANDE** `PRG_05_Translation.instTranslationM3.SpeedTgt_Pct` — LISIBLE?
9. **DEMANDE** `PRG_05_Translation.instTranslationM3.RampTargetPct` — LISIBLE?
10. **DEMANDE** `PRG_05_Translation.instTranslationM3.TonBrakeRealFreqTimeout.Q` — LISIBLE?
11. **DEMANDE** `PRG_05_Translation.instTranslationM3.MovementRequested` — LISIBLE?
12. **DEMANDE** `PRG_05_Translation.instTranslationM3.Brake.MovementRequested` — LISIBLE?
13. **DEMANDE** `PRG_05_Translation.instTranslationM3.Brake.BrakeCmd` — VISIBLE
14. **DEMANDE** `PRG_05_Translation.instTranslationM3.RequestedDriveControlWord` — VISIBLE
15. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
16. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveControlWord` — LISIBLE?
18. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
19. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M3Translation.Cmd.InvertDirection`

1. **SOURCE** `GVL_IHM.M3Translation.Cmd.InvertDirection` — LISIBLE?
2. **DEMANDE** `PRG_05_Translation.instTranslationM3.InvertDriveDirection` — LISIBLE?
3. **DEMANDE** `PRG_05_Translation.instTranslationM3.PhysicalMaintenance` — LISIBLE?
4. **DEMANDE** `PRG_05_Translation.instTranslationM3.RequestedDriveControlWord` — VISIBLE
5. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
6. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
7. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveControlWord` — LISIBLE?
8. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.M3Translation.Cmd.SetFreq_Hz`

1. **SOURCE** `GVL_IHM.M3Translation.Cmd.SetFreq_Hz` — LISIBLE?
2. **DEMANDE** `PRG_05_Translation.ArbM3_IHM.SetFreq_Hz` — LISIBLE?
3. **ARBITRAGE** `PRG_05_Translation.instArbM3.IHM.SetFreq_Hz` — LISIBLE?
4. **ARBITRAGE** `PRG_05_Translation.instArbM3.FreqPct` — LISIBLE?
5. **ARBITRAGE** `PRG_05_Translation.instArbM3.SpeedPct` — LISIBLE?
6. **DEMANDE** `PRG_05_Translation.M3_SpeedCmd_Active` — LISIBLE?
7. **DEMANDE** `PRG_05_Translation.instTranslationM3.SpeedTgt_Pct` — LISIBLE?
8. **DEMANDE** `PRG_05_Translation.instTranslationM3.RampTargetPct` — LISIBLE?
9. **DEMANDE** `PRG_05_Translation.instTranslationM3.TonBrakeRealFreqTimeout.Q` — LISIBLE?
10. **DEMANDE** `PRG_05_Translation.instTranslationM3.MovementRequested` — LISIBLE?
11. **DEMANDE** `PRG_05_Translation.instTranslationM3.Brake.MovementRequested` — LISIBLE?
12. **DEMANDE** `PRG_05_Translation.instTranslationM3.Brake.BrakeCmd` — VISIBLE
13. **DEMANDE** `PRG_05_Translation.instTranslationM3.RequestedDriveControlWord` — VISIBLE
14. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
15. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord` — LISIBLE?
16. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RequestedDriveControlWord` — LISIBLE?
17. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
18. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.Modes.Cmd.BtnFaultReset`

1. **SOURCE** `GVL_IHM.Modes.Cmd.BtnFaultReset` — LISIBLE?
2. **DEMANDE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.Reset` — LISIBLE?
4. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.ResetEdge.Q` — LISIBLE?
5. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` — LISIBLE?
6. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
7. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

### `GVL_IHM.Modes.Cmd.TglJoystickMaster`

1. **SOURCE** `GVL_IHM.Modes.Cmd.TglJoystickMaster` — VISIBLE
2. **REGLAGE** `PRG_05_Translation.instArbM3.TglJoystickMaster` — LISIBLE?
3. **ARBITRAGE** `PRG_05_Translation.instArbM3.ReqTremie` — LISIBLE?
4. **ARBITRAGE** `PRG_05_Translation.M3_ReqTremie_Active` — LISIBLE?
5. **DEMANDE** `PRG_05_Translation.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
6. **MESURE** `PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic` — LISIBLE?
7. **ARBITRAGE** `PRG_06_Outputs.M3_TremieHardStopActive` — LISIBLE?
8. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeReleaseRequest` — LISIBLE?
9. **BARRIERE** `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` — LISIBLE?
10. **SORTIE** `PRG_06_Outputs.M3_CommandWord` — A CONTROLER

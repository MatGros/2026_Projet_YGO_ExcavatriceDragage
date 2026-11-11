# Carte de flux AU

> Généré depuis `CODE/`. Chaîne, `fichier:ligne` et code cité : extraction mécanique. Colonnes de lecture : rédigées puis à relire. Aucune preuve sur automate.

**Couverture :** 122 variables dans le graphe, 82 maillons d'interface annotés, 24 points d'entrée reliés à une sortie, 0 maillon de chemin non annoté.

**Statuts :** {'A CONTROLER': 5, 'VISIBLE': 32, 'LISIBLE?': 45}. `VISIBLE` = chemin du snapshot ou copie directe. `LISIBLE?` = variable existante, lecture directe à confirmer sur automate.

## 1. Référentiel

### Actionneurs (3)

- `PRG_06_Outputs.EmergencyArming_RQ`
- `PRG_06_Outputs.PowerKeepAlive_A_RQ`
- `PRG_06_Outputs.PowerKeepAlive_B_RQ`

### Commandes atteintes (7)

- `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — non visible
- `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` — non visible
- `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` — VISIBLE
- `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — non visible
- `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — non visible
- `GVL_IHM.Modes.Cmd.BtnFaultReset` — non visible

### Réglages (3)

- `PRG_06_Outputs.instArmContactorProtector.Cfg_MinInterval`
- `PRG_06_Outputs.instKeepAliveAProtector.Cfg_MinInterval`
- `PRG_06_Outputs.instKeepAliveBProtector.Cfg_MinInterval`

### Bypass (12)

- `GVL_BypassRetain.BypassAuArmingPreconditions`
- `GVL_BypassRetain.BypassAuPowerCutOff`
- `GVL_BypassRetain.BypassAuRedundancyTest`
- `GVL_BypassRetain.BypassAuRedundancyTestA`
- `GVL_BypassRetain.BypassAuRedundancyTestB`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassArmingPreconditions`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestA`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestB`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestA`
- `PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestB`

### Mesures et retours physiques (11)

- `PRG_02_Acquisition.ConveyorInfeedReady_DI` — VISIBLE
- `PRG_02_Acquisition.EmergencyChainClosed_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI` — VISIBLE
- `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.HwReal.Machine` — LISIBLE?
- `PRG_02_Acquisition.HydraulicThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` — VISIBLE
- `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` — VISIBLE
- `PRG_02_Acquisition.PhaseRotationOk_DI` — VISIBLE
- `PRG_02_Acquisition.PowerContactorEngaged_DI` — VISIBLE
- `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` — VISIBLE

## 2. Maillons par étage (de la source vers l'actionneur)

### SOURCE (7)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.Modes.Cmd.BtnFaultReset` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_07_Supervision.FaultMachineReset_IHM |
| `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.ArmRequest |
| `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BtnEmergencyCutOff |

### MODE (4)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_Simulation.SimSafetyActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineInputSourceSimulated |
| `GVL_Simulation.SimulationModeActive` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.MachineInputSourceSimulated |
| `PRG_02_Acquisition.MachineInputSourceSimulated` | LISIBLE? | `PRG_02_Acquisition.st:138 = MachineInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimSafetyActive;` | SimulationModeActive et SimSafetyActive vrais | Verifier GVL_Simulation.SimulationModeActive et GVL_Simulation.SimSafetyActive |
| `PRG_06_Outputs.TRUE` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instArmContactorProtector.Enable, PRG_06_Outputs.instKeepAliveAProtector.Enable |

### BYPASS (12)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `GVL_BypassRetain.BypassAuRedundancyTest` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest |
| `GVL_BypassRetain.BypassAuRedundancyTestA` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestA |
| `GVL_BypassRetain.BypassAuRedundancyTestB` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestB |
| `GVL_BypassRetain.BypassAuArmingPreconditions` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BypassArmingPreconditions |
| `GVL_BypassRetain.BypassAuPowerCutOff` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest` | LISIBLE? | `entree liee a : GVL_BypassRetain.BypassAuRedundancyTest` | Entree recue depuis : GVL_BypassRetain.BypassAuRedundancyTest | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestA` | LISIBLE? | `entree liee a : GVL_BypassRetain.BypassAuRedundancyTestA` | Entree recue depuis : GVL_BypassRetain.BypassAuRedundancyTestA | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTestB` | LISIBLE? | `entree liee a : GVL_BypassRetain.BypassAuRedundancyTestB` | Entree recue depuis : GVL_BypassRetain.BypassAuRedundancyTestB | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassArmingPreconditions` | LISIBLE? | `entree liee a : GVL_BypassRetain.BypassAuArmingPreconditions` | Entree recue depuis : GVL_BypassRetain.BypassAuArmingPreconditions | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff` | LISIBLE? | `entree liee a : GVL_BypassRetain.BypassAuPowerCutOff` | Entree recue depuis : GVL_BypassRetain.BypassAuPowerCutOff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestA` | VISIBLE | `FB_Safety_EmergencyManagement.st:222 = BypassTestA := BypassRedundancyTest OR BypassRedundancyTestA;` | BypassTestA vrai si BypassRedundancyTest ou BypassRedundancyTestA | Vérifier les flags de bypass test redondance |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestB` | VISIBLE | `FB_Safety_EmergencyManagement.st:223 = BypassTestB := BypassRedundancyTest OR BypassRedundancyTestB;` | BypassTestB vrai si BypassRedundancyTest ou BypassRedundancyTestB | Vérifier les flags de bypass test redondance |

### ARBITRAGE (1)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_07_Supervision.FaultMachineReset_IHM` | LISIBLE? | `PRG_07_Supervision.st:138 = FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset OR GVL_IHM.M2TreuilBenne.` | un des cinq Boutons Reset IHM est vrai | Verifier les cinq variables GVL_IHM citees |

### DEMANDE (6)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1610 = WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;` | PowerCutOff de WinchM1FinalInterlockRequest affecte par instSafetyWinchM1.PowerCutOff | Verifier instSafetyWinchM1.PowerCutOff |
| `PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1627 = WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;` | PowerCutOff de WinchM2FinalInterlockRequest affecte par instSafetyWinchM2.PowerCutOff | Verifier instSafetyWinchM2.PowerCutOff |
| `PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_05_Translation.st:702 = TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;` | PowerCutOff de TranslationFinalInterlockRequest affecte par instSafetyTranslationM3.PowerCutOff | Verifier instSafetyTranslationM3.PowerCutOff |
| `PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff` | VISIBLE | `PRG_04_Treuils_Benne.st:1936 = Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;` | Data.WinchM1FinalInterlockRequest affecte par WinchM1FinalInterlockRequest | Verifier WinchM1FinalInterlockRequest.PowerCutOff |
| `PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_04_Treuils_Benne.st:1937 = Data.WinchM2FinalInterlockRequest := WinchM2FinalInterlockRequest;` | Data.WinchM2FinalInterlockRequest affecte par WinchM2FinalInterlockRequest | Verifier WinchM2FinalInterlockRequest.PowerCutOff |
| `PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff` | LISIBLE? | `PRG_05_Translation.st:880 = Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;` | Data.TranslationFinalInterlockRequest affecte par TranslationFinalInterlockRequest | Verifier TranslationFinalInterlockRequest.PowerCutOff |

### SECURITE (19)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_04_Treuils_Benne.instSafetyWinchM1.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff |
| `PRG_04_Treuils_Benne.instSafetyWinchM2.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff |
| `PRG_05_Translation.instSafetyTranslationM3.PowerCutOff` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff |
| `PRG_06_Outputs.instSafetyEmergencyManagement.ArmRequest` | LISIBLE? | `entree liee a : GVL_IHM.Emergency.Cmd.BtnEmergencyArming` | Entree recue depuis : GVL_IHM.Emergency.Cmd.BtnEmergencyArming | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` | LISIBLE? | `entree liee a : PRG_07_Supervision.FaultMachineReset_IHM` | Entree recue depuis : PRG_07_Supervision.FaultMachineReset_IHM | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.PowerCutOffReq` | VISIBLE | `PRG_06_Outputs.st:317 = PowerCutOffReq := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff OR PRG_04_Treuils_Benne.Data.WinchM2Final` | un des trois PowerCutOff de WinchM1 WinchM2 Translation est vrai | Verifier les trois Demandes PowerCutOff des blocs securite en amont |
| `PRG_06_Outputs.instSafetyEmergencyManagement.ArmReqEdge.Q` | LISIBLE? | `FB_Safety_EmergencyManagement.st:132 = ArmReqEdge(CLK := ArmRequest);` | front montant sur ArmRequest | Verifier ArmRequest et la logique aval de ArmReqEdge.Q |
| `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` | LISIBLE? | `FB_Safety_EmergencyManagement.st:131 = ResetEdge(CLK := Reset);` | front montant sur Reset | Verifier Reset et la logique aval de ResetEdge.Q |
| `PRG_06_Outputs.instSafetyEmergencyManagement.EmergencyChainClosed` | LISIBLE? | `entree liee a : PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.PowerContactorEngaged` | VISIBLE | `entree liee a : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | Entree recue depuis : PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.PowerCutOffRequest` | LISIBLE? | `entree liee a : PRG_06_Outputs.PowerCutOffReq` | Entree recue depuis : PRG_06_Outputs.PowerCutOffReq | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` | LISIBLE? | `FB_Safety_EmergencyManagement.st:205 = PreArmDelayActive := FALSE; ;; FB_Safety_EmergencyManagement.st:301 = PreArmDelayActive := TRUE;` | PreArmDelayActive mis à FALSE ligne 205 et TRUE ligne 301 | Vérifier la logique de temporisation pré-armement |
| `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` | VISIBLE | `FB_Safety_EmergencyManagement.st:140 = ArmingSeqStep := CST_STEP_IDLE; ;; FB_Safety_EmergencyManagement.st:232 = ArmingSeqStep := CST_STEP_IDLE;` | ArmingSeqStep initialisé à IDLE ligne 140 et remis à IDLE ligne 232 | Vérifier la logique de transition des étapes |
| `PRG_06_Outputs.instSafetyEmergencyManagement.BtnEmergencyCutOff` | LISIBLE? | `entree liee a : GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` | Entree recue depuis : GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instSafetyEmergencyManagement.CutOffActive` | LISIBLE? | `FB_Safety_EmergencyManagement.st:217 = CutOffActive := PowerCutOffRequest AND NOT BypassPowerCutOff AND NOT BypassArmingPreconditions;` | CutOffActive vrai si demande coupure sans bypass | Vérifier PowerCutOffRequest et les bypass |
| `PRG_06_Outputs.instSafetyEmergencyManagement.Enable` | LISIBLE? | `PRG_06_Outputs.st:486 = Enable := TRUE,` | Forcee a TRUE a l'appel du bloc : toujours vraie | Maillon non discriminant : verifier la sequence d'armement du bloc |
| `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` | VISIBLE | `FB_Safety_EmergencyManagement.st:559 = Cmd.ArmPulse_Cmd := Enable AND (ArmingSeqStep = CST_STEP_PULSE) AND NOT BtnEmergencyCutOff AND NOT CutOffActive` | Enable ET étape pulsation ET pas coupure bouton ET pas coupure active | Vérifier ArmingSeqStep et CutOffActive |
| `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainA_Cmd` | VISIBLE | `FB_Safety_EmergencyManagement.st:536 = Cmd.MaintainA_Cmd := Enable AND Maintain_ChainOk AND MaintainA_NoBlock;` | Enable ET Maintain_ChainOk ET MaintainA_NoBlock | Vérifier Maintain_ChainOk et MaintainA_NoBlock |
| `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainB_Cmd` | VISIBLE | `FB_Safety_EmergencyManagement.st:537 = Cmd.MaintainB_Cmd := Enable AND Maintain_ChainOk AND MaintainB_NoBlock;` | Enable ET Maintain_ChainOk ET MaintainB_NoBlock | Vérifier Maintain_ChainOk et MaintainB_NoBlock |

### SORTIE (17)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_06_Outputs.instArmContactorProtector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.T, PRG_06_Outputs.s` | Entree recue depuis : PRG_06_Outputs.T, PRG_06_Outputs.s | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveAProtector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.T, PRG_06_Outputs.ms` | Entree recue depuis : PRG_06_Outputs.T, PRG_06_Outputs.ms | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveBProtector.Cfg_MinInterval` | LISIBLE? | `entree liee a : PRG_06_Outputs.T, PRG_06_Outputs.ms` | Entree recue depuis : PRG_06_Outputs.T, PRG_06_Outputs.ms | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instArmContactorProtector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` | Entree recue depuis : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveAProtector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainA_Cmd` | Entree recue depuis : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainA_Cmd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveBProtector.Request` | LISIBLE? | `entree liee a : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainB_Cmd` | Entree recue depuis : PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainB_Cmd | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` | VISIBLE | `FB_ContactorProtector.st:34 = ActivationLatched := FALSE; ;; FB_ContactorProtector.st:53 = ActivationLatched := TRUE;` | ActivationLatched mis à TRUE à la ligne 53 | Vérifier les conditions de latch dans FB_ContactorProtector |
| `PRG_06_Outputs.instArmContactorProtector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveAProtector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instKeepAliveBProtector.Enable` | LISIBLE? | `entree liee a : PRG_06_Outputs.TRUE` | Entree recue depuis : PRG_06_Outputs.TRUE | Comparer avec la source : un ecart indique un probleme de liaison |
| `PRG_06_Outputs.instArmContactorProtector.Cmd` | VISIBLE | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | Cmd dépend de ActivationLatched selon la ligne 60 | Vérifier ActivationLatched du contacteur d'armement |
| `PRG_06_Outputs.instKeepAliveAProtector.Cmd` | VISIBLE | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | Cmd dépend de ActivationLatched selon la ligne 60 | Vérifier ActivationLatched du maintien A |
| `PRG_06_Outputs.instKeepAliveBProtector.Cmd` | VISIBLE | `FB_ContactorProtector.st:30 = Cmd := FALSE; ;; FB_ContactorProtector.st:60 = Cmd := ActivationLatched;` | Cmd dépend de ActivationLatched selon la ligne 60 | Vérifier ActivationLatched du maintien B |
| `PRG_06_Outputs.EmergencyArmingCmd` | VISIBLE | `PRG_06_Outputs.st:527 = EmergencyArmingCmd := instArmContactorProtector.Cmd;` | instArmContactorProtector.Cmd affecté à EmergencyArmingCmd | Vérifier la valeur de Cmd du contacteur d'armement |
| `PRG_06_Outputs.PowerKeepAliveACmd` | VISIBLE | `PRG_06_Outputs.st:517 = PowerKeepAliveACmd := instKeepAliveAProtector.Cmd;` | instKeepAliveAProtector.Cmd affecté à PowerKeepAliveACmd | Vérifier la valeur de Cmd du maintien A |
| `PRG_06_Outputs.PowerKeepAliveBCmd` | VISIBLE | `PRG_06_Outputs.st:518 = PowerKeepAliveBCmd := instKeepAliveBProtector.Cmd;` | instKeepAliveBProtector.Cmd affecté à PowerKeepAliveBCmd | Vérifier la valeur de Cmd du maintien B |
| `PRG_06_Outputs.EmergencyArming_RQ` | A CONTROLER | `PRG_06_Outputs.st:532 = EmergencyArming_RQ := EmergencyArmingCmd;` | EmergencyArmingCmd affecté à EmergencyArming_RQ | Vérifier la sortie physique de l'armement contacteur |

### MESURE (13)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.ConveyorInfeedReady_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.EmergencyChainClosed_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HydraulicThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.M1_M2_KoboldBottomTouch_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PhaseRotationOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.TremieFull_OR_GateRaised_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.instSimBench.Machine` | LISIBLE? | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwSim.Machine |
| `PRG_02_Acquisition.HwReal.Machine` | LISIBLE? | `PRG_02_Acquisition.st:189 = HwReal.Machine.PowerContactorEngaged_DI := PowerContactorEngaged_DI; ;; PRG_02_Acquisition.st:190 = HwReal.Machine.Emergen` | HwReal.Machine affecte PowerContactorEngaged_DI et EmergencyChainClosed_DI | Verifier les entrees PowerContactorEngaged_DI et EmergencyChainClosed_DI |
| `PRG_02_Acquisition.HwSim.Machine` | LISIBLE? | `PRG_02_Acquisition.st:437 = HwSim.Machine := instSimBench.Machine;` | HwSim.Machine affecte par instSimBench.Machine | Verifier instSimBench.Machine |
| `PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | HwIn.Machine sélectionné entre réel et simulé | Vérifier MachineInputSourceSimulated et les entrées Machine |
| `PRG_06_Outputs.T` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instArmContactorProtector.Cfg_MinInterval, PRG_06_Outputs.instKeepAliveAProtector.Cfg_MinInterval |
| `PRG_06_Outputs.ms` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instKeepAliveAProtector.Cfg_MinInterval, PRG_06_Outputs.instKeepAliveBProtector.Cfg_MinInterval |
| `PRG_06_Outputs.s` | A CONTROLER | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_06_Outputs.instArmContactorProtector.Cfg_MinInterval |

### RETOUR (3)

| Maillon | Statut | Code | Condition | Si dernier vrai |
|---|---|---|---|---|
| `PRG_02_Acquisition.M1_M2_M3_BrakeThermalOk_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.PowerContactorEngaged_DI` | VISIBLE | `entree liee a : ` | Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03 | Verifier en aval : PRG_02_Acquisition.HwReal.Machine |
| `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` | VISIBLE | `PRG_02_Acquisition.st:484 = HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` | MachineInputSourceSimulated selectionne HwReal ou HwSim pour HwIn.Machine | Verifier dans HwReal.Machine et HwSim.Machine les bits PowerContactorEngaged_DI et EmergencyChainClosed_DI |

## 3. Arbre par commande (chemin le plus court vers une sortie)

Parcours de haut en bas : si la valeur attendue s'arrête à un maillon, chercher dans la colonne `Si dernier vrai` du maillon. Les autres branches sont dans `edges` du graphe.

### `GVL_IHM.CycleSemiAuto.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.CycleSemiAuto.Cmd.BtnReset` — LISIBLE?
2. **ARBITRAGE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
7. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
12. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.Emergency.Cmd.BtnEmergencyArming`

1. **SOURCE** `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` — LISIBLE?
2. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmRequest` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmReqEdge.Q` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
7. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff`

1. **SOURCE** `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` — VISIBLE
2. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.BtnEmergencyCutOff` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
4. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
5. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
6. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
7. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M1TreuilRetenue.Cmd.BtnReset` — LISIBLE?
2. **ARBITRAGE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
7. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
12. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` — LISIBLE?
2. **ARBITRAGE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
7. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
12. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.M2TreuilBenne.Cmd.BtnReset`

1. **SOURCE** `GVL_IHM.M2TreuilBenne.Cmd.BtnReset` — LISIBLE?
2. **ARBITRAGE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
7. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
12. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

### `GVL_IHM.Modes.Cmd.BtnFaultReset`

1. **SOURCE** `GVL_IHM.Modes.Cmd.BtnFaultReset` — LISIBLE?
2. **ARBITRAGE** `PRG_07_Supervision.FaultMachineReset_IHM` — LISIBLE?
3. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Reset` — LISIBLE?
4. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ResetEdge.Q` — LISIBLE?
5. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.PreArmDelayActive` — LISIBLE?
6. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep` — VISIBLE
7. **SECURITE** `PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd` — VISIBLE
8. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Request` — LISIBLE?
9. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.ActivationLatched` — VISIBLE
10. **SORTIE** `PRG_06_Outputs.instArmContactorProtector.Cmd` — VISIBLE
11. **SORTIE** `PRG_06_Outputs.EmergencyArmingCmd` — VISIBLE
12. **SORTIE** `PRG_06_Outputs.EmergencyArming_RQ` — A CONTROLER

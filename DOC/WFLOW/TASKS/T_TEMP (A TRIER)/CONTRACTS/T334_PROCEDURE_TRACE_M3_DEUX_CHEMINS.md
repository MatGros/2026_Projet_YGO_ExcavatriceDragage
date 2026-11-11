# T334 — Procédure de trace 10 ms : M3, deux chemins de commande (manuel vs cycle)

> 🎯 Objectif : produire la preuve dynamique qui **confirme ou réfute** les hypothèses H1→H6 de la fiche
> `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` sur le dépassement
> de l'arrivée P1/Trémie **en cycle automatique**, et fournir la **comparaison directe manuel ↔ cycle**
> exigée par le constat utilisateur.
> 🔒 **Le run est HUMAIN** (CODESYS). Cette procédure est *prête à exécuter* : aucune écriture dans `CODE/`,
> aucun forçage de variable hors des réglages de simulation listés, aucun `Device.export` lu.
> 📄 Base : `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T300_M3_SIMBENCH.md` (même doctrine, canaux M3 étendus).
> 🎫 Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` (AC1→AC3, C3).

---

## 1. Pourquoi 10 ms, et pourquoi les traces existantes ne suffisent pas

| Fait mesuré | Valeur | Conséquence |
|---|---|---|
| Trace M3 existante `archives/Suivi_TranslationM3bug_20260904_27.trace` | 15 canaux, 352 éch., **dt médian 100 ms** | ne peut dater aucun événement < 150 ms |
| Trace M3 existante `Suivi_Cycle_M3_20260906_49.trace` | 15 canaux, 367 éch., **dt min 77 ms / médian 100 ms / max 128 ms** (39 valeurs distinctes) | idem — et **aucun jeton ni interne d'axe** |
| Traces `Suivi_66..70_SIMU_MaintMANU_20260919.trace` | 54→58 canaux, **uniquement treuils + joystick Y** | **aucune variable M3** : la comparaison manuel ↔ cycle n'existe pas |
| Période de tâche | `MainTask 10 ms` (`AF_Partie-02_Architecture_Programme_v3.2.md:517-525`) | la granularité 10 ms est **disponible** sans changer le projet |

➡️ **Aucune des trois expériences du protocole n'existe dans le dépôt.** Le verrou d'arrêt de l'axe se joue à
l'échelle de **1 à 10 scans** (debounce 100 ms, fronts de capteur de 1 scan) : une trace à 100 ms est
structurellement aveugle.

✅ **Faisabilité des canaux vérifiée** : les traces existantes enregistrent déjà des **internes d'instance par
chemin pointé**, y compris imbriqués (`PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedTgt`,
`PRG_02_Acquisition.instSimBench.instWinchElectricalM1.Slip_Ratio`). Les internes de `FB_Translation`
(`PRG_05_Translation.instTranslationM3.ArrivalLock`, `.CaptorDebounceTon.ET`, `.Brake.BrakeCmd`) sont donc
traçables — sans quoi la preuve de H2 serait impossible.

⚠️ **Limite assumée** : `AUDIT_T300_TRACE_20260904_v1.0.md:244` établit que le banc est **incapable** de
reproduire le défaut frein/cause 6 (cas C4). Un PASS banc **ne vaut pas** non-régression terrain : les
scénarios A/B/C sont donc rejouables au banc **et** sur site, et la conclusion doit dire lequel a été utilisé.

---

## 2. Préconditions

- Projet CODESYS chargé ; **mode simulation** (banc) ou **site** — préciser lequel dans l'archive.
- En simulation : `GVL_Simulation.SimulationModeActive` activé par un **front** `FALSE→TRUE` **après** le
  démarrage de l'automate, puis vérifier `GVL_Simulation.SimTranslationActive = TRUE` avant d'interpréter les
  DI (même piège que `PROCEDURE_TRACE_T300_M3_SIMBENCH.md:8`).
- Trace attachée à la **MainTask (10 ms)**, pas à l'EtherCAT (4 ms) ni au CANopen (20 ms).
- **Aucun forçage** de variable de logique. Seuls les réglages de simulation du §4 sont autorisés.
- Relever et archiver la **période effective** de la trace (le buffer et la charge peuvent l'allonger) : une
  période non relevée rend la trace inexploitable (`PROCEDURE_TRACE_T300_M3_SIMBENCH.md:9`).

### Réglage de la trace
| Paramètre | Valeur | Remarque |
|---|---|---|
| Tâche | `MainTask` | 10 ms |
| Nombre d'échantillons | **≥ 1 000** par canal | couvre 10 s à 10 ms |
| Avant déclenchement | 300 éch. (3 s) | voir l'approche complète |
| Après déclenchement | 300 éch. (3 s) | voir la reprise éventuelle |
| Déclencheur | front montant sur **le capteur d'arrivée de l'étape** : `M3_PosP1_DI` (AX2) ou `M3_PosTremie_DI` (AX14) | variante : sur l'entrée dans l'étape (`SequenceState.Step`) |

Si le buffer disponible ne tient pas tous les canaux du §3, **découper en 3 traces** et les nommer
explicitement (le rejeu reste concluant, chaque groupe étant auto-suffisant) :
`D1 Ordre/Arbitrage` · `D2 Capteurs/Jetons` · `D3 Verrou/Variateur`.

---

## 3. Liste EXACTE des canaux à enregistrer (à copier telle quelle)

> Format identique à `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_treuils_charge_v1.txt` (un symbole par ligne).
> 🆕 = canal **absent** de toute trace existante du dépôt, indispensable à T334.
> ⚠️ Les chemins `instXxx.<interne>` sont des **internes de FB** : traçables par symbole CODESYS, mais
> **jamais lus par du code** (`CODE_QUALITY_STANDARDS.md:526-527`, « internes privés »). Ils ne servent ici
> qu'à la preuve de diagnostic.

### Groupe A — Ordre demandé et mode (discrimine H1)
```text
PRG_03_Modes_Cycle.Data.SequenceState.Step
PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart
PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt
PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationStopTimer.ET
PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationStopTimer.Q
PRG_03_Modes_Cycle.instCycleSemiAuto.CycleMotionPermit
PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationP1Permit
PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationTremiePermit
GVL_IHM.CycleSemiAuto.State.CycleStep
```

### Groupe B — Arbitrage M3 (discrimine H1/H2)
```text
PRG_05_Translation.SelTarget
PRG_05_Translation.M3_RunRequest_Active
PRG_05_Translation.M3_ReqTremie_Active
PRG_05_Translation.M3_ReqMaintenance_Active
PRG_05_Translation.M3_SpeedCmd_Active
PRG_05_Translation.M3_PositionSensorTarget
PRG_05_Translation.M3_CycleTranslationStepAuthorized
PRG_05_Translation.M3_PositioningActive
PRG_05_Translation.instArbM3.RunRequest
PRG_05_Translation.instArbM3.ReqTremie
PRG_05_Translation.instArbM3.ReqMaintenance
PRG_05_Translation.instArbM3.SpeedPct
PRG_05_Translation.instArbM3.SelTarget
PRG_05_Translation.instArbM3.CommandConflict
```

### Groupe C — Capteurs et qualification de position (discrimine H1)
```text
PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI
PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI
PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI
PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI
PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI
PRG_05_Translation.instPosDecoderM3.SensorsWord
PRG_05_Translation.instPosDecoderM3.Incoherent
PRG_05_Translation.instPosDecoderM3.TranslationAtTremie
PRG_05_Translation.instPosDecoderM3.TranslationAtP1
PRG_05_Translation.instPosDecoderM3.TranslationAtP2
PRG_05_Translation.instPosDecoderM3.TranslationAtPV
PRG_05_Translation.instPosDecoderM3.TranslationAtMaintenance
PRG_05_Translation.M3_SensorsWordChanged
PRG_05_Translation.M3_AtTremieStable
PRG_05_Translation.M3_AtP1Stable
PRG_05_Translation.M3_AtPVStable
PRG_05_Translation.M3_AtP2Stable
PRG_05_Translation.M3_AtMaintenanceStable
PRG_05_Translation.M3_LimitSwitchTremieStable
PRG_05_Translation.M3_LimitSwitchMaintenanceStable
PRG_05_Translation.M3_LimitSwitchMaintenanceEffective
PRG_05_Translation.M3_BootPositionLock
```

### Groupe D — Le verrou d'arrêt (cœur du diagnostic : H2/H4)
```text
PRG_05_Translation.instTranslationM3.CaptorDebounceTon.ET
PRG_05_Translation.instTranslationM3.CaptorDebounceTon.Q
PRG_05_Translation.instTranslationM3.TargetReached
PRG_05_Translation.instTranslationM3.ArrivalEdge.Q
PRG_05_Translation.instTranslationM3.ArrivalLock
PRG_05_Translation.instTranslationM3.ArrivalWasTremie
PRG_05_Translation.instTranslationM3.ArrivalWasMaintenance
PRG_05_Translation.instTranslationM3.CommandedTremie
PRG_05_Translation.instTranslationM3.CommandedMaintenance
PRG_05_Translation.instTranslationM3.DirectionChangePending
PRG_05_Translation.instTranslationM3.RampTargetPct
PRG_05_Translation.instTranslationM3.SpeedRamp.Current
PRG_05_Translation.instTranslationM3.EffectiveSafeStop
PRG_05_Translation.instTranslationM3.MovementRequested
PRG_05_Translation.instTranslationM3.Brake.BrakeCmd
PRG_05_Translation.instTranslationM3.OverrunLimitSwitch
PRG_05_Translation.instTranslationM3.TonLimitSwitchOverrun.Q
```

### Groupe E — Barrière finale et mots variateur (effet physique)
```text
PRG_06_Outputs.M3_TremieHardStopActive
PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord
PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmdWord
PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCmd
PRG_06_Outputs.instTranslationOutputInterlockM3.Reason
PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.ErrorId
PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeTimeoutElapsed
M3_CommandWord
M3_SetpointFrequencyHz
M3_BrakeRelease_RQ
PRG_06_Outputs.Data.TranslationBrakeCmd
```

### Groupe F — Variateur, frein, sécurité, contexte
```text
M3_ActualFrequencyHz
M3_StatusWord
M3_BrakeIsOpen_DI
PRG_05_Translation.instSafetyTranslationM3.SafeStop
PRG_05_Translation.instSafetyTranslationM3.PowerCutOff
PRG_05_Translation.instSafetyTranslationM3.ErrorLimitSwitch
PRG_05_Translation.instSafetyTranslationM3.Fault.ErrorId
PRG_05_Translation.Data.TranslationState.ErrorId
PRG_05_Translation.Data.TranslationState.FinalInterlockReason
PRG_05_Translation.Data.TranslationState.FinalInterlockError
PRG_05_Translation.Data.TranslationBusy
PRG_05_Translation.Data.TranslationTrace.BlockReason
GVL_IHM.M3Translation.Bypass.LimitSwitch
GVL_IHM.M3Translation.Bypass.Global
GVL_IHM.M3Translation.Bypass.SensorIncoherent
GVL_IHM.Modes.Cmd.TglJoystickMaster
GVL_IHM.M3Translation.Cmd.SetFreq_Hz
PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive
PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative
PRG_02_Acquisition.Data.Joystick.AxisX.AtNeutral
PRG_02_Acquisition.Data.Joystick.DeadmanArmed
```

### Groupe G — Réglages de simulation (seulement si banc)
```text
GVL_Simulation.SimulationModeActive
GVL_Simulation.SimTranslationActive
GVL_Simulation.SimM3SensorIntermittenceActive
GVL_Simulation.SimM3SensorStabilizationS
GVL_Simulation.SimM3SensorElectricalDelayS
GVL_Simulation.SimM3SensorIntermittencePeriodS
GVL_Simulation.SimM3SensorHysteresis_M
GVL_Simulation.SimM3SensorScenarioSeed
PRG_02_Acquisition.HwSim.Translation.M3_PosTremie_DI
PRG_02_Acquisition.instSimBench.instSimTranslation.PositionTrue_M
PRG_02_Acquisition.instSimBench.instSimTranslation.LoadAngle_Rad
```

---

## 4. Les 3 scénarios

> 🎯 Le geste est **identique** dans les trois : joystick X **maintenu** jusqu'à l'arrêt complet, homme-mort
> armé. C'est la seule façon de comparer « manuel » et « cycle » sans confondre la cause avec le
> comportement de l'opérateur.

### Scénario A — référence cycle, capteur propre (SEMI_AUTO)
1. Mettre M3 **à la Trémie**, machine référencée, en `SEMI_AUTO`.
2. Démarrer le cycle → AX2 attendu (`SequenceState.Step = AX2_TRANSLATE_P1`, cible P1).
3. Pousser le joystick **vers P1 (X droite)** et **le maintenir** jusqu'à l'arrêt complet, puis relâcher.
4. Arrêter la trace **après** la disparition du mouvement (≥ 3 s après l'arrivée).
5. Archiver : `T334_A_SEMIAUTO_AX2_nominal_<AAAAMMJJ>_<n>.trace`.
6. Rejouer la même chose de P1 vers la Trémie pour **AX14** (après AX13, ou en forçant l'étape AX14 avec
   `GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget` + `BtnForceStepApply`) →
   `T334_A_SEMIAUTO_AX14_nominal_<AAAAMMJJ>_<n>.trace`.

### Scénario B — cycle avec intermittence capteur (le cas du terrain)
1. Mêmes étapes que A, avec en plus, **en simulation uniquement** :
```text
GVL_Simulation.SimM3SensorIntermittenceActive  := TRUE
GVL_Simulation.SimM3SensorStabilizationS       := 1.0
GVL_Simulation.SimM3SensorElectricalDelayS     := 0.01
GVL_Simulation.SimM3SensorIntermittencePeriodS := 0.12
GVL_Simulation.SimM3SensorHysteresis_M         := 0.02
GVL_Simulation.SimM3SensorScenarioSeed         := 3001
```
2. `GVL_Simulation.SimM3SensorsWordOverrideActive` doit rester **FALSE** (sinon la boucle est court-circuitée
   et la trace ne prouve rien).
3. Déclencher la trace **sur le premier front du capteur d'arrivée**, garder 3 s après.
4. Archiver : `T334_B_SEMIAUTO_<AX2|AX14>_intermittence_<AAAAMMJJ>_<n>.trace`.
5. ⚠️ Sur **site**, ce scénario ne se provoque pas : il s'**attend** (T287 documente des commutations
   `0↔1` d'environ 1 s aux arrivées). Lancer la trace en continu sur plusieurs cycles et conserver la
   première occurrence.

### Scénario C — référence manuel / maintenance (MAINT_N1)
1. Quitter le cycle, passer en `MAINT_N1`, mode joystick maître (`TglJoystickMaster`) ou boutons IHM.
2. Même trajet, **même geste maintenu** jusqu'à l'arrêt (c'est le point clé de la comparaison).
3. Archiver : `T334_C_MAINT_<P1|Tremie>_<AAAAMMJJ>_<n>.trace`.

### À archiver avec chaque trace (sinon la trace n'est pas exploitable)
Révision Git (`git rev-parse HEAD`), date, **période effective mesurée**, scénario, mode, sens, geste
(fréquence `SetFreq_Hz` en manuel / 100 % en cycle), état des bypass, réglages de simulation.

---

## 5. Matrice de décision (signature → hypothèse)

| Signature attendue sur la trace | Lecture | Hypothèse |
|---|---|---|
| `ReqTranslation.ReqStart` **0→1 après** l'arrivée, corrélé à `AtXxxStable` **1→0** ou à `M3_SensorsWordChanged`, geste toujours maintenu | le cycle **recrée** la demande sur perte de jeton | **H1 confirmée** |
| `ArrivalLock` reste à **0** alors que `AtXxxStable` a été à 1, et `CaptorDebounceTon.ET` ne dépasse pas 1 à 2 scans en AX14 | le debounce n'aboutit pas → aucun verrou armé | **H2 confirmée** |
| `GVL_IHM.M3Translation.Bypass.LimitSwitch` ou `.Global` = **1** | le dernier verrou (voie FdC) est neutralisé sans garde de mode | **H2 aggravée** (D09 de la fiche) |
| `SpeedCmd_Pct` = 100 et `M3_SetpointFrequencyHz` > vitesse d'approche **dans** la zone P2→P1 (AX2) ou PV (AX14) | arrivée prise trop vite (distance d'arrêt en v²) | **H3 confirmée** |
| `CommandedMaintenance` (resp. `CommandedTremie`) passe à **0** au même scan que la retombée de la demande, et `M3_CommandWord` 2→0 (roue libre) | le variateur perd le sens au lieu d'une consigne d'arrêt | **H4 confirmée** |
| `Data.TranslationBusy` = **0** alors que `M3_ActualFrequencyHz` > 50 (0,5 Hz ×100) | arrêt confirmé prématurément → l'étape avance | **H5 confirmée** |
| `instSafetyTranslationM3.ErrorLimitSwitch` ou `.PowerCutOff` sur une arrivée **nominale** | escalade déclenchée sans dépassement réel | **H6** (rapprochement **T287**) |
| `M3_TremieHardStopActive` = 0 alors que le DI Trémie est à 1 et que le chariot avance encore | coupure dure Trémie désarmée par le retrait de sémantique | D07 de la fiche |
| **Aucune** de ces signatures, arrivée propre | les hypothèses H1→H6 sont **réfutées** sur ce scénario | à livrer comme tel (AC1) |

**Comparaison A ↔ C obligatoire** : si le scénario C (manuel) présente la **même** signature que A, la cause
n'est pas le chemin de commande mais un mécanisme commun (capteur, variateur, mécanique) — et le constat
utilisateur (« en manuel ça s'arrête ») doit être requalifié, avec preuve.

---

## 6. Post-traitement et archivage

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py `
  "<chemin>\T334_B_SEMIAUTO_AX14_intermittence_<date>_<n>.trace" `
  --format wide -o "<chemin>\T334_B_SEMIAUTO_AX14_intermittence_<date>_<n>_wide.csv" `
  --metadata "<chemin>\T334_B_SEMIAUTO_AX14_intermittence_<date>_<n>_meta.json"
```
- La trace source n'est **jamais** modifiée ; les CSV dérivés sont des **artefacts** (comme ceux de
  `AUDIT_T300_TRACE…`, non suivis par Git).
- Les preuves durables (trace + CSV + analyse) vont sous `DOC/WFLOW/` (routage
  `TOOLS/AGENT_WORKFLOW/docs/STRUCTURE_AND_CLEANUP.md:112`), **jamais** à la racine du dépôt.
- La section §9 de la fiche T334 est ensuite enrichie de l'analyse **canal par canal**, avec pour chaque
  arrivée la première variable dont la valeur contredit l'attendu et le `fichier:ligne` qui la produit.
- 🧹 Aucun artefact n'est supprimé par un agent : le tri relève d'une décision humaine
  (`AGENTS.md`, § Routage des sorties).

---

## 7. Interdits

- Aucune modification de `CODE/`, aucun test, aucun gate, aucun `CODE_XML/`, aucune IHM.
- Aucun forçage de variable de **logique** (seuls les réglages `GVL_Simulation.SimM3Sensor*` du §4-B).
- Aucune lecture de `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` (périmé par doctrine).
- Ne pas conclure « cause prouvée » sur une trace dont la **période effective** n'a pas été relevée.
- Ne pas interpréter une trace à 100 ms comme une preuve de délai : la conclusion doit nommer la période.

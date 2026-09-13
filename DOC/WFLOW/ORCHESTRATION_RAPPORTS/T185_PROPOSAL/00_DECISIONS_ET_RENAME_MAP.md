# T185 — Décisions validées + carte de renommage (autorité)

> Validé par l'utilisateur (AskUserQuestion, 2026-08-30). Rien n'est écrit dans `CODE/` avant
> validation du diff complet assemblé dans `ORCHESTRATION_RAPPORTS/T185_PROPOSAL/`.

## Décisions

| Id | Décision |
|---|---|
| **Nommage** | Renommage **global maintenant**. Famille `Reference*` → `MachineHoming*` (collision vocabulaire réservé Homing, NAMING_CONVENTION §1quater + NC-090). |
| **Nom FB** | `FB_ReferenceCycle` → **`FB_MachineHomingCycle`** |
| **C-1** | Après perte de datum en mouvement : **acquittement conscient obligatoire** (front `Reset`) avant que `MachineHomed` puisse revenir TRUE. Cause latchée nommée **`MachineHomingLostInMotion`** (l'utilisateur a demandé ce renommage vs `ReferenceLostInMotion`). |
| **C-2** | `ConfirmOpen` **ET** `ConfirmClose` au même scan → **rejet total** (aucune transaction) + cause latchée `MachineHomingDoubleConfirm`. |
| **C-3** | *(non retranché ce tour)* — casser la boucle `FB_Bucket.ActiveOffsetValid` ↔ `MachineHomed` : `FB_MachineHomingCycle` = producteur unique. **À confirmer explicitement** avant patch `FB_Bucket.st`. |

## C-4 — Séparation stricte homing en mouvement / homing benne (clarif. spec utilisateur 2026-08-30)

> « si on est en mouvement le homing benne n'est pas possible ; idem pour le homing 0 m ;
> **seul le homing en montant sur capteur TOP** permet de référencer les 2 codeurs treuils **en
> mouvement**. » Cas à interdire : arrivée sur capteur TOP alors qu'un ref benne est déjà en
> cours ou demandé « au vol ».

Alignement AF-09 §5 : le homing **Nominal** (front `Home` + front capteur haut, capture au front,
vitesse d'accostage constante) est le **seul** qui référence M1/M2 **treuils en mouvement** — il
est produit par `FB_Encoder_Homing`, hors périmètre de ce FB.

Le **ref benne conjoint T185** (ce FB) est un mécanisme **distinct** : MAINT_N2, capteur haut
commun, **treuils à l'arrêt mécanique confirmé**, confirmation visuelle. Règles à encoder :

| # | Règle | Où |
|---|---|---|
| C-4.1 | Ouverture transaction ref benne : préconditions actuelles **+ `AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy`** (jamais « au vol » par-dessus un homing d'axe déjà en cours) | `FB_MachineHomingCycle` §7 |
| C-4.2 | En transaction : `NOT WinchesMechanicallyStopped` → abandon fail-safe (déjà présent `TxAbortRequested`) | idem §8 |
| C-4.3 | Demande de confirmation reçue alors qu'un homing d'axe est `Busy` → **ignorée**, cause latchée `CAUSE_CONFIRM_WHILE_HOMING`, guide reste `HOMING_IN_PROGRESS` | idem |
| C-4.4 | *(hors ce FB — à confirmer si dans le scope T185)* `BtnHomingAtZero` et homing unitaire MAINT : exiger `WinchesMechanicallyStopped` côté `FB_Encoder_Homing` / `PRG_02`. Le homing **Nominal** capteur-TOP reste le seul autorisé en mouvement. | `FB_Encoder_Homing` / `PRG_02` |

C-4.4 touche `AF_Partie-09` + `FB_Encoder_Homing` : **dans le scope du contrat T185** (fichiers
autorisés) mais élargit la tâche — **décision utilisateur requise** : traiter maintenant ou
follow-up T185-b.

## Carte de renommage — identifiants

| Ancien | Nouveau | Portée |
|---|---|---|
| `FB_ReferenceCycle` | `FB_MachineHomingCycle` | FB + fichier + XML + registry + reports + test |
| `instReferenceCycle` | `instMachineHomingCycle` | `PRG_02_Acquisition` |
| `MachineReferenceReady` | `MachineHomed` | sortie FB + PRG_02/03/04 + FB_Bucket + FB_Modes + DUT diag |
| `ReferenceStep` (INT) | `MachineHomingStep` (`E_MachineHomingStep`) | idem + FB_TroubleshootingView + ST_ChainBucket + ST_BucketHMIState |
| `ReferenceInstruction` | `MachineHomingInstruction` | idem |
| `ReferenceTransactionActive` | `MachineHomingActive` | idem (= miroir plat de `Lifecycle.Busy`) |
| `ReferenceLossSafeStop` | `MachineHomingLossSafeStop` | idem + `SafeStopM1/M2_Raw` (PRG_04) |
| `ReferenceFailed` | `MachineHomingFailed` | idem |
| `ReferenceStepAtError` *(nouveau)* | `MachineHomingStepAtError` | sortie FB (R9) |
| `HomingRequestM1` / `HomingRequestM2` | `M1Demand.HomeReq` / `M2Demand.HomeReq` | dans DUT (vocab réservé `HomeReq`) |
| `M2DynamicTargetM` | `M2Demand.DynamicTarget_M` | DUT (NC-030 underscore avant unité) |
| `M2UseDynamicTarget` | `M2Demand.UseDynamicTarget` | DUT |
| `CommitOpenPosition` / `CommitClosePosition` | `BucketCommit.CommitOpen` / `.CommitClose` | DUT sortie |
| `ReferenceCommitOpen` / `ReferenceCommitClose` (PRG_02→FB_Bucket) | `MachineHomingCommitOpen` / `MachineHomingCommitClose` | PRG_02, PRG_04, FB_Bucket |
| `SemiAutoRefusedReference` | `SemiAutoRefusedMachineHoming` | `FB_Modes` (local) |
| `E_MachineReferenceStep` | `E_MachineHomingStep` | nouveau type |
| valeur `BOTH_NOT_REFERENCED` | `BOTH_NOT_HOMED` | enum |
| valeur `M1_NOT_REFERENCED` / `M2_NOT_REFERENCED` | `M1_NOT_HOMED` / `M2_NOT_HOMED` | enum |
| valeur `CONFIRM_BUCKET` | `AWAIT_BUCKET_CONFIRM` | enum (état, pas impératif) |
| `ST_fbRef_AxisHomingStatus` | `ST_fbMachineHomingCycle_AxisHomingStatus` | NC-110 (nom complet FB) |
| `ST_fbRef_HomingDemand` | `ST_fbMachineHomingCycle_HomingDemand` | NC-110 |
| `ST_fbRef_BucketCommit` | `ST_fbMachineHomingCycle_BucketCommit` | NC-110 |

**Inchangés (déjà conformes)** : `Enable`, `Reset`, `Mode`, `TopPositionActive`,
`WinchesMechanicallyStopped`, `M1/M2HomedAndReliable`, `M1/M2HomingBusy/Done/Error`,
`BucketOffsetValid`, `ConfirmOpenPosition`, `ConfirmClosePosition` (audit O2 : `Confirm` =
confirmation d'observation opérateur, pas un `Req`), `Cfg*`, `Ready`, `Fault`, `Lifecycle`.

## Carte de renommage — fichiers

| Ancien | Nouveau |
|---|---|
| `CODE/G_CYCLE/FB_ReferenceCycle.st` | `CODE/G_CYCLE/FB_MachineHomingCycle.st` |
| `CODE_XML/G_CYCLE/FB_ReferenceCycle.xml` | `CODE_XML/G_CYCLE/FB_MachineHomingCycle.xml` (régénéré par bundle) |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_referencecycle.st` | `…/test_fb_machinehomingcycle.st` |
| — nouveaux — | `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` |
| | `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_AxisHomingStatus.st` |
| | `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_HomingDemand.st` |
| | `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_BucketCommit.st` |

`registry.yaml` : entrée `FB_ReferenceCycle:` → `FB_MachineHomingCycle:` (paths + test).
Doc : `AF_Partie-05_v2.1`, `AF_Partie-09_v2.4`, `AF_Partie-10_v2.1` (mentions `FB_ReferenceCycle`),
contrat `TASK_CONTRACT_T185_HOMING_BENNE_CONJOINT_N2.yaml`.

## Rejet d'une reco de l'audit Ollama

- `M2DynamicTargetM` → Ollama proposait `…Meters`. **Rejeté** : NC-030 impose le suffixe d'unité
  `_M` précédé d'un underscore → `DynamicTarget_M`.

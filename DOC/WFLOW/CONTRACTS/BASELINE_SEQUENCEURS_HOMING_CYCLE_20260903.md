# 📸 BASELINE — Séquenceurs Homing & Cycle (état AVANT refonte)

> **But** : figer le comportement **actuel** des deux séquenceurs, étape par étape, pour
> pouvoir **tracer ce que les refontes T226 (homing) et T229 (cycle) modifient**.
> Point de départ = référence de non-régression.
>
> - **Date** : 2026-09-03
> - **Réf. Git** : `7c243ea3` (AvantPrépaG7) — branche `backup/mes-septembre-20260902`
> - **Fichiers tracés** :
>   - `CODE/G_CYCLE/FB_MachineHomingCycle.st` + `_TYPES/E_MachineHomingStep.st`
>   - `CODE/G_CYCLE/FB_Cycle.st` + `_TYPES/E_CycleStep.st`
> - **Tâches liées** : [T226](TASK_CONTRACT_T226_REFONTE_HOMING_SEMIAUTO.yaml) · [T229](TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml) · note [T229_DESIGN](T229_DESIGN_FB_CYCLE_STEPS.md)

---

# 1️⃣ `FB_MachineHomingCycle` — le GUIDE de référencement

> ⚠️ **N'émet AUCUN ordre de mouvement.** Ce n'est **pas** un `CASE` séquentiel : c'est une
> **échelle de priorité recalculée chaque scan** (§6). Les « étapes » sont des **libellés de
> diagnostic**, pas des états qui s'enchaînent. En parallèle tourne une **vraie sous-machine** :
> la transaction de référencement conjoint (§4-§5).
>
> Instancié dans `PRG_02_Acquisition` (`instMachineHomingCycle`, `Enable := TRUE`).
> Sortie clé : `MachineHomed` (gate SEMI_AUTO). Flux : `PRG_02.Data.MachineHoming.*` →
> `PRG_04` (`BucketState.MachineHomingStep/.MachineHomingInstruction`).

## 🪜 Échelle du guide (priorité décroissante — `E_MachineHomingStep`)

| Prio | 🎦 Étape (val.) | Condition d'affichage | Consigne opérateur (texte exact) | Sortie / transition |
|---|---|---|---|---|
| 1 | 🟥 **FAILED** (70) | `MachineHomingFailed = TRUE` | « Referencement incomplet : rester en N2 et recommencer » | front `Reset` → purge complète |
| 2 | 🟧 **LOSS_SAFESTOP** (5) | `HomingLossLatched` (datum perdu **en mouvement**) | « Reference perdue en mouvement : arret controle en cours » + `MachineHomingLossSafeStop = TRUE` | arrêt méca confirmé **+** `Reset` conscient (`ReHomingAckRequired`) |
| 3 | ⏳ **HOMING_IN_PROGRESS** (50) | transaction armée (`HomingStarted`) OU un axe `HomingBusy` | « Referencement conjoint M1/M2 en cours : ne pas manoeuvrer » | fin de transaction (commit ou abort) |
| 4 | 🔴 **BOTH_NOT_HOMED** (10) | M1 **et** M2 non `HomedAndReliable` | « Codeurs M1 et M2 non references : passer en maintenance N2 » | M1 ou M2 devient homé |
| 5 | 🔸 **M1_NOT_HOMED** (11) | M1 seul KO | « Codeur M1 non reference ou mesure douteuse : homer M1 » | M1 homé |
| 6 | 🔸 **M2_NOT_HOMED** (12) | M2 seul KO | « Codeur M2 non reference ou mesure douteuse : homer M2 » | M2 homé |
| 7 | *(2 axes homés, mais datum benne inconnu : `NOT CommitPublished AND NOT BucketOffsetValid`)* | | | |
| 7a | 🅾️ **OFFSET_UNKNOWN** (20) | ci-dessus **ET** `Mode ≠ MAINT_N2` | « Offset benne inconnu : passer en maintenance N2 » | passage en N2 |
| 7b | ⬆️ **NEED_TOP_POSITION** (30) | en N2, `NOT TopPositionActive` | « Monter Both a vitesse lente jusqu au capteur haut » | capteur haut atteint |
| 7c | 🛑 **NEED_MECHANICAL_STOP** (40) | capteur haut OK, `NOT WinchesMechanicallyStopped` | « Capteur haut atteint : relacher la commande et attendre l arret » | treuils arrêtés |
| 7d | 🙋 **AWAIT_BUCKET_CONFIRM** (45) | `WindowSafe` (N2 + capteur haut + arrêt méca) | « Confirmer visuellement la benne : Fermee ou Ouverte » | front `ConfirmOpenPosition` / `ConfirmClosePosition` |
| 8 | ✅ **VALID** (60) | 2 axes `HomedAndReliable` + datum benne connu + `NOT Fault.Latched` | « Referencement machine valide : mode nominal disponible » | → **`MachineHomed = TRUE`** (gate SEMI_AUTO) |

### 🚪 Gate `NOT Enable` (§3)
`MachineHomingStep := IDLE (0)`, `MachineHomingInstruction := 'Referencement indisponible'`,
`MachineHomed := FALSE`, toutes demandes à FALSE, `RETURN`.

## 🔄 Sous-machine « transaction de référencement conjoint » (§4-§5)

| 🎬 | État | Ce qui se passe | Transition |
|---|---|---|---|
| 0️⃣ | **Repos** | `HomingStarted = FALSE` | ⬇️ ouverture |
| ▶️ | **Ouverture** | front **unique** `ConfirmOpenEdge XOR ConfirmCloseEdge`, **`WindowSafe`** (`Mode = MAINT_N2` + `TopPositionActive` + `WinchesMechanicallyStopped`), aucun axe `HomingBusy`, pas de double-confirm → `HomingStarted := TRUE` ; `M1Demand.HomeReq` + `M2Demand.HomeReq` (1 scan) ; `M2Demand.UseDynamicTarget := TRUE`, cible = `Cfg.CfgTopHomingTarget_M + Cfg.CfgOffset(Close/Open)_M` | ⬇️ |
| 👀 | **Attente Busy** | tant qu'un axe `HomingBusy` → `HomingBusyObserved := TRUE` | ⬇️ |
| ✅ | **Commit atomique** | `HomingBusyObserved` **ET** les 2 `HomedAndReliable` **ET** les 2 `HomingDone` → `BucketCommit.CommitOpen := PendingOpen` / `CommitClose := PendingClose` (1 scan) → `CommitPublished := TRUE`, `HomingStarted := FALSE` | fin |
| ❌ | **Abort fail-safe** | à tout instant pendant `HomingStarted` : `NOT TopPositionActive` **OU** `NOT WinchesMechanicallyStopped` **OU** `M1Status.HomingError` **OU** `M2Status.HomingError` → `MachineHomingFailed := TRUE`, `HomingStarted := FALSE`, pending purgés | → FAILED |

## ⚠️ Détection de perte de datum (§1)
- `MachineHomedRaw := AxisHomed AND (CommitPublished OR BucketOffsetValid) AND NOT MachineHomingFailed AND NOT ReHomingAckRequired`.
- `MachineWasHomed` mémorise un datum valide. Si `MachineWasHomed AND NOT MachineHomedRaw AND NOT WinchesMechanicallyStopped` → `HomingLossLatched := TRUE`.
- `HomingLossLatched` → `ReHomingAckRequired := TRUE` (pas de redémarrage auto : `MachineHomed` reste FALSE jusqu'à un `Reset` conscient).

---

# 2️⃣ `FB_Cycle` — le SÉQUENCEUR SEMI_AUTO

> ✅ Vrai `CASE` séquentiel sur `E_CycleStep`. Produit `WinchM1Cmd` / `WinchM2Cmd`
> (`ST_ProgramWinchRequest`), `TranslationCmd`, `BucketCmd`. Tout mouvement gaté par
> `ProcessPermit* = JoystickDeflected AND DeadmanArmed` (8 booléens identiques).
> Instancié dans `PRG_03_Modes_Cycle` (`instCycleSemiAuto`), `Enable := (Mode = SEMI_AUTO)`.
>
> ⚠️ En SEMI_AUTO, `FB_WinchCmdArbitrationM1/M2` = **passthrough pur** de `ReqWinch` : le
> gating aval (BucketBusy, SyncBlocks, atomicité both) est court-circuité. `FB_Cycle` porte
> **seul** la responsabilité du couplage M1/M2 côté commande.

| 🎬 Étape (val.) | Ce qu'on commande | Transition → étape suivante |
|---|---|---|
| 💤 **X0 PREPARATION** (0) | treuils 0, translation 0, benne 0. `WaitingForOperator`. `SampleCountDone := FALSE`. | front `StartCycle` **OU** front `DeadmanArmed`, **ET** `NOT Fault.Latched` → **X1** |
| ⬆️ **X1 HOMING** (1) | si `NOT HomedM1 OR NOT HomedM2` : M1+M2 **montée lente `StepTgt := 1`** (homme-mort). | `HomingRequest` → **X2** · si déjà homé (`HomedM1 AND HomedM2`) → **X2** direct |
| 🎯 **X2 WORK_POS_SELECT** (2) | translation M3 vers `SelTarget` (1=Trémie / 3=P1 / 4=Maintenance), `ProcessPermitM3_Tremie`. | joystick défléchi **ET** capteur cible (`Translation_At_Tremie`/`_At_P1`/`_At_Maintenance`) → **X3** |
| 🪣 **X3 OPEN_BUCKET** (3) | `BucketCmd.ReqOpen` (homme-mort). ⚠️ treuils **non re-forcés** à 0 (valeurs héritées). | `Benne_IsOpen` (+ `Benne_Done`) → **X4** · si déjà ouverte → **X4** direct |
| 🌊 **X4 DESCEND_OPEN** (4) | M1+M2 **descente synchro `StepTgt := 3`** + `BucketCmd.ReqKoboldMeasureEnable`. | joystick **ET** `KoboldContactFond` → mémorise `TouchPositionM` / `RaiseTargetM` → **X5** · ⚠️ cause défaut `LimitLegalReached` |
| ⬆️ **X5 BOTTOM_CONFIRMED** (5) | M1+M2 **montée `StepTgt := 1`**. | joystick **ET** `M1_CablePosM ≥ RaiseTargetM` **ET** `M2_CablePosM ≥ RaiseTargetM` → **X6** |
| 🪣 **X6 CLOSE_BUCKET** (6) | `WinchM1Cmd.RunRequest := FALSE`, `BucketCmd.ReqClose` (homme-mort). ⚠️ **flags M2 non nettoyés** (résidus `ReqAscent/StepTgt` de X5). | joystick **ET** `Benne_Done` **ET** (`Benne_IsClosed OR Benne_IsRoughlyClosed`) → **X7** |
| 🐌 **X7 CTRL_ASCENT** (7) | M1+M2 **montée lente `StepTgt := 1`** + surveillance **écart vitesse M1/M2** (`SpeedMismatch*`) + tempo stabilisation 30 s + tolérance écart codeurs 0,25 m. | joystick **ET** `M1&M2 ≥ TouchPositionM + 2,0 m` **ET** `|M1−M2| ≤ 0,25 m` → **X8** · ⚠️ cause défaut stabilisation / tolérance écart |
| ⬆️ **X8 ASCENT_LOADED** (8) | M1+M2 **montée `StepTgt := 4`**. | joystick **ET** `M1_CablePosM ≥ CableLimitM1AscentM` → **X9** |
| 💧 **X9 DRAIN_PAUSE** (9) | treuils 0. Tempo égouttage 5 s. ⚠️ `DrainingTimer(IN := TRUE)` **câblé en dur** → `Q` déjà vrai avant la 1ʳᵉ arrivée en X9 (égouttage non attendu au 1ᵉʳ cycle). | joystick **ET** `DrainingTimer.Q` → **X10** |
| 🚚 **X10 TRANSLATE_DUMP** (10) | translation M3 vers **Trémie** (`PositionTgt := 1`), homme-mort. | joystick **ET** `Translation_At_Tremie` → **X11** |
| 🪣⬇️ **X11 OPEN_DUMP** (11) | **M1+M2 descente `StepTgt := 1` ET `BucketCmd.ReqOpen` au MÊME scan** (`ReqOpen := ProcessPermitBucket_Open AND WinchM1Cmd.ReqDescend`) — la benne s'ouvre en déroulant M2. ⚠️ **étape à scinder (T229)** : mélange descente couplée + différentiel benne. Libellé dit « montée possible » mais le code ne commande **que** la descente. | joystick **ET** `Benne_Done` **ET** `Benne_IsOpen` → **X13** |
| ✅ **X13 DONE_SYNC** (13) | tout 0. `Lifecycle.Done := TRUE`. `SampleCount + 1` (cadré par `SampleCountDone`). | front `StartCycle` → **X0** (rebouclage cycle) |
| 🟧 **STABILIZING** (14) | repli défaut : tout 0, `BucketCmd.ReqKoboldMeasureEnable := FALSE`, `Fault.Latched`. | front `Reset` (cause disparue) → **X0** |

## ⚠️ Transitions transverses (hors `CASE`, évaluées chaque scan)

| Déclencheur | Effet |
|---|---|
| `NOT Enable` **OU** `NOT PowerContactorEngaged` **OU** `EncoderFaultPresent` | neutralise toutes les demandes ; si cycle en cours (`State ∉ {X0, X13, STABILIZING}`) → `PausedState := State`, `WaitingResume := TRUE` ; `RETURN` |
| front `Fault.Error` (`ErrorEdge.Q`) | `CycleStepAtError := State` → **STABILIZING** ; `WaitingResume := FALSE` |
| relâche manche **OU** homme-mort pendant `Lifecycle.Busy` | commandes coupées, **étape conservée** (pas de retour X0), **pas** de défaut |
| retour SEMI_AUTO après pause + front `StartCycle` | restaure `PausedState` (reprise **consciente**) ; sinon *hold* + message « Reprendre le cycle : appuyer sur StartCycle » |
| front `AbortCycle` | → **X0**, `WaitingResume := FALSE`, `PausedState := X0` |
| front `Reset` en STABILIZING | `SavedState := X0` ; → **X0** |
| **Causes de défaut latchées** (§1) | `LimitLegalReached` (X4 seul) · `WinchSyncError` (hors X0/STAB) · écart vitesse M1/M2 confirmé (500 ms, X7) · `NOT HeartbeatIhmOk` · **`StepMaxTimer.Q` 60 s** ⚠️ (`IN` conditionné à `State`, **non réarmé au changement d'étape** → cumulatif) · défaut stabilisation / tolérance écart codeurs (X7) |

---

# 📌 Ce que les refontes vont toucher (repères de suivi)

## T229 — `FB_Cycle`
| Zone | Cible | Étapes impactées |
|---|---|---|
| B1 | 🧹 8 `ProcessPermit*` → 1 `CycleMotionPermit` ; paliers `StepTgt` 1/3/4 → constantes nommées | toutes (iso-comportement) |
| B2 | 🐛 `StepMaxTimer` réarmé par étape ; `DrainingTimer` conditionné à `State = X9` ; résidus flags M2 en X6 | X6, X9, transverse |
| C | 📊 table `étape → {M1Dir, M2Dir, SpeedStep, BucketPhase}` (DUT `ST_CycleStepWinchProfile`) | X10, X11 (migration) puis X4–X9 (après T226) |
| D | ✂️ split X11 → `X11A_DUMP_ARRIVE` (15) + `X11B_DUMP_OPEN` (16), `X11C` (17) réservé | X11 |
| E | 🛡️ garde-fou `ABS(M1_CablePosM − M2_CablePosM)` dans `FB_Cycle` + gate CI statique sur la table | transverse |

## T226 — `FB_MachineHomingCycle` + `FB_Cycle` (Zone F, à cadrer)
- **`FB_Cycle.X1_HOMING` gutté** : SEMI_AUTO n'est entré que si `MachineHomed` (AC1) → le cycle
  ne contient **plus aucun référencement**. Supprimer : l'entrée `HomingRequest`, la branche
  `IF NOT HomedM1 OR NOT HomedM2` (montée lente + `StepTgt` référencement), le commentaire
  « chercher capteur top + référencement ». X1 devient une **vérification de position** : treuils
  au FDC logiciel haut → franchie sans mouvement ; sinon consigne opérateur « monter au FDC haut »
  (joystick maintenu, ralenti auto — cf. C3). Le référencement M1/M2 reste 100 % la responsabilité
  de `FB_MachineHomingCycle` (AC8, D5, D6).
- Échelle de priorité + transaction : rendre la transition **init → cycle** pilotée par **condition d'état** (D6 : plus de bouton `HomingRequest` / `ConfirmXxx` explicite).
- **Joystick armé pour tout mouvement du homing** : dès que la séquence de référencement coordonne
  un mouvement (montée couplée jusqu'au capteur haut, bootstrap datum), il faut le **même principe
  que `CycleMotionPermit`** (manche défléchi + homme-mort armé) — aucun ordre treuil sans permis
  opérateur maintenu. Aujourd'hui `FB_MachineHomingCycle` n'émet aucun ordre de mouvement (le
  mouvement passe par le joystick maintenance) ; si T226 lui fait coordonner le mouvement, ajouter
  ce gate.
- **Transaction §4/§5** : ✅ **FAIT** (hors T226, passe conformité) — réécrite en
  `CASE TxState OF` sur `E_MachineHomingTxState` (`IDLE` / `ARMED` / `BUSY_OBSERVED`),
  iso-comportement (18/18 tests). `HomingStarted` conservé en miroir de `(TxState <> IDLE)`.
  Le §6 (guide opérateur) **reste** en `IF/ELSIF` : échelle de priorité recalculée chaque scan,
  pas une machine d'état (l'étape est le résultat, pas l'état où l'on dispatche). Précédent projet :
  `FB_Modes.st:225-239` (échelle IF/ELSIF → `ModeChangeBlockReason`).
- **Angle mort §6** (revue cohérence, à traiter T226 ou tâche diag) : l'échelle `§6` **n'a aucune
  branche `Fault.Latched`**. Après un rejet `DOUBLE_CONFIRM` / `CONFIRM_WHILE_HOMING` (causes
  latchées qui **ne posent pas** `MachineHomingFailed`), on a `Fault.Latched = TRUE`,
  `MachineHomed = FALSE`, mais l'échelle affiche quand même `AWAIT_BUCKET_CONFIRM` / `VALID` —
  l'opérateur ne voit pas de consigne « acquitter le défaut », et `MachineHomingStepAtError` (R9)
  fige une étape non-défaut. Les causes `HOMING_ERROR_M1/M2` et `TransactionAbort` sont couvertes
  (elles posent `MachineHomingFailed`).
- Bootstrap datum : `M1 := 0`, `M2 := offset fermé`, montée couplée, capteur haut → réf config (~8,5 m) + `Homed`.
- Réf M1 + M2 au **même front unique** capteur haut.
- Perte datum SEMI_AUTO → SafeStop treuils **puis** bascule MAINT_N1.

---

---

# 🚫 Contraintes NON NÉGOCIABLES (rappels opérateur — à préserver par T226 / T229)

## C1 · Continuité de mouvement sans à-coup (cycle SEMI_AUTO nominal)
En nominal, l'opérateur **maintient le joystick dans la même position (défléchi + homme-mort armé)
du début à la fin du cycle**. L'automate enchaîne les étapes **sans jamais s'arrêter ni secouer** ;
une seule inversion de sens (pousser → tirer) sur tout le cycle.

| # | Étape vécue opérateur | Ce que l'automate fait | Joystick |
|---|---|---|---|
| 1 | pousse (demande plongée) en haut | si benne pas ouverte → **l'ouvre sans s'arrêter** puis enchaîne | poussé, maintenu |
| 2 | — | plongée **M1+M2 couplés**, contacteur Kobold armé sur condition profondeur | poussé, maintenu |
| 3 | — | détection fond → treuils **stop** + signalement | poussé, maintenu |
| 4 | on lui demande de **tirer** | inversion de sens | passe à tiré |
| 5 | tire | **fermeture benne** d'abord, sans arrêt | tiré, maintenu |
| 6 | — | benne fermée → **remontée palier 1** sur distance de contrôle ; matière coincée → **reste palier 1** | tiré, maintenu |
| 7 | — | remontée jusqu'en haut, aucun arrêt / secousse entre étapes | tiré, maintenu |

➡️ **Impact conception** : `CycleMotionPermit` ne retombe jamais entre étapes ; une transition ne
force `RunRequest := FALSE` que sur arrêt réellement voulu (fond, butée, fin). Le split X11 (T229)
et la table config treuil ne doivent pas introduire de creux de commande. Test dédié : parcours
X0→X13 à joystick constant, vérifier `RunRequest` sans trou aux frontières d'étape.

### C1e · Transition fermeture benne → remontée (X6 → X7) sans temps mort
Au passage « benne fermée » → « montée M1+M2 » : **M2 ne s'arrête pas** au moment où la benne
est fermée, **M1 est lancé sans temps d'arrêt** ni perte d'arming joystick ni à-coup. La commande
de montée doit être établie sur M1 **et** M2 dans le même scan que la sortie de X6, en continuité
directe de la fermeture (pas de scan intermédiaire à `RunRequest = FALSE`).
⚠️ **À vérifier** : l'interface `ST_ProgramWinchRequest` / `FB_WinchCmdArbitration` / `PRG_04`
permet-elle ce basculement sans creux ? (analyse en cours — StruCpp sim si besoin, sortie
`TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING`).

## C3 · Translation M3 en cycle = PAS de déplacement automatique (comme maintenance)
Le cycle **ne pilote jamais** un déplacement autonome de M3 vers une position.
- L'IHM affiche la consigne à l'opérateur (ex. « joystick à gauche vers trémie »).
- L'opérateur **maintient le joystick** dans ce sens (armé).
- Le **ralentissement automatique au capteur PV** (pré-position) et l'**arrêt au FDC de position**
  (P_trémie, P1, P2) sont assurés **exactement comme en maintenance** (`PRG_05` / `FB_Translation`) —
  rien de plus.
- Le séquenceur `FB_Cycle` se contente d'**afficher la consigne** et de **surveiller l'arrivée**
  (`Translation_At_Tremie` / `_At_P1`) pour franchir l'étape.
### C3.1 · X2 — point de départ du cycle = TOUJOURS P1
Axe M3 : **Trémie — P2 — P1 — Maintenance** (P2 = capteur PV entre Trémie et P1).
- M3 à **Trémie** ou entre Trémie et P1 (pas encore à P1) → consigne « joystick vers P1 » ;
  l'opérateur maintient, `PRG_05` ralentit au capteur P2 (PV) et **arrête sur P1**. Puis → X3.
- M3 **à P1** → rien à faire → X3.
- M3 **à Maintenance** ou au-delà de P1 côté maintenance → consigne « **quitter le SEMI_AUTO,
  se déplacer en maintenance vers P1 (à gauche), puis relancer le cycle** ». Le cycle **ne
  déplace pas** M3 dans ce cas.
→ le cycle part **toujours de P1**. Plus de `SelTarget` (cible unique = P1). X10 (retour trémie
pour vidage) : même principe — consigne « joystick vers trémie », ralenti PV, stop trémie.

⚠️ **Écart avec l'existant** : X2 / X10 posent aujourd'hui `TranslationCmd.PositionTgt := <cible>`
+ `TranslationCmd.ReqStart := CycleMotionPermit`. À retirer : le cycle ne fournit que la consigne
opérateur + la surveillance d'arrivée (`M3_AtP1Stable` / `M3_AtTremieStable`).

**Finding interface `PRG_05` (lecture partielle)** : la logique « joystick + ralenti PV + arrêt
sur position » **existe déjà** dans `instArbM3` (`FB_TranslationCmdArbitrationM3`) + `FB_Translation`
§4ter (anti-rebond `DirectionAtArrival`), branche `SelTarget = 0` (mode manuel). À vérifier :
`FB_TranslationCmdArbitrationM3` honore-t-il le joystick **en mode SEMI_AUTO** (comme le fait
maintenance/manuel) ou seulement `ReqTranslation` (comme `FB_WinchCmdArbitrationM1` qui est
passthrough pur en SEMI_AUTO) ? Si passthrough seul → petit ajout côté arbitrage M3 pour accepter
le joystick en SEMI_AUTO, OU le cycle dérive la direction joystick dans `ReqTranslation` (sans
`PositionTgt`). **PRG_05 hors scope T229 → à cadrer.**

## C2 · Homing au démarrage / sortie SEMI_AUTO si non référencé (→ T226)
- Au démarrage automate, **si les codeurs M1/M2 ne sont pas référencés → le cycle de homing machine
  doit se lancer** (guide `FB_MachineHomingCycle`).
- Si on est en SEMI_AUTO et que les codeurs ne sont plus référencés (`MachineHomed` FALSE) →
  **sortie du cycle automatique → bascule MAINTENANCE → on se retrouve dans la séquence
  `FB_MachineHomingCycle`**.
- Déjà porté par le contrat T226 : AC1 (SEMI_AUTO homed-only), AC2 (perte datum → SafeStop treuils
  PUIS MAINT_N1), D1. Ce rappel confirme l'intention, rien à rouvrir.

---

_Baseline figée le 2026-09-03. Toute modification de comportement listée ci-dessus doit être
rapprochée de cette référence (test de non-régression + revue de diff)._

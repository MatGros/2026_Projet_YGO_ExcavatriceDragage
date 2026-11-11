# ⚙️ CYCLES_AUDIT_A — Audit de conformité des cycles (code vs AF vs standards)

**Date** : 2026-08-31 · **Auteur** : Audit DSH (review impartial — pas alarmiste)
**Périmètre** : `FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionAssist`, `FB_MachineHomingCycle` + DUT
`_TYPES/` + `PRG_03_Modes_Cycle.st`
**Référentiels** : `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`, `AF_Partie-05_Modes_Maintenance_v2.1.md`,
`GUIDE_SEQUENCEUR_v1.2.md`, `CODE_QUALITY_STANDARDS.md` (POO §5, §2ter zéro-REX, §2quater, §11bis R1–R9), `NAMING_CONVENTION.md`
**Méthode** : relecture intégrale des 4 FB + DUT + `PRG_03`, vérification croisée ligne par ligne avec les AF
et les standards. **Aucun `Device.export`** utilisé (source de vérité = `CODE/*.st`).

> 📌 Un **contre-audit indépendant (`CYCLES_AUDIT_B_20260831.md`)** a été produit en parallèle sur le même
> périmètre. Ce rapport A est l'audit principal ; les points **convergents** sont signalés « = B#n », les
> points **nous spécifiques** sont signalés « A-nouveau ».

---

## 🧭 Synthèse & verdict par axe

| # | Axe | Verdict | Gravité |
|---|---|---|---|
| **1** | Conformité **code vs AF** | 🟠 **Partielle** — l'AF-P04 est **en partie périmée** (nom de FB, principe de réutilisation non réalisé, commentaires trompeurs). Le comportement fonctionnel des FB est largement conforme aux intentions, mais la doc ne reflète plus le code refactoré. | MED |
| **2** | Conformité **standards** (`POO §5`, `NAMING`, `R1–R9`, zéro-REX §2ter`) | 🟡 **Bonne avec écarts** — R1–R9 conformes ; **écarts isolés** : références `T185` dans le code (§2ter), interface FB_Cycle avec entrées non consommées (§4 « code mort »), drift de nom `ExtractionSequence`/`Assist` dans plusieurs AF. | LOW→MED |
| **3** | **Sécurité** cycles (homme-mort, interlocks, transitions Grafcet, StepAtFault) | 🟠 **2 points safety réels** (contournement d'un défaut latché non acquitté ; reprise de mode sans geste conscient) ; **fondations saines** par ailleurs. | HIGH / MED |
| **4** | **Ergonomie** / lisibilité / robustesse du séquenceur | 🟢 **Bonne** — séquenceur lisible (CASE + enum, labels `Xn`, régions), mais **duplication** d'implémentation SemiAuto/Maintenance et **entrées mortes**. | LOW→MED |

> ⚖️ **Verdict général** : le **socle fonctionnel et safety des cycles est solide** (homme-mort continu
> bien gaté, repli `STABILIZING` conforme R9, accumulateurs anti-pompage, coupure même-scan H1/H2, datum
> machine avec re-homing conscient). Les défauts identifiés sont **concentrés sur la trajectoire de
> conformité doc↔code** (drift post-refactor) et **2 points de robustesse safety** ciblés et correctibles à
> faible coût. Rien ne remet en cause l'architecture d'ensemble.

---

## ✅ Fondations saines — ce que l'audit A valide sans réserve

- **Gate continu homme-mort** (`FB_Cycle.st:259-266` puis `:655-662`) : chaque commande d'actionneur est
  gatée par `ProcessPermit* := CycleMotionPermit AND DeadmanArmed`, ré-évaluée **chaque scan**, et le repli
  §4 neutralise l'ensemble dès perte du permis. Conforme **D2 / AF-04 §2**.
- **Repli défaut** (`:275-278`) : `ErrorEdge.Q → CycleStepAtError := State` **puis** `State := STABILIZING`,
  capture **avant** la bascule → conforme **R9 / GUIDE_SEQUENCEUR §7**.
- **Acquittement sur front** : `ResetEdge` (R_TRIG) partout, pas de réarmement par niveau.
- **Anti-pompage homme-mort (D1)** : accumulateurs `+= CycleTime` uniquement sous `MotionRequestActive AND
  direction` (`DiveSearch:99-107`, `ExtractionAssist:118-130`).
- **Coupure même-scan (H2)** : `BucketCloseRequest := AssistPermit AND NOT BucketError` ; `AscentPermit`
  sur `AscentControlSafe`/`AscentNominalSafe` ; `DescendPermit/KoboldContactorCmd` sur `DescentActive`.
- **Bornage numérique (H3)** : `LIMIT(plancher, val, plafond)` avant `REAL→UDINT→TIME` (anti-overflow).
- **Datum machine `FB_MachineHomingCycle`** : perte de datum en mouvement → `MachineHomingLossSafeStop`,
  re-homing **conscient** C-1 (`ReHomingAckRequired`, aucun redémarrage auto), commit benne **atomique**
  après les deux succès, rejet du double-confirm (C-2). Câblé dans `PRG_02_Acquisition` (`:402-424,437-491`).
- **Interface `ST_Program*Request` (NC-090)** : `FB_Cycle` produit directement les types de contrat
  inter-PRG, plus de DUT `ST_fbCycle_*CmdDemand` redondants ni re-mapping champ-à-champ. Conforme `NC-090`.

---

## 🔴 Axe 3 — Sécurité (par ordre de gravité)

### 🟥 F-01 · HIGH / Safety — Contournement d'un défaut latché non acquitté via `Abort` + `Start`
*(convergence = B#1, confirmé ligne à ligne)*

**Fait**
- `FB_Cycle:253` — `Ready := Enable AND NOT Fault.Latched` (le défaut latché bloque `Ready`).
- `FB_Cycle:280-285` — `ResetEdge` ramène `STABILIZING → X0` **et** acquitte le socle (`instFault(Reset)`).
- `FB_Cycle:288-292` — `AbortEdge` ramène à `X0` **sans toucher au socle** → `Fault.Latched` reste `TRUE`.
- `FB_Cycle:324` — transition `X0→X1` : `IF (StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Error`
  → teste **`Fault.Error` (live)** et **pas `Fault.Latched`**.

**Chemin fautif** : cause latente latched (limite légale, synchro, heartbeat) → cause disparue → `Fault.Error=FALSE`
mais le latch reste → l'opérateur appuie **Abort** au lieu de **Reset** → `State := X0` (latch conservé) → un
**Start** ou l'armement homme-mort satisfont `NOT Fault.Error` → **le cycle redémarre avec un défaut latché
jamais acquitté**.

**Impact safety** : viole la règle non négociable « jamais de redémarrage automatique après défaut » et la
doctrine « `Reset` = front » (cause disparue **+** appui conscient). Une cause latente peut repartir en
mouvement sans validation consciente. **À corriger.**

✅ **Correctif** : la transition `X0→X1` doit tester `NOT Fault.Latched` (au lieu de `NOT Fault.Error`), ou gater
`Ready` sur `NOT Fault.Latched` de façon que le démarrage en X0 soit impossible tant que le défaut n'est pas
acquitté. Option complémentaire : exiger un `Reset` si `Fault.Latched` au `Abort`.

---

### 🟥 F-02 · HIGH (doc) / MED (safety) — Reprise après bascule de mode sans geste conscient (`WaitingResume` = code mort)
*(convergence = B#2, confirmé)*

**Fait**
- `FB_Cycle:121` `WaitingResume`, `:229-232` mémorise `PausedState`/`WaitingResume` à la sortie de mode.
- `FB_Cycle:269-272` — le bloc `IF EnableEdge.Q AND WaitingResume THEN ;` est **vide** (commentaire seul).
- `FB_Cycle:304+` — le `CASE` exécute l'état **mémorisé** directement (ex. `:418` X4 re-écrit la commande
  dès le retour) ; la porte §2 ne ramène **pas** à X0 (seul `STABILIZING` est renvoyé à X0 par `ResetEdge`).

**Conséquence** : à la bascule Maintenance→SemiAuto, si l'opérateur ré-engage manche + homme-mort, le cycle
**reprend immédiatement à l'étape mémorisée**, sans l'appui `BtnStart`/armement exigé par `AF_Partie-04 §4.1`.
Le seul gate restant est la présence opérateur continue (manche + deadman) — **moins strict que la doc**.

**Impact** : non-conformité doc↔code avérée (le contrat AF-04 §4.2 « reprise sécurisée » n'est pas tenu) et
affaiblissement du « geste conscient de reprise » en cas de toggle en pleine plongée/remontée. La présence
opérateur reste exigée → **impact safety réel modéré**, mais c'est un drift à traquer.

✅ **Correctif** : rendre `WaitingResume` réel — au retour de mode, forcer le passage par X0 (ou un état
PAUSE dédié) et n'autoriser la poursuite que sur un `StartCycle` explicite (aligner `AF-04 §4.1`).

---

### 🟠 F-03 · MED / Robustesse — Duplication Diving/Extraction dans `FB_Cycle` alors que l'AF revendique la réutilisation
*(convergence = B#3, confirmé — c'est aussi un écart **code ↔ AF**)*

**Fait** : `PRG_03:163-167` et `:173-176` — `Enable` de `FB_DiveSearch`/`FB_ExtractionAssist` = `(Mode=N1 OR N2)`
→ en **SEMI_AUTO** les assistants sont **désactivés** (`PRG_03:312` « Aucun assistant n'est actif en SEMI_AUTO »).
`FB_Cycle` **réimplémente** la plongée (X4), fermeture/remontée (X5–X8) en interne.

**Écart AF** : `AF_Partie-04 §2` (« Diving et Extraction… **réutilisés** par le cycle semi-auto ») et §3/§8
sur-communiquent une réutilisation **non réalisée dans le code**. **Deux moteurs** de la même logique coexistent
(cycle vs maintenance) → **risque de divergence** de réglages (seuils, paliers, timeouts) entre SemiAuto et
Maintenance.

**Impact** : pas une faille safety immédiate, mais un coût de maintenance élevé et un risque d'écart de
comportement futur. À assumer (doc) ou à traiter en dette.

---

### 🟠 F-04 · MED / Robustesse — Asymétrie X8 : progression sur M1 seul
*(convergence = B#4, confirmé)*

**Fait**
- X5 (`:459`) et X7 (`:506-509`) : transitions sur **M1 ET M2** (+ écart toléré).
- X8 (`:532`) : `IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM` → **M1 seul**.

**Conséquence** : X8 avance vers X9 (égouttage) puis X10 (translation) dès que **M1** atteint la limite haute,
même si M2 est **en retard dans la tolérance synchro** (≤0,50 m critique). Seul filet : le défaut synchro aval
`PRG_04`. **Pas une casse directe**, mais incohérence X5/X7 vs X8 à **justifier (M1 axe maître ?) ou corriger**
(ajouter `M2 >= CableLimitM1AscentM`).

---

### 🟢 F-05 · LOW / Coherence — Polarité / sémantique Kobold **contradictoire** entre `FB_Cycle` et `FB_DiveSearch` sur le **même** signal
*(A-nouveau — devoir d'alerte)*

**Fait** : `PRG_03` câble les deux FB sur le même `PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI`
(`FB_Cycle:223` `KoboldContactFond` ; `FB_DiveSearch:141` `KoboldImmersed`).
- **`FB_DiveSearch`** (conforme `AF-04 §3`) : signal **haut = immergé** pendant la descente ; **front descendant
  1→0 = fond** (`KoboldFallEdge` → `BottomTouchConfirmed`).
- **`FB_Cycle`** `X4→X5` (`:427-437`) : consomme **le niveau haut = contact fond** (`KoboldContactFond` TRUE,
  commentaire `:32` « TRUE = contact fond »).

**Risque** : deux interprétations **opposées** du même fil. Si la polarité physique suit l'AF-04 §3 (haut=immergé,
fond=front descendant), alors `FB_Cycle` déclencherait X4→X5 dès l'immersion, pas au fond. À **confirmer au
schéma électrique** — soit un défaut réel de polarité FB_Cycle, soit un signal dérivé/polarisé différemment par
mode. **Ne pas corriger sans confirmation matérielle**, mais à trancher explicitement (devoir d'alerte).

---

## 🔧 Axe 1 — Conformité code ↔ AF

### F-06 · MED / Doc — Nom de FB « extraction » incohérent sur tout le périmètre doc
*(A-nouveau — drift de renommage non propagé)*

Le code (et `PRG_03` + `GUIDE_SEQUENCEUR:350` + `INTERPRG_CONTRACT`) utilisent **`FB_ExtractionAssist`**. Mais
toute la chaîne AF / conception utilise encore **`FB_ExtractionSequence`** :
`AF-P04 §3`, §3bis (matrice), TC-P04-020/021, §2 ; `AF_Partie-02:220` ; `AF_Partie-10:11,315` ;
`FB_Bucket_v1.0:7,16,315,337,378` ; `DOC/DIA/*.puml` ; `TASKS.yaml` ; fiches `DESIGN_*T181*` ; `AF_VIEWER.html`.

➡️ **Confirme un refactor sans mise à jour des AF associées.** À traiter par un lot doc de renommage (aligner
`ExtractionSequence → ExtractionAssist`), sinon la traçabilité AF↔code se perd. (A noter : les docs `DESIGN_` et
`VERSION_HISTORY` montrent que le renommage `ExtractionControlActive` a été propagé **dans le code** mais pas le
nom du FB.)

### F-07 · LOW / Doc — Sections AF périmées (références obsolètes)
*(convergence = B#7, complété)*

| Source | Élément périmé |
|---|---|
| `AF-04 §2 / §8` | « Diving/Extraction **réutilisées** par le cycle semi-auto » — contredit par le câblage N1/N2-only (F-03). |
| `AF-04 §4.2` | Enum `E_CycleStep` conforme ; mais le commentaire X5 « fond validé **(FB_DiveSearch)** » est trompeur : en SEMI_AUTO c'est le **retour brut** `KoboldContactFond` qui transitionne (F-05), pas `FB_DiveSearch` (désactivé). |
| `AF-05 §4bis:250` | `FB_ReferenceCycle` → réel `FB_MachineHomingCycle` (renommage non propagé). |
| `AF-04 §3bis (1)(2)` | Facteurs cités en `VAR CONSTANT` `CST_*` — or dans `FB_DiveSearch` ils vivent dans le **DUT** `ST_fbDiveSearch_Config` (avec repli runtime) ; seul `FB_ExtractionAssist` porte des `CST_*`. |
| `GUIDE_SEQUENCEUR §7` | Note « ⚠️ chantier différé : ajouter `DiveStateAtError`/`ExtractionStateAtError` » — **déjà implémenté** (`StepAtFault` / `CycleStepAtError`). Note obsolète. |
| `FB_Cycle:26` | « 2=P2 » listé cible mais **non géré** (voir F-10). |

### F-08 · LOW / Coherence — Source de config divergente entre `FB_Cycle` et `FB_DiveSearch`
*(A-nouveau)*

- `PRG_03:225,234` (FB_Cycle) : `_CommunCfgPersist.LimitLegalDepthMinAllowed_M` / `_CommunCfgPersist.CfgCableLimitAscent_M`.
- `PRG_03:153-154` (FB_DiveSearch) : `GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M` / `GVL_IHM.Commun.Cfg.CfgCableLimitAscent_M`.

Les deux FBs calculent leurs protections sur la **même donnée métier** (limite légale / limite de course) via
**deux variables** (persist vs GVL_IHM). Si ces deux sources ne sont pas des miroirs strictement synchronisés,
l'un peut protéger avec une valeur différente de l'autre. À vérifier que `_CommunCfgPersist` est bien le miroir
persistant maintenu de `GVL_IHM.Commun.Cfg` (convention « Cfg + pont persistant ») — sinon risque de drift.

---

## 📐 Axe 2 — Conformité standards

### F-09 · MED / Standard — Références `T185` dans le code = violation §2ter « zéro REX »
*(A-nouveau)*

`FB_MachineHomingCycle.st` contient des références de ticket dans les commentaires :
`(* T185 C-1 : pas de redemarrage automatique ... *)` (`:174`), `(* T185 C-2 : ... *)` (`:201`),
`(* T185 C-4.3 : ... *)` (`:206`), `(* T185 C-4.1 : ... *)` (`:246`), et `(:12) T185 C-3`.

**Standard** : `CODE_QUALITY_STANDARDS §2ter` interdit le « journal intime / REX » dans le code ; la traçabilité
des décisions vit dans `DOC/` (VERSION_HISTORY, AF, TASKS.yaml). Les `T185` sont des **péripéties de
développement** hors du livrable. À retirer du code (le contenu des commentaires est **bien rédigé** et
explique le « pourquoi » → à conserver sans l'ID de ticket), traçabilité `T185` → `DOC/WFLOW/TASKS.yaml`.

### F-10 · LOW→MED / Standard — Interface `FB_Cycle` avec **entrées déclarées, câblées mais non consommées** (§4 « code mort »)
*(A-nouveau — non couvert par B)*

Grep sur le corps de `FB_Cycle.st` → entrées **jamais lues** (seule la déclaration apparaît) :

| Entrée | Rôle déclaré (`:26-62`) | Consommation |
|---|---|---|
| `SetDepthM` | `[CFG]` Profondeur de consigne (négative) | ❌ jamais utilisée — X4 calcule `RaiseTargetM` via `LimitLegalDepthM`+0,5, **sans** `SetDepthM`. |
| `SetOffsetM` | `[CFG]` Écart de fermeture benne cible | ❌ jamais utilisée. |
| `WinchSyncDeltaM` | `[HW]` Écart codeurs M1/M2 diagnostic | ❌ jamais utilisée (le corps fait `ABS(M1-M2)` localement). |
| `Translation_Busy` / `Translation_Done` | `[HW]` état translation | ❌ jamais utilisées (X2/X10 ne testent que `Translation_At_*`). |
| `Benne_Busy` | `[HW]` mouvement benne en cours | ❌ jamais utilisée (X3/X6 testent `Benne_Done/IsOpen/IsClosed`). |
| `TopPositionSensor` | `[HW]` capteur position haute | ❌ jamais utilisée (X1 teste `HomedM1/M2`, pas `TopPositionSensor`). |

Ces 7 entrées sont **câblées depuis `PRG_03` (`:221-247`)** pour rien → interface/du fil mort. Violation du §4
(« aucune variable non utilisée ») et de la checklist de restitution. En particulier `SetDepthM`/`SetOffsetM`
étant des **réglages CFG**, leur non-consommation est une **fonctionnalité morte** : la profondeur consigne n'est
effectivement pas appliquée (le cycle remonte à `TouchPositionM + 0.5` fixe). À **retirer de l'interface** ou
**honorer réellement**.

### ✅ Conformités standards confirmées (pas d'action)
- **R1–R9** (GUIDE_SEQUENCEUR) : `CASE` enum unique, labels `Xn - texte`, graphe **linéaire** (sauts = rejoint
  tronc, ex. X3/benne déjà ouverte), DONE_SYNC nommée (R4), `StepAtError` spécifique (R9), porte d'init §2 avec
  retour première étape (`:212-251`), TON par bloc (écart R5 « par transition » **acceptable** — see B#note).
- **POO §5** : producteur unique par donnée (FB_Cycle produit les `ST_Program*Request` ; FB_MachineHomingCycle
  producteur unique du datum machine, ne relit pas d'`ActiveOffsetValid` aval T185 C-3) ; composition (socle
  `FB_FaultCore`) ; internes privés.
- **NAMING** : `inst<Rôle>` conforme (`instCycleSemiAuto`, `instDiveSearch`, `instExtractionAssist`,
  `instMachineHomingCycle`) ; DUT `ST_fb<Fb>_<Rôle>` NC-110 conformes (`ST_fbDiveSearch_*`,
  `ST_fbMachineHomingCycle_*`) ; `E_*` enums nommés.
- **§9 Reset jamais conditionné** (FB_MachineHomingCycle) — le socle défaut est appelé **avant** la gate
  `NOT Enable` (`:212`), Reset non-conditionné, correct.

---

## 🎛️ Axe 4 — Ergonomie & robustesse du séquenceur

**Points notables** (convergence = B#5/B#6 + compléments) :

- **F-11 · MED / maintain** *(= B#5)* : le repli §4 neutra l'ensemble des actionneurs sur un **seul** permis
  (`ProcessPermitM1_Ascending`). Fonctionnellement équivalent aujourd'hui (tous les `ProcessPermit*` identiques)
  → robustesse : tester la **somme** des permis ou neutraliser chaque commande par son propre permis.
- **F-12 · LOW** *(= B#6)* : `SelTarget=2` (P2) **non géré** dans X2 (`:369` ne traite que `{1,3,4}`) → cul-de-sac →
  défaut `StepMaxTimer` non pertinent après 60 s. Retirer « 2=P2 » du commentaire d'interface (`:26`) et/ou le
  bloquer en amont.
- **Ergonomie générale** : lisible (régions `§1..§4`, enums clairs, `OperatorActionId/OperatorAction`,
  `WaitingForOperator/Process`, `ExpectedAxis/Direction`), bon **diagnostic IHM** conforme
  `ST_ChainCycleSemiAuto` (Idx209-216). ✅ Très satisfaisant.
- **F-13 · LOW / Robustesse** : homing semi-auto `X1` **redondant** avec `FB_MachineHomingCycle` (producteur
  unique du datum) et **transition X1→X2 sur `HomingRequest` (BtnHome) sans confirmation « homing terminé »**.
  En pratique SEMI_AUTO est gaté sur `MachineHomed` (donc X1 normalement court-circuité), mais la redondance et
  l'absence de confirmation de fin de homing méritent un commentaire explicite (le backstop est le
  `StepMaxTimer` 60s + sécurité top aval).
- **F-14 · Note** : `X9_DRAIN_PAUSE` — `DrainingTimer(IN:=TRUE)` continue de compter si le manche est relâché
  (seule la transition est gatée) → un relâchement/reprise peut « skipper » la durée d'égouttage perçue. **Mineur**
  (attente procédé sans mouvement). *(= B# note)*

---

## 🗺️ Impact safety consolidé & priorisation

| Priorité | Action | Obj. | Impact safety |
|---|---|---|---|
| **P1** | **F-01** : gater départ X0 sur `NOT Fault.Latched` (retirer le bypass `Abort`+`Start` d'un défaut latché). | `FB_Cycle:324` | ⛔ Élimine un **redémarrage après défaut non acquitté**. Obligatoire. |
| **P2** | **F-02** : rendre `WaitingResume` réel (reprise par `StartCycle` explicite, aligner AF-04 §4.1). | `FB_Cycle` | Affaiblissement « geste conscient » → rétabli. |
| **P3** | **F-05** : trancher la **polarité Kobold** `FB_Cycle` vs `FB_DiveSearch` (schéma électrique) sinon risque de détection de fond erronée. | câblage Kobold | ⚠️ Risque de transition X4→X5 prématurée à confirmer. |
| **P4** | **F-04** : justifier/corriger X8 (M2 sur limite haute) ; **F-10** : purger les 7 entrées FB_Cycle non consommées (dont CFG `SetDepth`/`SetOffset` morts). | `FB_Cycle` | Robustesse + honnêteté de l'interface. |
| **P5** | **F-06/F-07** : lot doc de renommage (`ExtractionAssist`) + purge sections AF périmées (AF-04 §2/3bis/4.2, AF-05 §4bis `FB_ReferenceCycle`, GUIDE_SEQ §7) ; **F-08** : aligner source de config persist/IHM. | `DOC/AF`, `DOC/STDS/GUIDES` | Cohérence doc↔code (traçabilité). |
| **P6** | **F-09** : retirer les `T185` du code (§2ter) ; **F-11/F-12/F-13/F-14** : dette maintenancedocumentée. | `FB_MachineHomingCycle`, `FB_Cycle` | Standard / lisibilité. |

> 🚫 **À NE PAS considérer comme défauts** (pour éviter tout alarmisme) : la « fenêtre 3 s » homme-mort de
> AF-04 §2 D2 est **descriptive** (armement = niveau `DeadmanArmed` re-évalué chaque scan, pas de timer 3s) —
> ne pas la signaler comme régression ; l'écart au « TON par transition » R5 (TON par bloc dans FB_Cycle) est
> **acceptable**.

---

## 📚 Points convergents vs `CYCLES_AUDIT_B`

Convergences totales sur les 4 points centraux : **F-01 (=B#1)**, **F-02 (=B#2)**, **F-03 (=B#3)**, **F-04 (=B#4)**,
et les points mineurs **F-11 (=B#5)**, **F-12 (=B#6)**, **F-07 (=B#7)**. 

Points **propres à l'audit A** (complémentaires au contre-audit) :
- **F-06** (drift de nom `FB_ExtractionAssist` dans toute la chaîne doc),
- **F-09** (références `T185` = §2ter zéro-REX),
- **F-10** (7 entrées `FB_Cycle` non consommées, dont CFG morts `SetDepth`/`SetOffset`),
- **F-05** (polarité Kobold contradictoire entre FB_Cycle et FB_DiveSearch — devoir d'alerte),
- **F-08** (sources de config persist/IHM divergentes).

La convergence sur les 2 points HIGH et les points MED renforce la fiabilité des conclusions.

---

📚 **Documents de référence** : `AF_Partie-04 v2.3` · `AF_Partie-05 v2.1` · `GUIDE_SEQUENCEUR v1.2` ·
`CODE_QUALITY_STANDARDS` (§2ter, §4, §5, §11bis) · `NAMING_CONVENTION` (NC-110, §instances).
Aucun `Device.export` utilisé — source de vérité = `CODE/*.st`.

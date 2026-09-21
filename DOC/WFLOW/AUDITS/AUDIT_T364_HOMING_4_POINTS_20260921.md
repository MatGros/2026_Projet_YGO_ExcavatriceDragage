# 🔎 AUDIT T364 — Cycle de homing machine `FB_CycleMachineHoming.st` (HX0→HXF) + 4 écarts machine réels

> **Tâche** : `DOC/WFLOW/TASKS.yaml:2-18` (T364, C1, parent T340, statut ⬜, agent `—`)
> **Brief** : `DOC/WFLOW/CONTRACTS/BRIEF_T364_URGENCE_HOMING_4_POINTS_MACHINE.md` (conservé tel quel)
> **Origine** : observation machine réelle 2026-09-21, 4 écarts relevés sur 2-3 étapes seulement.
> **Nature** : audit **read-only** — **AUCUNE ligne de `CODE/` écrite**, **AUCUN commit**, **AUCUN verrou pris**,
> **AUCUNE mise à jour de `TASKS.yaml`** (le statut T364 reste piloté par l'orchestrateur).

---

## 0 · Cadre de vérification (à lire avant tout verdict)

| Point | Valeur prouvée |
|---|---|
| Base de lecture | **arbre de travail** `CODE/G_CYCLE/FB_CycleMachineHoming.st` (876 lignes) — les numéros de ligne cités sont ceux **du disque** |
| HEAD dépôt | `276fc11e` (`feat(cycle,ihm): T358 - forcage de step a une valeur...`) |
| ⚠️ Fichier **modifié NON COMMITÉ** au moment de l'audit | lot **T362/DSH24** : 4 littéraux IHM contractés (`:794`, `:797`, `:800`, `:831`). `git diff -- CODE/G_CYCLE/FB_CycleMachineHoming.st` = **4 insertions / 4 suppressions**. Les points 1-2-4 du brief citent des lignes **post-T362** → cohérents avec le disque, **pas** avec `HEAD` |
| Verrou T364 | **absent** de `DOC/WFLOW/TASK_LOCKS.json` (aucune entrée T364 ; DSH24 = T362, DSH25 = T361) → aucun conflit d'acteur, aucune écriture concurrente de ma part |
| Contrainte de gate à ne pas oublier | **G408** (`TOOLS/AGENT_WORKFLOW/scripts/G408_check_ihm_message_length.py`) : plafond **70 car.** sur le message **assemblé** `CONCAT('Homing: ', MachineHomingInstruction)` (`CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:332`) → **tout littéral de `MachineHomingInstruction` doit rester ≤ 62 caractères** (8 + 62 = 70) |
| Méthode | lecture intégrale du FB + de ses producteurs/consommateurs (`PRG_02` → `PRG_03` → `PRG_04` → `PRG_06`), `FB_Bucket`, `FB_Safety_Winch`, `FB_WinchCmdArbitrationM1/M2`, `FB_Encoder_Homing`, `FB_FaultCore`, enums, AF-05/09/10, contrats T185/T233/T264/T340. Chiffres de longueur de message **mesurés** (PowerShell `.Length`) |

### Ce que l'audit n'a **pas** fait (transparence)
- ❌ aucun correctif, aucune proposition codée, aucun bundle, aucun gate lancé (aucune modification ⇒ rien à vérifier mécaniquement) ;
- ❌ `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` **non lu** (périmé par doctrine `AGENTS.md`) ;
- ❌ aucune décision d'architecture prise seul sur le point 3 (garde de sécurité mouvement).

---

## 1 · Synthèse — verdict global

**La confiance rompue est justifiée**, mais pas pour les raisons attendues : sur les **4 points remontés**, **1 n'est pas un bug** (doctrine), **2 sont des écarts réels**, **1 est réel mais mal formulé** — et l'audit exhaustif remonte **16 écarts supplémentaires non mentionnés** (§6, E1→E16), dont **2 de criticité sécurité (C1)** : E1 (aucun contrôle du couplage des treuils avant la montée de homing) et E2 (commit benne sans vérification de fermeture).

| # | Objet | Verdict |
|---|---|---|
| **P1** | HX1 exige MAINT_N2 | ✅ **NON CONFORME au ressenti, MAIS doctrine explicite validée** (T185 `APPROVED`, `validated_by: Utilisateur` 2026-08-30) — **et** un chemin N1 légitime existe (homing unitaire `BtnHome`). **Aucun code à écrire** |
| **P2** | Retirer les 3 appuis JOY à HX1 | 🛑 **REJET en l'état** — la demande littérale **casse 3 choses** (§3) : entrée HX7 (T340) pratiquement inatteignable, verrou M3 + perte de surveillance synchro **sans consentement opérateur**, 2 messages IHM deviennent du **code mort**. Contre-proposition §3.4 |
| **P3** | Benne utilisable hors homing sans FDC | ⚠️ **RISQUE RÉEL mais prémisse fausse** — la benne est manœuvrable (jog `WinchSel=2`) à **palier 1** ; ce qui est vrai c'est que **toutes les protections logicielles de position sont inertes** hors référencement (documenté `AF-10 §7.7`). La mécanique demandée (`WinchSel=2` forcé sous `NOT MachineHomed`) est **auto-destructrice** : elle **empêche le référencement**. Contre-proposition §4.5 |
| **P4** | Texte HX2 sans fermeture benne | ❌ **NON CONFORME** — `AF-09 v2.4:449` impose la **confirmation visuelle « benne fermée » AVANT tout mouvement**. 3 formulations chiffrées ≤ 62 car. proposées §5.4 |

**Carte des verdicts par étape (11 états réels, pas 8)** — `E_MachineHomingTxState` = `HX0, HX1, HX2, HX2N, HX3, HX3N, HX4, HX5, HX6, HXF, HX7` (`CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st:14-29`) :

| Étape | Texte IHM | Condition / geste | Verdict |
|---|---|---|---|
| HX0_REPOS | :843-859 | :543-546 | 🟠 SUSPECT (textes trompeurs) |
| HX1_CHOICE | :829-842 | :555-582 | ❌ NON CONFORME (doc contradictoire + P2) |
| HX2_CLIMB | :812 | :588-598 | ❌ NON CONFORME (P4 + absence de garde de couplage) |
| HX2N_NEUTRAL | :815 | :600-612 | 🟠 SUSPECT (latch neutre) |
| HX3_HOME_AXES | :818 | :614-632 | 🟠 SUSPECT (aucune attente de fin de preset) |
| HX3N_PAUSE | :821 | :634-644 | ✅ CONFORME |
| HX4_BUCKET_ADJUST | :824 | :646-661 | ❌ NON CONFORME (commit non vérifié) |
| HX5_BUCKET_COMMIT | :825-828 | :663-675 | ❌ NON CONFORME (préfixe « HX5 » pour HX6) |
| HX6_HOMED | :825-828 | :677-679 | ✅ CONFORME (code) |
| HX7_LOCKED_REFERENCE | :794-803 | :681-746 | ✅ CONFORME (le plus abouti du fichier) |
| HXF_FAILED | :786 | :748-750 | ❌ NON CONFORME (issue = Reset, non dite) |

Bilan : **3 CONFORME · 3 SUSPECT · 5 NON CONFORME**.

---

## 2 · Audit étape par étape (texte IHM ⇄ condition réelle ⇄ geste attendu)

### HX0_REPOS — `:530-549` / guide `:843-859` — 🟠 SUSPECT

| Élément | Preuve | Écart |
|---|---|---|
| Entrée en HX1 possible par **auto-armement** (300 ms) | `:291-295` `AutoArmCandidate := FirstScanDone AND NOT MachineHomed AND … AND MaintenanceActive`, `AutoArmTimer(PT := CST_ValidationHold = T#300ms)` (`:173`) | Le texte `:845` *« HX0 - RefHoming M1+M2 non ref - lancer (3 appuis JOY ou IHM) »* **ne dit pas que la machine se propose déjà toute seule** |
| L'entrée en HX1 exige **MaintenanceActive** | `:546` `AND MaintenanceActive` (`:207`) | En **MANU**, le geste annoncé (« 3 appuis JOY ») **ne fonctionne pas** — le texte est muet sur « passer en maintenance » |
| Textes `:848` / `:851` *« M1/M2 non ref - relancer le homing »* | `:846-851` | « relancer » est trompeur : l'auto-armement relance seul ; et la montée sera **couplée M1+M2** (`:589-590`) alors que le texte parle d'un seul axe |
| Verrou M3 | `:757-763` `CycleRunning` exclut HX0/HX1 → `M3Locked := CycleRunning` | ✅ conforme au commentaire `:759-762` (pas de verrou en HX1) |

### HX1_CHOICE — `:551-584` / guide `:829-842` — ❌ NON CONFORME

| Élément | Preuve | Verdict |
|---|---|---|
| Retour HX0 si datum redevient valide / sortie maintenance | `:555` | ✅ conforme |
| Entrée dans l'étape de choix = `BootReady AND ExplicitValidationPulse AND ModeIsMaint2` | `:557` | ⚠️ **P1 + P2** |
| Consommation de la confirmation benne **à l'instant exact de la sortie** | `:560-576` `IF BucketCloseConfirmedLatched AND NOT TopPositionSensor → HX7` | 🛑 **conflit temporel majeur avec P2** (§3.2) |
| Le **bouton IHM « Lancer »** (`StartRequest`) n'a **aucun effet** sur une machine pleinement référencée | `:543-546` (StartEdge accepté) → `:555` (`IF MachineHomed … THEN SeqStep := HX0`) : HX1 voit `MachineHomed=TRUE` et **revient immédiatement en HX0** | 🟠 **contredit le commentaire `:535-538`** (« seul le bouton IHM dedie (StartEdge) peut RE-referencer une machine deja homed ») ; et l'opérateur **ne voit aucun message** (`:804-809` : `MachineHomed AND NOT CycleRunning` → `Instruction := ''`) ⇒ **bouton sans effet, sans retour IHM** |
| ⚠️ Doctrine documentaire | `TASK_CONTRACT_T233_IMPL_GRAFCET_HOMING_MACHINE.yaml:29` : *« ET seulement si TxState=HX0_REPOS ET **Mode=MAINT_N2**. Hors N2, aucune entree en cycle »* — or le code accepte **N1 ou N2** (`:207`, `:546`) | ⚠️ **contrat obsolète** vs code ; de plus ce contrat est `status: PENDING`, `validated_by: ""` (`:117`, `:128-129`) : une garde de production adossée à une spec jamais validée |
| ⚠️ Doctrine documentaire (à jour) | `TASK_CONTRACT_T264_HOMING_BOOT_GUARD.yaml:8` : *« HX1 reste une étape informative et le référencement mouvement reste réservé à MAINT_N2 »* | ✅ adossement correct de la garde N2 |

### HX2_CLIMB — `:586-598` / guide `:812` — ❌ NON CONFORME

| Élément | Preuve | Verdict |
|---|---|---|
| Geste réel = `ClimbPermit := DeadmanArmed AND JoystickPull` | `:237`, action `:588-591` | ✅ texte *« Tirer JOY palier 1 »* globalement juste |
| **Aucune vérification que les 2 treuils montent** : `ClimbPermit` **ne lit aucun sélecteur** (le FB n'a même pas d'entrée `WinchSel`) | `:237` ; grep `WinchSel|JoystickWinchSelect` dans le FB = **0 occurrence** | 🛑 **ÉCART C1 hors brief** (§6-E1) : en `WinchSel=1/2`, un seul treuil bouge alors que le cycle croit une montée couplée, et le **capteur haut est commun M1/M2** (`PRG_02:555` `M1M2_TopPositionFree_DI`) ⇒ risque de **datum faux** |
| « FDC haut » vs « capteur haut » | `:812`, `:841` vs `:797`, `:800`, `E_MachineHomingStep.st:16` | 🟡 terminologie incohérente dans le même bandeau |
| Texte ne mentionne **pas** la fermeture benne | `:812` vs `AF_Partie-09_Fonction_Encoder_v2.4.md:449` *« 1. Confirmation visuelle benne fermée (opérateur, **avant tout mouvement**) »* | ❌ **P4** |

### HX2N_NEUTRAL — `:600-612` / guide `:815` — 🟠 SUSPECT

| Élément | Preuve | Verdict |
|---|---|---|
| Transition = `WinchesMechanicallyStopped AND SeenNeutral AND DescendPermit AND TopPositionSensor` | `:608-609` | ✅ conforme au geste annoncé (neutre puis poussée) |
| `SeenNeutral` est un **latch jamais remis à FALSE** dans HX2N/HX3N | `:602-604`, `:636-638` (aucune remise à FALSE) | 🟠 un **re-tirage** entre le neutre et la poussée n'est pas détecté ; seule la grâce de 3 s le rattrape (`SettleGraceTimer` `:246-250` + `MotionOutOfPhase` `:254-255`) |
| Voir aussi | `CODE_QUALITY_STANDARDS` : un latch de « vu neutre » est admis, mais l'intention affichée (« mouvement nul obligatoire ») n'est **pas** vérifiée au scan de transition | 🟠 |

### HX3_HOME_AXES — `:614-632` / guide `:818` — 🟠 SUSPECT

| Élément | Preuve | Verdict |
|---|---|---|
| Geste annoncé = pousser JOY, homing au vol sur front descendant | `:616-625` (`TopLostEdge.Q` → `M1/M2Demand.HomeReq`) | ✅ texte conforme |
| **Aucune attente de fin de transaction preset** avant la suite | `HomingBusy`/`HomingDone` **déclarés** (`ST_fbMachineHomingCycle_AxisHomingStatus.st:11-12`), **alimentés** (`PRG_02:512-513`, `:516-517`)… et **jamais lus** dans le FB (grep = 0 lecture) | 🟠 **interface morte** (§6-E6) ; risque borné en pratique par `CST_PresetVerifyTime = T#50MS` (`FB_Encoder_Homing.st:110`) |
| Sortie dès `NOT TopPositionSensor AND both homed` | `:629` | 🟠 en **re-référencement d'une machine déjà homed**, `Homed` ne retombe pas pendant la transaction (`FB_Encoder_Homing.st:290` `Homed := Calib.Homed AND NOT Calib.HomingSuspect`, `Calib.Homed` non effacé avant confirmation) ⇒ sortie de HX3 **au scan suivant le front**, avant confirmation du nouveau datum |

### HX3N_PAUSE — `:634-644` / guide `:821` — ✅ CONFORME
Transition `WinchesMechanicallyStopped AND SeenNeutral` (`:642`), texte *« JOY au neutre (arret avant benne) »* — cohérent. Aucun écart relevé.

### HX4_BUCKET_ADJUST — `:646-661` / guide `:824` — ❌ NON CONFORME

| Élément | Preuve | Verdict |
|---|---|---|
| Texte : *« Fermer benne puis valider (3 appuis JOY) »* | `:824` | — |
| Condition de sortie : `ExplicitValidationPulse AND NOT JoystickDeflected AND WinchesMechanicallyStopped` | `:657` | 🛑 **la fermeture de la benne n'est JAMAIS vérifiée** : grep `IsClosed|IsOpen|BucketOpening` dans le FB = **0 occurrence** (le FB ne reçoit que `BucketOffsetValid`) ⇒ un opérateur peut valider **benne ouverte** |
| Conséquence : `PendingClose := TRUE` inconditionnel puis `BucketCommit.CommitClose` | `:658-660`, `:669` → `FB_Bucket.st:375-380` force `BucketState.IsClosed := TRUE` **et** mémorise `LastPosM2Close := CablePosM2` (position courante, quelle qu'elle soit) | 🛑 **écart C1 hors brief** (§6-E2) : déclaration « benne fermée » **fausse** + référence de fermeture erronée ; la classification continue corrigera `IsClosed` au scan suivant si le datum est bon (`FB_Bucket.st:437-450`) mais **`BucketReferenced` reste latche** (`:403-407`) |
| 🛑 **La consigne `:824` est inexploitable telle quelle** : la fermeture benne n'atteint M2 **que si le sélecteur est sur le treuil benne (`WinchSel=2`)** | L'ordre du cycle (`CmdBucketClose` → `PRG_03:449-453` → `ReqBucket.ReqClose` → `FB_BucketCmdArbitration.st:66-67` `CmdClose_IHM := TRUE`) n'agit sur M2 que par la **voie override benne**, qui exige `Context.BucketBusy AND Context.BucketM2RunRequest AND (Select = 2 OR Mode = SEMI_AUTO)` (`FB_WinchCmdArbitrationM2.st:65-67`) — or HX4 tourne en **MAINT_N2** (jamais SEMI_AUTO) ⇒ **seul `WinchSel=2` rend la consigne exécutable** ; en `WinchSel=0`, M2 suit l'intention **couplée** (`:123-127`) et la benne **ne se ferme pas** (c'est le risque de désynchro « quasi-casse machine » du REX MES 2026-09-04, documenté `:59-64`) | ❌ **NON CONFORME** : le texte `:824` ne dit **jamais** de sélectionner le treuil benne (voir P4, variante C) |
| « palier 1 » annoncé mais **non tenu** à HX4 | commentaire `:647` *« Benne palier 1 SANS FDC soft »* ; or le plafond réel vient du joystick/config : `PRG_04:1325-1326` (≤ `MaxStepUp` = **2** en fermeture, `MaxStepDown` = **4** en ouverture — `ST_fbBucket_Config.st:15-16`) et `PRG_04:525-526` ; palier 1 **seulement** dans la zone de ralentissement (`PRG_04:1327-1332`, `JogSlowdownZoneM = 1.0`) ; et en N2 les deux axes **sont** homologués `Homed` à HX4 ⇒ le bridage « hors référencement » (`PRG_04:1236-1246`) ne s'applique **pas** | 🟠 SUSPECT — voir **E16** |

### HX5_BUCKET_COMMIT — `:663-675` / guide `:825-828` — ❌ NON CONFORME (mineur)
- Commit atomique correct (`:668-671`), abort correct (`:665`).
- ❌ **le guide affiche `'HX5 - …'` alors que l'étape courante est HX6** (`:825-826` couvre `HX5 OR HX6`) → l'opérateur voit « HX5 » à l'étape HX6. Correction triviale, **mais à ne pas oublier lors du lot texte**.

### HX6_HOMED — `:677-679` — ✅ CONFORME (code) · texte : voir HX5.

### HX7_LOCKED_REFERENCE — `:681-746` / guide `:790-803` — ✅ CONFORME
Étape la plus aboutie du fichier : verrou de mode tenu sans mouvement (`:697-703`), descente interdite (`:692-696`), garde de montée keyée sur l'ordre **réellement** émis (`:217`, `:258-261`), capture conditionnée à `LockedSettleActive AND WinchesMechanicallyStopped AND SeenNeutral` (`:735`), documentation honnête de l'inertie des ordres en MAINT_N2 (`:714-721`). **Aucun écart de cohérence texte/condition relevé.**
⚠️ Seule réserve : **atteignabilité** — voir §3.2 (P2).

### HXF_FAILED — `:748-750` / guide `:784-786` — ❌ NON CONFORME
- Sortie **uniquement** sur front `Reset` (`:748-750` : corps vide + purge `§4` `:367-382`).
- ❌ Le texte `:786` *« HXF - Homing incomplet - Recommencer en N2 »* **ne dit pas qu'il faut acquitter (Reset)** ⇒ opérateur bloqué sans issue annoncée. Formulation proposée §5.4-D.
- ⚠️ **Ce texte n'est atteignable que si aucune cause latchante n'est active** : toute cause latchante (`ClimbTimedOut` `:438-440`, `AxisHomingError` `:446-452`, `MotionOutOfPhase` `:442-444`, `HomeAxesTimedOut` `:454-456`, `LockedDescentRefused` `:458-460`) fait gagner la branche `:781-783` (« Acquitter (Reset) »). Seuls `ModeLostDuringCycle` (`:266`) et `NOT BothAxesHomed` en HX5 (`:665`) laissent passer le texte HXF. **À assumer explicitement** (aujourd'hui non documenté).

### Branche morte dans l'échelle de guide — ❌ NON CONFORME (nettoyage)
`:787-789` (`MachineHomingStep := LOSS_SAFESTOP` / *« Reference perdue - Arret controle »*) est **inatteignable** : `HomingLossLatched OR ReHomingAckRequired` alimente la cause 0 **latchante** (`:434-436`), `FB_FaultCore.st:63-69` latch dans le **même scan** ⇒ `Fault.Latched` TRUE ⇒ la branche `:781-783` gagne **toujours**. L'état `E_MachineHomingStep.LOSS_SAFESTOP` n'est donc **jamais publié** (§6-E10).

---

## 3 · POINT 2 — retrait de `ExplicitValidationPulse` à HX1 : 🛑 rejet en l'état, contre-proposition

### 3.1 État réel du geste (preuve)
- Condition : `:557` `ELSIF BootReady AND ExplicitValidationPulse AND ModeIsMaint2 THEN`
- Motif 3 appuis : `:297-328` ; définition `ExplicitValidationPulse` : `:124` (déclaration), `:196` (RAZ tête de scan), `:325-327` (impulsion 1 scan quand `ValidationPressCount >= 3`)
- **3 usages distincts**, un seul est visé : `:544` (HX0→HX1, lancement), **`:557` (HX1→choix)**, `:657` (HX4→HX5, validation benne). ⇒ retirer `:557` **n'affaiblit pas** `:544` ni `:657` : le motif « 3 appuis » **reste** utilisé ailleurs de façon critique (validation du commit benne). L'action du brief est donc techniquement locale, **mais** :

### 3.2 Ce que la demande littérale casse (3 effets prouvés)

**🛑 Effet 1 — l'entrée de l'étape verrouillée HX7 (livrée par T340) devient pratiquement inatteignable.**
- HX7 n'est atteignable que par `:560-569` : `IF BucketCloseConfirmedLatched AND NOT TopPositionSensor`.
- La confirmation est consommée **à l'instant exact où HX1 décide de sortir** ; `BucketCloseConfirmedLatched` est un latch purgé sur Reset **ou** sortie de maintenance (`§4ter` `:424-429`), et le front qui le pose **est le même** que la demande de preset M2 (`PRG_02:526-530`, `:576`).
- Aujourd'hui, HX1 **attend** : l'opérateur appuie le bouton N2 dédié (confirmation visuelle + preset M2) **puis** fait ses 3 appuis → HX7.
- Avec le retrait, l'entrée en HX1 (`:543-548`) est **immédiatement suivie** de la sortie au **même scan utile** (`:557` ne dépend plus d'un front opérateur) ⇒ **HX1 ne dure plus qu'un scan** et n'est plus affiché (le guide §10 lit `SeqStep` **après** le CASE). L'opérateur ne peut donc plus « préparer » HX7 : il faudrait appuyer la confirmation **avant** l'auto-armement (fenêtre `CST_ValidationHold = T#300ms`, `:173`, `:295`) — et un `Reset` purge le latch (`:427`) tout en relançant l'auto-armement.
- Bilan : **la voie « référencement à l'arrêt » (Plan B T340) devient résiduelle**, alors que c'est le chemin le plus sûr (franchissement réel prouvé, `:561-565`).

**🛑 Effet 2 — entrée dans une phase de MOUVEMENT sans consentement opérateur, avec 2 conséquences aval.**
- HX2 est une phase mouvement : `IsInMovePhase` `:224-226`, `CycleRunning` `:757-758`, `Lifecycle.Busy`/`MachineHomingActive` `:764-765`, `M3Locked := CycleRunning` `:763`.
- Conséquence A : **`M3Locked` verrouille la translation M3 sans bypass** — `PRG_05_Translation.st:508-513` (`M3_SafeStop_Aggregate := … OR PRG_02_Acquisition.Data.MachineHoming.M3Locked`, commentaire « Pas de bypass : conscient = quitter le cycle »). Sur une machine non référencée en MAINT_N2, le simple fait d'être en N2 **interdirait la translation** sans qu'aucun geste n'ait été fait.
- Conséquence B : **la surveillance d'écart M1/M2 est coupée** — `PRG_04_Treuils_Benne.st:426-427` `SyncOperationPermit := … AND NOT PRG_02_Acquisition.Data.MachineHoming.Active …` → consommée par `instWinchSync.Enable` (`:634`) **et** `CrossCheckEnable` (`:936`, `:1006`, → MecaE croisé) : `PRG_04:402-416`. Le cycle « actif » coupe ces surveillances **par conception** ; les couper automatiquement, sans geste, élargit la fenêtre où elles sont inactives.
- Nuance honnête : **aucun mouvement automatique** n'est créé — HX2 n'émet ses ordres que sous `ClimbPermit` (`:237`, `:588-591`) et, en MAINT_N2, ces ordres sont **inertes** (§6-E7) : le mouvement réel vient du joystick. Le risque est donc **de contexte et de verrouillage**, pas de mouvement fantôme.

**🛑 Effet 3 — 2 messages IHM deviennent du code mort.**
- `:838` *« HX1 - RefHoming Valider (3 appuis JOY) pour lancer »* et `:841` *« HX1 - RefHoming Sur FDC haut - valider (3 appuis JOY) »* ne sont affichés que si `SeqStep` vaut **encore** HX1 après le CASE — impossible en MAINT_N2 après le retrait (seule une sortie en N1 ou `NOT BootReady` maintient HX1 → `:831`/`:835` restent atteignables).
- ⇒ le lot P2 **doit** inclure la réécriture du guide HX1, sinon l'IHM affichera une consigne obsolète 0 scan (donc **jamais**).

### 3.3 Ce que la demande vise légitimement (à préserver)
Le grief de fond est **valide** : aujourd'hui, sur une machine non référencée en MAINT_N2, la machine **s'auto-arme** en HX1 (`:291-295`) et **exige un geste supplémentaire** (3 appuis **ou** IHM `BtnStart`) pour agir. L'opérateur perçoit une redondance de gestes. **Mais** ce geste est **le seul consentement explicite** à l'entrée en phase mouvement (verrou M3 + cycle actif + HX7).

### 3.4 Contre-propositions (à trancher, aucune codée)

| Option | Mécanique | Avantages | Risques / coût |
|---|---|---|---|
| **2-A (recommandée)** | **Conserver `:557` tel quel** et corriger l'IHM : afficher **un seul** geste demandé, avec la raison (`:838`/`:841` déjà explicites). Traiter le grief par l'**auto-armement** : le rendre **annoncé** (message HX1 explicite « confirmer par 3 appuis pour lancer le référencement ») plutôt que silencieux | zéro risque sécurité ; conserve HX7, M3, synchro ; très petit lot texte | ne supprime pas le geste (mais documente pourquoi) |
| **2-B** | Retirer `ExplicitValidationPulse` de `:557` **mais** remplacer le consentement par **`StartEdge`** (`BtnStart` IHM, front) : `ELSIF BootReady AND (ExplicitValidationPulse OR StartEdge.Q) AND ModeIsMaint2` | supprime la redondance joystick, garde un consentement explicite, HX7 encore atteignable **si** la confirmation benne est donnée avant | HX1 reste 1 scan ⇒ **HX7 reste difficile** ; exige de revoir §4ter (fenêtre de confirmation) |
| **2-C** | Retirer `:557` **et** déplacer la consommation de `BucketCloseConfirmedLatched` **hors de HX1** (ex. à l'entrée de HX2 : si confirmation présente → HX7) | rend HX7 de nouveau praticable sans le geste HX1 | touche le GRAFCET de l'étape verrouillée (T340) ⇒ **revue C1 obligatoire**, tests TC-P09-H2xx à rejouer |
| **2-D (rejetée telle quelle)** | Demande littérale (`BootReady AND ModeIsMaint2`) | — | effets 1-2-3 ci-dessus |

**Recommandation** : **2-A** pour l'immédiat (zéro risque, traite le grief de lisibilité), **2-C** si l'exploitant confirme qu'il veut **zéro geste** — mais alors C1 + contrat + tests obligatoires.

---

## 4 · POINT 3 — Benne hors homing : ⚠️ risque réel, prémisse fausse, mécanique demandée à rejeter

### 4.1 La benne est-elle manœuvrable hors homing ? **OUI — par le jog M2 `WinchSel=2` en MAINT**
| Maillon | Preuve | Condition exacte |
|---|---|---|
| `ManualBucketJogActive` | `PRG_04:305-306` | `(Auth.JoystickWinchSelectArbitrated = 2) AND (Mode = MAINT_N1 OR MAINT_N2)` |
| Jog M2 par joystick | `FB_WinchCmdArbitrationM2.st:117-122` | `IF Auth.JoystickWinchSelectArbitrated = 2 THEN ReqAscent := AxisY.Direction > 0; ReqDescend := …< 0` |
| Commande | `FB_WinchCmdArbitrationM2.st:143-151` | `RunRequest := (ReqAscent OR ReqDescend) AND … AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed) …` → **aucun terme `Homed`, aucun terme benne** |
| Exécution | `PRG_04:564-567` → `:1473-1476` → `instWinchM2` `:1523-1536` → `PRG_06` → `%Q` | — |

### 4.2 « Sans qu'aucune restriction ne s'applique » ? **FAUX — 4 restrictions restent actives**
| Restriction | Preuve | Effet |
|---|---|---|
| Plafond **palier 1** dès qu'un codeur n'est pas `HomedAndReliable` | `PRG_04:1236-1246` (`CommonMaxStepAscent/Descent := 1`), posture **ISO 13849** documentée `AF-10 v2.1:594-604` (§7.7) | vitesse minimale, mouvement maîtrisable à vue |
| Plafond palier 1 du jog benne M2 | `PRG_04:1320-1323` | idem, spécifique jog |
| **FDC haut PHYSIQUE** (capteur commun) | `FB_Safety_Winch.st:574-577` (`NOT TopPositionSensor AND NOT InReferencingMode`), non bypassable par cette voie | barrière dure indépendante |
| Les **boutons IHM benne** ne font rien hors référencement | `PRG_04:1118-1127` `EffectivePermitBucket_Open/Close := … AND EncoderM1.Homed AND EncoderM2.Homed …` + cause 4 `FB_Bucket.st:283-288` → `SevereError` `:423`, `:462-470` | le chemin « commande benne » est verrouillé, **seul le jog manuel reste** |

### 4.3 Le fond du constat est **VRAI et grave** : toutes les protections logicielles de position sont inertes
- **Documenté** : `AF_Partie-10_Fonction_Winch_v2.1.md:596-600` — *« tant que M1 **et** M2 ne sont pas `HomedAndReliable`, `CablePosM` est potentiellement faux et **toutes les protections logicielles de position sont inertes** (FDC haut logiciel, limite câble, limite légale, ralentissements bordure) »*.
- **Prouvé dans le code** : `ClassCanRun := HomedM1 AND HomedM2 AND NOT SevereError` (`FB_Bucket.st:430-431`) ⇒ classification benne (`:437-457`), **limite de recul** (`:587-591`), **arrêt de fermeture par seuil** (`:612-614`, `:625`) et **dépassement d'écart max** (`:204-209`) sont **tous** neutralisés.
- ⚠️ **Asymétrie de sécurité à connaître** : `FB_Safety_Winch.st:581` gate la butée haute **logicielle** par `Homed AND NOT HomingSuspect …` ⇒ **sans datum, cette barrière DISPARAÎT** (fail-open), alors que la limite câble de descente `:563-565` n'exige **pas** `Homed` (fail-closed apparent). Un défaut de référencement **lève** donc une barrière logicielle au lieu de la durcir. `HomingSuspect`/`Homed` sont bien propagés (`PRG_04:956-957`), le constat est donc bien dans le chemin réel.
- ⚠️ Nuance capitale sur les « FDC benne » : **il n'existe aucun FDC benne matériel** (aucune entrée `_DI` de fin de course benne dans `CODE/`). Les « FDC benne » **sont** les bornes géométriques logicielles sur `DeltaPosition_M = CablePosM2 − CablePosM1` (`GVL_PERSISTENT` : `OffsetOpenM=0.0`, `OffsetCloseM≈15.0`, `CoherenceLimitM=1.0` ; `ST_fbBucket_Config` : `CloseAnticipationM`, `OpenAnticipationM`, `JogSlowdownZoneM`). « Désactiver les FDC benne » ⇒ **retirer le seul filet de course existant**.
- ⚠️ **Le seul garde-fou « mouvement benne sans référence » est à trois trous** : `HomingMotionWithoutReference` (cause 4, `FB_Bucket.st:283-288`) est un défaut **LIVE non latché** (`:287`), il est **(a)** neutralisable par un seul bit IHM (`BypassGlobal`, `:181`), **(b)** **désarmé pendant le cycle de homing** (`AND NOT MachineHomingActive`, `:284`) — donc inactif en HX2→HX6, précisément quand la machine n'est pas encore référencée, et **(c)** **inexistant pour le jog M2 par joystick** (`FB_WinchCmdArbitrationM2.st:117-122`), qui ne traverse jamais `FB_Bucket`. C'est **ce chemin-là** que l'exploitant décrit.

### 4.4 `FB_Bucket.MachineHomed` : **entrée MORTE** (prouvé)
- Déclarée `FB_Bucket.st:25`, **câblée** `PRG_04:378`… et **jamais lue** : grep sur les 838 lignes = **1 seule occurrence (la déclaration)**. Absente de la doc `AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md` et des tests CI.
- Conséquence : l'état « M1/M2 référencés **mais** référence benne perdue » (`MachineHomed=FALSE`, `HomedM1=HomedM2=TRUE`) est **invisible** pour `FB_Bucket`. Le FB utilise `HomedM1/HomedM2` et `MachineHomingActive`, jamais l'agrégat.
⇒ Toute mécanique fondée sur `MachineHomed` **côté `FB_Bucket`** exige d'abord de **rendre cette entrée effective** (ou de la retirer proprement) — sinon on ajoute une garde sur un fil déjà coupé.

### 4.5 La mécanique demandée (`WinchSel=2` forcé sous `NOT MachineHomed`) est **auto-destructrice**
| # | Effet | Preuve |
|---|---|---|
| 🔴 1 | **Le référencement devient impossible** : avec le sélecteur arbitré à **2**, `M1` ne reçoit plus **aucune** commande joystick (`FB_WinchCmdArbitrationM1.st:88-103` : `Select=1` → M1 ; `ELSIF BothIntent.Active` → both ; **`ELSE` → `ReqAscent/ReqDescend := FALSE`) ; or `BothIntent.Active := WinchBothMotionActive` (`PRG_03:318`) qui **exige `Select = 0`** (`PRG_03:142-144`) | Le cycle homing monte **les deux** treuils (`:589-590`, `:724-725`) et le mouvement réel vient du **joystick** (`:714-721`) ⇒ plus de montée couplée ⇒ `MachineHomed` reste FALSE ⇒ **le forçage reste actif** ⇒ **verrou définitif** (seul secours : mode Boutons `TglJoystickMaster=FALSE`, `PRG_03:146-153`) |
| 🔴 2 | **`SyncOperationPermit` tombe** ⇒ surveillance d'écart M1/M2, concordance contacteurs et **MecaE croisé** coupées | `PRG_04:426-427` → `:634`, `:936`, `:1006` |
| 🟠 3 | **Pilotage couplé de dégagement supprimé** en MAINT | `PRG_03:142-144` ; procédure `TASKS.yaml:826` |
| 🟠 4 | `T248BucketJogActive` devient TRUE en phase couplée (or `FB_Modes` **force** `Select=0` en phase couplée) ⇒ limites `CoherenceLimitM` appliquées à tort | `PRG_04:778-779`, `:788`, `:799` vs `FB_Modes.st:388-393` |
| 🟠 5 | `WinchSelTransitionHold` (1,2 s) à chaque flapp de `MachineHomed` ⇒ arrêts M1/M2 répétés | `FB_Modes.st:407-410`, `CST_T248TransitionSettle = T#1s200ms` (`FB_Modes.st:117`) → `PRG_04:572-575` |
| 🟠 6 | Checklist de homing M1 faussée (« non sélectionné » pendant tout le référencement) | `FB_TroubleshootingView.st:432`, `:458` |
| ⚠️ 7 | **Piège de formulation** : `NOT MachineHomed` est **vrai pendant TOUT le cycle** (le datum n'est posé qu'en `MachineHomed` `:771-773`, donc après HX5/HX6). Une garde keyée sur `NOT MachineHomed` seul **reste active en HX2/HX3** ⇒ même en excluant « hors cycle homing » par `NOT MachineHomingActive`, le forçage se réactive dès que le cycle s'arrête… sans référence obtenue | `:771-773` vs `:757-765` |

### 4.6 Contre-propositions (aucune codée)

| Option | Mécanique | Remarque |
|---|---|---|
| **3-A (recommandée, minimaliste)** | **Ne rien forcer.** Reconnaître que le jog `WinchSel=2` en MAINT est **déjà** le mode « fermeture à vue » voulu, et **corriger la seule anomalie réelle** : rendre la garde `TopLimitM2_M` du jog **qualifiée** (aujourd'hui `PRG_04:899-901` `TopLimitM2_M := M1.CablePosM + OffsetCloseM + 2.0` calcule sur des positions **non référencées** ⇒ borne arbitraire) + afficher un **message IHM explicite** « hors référencement : benne à vue, palier 1 » | zéro impact sécurité, zéro risque de verrou ; traite le « pas logique » ressenti par la lisibilité |
| **3-B** | Forçage `WinchSel := 2` **uniquement** en MAINT **et** hors cycle **et** avec un chemin de sortie garanti : `(NOT MachineHomed) AND NOT MachineHomingActive AND NOT MachineHomingFailed AND …` + **bypass opérateur** obligatoire pour reprendre le couplé et pouvoir se référencer. ⚠️ **Précédent existant à copier** : `FB_Modes.st:372-374` force déjà `JoystickWinchSelectArbitrated := 2` à la Trémie (`M3AtTremie AND NOT AllowWinchMoveAtTremie`) **avec une échappatoire consciente** (`AllowWinchMoveAtTremie`, bit IHM `T249`) — c'est **exactement** le patron à reproduire (forçage + porte de sortie explicite), et il est déjà éprouvé en exploitation | À instruire en **contrat C1** ; ne pas coder sans revue de sécurité (touche `FB_Modes` + `PRG_03`) |
| **3-C** | Traiter la **cause racine** : rendre effectif `FB_Bucket.MachineHomed` (entrée morte) et **durcir** au lieu d'assouplir : hors référencement, **interdire** la manœuvre benne **sauf** jog `WinchSel=2` explicitement sélectionné (conscient), au lieu de laisser un jog à limite non qualifiée | plus robuste, mais change une doctrine MES (T146/§7.7) ⇒ décision humaine |
| 🛑 **3-D** | Demande littérale (`WinchSel=2` sous `NOT MachineHomed`) | **rejetée** : effets 1-2 ci-dessus + piège 7 |

**Question bloquante pour l'exploitant** : quel est le besoin réel ? (a) *« je veux pouvoir fermer la benne à l'œil avant de référencer »* → **3-A** suffit (le jog existe déjà) ; (b) *« je veux que la benne soit TOUJOURS sélectionnée quand la machine n'est pas référencée »* → **3-B** avec bypass obligatoire.

---

## 5 · POINT 4 — texte HX2 / fermeture benne : ❌ NON CONFORME

### 5.1 Preuve de l'écart (doc, pas opinion)
`DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md:447-453` — **« Procédure terrain (nominal, benne fermée) : 1. Confirmation visuelle benne fermée (opérateur, avant tout mouvement) — tant que M1/M2 ne sont pas référencés, `CablePosM` est potentiellement faux, aucun interlock position n'est fiable. »**
⇒ La spec met la confirmation **avant** la montée ; le guide ne la mentionne qu'à **HX4** (`:824`), soit **après** la montée (HX2) et le homing (HX3). **Écart texte/spec.**

### 5.2 Où la séquence manipule réellement la benne
| Étape | Geste benne | Preuve |
|---|---|---|
| HX1 (option verrouillée) | confirmation visuelle benne fermée **+ bouton N2 dédié** (preset M2) | `:560-569`, `PRG_02:526-530`, `:576` |
| HX2 / HX3 | **montée couplée puis descente — benne non mentionnée** | `:588-591`, `:616-618` |
| HX4 | fermeture (ou ouverture) benne **par jog benne — `WinchSel=2` obligatoire**, puis 3 appuis | `:646-652`, `:657`, `FB_WinchCmdArbitrationM2.st:65-67` |
| HX5 | commit — **sans vérification de fermeture** (cf. §6-E2) | `:663-671` |

### 5.3 Nuance à faire trancher (ne pas décider seul)
La confirmation **consommée** par le GRAFCET est celle du **bouton N2 dédié** (`BucketCloseConfirmed`, `PRG_02:576`) — elle **route** vers HX7. Il y a donc **deux** lectures possibles :
1. **la confirmation doit venir AVANT tout mouvement** (lecture AF-09:449) ⇒ HX2 doit la rappeler, et le chemin HX2/HX3/HX4 devient un chemin « sans confirmation préalable » **assumé** (l'opérateur fermera à HX4) ;
2. **HX4 est le bon endroit** pour le geste, et HX2 ne doit porter qu'un **rappel** (« benne fermée ? ») — mais alors il faut l'écrire dans l'AF, sinon la doc reste contredite.

### 5.4 Formulations proposées (longueurs **mesurées**, plafond G408 = **62 car.**)

| Réf | Texte proposé | Long. | Emplacement | Effet |
|---|---|---|---|---|
| **A** | `HX2 - RefHoming Benne fermee puis tirer JOY, capteur haut` | **57** | remplace `:812` | rappel **intégré** à la consigne HX2 (le plus simple, 1 ligne) |
| **B** | `HX1 - RefHoming Benne fermee AVANT de monter (JOY palier 1)` | **59** | remplace `:838` **ou** `:841` | porte la confirmation **avant tout mouvement** (conforme AF-09:449) — cohérent avec l'option **2-A** |
| **C** | `HX2 - RefHoming Benne fermee, valider BP benne, tirer JOY` | **57** | remplace `:812` | variante « chemin HX7 » : nomme le **bouton benne** (prérequis du plan B T340) |
| **D** (bonus, corrige §2/HXF) | `HXF - Homing incomplet - Acquitter (Reset) puis N2` | **50** | remplace `:786` | rend l'issue **Reset** explicite |
| **E** (bonus) | `HX2 - RefHoming Tirer JOY palier 1 vers FDC haut` (**actuel**, 48) | 48 | `:812` | référence — **ne mentionne pas** la benne |

📌 **Toute** modification de ces littéraux doit être rejouée contre **G408** (`run_all_gates.py --palier C`), le plafond portant sur le message **assemblé** `Homing: <littéral>` (`FB_Hmi_BannerFormatter.st:332`).

---

## 6 · Écarts découverts hors brief (le vrai apport de l'audit)

| # | Écart | Gravité | Preuves |
|---|---|---|---|
| **E1** | **HX2/HX3 ne vérifient jamais que le sélecteur est COUPLÉ.** `ClimbPermit := DeadmanArmed AND JoystickPull` (`:237`) — le FB n'a **même pas d'entrée** `WinchSel`. En MAINT_N2 avec `WinchSel=1/2`, un seul treuil bouge (`FB_WinchCmdArbitrationM1.st:90-103`, `M2:117-122`) alors que le **capteur haut est commun M1/M2** (`PRG_02:555`, `:25`, `:624`) ⇒ HX2→HX2N puis `HomeReq` sur le front descendant (`:621-625`) peut **graver un datum faux** sur l'axe resté bas, puis `MachineHomed` (`:771-773`) **ouvre SEMI_AUTO** | 🔴 **C1 sécurité** | `:237`, `:588-591`, `:621-625`, `PRG_02:555`, `FB_WinchCmdArbitrationM1.st:90-103` |
| **E2** | **Le commit benne HX5 ne vérifie pas que la benne est fermée** (texte l'exige, code non) ⇒ `IsClosed := TRUE` + `LastPosM2Close := CablePosM2` forcés | 🔴 **C1 sécurité** | `:657`, `:658-660`, `:669` → `FB_Bucket.st:375-380` ; grep `IsClosed` dans le FB = 0 |
| **E3** | **HXF sans issue annoncée** : sortie **uniquement** sur front Reset, texte muet | 🟠 C2 | `:748-750`, `:784-786`, purge `§4` `:367-382` |
| **E4** | **Bouton IHM « Lancer » sans effet sur une machine référencée**, et **sans aucun retour IHM** (bandeau vide) — contredit le commentaire MES `:535-538` | 🟠 C2 | `:543-546`, `:555`, `:804-809` |
| **E5** | **Gouvernance documentaire cassée** : le commentaire `:522-527` désigne `AF_Partie-09 (F09.08 - cycle de homing machine)` comme carte des réceptivités — or **F09.08 = exigence « centre-plage »** (`AF-09:401-428`) et l'AF **ne contient AUCUNE carte HX\*** : grep `HX` sur tout `DOC/AF/` = **2 occurrences seulement**, toutes deux la simple mention *« GRAFCET HX0..HX6 »* (`AF_Partie-09…v2.4.md:462` note RES-004, `:583`) ⇒ **HX7 (livré par T340) n'est documenté dans AUCUN AF** et aucune réceptivité HXn n'y est écrite ; la carte réelle n'existe que dans une **fiche de troubleshooting** aux **numéros de ligne périmés** (`TROUBLESHOOTING_T336_CycleHoming_Graphe7_2026-09-20.md:20-26` — cite `:436-440`, `:476-488`, alors que le fichier fait 876 lignes après T340/T362) et un **contrat obsolète** (`TASK_CONTRACT_T233:29`, `status: PENDING`) | 🟠 C2 | voir colonne preuves |
| **E6** | **Interface morte** : `HomingBusy`/`HomingDone` alimentés (`PRG_02:512-513`, `:516-517`) et **jamais lus** ⇒ **aucune garde « preset confirmé »** avant HX4/HX5 ; en re-référencement d'une machine déjà homed, HX3 peut sortir avant confirmation (risque borné en pratique par `CST_PresetVerifyTime = 50 ms`) | 🟠 C2 | `ST_fbMachineHomingCycle_AxisHomingStatus.st:11-12`, `FB_Encoder_Homing.st:110`, `:290` |
| **E7** | **Les ordres `CmdWinchM1/M2` du cycle sont INERTES en MAINT_N2** : routés `PRG_03:421-425` → `Data.ReqProgram.ReqWinchM*` → `instArbM*` (`PRG_04:534`, `:557`) mais consommés **uniquement en SEMI_AUTO** (`FB_WinchCmdArbitrationM1.st:56`, `M2:85`) ⇒ le mouvement vient **du joystick** ; `StepTgt := CST_StepSlow` (`:589`) jamais appliqué. Seul HX7 le documente (`:714-721`) | 🟠 C2 (interface trompeuse) | idem |
| **E8** | `§10` viole la règle édictée `:204` (« jamais de comparaison niée inline ») : `IF Mode <> E_Mode.MAINT_N2` | 🟡 C3 style | `:833`, `:853` |
| **E9** | Commentaire faux : « appui maintenu >= **300 ms** » alors que le seuil réel est **150 ms** | 🟡 C3 | `:321` vs `:174`, `:302` |
| **E10** | **Branche de guide morte** : `LOSS_SAFESTOP` (`:787-789`) jamais publiée (cause 0 latchante gagne en `:781-783`) | 🟡 C3 (code mort) | `:434-436`, `FB_FaultCore.st:63-69` |
| **E11** | Guide HX6 annoncé « HX5 » | 🟡 C3 texte | `:825-828` |
| **E12** | `FB_Safety_Winch` : butée haute **logicielle fail-open** si `NOT Homed` (`:581`) vs limite câble descente non gatée (`:565`) | 🟠 C2 (asymétrie) | `FB_Safety_Winch.st:563-582`, `AF-10:594-604` |
| **E13** | `AF-09:395`/`:455` (« Unitaire (**MAINT_N2** typiquement) ») et `FB_Encoder_Homing.st:4` contredisent le code qui autorise **N1 ET N2** (`PRG_02:610`, `:663`) ⇒ **source probable de l'attente de l'opérateur sur le point 1** | 🟡 C3 doc | idem |
| **E14** | **`MachineHomed` ne porte aucun terme de mode** (`:771-773`) : deux homings **unitaires** `BtnHome` en MAINT_N1 (`PRG_02:610`, `:663`) + une référence benne **RETAIN** (`PRG_02:562`, `FB_Bucket.st:403-407`) suffisent à qualifier la machine **en N1** ⇒ SEMI_AUTO redevient sélectionnable depuis N1 (`FB_Modes.st:251`). La qualification est **réelle** (les 2 axes ont un datum), mais elle est obtenue **hors du cycle guidé** et le **front de franchissement n'est pas exigé** (capteur actif suffit, `FB_Encoder_Homing.st:206-207`) — soit exactement l'affaiblissement que T340 a corrigé pour le cycle. À **assumer explicitement** dans la doctrine « N2 » plutôt qu'à laisser implicite | 🟡 C3 (doctrine) | `:771-773`, `PRG_02:610`, `:663`, `:562`, `FB_Modes.st:251`, `FB_Encoder_Homing.st:206-207` |
| **E15** | **Doc ≠ code sur le bypass benne** : `ST_BypassBucket.st:3` énonce *« Doctrine : actionnable **UNIQUEMENT en MAINT_N2** »*, alors que `PRG_04:386` transmet `GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global` **sans gate de mode** (dérogation MES assumée `PRG_04:292-294`). Or ce bit **neutralise la cause 4** (`FB_Bucket.st:181`) — le **seul** garde-fou « mouvement benne sans référence » | 🟠 C2 | `ST_BypassBucket.st:3`, `PRG_04:386`, `:292-294`, `FB_Bucket.st:181`, `:283-288` |
| **E16** | **« Palier 1 » annoncé pour HX4 mais NON tenu** : hors zone de ralentissement, une fermeture benne peut monter à `MaxStepUp = 2` (ouverture : `MaxStepDown = 4`) | 🟠 C2 (commentaire/doctrine vs code) | `:647`, `PRG_04:1325-1332`, `:525-526`, `ST_fbBucket_Config.st:15-16` |

---

## 7 · POINT 1 — doctrine MAINT_N2 : verdict **DOCTRINE EXPLICITE VALIDÉE**

| Preuve | Contenu |
|---|---|
| `TASK_CONTRACT_T185_HOMING_BENNE_CONJOINT_N2.yaml:104-107` | `validation: status: APPROVED` · `validated_by: "Utilisateur"` · `validated_at: 2026-08-30` · *« cycle de referencement guide, **actions libres en N2**… »* |
| idem `:7`, `:12` | Objectif : *« les actions restent libres en **MAINT_N2** »* ; AC1 : *« Une confirmation Ouverte/Fermee est **refusee hors MAINT_N2**… »* |
| idem `:77-78` (`dropped_on_purpose`) | *« Le recalage immediat de M2 seul par BtnConfirmOpenPos/BtnConfirmClosePos en **MAINT_N1** ou MAINT_N2 »* → capacité N1 **retirée volontairement** |
| `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md:266` | **« Décision T184 : MAINT_N2 seul pour confirmer la position visuelle de benne. »** (+ `:268` préconditions cumulatives `MAINT_N2` ; `:271` *« MAINT_N2 conserve les actions de récupération autorisées »*) |
| `TASK_CONTRACT_T264_HOMING_BOOT_GUARD.yaml:8` | *« HX1 reste une étape informative et **le référencement mouvement reste réservé à MAINT_N2** »* |
| Code | Garde N2 : `:557` (`ModeIsMaint2`), commentaire d'interface `:21`, routage des ordres `PRG_03:417-425`, `:445-453` |
| Code — **origine datée de la garde** | `git blame` : la garde N2 de HX1→HX2 est **préexistante** (`5efede11`, **2026-09-03**), dont le message cite *« Decision utilisateur (tranche Q3) »* ; **T340** (`266fb11f`, 2026-09-20) l'a **renommée** `ModeIsMaint2` **sans la créer** ; le commentaire d'interface `:21` vient de `e6bc681b` (2026-09-03, T233) |
| `TASK_CONTRACT_T340_HOMING_LOCKED_ASCENT.yaml:132-134` (AC7) et `:193` (`must_survive`) | *« en **MAINT_N1/N2**, le referencement unitaire manuel (bouton `BtnHome`, treuils arretes ou capteur haut atteint) reste disponible et sa semantique est inchangee »* → la voie N1 est un **chemin légitime reconnu par contrat**, pas une anomalie |

⚠️ **Chaîne de traçabilité cassée (fait à connaître)** : `AF-05:266` énonce une **« Décision T184 »** — or l'identifiant **T184** correspond aux **permits directionnels M3** (`AF_Partie-11`), **aucune entrée `id: T184`** n'existe dans `TASKS.yaml`, et le snapshot archivé `DOC/WFLOW/ARCHIVES/TASKS_SNAPSHOT_20260915/TASKS_20260915_234600.yaml:3997` qualifie lui-même le lot d'origine d'*« ex-contrat **T184** homing benne, **mal numéroté** »*. ⇒ Le seul ancrage humain réellement traçable de la doctrine est le **contrat T185** (`_CONJOINT_N2`, `APPROVED`). Si l'exploitant rouvre la doctrine, le point d'entrée documentaire est **T185 + `AF-05:262-272`**, jamais « décision T184 ».

✅ **Chemin N1 légitime qui existe déjà** (ce que l'opérateur cherche probablement) : **homing unitaire par bouton IHM**, autorisé **MAINT_N1 ET MAINT_N2** :
`PRG_02:610-613` (M1) et `:663-666` (M2) : `HomingPermit := ((Mode = MAINT_N1 OR Mode = MAINT_N2) AND (MachineHomingMechanicalStopOk OR (NOT BtnHomingAtZero AND NOT TopPositionFree))) OR instCycleMachineHoming.MxDemand.HomeReq` — commandé par `GVL_IHM.Mx…Cmd.BtnHome` (`:614`, `:667`).
⚠️ **Mais le guidage IHM ne le dit jamais** : en MAINT_N1 non référencé, le bandeau affiche « Passer en MAINT_N2 pour referencer » (`:835`) et « lancer (3 appuis JOY ou IHM) » (`:845`) **sans mentionner** le bouton `BtnHome` unitaire.

**Verdict P1** : **pas de bug, pas de correctif à coder**. Action = **documentation + guidage** :
1. confirmer à l'exploitant la doctrine (preuves ci-dessus, décision T184/T185 du 2026-08-30) ;
2. si le besoin est « référencer en N1 », la réponse est le **bouton unitaire `BtnHome`/`BtnHomingAtZero`** — à **rendre visible** dans le message (`:835`/`:845`) ;
3. si l'exploitant veut **élargir le cycle** à N1, c'est un **changement de doctrine** (donc décision humaine explicite + C1 + contrat), pas un correctif.

---

## 8 · Décisions demandées (aucune ne peut être prise par un agent)

| # | Question | Options |
|---|---|---|
| **D1** | P2 : quel consentement à l'entrée en phase mouvement ? | 2-A (recommandée) · 2-B · 2-C |
| **D2** | P3 : besoin réel de l'exploitant ? | 3-A (recommandée) · 3-B · 3-C · 3-D (rejetée) |
| **D3** | P4 : où doit apparaître « benne fermée » ? | formulation **A** · **B** · **C** (+ **D** pour HXF) |
| **D4** | E1 (C1) : ajouter un contrôle « couplage effectif » avant HX2 ? | oui (nouvelle entrée FB ou garde en amont) · non (assumé, à tracer) |
| **D5** | E2 (C1) : exiger `benne fermée` avant le commit HX5 ? | oui (lecture `IsClosed`/delta → nouvelle entrée FB) · non (assumé, texte corrigé) |
| **D6** | E5 : écrire la **carte des réceptivités HX0..HX7** dans `AF-09` (source de vérité unique) et corriger les 3 docs divergentes ? | oui · non |
| **D7** | E4/E3/E10/E11/E9/E8 : lot de **nettoyage texte/code mort** — dans le même lot ou lot séparé ? | même lot · lot séparé |
| **D8** | E12 : la butée haute **logicielle** doit-elle devenir **fail-closed** (durcir hors homing) ou rester en l'état ? | durcir (C1) · statu quo documenté |

---

## 9 · Suite proposée (après validation)

1. **GO sur ce rapport** (le brief impose : aucun code avant remise **et validation**).
2. Décisions D1→D8 tranchées par l'exploitant → **contrat C1** (`TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`, `check_task_contract.py`) portant les critères testables.
3. Lot **texte + guide** (P4, E3, E4, E9, E10, E11, E8) : périmètre `CODE/G_CYCLE/FB_CycleMachineHoming.st` **uniquement**, rejeu **G408** + **G200** + palier C, bundle + diff bundle.
4. Lot **sécurité** (E1, E2, E12) : **contrat C1 séparé**, revue indépendante obligatoire, tests `TC-P09-H2xx` rejoués, **aucun code avant D4/D5/D8**.
5. P3 : **rien** avant D2 (garde de sécurité mouvement) ; le cas échéant, contrat C1 + revue.
6. P1 : **aucun code** — note de doctrine + guidage IHM.

**Aucun commit** : le brief impose un accord explicite **distinct** du GO. Le lot T362 (4 littéraux) est **toujours non commité** dans l'arbre — à arbitrer par l'orchestrateur avant toute nouvelle écriture sur ce fichier.

---

*Rapport produit en lecture seule — `DOC/WFLOW/AUDITS/AUDIT_T364_HOMING_4_POINTS_20260921.md` · base : arbre de travail `FB_CycleMachineHoming.st` (HEAD `276fc11e` + diff T362 non commité) · 2026-09-21.*

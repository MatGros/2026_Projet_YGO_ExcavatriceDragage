# 🎬 BRIEFING T213 — Diagnostic homing M2 « benne fermée »

| | |
|---|---|
| **Date** | 2026-11-02 10:1x (session DSH) |
| **Tâche** | T213 — `⬜` à faire · **C2** · OUTILLAGE · contrat `PENDING` / validation `PENDING` |
| **HEAD** | `540a8a86` |
| **Verrou** | aucun (T213 non verrouillée ; `TASK_LOCKS.json` = T426/CDX01 seulement) |
| **Mode** | **READ-ONLY strict** — aucun fichier `CODE/` touché, aucun bundle, aucun gate |
| **Méthode** | workflow `briefing-t213` : 4 audits parallèles (diagnostic existant · chaîne homing M2 · outillage CI · traçabilité doc) + vérification directe par l'orchestrateur |
| **Réfs** | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T213.yaml` · `DOC/WFLOW/AUDITS/DESIGN/PLAN_T213troubleshooting_homing_M2.md` |

---

## 🚦 §0 — Verdict en 30 secondes

> **T213 est faisable, mais pas tel qu'il est écrit.**

| Constat | Effet |
|---|---|
| 🔴 **La prémisse de T213 est fausse** : la chaîne `M2Demand.UseDynamicTarget → instEncoderM2.UseDynamicTarget → CfgTopHomingTarget_M + CfgOffsetClose_M` **n'existe pas dans le code** | AC7 (critère d'acceptation central) est **structurellement inatteignable** ; le lot serait rejeté après avoir consommé bundle + gates |
| 🔴 **Le REX qui explique pourquoi elle n'existe pas a été supprimé du code** (T364, `42fe45c8`) | Réactiver la cible dynamique réintroduit l'incident machine documenté : écart M1/M2 ~15 m → `FB_WinchSync` SafeStop → `Fault.Latched` |
| 🟠 **0 / 10** des champs T213 ne sont dans `F_HomingM2` ; **4 / 10 existent déjà ailleurs** dans le snapshot | Une partie du besoin est déjà satisfaite hors du slot homing |
| 🟠 **4 références de fichiers mortes** dans le contrat/plan, et **`check_task_contract.py` passe PASS quand même** | Garde-fou fantôme : « `git diff` de `FB_MachineHomingCycle.st` = vide » passerait trivialement |
| 🟢 **L'outillage suit tout seul** : `troubleshooting_variables.txt` est **généré** depuis les `.st` | AC3 est prouvable en 2 commandes — mais **aucun gate ne verrouille** cette liste |
| 🟠 **Le symptôme « 8,5 m » pourrait être voulu** (fix `0350e3d1`, décision `TASKS.yaml:9154`) | T213 documente peut-être un comportement de conception, pas un bug — à trancher **avant** d'écrire (§2bis) |
| 🟠 **`AF_Partie-14` est muet sur le homing** (1 occurrence, aucun champ) | T213 = **exigence nouvelle**, pas rattrapage d'écart ; la doc devra être **créée**, pas complétée |

**→ 6 décisions humaines à trancher (§7) avant de lever `ARRET VALIDATION 1`.**

---

## 📋 §1 — Ce que T213 demande vs ce que le code porte

Source de vérité : `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st:6-35` (16 champs), `CODE/J_SUPERVISION/FB_TroubleshootingView.st:456-480`.

| # | Champ exigé (contrat §AC1) | État réel | Producteur réel (fichier:ligne) | Publication nécessaire |
|---|---|---|---|---|
| 1 | `MechanicalStopOk` | ❌ absent | `PRG_02_Acquisition.st:43`, calcul `:557-560` | locale → à publier |
| 2 | `BucketReferenceRequested` | ❌ absent | `PRG_02_Acquisition.st:47`, calcul `:566-568` | locale → à publier |
| 3 | `UseDynamicTarget` (M2) | ⚠️ **aucune variable** : expression inline | `PRG_02_Acquisition.st:718` | à matérialiser puis publier |
| 4 | `DynamicHomingTargetM` | ⚠️ **aucune variable** : expression inline | `PRG_02_Acquisition.st:719-720` | à matérialiser puis publier |
| 5 | `M2DemandHomeReq` | ⚠️ existe, non exposé | `FB_CycleMachineHoming.st:82`, écrit `:201/378/465/482/503` | à publier |
| 6 | `M2DemandUseDynamicTarget` | 🔴 **jamais écrit — chemin mort** | lu `PRG_02:718`, **0 écriture dans tout `CODE/`** | ⚠️ affichera `FALSE` à vie |
| 7 | `M2DemandDynamicTarget_M` | 🔴 **jamais écrit — chemin mort** | lu `PRG_02:720`, **0 écriture dans tout `CODE/`** | ⚠️ affichera `0.0` à vie |
| 8 | `CfgTopHomingTarget_M` | ⚠️ existe, non exposé | `PRG_02:583` ← `_WinchM2CfgPersist.CfgTopSensorPos_M` | à publier |
| 9 | `CfgOffsetClose_M` | ⚠️ existe, non exposé | `PRG_02:585` ← `_BucketCfgPersist.Config.OffsetCloseM` | à publier |
| 10 | état cycle `MachineHomed/Active/Step/Failed` | ✅ **déjà visible** | `FB_TroubleshootingView.st:338,339,340,344` → `K_BenneOuvertureFermeture.Idx113/114/115/119` | aucune (déjà là) |

**Deux faits critiques absents du contrat** (audités comme discriminants) :

| Champ | Pourquoi il compte | Preuve |
|---|---|---|
| `BucketReferenceTargetM` | **La seule cible dynamique réellement vivante** du programme | `PRG_02_Acquisition.st:48`, calcul `:574` / `:576` |
| `SeqStep` (GRAFCET HX0..HXF) | Localise le point de blocage ; `Step` (priorité) ne le fait pas | `ST_MachineHoming.st:20`, publié `PRG_02:631` |

---

## 🚨 §2 — Prémisse fausse : le maillon central est mort

**Ce que T213 suppose** (`PLAN_T213:37-40`) :
`M2Demand.UseDynamicTarget` ⇒ `instEncoderM2.UseDynamicTarget` ⇒ cible = `CfgTopHomingTarget_M + CfgOffsetClose_M`.

**Ce que le code fait** (vérifié par grep exhaustif, hors `CODE_BACKUP/`) :

```text
M2Demand.HomeReq          ← écrit  (FB_CycleMachineHoming.st:201, 378, 465, 482, 503)
M2Demand.UseDynamicTarget ← JAMAIS écrit   (seule occurrence : lecture PRG_02:718)
M2Demand.DynamicTarget_M  ← JAMAIS écrit   (seule occurrence : lecture PRG_02:720)
CfgTopHomingTarget_M      ← écrit une fois (PRG_02:583) puis JAMAIS relu
CfgOffsetClose_M          ← écrit une fois (PRG_02:585) puis JAMAIS relu
```

**Conséquences mécaniques :**

1. `M2Demand.UseDynamicTarget` vaut `FALSE` par défaut de STRUCT ⇒ le cycle **ne demande jamais** de cible dynamique.
2. `CfgTopHomingTarget_M + CfgOffsetClose_M` **n'est calculé nulle part** — ni dans le code, ni dans la spec.
3. Sans `UseDynamicTarget`, `FB_Encoder_Homing.st:219-220` retombe sur `TargetPositionM := CfgTopSensorPosM` = **8.5 m** (`GVL_PERSISTENT.st:49`).
   → 🎯 **c'est l'explication exacte du symptôme « M2 reste à 8,5 m »** : la cible dynamique n'est pas « mal calculée », elle n'est **pas armée**.

> ⚠️ **Exposer ces champs sans le dire produirait un faux témoin** : un technicien lirait `M2DemandUseDynamicTarget = FALSE` et `DynamicTarget_M = 0.0` en permanence et conclurait à tort que le cycle demande 0 m, au lieu de voir que le maillon est inerte par construction.

---

## 🧭 §2bis — Attention : « M2 reste à 8,5 m » pourrait être un comportement **voulu**

Traçabilité de la décision (audit documentaire) :

| Source | Décision actée |
|---|---|
| `DOC/WFLOW/TASKS.yaml:9154` | fix `0350e3d1` : **`M2Demand.UseDynamicTarget := FALSE` forcé** ⇒ preset M2 à `CfgTopSensorPos_M` (8,5 m) quel que soit l'état benne |
| `DOC/WFLOW/TASKS.yaml:9160-9163` | décision exploitant : le référencement doit marcher **benne ouverte OU fermée** |
| `DOC/WFLOW/TASKS.yaml:9185-9186` | T240 close « benne ouverte ou fermée pris en charge » — **non vérifiable dans le code actuel** (aucune affectation `UseDynamicTarget`) |
| `DOC/AF/AF_Partie-09_v2.4.md:459` | M2 reçoit sa **propre** cible haute (`_WinchM2CfgPersist.CfgTopSensorPos_M` ± offset), « jamais la config M1 ni une position M1 live » |
| `CHALLENGE_T336_HOMING_HYPOTHESE_MONTEE_2026-09-20.md:346` | **RES-004 « benne ouverte » : toujours ouverte**, pas d'abandon prononcé |

> 🎯 **Reformulation du problème** : la question n'est pas « la cible dynamique est cassée » mais **« quelle voie est censée armer la cible M2 — le cycle (mort par décision) ou la confirmation benne opérateur (vivante) ? »**.
> Si la réponse est « confirmation benne », alors `BucketReferenceRequested` / `MachineHomingMechanicalStopOk` / `BucketReferenceTargetM` sont **les trois seules variables qui expliquent le symptôme**, et les champs `M2Demand*` n'ont aucun pouvoir diagnostique.

---

## 💥 §3 — Pourquoi c'est mort : le REX a été effacé du code par T364

| Fait | Preuve |
|---|---|
| Le code portait un REX : *« Cible dynamique (top + offset ~23 m) supprimée ici : elle créait un écart apparent M1/M2 de ~15 m au preset → FB_WinchSync SafeStop → Fault.Latched »* | Cité verbatim dans `TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md:603` et `:745` (constat A16) |
| Ce REX **n'existe plus** dans `FB_CycleMachineHoming.st` ; les lignes `412-420` sont aujourd'hui `HX0_REPOS` | `FB_CycleMachineHoming.st:411-418` (lecture directe) |
| Il a été supprimé avec les deux lignes de forçage lors de la refonte T364 | `git show 42fe45c8` : suppression de `M1Demand.UseDynamicTarget := FALSE;` / `M2Demand.UseDynamicTarget := FALSE;` + du commentaire REX |
| Les fiches T336 / T334 / T338 citent encore `:412-420` et `:510-515` | Renvois **périmés** (T364 a réécrit la séquence HX0..HX6) |

**🚨 Risque machine si on réactive sans traiter la cause :** l'incident d'origine (écart apparent ~15 m au preset) est un **défaut latché par la surveillance de synchronisme M1/M2**. Réarmer la cible dynamique sans résoudre cet incident le reproduit — sur une machine réelle.

> 📌 Le commentaire REX doit **revenir dans le code** (ou dans la spec) avant toute modification du homing : sans lui, le prochain agent « réparant » le maillon mort réintroduira l'incident en croyant corriger un oubli.

---

## 🔎 §4 — Le mécanisme réellement vivant (et un écart spec à confirmer)

La **seule** cible dynamique active aujourd'hui est la **référence benne hardware** :

```st
// PRG_02_Acquisition.st:566-577
BucketReferenceRequested := (front BtnConfirmOpenPos XOR front BtnConfirmClosePos)
                            AND Mode = MAINT_N2
                            AND MachineHomingMechanicalStopOk;
BucketReferenceTargetM   := instEncoderM1.Measurement.CablePosM + Offset(Open/Close)M;
// :718-720
UseDynamicTarget     := BucketReferenceRequested OR M2Demand.UseDynamicTarget;   // ← 2e terme mort
DynamicHomingTargetM := SEL(BucketReferenceRequested, M2Demand.DynamicTarget_M, BucketReferenceTargetM);
```

C'est **conforme à la spec** `AF_Partie-09_v2.4.md:359` (« M2 seul, actif : `M2BucketRefRequested` … auto-référence M2 sur `CablePosM1` ± `OffsetCloseM` »).

🟠 **Écart spec/code à trancher (non prouvé, à confirmer en revue)** — AF-09 `:359` et `:434-436` exigent que la cible `CablePosM1 ± offset` ne soit acceptée **que si M1 est `HomedAndReliable`** (« sinon la cible repose sur une mesure non fiable, homing refusé — `ErrorId` dédié »).
**Aucune porte `HomedAndReliable` n'existe sur ce chemin** : `PRG_02:566-568` (MAINT_N2 + arrêt mécanique) et `PRG_02:718-720` n'en portent aucune ; `FB_Encoder_Homing.st:211-223` ne connaît pas M1. → À vérifier (une garde peut exister ailleurs), mais **si l'écart est réel, il est plus grave que le bug que T213 vise**.

---

## 🧾 §5 — Références mortes : le contrat protège des fichiers fantômes

| Emplacement | Référence citée | Réalité |
|---|---|---|
| Contrat `:124` (interdit), `:81/:84` | `CODE/G_CYCLE/FB_MachineHomingCycle.st` | **absent** → `CODE/G_CYCLE/FB_CycleMachineHoming.st` (renommé T239, `239085de`) |
| Contrat `:54-55` | `instMachineHomingCycle` | **`instCycleMachineHoming`** (`PRG_02:36`) |
| Contrat `:126`, `:132` | `DOC/NAMING_CONVENTION.md`, `CODE/CODE_Bundle.xml` | → `DOC/STDS/NAMING_CONVENTION.md`, `CODE_XML/CODE_Bundle.xml` |
| Plan `:19, :47`, `:30, :35` | idem nom de POU / d'instance | idem |
| REX `ST_fbMachineHomingCycle_HomingDemand.st:6, :14` | affirme la cible `CfgTopHomingTargetM + offset` | **vœu de conception jamais implémenté** |
| En-tête `FB_CycleMachineHoming.st:9-10` | bande HX4 `[8.50..8.80 m]` | code réel `7.50..9.50` (`ST_fbMachineHomingCycle_Cfg.st:29-30`) |
| Contrat `:29-30` | « Ces faits sont **publiés** par PRG_02_Acquisition » | **faux** : `MachineHomingMechanicalStopOk` (`:43`), `BucketReferenceRequested` (`:47`), `MachineHomingCfg` (`:44`) sont des **locales privées** |
| Contrat `:52-53` (AC2) | `instEncoderM2.UseDynamicTarget` présenté comme producteur | ce sont des **`VAR_INPUT`** (`FB_Encoder.st:32-33`) écrites par `PRG_02:718-720` |
| AF-09 `:433`, `:580` | cite `PRG_02_Acquisition.st:443` | l'affectation réelle est `:583` |
| AF-09 `:569` | `GVL_Troubleshooting.HomingM1/HomingM2` | réels `E_HomingM1` / `F_HomingM2` (`GVL_Troubleshooting.st:14-15`) ; **pointeur orphelin vers un AF-14 muet** |
| Plan `:35` vs contrat `:42` | `HomingCycleActive/Step/Failed` vs `Active/Step/Failed` | noms cibles **divergents** entre plan et contrat |

⚠️ **`check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T213.yaml` → PASS (0 erreur, 0 avertissement)** : le contrôle valide la **structure** du contrat, pas l'**existence** des chemins cités. C'est exactement le trou par lequel un garde-fou fantôme passe.

---

## 🧰 §6 — Outillage : ça suit tout seul, mais rien ne verrouille

| Question | Réponse | Preuve |
|---|---|---|
| `troubleshooting_variables.txt` est-il maintenu à la main ? | **Non** : 571 lignes générées depuis les `STRUCT` de `CODE/` (+30 lignes en dur dans le script) | `generate_variable_list_from_code.py:3-12, :27, :43-76, :98-145` |
| Les nouveaux champs apparaîtront-ils ? | **Oui, automatiquement** après extension de `ST_HomingChecklist` | `:87-92`, `:147-149` |
| Bloc homing M2 actuel | `E_HomingM1` `:98-113`, `F_HomingM2` `:114-129` (16 lignes chacun) | lecture directe |
| Piège AC3 | `--output` par défaut = **écrase le fichier de référence** (:24) → une comparaison « après régénération en place » est vide **par construction** | :21-24, :79-82 |
| Un gate verrouille-t-il cette liste ? | **Aucun.** G200 ne couvre que les `PRG_*` ; G330 couvre les membres de STRUCT ; palier C = 61 gates exécutés, aucune lecture de la liste | audit outillage |
| Type partagé | `ST_HomingChecklist` sert **M1 ET M2** (`GVL_Troubleshooting.st:14-15`) → 10 champs M2 apparaîtront **inertes côté M1** | idem |

**Commandes AC3 correctes** (jamais de scratch dans le dépôt, règle T279) :
```powershell
py -3.13 TOOLS/PLC_CSV_SNAPSHOT/variable_lists/generate_variable_list_from_code.py --output "$env:TEMP\ts_vars.txt"
git diff --exit-code -- TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt
```

---

## 🔗 §6bis — Dépendances et collisions de périmètre (à lever avant d'écrire)

| Tâche | Statut | Lien avec T213 | Risque |
|---|---|---|---|
| **T313** | `⬜` C2 | réorganise **`GVL_Troubleshooting.st`** + vue IHM | 🔴 **collision directe** : même fichier que le périmètre autorisé T213 (`contrat:111`) → **un seul écrivain**, séquencement obligatoire |
| **T235** | `⬜` C4 | touche `FB_Encoder_Homing.st` (latence 500 ms) et cite « cf. T213 » | 🟠 dépendance cachée, **même bug M2** |
| **T336** | ouvert | arbitrage « Graphe 7 force la cible dynamique inactive » | 🟠 T213 **expose** ce que T336 doit **arbitrer** — arbitrage toujours ouvert |
| **T338** | — | « Position M2 figée » (simulateur) | 🟢 même symptôme, conclusion croisée possible |
| **T364** | `✅` 2026-09-21 | refonte GRAFCET HX0..HX7_FAILED, **postérieure au contrat T213** (2026-09-01) | 🔴 le contrat T213 est **antérieur** à la refonte qui a supprimé le REX ; `BtnConfirmHomingBucket` (`PRG_02:612`) et HX7 n'y figurent pas |

---

## ⚖️ §7 — Décisions à trancher (bloc unique, un seul tour)

| # | Décision | Options | 🎯 Recommandation orchestrateur |
|---|---|---|---|
| **D1** | Périmètre de T213 | (a) **diagnostic seul** — AC7 réécrit pour prouver l'**état** des maillons, pas la formule ; (b) diagnostic **+ réactivation** de la cible dynamique | **(a)** maintenant. (b) est un lot distinct, criticité relevée, incident sync M1/M2 à traiter d'abord |
| **D2** | Où publier les faits | (a) étendre le bus `Data.MachineHoming` (consommé par PRG_03/04/07 + `GVL_IHM`) ; (b) **VAR_OUTPUT plats neufs** sur `PRG_02` | **(b)** — rayon d'action minimal, pas de régression sur 4 consommateurs |
| **D3** | Compléter le contrat | ajouter `BucketReferenceTargetM` + `SeqStep` | **OUI** — sans eux le snapshot ne montre pas la vraie cible ni le point de blocage |
| **D4** | Réécrire AC7 | formule T213 vs état des maillons | **OUI** — AC7 devient : *« le snapshot montre que la cible dynamique n'est armée que par la référence benne, et affiche la cible effectivement présentée à l'encodeur M2 »* |
| **D5** | Corriger les références mortes | contrat + plan (POU, instance, chemins) | **OUI, avant toute écriture** — sinon les garde-fous sont fantômes |
| **D6** | Écart `HomedAndReliable` sur la référence benne (§4) | traiter dans T213 / ouvrir une tâche dédiée | **tâche dédiée** (safety > outillage) — ne pas diluer T213 |
| **D7** | Collision de périmètre avec **T313** (`GVL_Troubleshooting.st`) | séquencer / découper / fusionner | **séquencer** : T213 ne démarre pas tant que T313 tient le fichier (un seul écrivain) |
| **D8** | « M2 reste à 8,5 m » = bug ou conception ? (§2bis) | (a) comportement voulu → T213 devient **outil de preuve**, le « bug » se referme ; (b) comportement non voulu → **nouvelle tâche homing** (hors outillage) | **trancher d'abord** : sans cette réponse, T213 documente un diagnostic dont la cible est indéfinie |

> 🛑 Sans ces arbitrages, `ARRET VALIDATION 1` reste fermé : **aucune écriture dans `CODE/`** (`AGENTS.md`, C2 machine réelle).

---

## 📐 §8 — Plan corrigé proposé (si D1 = (a))

| Phase | Action | Fichiers | Gate |
|---|---|---|---|
| **P0** | Corriger contrat + plan (réfs mortes, AC7, champs ajoutés) | `TASK_CONTRACT_T213.yaml`, `PLAN_T213…md` | `check_task_contract.py` |
| **P1** | Étendre `ST_HomingChecklist` (champs M2) | `ST_HomingChecklist.st` | bundle + G200 |
| **P2** | Publier les faits (VAR_OUTPUT `PRG_02`) + matérialiser `UseDynamicTarget`/`DynamicHomingTargetM` en variables locales lisibles | `PRG_02_Acquisition.st` | bundle + G200 + grep chemins |
| **P3** | Projeter (VAR_INPUT + affectations, lecture seule stricte) | `FB_TroubleshootingView.st`, `PRG_07_Supervision.st` | bundle + G200 + revue diff (AC4) |
| **P4** | Régénérer la liste + comparer | `troubleshooting_variables.txt` | AC3 (§6) |
| **P5** | Doc : créer la section « diagnostic homing » (aujourd'hui **inexistante**) | `AF_Partie-14_v1.4`, `AF_Partie-09_v2.4` | G340 |
| **P6** | Lot complet | — | `run_all_gates.py --palier C` + diff bundle |
| **P7** | 🛑 ARRET VALIDATION finale (snapshot réel, export frais) | — | humain |

**Interdits confirmés** : `FB_CycleMachineHoming.st` (logique homing), `FB_Encoder.st`, `Device.export`. Aucun changement de comportement.

---

## 🛡️ §9 — Garde-fous à produire (règle `fix:` + `guard:`)

| Garde-fou | Ce qu'il empêche | Cible |
|---|---|---|
| **G-refs** : contrôle d'existence des chemins cités dans `CONTRACTS/*.yaml` | Contrat « PASS » protégeant un fichier fantôme (cas T213 : 4 réfs mortes) | `TOOLS/AGENT_WORKFLOW/scripts/` |
| **G-var-list** : régénération → comparaison, sans écrasement possible | Une liste `troubleshooting_variables.txt` désynchronisée du code, silencieusement | idem |
| **G-REX** : vérifie que le POU homing porte son REX (garde de non-régression documentaire) | Perte du REX T364 → réintroduction du risque machine | idem |

---

## ✅ §10 — Preuves de cette session

**Exécuté (read-only)** :
- 4 audits parallèles (workflow `briefing-t213`) : diagnostic existant · chaîne homing M2 · outillage · traçabilité.
- Greps exhaustifs hors `CODE_BACKUP/` : `M2Demand.*`, `CfgTop/Offset*`, `DynamicTarget_M`, `BucketReference*`, `HomedAndReliable`.
- `git log`/`git show 42fe45c8` sur `CODE/G_CYCLE/FB_CycleMachineHoming.st`.
- Lectures : `PRG_02:557-577 / 710-725`, `FB_Encoder_Homing.st:200-241`, `FB_TroubleshootingView.st:338-344 / 456-480`, `AF_Partie-09_v2.4:352-454`, `AF_Partie-14_v1.4` (grep), `TROUBLESHOOTING_T334:596-617 / 738-755`.
- `check_task_contract.py T213` → **PASS (0/0)**.

**NON exécuté (volontairement)** : aucun bundle, aucun `G200`, aucun gate, aucun test, **aucune modification de fichier `CODE/`**. Aucun export CODESYS (règle : `Device.export` interdit / périmé).

---

## 👤 §11 — Ce qui reste à l'humain

1. Trancher **D1 → D6** (§7) — en un seul tour, pas micro-décision par micro-décision (§ regroupement obligatoire).
2. Confirmer ou infirmer l'**écart `HomedAndReliable`** (§4) : c'est un sujet **safety**, prioritaire sur T213.
3. Fournir un **export CODESYS frais** + un snapshot réel quand le lot sera prêt (TC-04), jamais le `Device.export` du dépôt.
4. Décider si le REX T364 doit revenir **en commentaire dans le code** (recommandé) ou seulement en spec.

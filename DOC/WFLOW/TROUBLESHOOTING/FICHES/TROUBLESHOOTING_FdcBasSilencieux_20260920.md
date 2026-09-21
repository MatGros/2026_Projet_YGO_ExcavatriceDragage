# 🕵️ Session de Troubleshooting — FDC logiciel BAS silencieux (AnyFault allumé, bandeau muet)

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_FdcBasSilencieux_20260920.md`
> 📅 Date : 2026-09-20 · 🧊 Situation : **[SITE] MES** (constat opérateur rapporté, aucun snapshot fourni) · 📄 Statut : **[EN COURS]**
> 🎫 Tâche : **T255-D** (C2, verrou `DSH05` — tag renommé le 2026-09-20 sur collision `DSH01`) · 🔒 `DOC/WFLOW/TASK_LOCKS.json` → `work_locks.T255-D`
> 🧭 Méthode : **[3] Analyse statique** (lecture de code) — **aucun** snapshot PLC (§4bis non disponible sur ce symptôme : aucune variable de décision live n'est requise, la chaîne est entièrement statique).

---

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
- Constat terrain MES rapporté (2026-09-20, remonté aussi dans la passation du 20/09) : **à l'arrivée en fin de course logicielle BASSE d'un treuil, le voyant `AnyFault` s'allume, mais le bandeau IHM n'affiche ni message d'alarme ni texte d'action opérateur exploitables**.
- Besoin exprimé : au **même scan** que `AnyFault`, l'opérateur doit voir **la cause** (quel treuil, quelle limite) **et ce qu'il a le droit de faire** (ex. remonter).
- Cadrage de mission : « le défaut FDC bas entre-t-il dans `AnyFaultActive` sans entrée bandeau ? est-il filtré (priorité/carrousel) ? a-t-il un libellé vide ? »
- Cadrage initial situait le point chaud en `PRG_07_Supervision` **lignes 424-427** — **non conforme au code** (`AnyFaultActive` = `PRG_07_Supervision.st:537-547`, le POU est `CODE/M_MAIN/`, pas `CODE/J_SUPERVISION/`). Écart signalé, sans conséquence sur la cause.

### Variables & valeurs
> ⚠️ **Aucune acquisition PLC** dans cette session : diagnostic **statique** (faits de code 🟢). Les valeurs « atteintes » côté terrain sont **rapportées** 🟡, jamais mesurées par l'agent.

| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Limite basse câble atteinte (cause 6) | `FB_Safety_Winch.instCauses[6].Active` ← `CablePosM <= CfgCableLimitDescentM` | TRUE (rapporté 🟡) | — |
| Bit de défaut correspondant | `ST_SafetyWinch.ErrorId` bit **6** = `16#0040` | `16#0040` (déduit 🟢 de `FB_Safety_Winch.st:319-325`) | — |
| Agrégat voyant | `GVL_IHM.Modes.State.AnyFaultActive` | **TRUE** (déduit 🟢 de `PRG_07:537-547`) | — |
| Carrousel alarmes | `GVL_IHM.Banner.AlarmBanner.HasAlarm` / `.Count` | **FALSE** / **0** (déduit 🟢 de `FB_Hmi_BannerFormatter.st:1175-1181`) | — |
| Permis descente | `ST_SafetyWinch.DescendPermit` | **FALSE** (déduit 🟢 de `FB_Safety_Winch.st:563-564`) | — |

### Périmètre interdit confirmé
- ⚠️ **`ST_IHM_MANU` n'existe pas dans `CODE/`** : supprimé définitivement le 2026-07-19 (`CODE_BACKUP/…/GVL_IHM.st:19`). Seules des traces subsistent dans `CODE_BACKUP/` et `ARCHIVES/` — **aucun fichier actif à interdire**. Le cadrage de mission le listait encore comme « table figée » : **écart de cadrage constaté**.

---

## 2. 🎯 Symptôme

À l'arrivée en **fin de course logicielle basse** d'un treuil (M1 ou M2), le voyant **`AnyFault` s'allume** (défaut réellement actif) alors que le **carrousel d'alarmes reste vide** (`HasAlarm=FALSE`) et que le texte d'action opérateur **ne nomme jamais la cause** (il affiche un message générique de joystick). Permanent tant que le treuil reste sur la butte basse. Reproductible (mécanisme statique, indépendant du banc).

---

## 3. 🧩 Indices / historique

- **Derniers changements** : `AF-07 v2.3` (2026-09-01) — « Tri du carrousel : ne publie que les **défauts actifs bloquants** (SafeStop / PowerCutOff / interlock), warnings non bloquants exclus » (`AF_Partie-07…v2.3.md:365`). Le code a **étendu** cette exclusion aux « limites basse/haute » (`FB_Hmi_BannerFormatter.st:813-816`), ce que la spec ne dit pas.
- **Déjà essayé** : —
- **Conditions d'apparition** : `CablePosM <= CfgCableLimitDescentM` (défaut `-50.0 m`, `ST_WinchCfg.st:13`), hors `InReferencingMode`, hors bypass `BypassCableLimitSwitch`.
- **Alarmes** : **aucune** dans `AlarmBanner` alors que le défaut est actif → c'est le symptôme.
- **Constat de la mission à challenger** : « le bandeau n'affiche NI message d'alarme NI texte d'action ». Résultat du diagnostic : **l'alarme est réellement vide** (`HasAlarm=FALSE`), mais **le texte d'action n'est jamais vide** — la chaîne `FB_Hmi_BannerFormatter.st:605-754` se termine toujours par un `ELSE`. Le défaut réel est **un texte d'action muet sur la cause** (message générique), pas une absence de texte. Cette nuance conditionne la formulation de l'AC2.

---

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| H1 | Le défaut FDC bas **n'entre pas** dans `AnyFaultActive` | `AnyFaultActive` ← `…Safety.Error` | devrait agréger les défauts treuil (`PRG_07:541-542`) | **agrégé** : `PRG_07_Supervision.st:541-542` inclut `M1TreuilRetenue.Safety.Error` / `M2TreuilBenne.Safety.Error` | ❌ **réfutée** |
| H2 | Le défaut est présent dans `AnyFaultActive` mais **filtré par le carrousel** | décodage `ErrorId` §5a/§5b | toute cause active bloquante publiée (`AF-07 §6:287-292`) | **bit6 = `16#0040` jamais décodé** (`FB_Hmi_BannerFormatter.st:817-849` + décision `:813-816`) | ✅ **CONFIRMÉE (cause racine)** |
| H3 | Le défaut a un **libellé vide** | `instCauses[6].Texte` | libellé non vide | `'Limite basse cable atteinte'` (`FB_Safety_Winch.st:325`) — libellé **existe**, il n'est simplement **pas routé** au bandeau | ❌ **réfutée** |
| H4 | La cause n'est **jamais levée** (limite non atteinte) | `CablePosM <= CfgCableLimitDescentM` | FALSE | TRUE à l'arrivée en butte basse (`FB_Safety_Winch.st:319`) | ❌ **réfutée** |
| H5 | Le texte d'action est **vide** | `Banner.OperatorActionText` | non vide | **non vide mais générique** (`[JOYSTICK] Armé - actionner axe`, `FB_Hmi_BannerFormatter.st:751-752`) — la cause n'y apparaît jamais sans commande de descente | ✅ **confirmée (2ᵉ défaut, de contenu)** |
| H6 | Le repli documenté (« visibles via `OperatorActionText`/`SpecialCondition` », `:813-816`) fonctionne | branche `:656-658` | atteignable | **inatteignable** sans `DirectionBlocked AND CurrentDirection<0` (`:648-649`) et **absente** de `SpecialCondition` (`:359-382`) | ✅ **confirmée (repli mort)** |
| H7 | Toute cause de `Safety.Error` est décodable par `ErrorId` | `WinchM1Safety.Error` vs `.ErrorId` | même jeu de causes | **asymétrie** : `Error = OR(WinchRef.Fault.Error, Safety.Fault.Error)` mais `ErrorId = Safety.Fault.ErrorId` seul (`FB_WinchStateProjection.st:236-237`) | ✅ **confirmée (trou structurel)** |

---

## 5. 📊 Arbre vertical des hypothèses (flux de données) — §3ter producteur → routeur → consommateur

```text
[PRODUCTEUR] CablePosM <= CfgCableLimitDescentM            (REAL, seuil -50,0 m)
  └─ FB_Safety_Winch.st:319-325  instCauses[6].Active := TRUE ; Latching := FALSE
      Texte := 'Limite basse cable atteinte'                     ✅ libellé existe
      └─ FB_Safety_Winch.st:488  instFault(Enable, Reset, Causes)
          └─ Fault.ErrorId bit6 = 16#0040 ; Fault.Error = TRUE    ✅
[ROUTEUR 1] FB_WinchStateProjection.st:237  WinchM1Safety.ErrorId := SafetyM1.Fault.ErrorId
[ROUTEUR 2] FB_WinchStateProjection.st:236  WinchM1Safety.Error := WinchM1Ref.Fault.Error OR SafetyM1.Fault.Error
[ROUTEUR 3] PRG_04_Treuils_Benne.st:1051 / instSafetyWinchM1 → Data.WinchM1Safety
[ROUTEUR 4] PRG_07_Supervision.st:441  GVL_IHM.M1TreuilRetenue.Safety := PRG_04…WinchM1Safety
[ROUTEUR 5] PRG_07_Supervision.st:537-547
              AnyFaultActive := … OR GVL_IHM.M1TreuilRetenue.Safety.Error
                                 OR GVL_IHM.M2TreuilBenne.Safety.Error        ✅ VOYANT ALLUMÉ
[CONSOMMATEUR FINAL] FB_Hmi_BannerFormatter  (§5 carrousel)
  └─ :812-816  décision : « limites basse/haute EXCLUS du carrousel »
  └─ :817-849  §5a/§5b décodent bits 0-4 puis 7-15 — bit6 (16#0040) N'EST PAS DÉCODÉ ❌
  └─ :1175-1181 AlarmCount = 0 → HasAlarm := FALSE ; Text := ''                 ❌ BANDEAU VIDE

[CHEMIN DE REPLI ANNONCÉ — mort]
DescendPermit := NOT(… CauseCableLimitActive …) = FALSE        (FB_Safety_Winch.st:563-564)
  └─ DirectionBlocked := (CurrentDirection<0 AND NOT DescendPermit) OR …   (:408-409)
      ├─ joystick RELÂCHÉ  → CurrentDirection = 0 → DirectionBlocked = FALSE ❌
      │     └─ branche :656-658 (SEUL libellé nommant la limite) INATTEIGNABLE
      │         └─ chute :747-754 → '[JOYSTICK] Appuyé homme-mort' / 'Armé - actionner axe' ❌ cause absente
      └─ SpecialConditionText :359-382 : AUCUNE branche « limite basse câble »  ❌
```

**Résumé une ligne** : `[CablePosM<=CfgCableLimitDescentM=1] → [ErrorId.bit6=16#0040=1] → [AnyFaultActive=1] ✅ → [bit6 décodé au carrousel=0] ❌ → [HasAlarm=0 / Text=''] ❌`

---

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- `PRG_07_Supervision.st:537-547` (lu) : `AnyFaultActive` = OR de **11 sources** ; agrège bien `Safety.Error` des deux treuils → **le voyant ne ment pas**.
- `FB_Hmi_BannerFormatter.st:817-849` (§5a/§5b) : décodage des `ErrorId` M1/M2 par champ nommé (`ErrorOperatorComm`, `ErrorEncoder`, `ErrorPhaseRotation`, `ErrorMecaA…E`, `ErrorOppositeDir`, `ErrorNoMovement`, `ErrorOverspeed`). **Aucun champ « limite basse câble » / « butée haute »**.
- `FB_Hmi_BannerFormatter.st:1056-1099` (§5i `[HISTO]`) : masques `16#0020` et `16#0040` absents — **sans défaut** : les causes 5 et 6 sont `Latching := FALSE` (`FB_Safety_Winch.st:315/324`), donc jamais présentes dans `LatchedId AND NOT ErrorId`. **Ne pas traiter ce point comme un bug.**
- `AF_Partie-07_Interface_IHM_v2.3.md:287-292` (lu) : le carrousel publie « **uniquement les défauts actifs bloquants** » ; les exemples de warnings exclus sont **`mou de cable`** et **`surchauffe moteur`** — **les limites basse/haute n'y figurent pas**. `HasAlarm` = « au moins un défaut actif bloquant (**SafeStop / PowerCutOff / interlock**) » (`:296`).
- `FB_Safety_Winch.st:563-564` (lu) : la limite basse câble **est un interlock** (`DescendPermit := FALSE`) → au sens d'AF-07 §6, **elle relève du carrousel**. L'exclusion codée **dévie de la spec**.
- `TOOLS/TEST_AUTO_CI/RESULTS/J_SUPERVISION/tests/test_fb_hmi_bannerformatter.st:174-190` (lu) : `TC-P07-023` pose `WinchM1Safety.CableLimitDescent := TRUE` **en même temps** qu'une perte codeur et attend `Count = 1` (`'1/1 [M1] Codeur absolu COD1 non detecte (ECAT)'`). **Contrainte de non-régression dure** : toute entrée carrousel ajoutée pour la limite basse doit être gatée `AND EncM1Valid` (patron des enfants §5a), sinon ce TC casse.

### 🧪 Reproduction par exécution (PREUVE, 2026-09-20)

Scénario exploratoire **hors CI officiel** (skill `troubleshooting` §4ter) :
`TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/DSH05_T255D_FDC_BAS/`
(`tests/run.py` = registre éphémère hors dépôt, sources officielles ; lancement **un cas à la fois**,
le pool multi-processus du runner étant refusé sous sandbox).

**1) PRODUCTEUR — `FB_Safety_Winch`, cause limite basse câble **seule** (`-fb FB_Safety_Winch`)**

| Test | Assertion | Résultat |
|---|---|---|
| `T255D-PROD-1` | `Fault.Error` (vue LIVE) = TRUE | **PASS** |
| `T255D-PROD-2` | `Fault.ErrorId = 16#0040` **et** `Fault.Latched = FALSE` | **PASS** |

Entrées : `Enable := TRUE`, `CablePosM := -50.1 <= CfgCableLimitDescentM := -50.0`, `InReferencingMode := FALSE`,
aucun bypass, encodeur disponible, thermiques sains, capteur haut libre (NC = TRUE), aucune commande.
⇒ **`Error = TRUE` avec `Latched = FALSE`** : une limite basse câble seule **allume** la vue publiée
**sans aucun défaut latché** (`FB_FaultCore.st:49-57` : `Error := (ErrorId <> 0)`).

**2) CONSOMMATEUR — harnais `FB_TestHarness_PRG_07` (`-fb PRG_07_Supervision`)**

Injection de l'état publié par le producteur : `WinchData.WinchM1/M2Safety.Error := TRUE`,
`ErrorId := 16#0040`, `CableLimitDescent := TRUE`, `DescendPermit := FALSE`, `AscentPermit := TRUE`,
mode `MAINT_N1`, joystick relâché, réseau sain.

| Test | Assertion | Résultat |
|---|---|---|
| `T255D-REPRO-M1-A1` | `HasAlarm OR SpecialConditionText <> ''` | **FAIL** — `expected TRUE, got FALSE` |
| `T255D-REPRO-M1-A2` | `OperatorActionText <> '[JOYSTICK] Appuyer homme-mort au neutre'` | **FAIL** — le texte vaut **exactement** ce rappel joystick |
| `T255D-REPRO-M2-A1` | idem M1 | **FAIL** — `expected TRUE, got FALSE` |
| `T255D-REPRO-M2-A2` | idem M1 | **FAIL** — texte = rappel joystick |

`1 FB testé, 0 PASS, 1 FAIL` · rapports dans `…/DSH05_T255D_FDC_BAS/reports/`.

⇒ **RC1 et RC2 prouvées par exécution de bout en bout** : la cause allume le voyant, **aucun canal du
bandeau ne l'expose**, et le texte d'action reste un **rappel joystick générique** alors que l'action
autorisée est la **montée**. Après correctif, ces 4 tests doivent passer au vert (AC3).

> ⚠️ **Obstacle CI constaté (à traiter avant AC3/AC4 sur le test unitaire du bandeau)** : l'entrée de
> registre `FB_Hmi_BannerFormatter` (`TOOLS/TEST_AUTO_CI/scripts/config/registry.yaml:620`) référence
> `CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/ST_ChainDredgingAssist.st`, **absent de `CODE/`**
> (il ne subsiste que dans `CODE_BACKUP/` et les worktrees). Conséquence :
> `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_Hmi_BannerFormatter` **échoue en conversion**
> (`FileNotFoundError`), donc les TC-P07-0xx ne s'exécutent pas dans l'arbre principal. La reproduction a
> donc été portée par le harnais `PRG_07_Supervision`, qui est **vert 3/3** (baseline mesurée le 2026-09-20).

> 🔎 **Défaut de baseline découvert dans ces TC morts** : `TC-P07-020` (`test_fb_hmi_bannerformatter.st:94-107`)
> attend `'[M1] mou de cable'` dans le carrousel actif alors que ce littéral **n'existe plus** dans
> `FB_Hmi_BannerFormatter.st` — seul subsiste `'[HISTO] [M1] ErrorID:04 - mou de cable'` (`:1071`).
> Ce TC est donc **structurellement rouge** à la date du 2026-09-20 et ne peut pas servir d'ancre de
> non-régression en l'état. Toute remise en état de cette assertion est une décision humaine (elle
> documente la décision 2026-09-01), jamais une retouche silencieuse d'agent.

### 🧭 Hypothèses de l'orchestrateur — MESURÉES, une par une (2026-09-20)

Cas ajoutés : `tests/run.py --case banner-hyp` (registre éphémère) et `--case banner-ref` (fichier de test **officiel** du bandeau).

| Hypothèse du brief CC01 | Protocole | Résultat mesuré | Verdict |
|---|---|---|---|
| « `AnyFaultActive` agrège des `.Error` **latchés** ⇒ une limite basse seule ne l'allume pas » | `--case producer` : limite basse câble **seule** | **PASS 2/2** : `Fault.Error = TRUE`, `ErrorId = 16#0040`, **`Latched = FALSE`** | ❌ **réfutée** |
| **(A)** défaut latché **masqué** par un `*Valid = FALSE` | `--case banner-hyp` A1 (matériel sain) vs A2 (même cause + codeur M1 perdu) | A1 : `'1/1 [M1] ErrorID:09 - MecaB - arret non confirme apres stop'` (**visible**) · A2 : `Count = 1`, `'1/1 [M1] Codeur absolu COD1 non detecte (ECAT)'` (**la cause bloquante MecaB a disparu**) | ✅ **(A) existe et est réelle** — mais **elle affiche un PARENT** : l'opérateur n'est **jamais** devant un `HasAlarm = FALSE` |
| **(B)** source sans entrée `AlarmCount` (piste `JOY1 :547`) | lecture du `VAR_INPUT` du formateur (`:11-81`) | **aucune entrée** ne porte le défaut fonctionnel joystick (calibration bit0, capteur hors plage bit1, perte bus bit2 — cf. `PRG_07:574-578`) | ✅ **(B) existe** — mais sujet = joystick, **pas** la limite basse (→ T220) |
| **Terrain FDC bas** | `--case consumer` | **FAIL 4/4** : `HasAlarm = FALSE` **et** `SpecialConditionText = ''`, action = rappel joystick | ✅ **mécanisme C** |

**Discriminant décisif entre (A) et le cas terrain** : en (A) le bandeau n'est **pas vide** — il affiche l'alarme **parente** (`[ECAT]`, `[IO]`). Le constat terrain est un bandeau **vide** (`HasAlarm = FALSE`). (A) est donc **incompatible avec le symptôme rapporté**, et (C) en rend compte exactement.

### 📉 Baseline RÉELLE des TC officiels du bandeau (mesurée, registre réparé localement)

`--case banner-ref` (fichier de test **officiel non modifié**, entrée de registre réparée **localement seulement**) :
**15/19 PASS — 4 FAIL pré-existants** : `TC-P07-020`, `TC-P07-006`, `TC-P07-008`, `TC-P07-031`.

⇒ La note `TASKS.yaml:2539` (« 3 TC pré-existants rouges ») est **confirmée et précisée : 4**, tous dans la famille « `[M1] mou de cable` comme alarme **active** » (littéral supprimé du formateur par la décision 2026-09-01) plus `TC-P07-031` (bit latché AX_STAB).
⇒ **AC4 ne peut pas reposer sur ces TC** : ils étaient rouges **avant** le lot (et invisibles, car l'entrée de registre ne compilait pas). Ancres réellement vertes et exécutables : `PRG_07_Supervision` **3/3** + `TC-P07-023` (qui pose `CableLimitDescent := TRUE`, **PASS** — confirme que la contrainte `AND EncM1Valid` protège ce cas).

**Réparation locale du registre (constat pour D4)** : l'entrée `FB_Hmi_BannerFormatter` cumule **13 sources absentes** (tout le dossier `CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/`, retiré) **et** une source manquante non déclarée (`E_CycleDepthStopMode.st`, requise par `ST_CycleCfg.st` qu'elle liste). Sans ces deux réparations, les 19 TC du bandeau sont **morts** — aucune exécution possible, donc aucune détection des 4 rouges.

### 🔍 Revue indépendante read-only (2026-09-20) — constats et suites

| Constat | Disposition |
|---|---|
| **MAJOR-1** `CableLimitDescent` = comparaison **brute de projection**, sans bypass (`FB_WinchStateProjection.st:217-218/230`) ⇒ **fausse alarme** sous `BypassCableLimitSwitch` et action « remonter » alors que la descente est autorisée | ✅ **CORRIGÉ** : lecture du **bit 6 sur `ErrorId`** (`CST_WinchErrorIdCableLimitDescent := 16#0040`) dans le carrousel **et** dans l'action ; ancre de non-régression `TC-P07-043` (champ brut seul ⇒ **aucune** alarme) |
| **MAJOR-2** G506 raisonnait par **source** : un nouveau bit muet sur une source connue passait, et supprimer une ligne de table supprimait l'exigence (faux PASS reproduit par le relecteur) | ✅ **CORRIGÉ** : complétude **par bit**, vérifiée contre le **producteur** (`FB_Safety_Winch.instCauses[i].Texte`, 16 causes) ; preuve : table privée du bit 6 ⇒ **FAIL « BIT NON CARTOGRAPHIE … c'est exactement le bug T255-D »** |
| **MAJOR-3** entrée registre `FB_TroubleshootingView` toujours inutilisable | 🟡 **PARTIELLE** : 5 sources ajoutées (enum + 4 DUT IHM) ; cascade de 10+ types manquants ensuite ⇒ **arrêt borné**, hors périmètre T255-D (0 source morte dans tout le registre) |
| **MINOR-1/2** bit 5 : DI **commune** M1/M2 (2 alarmes pour 1 capteur) et état **normal** de fin de course (fatigue d'alarme) | ✅ **CORRIGÉ** : bit 5 **retiré du carrousel**, désormais **exemption nominative** motivée dans G506 (état normal, DI commune, action déjà publiée par « Montée interdite - limite haute ») |
| **MINOR-3** branche d'action court-circuitant `DISABLE` (action inexécutable) | ✅ **CORRIGÉ** : branche placée **après** les prérequis (mode `DISABLE`, homme-mort) ; ancre `TC-P07-044` (`DISABLE` ⇒ « Sélectionner un mode ») |
| **MINOR-6** citations périmées | ✅ **CORRIGÉ** (commentaires) |
| **MINOR-7** commentaires faux sur une « fuite d'état entre tests » | ✅ **CORRIGÉ** — et **confirmé par les faits** : le TC M2 échouait justement parce qu'il dépendait de l'état posé par M1 (setup régénéré par cas) ; entrées reposées explicitement |
| **MINOR-4** bump AF vs `CODE_QUALITY_STANDARDS.md:26` | ⏳ **remonté** : D2 = mise à jour en place sans dérogation écrite au standard ⇒ **arbitrage** (dérogation ou `_v2.4`) |
| **MINOR-5/8/9** 4 TC rouges (T335), G408 pré-existant, suppressions de renommage | ⏳ **remontés** (hors périmètre ; G408 non exempté : une allowlist n'est pas une décision d'agent) |
| INFO : `G430` relevait mes commentaires de dev-dans-le-code | ✅ **CORRIGÉ** : historique retiré des commentaires (§2ter), comportement seul décrit |

**Conformités confirmées par la revue** : aucun masquage d'un message safety par la nouvelle branche · gardes `EncMxValid` cohérentes · littéraux ≤ 40 car. (plafond G408 70) · **aucune variable** nouvelle (1 `VAR CONSTANT` locale) · bundle plus récent que tous les `.st`.

### 📈 Résultats après revue et corrections

| Suite | Avant lot | Après lot | Après revue |
|---|---|---|---|
| `PRG_07_Supervision` (harnais officiel) | 3/3 | 5/5 | **5/5** |
| `FB_Hmi_BannerFormatter` (fichier officiel) | 15/19 | 18/22 | **20/24** (5 TC T255-D verts, mêmes 4 rouges) |
| Exploratoire `--case consumer` (assertions d'origine) | 0/4 | 4/4 | **4/4** |
| Exploratoire `--case producer` | 2/2 | 2/2 | **2/2** |
| `G506` | (n'existait pas) | PASS | **PASS** (16 causes/bit, 7 exemptions) |
| `G200` liaison | PASS | PASS | **PASS** (0 erreur) |

### Chronogramme (événements × signaux — séquence rapportée 🟡, non mesurée)
| <nobr>Événement</nobr> | `CablePosM` vs `CfgCableLimitDescentM` | `ErrorId` bit6 | `DescendPermit` | `AnyFaultActive` | `AlarmBanner.HasAlarm` | `OperatorActionText` |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| T1 Descente normale | `>` | 0 | TRUE | FALSE | FALSE | `[JOYSTICK] Déplacement en cours` |
| T2 Franchissement butte basse | `<=` | 1 | FALSE | **TRUE** | **FALSE** | `[JOYSTICK] Déplacement en cours` |
| → joystick **maintenu** en descente | `<=` | 1 | FALSE | TRUE | FALSE | `[TREUIL] Descente interdite - Limite basse cable` ✅ (seul cas visible) |
| T3 joystick **relâché** (cas terrain) | `<=` | 1 | FALSE | **TRUE** | **FALSE** | `[JOYSTICK] Armé - actionner axe` ❌ cause absente |

---

## 7. 🏁 Conclusion

### Cause racine (RC1 — alarme muette) — cause du symptôme principal
Le carrousel d'alarmes est le **seul** canal du bandeau qui publie un défaut **actif**, et il **exclut explicitement** les causes 5 et 6 de `ST_SafetyWinch.ErrorId` (respectivement `16#0020` « Fin de course haut capteur » et `16#0040` « Limite basse cable atteinte ») :
- décision écrite dans le code : `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:812-816` ;
- décodage effectif : `:817-849` (§5a/§5b) — bit6 absent ;
- l'agrégat du voyant, lui, **inclut** la cause : `CODE/M_MAIN/PRG_07_Supervision.st:537-547` (via `FB_WinchStateProjection.st:236`).

D'où : **`AnyFaultActive = TRUE` et `AlarmBanner.HasAlarm = FALSE` au même scan**. Et cette exclusion **dépasse la spec** `AF-07 v2.3 §6` (`:287-292`), qui n'exclut nommément que `mou de cable` / `surchauffe moteur`, alors que la limite basse câble **est un interlock bloquant** (`FB_Safety_Winch.st:563-564`).

### 📋 Couverture exacte des bits de `ST_SafetyWinch.ErrorId` (mesurée dans le code)
| Bit | `16#` | Cause (`FB_Safety_Winch.st`) | Latching | Carrousel **actif** (§5a/§5b) | `[HISTO]` (§5i) |
|---|---|---|---|---|---|
| 0 | `0001` | perte com opérateur | non | ✅ `:817` | ✅ `:1061` |
| 1 | `0002` | perte codeur | **oui** | ✅ `:820` | ✅ `:1064` |
| 2 | `0004` | surchauffe moteur | **oui** | ❌ | ✅ `:1067` |
| 3 | `0008` | mou de câble | non | ❌ | ✅ `:1070` |
| 4 | `0010` | rotation phases | **oui** | ✅ `:823` | ✅ `:1073` |
| **5** | **`0020`** | **FdC haut capteur atteint** | non | ❌ | ❌ **impossible** (non latchée) |
| **6** | **`0040`** | **limite basse câble atteinte** | non | ❌ | ❌ **impossible** (non latchée) |
| 7-9, 11-15 | … | MecaA/B/C, MecaD, MecaE, sens opposé, absence mouvement | oui | ✅ `:826-849` | ✅ |
| **10** | **`0400`** | **surchauffe frein** | **oui** | ❌ | ✅ `:1085` **seulement après disparition** |

**Lecture** : les bits **2 et 3** sont exclus **conformément à la spec** (warnings nommés). Les bits **5, 6 et 10** sont exclus **au-delà de la spec** :
- **bits 5 et 6** : cause **non latchée** ⇒ **invisible dans TOUS les états** (jamais dans `LatchedId`) ⇒ **trou total**. C'est le cas terrain T255-D (bit 6).
- **bit 10** (**surchauffe frein**, latchée) : visible en `[HISTO]` **seulement une fois la cause disparue** ⇒ tant que le frein est chaud, **rien** n'est affiché alors que `AnyFault` est allumé. **C'est exactement la famille du REX `MES-032` / `C1-ANYFAULTACTIVE-EXHAUSTIF` cité par l'orchestrateur** — donc même famille que T255-D, et **pas** un cas « latché masqué par un `*Valid` ».
- **cas (A) mesuré** (`--case banner-hyp`) : quand `EncM1Valid = FALSE`, l'entrée **active** de `MecaB` (`:829`, gardée par `EncM1Valid`) est **sautée** et remplacée par le **parent** `[ECAT]` — masquage **par conception** (`AF-07 §6:321`). La cause **spécifique** disparaît, mais l'opérateur garde une alarme ⇒ **pas** un cas de silence (donc pas le cas terrain).

### Cause racine (RC2 — action opérateur muette sur la cause)
Le repli annoncé par la décision (`:813-816`, « ils restent visibles via `OperatorActionText`/`SpecialCondition` ») est **inopérant** pour la limite basse :
- le seul libellé qui la nomme (`:656-658`) est **imbriqué** sous `DirectionBlocked AND CurrentDirection < 0` (`:648-649`) : il faut **maintenir une commande de descente** pour le voir — or en butte basse l'action autorisée est la **montée** ;
- `SpecialConditionText` (`:359-382`) n'a **aucune** branche limite basse câble ;
- la branche **ne nomme pas le treuil** concerné (M1 OR M2, `:656`), alors que l'exigence est « quel treuil » ;
- priorité : `LegalLimitReached` (`:653-655`) et `WinchDescentLockedByM3` (`:650-652`) **masquent** la limite câble quand ils sont vrais.

### Cause racine (RC3 — trou structurel, générique → AC6, non corrigé ici)
`WinchM1Safety.Error = WinchM1Ref.Fault.Error OR SafetyM1.Fault.Error` mais `WinchM1Safety.ErrorId = SafetyM1.Fault.ErrorId` **seul** (`FB_WinchStateProjection.st:236-237`) : toute cause portée par `FB_Winch` allume `AnyFaultActive` **sans aucun décodage possible** au bandeau (ex. `FB_Winch.st:124-126` « Configuration table des paliers vitesse invalide », latchée → voyant allumé à vie, zéro message).

### Statut
**RÉSOLUE au sens diagnostic** (cause racine prouvée fichier:ligne **et reproduite par exécution** —
4 tests rouges `T255D-REPRO-*`). **Correction NON appliquée** : arrêt de validation humaine requis
(mission T255-D, point d'arrêt n°2).

### 🚨 Écart de cadrage majeur réfuté par le code (brief CC01 §3.2)
Le brief affirme : « `AnyFaultActive` agrège `.Error` (**défauts latchés**) — il **ne contient PAS** les
causes vives de permis (`CableLimitDescent`, `LimitLegalReached`, `CauseTopLimitSwitchActive`) ⇒ une
limite basse seule **n'allume donc PAS** `AnyFault` ; si le voyant s'allume, c'est qu'un **défaut latché**
s'est ajouté ». **C'est FAUX**, prouvé **trois fois** :
- code : `FB_FaultCore.st:49-57` → `Fault.ErrorId` = bitfield des `Causes[i].Active` **maintenant**, et
  `Fault.Error := (Fault.ErrorId <> 0)` → `.Error` est la vue **LIVE**, pas la vue latchée
  (`Latched`/`LatchedId` est la vue latchée, `FB_FaultCore.st:72-81`) ;
- exécution, **producteur** (`T255D-PROD-1`/`-2`, `-fb FB_Safety_Winch`) : limite basse câble **seule**
  ⇒ **`Fault.Error = TRUE`**, `ErrorId = 16#0040`, **`Fault.Latched = FALSE`** (2/2 PASS) ;
- exécution, **consommateur** (`T255D-REPRO-M1-A1`/`-M2-A1`) : avec cet état publié, le bandeau reste
  muet (`HasAlarm = FALSE`, `SpecialConditionText = ''`) ⇒ **la limite basse seule suffit à allumer le voyant**.

⚠️ **Nuance à ne pas perdre** : certaines **causes** sont latchées à l'intérieur du FB (`MecaA/B/C/D/E`,
codeur, thermiques : `instCauses[i].Latching := TRUE`), donc leur bit **persiste** dans `ErrorId`
jusqu'au `Reset` — ce qui donne l'impression d'une vue latchée. Les causes **non latchées** (bits 3, 5, 6 :
mou de câble, FdC haut capteur, limite basse câble) allument `Error` **tant qu'elles sont actives** et
retombent seules. La vue `.Latched`/`.LatchedId` est **distincte** et n'est pas ce qu'agrège `AnyFaultActive`.

⇒ Les mécanismes candidats « A » (défaut latché masqué par un flag `*Valid`) et « B »
(`AnyFaultActive` sans entrée d'alarme, piste joystick) du brief **ne sont pas** la cause du cas terrain :
le mécanisme réel est **C — une cause LIVE de permis est agrégée par `.Error` et n'est décodée par aucun
canal du bandeau**. Le cas « B » existe bien par ailleurs (voir inventaire ci-dessus, joystick et modes) :
il est **signalé**, pas corrigé.

### Inventaire des autres défauts muets (AC6 — signalés, non corrigés)
| Cause agrégée dans `AnyFaultActive` (`PRG_07:537-547`) | Décodage bandeau | Rattachement |
|---|---|---|
| `GVL_IHM.JOY1Joystick.State.Error` (`PRG_07:547`) | **aucun** — le formateur n'a **pas** d'entrée `ErrorId` joystick | **T220** |
| `PRG_03_Modes_Cycle.Data.ModesFault.Error` / `.Latched` (`PRG_07:539-540`) | aucun libellé carrousel ; seulement un motif de bascule en `SpecialCondition` (`:359-361`) | **T220** |
| `FB_Winch.Fault.Error` (motion) via `Safety.Error` (`FB_WinchStateProjection.st:236`) | **structurellement indécodable** : `ErrorId` (`:237`) ne porte que la sécurité ; ex. `FB_Winch.st:124-126` « Configuration table des paliers vitesse invalide » (latchée) | **T243** |
| `WinchM1/M2Safety` cause **bit5** `16#0020` « Fin de course haut capteur atteint » (`FB_Safety_Winch.st:309-316`) | **aucun** (§5a/§5b décodent bits 0-4 puis 7-15) | **T255-D** (même famille, à traiter avec la limite basse) |
| `LimitLegalReached` (limite légale) | interlock **sans cause** dans `ErrorId` ⇒ n'allume **pas** le voyant ; message uniquement sous commande de descente (`:653-655`) | **T220 / T243** |
| Défauts M1/M2 `[HISTO]` `16#0020` / `16#0040` (§5i) | absents — **NON un défaut** : ces causes sont `Latching := FALSE`, jamais dans `LatchedId` | — |

---

## 8. 🛠️ Proposition de correction

> ⚠️ **Aucun code modifié.** Validation humaine obligatoire avant implémentation.

- **Option 1 (immédiat, sans code — dépannage opérateur)** : en butte basse, **tirer la montée** ; ne pas relâcher puis attendre une information du bandeau (elle n'existe pas dans ce cas). *Risque* : aucune information ne distingue cette situation d'un arrêt normal → perte de temps MES, et un opérateur peut conclure à tort à un blocage machine.
- **Option 2 (définitif, recommandée — périmètre `FB_Hmi_BannerFormatter.st` uniquement)** :
  1. **AC2-alarme** : publier la cause au carrousel (§5a/§5b) — `[M1] Limite basse cable atteinte` / `[M2] …`, **gaté `AND EncM1Valid` / `AND EncM2Valid`** (patron des enfants, protège `TC-P07-023`). Conforme `AF-07 §6` (interlock = bloquant) — **lève une déviation spec**.
  2. **AC2-action** : rendre le libellé limite basse **atteignable sans commande** (sortie de l'imbrication `DirectionBlocked`) **et** le publier dans `SpecialConditionText` (ex. `ATTENTION: Limite basse cable M1 - montee autorisee`), en **nommant le treuil**.
  3. **AC5-guard** : nouveau gate `G506_check_anyfault_banner_labels.py` (numéros `G504`/`G505` réservés à T291-B ; `G500` est **déjà dupliqué** dans `scripts/`) : toute cause agrégée dans `AnyFaultActive` doit avoir un libellé bandeau non vide, **liste d'exemptions nominative** (cause → T220/T243) affichée en warning, enregistré dans `PLANS` de `run_all_gates.py`.
  *Risque* : élargit le carrousel → vérifier `TC-P07-020/023`, `G408` (longueur messages IHM) et `G407` (pire cas `CONCAT`).
- **Option 3 (hors scope, à ne pas faire ici)** : retirer la cause de `AnyFaultActive` pour « éteindre » le voyant — **refusée** : masquerait un interlock réellement actif (contraire au sens d'`AnyFault`).
- **⚠️ Validation requise** : **[humaine]** — arbitrage ① carrousel (Option 2.1, touche `AF-07 §6`) vs champs 3/4 seuls (2.2) ; ② mise à jour de `AF_Partie-07` (version en place ou `_v2.4`).

---

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ **Hand-off humain** : la correction (§8) doit être **validée par l'humain** avant application.

À prouver après GO (mission T255-D, phases 3-6) :
- **Reproduction déjà acquise (AVANT correctif)** : 4 tests rouges `T255D-REPRO-M1-A1/A2`, `T255D-REPRO-M2-A1/A2` dans `RESULTS/_TROUBLESHOOTING/DSH05_T255D_FDC_BAS/`, sortie brute citée en §6.
- **AC3** : mêmes 4 tests **verts après** correctif, **sans modification des assertions** ; puis promotion du scénario dans le test enregistré (`RESULTS/M_MAIN/tests/test_prg_07_supervision.st`, harnais `FB_TestHarness_PRG_07`).
- **AC4** : baseline mesurée le 2026-09-20 — `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb PRG_07_Supervision` = **PASS 3/3** (les 3 cas existants doivent rester verts). ⛔ Le test unitaire du bandeau (`--fb FB_Hmi_BannerFormatter`) **ne peut pas s'exécuter** (source manquante au registre, cf. §6) ⇒ décision humaine requise pour le réparer.
- **AC5** : gate présent, enregistré dans `PLANS`, PASS ; **échoue** si l'on retire le libellé limite basse câble (preuve par retrait).
- **AC7** : bundle + diff bundle + `G200 --report` + `run_all_gates.py --palier C` + `git status --short` propre.

---

## 10. 📝 Journal (chronologique)

- **2026-09-20 13:53** : prise de session, verrou `T255-D` (`TASK_LOCKS.json` `work_locks.T255-D`, acteur `DSH05` depuis le renommage du 15:55 — `DSH01` était en collision, 4 sessions) ; `TASKS.yaml` → `agent: DSH05`, `locked_at`/`updated_at` posés.
- **2026-09-20 15:55** : assainissement nomenclature par CC01 (`T328→DSH03`, `T332→DSH04`, `T255-D→DSH05`) ; dossier exploratoire renommé `DSH05_T255D_FDC_BAS`, références corrigées (contrat, fiche, README, `run.py`).
- **2026-09-20 13:54** : lectures cadrage — `AGENTS.md`, `CODE_QUALITY_STANDARDS §3ter` (`:479-503`), `AF-07 v2.3 §6` (`:287-321`), `TASKS.yaml` (T255-C/T220/T243), `FB_Safety_Winch.st`, `FB_WinchStateProjection.st`, `PRG_07_Supervision.st`, `FB_Hmi_BannerFormatter.st` (1202 lignes), tests CI bandeau.
- **2026-09-20** : écarts de cadrage constatés — `AnyFaultActive` en `PRG_07:537-547` (et non `:424-427`), POU en `CODE/M_MAIN/` (et non `CODE/J_SUPERVISION/`), `ST_IHM_MANU` inexistant (supprimé 2026-07-19).
- **2026-09-20** : RC1 + RC2 + RC3 établies, fichier:ligne ; §5i `[HISTO]` **disculpée** (causes non latchées).
- **2026-09-20 14:0x** : reproduit par exécution (dossier `_TROUBLESHOOTING/DSH05_T255D_FDC_BAS`) — **4/4 tests rouges** ; baseline `PRG_07_Supervision` mesurée **PASS 3/3** ; obstacle registre `FB_Hmi_BannerFormatter` constaté et signalé.
- **2026-09-20 16:0x** : revue indépendante read-only → 3 MAJOR / 9 MINOR ; **MAJOR-1 était un défaut introduit par mon lot** (faux positif sous bypass) : corrigé, bit 6 lu sur `ErrorId` ; G506 durci (complétude par bit contre le producteur, preuve de fermeture) ; bit 5 retiré du carrousel (exemption nominative) ; branche d'action déplacée après les prérequis (mode/homme-mort) ; commentaires nettoyés (§2ter). Résultats finaux : PRG_07 **5/5**, bandeau **20/24** (mêmes 4 rouges), exploratoire **4/4** et **2/2**, G200 **PASS**, G506 **PASS** ; palier C : 5 rouges **hors périmètre** (G300 scratch G390 + `prototypes`, G340 = AF-11 v2.4 de T333, G408 pré-existant, G430 pré-existant, G483 pré-existant).
- **2026-09-20** : écart de cadrage majeur réfuté (§7 : `.Error` est la vue LIVE, `FB_FaultCore.st:49-57`) — mécanismes A/B du brief écartés, mécanisme **C** prouvé. Fiche consignée. **ARRÊT — validation humaine.**

---

📖 **Documentation complète** : `DOC/WFLOW/TROUBLESHOOTING/GUIDE_Troubleshooting.md` (même dossier).

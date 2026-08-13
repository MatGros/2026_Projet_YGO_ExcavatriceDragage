# 🧪 Guide des Gates & Tests (v1.2)

## 🎯 Raison d'être & Responsabilité Unique
- **Problème résolu** : les gates n'existaient que sous forme de titres en dur dans
  `run_all_gates.py` — aucun document n'expliquait ce qu'ils vérifient, ni quel test lancer
  selon la tâche en cours (2026-08-12).
- **Périmètre strict** : quel test/gate lancer, quand, pourquoi, avec quel ID. Ne redéfinit pas
  les règles elles-mêmes (portées par `CODE_QUALITY_STANDARDS.md`/`NAMING_CONVENTION.md`),
  seulement leur déclenchement et leur identifiant.
- **Type de composant** : guide pratique, standard qualité au même titre que le nommage ou la
  déclaration — un humain **et** un agent doivent savoir quel test choisir sans deviner.

---

## 🧭 Sommaire

| <nobr>§</nobr> | Contenu |
|---|---|
| <nobr>1</nobr> | Principe — menu par intention |
| <nobr>2</nobr> | Les 4 paliers (A/B/C/D) — chaque palier possède sa tranche d'ID |
| <nobr>3</nobr> | Table des gates — `ID Gate` organisé par palier |
| <nobr>4</nobr> | Outils hors `run_all_gates.py` — conversion granulaire, compilation |
| <nobr>5</nobr> | Reliquats connus |

---

## 🎯 1. Principe — menu par intention, pas déclenchement automatique caché

Un agent **choisit** le test adapté à sa tâche du moment, il ne subit pas un automatisme cousu
dans un script (ex. un nom de fichier qui déclenche seul une conversion). L'utilisateur peut à
tout moment exiger l'exécution complète, mais ce n'est pas le mode par défaut pendant l'écriture.

Le choix se fait à deux niveaux : **quel palier** (`--palier A|B|C|D`) et, pour un bloc encore
isolé, **quel fichier** (`--files <fichier.st>`). Exécuter sur un fichier unique est légitime :
on ne peut pas valider le programme global à partir d'une seule fonction — on valide le fichier,
et les contrôles globaux sont rejoués sur le bundle complet au palier C.

---

## 🪜 2. Les 4 paliers — un palier = une tranche de centaine

> Règle d'organisation : la tranche d'ID suit **l'ordre du palier** (A=100s, B=200s, C=300s+,
> D=500s), pas la catégorie de contrôle. Avant cette révision, les IDs étaient groupés par
> catégorie (Structure/Style/Doc...) indépendamment du palier — résultat décousu (palier A
> renvoyait vers `200` et `340`, deux tranches sans rapport). Corrigé.

| <nobr>Palier</nobr> | Quand | <nobr>Tranche ID</nobr> | Outils | <nobr>Commande</nobr> | <nobr>Coût</nobr> |
|---|---|---|---|---|---|
| <nobr>**A** — bloc isolé</nobr> | Édition d'un bloc/fonction/FB/ST écrite **de façon isolée**, pas encore reliée à d'autres | <small><code>100</code>-<code>110</code></small> | <small><code>G100_check_code_style.py</code><br><code>G110_check_naming_style.py</code></small> | <small><code>run_all_gates.py --palier A</code></small> | <nobr>instantané</nobr> |
| <nobr>**B** — liens/dépendances</nobr> | Dès que l'édition crée des **liens/dépendances** avec d'autres blocs (appel d'instance, référence croisée) | <small><code>200</code>-<code>220</code></small> | <small><code>G200_check_linkage.py --report</code></small> | <small><code>run_all_gates.py --palier B</code></small> | <nobr>secondes</nobr> |
| <nobr>**C** — fin de lot</nobr> | Plusieurs fonctions codées, lot complet, avant d'annoncer terminé | <small><code>300</code>-<code>420</code></small> | <small><code>run_all_gates.py</code> + génération XML granulaire (`CODE_XML/`) + bundle agrégé (`CODE_XML/CODE_Bundle.xml`, construit **à partir** du granulaire)</small> | <small><code>run_all_gates.py --palier C</code></small> | <nobr>secondes</nobr> |
| <nobr>**D** — sur demande</nobr> | Validation explicite demandée par l'utilisateur, pas systématique | <small><code>500</code>-<code>510</code></small> | <small><code>G500_check_codesys_compile.py</code> (log) / <code>test_codesys_compile.py &lt;Objet&gt;</code> (vrai compilateur, tâche de fond)</small> | <small><code>run_all_gates.py --palier D --codesys-log &lt;build.log&gt;</code></small> | <nobr>minutes</nobr> |

`430`-`490` restent en réserve pour de futurs gates du palier C sans empiéter sur la tranche D.

**Point d'entrée unique par palier** (`run_all_gates.py --palier A|B|C|D`) — le guide est
documenté §1 : menu par intention, l'agent choisit le palier adapté à sa tâche. Sans `--palier`,
le runner exécute tout (comportement historique). `--codesys-log` ajoute G500 à n'importe quel
palier ; `--palier D` sans log affiche un message informatif (validation sur demande) sans échouer.

### Ciblage d'un fichier unique — `--files <fichier.st>`

Un FB, une fonction ou un POU **isolé** (pas encore relié au reste) se vérifie sans le bundle
complet. Seuls les gates applicables à un bloc isolé s'exécutent :

| <nobr>Gate</nobr> | Applicable en `--files` ? |
|---|---|
| <small><code>100</code></small> — style | ✅ oui (scope = le fichier) |
| <small><code>110</code></small> — nommage | ✅ oui (scope = le fichier) |
| <small><code>200</code></small> — liaison | ✅ oui (`--files` du script) |
| <small><code>210</code>-<code>420</code></small> | ❌ globaux (bundle/dépôt) → signalés `[--]` non applicables, s'exécuteront au palier C |

```
python run_all_gates.py --files CODE/TRANSLATION/FB_TranslationOutputInterlock_LD.st
python run_all_gates.py --palier A --files CODE/MAIN/PRG_02_Acquisition.st
python run_all_gates.py --files CODE/TRANSLATION/FB_TranslationOutputInterlock_LD.st CODE/TREUILS/FB_WinchOutputInterlock_LD.st   # multi-fichiers
```

Les gates globaux sont listés comme **non applicables** (sans bloquer) : le mode fichier
prévient explicitement qu'ils seront rejoués sur le bundle complet au palier C.

---

## 📋 3. Table des gates — organisée par palier

> `ID Gate` est le **seul identifiant à retenir**. Numérotation par pas de 10 à l'intérieur
> d'une tranche (comme `NC-0xx`/`TC-Pxx-0xx`) : insertion possible sans renuméroter. Un ID
> retiré n'est **jamais** réattribué.
> ⚠️ **Reliquat** : `run_all_gates.py` affiche encore en interne les anciens titres
> (`GATE 1bis`, `GATE 2quater`...) — le script n'a pas encore été renommé pour utiliser ces IDs
> directement (voir §5). Cette table reste la référence documentaire cible.

### Palier A — `100`-`110`

| <nobr>ID Gate</nobr> | <nobr>Script</nobr> | Vérifie |
|---|---|---|
| <nobr><code>100</code></nobr> | <small><code>G100_check_code_style.py</code></small> | Style (`VAR_OUTPUT`, simulation) |
| <nobr><code>110</code></nobr> | <small><code>G110_check_naming_style.py</code></small> | Nommage IEC 61131-3 (`NC-010`→`NC-070`, informatif, baseline) |

### Palier B — `200`-`220`

| <nobr>ID Gate</nobr> | <nobr>Script</nobr> | Vérifie |
|---|---|---|
| <nobr><code>200</code></nobr> | <small><code>G200_check_linkage.py</code></small> | Liaison — **seule preuve de câblage réel**, `§3` |
| <nobr><code>210</code></nobr> | <small><code>G210_check_cfc_wiring.py</code></small> | Câblage CFC natif |
| <nobr><code>220</code></nobr> | <small><code>G220_check_model_routing.py</code></small> | Routage modèle (Pi Subagents) |

### Palier C — `300`-`420`

| <nobr>ID Gate</nobr> | <nobr>Script</nobr> | Vérifie |
|---|---|---|
| <nobr><code>300</code></nobr> | <small><code>G300_check_structure.py</code></small> | Structure générale du dépôt |
| <nobr><code>310</code></nobr> | <small><code>G310_check_code_structure.py</code></small> | Structure `CODE/` (POU, suffixe, ordre) |
| <nobr><code>320</code></nobr> | <small><code>G320_check_bundle_main_coverage.py</code></small> | Couverture `MAIN` dans le bundle |
| <nobr><code>330</code></nobr> | <small><code>G330_check_type_safety.py</code></small> | Sécurité des types/membres `STRUCT` |
| <nobr><code>340</code></nobr> | <small><code>G340_check_doc_links.py</code></small> | Liens documentaires (`DOC/`) |
| <nobr><code>350</code></nobr> | <small><code>G350_check_hw_name_collision.py</code></small> | Collision noms HW (REX 2026-08-05, `§3bis`) |
| <nobr><code>360</code></nobr> | <small><code>G360_check_direction_change_interlock.py</code></small> | Interlock changement de sens |
| <nobr><code>370</code></nobr> | <small><code>G370_check_position_calibration_wiring.py</code></small> | Câblage position calibrée |
| <nobr><code>380</code></nobr> | <small><code>G380_check_config_persistence.py</code></small> | Persistance config (RETAIN/PERSISTENT) |
| <nobr><code>390</code></nobr> | <small><code>G390_check_bundle_freshness.py</code></small> | Fraîcheur du bundle vs. sources |
| <nobr><code>400</code></nobr> | <small><code>G400_check_bundle_st_syntax.py</code></small> | Syntaxe ST du bundle (no terminator) |
| <nobr><code>410</code></nobr> | <small><code>G410_check_ld_invariants.py</code></small> | Invariants LD — tous les POU `_LD` du bundle (`PRG_06_Outputs_LD`, `PRG_02_Acquisition_LD`, …) |
| <nobr><code>420</code></nobr> | <small><code>pytest</code></small> | Tests gates (`AGENT_WORKFLOW/tests/`) + convertisseur ST→XML (`ST_PLCOPENXML_GENERATOR/tests/`) |

### Palier D — `500`-`510`

| <nobr>ID Gate</nobr> | <nobr>Script</nobr> | Vérifie |
|---|---|---|
| <nobr><code>500</code></nobr> | <small><code>G500_check_codesys_compile.py</code></small> *(optionnel)* | Analyse d'un log de compilation CODESYS déjà produit |
| <nobr><code>510</code></nobr> | <small><code>test_codesys_compile.py</code></small> | Vrai compilateur CODESYS headless (`codesys.exe --noUI`) |

---

## 🛰️ 4. Outils hors gates numérotés — conversion granulaire

Outils de génération, pas de vérification — pas d'`ID Gate` :

| Outil | Rôle | Déclenchement |
|---|---|---|
| <small><code>st_to_pou.py</code></small> | 1 fichier `.st` (FB/PROGRAM) → 1 `<pou>` ST isolé | Choix explicite selon le type réel de l'objet |
| <small><code>st_to_dut.py</code></small> | 1 fichier `.st` (STRUCT/ENUM) → 1 `<dataType>` isolé | Idem |
| <small><code>st_to_ld.py</code></small> | 1 fichier `PRG_*_LD.st` → 1 `<pou>` Ladder isolé | Idem — **le suffixe du fichier ne décide pas seul**, l'agent choisit |
| <small><code>generator.cli --out-dir CODE_XML</code></small> | Régénère le miroir granulaire `CODE_XML/` (1 `.xml` par `.st`, dépendances incluses) | Fin de lot (palier C) |
| <small><code>build_bundle.py</code></small> | Agrège les XML granulaires en un bundle | Fin de lot (palier C), **cible : lit `CODE_XML/`, écrit `CODE_XML/CODE_Bundle.xml`** |
| <small><code>codesys_compilation_diag.py</code></small> | Traduit un code d'erreur `C0xxx` en français + correctif suggéré | Sur un log/texte d'erreur, à la demande (palier D) |

<small>Chemins complets : `TOOLS/AGENT_WORKFLOW/scripts/` pour les 4 derniers, `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/` (ou `generator/`) pour les 3 premiers.</small>

### 📍 Emplacement cible du bundle — `CODE_XML/CODE_Bundle.xml` uniquement

`CODE_Bundle.xml` **ne doit exister que dans `CODE_XML/`** — jamais à la racine de `CODE/`. Il
est **généré à partir** des XML granulaires du même dossier (`CODE_XML/*.xml`), pas produit
directement depuis les sources `.st` par un chemin séparé.

⚠️ **Non câblé aujourd'hui** (reliquat, §5) : `generate_codesys_bundle.py` écrit encore
`CODE_XML/CODE_Bundle.xml`, et `G200_check_linkage.py` (Gate `200`) lit ce même chemin en dur pour ses
vérifications L5. Relocaliser le bundle sans adapter `G200_check_linkage.py` casserait la preuve de
liaison — chantier à faire ensemble, pas en isolation.

---

## ⚠️ 5. Reliquats connus — non traités par ce guide

- **Renommage de `run_all_gates.py`** vers les `ID Gate` ci-dessus (le script affiche encore les
  anciens titres `GATE 1bis`/`GATE 2quater`...) : chantier séparé, pas fait.
- **Relocalisation du bundle** `CODE_XML/CODE_Bundle.xml` → `CODE_XML/CODE_Bundle.xml` : décidée
  (ci-dessus), mais `generate_codesys_bundle.py` et `G200_check_linkage.py` (Gate `200`) doivent être
  adaptés ensemble — pas fait.
- **Palier B en pratique** : `G200_check_linkage.py` existe et fonctionne déjà mid-édition, mais rien
  n'automatise son déclenchement dès qu'un lien apparaît — c'est aujourd'hui une discipline
  documentée, pas un hook.
- **Audit du nombre de tests** (`AGENT_WORKFLOW/tests/` : 13 fichiers · `ST_PLCOPENXML_GENERATOR/tests/` : ~15 fichiers) : pas revu fichier par fichier pour identifier d'éventuels tests redondants ou obsolètes — chantier distinct, à traiter un par un plutôt qu'à la louche.

---

## 📚 Documents liés

- [`CODE_QUALITY_STANDARDS.md §3`](../CODE_QUALITY_STANDARDS.md) — pourquoi `G200_check_linkage.py` est non négociable.
- [`GUIDE_SEQUENCEUR_v1.2.md`](GUIDE_SEQUENCEUR_v1.2.md) — norme d'écriture des séquenceurs (sujet différent, même famille de guides).
- `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md` — criticité C0-C4, voies Fast/Standard/Safety (processus humain↔agent, pas la liste des gates).
- `DOC/WFLOW/RAPPORT_LINTER_ET_WORKFLOW_CODESYS.md` — rapport d'origine ayant introduit `CODE_XML/`, `test_codesys_compile.py`, `codesys_compilation_diag.py`.

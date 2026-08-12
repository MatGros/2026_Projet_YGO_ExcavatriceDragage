# 🧪 Guide des Gates & Tests (v1.1)

## 🎯 Raison d'être & Responsabilité Unique
- **Problème résolu** : les gates n'existaient que sous forme de titres en dur dans
  `run_all_gates.py` — aucun document n'expliquait ce qu'ils vérifient, ni quel test lancer
  selon la tâche en cours (2026-08-12).
- **Périmètre strict** : quel test/gate lancer, quand, pourquoi. Ne redéfinit pas les règles
  elles-mêmes (portées par `CODE_QUALITY_STANDARDS.md`/`NAMING_CONVENTION.md`), seulement leur
  déclenchement.
- **Type de composant** : guide pratique, standard qualité au même titre que le nommage ou la
  déclaration — un humain **et** un agent doivent savoir quel test choisir sans deviner.

---

## 🧭 Sommaire

| <nobr>§</nobr> | Contenu |
|---|---|
| <nobr>1</nobr> | Principe — menu par intention |
| <nobr>2</nobr> | Les 3 paliers (A/B/C) |
| <nobr>3</nobr> | Table des gates — ID numérique cible |
| <nobr>4</nobr> | Outils hors `run_all_gates.py` — palier C et conversion granulaire |
| <nobr>5</nobr> | Reliquats connus |

---

## 🎯 1. Principe — menu par intention, pas déclenchement automatique caché

Un agent **choisit** le test adapté à sa tâche du moment, il ne subit pas un automatisme cousu
dans un script (ex. un nom de fichier qui déclenche seul une conversion). L'utilisateur peut à
tout moment exiger l'exécution complète, mais ce n'est pas le mode par défaut pendant l'écriture.

---

## 🪜 2. Les 3 paliers

| <nobr>Palier</nobr> | Quand | Outils | <nobr>Coût</nobr> |
|---|---|---|---|
| <nobr>**A** — écriture</nobr> | À chaque édition | <small><code>check_code_style.py</code><br><code>check_naming_style.py</code></small> | <nobr>instantané</nobr> |
| <nobr>**B** — fin de lot</nobr> | Avant d'annoncer un lot terminé | <small><code>check_linkage.py --report</code><br><code>run_all_gates.py</code></small> | <nobr>secondes</nobr> |
| <nobr>**C** — validation lourde</nobr> | Changement multi-blocs, avant import CODESYS réel | <small><code>test_codesys_compile.py &lt;Objet&gt;</code> — tâche de fond, non bloquant</small> | <nobr>minutes</nobr> |

Le palier C ne fait **pas** partie de `run_all_gates.py` aujourd'hui (script autonome, orphelin) —
à lancer explicitement, jamais à chaque édition (trop coûteux avec des agents qui itèrent vite).

---

## 📋 3. Table des gates — ID numérique cible (groupes de 100, pas de 10)

> ⚠️ **Statut de transition** : `run_all_gates.py` affiche encore les anciens titres
> (`GATE 1bis`, `GATE 2quater`...) — le renommage du script est un chantier séparé, pas encore
> fait. Cette table est la **cible documentaire** ; la colonne "Titre actuel" permet de faire le
> lien tant que le code n'a pas suivi.

| <nobr>ID</nobr> | Groupe | <nobr>Titre actuel</nobr> | <nobr>Script</nobr> | Vérifie |
|---|---|---|---|---|
| <nobr><code>100</code></nobr> | Structure | <small><code>GATE 1</code></small> | <small><code>check_structure.py</code></small> | Structure générale du dépôt |
| <nobr><code>110</code></nobr> | Structure | <small><code>GATE 1bis</code></small> | <small><code>check_code_structure.py</code></small> | Structure `CODE/` (POU, suffixe, ordre) |
| <nobr><code>120</code></nobr> | Structure | <small><code>GATE 1ter</code></small> | <small><code>check_bundle_main_coverage.py</code></small> | Couverture `MAIN` dans le bundle |
| <nobr><code>130</code></nobr> | Structure | <small><code>GATE 1quater</code></small> | <small><code>check_type_safety.py</code></small> | Sécurité des types/membres `STRUCT` |
| <nobr><code>200</code></nobr> | Style/Liaison | <small><code>GATE 2</code></small> | <small><code>check_code_style.py</code></small> | Style (`VAR_OUTPUT`, simulation) |
| <nobr><code>210</code></nobr> | Style/Liaison | <small><code>GATE 2bis</code></small> | <small><code>check_linkage.py</code></small> | Liaison — **seule preuve de câblage réel**, `§3` |
| <nobr><code>220</code></nobr> | Style/Liaison | <small><code>GATE 2bis-bis</code></small> | <small><code>check_cfc_wiring.py</code></small> | Câblage CFC natif |
| <nobr><code>230</code></nobr> | Style/Liaison | <small><code>GATE 2ter</code></small> | <small><code>check_model_routing.py</code></small> | Routage modèle (Pi Subagents) |
| <nobr><code>300</code></nobr> | Doc/Nommage | <small><code>GATE 2quater</code></small> | <small><code>check_doc_links.py</code></small> | Liens documentaires (`DOC/`) |
| <nobr><code>310</code></nobr> | Doc/Nommage | <small><code>GATE 2quinquies</code></small> | <small><code>check_hw_name_collision.py</code></small> | Collision noms HW (REX 2026-08-05, `§3bis`) |
| <nobr><code>320</code></nobr> | Doc/Nommage | <small><code>GATE 2sexies</code></small> | <small><code>check_direction_change_interlock.py</code></small> | Interlock changement de sens |
| <nobr><code>330</code></nobr> | Doc/Nommage | <small><code>GATE 2septies</code></small> | <small><code>check_position_calibration_wiring.py</code></small> | Câblage position calibrée |
| <nobr><code>340</code></nobr> | Doc/Nommage | <small><code>GATE 2octies</code></small> | <small><code>check_naming_style.py</code></small> | Nommage IEC 61131-3 (`NC-010`→`NC-070`, informatif, baseline) |
| <nobr><code>400</code></nobr> | Persistance | <small><code>GATE 3</code></small> | <small><code>check_config_persistence.py</code></small> | Persistance config (RETAIN/PERSISTENT) |
| <nobr><code>500</code></nobr> | Bundle | <small><code>GATE 4</code></small> | <small><code>check_bundle_freshness.py</code></small> | Fraîcheur du bundle vs. sources |
| <nobr><code>510</code></nobr> | Bundle | <small><code>GATE 4bis</code></small> | <small><code>check_bundle_st_syntax.py</code></small> | Syntaxe ST du bundle (no terminator) |
| <nobr><code>520</code></nobr> | Bundle | <small><code>GATE 4ter</code></small> | <small><code>check_ld_invariants.py</code></small> | Invariants LD `PRG_06_Outputs_LD` |
| <nobr><code>600</code></nobr> | Tests | <small><code>GATE 5</code></small> | <small><code>pytest</code></small> | Tests gates (`AGENT_WORKFLOW/tests/`) + convertisseur ST→XML (`ST_PLCOPENXML_GENERATOR/tests/`) |
| <nobr><code>700</code></nobr> | CODESYS | <small><code>GATE 6</code></small> *(optionnel)* | <small><code>check_codesys_compile.py</code></small> | Analyse d'un log de compilation CODESYS déjà produit |

Numérotation par pas de 10 à l'intérieur d'un groupe (comme `NC-0xx`/`TC-Pxx-0xx`) : insertion
possible sans renuméroter. Un ID retiré n'est **jamais** réattribué.

---

## 🛰️ 4. Outils hors `run_all_gates.py` — palier C et conversion granulaire

Ces outils existent mais ne sont **pas** dans la liste des gates ci-dessus — à invoquer
explicitement selon le besoin, jamais automatiquement :

| Outil | Rôle | Déclenchement |
|---|---|---|
| <small><code>test_codesys_compile.py</code></small> | Vrai compilateur CODESYS headless (`codesys.exe --noUI`), isolé dans un projet temp, `proj.check_syntax()` | Manuel, sur un objet nommé, en tâche de fond |
| <small><code>codesys_compilation_diag.py</code></small> | Traduit un code d'erreur `C0xxx` en français + correctif suggéré | Sur un log/texte d'erreur, à la demande |
| <small><code>st_to_pou.py</code></small> | 1 fichier `.st` (FB/PROGRAM) → 1 `<pou>` ST isolé | Choix explicite selon le type réel de l'objet |
| <small><code>st_to_dut.py</code></small> | 1 fichier `.st` (STRUCT/ENUM) → 1 `<dataType>` isolé | Idem |
| <small><code>st_to_ld.py</code></small> | 1 fichier `PRG_*_LD.st` → 1 `<pou>` Ladder isolé | Idem — **le suffixe du fichier ne décide pas seul**, l'agent choisit |
| <small><code>build_bundle.py</code></small> | Merge plusieurs fichiers/dossiers en un bundle | Sur demande, périmètre choisi |
| <small><code>generator.cli --out-dir CODE_XML</code></small> | Régénère le miroir granulaire `CODE_XML/` (1 `.xml` par `.st`, dépendances incluses) | Avant un import CODESYS ciblé sur un seul objet |

<small>Chemins complets : `TOOLS/AGENT_WORKFLOW/scripts/` pour les 2 premiers, `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/` (ou `generator/`) pour les suivants.</small>

---

## ⚠️ 5. Reliquats connus — non traités par ce guide

- **Renommage de `run_all_gates.py`** vers les IDs numériques ci-dessus : chantier séparé, pas fait.
- **Audit du nombre de tests** (`AGENT_WORKFLOW/tests/` : 13 fichiers · `ST_PLCOPENXML_GENERATOR/tests/` : ~15 fichiers) : pas revu fichier par fichier pour identifier d'éventuels tests redondants ou obsolètes — chantier distinct, à traiter un par un plutôt qu'à la louche.

---

## 📚 Documents liés

- [`CODE_QUALITY_STANDARDS.md §3`](../CODE_QUALITY_STANDARDS.md) — pourquoi `check_linkage.py` est non négociable.
- [`GUIDE_SEQUENCEUR_v1.2.md`](GUIDE_SEQUENCEUR_v1.2.md) — norme d'écriture des séquenceurs (sujet différent, même famille de guides).
- `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md` — criticité C0-C4, voies Fast/Standard/Safety (processus humain↔agent, pas la liste des gates).
- `DOC/WFLOW/RAPPORT_LINTER_ET_WORKFLOW_CODESYS.md` — rapport d'origine ayant introduit `CODE_XML/`, `test_codesys_compile.py`, `codesys_compilation_diag.py`.

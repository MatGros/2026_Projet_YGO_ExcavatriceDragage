# 🗂️ PLAN_TASK — Suivi Planning & Reliquats (v1.0)

> 🎯 **Rôle** : seul document de pilotage projet (jalons, tâches, TBD, questions client). Les `AF_PartieN` restent **spec fonctionnelle pure** — tout ce qui est planning/organisationnel vit ici, pas dans les specs.
> 📥 **Remplace** : `PLAN_Finalisation_v1.0.md` + `v1.1.md` + `SAT_Protocole_Essais_v1.0.md` (les 3 archivés dans `ARCHIVES/Doc/`, contenu ingéré ci-dessous).
> 🗓️ Créé 2026-07-09.

---

## 🧭 Plan d’implémentation orchestré — état courant

> 📌 **Protocole Multi-Agents & Verrouillage (Lock Agent)** :
> Avant de démarrer un travail, l'agent **DOIT** inscrire son identifiant dans la colonne `Lock Agent` et passer le `Statut` à 🔍 ou 🔒 pour signaler la prise en charge et éviter tout travail en doublon.
>
> **Légende des Statuts** :
> - `⬜` : **Libre / À faire** (non commencé, disponible)
> - `🔍` : **Étude / Analyse** (analyse/spec en cours, lecture seule)
> - `🔒` : **En cours de dev (Verrou)** (code en cours d'édition par l'agent)
> - `⏳` : **En attente validation / tests** (codé & bundle généré, en attente de test CODESYS ou confirmation humaine)
> - `⏸️` : **Bloqué / Prérequis** (dépendance externe, décision client ou matériel)
> - `✅` : **Clôturé & Validé** (validé formellement par l'humain et archivé)
>
> **Légende des Identifiants Agents (`Lock Agent`)** :
> `CC-01`/`CC-02` (Claude Code) · `AGY-01`/`AGY-02` (Antigravity/Gemini) · `CDX-01` (Codex/OpenAI) · `PI-01` (Pi/OmniRoute) · `DSH-01`/`DSH-02` (DeepSeek Harness) · `HUM` (Humain/Terrain) · `—` (Libre).
>
> 📌 **Notice** : chaque identifiant est **unique** — un agent ne reprend jamais un identifiant déjà pris. À chaque nouvel agent, on **incrémente** le numéro (ex. `DSH-01` → `DSH-02` → `DSH-03`). Vérifier les identifiants déjà utilisés avant de s'inscrire.

| Ordre | Lot fonctionnel | Tâches | Dépendances / décision | Statut | Lock Agent | Validation utilisateur |
|---:|---|---|---|:---:|:---:|---|
| 1 | Fiabilisation mesure Winch | T84 + T85 + T86 | Fenêtre interne 50 ms ; producteur chaîne codeur ; pulse source générique depuis `PRG_02` ; vitesse opérationnelle | ⏳ | PI-01 | ⏳ Validation code attendue |
| 2 | Assistants Kobold maintenance | T81 + T82 | `FB_DiveSearch` : `0→1→0` ; `FB_ExtractionSequence` : fermeture, palier 1 sur 2 m puis nominal ; hors `FB_Cycle` | ⏳ | PI-01 | ⏳ Validation CODESYS/terrain requise |
| 3 | Garde-fou et calibration paliers | T94 + T95 + T96 | Dépend du lot 1 : mesure vitesse fiabilisée avant calibration ; T96 = mode apprentissage auto (remplace saisie manuelle T95) | ⬜ | — | — |
| 4 | Frein et commande par paliers | T91 + T93 | Étude montée/descente avant code (T87 clos : frein piloté sur contacteurs) | ⬜ | — | — |
| 5 | Reliquats safety | T72 + T73 + T74 | Réévaluer l’état réel du code après les lots précédents | ⬜ | — | — |
| 2A | Interlocks finaux frein / puissance | Lot 3A | `FB_WinchOutputInterlock` + `FB_TranslationOutputInterlock` ; `SafeStop` reste la rampe rapide métier, tests PLC préparés ; qualification CODESYS/simulation à faire | ⏳ | PI-01 | ⏳ Validation CODESYS/terrain requise |
| 7 | Translation M3 — sécurité, sortie moteur, homme-mort | T104 + T105 + T106 + T107 | Audit 2026-08-05 (session M3), 4 lots implémentés dans l'ordre LOT0 → M4 → LOT3 → LOT2, `check_linkage.py`/`check_ld_invariants.py`/bundle PASS à chaque lot | ⏳ | HUM | 🟢 Prêt à tester (mise en service) |
| 6 | Améliorations secondaires | T76 + T77 + T79 + T88 | T78 attend la décision T93 (T75 clos, T84/T85/T86 déjà implémentés au lot 1) | ⏸️ | — | — |
| 8 | Audit doc — lot C4 AU Troubleshooting | Vérifier clôture du lot (§06) | REGISTRE + TEST_DESIGN C4 AU | ⏳ | DSH-01 | ✅ Vérification clôture faite 2026-08-18 : code implémenté (`Step4_ContactorReleased` + préconditions AF01 en lecture seule, 2026-08-14), cohérent avec TEST_DESIGN. ⏳ Essais Watch C4-001→005 non exécutés — validation CODESYS/terrain en suspens |
| 9 | Audit outillage `TOOLS/AGENT_WORKFLOW` | Purge Herdr/Pi, réécriture C0-C4 vers agents natifs, archivage `G220`, nettoyage `PROJECT_WORKSPACE` | Herdr/Pi abandonné (confirmé 2026-08-17) ; C0-C4 rebranché sur antigravity/Codex/forks Claude Code | ✅ | CC-01 | ✅ Validé (revue experte PASS) |
| 10 | Audit `CODE_XML` — reliquats & génération | 4 XML orphelins supprimés, génération rendue atomique (`generate_codesys_bundle.py`) | Bug trouvé en revue : purge non-atomique pouvait faire passer `G200` faussement au vert si le générateur échouait — corrigé et testé (2 scénarios d'échec simulés) | ✅ | CC-01 | ✅ Validé (revue experte PASS) |
| 11 | Audit documentation `DOC/TESTS`, `DOC/WFLOW` | Fusion registre MES (30 entrées, collision `MES-022/023` corrigée), archivage `Architecture/` (migration 7 POU terminée), liens morts corrigés | `ARCHIVES/Doc/` découvert gitignoré (comme `.claude/`/`.vscode/`) — forcé au tracking | ✅ | CC-01 | ✅ Validé (revue experte PASS) |
| 12 | Refactoring Indexation Dossiers `CODE/` (`A_` à `M_`) | T122-A à T122-D (Phases 1 à 4 terminées) | Aligner explorateur CODESYS sur l'ordre d'exécution MainTask (indexation par lettres `A_COMMUN` .. `M_MAIN`) ; plan détaillé dans `AUDIT_Plan_Refactor_Dossiers_Indexes_v1.0.md` | ✅ | AGY-01 | ✅ Validé (revue experte PASS & 100% Gates verts) |
| 13 | Standardisation Déclarations ST & En-têtes concis | T123-STD à T123-M (Terminé) | Rangement variables, flèches ASCII, tags et purge REX intégrale sur 169 fichiers CODE/ (G430 PASS) | ✅ | AGY-01 | ✅ Validé (Code 100% conforme CQS §2) |
| 14 | Encapsulation Bus Inter-PRG par DUTs | T142-P1 à T142-P4 (Phasage étanche) | Migration progressive PRG_02 → PRG_04 → PRG_05 → PRG_06 vers structures `Data : ST_xxxInterPrg` avec validation mécanique unitaire | 🔒 | DSH-02 | 🔓 **Remap PRG_03/04/05/07 vers `Data` validé en simu CODESYS (2026-08-20) : compile + run + treuil + codeurs + translation** · reste : retrait sorties plates PRG_02 (à valider) |

### 🗂️ Chantier Refactoring Indexation Dossiers CODE (T122-A à T122-D)

| Sous-tâche | Phase | Description & Périmètre | Contrat d'exécution | Statut | Lock Agent | Validation |
|---|---|---|---|:---:|:---:|---|
| **T122-A** | Phase 1 | Renommage physique `git mv` des 13 répertoires `CODE/` (`A_COMMUN` à `M_MAIN`) | `TASK_CONTRACT_REFACTOR_DOSSIERS_PHASE1_RENOMMAGE.yaml` | ✅ | AGY-01 | ✅ Validé par l'orchestrateur |
| **T122-B** | Phase 2 | Patch des 8 scripts Python `TOOLS/` & baseline `naming_baseline.json` | `TASK_CONTRACT_REFACTOR_DOSSIERS_PHASE2_PATCH_OUTILLAGE.yaml` | ✅ | AGY-02 | ✅ Validé par l'orchestrateur (PyTest 381 PASS, Baseline OK) |
| **T122-C** | Phase 3 | Patch cartouches documentaires `DOC/AF/` & Rebuild bundle `CODE_Bundle.xml` | `TASK_CONTRACT_REFACTOR_DOSSIERS_PHASE3_DOCS_ET_BUNDLE.yaml` | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G340 PASS, Bundle 170 objets) |
| **T122-D** | Phase 4 | Exécution & Validation des Portails Mécaniques (`run_all_gates.py` A, B, C) | `TASK_CONTRACT_REFACTOR_DOSSIERS_PHASE4_VALIDATION_GATES.yaml` | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200 PASS, G300 PASS, G310 PASS) |

### 🏷️ Chantier Standardisation Déclarations & Cartouches (T123-STD à T123-M)

| Sous-tâche | Périmètre | Contenu du Refactor | Statut | Lock Agent | Validation |
|---|---|---|:---:|:---:|---|
| **T123-STD** | Documentation Standards | Mise à jour `CODE_QUALITY_STANDARDS.md` & `NAMING_CONVENTION.md` | ✅ | AGY-01 | ✅ Normes rédigées & validées |
| **T123-A** | `CODE/A_COMMUN/` (5 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-B** | `CODE/B_AU_SECURITE/` (9 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-C** | `CODE/C_DIAG_RESEAUX/` (2 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-D** | `CODE/D_JOYSTICK/` (4 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-E** | `CODE/E_CODEURS/` (3 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-F** | `CODE/F_MODES/` (2 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-G** | `CODE/G_CYCLE/` (5 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-H** | `CODE/H_TREUILS_BENNE/` (11 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags | ✅ | AGY-01 | ✅ Validé par l'orchestrateur (G200..G410 PASS, logique métier 100% intacte) |
| **T123-I** | `CODE/I_TRANSLATION/` (7 fichiers) | En-têtes concis ≤15L + Ordre VAR + Flèches ASCII (`-->`/`<--`/`*`/`.`) + Tags + purge REX/dates des commentaires (invariants reformulés) + régions `§N` | ✅ | AGY-01 | ✅ Validé (exécutable identique, diff --check PASS) |
| **T123-J** | `CODE/J_SUPERVISION/` (3 FB + GVL + ~50 DUT `_TYPES`) | En-têtes concis ≤15L + Tags + purge REX/dates + régions `§N` | ✅ | AGY-01 | ✅ Validé (exécutable identique, diff --check PASS) |
| **T123-K** | `CODE/K_DEPANNAGE/` (2 fichiers) | En-têtes concis ≤15L + Tags + purge REX/dates + régions `§N` | ✅ | AGY-01 | ✅ Validé (exécutable identique, diff --check PASS) |
| **T123-L** | `CODE/L_SIMULATION/` (7 fichiers) | En-têtes concis ≤15L + Tags + purge REX/dates + régions `§N` | ✅ | AGY-01 | ✅ Validé (exécutable identique, diff --check PASS) |
| **T123-M** | `CODE/M_MAIN/` (7 fichiers) | En-têtes concis ≤15L + Tags + purge REX/dates + régions `§N` | ✅ | AGY-01 | ✅ Validé (exécutable identique, diff --check PASS) |
| **T123-VAL** | Validation & Bundle | `run_all_gates.py` + Régénération `CODE_Bundle_v2.xml` | ⬜ | — | — |

### Règles de conduite

- Un lot à la fois : analyse → plan → validation utilisateur → implémentation agent → contrôle orchestrateur → validation utilisateur.
- Agents d’exécution : scope borné, aucun commit. Revues : lecture seule.
- Aucun nouveau document de pilotage : specs `AF_PartieN`, registres existants, ce plan et `VERSION_HISTORY.md` font foi.
- `TOOLS/OUTILS_ST2PY/` est hors périmètre tant qu’un autre agent y travaille.

---

## 🏁 1. Jalons connus de l'affaire

| Date | Jalon |
|---|---|
| 2026-08-12 | 🤖 Audit du nommage IEC 61131-3 mécanisable (NC-010 à NC-070) révisé (`AUDIT_Nommage_Mecanisable_v1.0.md`) et déployé (`check_naming_style.py`, `GATE 2octies`, `naming_baseline.json`) |
| 2026-08-01 | 🗑️ `CODE/TESTS/` archivé (4 fichiers → `ARCHIVES/Code/TESTS/`) + retrait de l'obligation de test PLC automatique en C3/C4 — détail §2 « Extension 2026-08-01 » |
| 2026-07-28 | 🚀 `v0.5.3_PreCommissioningPrep` — Initialisation nouvelle session de travail, cadrage registre post-MES (`PMS-XXX`), pense-bête client YGO (isolation simu, visu pas-à-pas, dédouanement PLC/Matériel, MAINT_N1 ➔ Auto) |
| 2026-07-27 | 🏁 **Chantier pré-livraison — simulation & diagnostic TERMINÉ** (commits `72a3bbc`→`HEAD`). Détail §1bis. Documents de conduite archivés dans `ARCHIVES/Doc/AUDITS/PreLivraison/` : ce plan redevient l'unique source du pilotage |
| 2026-07-24 | 🎯 **Priorité Demain** — 1) Chargement API + vérification Visualisation IHM (remapping). 2) Qualification purge Bypass Global (M1, M2, M3). 3) Essai du fonctionnement **Capteur Kobold** (contact fond) & IHM. 4) Essai du **Positionneur Translation M3** ("Aller à la position" Trémie/Maintenance/Zone travail). |
| 2026-07-23 | Correctifs terrain — Purge `BypassContactorCheck` (M1, M2, M3), documentation audit `AUDIT_BypassGlobal_Homogenization_v1.0.md` et consignation `MES-004`. |
| 2026-07-22 | `v0.4.27_SupervisionConformityRename` — Renommage complet supervision GVL_IHM + ST_*HMI et conformité suffixes physiques (_M, _Pct, _Hz, _Mps) |
| 2026-07-22 | `v0.4.26_IhmCompatibilityRepair` — Restauration des noms publics IHM historiques : visualisation inchangée |
| 2026-07-15 | `v0.4.8` — IHM_MANU M1/M2 pilotés via `FB_Winch` (rampe/ralentissement natifs, retrait doctrine "Conditional Bypass"), nouvelle limite `CableLimitAscentM1/2_M`, correctifs Méca B (bit8) + benne couplé + `FB_Safety_Translation` (latch défaut) |
| 2026-07-09 | Audit complet + ce `PLAN_TASK` |
| 2026-07-09 | `PLAN_Finalisation_v1.1` (bloquants résolus + priorités actées) + `SAT_Protocole_Essais_v1.0` (protocole recette écrit) — ⚠️ pas encore commités |
| 2026-07-08/09 | `v0.4.4`/`v0.4.5` **IHM_MANU** — mise en service d'urgence (dérogation active, voir §3 ⏸️) |
| 2026-07-08 | `v0.4.0`→`v0.4.3` : simulation stable Winch/Benne + synchro critique Méca E, pré-commissioning câble réel |
| 2026-07-07/08 | Réarchitecture `PRG_00`→`PRG_10` (abandon `PLC_PRG_MAIN`), campagne doc massive, audit cohérence documentaire |
| 2026-07-04 | `PLAN_Finalisation_v1.0` — 1er état des lieux (bloquants, écarts, TBD) |
| 2026-06-30 | Bootstrap projet (init CODESYS, skill workflow, convention nommage) |

---

## 🏁 1bis. Chantier pré-livraison (2026-07-26 → 27) — ce qui a été fait

### ✅ Terminé

| Lot | Contenu |
|---|---|
| **T80** | 🐛 Capteur PV M3 non relié (voie mappée `PosPV_DI_`, lue depuis un stub jamais alimenté) — corrigé |
| **L2/L3** | `GVL_PLC_Tests` (20 `Override*` + 31 lecteurs) supprimée · `FB_Sim_DigitalMirror`, `ST_TestTranslation`, `ST_TestCycle`, `BypassRestoreDone` retirés |
| **L4a→L4d** | Simulation **entièrement débranchée** : 8 conditions `DI OR (SimActive AND NOT …IsReal)`, instances `FB_Sim_*`, flag pilotant `DeadmanRearmTimeout` (figé à `T#10S`) |
| **Renommage E/S** | Convention `<Domaine>_<ÉtatQuandTRUE>_DI` — voir `AUDITS/TABLE_Renommage_IO_v1.0.md` |
| **L5** | **Frontière unique `HwIn`** : toutes les entrées acquises en un seul point (`PRG_00` §0) + refonte de lisibilité (carte des blocages, polarité affichée à chaque étage) |
| **L6** | Banc `FB_SimBench` rebranché **derrière** la frontière · `GVL_Simulation` 25 flags → 1 bit maître + 4 domaines, polarité positive |
| **L7/L8** | `HwSim` exposé (lecture comparée) · gates CI : confinement `GVL_Simulation`, interdiction du forçage hybride, `check_structure`/`check_code_style` réparés · `AF-13 v2.0`, `AF-06 v1.7` |
| **D1** | `FB_Acquisition_Preflight` (verdict d'état machine à l'arrêt) et `FB_Winch_Symmetry` (écarts M1/M2, MES-008) — observateurs purs dans `PRG_11` · correctif libellé `BrakeIsOpen_DI` → `BrakeApplied` |

### 📌 Décisions structurantes actées

| # | Décision |
|---|---|
| **Frontière unique** | La simulation ne complète jamais le réel : elle le **remplace en bloc, par domaine entier**, à un seul endroit. Un domaine est simulé **OU** réel, jamais un mélange |
| **3 outils, 3 besoins** | Bypass IHM = ignorer un défaut sur matériel **présent** · Simulation = fabriquer une valeur pour matériel **absent** · Force natif CODESYS = injecter une panne **ponctuelle** |
| **Pas de comparateur automatique** | `FB_HwCompare`/`HwDelta` abandonné : le modèle n'est pas une vérité de référence. Lecture côte à côte `HwReal`/`HwSim`/`HwIn` + `PRG_11` suffisent. Le verdict est rendu par `FB_Acquisition_Preflight`, qui compare à un **état attendu connu** |
| **Nommage E/S** | Le nom porte l'état vrai (`M1_BrakeIsOpen_DI`). Un nom muet sur sa polarité a coûté un défaut réel (C1) |
| **Une seule convention de polarité** *(révisée 2026-08-03)* | « TRUE = frein **OUVERT** (desserré) » dans toute la chaîne — logique physique directe du frein à manque de courant. **Révocation** de la décision 2026-07-26 (« TRUE = serré » via `BrakeFeedbackInvertLogic`). Plus d'inversion à la frontière : `M1BrakeFeedback = M1_BrakeIsOpen_DI`. Les blocs safety ajustent leurs conditions (`NOT BrakeFeedback` là où ils voulaient « serré »). |
| **Découpage par procédé** *(2026-08, actée)* | 7 POU **par ensemble mécanique**, pas par couche transverse. Chaque procédé porte sa safety dans sa page, visible à côté des blocs métier. ❌ Abandonné : `PRG_SAFETY_CFC` global, `PRG_01_Diagnostics`, `PRG_02_Encoders`, `PRG_AUXILIARY_CFC`, `PRG_TROUBLESHOOTING_CFC`/`PRG_11_Troubleshooting` comme **cibles**. Décision : `AUDITS/Architecture/RU_C4_ARCHITECTURE_PROCEDES.md` · cible : `AF_Partie-02` §2/§4 |
| **`PowerCutOff` agrégé en sortie** *(2026-08, actée)* | Chaque procédé publie **sa demande** ; `PRG_06_Outputs`, seul au plus près des sorties, agrège et coupe. Aucun POU « safety machine globale ». La chaîne AU matérielle reste indépendante et prioritaire (Partie 01) |
| **État AU acquis en entrée** *(2026-08, actée)* | L'état AU est un **fait d'entrée qualifié** acquis dans `PRG_02_Acquisition_CFC` (visibilité maintenance). ⚠️ Acquisition de l'état ≠ lieu d'action : le FB agit sur les sorties via la barrière finale |
| **Interdictions portées par qui subit** *(2026-08, actée)* | Une interdiction appartient au procédé qui la **subit** (ex. interdire M3 selon un état benne → `PRG_05_Translation_CFC`). Les Modes **distribuent des autorisations**, ils ne portent pas l'interdiction métier |

### ⬜ Abandonné / différé

`FB_MotionInhibit` (doublon de `PRG_11`) · `FB_FirstFault` (différé — utile seulement si les cascades gênent en essai) · `FB_HwCompare` (voir ci-dessus)

---

## 🧩 2. Tâches / Features — état

### ✅ Fait
Joystick · Winch/SpeedStep · Benne · Encoder (pipeline) · Safety_Winch (14 bits) · Modes · Diag CanOpen/EtherCAT · Brake/Ramp · GVL_Simulation

### ✅ Priorités sécurité v1.1 — réalisées
| # | Sujet |
|---|---|
| 2.A | Homme-mort joystick absent en `SEMI_AUTO` → asservir `StartStop` M1/M2/M3 à `DeadmanArmed` + déflexion |
| 2.B | `SafeStopActive` non intégré dans `FB_Cycle` → transition `ERROR_HOLD` manquante |

### 🟡 Partiel
| Brique | Manque |
|---|---|
| `FB_WinchSync` | Surveillance seule (assumé), pas de correction active |
| `FB_Translation` | ✅ Cinématique M3, cinq capteurs, décodage position et ralentissement PV intégrés ; essais terrain restant à réaliser |
| `FB_Safety_Translation` | ✅ Limites Trémie/Maintenance et incohérence capteurs intégrées ; validation banc restant à réaliser |
| `FB_Cycle` | ✅ `Error`/`ErrorId`, `ResetEdge`, `ERROR_HOLD` et stabilisation double codeur intégrés ; essais terrain restant à réaliser |
| `FB_Input`/`FB_Output` (COMMUN) | Existent mais pas intégrés dans Winch/Translation (logique contacteur dupliquée) |

> ℹ️ Cette table conserve les briques historiquement partielles pour assurer la traçabilité. Pour l'état
> courant, la section « État réel du plan » et les lignes T33 à T39 font foi.

### 🔄 État réel du plan — mise à jour 2026-07-18

| Domaine | État actuel | Suite prévue |
|---|---|---|
| Translation M3 / cinq capteurs | ✅ Implémenté et exposé dans `GVL_IHM.TranslationM3` | Essais CODESYS puis terrain |
| Translation M3 / sécurité | ✅ Limites Trémie/Maintenance + incohérence capteurs + SafeStop/PowerCutOff | Vérifier les réactions sur banc |
| Cycle semi-auto / Kobold | ✅ Contact, remontée synchronisée et reprise homme-mort raccordés | Finaliser la stabilisation et les cas d'obstacle |
| IHM cycle et Translation | ✅ GVL de commande, état, diagnostic et simulation | Étendre aux Codeurs/Homing et aux tests opérateur |
| Vitesse réelle des codeurs | ✅ Calcul m/s, surveillance et exposition IHM réalisés | Valider les seuils sur site |
| Remontée cycle / contrôle dynamique | 🟠 Comparaison vitesse M1/M2 raccordée ; seuil/tempo à 0 donc inactive | Définir puis activer les paramètres après essais terrain |
| Paliers / charge estimée | ✅ 5 plages, tableau 2D et garde-fou implémentés | Calibrer et activer progressivement sur site |
| IHM_MANU | ✅ Supprimé définitivement (2026-07-19) — pilotage manuel exclusivement MAINT_N1/N2 + joystick homme-mort | Rien — historique dans `IHM_MANU_Journal_Modifications.md` |
| Documentation architecture | ✅ Réalignée avec l'orchestration `PRG_00`→`PRG_10` | Contrôle des liens et chemins réalisé ; en-têtes historiques à traiter séparément si nécessaire |
| Visu graphique | ❌ Hors périmètre livré, GVL disponible | À traiter séparément avec l'IHM supervision |

### ⏸️ Différé assumé (pas un trou béant)
`PRG_AUXILIARY_CFC` — les commandes casque, grille et centrale hydraulique sont retirées du périmètre PLC ; seul le retour thermique de la centrale reste à remonter en diagnostic.

### ❌ Manquant
IHM visu graphique (dossier `visu/` vide, seule la couche d'échange `GVL_IHM` existe).

### ❌ Abandonné — framework de tests automatiques in-PLC (2026-07-26, v0.5.1)
`PLC_TESTS` (`FB_TestSequencer`, BRICKS/CORE, 8 suites de validation, 45 fichiers / 7 300 lignes)
**retiré** → `ARCHIVES/Code/PLC_TESTS/`. **Motif** : 43 % des lignes ST du projet et 30 Ko de RAM
pour des rapports jamais relus, + resynchronisation des 7 suites à chaque évolution métier.
`GVL_PLC_Tests` survit, réduite à ses 20 `Override*` = points d'injection de pannes en **forçage
manuel**. Non-régression (ex-TC-01/02/03, matrice V1–V7) → simulation CODESYS manuelle + FAT/SAT.
Spec archivée : `ARCHIVES/Doc/AF_Partie-14_PLC_Tests_Validation_v1.2.md`.

### ❌ Extension 2026-08-01 — `CODE/TESTS/` archivé, gate C3/C4 test-auto retiré
Même motif que ci-dessus, étendu aux bancs de test C4 restants : `PRG_AU_TestBench.st`,
`PRG_Test_FinalBrakePowerInterlock.st` (LOT3A), `PRG_Test_KoboldMaintenance.st` (LOT2A/T81-T82),
`ST_Safety_Emergency_TestContext.st` **retirés** → `ARCHIVES/Code/TESTS/`. Aucun n'avait jamais
été exécuté en CODESYS réel (en-têtes explicites : « preuves préparées, pas une exécution
CODESYS déclarée »).
📌 **Décision projet** : le test PLC automatique n'est plus une obligation C3/C4 —
`check_task_test_contract.py`, les skills `codesys-workflow`/`codesys-change`/`release-check`
et `docs/TASK_CONTEXT.md` mis à jour en conséquence. La garantie C3/C4 repose désormais
sur `human_validation_required` seul : **vérification manuelle exhaustive (Watch/forçage
CODESYS) avant tout chargement**, y compris pour ce qui ne peut pas être testé autrement.
`TASK_CONTEXT_LOT2A_KOBOLD_MAINTENANCE.yaml` et `TASK_CONTEXT_LOT3A_WINCH_FINAL_INTERLOCK.yaml`
repassés `tests_automated_required: false` / `tests_status: planned` — **T81/T82 (Kobold) et
le lot Interlocks finaux (2A) restent à valider manuellement en CODESYS avant mise en service**,
sans artefact de test embarqué.

### 🗑️ Nettoyage dû
`GVL_BUS`/`GVL_Machine_Stub` ✅ supprimés (2026-07-15, orphelins confirmés) · `ST_IHM_MANU` ✅ supprimé (2026-07-19) ·
Anciens champs `GVL_Translation_M3_Stub` liés à `DEGRADED_IO` ✅ supprimés après confirmation
d'absence de consommateur. `PosPV_DI` et `StubTranslationPositionSelect_IHM` restent consommés :
ne pas supprimer le GVL entier.

### 🏷️ Nommage — chantier séparé (2026-07-15)
Règle `Req`/`Cmd` préfixe formalisée (`NAMING_CONVENTION.md`), initialement pilotée sur
Translation M3 uniquement (`ST_TranslationHMI.ReqFwd/ReqRev`) — ⚠️ **non retenue** (audit
2026-07-22) : le code actuel garde `BtnFwd`/`BtnRev`/`TglJoystickMaster`/`SelTarget`, la
migration Req/Cmd n'est appliquée nulle part dans le code. Reste en préfixe `CmdX`, à auditer/migrer plus tard :
`FB_Bucket`/`FB_Winch`/`ST_BucketHMI`/`ST_WinchHMI` (`CmdOpen`/`CmdClose`/`CmdReset`/`CmdHome`/
`CmdInhibit`) et `FB_Cycle` (`CmdWinchM1_*`/`CmdTranslationM3_*`/`CmdBucket_*`) — blast radius plus
large (interfaces FB largement utilisées), plan dédié à valider avant d'y toucher.

📌 **Décisions client (2026-07-15)** :
- Le dossier `treuil` est conservé.
- **M1** est officiellement le **moteur de retenue**.
- **M2** devient le **moteur Benne** (le terme "Benne" disparaît au profit de "**Benne**").
- Le "**Translation**" devient "**Translation**" (terme abrégé cible à définir : `Trans`, `Translat` ?).

📌 **Nouvelles décisions client — Translation / auxiliaires / cycle semi-auto (2026-07-17)** :
- M3 possède cinq capteurs croisés dans l'ordre `Trémie | PV | P2 | P1 | Maintenance`.
- Codes valides : `11111 → 01111 → 00111 → 00011 → 00001 → 00000` ; toute autre combinaison est incohérente.
- `Trémie` est l'extrême gauche safety ; `Maintenance` est l'extrême droite safety et reste réservée à `MAINT_N2`.
- `PV` est le point de ralentissement avant l'arrêt répétable sur Trémie.
- Le PLC ne commande plus casque, grille ni centrale hydraulique ; seul le thermique centrale remonte en diagnostic.
- Le détecteur de fond Kobold est commandé par un contacteur de puissance à définir et fournit un retour contact fond.
- Le cycle semi-auto est reprenable par homme-mort : relâchement joystick = pause sur étape ; nouvelle commande valide = reprise.

🎯 **Cap long terme** (demande explicite utilisateur 2026-07-15) : généraliser le préfixe
(rôle/type d'abord, ex. `Req`/`Cmd`/`Sensor`/`Position`) à TOUT le projet — objectif : recherche/
autocomplete efficace, taper le rôle suffit à retrouver toutes les variables du même type peu
importe le mécanisme. Concerne potentiellement `Ready`/`Busy`/`RelayFwd`/`SpeedRef`/`CablePosM`/
`TopPositionSensor`... (usage massif, tout le projet) — **chantier majeur à planifier séparément**,
jamais improvisé vu le volume et la criticité sécurité de certaines variables concernées
(ex. `TopPositionSensor`, homing/safety Winch, déjà responsable d'un vrai bug de polarité passé).

### 📄 Doc à mettre à jour
- Presque tous les `AF_PartieN` : en-tête "Dépend de Partie 2 vX.Y" obsolète → aligner sur l'architecture courante
- `AF_Partie-07` (Interface IHM) : réalignée sur `PRG_07_Supervision`
- `AF_Partie-11` : titre et version alignés v1.4 ; chemins Benne/PERSISTENT corrigés
- `CLAUDE.md` : arborescence réalignée sur `PRG_02`→`PRG_07`

---

## ❓ 3. Reliquats, TBD & actions ouvertes

> 🎯 **Règle de conduite & Lock Agent** :
> Avant de démarrer une tâche, l'agent **DOIT** poser son verrou dans `Lock Agent` (`CC-01`, `AGY-01`, `CDX-01`, `PI-01`) et passer le `Statut` à 🔍 ou 🔒.
> - `⬜` : Libre / À faire · `🔍` : Étude / Analyse · `🔒` : Code en cours (Verrou) · `⏳` : Attente validation/tests · `⏸️` : Bloqué · `✅` : Validé

| # | Sujet | Qui tranche / Domaine | Statut | Lock Agent | Source & Détails |
|---|---|---|:---:|:---:|---|
| T1 | Détail séquence `INIT` (sous-vérifications position/cohérence) | Projet | ⏸️ | — | AF_Partie-04 §2, D22 |
| T4 | Protocole registre AC600 (`DriveControlWord`/`StatusWord`) | Constructeur variateur | ⏸️ | — | Translation/Safety_Translation |
| T6 | Périmètre `PRG_08` Auxiliaire | Client | ⏸️ | — | v1.1 §3 (différé assumé) |
| T8 | Rôle de `CodeSeqTriggerCmd` (codeurs) | Terrain | ⏸️ | — | AF_Partie-10 |
| T9 | Comportement frein en montée chargée | Terrain | ⏸️ | — | AF_Partie-09 §4undecies (différé après essais) |
| T11 | `EmergencyStopOk` : confirmation temporisée post-réarmement | Projet | ⬜ | — | AUDIT D93 |
| T15 | Validation câblage réel `EmergencyStopOk_DI` et réarmement | Projet / Terrain | ⏳ | HUM | AF_Partie-01, `PRG_02_Acquisition` |
| T17 | Checklist Joystick : exécution terrain et verdict signé | Projet / Terrain | ⏳ | HUM | `ARCHIVES/Doc/CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.1.md` |
| T20 | Sélecteur treuil IHM : widget visu physique restant | Projet | ⬜ | — | AF_Partie-05 §2, AF_Partie-09 §1 |
| T21 | Checklist validation Winch v1.7 terrain | Terrain | ⏳ | HUM | AF_Partie-09 §8 |
| T22 | Tolérance de calibration `TopSensorPositionM` à fixer sur site | Terrain | ⏳ | HUM | AF_Partie-10 §7bis |
| T25 | Suite Encoder/Homing : essais CODESYS bornage/redémarrage | Projet / Terrain | ⏳ | HUM | AF_Partie-10 §10 |
| T26 | Checklist Translation AC600 terrain (EtherCAT, sens, PV, 5 capteurs) | Terrain | ⏳ | HUM | `ARCHIVES/Doc/CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md` |
| T27 | Benne : essais MES terrain (cinématique, offsets) | Terrain | ⏳ | HUM | AF_Partie-11 §6 |
| T39 | Interfaces Homing nominale et unitaire : essais opérateur CODESYS | Projet / Terrain | ⏳ | HUM | AF_Partie-10 |
| T43 | Comparaison vitesse M1/M2 remontée : régler seuils/tempo (inactif à 0) | Projet / Client | ⏸️ | — | AF_Partie-04 §3quater, `FB_Cycle` |
| T47 | Garde-fou palier vitesse treuils : documenter métier, calibrer et activer | Projet / Sécurité / Terrain | ⏳ | HUM | `FB_SpeedStep`, `GVL_PERSISTENT._WinchSpeedConfig` |
| T48 | Matrice validation pannes treuils V1–V7 en simulation/terrain | Projet / Terrain | ⏳ | HUM | `REGISTRE_Suivi_MiseEnService.md` |
| T52 | Valider chaîne `PowerCutOff` physique et temps coupure réel | Électricité + Projet | ⏳ | HUM | `PRG_06_Outputs.st` |
| T54 | Intégrer latence boucle automate (~10 ms) au calcul temps d'arrêt | Projet | ⬜ | — | AUDIT Winch §3.2 |
| T55 | Stratégie synchronisme unique (info / mineur / majeur / critique) | Projet | ⬜ | — | `FB_WinchSync` |
| T56 | Caractériser seuils sécurité terrain (0,02 m/s, 2 m, 3 s, 800 ms, 500 ms) | Projet / Terrain | ⏳ | HUM | `FB_Safety_Winch` |
| T57 | Unifier limite haute M2 selon offset benne | Projet | ⬜ | — | `PRG_04_Treuils_Benne` |
| T58 | Séparation Config/Commands/Status/Alarms post-maquette IHM | Projet + IHM | ⏸️ | — | AUDIT Winch §5.2 |
| T59 | IHM : afficher arrêt croisé effectif (`ForbidAscentM1_Active`) | IHM | ⬜ | — | `PRG_07_Supervision` |
| T64 | Plafond palier vitesse essais : restaurer valeur d'exploitation | Projet / Terrain | ⏳ | HUM | MES-003 |
| T72 | Interverrouillage commande/frein : bloquer `RelayFwd/Rev` si frein fermé | Projet / Sécurité | ⬜ | — | `FB_Winch.st`, `FB_Translation.st` |
| T73 | Winch : confirmation temporisée + escalade PowerCutOff limite basse | Projet / Sécurité | ⬜ | — | `FB_Safety_Winch.st` |
| T74 | Translation : temporiser escalade PowerCutOff sur `LimitSwitch` | Projet / Sécurité | ⬜ | — | `FB_Safety_Translation.st` |
| T76 | `FB_Cycle.st` : raccorder `DrainingTime` au persistant/IHM | Projet | ⬜ | — | `FB_Cycle.st` |
| T77 | POO Diagnostics : passer statuts bruts aux FB (retrait expressions) | Projet / Architecture | ⬜ | — | `PRG_02_Acquisition`, `FB_Diag_*` |
| T78 | Rampe Treuils : passer à 10%/s par défaut et égaliser en couplé | Projet / Commande Treuils | ⬜ | — | `FB_Winch.st`, `PRG_04_Treuils_Benne.st` |
| T79 | Configurer Trace CODESYS 10ms diagnostic arrêt différencié M1/M2 | Projet / Terrain | ⏳ | HUM | MES-008 |
| T81 | Séquence détection fond Kobold à 4 étapes | Projet / Client | ⏳ | PI-01 | `AF_Partie-04`, `FB_DiveSearch` (codé, attente essais) |
| T82 | Arrêt sécurisé si séquence Kobold invalide | Projet / Sécurité | ⏳ | PI-01 | `FB_ExtractionSequence` (codé, attente essais) |
| T83 | Repasser `ST_BypassNetwork.IhmHeartbeat` à `FALSE` dès visu opérationnelle | Projet / IHM | ⏳ | HUM | `ST_BypassNetwork.st` |
| T84 | Validation CODESYS/terrain mesure vitesse 50 ms (`FB_Encoder_SpeedMeasure`) | Projet / Sécurité | ⏳ | PI-01 | `FB_Encoder_SpeedMeasure.st` |
| T85 | Validation chaîne producteur codeur unique (`PRG_02_Acquisition`) | Projet / Architecture | ⏳ | PI-01 | `PRG_02_Acquisition.st` |
| T86 | Validation blocage déterministe si `Enable=FALSE` (`FB_Safety_Winch`) | Projet / Sécurité | ⏳ | PI-01 | `FB_Safety_Winch.st` |
| T88 | Bouclage `TIME()` (49,7j) dans `FB_CycleTime` : garde-fou `DeltaTimeMs > 1000` | Projet | ⬜ | — | `FB_CycleTime.st` |
| T89 | Valider sur site offset benne fermée ≈ 15 m (grandeur d'état mécanique) | Terrain / Projet | ⏳ | HUM | MES-010 |
| T90 | Valider sur site cote capteur haut 8.0 m et limite 7.5 m au premier homing | Terrain / Sécurité | ⏳ | HUM | MES-009 |
| T91 | ÉTUDE : Séquence frein/puissance asymétrique (montée frein d'abord / descente immédiat) | Projet / Sécurité / Terrain | ⬜ | — | MES-006, `FB_Brake` |
| T92 | Qualification terrain persistance bypass RETAIN et homing à 0 m | Terrain / Sécurité | ⏳ | HUM | MES-002 |
| T93 | Remplacer rampe %/s par temporisations de maintien entre paliers contacteurs | Projet / Maintenance | ⬜ | — | `FB_SpeedStep`, `FB_Winch` |
| T94 | Rendre `SpeedGuardEnable` persistant et exposé IHM MAINT_N2 | Projet / Terrain | ⏳ | PI-01 | `PRG_04_Treuils_Benne`, `GVL_PERSISTENT` |
| T95 | Table `VitesseMax[1..5]` de calibration dans `FB_Winch_Symmetry` | Projet / Terrain | ⏳ | PI-01 | `FB_Winch_Symmetry.st` |
| T96 | Mode apprentissage automatique des bandes de vitesse à vide et en charge | Projet / Terrain | ⏸️ | — | `AF_Partie-10_v2.0` §9bis.3 |
| T98 | Câbler `BrakeThermalFault`/`PhaseRotationFault` vers `GVL_IHM.Commun` | Projet | ⬜ | — | `PRG_07_Supervision.st` |
| T108 | Interlock Translation M3 si Trémie pleine (`HopperFull_OR_GateRaised_DI`) | Projet / Translation M3 | ⬜ | — | `PRG_05_Translation.st` |
| T109 | Formaliser convention polarité positive (`*Permit` / `Allowed`) pour arbitrages | Projet / Convention | ⬜ | — | `NAMING_CONVENTION.md` |
| T110 | Clarifier sémantique `DriveStatusWord.0` AC600 ("Power Ready" vs "Mouvement" Méca B) | Projet / Sécurité | ⬜ | — | `FB_Safety_Translation.st` |
| T115 | Bandeau IHM champ 2 « Cycle » : `CycleStep` non alimenté → affiche `INIT` | Projet / IHM | ⏸️ | — | `PRG_07_Supervision.st`, lié au lot Cycle Auto |
| T116 | IHM : message homme-mort/neutre dynamique selon l'état réel (3 états) | Projet / IHM | ✅ | DSH-02 | `PRG_07_Supervision.st`, `FB_Hmi_BannerFormatter.st`, `FB_Joystick.st` |
| T117 | Renommage/élimination des variables `Forbid*` (`ForbidDescent`/`ForbidAscent`) | Projet / Convention | ✅ | DSH-02 | `NAMING_CONVENTION.md`, `T109` |
| T118 | Refonte des textes IHM du bandeau (`FB_Hmi_BannerFormatter`) : cause + action | Projet / IHM | ✅ | DSH-02 | `FB_Hmi_BannerFormatter.st`, `PRG_07_Supervision.st`, Option A |
| T119 | Analyse comportement Dive / référencement benne dans le cycle semi-auto | Projet / Sécurité / IHM | ✅ | DSH-02 | Reliquat session 2026-08-16, lié à T118 |
| T120 | Autoriser SEMI_AUTO même si prérequis non prêts (attente explicite cycle) | Projet / Sécurité / IHM | ⏸️ | DSH-02 | `FB_Modes.st`, `PRG_03_Modes_Cycle.st`, `FB_Cycle.st` — agent échoue (C4), différé |
| T121 | Audit & élimination des constantes magiques (`<> 8` → symboles DUT/enums) | Projet / Convention / Sécurité | ✅ | DSH-02 | `CODE/` (grep), `NAMING_CONVENTION.md` |
| T122 | Renommage flux joystick → actionneurs (CoupledUserRequest / LogicRequest) | Projet / Convention / Sécurité | ✅ | DSH-02 | `PRG_04_Treuils_Benne.st` (Phases 1-2 faites, phase 3 différée) |
| T123 | Compléter la vue Troubleshooting (flux chronologique, 18 TBD) | Projet / Diagnostic | ✅ | DSH-02 | `FB_TroubleshootingView.st`, `ST_ChainWinch.st`, `GVL_Troubleshooting.st` |
| T124 | `FB_Hmi_BannerFormatter` — suivi revue expert anti-clignotement | Projet / IHM / Convention | ⏳ | DSH-01 | **Implémenté 2026-08-18** : (1) `DirectionBlocked` tranché en `CriticalActionActive` (interlock = affichage immédiat) ; (2) doublon anti-flicker refactoré → `FB_AntiFlickerText` (DRY, 2 instances) ; (3) préfixe `CST_` documenté dans `NAMING_CONVENTION`. + régions `{region §N}` + renvois formats AF dans le FB. AF-07 §4.3 mis à jour. Gates G405 (ASCII) + G200 (liaison) **PASS** ; bundle régénéré. ⏳ Validation CODESYS (banc) à faire |
| T125 | Revue conception modes dragage (DiveSearch / ExtractionSequence / DumpAtTremie) — standard projet + fonctionnel après essais | Projet / Sécurité / IHM | ⬜ | — | Session 2026-08-18 : logique DumpAtTremie **inline dans `PRG_04`** (violation « 1 FB = 1 responsabilité ») ; **verrou translation à la trémie absent** ; **latch « une fois descendu → translation interdite » (P1/Maintenance) absent** ; DiveSearch/ExtractionSequence à revoir (standard + fonctionnel). Traitement en 2e temps |
| T126 | IHM : message « descente interdite » — préciser la **cause** + retirer champ figé « PILOTAGE DIRECT » → contexte `[SIMU] [MAINT_N1] [M1+M2 COUPLÉS] [PILOTAGE MANUEL]` | Projet / IHM | ⬜ | — | Session 2026-08-18, `FB_Hmi_BannerFormatter` / `GVL_IHM` — message actuel trop générique, champ PILOTAGE DIRECT statique inutile |
| T127 | Implémentation + tests du **cycle semi-auto** (grafcet séquence) — valider les nouveaux standards grafcet, **figer les sous-séquences** réutilisables en MAINT, puis intégration version aboutie en MAINT | Projet / Sécurité / IHM | ⬜ | — | Session 2026-08-18, `AF_Partie-04`, `FB_Cycle` — prérequis : revue T125 + essais |
| T128 | Mise en conformité des **commentaires `GVL_IHM`** (émoticônes non gérés, commentaires vides, libellés pourris) | Projet / Convention / IHM | ⬜ | — | Session 2026-08-18 — audit commentaires `GVL_IHM.st` |
| T129 | **Trou dans la raquette troubleshooting** : exposer `instSafetyTranslationM3.ErrorId` + `M3_Direction_Active` dans `GVL_Troubleshooting` (absents des snapshots → impossible de diagnostiquer l'éjection SEMI_AUTO) | Projet / Diagnostic | ⬜ | — | Session 2026-08-18, `GVL_Troubleshooting.st`, `ST_ChainTranslation.st` |
| T130 | **Standardiser le décodage d'intention joystick en amont** (→ `{Direction, Palier}` arbitré), consommé par le cycle et les FB mouvement ; relâchement = arrêt instantané universel | Projet / Sécurité / IHM | 🔍 | — | Session 2026-08-19 — `FB_Cycle` réinvente `Direction := 1`/`SpeedPct := 10` au lieu de consommer `AxisCmdY` (AF P08 §6) ; le décodage doit vivre avant le cycle, pas dedans. **Décisions actées (2026-08-19)** : `FB_IntentionDecoder` instancié dans `PRG_02_Acquisition` ; `ST_WinchCmdDemand.SpeedPct` → `Palier : INT` (Option B). **Phase étude/planification — zéro code**. ⚠️ **Architecture révisée le 2026-08-19 (soir)** : 2 blocs (`FB_GestureIntention` → `FB_ActionIntention_Winch`/`_Translation`), préfixe **`Req*`** et non `Act*` (collision `NAMING_CONVENTION.md:160`) — voir `DOC/WFLOW/AUDITS/REVUE_CRITIQUE_DESIGN_INTENTION_ARCHITECTURE_v0.1.md` (11 décisions actées). 🔴 **Faire T136 d'abord** (contrats d'interface socle), sinon les FB neufs naissent non conformes |
| T131 | **Vitesse par paliers (1-5) dans le cycle** au lieu de % : `ST_WinchCmdDemand` + `FB_Cycle` + `PRG_04` | Projet / Convention / Sécurité | ⬜ | — | Session 2026-08-19 — `ST_WinchCmdDemand.SpeedPct` (REAL %) → `FB_SpeedStep` ; le cycle hardcode 10/50/20/70% ; doit exprimer un palier 1-5 (AF P10 §6) — **partie intégrante de T130** (le palier est une sortie du décodage d'intention) |
| T132 | **Référencement benne fermée** : étape cycle + mise à jour AF P09 §5 | Projet / Sécurité / IHM | ⬜ | — | Session 2026-08-19 — AF P09 §5 « benne ouverte » obsolète → benne fermée (précision visuelle, mâchoires tendues sur câbles) ; ajouter étape cycle où l'opérateur ferme/valide |
| T133 | **Refactor X2** : translate vers trémie / position travail, retirer maintenance du semi-auto | Projet / Sécurité / IHM | ⬜ | — | Session 2026-08-19 — `FB_Cycle.st` X2 — semi-auto ne va jamais en maintenance ; flux trémie → P1 → plongée |
| T134 | **Mise à jour AF P04 (graphe)** pour le nouveau flux | Projet / Doc | ⬜ | — | Session 2026-08-19 — `AF_Partie-04` — aligner le grafcet sur le flux validé |
| T135 | **Refactor intention dans le reste du programme** (PRG_04, PRG_05, FB_Winch, FB_Translation) : consommer `FB_IntentionDecoder` au lieu de re-décoder `Direction`/`SpeedPct` en interne | Projet / Sécurité / Convention | ⬜ | — | Session 2026-08-19 — **séparé de T130** (test cycle d'abord) ; `Direction := 1`/`SpeedPct` ne doivent plus apparaître dans les PRG ; travailler avec des bits d'information travaillés (AF P08 §6) |
| T136 | **Écrire les 2 contrats d'interface FB** (`light` / `standard` + DUT `ST_FbStatus`) dans `CODE_QUALITY_STANDARDS.md` + `guard:` de vérification — **doc seul, zéro ligne `CODE/`** | Projet / Convention | ⏳ | AGY-01 | **Implémenté 2026-08-19** : (1) Contrats light et standard + struct `ST_FbStatus` (6 membres) documentés dans `CODE_QUALITY_STANDARDS.md §2quinquies` ; (2) doublon 2bis résolu ; (3) déduplication Ladder dans `AF_Partie-03` ; (4) script de garde mécanique `G315_check_fb_interface.py` créé et validé (53 FB classés : 21 standard, 27 light, 5 exceptions documentées) + unittests OK. Contrat validé : `TASK_CONTRACT_STANDARD_INTERFACES_FB.yaml`. ⏳ En attente de validation orchestrateur/humain |
| T137 | **Migrer les 21 FB existants vers `ST_FbStatus`** — lot dédié, **séparé de T130/T136** | Projet / Convention | ⬜ | — | ✅ **Prérequis levé (2026-08-19)** : `G315_check_fb_interface.py` corrigé — il ne détectait que les membres **à plat** et ignorait `ST_FbStatus`, si bien qu'un FB migré retombait en « light » et que le script **sortait en succès sans alerter** (garde-fou dégradé en silence dès le 1ᵉʳ FB migré). Corrigé + 4 tests de non-régression. **Bonus** : le rapport distingue désormais *forme cible* / *forme héritée* → le guard sert d'**indicateur d'avancement T137** (migration finie quand la forme héritée tombe à 0 ; aujourd'hui **0 cible / 21 héritée**). **Arbitrage humain 2026-08-19 : `ST_FbStatus` est une CIBLE (option A)**, pas une forme alternative — d'où le maintien de cette tâche. Session 2026-08-19 — **144 lignes** mesurées (`PRG_04` 105 · `PRG_07` 20 · `PRG_05` 10 · `PRG_03` 5 · `PRG_02` 3 · `PRG_06_Outputs` 1 **hors périmètre** : `instSafetyEmergencyManagement.State` est un `ST_Safety_Emergency_State`, pas la phase `E_State` → **zéro risque import Ladder**). ✅ **Impact IHM/SCADA = 0** (vérifié) : double couche d'adaptation `FB → struct métier → GVL_IHM` (`PRG_04:968` puis `PRG_07:292`) — seuls les **membres droits** changent, `GVL_IHM` et le pupitre sont intacts → **pas de transition en miroir**, migration franche. 🟢 100% rattrapé par le compilateur. ⚠️ **Ne pas mélanger avec T130/T135** : les deux tapent lourdement dans `PRG_04`, le `git diff` deviendrait irrelisible (impossible de distinguer un renommage mécanique d'un vrai changement de logique — rédhibitoire sur du code sécurité). Pilote proposé : **`FB_Translation`** (10 lignes) plutôt que `FB_Winch` (105). Bénéfice bonus : `Status.State` **supprime la cause** de la surcharge du nom `State` contournée par renommage en `FBState` (`ST_SyncState.st:13`) |
| T138 | **Dédup. documentaire** `AF_Partie-03` ↔ `CODE_QUALITY_STANDARDS` : §6 Ladder → **pointeur** vers CQS §11 · renuméroter le **double `2bis`** de CQS | Projet / Doc / Convention | ✅ | AGY-01 | Traité et intégré dans le cadre de T136 (AC4 & AC5) |
| T139 | **Restructuration thématique des 77 DUT** dans `CODE/J_SUPERVISION/_TYPES/` (8 sous-dossiers thématiques) + mise à jour outillage et baseline | Projet / Convention | ✅ | AGY-01 | **Validé et commité (2026-08-19)** : 77 DUT dans 8 sous-dossiers, G380 rglob, baseline OK, Palier C PASS |
| T140 | **Purge de `GVL_Global` & Assainissement Barrière Sorties** : suppression des 18 variables contacteurs de `GVL_Global.st`, passage en `VAR_OUTPUT` taguées/fléchées dans `PRG_06_Outputs.st`, câblage direct `FB_SimBench` | Projet / Convention / Sécurité | ⏳ | AGY-01 | **Implémenté 2026-08-19** : Purge GVL_Global, PRG_06 conforme CQS §2 (tags `[ACT]`, `[SAFE]`, `[CMD]` et flèches ASCII `<--`), câblage direct `PRG_02_Acquisition`, bundle fresh, 15/15 gates PASS (`run_all_gates.py --palier C`), G200 PASS. Contrat : `TASK_CONTRACT_PURGE_GVL_GLOBAL_OUTPUTS.yaml`. ⏳ En attente de validation orchestrateur/humain |
| T141 | **Standardisation globale des 7 PRG** : ordre strict des blocs de déclaration (`VAR_INPUT` $\rightarrow$ `VAR_OUTPUT` $\rightarrow$ `VAR`), bannières ASCII, tags CQS §2 et purge intégrale des commentaires REX / vestiges historiques | Projet / Convention | ✅ | AGY-01 | **Validé et commité (2026-08-19)** : `PRG_02` à `PRG_07` réordonnés et formatés selon CQS §2, Palier C PASS |
| T142 | **Encapsulation des échanges inter-PRG par bus DUT typés** (Phasage étanche : P1=PRG_02, P2=PRG_04, P3=PRG_05, P4=PRG_06) | Projet / Architecture | 🔒 | DSH-02 | **Découpage en 4 phases étanches** avec contrôle mécanique unitaire à chaque étape :<br>• **P1 (En cours, repris AGY-01→DSH-02 — pilote PRG_02↔PRG_04 validé 2026-08-20)** : `PRG_02_Acquisition` expose `Data : ST_AcquisitionInterPrg` + remap `PRG_04` appliqué et validé (compile + run + simu treuil) · **reste** : remap `PRG_03/05/07` + `FB_TroubleshootingView`, puis suppression sorties plates absorbées + bundle fresh + Gates Palier C.<br>• **P2** : `PRG_04_Treuils_Benne` expose `Data : ST_WinchInterPrg`.<br>• **P3** : `PRG_05_Translation` expose `Data : ST_TranslationInterPrg`.<br>• **P4** : `PRG_06_Outputs` expose `Data : ST_OutputsInterPrg`. |

---

### 📦 3.1 Registre des tâches traitées & validées

| # | Sujet | Résolution / Validation |
|---|---|---|
| **T2 / T3 / T5** | Programmes et types de base (`PRG_IP`, `FB_Filter_PT1`, Priorités tâches 1/10/16) | ✅ Conformes et intégrés. |
| **T7 / T40** | Suppression définitive d'`IHM_MANU` au profit de MAINT_N1/N2 + Homme-mort | ✅ Supprimé du code, validé par `SUITE_MODES`. |
| **T10 / T12 / T13** | Alignement Safety Winch (bits 14/15) & Safety Translation conforme matériel | ✅ Validé dans `FB_Safety_Winch` et `FB_Safety_Translation`. |
| **T16 / T18 / T19** | Purgé vestige `PRG_JOY1`, GVL IHM structurée, retrait `ChannelOk` non utilisé | ✅ Conforme architecture 7 POU. |
| **T23 / T24** | Homing nominal/unitaire MAINT_N2 et `FB_Encoder_Safety` intégrés | ✅ Câblé et vérifié. |
| **T28 / T29 / T30** | Terminologie M1 Retenue/M2 Benne/M3 Translation, échelle 60 Hz M3 | ✅ Alignement complet DOC + CODE. |
| **T31 / T32** | Vitesse linéaire m/s calculée, tableau 2D estimation charge | ✅ Implémenté (`FB_Encoder_Scale`, `FB_WinchLoadEstimator`). |
| **T33 / T34** | Décodage 5 capteurs M3 (`FB_Translation_PositionDecoder`), E/S Kobold assignées | ✅ Intégré dans `PRG_05_Translation` et `PRG_02_Acquisition`. |
| **T35 / T36** | Descente semi-auto Kobold et stabilisation double codeur fermée | ✅ Séquenceur `FB_Cycle` mis à jour. |
| **T37 / T38** | Retrait commandes auxiliaires (thermique seul conservé), doc réalignée | ✅ Conforme décisions client. |
| **T41 / T42 / T44** | Exposition m/s IHM, `FB_Encoder_SpeedMonitor`, GVL_IHM vitesses | ✅ Validé. |
| **T45 / T46** | 5 plages vitesse paramétrables, table charge 2D | ✅ Déclaré dans `ST_WinchSpeedConfig`. |
| **T49 / T50 / T53** | Hauteurs unifiées (8.0m / 8.5m), `FB_SpeedStep` borné, safety stricte par défaut | ✅ Intégré. |
| **T60 / T61 / T62** | Neutralisation `E_Mode.DISABLE`, estimateur charge en montée seule, fin montée 8.0m | ✅ Vérifié. |
| **T65 / T66 / T67** | Persistance `GVL_PERSISTENT` testée CODESYS, protection Cycle/Translation | ✅ Gate `G380` PASS. |
| **T68 / T69 / T70 / T71** | VAR_IN_OUT joystick persistant, timeout benne persistant, gate persistance CI | ✅ Gate `G380` intégré. |
| **T75** | `G100_check_code_style.py` : exemptions obsolètes épurées lors de la refonte des dossiers | ✅ Terminé (outillage adapté à `A_COMMUN`..`M_MAIN`). |
| **T80** | Capteur PV M3 raccordé (suppression stub) | ✅ Corrigé dans `PRG_02_Acquisition`. |
| **T87** | Sort de `DelayMotorDecel` / `FB_Brake` M1/M2 | ✅ Sans objet : Freins M1/M2 pilotés directement sur contacteurs FWD/REV + interlocks dans `PRG_06_Outputs`. |
| **T97 / T102** | Rationalisation acquisition, retrait `PRG_01_Inputs_LD` / `FB_Input` | ✅ Terminé : `PRG_02_Acquisition` est la frontière unique active (`HwReal/HwSim/HwIn`). |
| **T99** | Suppression `GVL_IHM_AU` & types `ST_Safety_Emergency_Hmi*` | ✅ Code mort archivé dans `ARCHIVES/Code/SUPERVISION/`. |
| **T100 / T101** | Fix gate L9 mapping E/S, architecture ciblée 7 POU par procédé actée | ✅ Validé. |
| **T103** | Dépendance Homing déplacée dans le lot M3 (Treuils) | ✅ Architecture résolue. |
| **T104 / T105 / T106 / T107** | Lot Translation M3 (Safety, mot de commande/fréquence, homme-mort, heartbeat IHM) | ✅ Codé, lié, gates PASS. |
| **T111** | Mou de câble : blocage descente + autorisation montée lente pour retendre | ✅ Corrigé dans `FB_Safety_Winch` (2026-08-15). |
| **T112** | Polarité positive `AscentPermit`/`DescendPermit` sur Treuils | ✅ Homogénéisé dans `FB_Safety_Winch` et `PRG_04` (2026-08-15). |
| **T113** | Synchronisation M1/M2 étagée (nominal <0.3m, dégradation Palier 1 0.3-0.8m, SafeStop >1.2m) | ✅ Implémenté dans `FB_WinchSync` (2026-08-15). |
| **T114** | Autorisation remontée Palier 1 si Benne obstruée / décalage codeur | ✅ Implémenté dans `PRG_04_Treuils_Benne` (2026-08-15). |

### 🧰 3.2 Outillage livré (hors `Txx` — repère de traçabilité)

> ⚠️ Les livrables d'outillage/gouvernance ne sont **pas** des tâches de lot `Txx` (pas de colonne
> `Lock Agent`) : ils sont tracés ici comme **repère**, dans `TOOLS/AGENT_WORKFLOW/` et `AGENTS.md`.

| # | Livrable | Emplacement | État |
|---|---|---|---|
| **O1** | Gate `G405` — littéraux STRING ASCII (REX 2026-08-17) | `TOOLS/AGENT_WORKFLOW/scripts/G405_check_st_string_ascii.py` + palier C de `run_all_gates.py` | ✅ **PASS** (créé, intégré) |
| **O2** | Hook `pre-push` non bloquant (diff-stat, alertes suppressions/chemins protégés, rappel « premier réflexe = demander l'humain ») | `TOOLS/AGENT_WORKFLOW/scripts/pre_push_guard.py` + `TOOLS/AGENT_WORKFLOW/hooks/pre-push` | ✅ Livré (script testé, hook `sh`) |
| **O3** | Règle « Premier réflexe avant commit/push » + activation `core.hooksPath` | `AGENTS.md` | ✅ Acté |

✅ **Session 2026-07-09 (agent de scan doc)** : table complétée (T12-T27) — voir §5 pour le détail des renvois ajoutés dans chaque `AF_PartieN`.

---

## 📋 4. Recette

### 🧭 4.0 Stratégie de mise en service (actée 2026-07-27)

> 🎯 Principe : **on mesure avant de protéger.** Les seuils de sécurité actuels sont théoriques —
> les activer sans les avoir calibrés sur la machine réelle produirait des déclenchements au jugé.

#### 🔧 Lots code à faire AVANT les essais

| # | Lot | Pourquoi d'abord |
|---|---|---|
| **1** | **T84 + T85 + T86** — mesure `MeasuredSpeedMps` (fenêtre interne 50 ms), producteur chaîne codeur (`PRG_02_Encoders`), `ForbidAscent` déterministe | Même fichier/chaîne (`FB_Encoder_SpeedMeasure`/`FB_Safety_Winch`) → **un seul passage sur le cœur sécurité**. Sans T84, toutes les mesures suivantes portent sur du bruit. T87 (`DelayMotorDecel`) **hors périmètre** de ce lot, reporté au lot étude 4 (T91/T93) |
| **2** | **T81 + T82** — séquence de détection de fond Kobold | Le cycle semi-auto ne peut pas être qualifié tant que la détection de fond repose sur l'immersion |
| **3** | **T94 + T95** — garde-fou pilotable/persistant + table `VitesseMax[1..5]` | Ce sont les **outils** de la calibration ci-dessous : sans eux, on ne peut ni mesurer ni conserver le résultat |

#### 🧪 Déroulé sur machine

| Phase | Contenu | Garde-fou vitesse |
|---|---|---|
| **0** | Import CODESYS, compilation, `FB_Acquisition_Preflight` → vérifier l'état machine **avant tout mouvement** | — |
| **1** | Simulation domaine par domaine (`CHECKLISTS/CHECKLIST_MiseEnRoute_Simulation`) | — |
| **2** | Essais treuils réels : montées/descentes, paliers 1→5, **à vide puis en charge**. Relevés : `VitesseMax` par palier (T95), hauteurs (T90), offset benne (T89), symétrie M1/M2 (`FB_Winch_Symmetry`, MES-008) | 🔴 **DÉSACTIVÉ** |
| **3** | Renseigner `_WinchSpeedConfig.MaxMeasuredSpeedMps` et `SpeedBandMaxMps[1..5]` avec les valeurs **mesurées** (T45/T47) | 🔴 désactivé |
| **4** | Activer `SpeedGuardEnable` par axe, vérifier que `SpeedGuardLimited` ne se déclenche **pas** en usage normal | 🟢 **ACTIVÉ** |
| **5** | Qualification bypass + homing 0 m (T92, `CHECKLISTS/CHECKLIST_Essais_Persistance_Bypass_Frein`), puis cycle semi-auto complet | 🟢 activé |

⚠️ **Le garde-fou de palier n'est pas un confort** : engager trop de contacteurs de vitesse au
démarrage en charge fait **décrocher le moteur et disjoncter la machine** (T47). Il doit être activé
avant l'exploitation, et son état doit survivre aux downloads (T94).

#### 🔬 Études à mener en parallèle (pas de décision prise)

**T91** séquence frein/puissance asymétrique selon le sens · **T93** temporisations par palier en
remplacement de la rampe %/s. Les deux interagissent : le temps de décélération conditionne la
séquence de freinage. À instruire ensemble, sur machine.

#### 🚚 Avant livraison client

`SimulationModeActive = FALSE` et 4 domaines à `FALSE` · **bypass RETAIN remis à zéro** ·
`Network.Bypass.IhmHeartbeat := FALSE` (**T83**) · `SpeedGuardEnable` activé · valeurs persistantes
relevées et archivées.

📝 **Chaque phase donne lieu à une entrée `MES-xxx`** dans `REGISTRE_Suivi_MiseEnService.md`.

---


📥 **Ingéré depuis** `SAT_Protocole_Essais_v1.0.md` (archivé dans `ARCHIVES/Doc/`, contenu ci-dessous fait foi).

⚠️ **NO-GO mouvement** (diag EtherCAT + câblage CAN joystick, AUDIT D47) à lever formellement avant de dérouler ce protocole.

**Prérequis** : Homing M1/M2 fait (8,5 m, `Homed=TRUE`) · Joystick calibré (deadband 10%) · `GVL_Simulation.SimulationModeActive = FALSE`.

| # | Test | Résultat attendu |
|---|---|---|
| 2.1 | AU physique | Coupure puissance immédiate, `EmergencyStopOk=FALSE`, freins M1/M2/M3 serrés, alarme IHM |
| 2.2 | Collage contacteur (`PowerCutOff`) | Incohérence détectée → `PowerCutOff` déclenché, réarmement interdit tant que cause présente |
| 3.1 | Mou de câble M2 | Descente coupée immédiatement, montée restant autorisée, défaut IHM |
| 3.2 | Butée haute M1 (logicielle + physique) | Arrêt sur butée virtuelle ; coupure immédiate si `TopPositionSensor` s'ouvre |
| 4.1 | Synchro mineure (>0.25m, Soft-Stop) | Ralentissement + arrêt rampe normale, sens aggravant bloqué |
| 4.2 | Synchro majeure (>2.0m, Méca E) | `SafeStop` immédiat M1+M2, freins serrés, reset + retour neutre requis |
| 5.1 | Homme-mort manuel | Armé au neutre → mouvement possible ; lâcher → arrêt, désarmement auto après 500ms |
| 6.1 | Homme-mort en SEMI_AUTO | Neutre = immobile ; armé+poussé = mouvement gated ; relâche = arrêt, reprise si réarmé |
| 6.2 | SafeStop en séquence Auto | `ERROR_HOLD` immédiat, reprise exacte après Reset+Start une fois défaut disparu |

**Fiche signature** : Date / Responsable Automatisme / Représentant Client + tableau Pass/Fail par test + commentaires.

### 🧾 Journal des séances MES / REX

Les constats, mesures et décisions issus du banc ou du terrain sont consignés dans
`REGISTRE_Suivi_MiseEnService.md`. Toute action différée issue d'une séance doit
être créée ou mise à jour ici au §3 avec un identifiant `Txx` : ce plan reste l'unique source des
reliquats à implémenter.

---

## 🔗 5. Renvois AF_Partie → ce document

✅ **Scan complet effectué (2026-07-09)** — 12 des 13 `AF_PartieN` touchés (contenu organisationnel
extrait et/ou harmonisation titre/nom de fichier) ; `AF_Partie-03` laissé intact (aucun contenu
organisationnel trouvé). Détail fichier par fichier :

| Fichier | Ancien nom | Nouveau nom | Renvois ajoutés | Txx référencées |
|---|---|---|---|---|
| Partie 1 | `..._v1.5.md` | `..._v1.6.md` | 2 | T12, T13 |
| Partie 2 | `..._v2.11.md` | `..._v2.12.md` | 1 | T5 |
| Partie 3 | — | — (inchangé) | 0 | — |
| Partie 4 | `..._v1.2.md` | `..._v1.3.md` | 1 | T1 |
| Partie 5 | `..._v1.3.md` | `..._v1.5.md` | 1 | T18 |
| Partie 6 | `..._v1.5.md` | `..._v1.6.md` | 1 | T19 |
| Partie 7 | `..._v1.2.md` | `..._v1.3.md` | 0 (harmonisation titre/fichier uniquement) | — |
| Partie 8 | `..._v1.2.md` | `..._v1.3.md` | 3 | T15, T16, T17 |
| Partie 9 | `..._v1.9.md` | `..._v1.10.md` | 3 | T9, T20, T21 |
| Partie 10 | `..._v1.7.md` | `..._v1.9.md` | 8 | T4, T8, T22, T23, T24, T25 |
| Partie 11 | `..._v1.3.md` | `..._v1.4.md` | 5 | T4, T12, T26 |
| Partie 11 | `..._v1.2.md` | `..._v1.4.md` | 1 | T27 |
| Partie 13 | `..._v1.1.md` | `..._v1.2.md` | 0 (harmonisation titre/fichier uniquement) | — |

📌 Chaque fichier renommé a été archivé tel quel (version pré-nettoyage) dans `ARCHIVES/Doc/`
avant incrémentation, conformément à la convention de versionnage du projet. Toutes les
références croisées connues (`CLAUDE.md` + liens inter-`AF_PartieN`) ont été mises à jour vers les
nouveaux noms de fichier.

---

## 📎 Sources archivées
`ARCHIVES/Doc/PLAN_Finalisation_v1.0.md` · `ARCHIVES/Doc/PLAN_Finalisation_v1.1.md` · `ARCHIVES/Doc/SAT_Protocole_Essais_v1.0.md`

- 🛡️ Lot 3A : instances finales `_LD` implantées exclusivement dans `PRG_OUTPUTS_LD` ; qualification CODESYS/import/PLC/simulation toujours à faire.

# 🗂️ PLAN_TASK — Suivi Planning & Reliquats (v1.0)

> 🎯 **Rôle** : seul document de pilotage projet (jalons, tâches, TBD, questions client). Les `AF_PartieN` restent **spec fonctionnelle pure** — tout ce qui est planning/organisationnel vit ici, pas dans les specs.
> 📥 **Remplace** : `PLAN_Finalisation_v1.0.md` + `v1.1.md` + `SAT_Protocole_Essais_v1.0.md` (les 3 archivés dans `ARCHIVES/Doc/`, contenu ingéré ci-dessous).
> 🗓️ Créé 2026-07-09.

---

## 🧭 Plan d’implémentation orchestré — état courant

> Source unique de suivi des lots automate. Mise à jour uniquement aux changements d’état significatifs.

| Ordre | Lot fonctionnel | Tâches | Dépendances / décision | État | Agent | Validation utilisateur |
|---:|---|---|---|---|---|---|
| 1 | Fiabilisation mesure Winch | T84 + T85 + T86 | Fenêtre interne 50 ms ; producteur chaîne codeur ; pulse source générique depuis `PRG_00` ; T87 reporté au lot étude 4 (T91/T93) | 🟠 Implémenté et revu, validation CODESYS/terrain requise | Pi via OmniRoute | ⏳ Validation code attendue |
| 2 | Assistants Kobold maintenance | T81 + T82 | `FB_DiveSearch` : `0→1→0` ; `FB_ExtractionSequence` : fermeture, palier 1 sur 2 m puis nominal ; hors `FB_Cycle` | 🟠 Implémenté, tests PLC créés ; compilation/essais CODESYS requis | Pi + revue Sonnet 5 | ⏳ Validation CODESYS/terrain requise |
| 3 | Garde-fou et calibration paliers | T94 + T95 + T96 | Dépend du lot 1 : mesure vitesse fiabilisée avant calibration ; T96 = mode apprentissage auto (remplace saisie manuelle T95) | ⬜ En attente lot 1 | — | — |
| 4 | Frein et commande par paliers | T91 + T93 + décision T87 | Étude montée/descente avant code ; ne pas choisir arbitrairement le sort de `DelayMotorDecel` | ⬜ Étude à préparer | — | — |
| 5 | Reliquats safety | T72 + T73 + T74 | Réévaluer l’état réel du code après les lots précédents | ⬜ À réévaluer | — | — |
| 2A | Interlocks finaux frein / puissance | Lot 3A | `FB_WinchOutputInterlock_LD` + `FB_TranslationOutputInterlock_LD` ; `SafeStop` reste la rampe rapide métier, tests PLC préparés ; qualification CODESYS/simulation à faire | 🟠 Implémenté, revue C4 et essais requis | Pi | ⏳ Validation CODESYS/terrain requise |
| 6 | Améliorations secondaires | T75 + T76 + T77 + T79 + T88 | T78 attend la décision T93 (T84/T85/T86 déjà implémentés au lot 1, T87 reporté au lot 4) | ⬜ Différé | — | — |

### Règles de conduite

- Un lot à la fois : analyse → plan → validation utilisateur → implémentation agent → contrôle orchestrateur → validation utilisateur.
- Agents d’exécution : scope borné, aucun commit. Revues : lecture seule.
- Aucun nouveau document de pilotage : specs `AF_PartieN`, registres existants, ce plan et `VERSION_HISTORY.md` font foi.
- `TOOLS/OUTILS_ST2PY/` est hors périmètre tant qu’un autre agent y travaille.

---

## 🏁 1. Jalons connus de l'affaire

| Date | Jalon |
|---|---|
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
| **Une seule convention de polarité** | « TRUE = frein serré » dans tout l'aval. Normalisation **à la frontière** (`BrakeFeedbackInvertLogic`), jamais dans les blocs métier |

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
- `AF_Partie-07` (Interface IHM) : réalignée sur `PRG_09_Supervision` et renommée v1.5
- `AF_Partie-11` : titre et version alignés v1.4 ; chemins Benne/PERSISTENT corrigés
- `CLAUDE.md` : arborescence réalignée sur `PRG_00`→`PRG_10`

---

## ❓ 3. Reliquats, TBD & questions client

| # | Sujet | Qui tranche | Source |
|---|---|---|---|
| T1 | Détail séquence `INIT` (sous-vérifications position/cohérence) | Projet | AF_Partie-04 §2, D22 |
| T2 | ✅ `PRG_IP` existe mais n'est appelé dans aucune tâche CODESYS : programme inactif | Projet | `Device.export`, AF_Partie-02 §3 |
| T3 | ✅ Nom confirmé dans le code et l'export : `FB_Filter_PT1` | Projet | `FB_Joystick`, `Device.export` |
| T4 | Protocole registre AC600 (`DriveControlWord`/`StatusWord`) | **Constructeur variateur** | Translation/Safety_Translation |
| T5 | ✅ Priorités confirmées par export : EtherCAT=1, Main=10, CAN=16 ; watchdogs 200 ms | Projet | `Device.export`, AF_Partie-02 §2 |
| T6 | Périmètre `PRG_08` Auxiliaire | **Client** (en cours, différé assumé) | v1.1 §3 |
| T7 | ✅ `IHM_MANU` retiré définitivement (2026-07-19), sans attendre de critère de qualification — décision projet | Projet | `IHM_MANU_Journal_Modifications.md` |
| T8 | Rôle de `CodeSeqTriggerCmd` (codeurs) | À vérifier terrain | AF_Partie-10 |
| T9 | Comportement frein en montée chargée | Différé après essais terrain | AF_Partie-09 §4undecies |
| T10 | ✅ `Safety_Winch` : sens réel opposé (bit14) + absence de mouvement malgré commande (bit15), temporisés et câblés M1/M2 | Projet | AF_Partie-09 v1.11 |
| T11 | `EmergencyStopOk` : pas de confirmation temporisée post-réarmement, redondance A/B logicielle seulement | Projet | AUDIT D93 |
| T12 | ✅ Safety Translation conforme au matériel : aucun contacteur puissance M3 dédié ; surveillance par état/fréquence AC600 + retour frein M3. `PowerCutOff` actif sur bits3–7 | Projet | AF_Partie-01, AF_Partie-11 v1.9 |
| T13 | ✅ Aucun identifiant Safety Mouvement A/B/C actif. Les suffixes `PowerCutOff_A/B` sont conservés : canaux physiques redondants, pas rôles métier | Projet | AF_Partie-01, CODE/AU |
| T15 | 🔎 Source logicielle clarifiée : `PRG_00_Inputs.EmergencyStopOk` vient de `EmergencyStopOk_DI` (retour contacteur de puissance) ; simulation et override tests restent explicitement séparés. Validation du câblage réel et du comportement post-réarmement à réaliser | Projet / Terrain | AF_Partie-01 §Sécurité électrique, AF_Partie-03 §1, `PRG_00_Inputs` |
| T16 | ✅ Vestige `PRG_JOY1` retiré des instructions actives ; programme réel `PRG_01_Diagnostics`, filtre `FB_Filter_PT1` | Projet | AF_Partie-08 §6bis |
| T17 | 🟠 Checklist Joystick rédigée ; exécution terrain et verdict signé restant à réaliser. Limitations de robustesse ajoutées sur `FB_AxisScale`, `FB_Ramp` et la consigne finale M3 | Projet / Terrain | `CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.1.md`, AF_Partie-08 §8 |
| T18 | ✅ GVL d'échange IHM créée et structurée par métier (modes, Translation M3, cycle, diagnostics) | Projet | `GVL_IHM` + Partie 7 v1.5 |
| T19 | Mapping `ChannelOk` carte/voie E-S (diagnostic carte non exploité) à définir si besoin confirmé | Projet | AF_Partie-06 §4 |
| T20 | Sélecteur treuil IHM (visu/physique) — variable rapatriée dans `GVL_IHM.Modes.JoystickWinchSelect` (2026-07-19, ex-`GVL_IHM.IHM_MANU`) ; widget visu physique restant à faire. Arbitrage MAINT_N2 fait, cf. AF_Partie-05 v1.6 | Projet | AF_Partie-05 §2, AF_Partie-09 §1 |
| T21 | Checklist validation Winch v1.7 non réalisée (inhibition, HomingApproachEnable, Méca B/D, diagnostics IHM, simulation) | Terrain | AF_Partie-09 §8 |
| T22 | Tolérance de calibration `TopSensorPositionM` (contrôle visuel) à fixer sur site | Terrain | AF_Partie-10 §7bis |
| T23 | ✅ Homing nominal et unitaire MAINT_N2 raccordés : sélection M1/M2, cible libre par treuil, limite ±99 m et diagnostics bits0/1/4 | Projet | `FB_Encoder_Homing`, `PRG_02_Encoders`, `ST_WinchHMI` |
| T24 | ✅ `FB_Encoder_Safety` intégré (instances M1/M2, inhibition `SEMI_AUTO`, diagnostic IHM) | Projet | AF_Partie-10 §9bis |
| T25 | 🟠 Suite automatisée nominale Encoder/Homing renforcée : gate simulation explicite, watchdog local, rapports TC-E1/TC-E2 corrigés ; essais CODESYS et scénarios unitaire/bornage/redémarrage restant | Projet / Terrain | `SuiteEncoder = 4`, AF_Partie-10 §10 |
| T26 | 🟠 Checklist Translation AC600 rédigée ; exécution terrain et verdict signé restant à réaliser (EtherCAT, commande, fréquence, sens, arrêts, PV, 5 capteurs, Fdc, thermique, diagnostics) | Terrain | `CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md`, AF_Partie-11 §8 |
| T27 | Benne : essais de mise en service non réalisés (cinématique, offsets, Méca C couches 1/2) | Terrain | AF_Partie-11 §6 |
| T28 | ✅ Plafond palier "essais progressifs" (`WinchMaxStepFwd/Rev`) retiré avec IHM_MANU (2026-07-19) — `PRG_06_WinchControl` applique désormais un plafond fixe (5/`_WinchMaxStepDescent`), identique Auto et Manuel | Projet | Session 2026-07-19 |
| T29 | ✅ Terminologie active alignée : Translation M3, M1 Retenue, M2 Benne | Projet | CODE + AF métiers |
| T30 | ✅ Translation configurée sur échelle max 60 Hz ; nominal 30 Hz à 50 % | Projet | `FB_Translation.DriveFreqScaleMaxHz` |
| T31 | ✅ Vitesse câble calculée en m/s et répartie sur 5 plages paramétrables | Projet | T41/T45 |
| T32 | ✅ Estimation charge par tableau 2D palier contacteurs × plage vitesse, réglable et informative | Projet | T46 |
| T33 | ✅ Définir et implémenter le décodage cinq capteurs M3 (`Trémie/PV/P2/P1/Maintenance`) et le diagnostic des combinaisons incohérentes | Projet | Implémenté : `FB_Translation_PositionDecoder` |
| T34 | ✅ Définir les E/S réelles du contacteur Kobold et de son retour contact fond | Projet / Électricité | `KoboldContactFond_DI`=%IX0.5 · `KoboldContactor_DQ`=%QX0.6 — aucun réemploi du capteur mou de câble |
| T35 | ✅ Définir la stratégie de descente semi-auto : limite légale, détection Kobold, remontée synchronisée au-dessus de la limite, puis fermeture benne | Projet | Implémenté et raccordé au cycle v0.4.17 |
| T36 | ✅ Finaliser la stabilisation après fermeture benne : vitesse lente, tolérance codeurs, blocage/obstacle/câble mou et reprise | Projet | Double contrôle codeurs + timeout + `ERROR_HOLD` implémentés ; essais terrain restant |
| T37 | ✅ Retirer les commandes PLC casque/grille/centrale et conserver uniquement le diagnostic thermique centrale | Projet | Implémenté selon décision client 2026-07-17 |
| T38 | ✅ Réaliser la passe documentaire architecture : remplacer les références `PLC_PRG_MAIN`/anciens chemins et vérifier les liens | Projet | AF Partie 2/5/7/8/10/14 — liens locaux validés |
| T39 | 🟠 Interfaces Homing nominale et unitaire réalisées ; essais opérateur CODESYS restant | Projet / Terrain | T23/T25, AF_Partie-10 |
| T40 | ✅ Suppression définitive d'IHM_MANU (dispositif dérogatoire mise en service urgence, v0.4.4) : plus aucune dépendance opérationnelle en code actif ; pilotage manuel exclusivement MAINT_N1/MAINT_N2 + joystick homme-mort ; nouvelle suite de tests `SUITE_MODES` (TC-M1→M6, couvrant les 10 items obligatoires de la revue) ; revue de sécurité post-mission : homme-mort ajouté sur boutons IHM Translation M3 (écart préexistant relevé, cf. AF_Partie-11 v1.9 §6bis) | Projet | AF_Partie-11 v1.9, `IHM_MANU_Journal_Modifications.md` (historique), REX 2026-07-19 |
| T41 | ✅ Exposer la vitesse linéaire réelle de chaque câble en m/s à partir de la position codeur et d'un temps de cycle fiable | Projet | AF_Partie-10/09, `FB_Encoder_Scale`, `FB_Safety_Winch` — `MeasuredSpeedMps` exposé IHM |
| T42 | ✅ Créer la surveillance générique de vitesse codeur : variation brusque paramétrable, durée de confirmation, état et `ErrorId` | Projet | `FB_Encoder_SpeedMonitor.st` — diagnostic seul, intégration cycle reportée |
| T43 | 🟠 Raccorder les vitesses M1/M2 au cycle de remontée : comparaison, désynchronisme de vitesse, temporisation, pause/défaut sans attente infinie | Projet / Client | AF_Partie-04 §3quater, `FB_Cycle` — bit4 `ErrorId` câblé ; `SpeedMismatchThresholdMps` et `SpeedMismatchTimeout` restent à `0` (contrôle inactif) tant que les valeurs métier ne sont pas définies |
| T44 | ✅ Exposer dans `GVL_IHM` les vitesses mesurées, écarts, variations, paliers commandés et états de surveillance | Projet | AF_Partie-07, `ST_WinchHMI`, `ST_CycleHMI`, `PRG_03_Safety`, `PRG_09_Supervision` |
| T45 | ✅ Définir les 5 plages de vitesse réelle à partir de `VitesseMaxMps` (valeur provisoire 2,0 m/s), avec seuils paramétrables et hystérésis | Projet / Client | `ST_WinchSpeedConfig`, AF_Partie-09 — valeurs à confirmer terrain |
| T46 | ✅ Créer le tableau 2D empirique `palier contacteurs × vitesse mesurée → charge estimée %` ; valeur informative non certifiée, réglable en mise en service | Projet / Terrain | `ST_WinchSpeedConfig`, `ST_WinchLoadEstimateTable`, `FB_WinchLoadEstimator` |
| T47 | 🟠 **Garde-fou de passage de palier — implémenté, NON ACTIVÉ.** `FB_SpeedStep:230-238` bride le palier demandé à la bande de vitesse réellement atteinte (`StepNumber := MeasuredSpeedBand`), avec stabilité temporelle. Piloté par `SpeedGuardEnable` (**défaut `FALSE`**), bandes dans `_WinchSpeedConfig` (`[0.4, 0.8, 1.2, 1.6, 2.0]` m/s, hystérésis 0.05 — **valeurs provisoires**).<br>🔴 **Raison métier à documenter (REX 2026-07-27, non écrite à ce jour)** : la construction des moteurs fait qu'**engager trop de contacteurs de vitesse au démarrage en charge provoque un décrochage — comme une voiture qui cale en mauvaise vitesse — et fait DISJONCTER toute la machine.** Ce garde-fou est la protection contre ce phénomène, pas un confort.<br>À faire : ① inscrire ce phénomène dans `AF_Partie-09` ; ② calibrer les 5 bandes en charge réelle ; ③ activer `SpeedGuardEnable` — sans être trop restrictif, l'objectif est d'empêcher l'enchaînement de paliers sur un treuil pas assez lancé.<br>📌 Fiabilité directement conditionnée par **T84** (qualité de `MeasuredSpeedMps`) et à traiter avec **T93** (temporisations entre paliers) | Projet / Sécurité / Terrain | `FB_SpeedStep`, `FB_Winch`, `FB_Encoder_SpeedMonitor`, `GVL_PERSISTENT._WinchSpeedConfig` |
| T48 | 🟠 Valider les réactions et seuils par simulation puis essais terrain : démarrage en charge, treuil freiné, câble mou, effort asymétrique, perte codeur | Projet / Terrain | Matrice V1–V7 (ex-AF_Partie-14 §7.4.4, archivée) ; à rejouer en simulation manuelle / terrain |
| T49 | ✅ Hauteurs unifiées : 8,0 m limite exploitation ; 8,5 m capteur/homing. Références 12,0/12,5 purgées du code et des specs actives | Projet + Mécanique | WINCH-CORE-01, `GVL_PERSISTENT`, P4/P7/P9/P10 |
| T50 | ✅ `FB_SpeedStep` borné/validé ; ConfigError remonté dans `FB_Winch.ErrorId` bit2, sorties sûres. Palier 1 tout FALSE autorisé (résistances insérées) | Projet | WINCH-CORE-01, `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §2.2 |
| T52 | 🔴 Valider chaîne `PowerCutOff` physique : câblage sorties A/B, contacteur puissance, retour confirmation, temps coupure réel (P0.3 audit Winch) | Électricité + Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §2.3, `PRG_10_Outputs.st:136-156` |
| T53 | ✅ Choix implémenté : safety stricte par défaut ; bypass individuel maintenu uniquement en MAINT_N2 + Reset, sans masquer les autres défauts | Projet | WINCH-CORE-01, `FB_Safety_Winch`, P9 |
| T54 | 🟠 Documenter latence PRG_03→PRG_06→PRG_10 (~10 ms) et l'intégrer au calcul temps d'arrêt (P1.2) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.2 |
| T55 | 🟠 Définir stratégie synchronisme unique (info / mineur / majeur / critique) et aligner DOC/CODE/IHM (P1.3) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.3, `FB_WinchSync`, `PRG_06:329-338` |
| T56 | 🟠 Caractériser seuils sécurité terrain (0,02 m/s, 2 m, 3 s, 800 ms, 500 ms) avec charge/vide/frein chaud (P1.4) | Projet / Terrain | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.4, `FB_Safety_Winch:149-169` |
| T57 | 🟠 Unifier limite haute M2 selon offset benne : une seule limite active distribuée à Winch/Safety/IHM (P1.5) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.5, `PRG_06:379` vs `PRG_03:53,96` |
| T58 | 🟠 Purge boot des commandes RETAIN réalisée dans PRG_00 ; séparation Config/Commands/Status/Alarms différée jusqu'à maquette IHM validée | Projet + IHM | WINCH-CORE-01, `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §5.2 |
| T59 | 🟡 IHM afficher arrêt croisé effectif (ForbidAscentM1_Active) pas seulement safety local (P5.3) | IHM | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §5.3, `PRG_09:319,382` vs `PRG_06:393-398` |
| T60 | ✅ `E_Mode.DISABLE` neutralise explicitement FB_Winch M1/M2 et FB_Translation M3 | Projet | WINCH-CORE-01, suite TC-M7 |
| T61 | ✅ Estimateur de charge actif uniquement pour vitesse signée positive (montée) | Projet | WINCH-CORE-01, suite TC-M10 |
| T62 | ✅ Fin `ASCENDING_LOADED` alignée sur `_CableLimitM1Ascent_M` (8,0 m) | Projet | WINCH-CORE-01, suite TC-M11 |
| T63 | ⏸️ Persistance flags simulation + split `GVL_SimulationBench` reportés : bindings visualisation à maquetter avant import | Projet + IHM | REX session revertée, hors scope WINCH-CORE-01 |
| T64 | 🟠 Essais treuils du 2026-07-23 : plafond de palier vitesse réglé temporairement à `0`. Confirmer le comportement effectif, tracer les essais, puis définir/restaurer la valeur d'exploitation avant mise en service normale | Projet / Terrain | `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-003 |
| T65 | ✅ Résolu — Test PLC automatique exécuté réel CODESYS (2026-07-24) : `TESTRUN_PASSED`, TC-CP1..CP5. 1 bug de test trouvé/corrigé au passage (étape 52, garde-fou redondant — PRG_09_Supervision.st non affecté). | Projet | `CONFIG-PERSIST-01`, `PRG_09_Supervision.st` §2/§2bis/§3 |
| T66 | ✅ Résolu (Lot 2f, commit `b61e540`) : `Cycle.Cfg.SetDepth_M`/`SetOffset_M` protégés par `_CycleCfgPersist`, alarme `ConfigRestoredFromPersistent` incluse. | Projet / Sécurité | AF_Partie-11 §4, `PRG_05_Cycle.st` |
| T67 | ✅ Résolu (Lot 4) : `TranslationM3.Cmd.SetFreq_Hz` protégé par `_TranslationSetFreq_Hz` + flag `Initialized` dédié (pattern manuel, pas de pont générique — éviterait de persister aussi `BtnFwd`/`BtnRev`). | Projet | AF_Partie-11 §4, `PRG_07_TranslationControl.st:97-100` |
| T68 | ❌ Non-problème — vérifié 2026-07-24 : `NeutralXMem`/`NeutralYMem` sont des `VAR_IN_OUT` de `FB_Joystick`, `_JoystickNeutralX`/`_JoystickNeutralY` sont passées PAR RÉFÉRENCE depuis `PRG_01_Diagnostics.st` — la calibration écrit déjà directement dans le persistant. Aucune correction nécessaire. | Projet | AF_Partie-11 §4, `FB_Joystick.st` |
| T69 | ✅ Résolu (Lot 3b, commit `8f90d89`) : `Bucket.Cfg.CfgTimeoutDuration` protégé par `_BucketCfgPersist` (effet de bord du miroir de struct complet). | Projet | AF_Partie-11 §4, `PRG_09_Supervision.st` §2 |
| T70 | ❓ `Modes.SelMode`/`SelJoystickWinch`/`TglJoystickMaster` repartent en valeur restrictive (MAINT_N1) au boot — à confirmer si voulu (sécurité) ou oubli avant de traiter | Projet / Client | AF_Partie-11 §4 |
| T71 | ✅ Résolu (Lot 3c, commit `f836c0f`/`9d2d12f`) : `check_config_persistence.py` créé et intégré à `run_all_gates.py` (Gate 3). | Projet | AF_Partie-11 §5 |
| T72 | 🟠 Interverrouillage de sécurité commande / frein : conditionner l'activation des contacteurs de sens (`RelayFwd`/`RelayRev`) à l'ordre effectif de desserrage du frein (`BrakeCmd = TRUE`), pour interdire physiquement toute alimentation moteur sous frein serré par l'automate. | Projet / Sécurité | `FB_Winch.st`, `FB_Translation.st`, REX 2026-07-23 |
| T73 | 🟠 Winch : asymétrie fin de course haute (bit5, a Méca D bit11 = confirmation + escalade PowerCutOff) vs limite basse câble (bit6, Forbid seul, AUCUNE escalade). Ajouter l'équivalent Méca D pour la limite basse — seuils/délais différents selon le sens (montée = tolérance faible, descente = tolérance plus grande) | Projet / Sécurité | FB_Safety_Winch.st bit6, REX 2026-07-23 — logique seulement, pas de bypass |
| T74 | 🟠 Translation : LimitSwitch (bit6) escalade en PowerCutOff immédiatement (pas de délai de confirmation) — contrairement à Winch/Méca D qui laisse une fenêtre de confirmation avant d'escalader. Harmoniser vers le pattern Méca-style (dépassement transitoire toléré, escalade seulement si mouvement encore anormal après arrêt moteur attendu) | Projet / Sécurité | FB_Safety_Translation.st bit6, REX 2026-07-23 — logique seulement, pas de bypass |
| T75 | 🟡 `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py` : `KNOWN_VAR_OUTPUT_VIOLATIONS["MAIN/PRG_09_Supervision.st"]` obsolète depuis la restructuration Winch/Translation du 2026-07-22 (regex capture `State`/`Safety` au lieu de `M1TreuilRetenue`/etc. après passage en sous-structs) — mettre à jour la liste précise (pas d'exemption globale) | Projet | REX 2026-07-23, Lot 2a M1M2Sync |
| T76 | 🟡 `FB_Cycle.st:112` : `DrainingTime : TIME := T#5s` jamais câblé depuis `GVL_IHM`/`GVL_PERSISTENT` — paramètre en dur, jamais identifié dans l'audit persistance initial (trouvé en préparant ce chantier, hors scope) | Projet | Trouvé en préparant DOC/AUDITS/ConfigPersistence, `FB_Cycle.st:112` |
| T77 | 🟠 Architecture / POO Diagnostics : Remplacer le pré-calcul d'expressions booléennes complexes dans les entrées de `PRG_01_Diagnostics` (`(GetBusState()=1) OR (SimulationModeActive AND...)`) par la transmission directe des objets/statuts bruts matériel (`GetDeviceState()`, `GetBusState()`, `SimulationModeActive`, `BypassGlobal`). Laisser l'encapsulation POO dans `FB_Diag_CanOpen` et `FB_Diag_Ethercat` gérer l'interprétation des états et des modes. | Projet / Architecture | `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-005, `PRG_01_Diagnostics.st`, `FB_Diag_CanOpen.st`, `FB_Diag_Ethercat.st` |
| T78 | 🟠 Rampes d'accélération Treuils M1/M2 : 1) Modifier la rampe d'accélération par défaut `CfgRampAccelRate` de 50%/s à **10%/s** pour adoucir le démarrage. 2) Développer un mécanisme d'égalisation automatique dynamique des rampes d'accélération entre M1 et M2 lorsque le mode `Both` / couplé est actif (pour éviter la désynchronisation), tout en laissant les rampes dissociées et indépendantes si un seul treuil est piloté séparément. | Projet / Commande Treuils | `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-007, `PRG_TREUILS_CFC.st`, `FB_Winch.st` |
| T79 | 🟠 Diagnostic arrêt différencié M1 vs M2 : Préparer et documenter la configuration de l'outil **Trace CODESYS** (échantillonnage 10ms synchrone) comprenant : sorties commandes relais M1/M2 (`RelayFwd`, `RelayRev`, `Contactor1..4`), retours physiques (`BrakeFeedback`, `FwdRevSpeedFeedbackOff`), positions codeurs (`CablePosM1`, `CablePosM2`), consigne rampée (`SpeedRamp.Current`) et écart synchro (`DeltaPosM`, `SignedDeltaPosM`) pour distinguer un retard de commande PLC d'un décalage mécanique/frein sur le terrain. | Projet / Diagnostics terrain | `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-008, CODESYS Trace, `PRG_TREUILS_CFC.st` |



| T84 | 🟠 **Implémenté 2026-07-28 — validation CODESYS requise.** `FB_Encoder_SpeedMeasure` : 6 positions horodatées / 5 intervalles, fenêtre interne fixe 50 ms, temps réel écoulé, sans PT1/réglage externe. Seuils et temporisations safety inchangés | Projet / Sécurité | `FB_Encoder_SpeedMeasure`, AF10 v1.11 |
| T85 | 🟠 **Implémenté 2026-07-28 — validation CODESYS requise.** Vitesse absolue/signée/validité produites uniquement par `PRG_02_Encoders`; `FB_Safety_Winch` est consommateur. Bascule réel/simulé purgée par pulse générique `PRG_00_Inputs.WinchInputSourceChanged` | Projet / Architecture | AF09 v1.13, AF10 v1.11 |
| T86 | 🟠 **Implémenté 2026-07-28 — validation CODESYS requise.** Gate `Enable=FALSE` de `FB_Safety_Winch` force désormais `ForbidAscent=TRUE` | Projet / Sécurité | `FB_Safety_Winch`, AF09 v1.13 |
| T87 | 🟠 **C4** — `DelayMotorDecel` : paramètre de frein propagé depuis `FB_Winch` et réglable en mise en service, mais son `TON` est armé à `IN := FALSE` → **sans aucun effet**. Supprimer de l'interface **ou** réimplémenter la temporisation ; dans les deux cas corriger l'en-tête de `FB_Brake` qui décrit un comportement inexistant. Reporté au lot étude T91/T93 (frein/paliers) — **pas** groupé avec T84 | Projet / Sécurité | `AUDIT_Revue_Technique_v1.0.md` §6 |
| T88 | 🔵 **C6** — `FB_CycleTime` ne gère pas le bouclage de `TIME()` (~49,7 jours) : 1 cycle de `CycleTimeS` aberrant → la rampe saute à sa cible. Borné par `LIMIT(±100)` donc non dangereux, mais à-coup possible sur une machine laissée en marche continue. Garde-fou : `IF DeltaTimeMs > 1000 THEN CycleTimeS := DefaultValueS;` | Projet | `AUDIT_Revue_Technique_v1.0.md` §8 |
| T89 | 🟡 **Offset benne = ÉTAT de la benne** (MES-010, précisé 2026-07-27) : l'écart de position entre M1 et M2 **définit** l'état mécanique — `M1 = M2` (offset 0) ⇒ benne **OUVERTE** · `M2` décalé de **≈ 15 m** ⇒ benne **FERMÉE**. Ce n'est donc pas un simple réglage : c'est la grandeur qui porte l'ouverture/fermeture, et **tout le cycle en dépend**. Valeur appliquée le 2026-07-27 (`OffsetCloseM` 10.0 → 15.0). À faire : ① valider la cote au premier essai en charge ; ② vérifier que **l'ouverture/fermeture ET le cycle complet sont fonctionnels et simulables** avec cette valeur | Terrain / Projet | `REGISTRE` MES-010, `GVL_PERSISTENT`, `FB_Bucket` |
| T90 | 🟡 **Hauteurs treuils à contrôler sur site** (MES-009) : capteur haut mesuré à 8,0 m, arrêt réel ≈ 7,5 m. Appliqué le 2026-07-27 : `CfgTopSensorPos_M := 8.0` (position inscrite par le homing au déclenchement du capteur) et `CfgCableLimitAscent_M := 7.5` (limite logicielle sous le capteur physique). ⚠️ Une erreur sur `CfgTopSensorPos_M` **décale toutes les positions machine** → vérifier au premier homing que `Position_M` correspond à la cote réelle. 📌 **À inscrire aussi dans la doc** (`AF_Partie-09` §hauteurs et `AF_Partie-10` homing) : ces deux cotes sont des **valeurs de base de la configuration persistante**, pas des réglages libres | Terrain / Sécurité | `REGISTRE` MES-009, `GVL_PERSISTENT` |
| T91 | 🔴 **ÉTUDE — séquence frein / puissance à l'arrêt, ASYMÉTRIQUE selon le sens** (MES-006, cadré 2026-07-27). Raisonner comme un **engin de levage / ascenseur**, pas comme un convoyeur :<br>• **MONTÉE** : serrer le frein **d'abord**, couper la puissance **quelques dizaines de ms après** → la charge ne doit pas retomber pendant le recouvrement.<br>• **DESCENTE** : agir **immédiatement**, ne pas attendre la fin de la rampe de décélération ni un passage de palier.<br>⚠️ Crainte à instruire : **certains blocs peuvent retarder le freinage** (`FB_Ramp` qui maintient la commande tant que `SpeedRamp.Current > 0.1 %`, `FB_SpeedStep`, temporisations `FB_Brake`). Identifier **le chemin réel et le temps réel** entre « joystick au neutre » et « frein serré », dans les deux sens.<br>📌 Dépend de **T87** (`DelayMotorDecel` est aujourd'hui du code mort : le réglage prévu pour ça n'agit sur rien). **Décision non prise — étude d'abord**, essais en charge en présence du dragueur | Projet / Sécurité / Terrain | `REGISTRE` MES-006, `FB_Brake`, `FB_Winch`, `FB_Ramp`, `AUDIT_Revue_Technique` §6 |
| T93 | 🟠 **Remplacer la rampe %/s par des temporisations entre paliers, sur les treuils** (demande 2026-07-27) : `CfgRampAccelRate`/`CfgRampDecelNormalRate` en **%/s** sont **incompréhensibles pour la maintenance**, et surtout ce n'est pas ce que fait le matériel — M1/M2 sont pilotés par **contacteurs discrets** (5 paliers résistifs), il n'y a pas de vitesse continue mais des **sauts de palier**. Cible : un **temps de maintien réglable par palier** (« combien de temps sur le palier 2 avant de passer au 3 »), bien plus parlant et plus proche du réel.<br>✅ **Garder `FB_Ramp` pour M3** (variateur AC600 : la rampe de fréquence est une vraie rampe).<br>⚠️ Impact à évaluer : `FB_Winch`, `FB_SpeedStep`, `FB_Cycle`, IHM et `GVL_PERSISTENT`. **La temporisation par palier et le garde-fou vitesse (T47) sont complémentaires** : le temps de maintien donne au treuil l'occasion de se lancer, le garde-fou vérifie qu'il l'a fait. Prévoir des temporisations **différentes par palier** (le démarrage en charge est le plus critique). **Interaction directe avec T91** (le temps de décélération conditionne la séquence de freinage) → à étudier ensemble | Projet / Maintenance | Demande utilisateur 2026-07-27 |
| T94 | 🟠 **Rendre le garde-fou palier pilotable et persistant** (REX 2026-07-27) : `SpeedGuardEnableM1/M2` sont aujourd'hui des `VAR` **locales** de `PRG_TREUILS_CFC` (l. 49-50), à `FALSE` — donc ni exposées à l'IHM, ni persistantes : **un download les remet à `FALSE` et l'activation obtenue après calibration serait perdue silencieusement**. À faire : passer en `PERSISTENT` + exposer en MAINT_N2 (activation/désactivation par axe), et afficher `SpeedGuardLimited` pour que l'opérateur voie quand le palier est bridé. Prérequis à la stratégie de mise en service : garde-fou **désactivé pendant les essais**, mesures relevées, puis activé | Projet / Terrain | `PRG_TREUILS_CFC.st:49-50`, `FB_SpeedStep`, lié T47 |
| T95 | 🟠 **Outil de calibration des bandes de vitesse** (REX 2026-07-27) : pour renseigner `_WinchSpeedConfig.SpeedBandMaxMps` (aujourd'hui `[0.4, 0.8, 1.2, 1.6, 2.0]`, **valeurs théoriques** dérivées d'un `MaxMeasuredSpeedMps := 2.0` provisoire, T45), il faut **mesurer la vitesse réellement atteinte à chaque palier**, à vide **et** en charge. Rien ne l'enregistre aujourd'hui. Proposition : étendre `FB_Winch_Symmetry` (lot D1, déjà en place dans `PRG_11`) avec une table `VitesseMax[1..5]` par axe, remise à zéro sur commande — mesure passive, aucun asservissement. Sans ça, la calibration de T47 se ferait au jugé | Projet / Terrain | `FB_Winch_Symmetry`, `GVL_PERSISTENT._WinchSpeedConfig`, T45/T47 |
| T96 | 🟡 **NOUVEAU (demande utilisateur 2026-07-30) — Mode apprentissage vitesse par palier, à vide et en charge.** Remplace la saisie manuelle théorique de `SpeedBandMaxMps` (T95) par une **mesure automatisée** : un mode maintenance dédié ("Apprentissage à vide" / "Apprentissage en charge", 2 jeux de bandes distincts) fait parcourir les 5 paliers ; à chaque palier stabilisé (~1-2 s), le système capture la vitesse mesurée (peu filtrée, anti-pic) et la stocke. **Justification métier** : alimentation par groupe électrogène vs secteur peut donner des vitesses réelles différentes à charge égale — l'apprentissage évite une calibration manuelle poste par poste. **Contraintes** : valeur brute jamais utilisée telle quelle, toujours via un **offset réglable** (marge) avant utilisation comme seuil garde-fou (T47/T94). **TBD à trancher avant code** : bit unique vs 2 bits dédiés vide/charge ; durée de stabilité et fenêtre de mesure (la fenêtre 50 ms de `FB_Encoder_SpeedMeasure`, T84, est probablement insuffisante seule pour une capture stable — agrégation à définir) ; portée par treuil (M1/M2 séparés, cohérent avec `SpeedBandMaxMps` déjà par instance). Nom de FB proposé (non engageant) : `FB_WinchSpeedLearning`. Dépend de T84 (mesure vitesse fiabilisée) | Projet / Terrain | Demande utilisateur 2026-07-30, `AF_Partie-10_Fonction_Winch_v2.0.md` §9bis.3, T84/T95 |
| T99 | 🟡 **`GVL_IHM_AU` détectée orpheline (LOT_A_SUPPRESSION_CODE_MORT, 2026-08-01).** Même origine que `FB_Sim_AU_ChainFeedback`/`GVL_Simulation_AU` (banc de test AU jamais raccordé, cf. `PRG_AU_TestBench.st` archivé) : aucun champ `Cmd`/`State` jamais lu/écrit hors de son propre fichier. **Hors périmètre explicite du lot** (contrat de tâche restreint à 3 objets nommément désignés) — tracée en exemption `KNOWN_ORPHANS_PENDING_DECISION` dans `check_linkage.py` (WARN visible, pas d'erreur bloquante). **Décision à prendre par l'utilisateur** : supprimer avec `ST_Safety_Emergency_HmiCmd`/`HmiState` (même sort que les 3 objets déjà retirés) ou conserver si un usage futur est prévu | Projet | `CODE/SUPERVISION/GVL_IHM_AU.st`, `TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py` (L13) |
| T97 | 🟠 **Refonte architecture acquisition : `PRG_ACQUISITION_CFC` + `PRG_INPUTS_LD`.** Remplacer `PRG_00_Inputs` par la nouvelle frontière : `PRG_ACQUISITION_CFC` (CFC) pour device → `HwReal` → `FB_SimBench` → `HwIn` + FB complexes (Joystick, Codeurs, PositionDecoder M3) ; `PRG_INPUTS_LD` (Ladder) pour l'affichage des 21 E/S TOR qualifiées via `FB_Input`. Flux inter-programmes par DUT (`ST_HardwareImage`, `ST_AcquisitionTOR`) en `VAR_OUTPUT`, **pas de GVL-bus interne**. Ordre d'exécution cible validé dans `AF_Partie-02` §4. **Reliquats** : ① câblage exact des instances `FB_*` dans la page CFC ; ② mapping des 21 entrées TOR dans `PRG_INPUTS_LD` ; ③ migration des consommateurs vers `PRG_ACQUISITION_CFC.HwIn` / `PRG_INPUTS_LD` sorties qualifiées ; ④ validation `check_linkage.py` PASS ; ⑤ archivage `PRG_00_Inputs` legacy. | Projet | `AF_Partie-02_Architecture_Programme_v3.0.md` §4, `AF_Partie-06_Acquisition_Qualification_IO_v2.0.md` §1/§2 |
| T98 | 🟠 **`BrakeThermalFault`/`PhaseRotationFault` (`ST_CommunHMI`) déclarés mais jamais câblés vers l'IHM** — même bug de câblage que `HydraulicThermalFault` (corrigé LOT_B 2026-08-01, `PRG_SUPERVISION_CFC.st`). Les deux champs existent dans `ST_CommunHMI` (diagnostic seul, aucune commande PLC) et leurs sources brutes sont déjà lues et consommées par la sécurité (`PRG_INPUTS_LD.BrakeThermalFeedback` → `FB_Safety_Winch`/`FB_Safety_Translation`, `PRG_INPUTS_LD.PhaseRotationOk` → mêmes FB), mais **aucune assignation** `GVL_IHM.Commun.BrakeThermalFault :=` / `GVL_IHM.Commun.PhaseRotationFault :=` n'existe dans `PRG_SUPERVISION_CFC.st` : l'opérateur ne voit jamais ces défauts sur l'IHM alors que la sécurité les traite déjà. **Hors scope explicite du LOT_B** (refusé par l'utilisateur) — documenté seulement, câblage à faire dans un lot dédié (même pattern qu'`HydraulicThermalFault` : `Champ := NOT PRG_INPUTS_LD.<Source>` ou équivalent, polarité à revérifier par champ) | Projet | `CODE/SUPERVISION/_TYPES/ST_CommunHMI.st`, `CODE/MAIN/PRG_SUPERVISION_CFC.st`, `CODE/TREUILS/FB_Safety_Winch.st`, `CODE/TRANSLATION/FB_Safety_Translation.st` |
| T100 | ✅ **Gate `check_linkage.py` L9 (mapping E/S) corrigé — 72 KO → 0 KO (2026-08-01, hors périmètre codex confirmé par grep des `TASK_CONTEXT_*.yaml`, aucun n'édite `check_linkage.py`/`linkage_gates_l8_l12.py`).** Cause racine confirmée : `load_io_mapping()` (`linkage_gates_l8_l12.py`) ne construit des clés que pour `PRG_OUTPUTS_LD.*`/`PRG_INPUTS_LD.*` (seul point de contact réel avec le CSV), mais L9 comparait **tout** `VAR_OUTPUT` de **tout** PROGRAM contre cette table — faux positif garanti par construction pour ~64 des 72 erreurs (signaux internes calculés : `HydraulicFaultOk`, `Auth`, `FaultMachineReset_IHM`, `WinchM1FinalInterlockRequest`...). **Fix appliqué** : `L9Checker.check()` restreint aux deux POU physiques ; les 22 erreurs restantes (réellement dans `PRG_OUTPUTS_LD`/`PRG_INPUTS_LD`) sont un vrai écart de nommage — le CSV utilise le libellé matériel brut (`M1_RelayFwd_Up_DQ`), le code le nom métier retraité (`M1RelayFwd`) — **aucune correspondance auto inventée** (règle projet), downgradées en WARN non bloquant à rapprocher manuellement. `check_linkage.py --report` = PASS, bundle régénéré, `run_all_gates.py` : GATE 2bis (LIAISON) PASS, PyTest 409 passed/8 skipped. **Reliquat** : les 22 WARN L9 (écart nommage CSV/code) restent à trancher par l'utilisateur — pas un bug outil, juste un rapprochement manuel non fait | Projet / Outillage | `TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py` (classe `L9Checker`) |
| T92 | 🟠 **Qualification des bypass ciblés et du homing à 0 m** (MES-002) : à valider — comportement de chaque bypass, **persistance après redémarrage** (ils sont RETAIN), homing M1/M2 à 0,0 m, cohérence de la position et réarmement sûr. ⚠️ Rappelé par la revue L3 : une invalidation RETAIN remet les bypass à `FALSE`, ce qui peut **faire réapparaître un blocage qu'un bypass masquait** | Terrain / Sécurité | `REGISTRE` MES-002, `CHECKLISTS/CHECKLIST_Essais_Persistance_Bypass_Frein` (11 tests) |
| T83 | 🟠 **Bypass heartbeat IHM provisoire** : `ST_BypassNetwork.IhmHeartbeat` créé le 2026-07-27 avec défaut **`TRUE`** (bypass actif) + secours `GVL_Global.BlinkClock` — décision CK6, justifiée tant que la visu ne toggle pas `TglHeartbeatIhm`. ⚠️ Champ **RETAIN** : il survit aux downloads. **Action de livraison : repasser à `FALSE` dès que la visu est opérationnelle**, sinon la perte de l'IHM ne produit plus aucun `SafeStop` | Projet / IHM | `PRG_01_Diagnostics.st:64-67`, `ST_BypassNetwork.st:15` |
| T80 | ✅ **Résolu 2026-07-27** — **Capteur PV M3 non relié** : la voie est mappée sous `PosPV_DI_` (underscore ajouté par CODESYS sur collision) ; `PRG_00:267` lit `GVL_Translation_M3_Stub.PosPV_DI`, un stub que rien n'écrit. En réel : mot 5 capteurs incohérent en position Trémie → `SafeStop` + `PowerCutOff`, et butées extrêmes M3 inopérantes. Correction : supprimer la déclaration du stub, remapper en `M3_PosPV_DI`, corriger `PRG_00:267` | Projet / Électricité | `AUDITS/PreLivraison/ANALYSE_Impact_Chaines_Actionneurs_v1.0.md` §6.1, `TABLE_Renommage_IO_v1.0.md` §3 |
| T81 | 🔴 **Séquence de détection de fond Kobold** (mise à jour client 2026-07-31) : séquence à 4 étapes obligatoire. ① Départ hors de l'eau ($\ge +1,0$ m) $\rightarrow$ Capteur à `0` ; ② Immersion surface (fenêtre $[-0,5 ; +0,5]$ m) $\rightarrow$ Front montant à **`1`** ; ③ Plongée eau libre $\rightarrow$ Retombée à **`0`** ; ④ Toucher fond $\rightarrow$ Front montant à **`1`** (détection réelle du fond). `Fond détecté ⟺ Capteur=1 APRÈS séquence complète 0 -> 1 -> 0`. Si la séquence d'immersion n'est pas validée autour de $0,0$ m, la détection est bloquée et la descente stoppée (T82). Bornes et fenêtres en `PERSISTENT` + réglables IHM | Projet / Client | REX utilisateur 2026-07-31, `AF_Partie-04` §2 |
| T82 | 🔴 **Arrêt sécurisé si séquence Kobold invalide** (lié à T81) : `M1_M2_KoboldMeasureEnable_DQ` alimente la mesure ; sans activation **ou** sans front d'immersion attendu, aucune détection de fond n'est possible. **Deux issues, et deux seulement** : ① séquence invalide → **arrêt dans l'eau + remontée d'un défaut** (on ne descend pas à l'aveugle) ; ② séquence valide → fond détecté → **arrêt propre** (décélération normale, pas un `SafeStop`). Jamais de descente prolongée sans détection possible | Projet / Sécurité | REX utilisateur 2026-07-27 |
| T96 | 🟠 **`M3_ThermalFeedback_DI` câblé mais jamais lu** (audit nommage 2026-07-30) : disjoncteur thermique **moteur/variateur AC600** (Device.export : "Retour état disjoncteur thermique") — distinct de `BrakeThermalFeedback` (thermique frein commun M1/M2/M3, déjà remonté). Décision utilisateur 2026-07-30 : **à intégrer**, alarme à faire remonter (diagnostic Translation M3, pas d'arrêt automatique tant que non spécifié). À faire : ajouter la lecture dans `PRG_00_Inputs` (frontière `HwIn`), consommer dans `FB_Safety_Translation`/diagnostic IHM, documenter dans `AF_Partie-11/12` (Translation). ℹ️ `ConveyorInfeedReady_DI` (convoyeurs aval) analysé au même audit — **hors périmètre actuel**, pas de action | Projet / Électricité | `Device.export`, `PRG_00_Inputs` |



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

📝 **Chaque phase donne lieu à une entrée `MES-xxx`** dans `REGISTRE_Suivi_MiseEnService_v1.0.md`.

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
`REGISTRE_Suivi_MiseEnService_v1.0.md`. Toute action différée issue d'une séance doit
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

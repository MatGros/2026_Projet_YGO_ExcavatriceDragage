# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : Historique factuel des séances banc/terrain (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/WFLOW/PLAN_TASK.md` §3 (registre maître `Txx`).

---

## 1. ⚡ Règles & Statuts

| Élément | Emplacement |
|---|---|
| Test prévu & verdict Pass/Fail | Checklist métier / `PLAN_TASK` §4 |
| Mesure, anomalie, réglage terrain | 📍 Ce registre |
| Code, câblage, action différée | 📌 Ligne `Txx` dans `PLAN_TASK` §3 |
| Évolution CODE/DOC majeure | 📦 `VERSION_HISTORY.md` |

### 🚦 Statuts
- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

---

## 2. 📝 Entrées de Séances


### 🎯 Objectif de séance — 2026-08-07
- **Cible** : réaliser un **cycle complet** (descente → contact Kobold → remontée → vidage trémie) **sans sécurité particulière, ou à sécurité limitée** — validation mécanique/mouvement avant la mise en place des protections finales.
- ⚠️ **Risque noté (devoir d'alerte)** : cycle réel sur machine sans les sécurités complètes → **uniquement avec bypass explicites** (`Bypass.Global`/ciblés), **homme-mort** maintenu, vigilance opérateur, **aucun redémarrage auto après défaut**, personnes écartées de la zone.
- 📌 **Point à clarifier** : la barrière `SafetyStructureNotValidated := TRUE` (`PRG_06_Outputs_LD.st:50`) coupe toutes les sorties → confirmer le moyen d'autoriser le mouvement pour cet essai (retrait ponctuel vs bypass).

---

### MES-030 — 📦 Décision : point de sauvegarde code `v0.5.25_DepartSoirEssai`
- 📅 **Date** : 2026-08-07 | 📍 **Lieu** : Organisation projet
- 🎯 **Périmètre** : Gestion version — `CODE/` reste le **code actif** (travail de tous les agents/programmeurs) ; création d'un **dossier daté** = snapshot du dernier point qui fonctionne (`v0.5.25_DepartSoirEssai`)
- 🚦 **Statut** : 🟢 **Décision actée** (création par l'utilisateur)
- 🛠️ **Utilité** : Point de sauvegarde + **code exemple de référence** → permet aux agents/IA de **comparer le fonctionnement** et préserver les **fonctions qui marchent aujourd'hui**.
- ⚠️ **Point à valider (emplacement)** : placer le snapshot **HORS de `CODE/`** (ex. `ARCHIVES/Code/…` ou racine repo) — sinon les outils qui scannent `CODE/*.st` (bundle PLCopenXML, `G200_check_linkage.py`, gates) risquent de l'ingérer comme code actif et fausser la liaison/les gates.

---

### MES-029 — 🏁 Clôture journée & bascule de version → `v0.6.00`
- 📅 **Date** : 2026-08-07 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.25_DepartSoirEssai`
- 🎯 **Périmètre** : Clôture séance MES, transition version, jalon préréception
- 🚦 **Statut** : ✅ **Journée terminée**
- 🔍 **Constat** : Fin de la journée de MES **avec** `v0.5.25_DepartSoirEssai` (version d'essai en soirée).
- 🛠️ **Décision** : Passage en **`v0.6.00`** pour la suite du chantier et les **prochains essais**.
- 📅 **Jalon** : **Préréception le 17** (commentaires possibles à intégrer). En attendant, avancement sur le programme.
- 📌 **Action** : Logger le jalon `v0.6.00` dans `VERSION_HISTORY.md` (proposé — pas modifié sans ta validation).

---

### MES-028 — 🟠 Palier ralentissement fin de course haut trop bas si benne chargée
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : en cours
- 🎯 **Périmètre** : M1/M2 — zone de ralentissement à l'approche de la fin de course haute (`CfgSlowdownDistanceM`)
- 🚦 **Statut** : 🟠 **Action ouverte** — non corrigé, noté pour action
- 🔍 **Constat** : `WinchSlowdownMaxStep := 1` (`GVL_PERSISTENT._CommunCfgPersist`, commun M1/M2) plafonne au palier 1 dans la zone de ralentissement — palier 1 cale (couple insuffisant) si la benne est chargée. Il faut autoriser au moins le palier 2 dans cette zone.
- 🛠️ **Solution envisagée** : `WinchSlowdownMaxStep` 1 → 2 (`GVL_PERSISTENT.st:142`, `ST_CommunCfg.st:22`). Pas encore appliqué — à confirmer avant modif (impact sécurité : palier plus élevé = distance de freinage plus longue près de la butée haute).
- 📌 **Action** : décider palier cible (2 probable) et appliquer, en vérifiant que la distance de ralentissement (`CfgSlowdownDistanceM`) reste suffisante au palier retenu.

---

### MES-027 — 🟢 Mode pilotage unitaire M2 sécurisé (bornes ouvert/fermé + palier 1)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : en cours
- 🎯 **Périmètre** : M2 — pilotage unitaire joystick (`SelJoystickWinch=2`)
- 🚦 **Statut** : 🟢 **Implémenté** — défaut `TRUE` (demande client)
- 🔍 **Constat** : besoin d'un jog libre M2 borné dans les limites benne (0 → `OffsetCloseM`, config) à vitesse bridée, sans passer par `instBucket` (pas de mémorisation `CloseReq`/`OpenReq`).
- 🛠️ **Solution** : `GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits` (défaut `TRUE`) — actif uniquement en pilotage unitaire M2, borne `ForbidDescentM2`/`ForbidAscentM2` sur `CablePosM1 + OffsetOpenM/OffsetCloseM`, plafonne palier 1. Preuve : `CODE/J_SUPERVISION/_TYPES/ST_BucketCmd.st`, `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§5-6).
- 📌 **Action** : valider bornes réelles sur site (0 → 15m config actuelle).

### MES-026 — 🟡 Bypass séquence DiveSearch (réglages seuils pas encore calibrés)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : DiveSearch — confirmation fond hors préconditions strictes
- 🚦 **Statut** : 🟡 **À surveiller** — fonctionnel, réglages définitifs (`DiveStartMin_M`/`ImmersionUpper_M`/`ImmersionLower_M`) pas encore calibrés
- 🔍 **Constat** : préconditions `WAIT_PRECONDITIONS` (benne ouverte, fenêtre immersion) bloquaient toute progression tant que les seuils n'étaient pas réglés — besoin d'un chemin de test simplifié pendant la mise en service.
- 🛠️ **Solution** : `GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence` (défaut `FALSE`) — front montant Kobold pendant descente couplée confirme directement le fond ET bloque la descente (même doctrine que Fiche 05), sans passer par les préconditions. `FB_DiveSearch` continue de gérer le contacteur Kobold en parallèle (jamais désactivé). Preuve : `CODE/G_CYCLE/FB_DiveSearch.st` (`BypassPreconditions`), `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§1).
- 📌 **Action** : régler `DiveStartMin_M`/`ImmersionUpper_M`/`ImmersionLower_M` définitivement, puis repasser le toggle à `FALSE`.
- 🟡 **Suivi terrain (même jour, après essais)** : le bypass fonctionne (fond confirmé), mais `DredgingAssist.State.DiveErrorId = 2` (bit1, "séquence Kobold invalide") se déclenche quand même côté `FB_DiveSearch` — normal : ce FB continue de tourner en parallèle avec SA propre logique stricte (fenêtre immersion `ImmersionUpper_M`/`ImmersionLower_M`, pas encore calibrée, voir ci-dessus), indépendante du bypass. Obligation de faire un Reset manuel (`FaultMachineReset_IHM`) pour clear le défaut à chaque fois. Cause racine identique à l'action ouverte ci-dessus (seuils pas calibrés) — pas un bug distinct, mais gênant en pratique tant que non réglé.

### MES-025 — 🟠 Palier vitesse M2 non plafonné pendant mouvement benne (contacteurs de vitesse)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `2405976`
- 🎯 **Périmètre** : M2 — vitesse pendant ouverture/fermeture benne pilotée par `FB_Bucket`
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `instBucket.M2_ForceSlowSpeed` ("Bloque les contacteurs de vitesse de M2") ne substituait que la table de vitesse, ne plafonnait pas réellement `MaxStepAscent`/`CfgMaxStepDescente` — un contacteur de vitesse a été observé enclenché brièvement pendant `CLOSING_BUCKET` avant correctif.
- 🛠️ **Solution** : `CfgMaxStepDescente`/`MaxStepAscent` (instWinchM2) suivent désormais `instBucket.M2_ForceSlowSpeed`. Preuve : `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§6, `instWinchM2`).
- 📌 **Action** : ⚪ reproduction non confirmée après correctif — à surveiller sur prochains essais fermeture benne.

### MES-024 — 🔴 Permis de mouvement `DescendPermit`/`AscentPermit` calculés mais jamais consommés
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : Modes DiveSearch (descente) / ExtractionSequence (montée)
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `instDiveSearch.DescendPermit` et `instExtractionSequence.AscentPermit` calculés par leur FB respectif mais jamais lus dans `PRG_04`/`PRG_06` — rien n'empêchait réellement de descendre benne fermée (Dive) ou de monter sans fond confirmé (Extraction).
- 🛠️ **Solution** : `ForbidDescentDiveBucketClosed` / `ForbidAscentExtractionBottomNotConfirmed`, blocage direct indépendant du timing interne des FB. Preuve : `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§5).
- 📌 **Action** : aucune, correctif autonome.

### MES-023 — 🔴 Contacteur mesure Kobold jamais physiquement commandé
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : Capteur Kobold — activation contacteur mesure (`M1_M2_KoboldMeasureEnable_DQ`)
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `KoboldContactorCmd` (`PRG_06_Outputs_LD`) déclaré mais **jamais assigné** — chaîne `instDiveSearch.KoboldMeasureEnable → KoboldContactorCmdArbitrated` s'arrêtait net, aucune erreur de compilation/gate pour le signaler. Même classe de bug que le fix frein M3 du 2026-08-05.
- 🛠️ **Solution** : `KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated;` + coil directe sur `M1_M2_KoboldMeasureEnable_DQ` (même pattern validé M1/M2/M3). Preuve : `CODE/M_MAIN/PRG_06_Outputs_LD.st` | Générateur PLCopenXML ST→LD | `TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py` | 🟢 Généralisé (Ladder standard) | `DIRECT_HW_COILS`.
- 📌 **Action** : confirmer import CODESYS propre (risque connu, REX 2026-08-04, validé sur M1/M2/M3).

### MES-022 — 🔴 Coupe-circuit séquencement auto benne (Fiche 01) après blocages répétés terrain
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`/`2405976`
- 🎯 **Périmètre** : Benne M2 — armement automatique ouverture/fermeture sur mouvement couplé joystick
- 🚦 **Statut** : 🟢 **Implémenté** — Fiche 01 désactivée par défaut, pilotage repose sur DiveSearch/ExtractionSequence
- 🔍 **Constat** : essais terrain → benne coincée en boucle (`M2_LimitShift` figé empêchait d'atteindre la cible fermeture), verrouillait M1/M2 en permanence (`instBucket.Busy`). Décision client : revenir au pilotage par modes le temps de fiabiliser.
- 🛠️ **Solution** : `GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing` (défaut `FALSE`) — `CoupledDiveBucketOpenArmed`/`CoupledAscentBucketCloseArmed` figés `FALSE` tant que non réarmé. `M2_LimitShift` rendu dynamique (suit la position réelle de M1, plus une limite théorique figée). Preuve : `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (§1, `M2_LimitShift`).
- 📌 **Action** : ne réactiver le toggle qu'après validation terrain complète de la séquence.

### MES-021 — 🏗️ Ajout mode « au-dessus de la trémie » : joystick → commande ouverture benne
- 🟢 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Benne M2 / translation M3 — mode vidage à la trémie, pilotage joystick
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/07)**
- 🔍 **Constat** : Ajout d'un **mode « au-dessus de la trémie »** où le **joystick commande l'ouverture** (de la benne).
- 🛠️ **Preuve code** : `CODE/M_MAIN/PRG_04_Treuils_Benne.st:221-234` (`DumpAtTremieAssistActive` + `M3_AtTremieStable` → `DumpAtTremieBucketOpenArmed` → `CmdOpen_IHM`). Le mouvement réel reste gouverné par la demande joystick (`MotionRequestActive`/`MotionDirection`).
- 📌 **À valider** : comportement armement ouverture sur site au chargement `v0.5.9_IOTest`.

---

### MES-020 — 🔧 Simplification : commande **frein directe** avec les contacteurs de sens
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Treuils M1/M2 — commande frein vs contacteurs de sens
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/06)**
- 🔍 **Constat / Décision** : Simplification : le frein est commandé **directement** par la commande des **contacteurs de sens** (`BrakeCmd := RelayFwd OR RelayRev`). Aucun écart frein/mouvement possible.
- 🛠️ **Preuve code** : `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock_LD.st:244` (`BrakeCmd := RelayFwd OR RelayRev`), `FB_WinchOutputInterlock_LD.st:13-15`, `FB_Winch.st:9` (+ câblage `PRG_06_Outputs_LD`).
- 📌 **Action** : À tester au chargement `v0.5.9_IOTest` (séquence frein+sens).

---

### MES-019 — ⚙️ Paramétrage variateur AC600 M3 (moteur + décélération)
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Variateur AC600 M3 — paramétrage moteur & rampes
- 🚦 **Statut** : 🟡 **Paramètres posés — à compléter/vérifier en essai**
- 🔍 **Paramètres** :
  - **F10.54** + **F2.xx** → **paramétrage moteur** *(valeurs exactes à préciser)*
  - **F01.22/23 rampes variateur** (valeurs finales) : **Accel = 1,5 s** · **Decel = 2 s**
  - **Rampes PLC** (`FB_Translation` %/s) : **Accel = 40 %/s** · **Decel = 50 %/s**
- 🛠️ **Cohérence** : rampe variateur + rampe logicielle PLC en **série** → c'est la plus lente qui domine. Vérifier l'effet réel à l'essai (allure/arrêt).
- ⚠️ **Repo `v0.5.9`** : les défauts `GVL_PERSISTENT.st:89-91` sont **accel 20 / decel 40** — tes valeurs terrain (40/50) ne sont pas encore dans le repo. Confirmer si elles doivent y être portées.
- 📌 **Action** : Compléter les valeurs `F2.xx`/`F10.54` (U/f, courant, vitesse nominale…).

---

### 📌 À faire — Ajouter les **In/Out (entrées/sorties) dans l'IHM** pour la maintenance
- 🎯 **Demande** : Rendre visibles dans l'IHM les **entrées/sorties physiques** (état réel) en vue maintenance — utile pour la MES, le test I/O (`v0.5.9_IOTest`) et le diagnostic câblage (polarité NO/NC, sens).
- 🚦 **Statut** : ⚪ **Non traité — à planifier**
- 📌 **Action différée** : Créer une ligne `Txx` dans `PLAN_TASK` §3 (proposé ; pas modifié sans ta validation).

---

### MES-018 — 📡 Translation M3 : à l'installation / retour, décodage des capteurs → position connue
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Translation M3 — décodage 5 capteurs (Trémie|PV|P2|P1|Maintenance), position au démarrage/installation
- 🚦 **Statut** : 🟢 **Modification faite — OK**
- 🔍 **Constat** : À l'**installation / retour** (démarrage, remise en place), la position n'était pas connue directement.
- 🛠️ **Modification** : Avec le **décodage des capteurs**, le code **dit « on est à telle position »** dès le démarrage (position initialisée depuis le capteur actif, sans homing).
- ⚠️ **Repo** : comportement déjà implémenté à `CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st:90-99` (init au premier capteur actif) + recalage absolu aux fronts (§2). ⚠️ L'init se base sur les **capteurs bruts**, pas sur le mot **validé** par `FB_Translation_PositionDecoder` (combinaisons incohérentes) — vérifier le garde-fou incohérence au démarrage dans `v0.5.9`.

---

### MES-017 — 🎯 Ajout : référencement codeurs absolus **sans condition via IHM**
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Codeurs absolus M1/M2, référencement via IHM (`FB_Encoder_Homing`, homing unitaire/nominal)
- 🚦 **Statut** : 🟢 **Ajouté — à valider en essai**
- 🔍 **Constat** : Avant, le référencement était **conditionné** (modes MAINT_N1/N2, sélection treuil, codeur opérationnel, contacteurs relâchés, frein appliqué — cf. `GVL_Troubleshooting.HomingM1/M2` Step1-5).
- 🛠️ **Ajout** : Possibilité de **référencement sans condition via IHM** — preset logiciel immédiat (`HomingRefRaw` recalculé à l'instant, `CablePosM` bascule à `0.0 m` / `CfgTopSensorPosM`).
- ⚠️ **Repo** : le mécanisme « Homing logiciel immédiat sans condition » existe déjà à `CODE/E_CODEURS/FB_Encoder_Homing.st:126-135` (front `Home`, `UnitaryMode`). Vérifier qu'il est **câblé/exposé IHM dans `v0.5.9`** (la version repo est la nouvelle archi, pas la `v0.4.27` chargée machine).

---

### MES-016 — ⚠️ PRG_06 : variables output déclarées **même nom que les sorties HW** → chevauchement/écrasement
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : `PRG_06_Outputs_LD` — sorties HW M1/M2/M3 (`*_DQ`/`*_RQ`), mapping E/S device
- 🚦 **Statut** : 🟠 **Gros problème — traitement à confirmer**
- 🔍 **Constat** : Des `VAR_OUTPUT` de `PRG_06` étaient déclarées **avec le même nom que les sorties hardware** (`M1/M2/M3_BrakeRelease_RQ`, `*_DQ`…). → **chevauchement / écrasement** → les sorties **n'étaient pas pilotées correctement**.
- 💡 **Mécanisme (vérifié)** : le mapping E/S (`Device.export` l.42842-42844, `CreateVariable=True`) auto-crée des **variables globales device** nommées `M3_BrakeRelease_RQ`, etc. Le POU déclare le **même symbole** en `VAR_OUTPUT` → la portée locale gagne : l'affectation du programme écrit la **copie POU**, la sortie physique (reliée à la globale) ne reçoit **rien**.
- 🛠️ **Traitement** : *(à confirmer — désambiguïsation noms VS variables locales de mapping, cf. note `PRG_06_Outputs_LD.st` l.190-201 : le raccordement physique doit pointer les **variables locales** (ex. `M1BrakeCmd`), pas les `*_DQ/*_RQ`)*
- ⚠️ **Repo `v0.5.9` à contrôler** : `CODE/M_MAIN/PRG_06_Outputs_LD.st:64,72,74` garde les `VAR_OUTPUT` homonymes ET `Device.export` garde le mapping sur ces noms → risque identique si le mapping n'est pas déplacé sur les variables locales. **Réauditer au chargement `v0.5.9_IOTest`.**

---

### MES-015 — 📉 Translation M3 : ralentissement PV en **Hz fixe** au lieu d'un **%**
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Ralentissement PV (`FB_Translation.st` §4bis, `ApproachSpeedHz`), `PRG_05_Translation.st:181` (`GVL_PERSISTENT._TranslationApproachSpeed_Hz`)
- 🚦 **Statut** : 🟡 **Constat — décision à prendre** (garde en Hz ou passage en %)
- 🔍 **Constat** : Le ralentissement PV est exprimé en **Hz fixe** (`ApproachSpeedHz := 10.0`), converti en % de l'échelle max au vol (`FB_Translation.st:142-143`). Moins parlant pour la maintenance que la consigne vitesse (en %) utilisée partout ailleurs.
- 🛠️ **Décision** : À trancher pendant la MES (cohérence IHM/maintenance).

### 🧭 Relevés à prendre — Calibration vitesse Translation M3 (Hz ↔ m/s)
> Objectif : relier fréquence variateur (Hz) ↔ vitesse réelle du pont (m/s) à partir de **temps de déplacement mesurés** sur une **distance connue** entre capteurs (Trémie | PV | P2 | P1 | Maintenance).

| # | Sens (Fwd/Rev) | Trajet capteurs | Distance (m) | Temps mesuré (s) | Vitesse (m/s) | Hz variateur | Consigne % | Commentaire |
|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |

---

### MES-014 — ⛓️ Fdc traité comme « Fdc extrême » → défaut + blocage ; corrigé en Fdc normal
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Fins de course (Fdc) — traitement extrême vs normal (`FB_Translation` / `FB_Safety_Translation` M3)
- 🚦 **Statut** : 🟢 **Modification faite — OK**
- 🔍 **Constat** : Un Fdc était traité comme **Fdc extrême** → générait un **défaut avec blocage** (`ErrorId` bit6 / `ErrorLimitSwitch`, escalade `TonLimitSwitchOverrun` dans `FB_Safety_Translation.st`).
- 🛠️ **Modification** : Traitement passé en **Fdc normal** (simple butée/arrêt, sans défaut bloquant) — **fait, OK**.
- ⚠️ **À confirmer** : le code repo (`CODE/I_TRANSLATION/FB_Translation.st:23-24`, `FB_Safety_Translation.st:30-31,63`) garde la sémantique « extrême ». Vérifier que la modif « Fdc normal » est bien répercutée dans `v0.5.9` (nouvelle archi).

---

### MES-013 — 🔌 `M3_BrakeRelease_RQ` : Sorties HW non mappées / GVL sans lien
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Sorties automate HW (`PRG_06_Outputs_LD`, `M3_BrakeRelease_RQ`), mapping E/S devices
- 🚦 **Statut** : 🟢 **Problème traité — noté** (revoir au chargement `v0.5.9_IOTest`)
- 🔍 **Constat** : Sorties HW **non mappées** physiquement dans le programme chargé ; **GVL utilisés sans lien** vers le matériel (pas d'adresse device).
- 🛠️ **Traitement** : Raccordement via **mapping E/S manuel CODESYS** (`Device.export`) — geste documenté `CODE/M_MAIN/PRG_06_Outputs_LD.st` §2 (l. 190-201, 221-225) : les `*_DQ/*_RQ` sont auto-créées par le mapping, absentes du bundle isolé.
- 📌 **Action** : Réauditer le mapping de **toutes** les sorties HW (M1/M2/M3) pendant `v0.5.9_IOTest`.

---

### MES-012 — 🖥️ Présentation Machine & Manipulation Programme (Séance 2026-08-05)
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite` (chargée machine, avant modification)
- 🎯 **Périmètre** : Matin = présentation de la machine · manipulation du programme (config persistance, supervision, translation)
- 🚦 **Statut** : ⚪ **Non testé — en attente de données**
- 🔍 **Constat / Essai** : *(à renseigner pendant la séance)*
- 🛠️ **Solution / Décision** : *(à renseigner pendant la séance)*
- 📌 **Plan annoncé** : Après cette séance → charger **`v0.5.9_IOTest`** (nouvelle architecture) : test des **entrées/sorties de tous les devices** pour valider le câblage (NO/NC, sens, polarité)
- 📌 **Action différée** : *(réf `Txx` si nécessaire)*

---

### MES-011 — ⚡ Polarité Retour Frein (Câblage vs Logiciel)
- 📅 **Date** : 2026-07-26 | 📍 **Lieu** : Terrain (Armoire) | 🏷️ **Commit** : `1d2e086`
- 🎯 **Périmètre** : Retours freins M1, M2, M3 (`PRG_00_Inputs.st`, `FB_Brake.st`, `AF_Partie-09` §5bis)
- 🚦 **Statut** : ✅ Corrigé logiciel ➔ ⚡ **Contrôle terrain au 1er essai**
- 🔍 **Constat** :
  - Frein à **manque de courant** (`PLC Output = 1 ➔ Frein Ouvert`).
  - Retour câblé = **contacteur de commande** (`DI = 1 ⟺ Frein OUVERT`).
  - 💥 **Bug initial** : Le PLC supposait `TRUE = Frein serré` dans `FB_Safety_Winch` (Méca A/B/D/E) et `FB_Safety_Translation` (Méca B).
- ❓ **Pourquoi invisible avant ?** : `Sensor*ContactorFeedbackIsReal = FALSE`. Le modèle simulé renvoyait `NOT BrakeCmd` (compensait la fausse logique).
- ⚠️ **Risques évités sur matériel réel** :
  - **Méca B** ➔ `SafeStop` + `PowerCutOff` 3s après chaque arrêt.
  - **Méca A désarmé** ➔ Perte détection roue libre / frein qui patine.
  - `FB_Brake` en incohérence ➔ Serrage frein sous couple + coupure relais (cause incident `v0.4.27`).
- 🛠️ **Fix appliqué** : Normalisation frontière NO/NC via `FB_Input` : `PRG_00_Inputs.BrakeFeedbackInvertLogic : BOOL := TRUE`. Modèle simulé fixé (`:= BrakeCmd`). `FB_Brake` incohérence `<>` ➔ `=`. `FB_Safety_*` intacts.
  > ⚠️ **RÉVOQUÉ 2026-08-03** : `BrakeFeedbackInvertLogic := FALSE` (plus d'inversion). `M1BrakeFeedback = M1_BrakeIsOpen_DI` (TRUE = frein ouvert). `FB_Brake` test repasse en `<>`. `FB_Safety_*` conditions inversées (`NOT BrakeFeedback`) pour garder le même comportement. Voir `LOT_SAFETY_POLARITE_FREIN`.
- ~~🔩 **Action Terrain (Machine à l'arrêt, frein serré)** :~~
  ~~1. Lire `M1_BrakeFeedback_DI`.~~
  ~~2. Si `0` ➔ Conforme (`BrakeFeedbackInvertLogic = TRUE`).~~
  ~~3. Si `1` ➔ Câblage inversé ➔ passer `BrakeFeedbackInvertLogic := FALSE` à chaud + figer init.~~
  > Procédure supprimée : plus de `BrakeFeedbackInvertLogic` à ajuster (constant à FALSE, logique directe).
- 🛑 **Limite connue** : Retour = contacteur, PAS le frein physique. Seul **Méca A** (dérive codeur, `FB_Safety_Winch` bit7) détecte la patinage (`0,02 m/s` direct).
- 🚀 **Activation** : Passer `SensorM1/M2/M3ContactorFeedbackIsReal := TRUE` **axe par axe**.

---

### MES-010 — 📐 Mesure Offset M1/M2 Fermeture Benne
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Benne M2, offset ouverture/fermeture (`FB_Bucket.ActiveOffsetM`)
- 🚦 **Statut** : 🟡 **Appliqué 2026-07-27** (`OffsetCloseM` 10.0 ➔ **15.0 m**), à reconfirmer en charge (`T89`)
- 🔍 **Constat** : Offset mesuré fermeture benne = **≈ 15 m**.
- 🛠️ **Décision** : Comparer avec `ActiveOffsetM` (`instBucket`) et `AF_Partie-11` v1.4.

---

### MES-009 — 🎯 Position Capteur Haut vs Arrêt Réel Treuils
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Capteur position haute M1/M2 (`TopPositionSensor`), arrêt treuils
- 🚦 **Statut** : 🟡 **Appliqué 2026-07-27** (`CfgTopSensorPos_M` 8.5 ➔ **8.0**, `CfgCableLimitAscent_M` 8.0 ➔ **7.5**), contrôle terrain à faire (`T90`)
- 🔍 **Constat** : Déclenchement capteur physique = **8 m**. Arrêt réel mouvement = **≈ 7,5 m** (marge ~0,5 m).
- 🛠️ **Décision** : Comparer aux cibles homing (`HomingTargetM1/M2_M`) et distance de freinage à vitesse d'approche.

---

### MES-008 — 📈 Diagnostic Arrêt M1 vs M2 (Trace CODESYS)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Treuils M1/M2, relais, freins, codeurs (`PRG_06`, `FB_Winch`, `FB_Brake`)
- 🚦 **Statut** : 🟠 **Action ouverte** (`T79`)
- 🔍 **Constat** : Écart de comportement à l'arrêt entre M1 (Retenue) et M2 (Benne). Besoin de trancher entre **commande PLC dissymétrique** et **retard mécanique/hydraulique**.
- 🛠️ **Config Trace 10ms à créer** :
  1. **Sorties PLC** : `RelayFwd/Rev`, `Contactor1..4`, `BrakeCmd`.
  2. **Feedbacks** : `BrakeFeedback`, `FwdRevSpeedFeedbackOff`.
  3. **Dynamique** : `SpeedRamp.Current`, `CablePosM`, `MeasuredSpeedMps`.
  4. **Écart** : `DeltaPosM`, `SignedDeltaPosM` (`FB_WinchSync`).

---

### MES-007 — ⚖️ Alignement Rampes Accél M1/M2 en Mode Couplé (Both)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Treuils M1/M2, rampes `CfgRampAccelRate`
- 🚦 **Statut** : 🟠 **Action ouverte** (`T78`)
- 🔍 **Constat** :
  1. Rampe accél nominale à adoucir : 50%/s ➔ **10%/s**.
  2. Si rampes M1/M2 différentes en mode `Both` (couplé) ➔ accélérations différentes ➔ désynchronisation mécanique.
- 🛠️ **Solution** : Égalisation automatique dynamique des rampes (`CfgRampAccelRate`) active **uniquement en mode `Both`**, conservation des rampes indifs en séparé.

---

### MES-006 — 🛑 Compromis Freinage Treuils : Glissement vs Choc
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : M1/M2, pilotage freins et rampes décél
- 🚦 **Statut** : 🟡 **À surveiller / Réglage terrain**
- 🔍 **Constat** : Sensation de "glissement" au retour joystick neutre en petite vitesse.
- 💡 **Analyse** :
  1. Decel normale maintient commande tant que `SpeedRamp.Current > 0.1%` (évite les chocs).
  2. Couper trop net = à-coups violents sur flèche, câbles et réducteurs.
  3. **Levier** : Conserver la rampe progressive mais optimiser `DelayMotorDecel` (`FB_Brake.st`) dès vitesse nulle.
- 🛠️ **Décision** : Rampes inchangées au code. Ajustement fin du délai de fermeture frein à faire avec le dragueur en charge.

---

### MES-005 — 🏗️ Refactoring Architecture Diagnostics (POO vs Externe)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain / Architecture
- 🎯 **Périmètre** : `PRG_01_Diagnostics`, `FB_Diag_CanOpen`, `FB_Diag_Ethercat`
- 🚦 **Statut** : 🟠 **Action ouverte** (`T77`)
- 🔍 **Constat** : Fausse alarme `CANbusOnline = FALSE` avec joystick fonctionnel. `PRG_01` calculait une logique complexe dans les entrées du FB (`(GetBusState() = 1) OR (SimulationModeActive AND NOT BusIsReal)...`).
- 💥 **Problèmes POO** :
  1. Logique métier/simu sortie des FB.
  2. FB "aveugle" incapable de gérer les états transitoires légitimes (`BUS_WARNING`, boot).
  3. Alarmes bloquées intempestivement.
- 🛠️ **Cible** : Passer les statuts bruts aux FB (`CANbus.GetBusState()`, `JOY1.GetDeviceState()`, `AC600.GetDeviceState()`, `SimulationModeActive`, `BypassGlobal`). Chaque FB gère sa propre machine d'état.

---

### MES-004 — 🔓 Purge Retours Contacteurs/Freins par Bypass Global
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Terrain | 📑 **Audit** : `AUDIT_BypassGlobal_Homogenization_v1.0.md`
- 🎯 **Périmètre** : M1, M2, M3, `FB_Winch`, `FB_Translation`, `FB_Brake`
- 🚦 **Statut** : 🟢 **Validé / Appliqué**
- 🔍 **Constat** : En `Bypass.Global`, `FB_Brake` et `FB_Winch` gardaient leurs erreurs `StuckOpen`/`StuckClosed` mémorisées (entrées reliées à la simu seule). Axe bloqué à 0.
- 🛠️ **Fix appliqué** : Entrée `BypassContactorCheck` alimentée avec `OR GVL_IHM.Mx.Bypass.Global` (`PRG_06`, `PRG_07`). Purge immédiate des erreurs.
- ⚠️ **Sécurité M2** : Alimenter les contacteurs de sens avant l'ouverture du frein fait forcer le moteur sous frein serré. Ajout nécessaire d'un verrou interdisant les contacteurs de sens si frein non piloté.

---

### MES-003 — 🐢 Limitation Temporaire Palier Vitesse Treuils
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Essais Treuils
- 🎯 **Périmètre** : Winch M1/M2
- 🚦 **Statut** : 🟠 **Réglage temporaire d'essai** (`T64`)
- 🛠️ **Réglage** : Plafond palier vitesse limité à `0` pour réduire la vitesse/énergie lors des 1ers essais.
- 📌 **Action `T64`** : Vérifier décodeur paliers + contacteurs pilotés, puis restaurer la valeur d'exploitation.

---

### MES-002 — 🎯 Bypass Ciblés & Homing à 0 m
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Dev / Prépa MES | 🏷️ **Commit** : `96ef589`
- 🎯 **Périmètre** : M1/M2, M3, réseau, codeurs (`GVL_BypassRetain`, `FB_Encoder_Homing`)
- 🚦 **Statut** : 🟡 **À valider banc/terrain**
- 🛠️ **Réalisé** : Bypass globaux/ciblés regroupés dans `GVL_BypassRetain`. Homing unitaire M1/M2 réglable init à `0,0 m` (ignore capteur haut, prend la pos courante).
- ⚠️ **Vigilance** : Désactiver les bypass dès le matériel validé.

---

### MES-001 — 📋 Création Registre Initial
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Documentation
- 🎯 **Périmètre** : Registre MES/REX
- 🚦 **Statut** : 🟢 **Validé** (remplacé par l'usage courant)

---

## 3. 📄 Modèle à Dupliquer

```md
### MES-XXX — Titre court
- 📅 **Date** : YYYY-MM-DD | 📍 **Lieu** : Simulation / Banc / Terrain | 🏷️ **Version** : Commit/Export
- 🎯 **Périmètre** : Axe / Fonction / Composant
- 🚦 **Statut** : 🟢 / 🟡 / 🟠 / 🔴 / ⚪
- 🔍 **Constat / Essai** : Mesures, observations, faits
- 🛠️ **Solution / Décision** : Réglage, fix, validation
- 📌 **Action différée** : Réf `Txx` dans PLAN_TASK §3
```

---

## 4. ✅ Procédure de Clôture `Txx`
1. Ajouter l'entrée `MES-XXX` avec preuve.
2. Mettre `✅` + réf MES dans `PLAN_TASK` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.

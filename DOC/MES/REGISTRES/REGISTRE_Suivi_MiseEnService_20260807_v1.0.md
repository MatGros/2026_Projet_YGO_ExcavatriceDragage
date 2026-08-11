# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : Historique factuel des séances banc/terrain (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/PLAN_TASK_v1.0.md` §3 (registre maître `Txx`).

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

### MES-020 — 🔧 Simplification : commande **frein directe** avec les contacteurs de sens
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Treuils M1/M2 — commande frein vs contacteurs de sens
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/06)**
- 🔍 **Constat / Décision** : Simplification : le frein est commandé **directement** par la commande des **contacteurs de sens** (`BrakeCmd := RelayFwd OR RelayRev`). Aucun écart frein/mouvement possible.
- 🛠️ **Preuve code** : `CODE/TREUILS/FB_WinchOutputInterlock_LD.st:244` (`BrakeCmd := RelayFwd OR RelayRev`), `FB_WinchOutputInterlock_LD.st:13-15`, `FB_Winch.st:9` (+ câblage `PRG_06_Outputs_LD`).
- 📌 **Action** : À tester au chargement `v0.5.9_IOTest` (séquence frein+sens).

---

### MES-021 — 🏗️ Ajout mode « au-dessus de la trémie » : joystick → commande ouverture benne
- 🟢 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Benne M2 / translation M3 — mode vidage à la trémie, pilotage joystick
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/07)**
- 🔍 **Constat** : Ajout d'un **mode « au-dessus de la trémie »** où le **joystick commande l'ouverture** (de la benne).
- 🛠️ **Preuve code** : `CODE/MAIN/PRG_04_Treuils_Benne.st:221-234` (`DumpAtTremieAssistActive` + `M3_AtTremieStable` → `DumpAtTremieBucketOpenArmed` → `CmdOpen_IHM`). Le mouvement réel reste gouverné par la demande joystick (`MotionRequestActive`/`MotionDirection`).
- 📌 **À valider** : comportement armement ouverture sur site au chargement `v0.5.9_IOTest`.

---

### MES-022 — 🔴 Coupe-circuit séquencement auto benne (Fiche 01) après blocages répétés terrain
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`/`2405976`
- 🎯 **Périmètre** : Benne M2 — armement automatique ouverture/fermeture sur mouvement couplé joystick
- 🚦 **Statut** : 🟢 **Implémenté** — Fiche 01 désactivée par défaut, pilotage repose sur DiveSearch/ExtractionSequence
- 🔍 **Constat** : essais terrain → benne coincée en boucle (`M2_LimitShift` figé empêchait d'atteindre la cible fermeture), verrouillait M1/M2 en permanence (`instBucket.Busy`). Décision client : revenir au pilotage par modes le temps de fiabiliser.
- 🛠️ **Solution** : `GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing` (défaut `FALSE`) — `CoupledDiveBucketOpenArmed`/`CoupledAscentBucketCloseArmed` figés `FALSE` tant que non réarmé. `M2_LimitShift` rendu dynamique (suit la position réelle de M1, plus une limite théorique figée). Preuve : `CODE/MAIN/PRG_04_Treuils_Benne.st` (§1, `M2_LimitShift`).
- 📌 **Action** : ne réactiver le toggle qu'après validation terrain complète de la séquence.

### MES-023 — 🔴 Contacteur mesure Kobold jamais physiquement commandé
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : Capteur Kobold — activation contacteur mesure (`M1_M2_KoboldMeasureEnable_DQ`)
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `KoboldContactorCmd` (`PRG_06_Outputs_LD`) déclaré mais **jamais assigné** — chaîne `instDiveSearch.KoboldMeasureEnable → KoboldContactorCmdArbitrated` s'arrêtait net, aucune erreur de compilation/gate pour le signaler. Même classe de bug que le fix frein M3 du 2026-08-05.
- 🛠️ **Solution** : `KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated;` + coil directe sur `M1_M2_KoboldMeasureEnable_DQ` (même pattern validé M1/M2/M3). Preuve : `CODE/MAIN/PRG_06_Outputs_LD.st`, `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py` (`DIRECT_HW_COILS`).
- 📌 **Action** : confirmer import CODESYS propre (risque connu, REX 2026-08-04, validé sur M1/M2/M3).

### MES-024 — 🔴 Permis de mouvement `DescendPermit`/`AscentPermit` calculés mais jamais consommés
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : Modes DiveSearch (descente) / ExtractionSequence (montée)
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `instDiveSearch.DescendPermit` et `instExtractionSequence.AscentPermit` calculés par leur FB respectif mais jamais lus dans `PRG_04`/`PRG_06` — rien n'empêchait réellement de descendre benne fermée (Dive) ou de monter sans fond confirmé (Extraction).
- 🛠️ **Solution** : `ForbidDescentDiveBucketClosed` / `ForbidAscentExtractionBottomNotConfirmed`, blocage direct indépendant du timing interne des FB. Preuve : `CODE/MAIN/PRG_04_Treuils_Benne.st` (§5).
- 📌 **Action** : aucune, correctif autonome.

### MES-025 — 🟠 Palier vitesse M2 non plafonné pendant mouvement benne (contacteurs de vitesse)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `2405976`
- 🎯 **Périmètre** : M2 — vitesse pendant ouverture/fermeture benne pilotée par `FB_Bucket`
- 🚦 **Statut** : 🟢 **Corrigé**
- 🔍 **Constat** : `instBucket.M2_ForceSlowSpeed` ("Bloque les contacteurs de vitesse de M2") ne substituait que la table de vitesse, ne plafonnait pas réellement `MaxStepAscent`/`CfgMaxStepDescente` — un contacteur de vitesse a été observé enclenché brièvement pendant `CLOSING_BUCKET` avant correctif.
- 🛠️ **Solution** : `CfgMaxStepDescente`/`MaxStepAscent` (instWinchM2) suivent désormais `instBucket.M2_ForceSlowSpeed`. Preuve : `CODE/MAIN/PRG_04_Treuils_Benne.st` (§6, `instWinchM2`).
- 📌 **Action** : ⚪ reproduction non confirmée après correctif — à surveiller sur prochains essais fermeture benne.

### MES-026 — 🟡 Bypass séquence DiveSearch (réglages seuils pas encore calibrés)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `aa4219c`
- 🎯 **Périmètre** : DiveSearch — confirmation fond hors préconditions strictes
- 🚦 **Statut** : 🟡 **À surveiller** — fonctionnel, réglages définitifs (`DiveStartMin_M`/`ImmersionUpper_M`/`ImmersionLower_M`) pas encore calibrés
- 🔍 **Constat** : préconditions `WAIT_PRECONDITIONS` (benne ouverte, fenêtre immersion) bloquaient toute progression tant que les seuils n'étaient pas réglés — besoin d'un chemin de test simplifié pendant la mise en service.
- 🛠️ **Solution** : `GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence` (défaut `FALSE`) — front montant Kobold pendant descente couplée confirme directement le fond ET bloque la descente (même doctrine que Fiche 05), sans passer par les préconditions. `FB_DiveSearch` continue de gérer le contacteur Kobold en parallèle (jamais désactivé). Preuve : `CODE/CYCLE/FB_DiveSearch.st` (`BypassPreconditions`), `CODE/MAIN/PRG_04_Treuils_Benne.st` (§1).
- 📌 **Action** : régler `DiveStartMin_M`/`ImmersionUpper_M`/`ImmersionLower_M` définitivement, puis repasser le toggle à `FALSE`.
- 🟡 **Suivi terrain (même jour, après essais)** : le bypass fonctionne (fond confirmé), mais `DredgingAssist.State.DiveErrorId = 2` (bit1, "séquence Kobold invalide") se déclenche quand même côté `FB_DiveSearch` — normal : ce FB continue de tourner en parallèle avec SA propre logique stricte (fenêtre immersion `ImmersionUpper_M`/`ImmersionLower_M`, pas encore calibrée, voir ci-dessus), indépendante du bypass. Obligation de faire un Reset manuel (`FaultMachineReset_IHM`) pour clear le défaut à chaque fois. Cause racine identique à l'action ouverte ci-dessus (seuils pas calibrés) — pas un bug distinct, mais gênant en pratique tant que non réglé.

### MES-027 — 🟢 Mode pilotage unitaire M2 sécurisé (bornes ouvert/fermé + palier 1)
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : en cours
- 🎯 **Périmètre** : M2 — pilotage unitaire joystick (`SelJoystickWinch=2`)
- 🚦 **Statut** : 🟢 **Implémenté** — défaut `TRUE` (demande client)
- 🔍 **Constat** : besoin d'un jog libre M2 borné dans les limites benne (0 → `OffsetCloseM`, config) à vitesse bridée, sans passer par `instBucket` (pas de mémorisation `CloseReq`/`OpenReq`).
- 🛠️ **Solution** : `GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits` (défaut `TRUE`) — actif uniquement en pilotage unitaire M2, borne `ForbidDescentM2`/`ForbidAscentM2` sur `CablePosM1 + OffsetOpenM/OffsetCloseM`, plafonne palier 1. Preuve : `CODE/SUPERVISION/_TYPES/ST_BucketCmd.st`, `CODE/MAIN/PRG_04_Treuils_Benne.st` (§5-6).
- 📌 **Action** : valider bornes réelles sur site (0 → 15m config actuelle).

### MES-028 — 🟠 Palier ralentissement fin de course haut trop bas si benne chargée
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : en cours
- 🎯 **Périmètre** : M1/M2 — zone de ralentissement à l'approche de la fin de course haute (`CfgSlowdownDistanceM`)
- 🚦 **Statut** : 🟠 **Action ouverte** — non corrigé, noté pour action
- 🔍 **Constat** : `WinchSlowdownMaxStep := 1` (`GVL_PERSISTENT._CommunCfgPersist`, commun M1/M2) plafonne au palier 1 dans la zone de ralentissement — palier 1 cale (couple insuffisant) si la benne est chargée. Il faut autoriser au moins le palier 2 dans cette zone.
- 🛠️ **Solution envisagée** : `WinchSlowdownMaxStep` 1 → 2 (`GVL_PERSISTENT.st:142`, `ST_CommunCfg.st:22`). Pas encore appliqué — à confirmer avant modif (impact sécurité : palier plus élevé = distance de freinage plus longue près de la butée haute).
- 📌 **Action** : décider palier cible (2 probable) et appliquer, en vérifiant que la distance de ralentissement (`CfgSlowdownDistanceM`) reste suffisante au palier retenu.

---

### MES-022 — 🏁 Clôture journée & bascule de version → `v0.6.00`
- 📅 **Date** : 2026-08-07 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.25_DepartSoirEssai`
- 🎯 **Périmètre** : Clôture séance MES, transition version, jalon préréception
- 🚦 **Statut** : ✅ **Journée terminée**
- 🔍 **Constat** : Fin de la journée de MES **avec** `v0.5.25_DepartSoirEssai` (version d'essai en soirée).
- 🛠️ **Décision** : Passage en **`v0.6.00`** pour la suite du chantier et les **prochains essais**.
- 📅 **Jalon** : **Préréception le 17** (commentaires possibles à intégrer). En attendant, avancement sur le programme.
- 📌 **Action** : Logger le jalon `v0.6.00` dans `VERSION_HISTORY.md` (proposé — pas modifié sans ta validation).

---

### MES-023 — 📦 Décision : point de sauvegarde code `v0.5.25_DepartSoirEssai`
- 📅 **Date** : 2026-08-07 | 📍 **Lieu** : Organisation projet
- 🎯 **Périmètre** : Gestion version — `CODE/` reste le **code actif** (travail de tous les agents/programmeurs) ; création d'un **dossier daté** = snapshot du dernier point qui fonctionne (`v0.5.25_DepartSoirEssai`)
- 🚦 **Statut** : 🟢 **Décision actée** (création par l'utilisateur)
- 🛠️ **Utilité** : Point de sauvegarde + **code exemple de référence** → permet aux agents/IA de **comparer le fonctionnement** et préserver les **fonctions qui marchent aujourd'hui**.
- ⚠️ **Point à valider (emplacement)** : placer le snapshot **HORS de `CODE/`** (ex. `ARCHIVES/Code/…` ou racine repo) — sinon les outils qui scannent `CODE/*.st` (bundle PLCopenXML, `check_linkage.py`, gates) risquent de l'ingérer comme code actif et fausser la liaison/les gates.

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
2. Mettre `✅` + références MES dans `PLAN_TASK` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.
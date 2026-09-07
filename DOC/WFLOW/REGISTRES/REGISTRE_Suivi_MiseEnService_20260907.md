# 🧾 Registre de Suivi Mise en Service — Séance 2026-09-07 (v1.0)

> 🎯 **Rôle** : Historique factuel de la séance de mise en service du 2026-09-07 (actions, mesures, constats, décisions, synchronisation IHM/Cycle/Sécurité).
> 📌 **Reliquats & Actions** : `DOC/WFLOW/TASKS.yaml` §3 (registre maître `Txx`).
> 🔗 **Séance précédente** : `REGISTRE_Suivi_MiseEnService_20260905.md` (entrées MES-046 à MES-050).
> 🔢 **Numérotation entrées** : démarre aujourd'hui à **MES-051**.

---

## 1. ⚡ Règles & Statuts

### 🚦 Statuts
- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

| Élément | Emplacement |
|---|---|
| Mesure, anomalie, réglage terrain | 📍 Ce registre |
| Code, câblage, action différée | 📌 Ligne `Txx` dans `TASKS.yaml` §3 |
| Évolution CODE/DOC majeure | 📦 `VERSION_HISTORY.md` |

---

## 2. 🎯 Objectifs de séance — 2026-09-07

| # | Objectif | Tâche / Contrat | Statut |
|---|----------|-----------------|--------|
| **1** | **Fiabilisation manœuvres benne & fausses alertes synchro** : neutraliser les déclenchements de désynchronisation intempestifs lors des phases d'ouverture/fermeture benne. | `T263`, `TASK_CONTRACT_T263_BUCKET_SYNC_HOLD_4S` | 🟢 Validé |
| **2** | **Sécurisation chaîne AU au boot / essais site** : lever temporairement les blocages de chaîne de sécurité lors des démarrages tout en assurant la traçabilité de retrait avant livraison. | `T264`, `TASK_CONTRACT_T264_RETRAIT_BYPASS_POWER_CUTOFF_LIVRAISON` | 🟢 Validé |
| **3** | **Correction polarité & gestion FdC haut treuils** : analyse du capteur de sécurité `TopPositionSensor` / `M1M2_TopPositionFree_DI` sur M1 et M2. | `T268`, `TASK_CONTRACT_T268_TOP_SENSOR_POLARITY` | 🟡 À surveiller (revert conservateur) |
| **4** | **Couplage Navigation IHM ↔ Sélection de Mode** : automatiser l'activation des modes `MAINT_N1` et `SEMI_AUTO` selon la page IHM visualisée par l'opérateur. | Évolution IHM / PRG_03 | 🟢 Validé |
| **5** | **Normalisation des échanges IHM/Automate** : fiabiliser les blocs de statut/contrôle et l'image I/O lecture seule. | `T261`, `ba99abba`, `d5510430` | 🟢 Validé |

---

## 3. 📝 Entrées de Séance

### MES-051 — Coupure instantanée de la surveillance synchronisation M1/M2 lors des actions benne
- 📅 **Date** : 2026-09-07 10:15 | 📍 **Lieu** : Banc d'essais / Machine
- 🎯 **Périmètre** : `PRG_04_Treuils_Benne.st`, `FB_Bucket.st`, `FB_WinchSync.st`
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai** :
  1. Lors de l'ouverture ou fermeture benne (mouvement dissymétrique normal de M2 par rapport à M1), la surveillance d'écart M1/M2 (`FB_WinchSync`) déclenchait des avertissements ou blocages intempestifs.
  2. Le temps de stabilisation post-mouvement (coast mécanique et décélération treuils) générait un transitoire où un faux écart était détecté.
- 🛠️ **Solution appliquée** :
  - Coupure immédiate de `instWinchSync` et purge automatique de `WarnLatched` dès qu'une commande benne est active.
  - Extension du maintien de désactivation `BucketActivityHold` (`TOF`) de **2 s à 4 s** dans `PRG_04_Treuils_Benne.st` pour couvrir l'intégralité du temps de settle codeur et arrêt freins.
- 📦 **Commits associés** : `ff15a114`, `e60eea54`.

---

### MES-052 — Clarification et nommage des registres de changement de page IHM
- 📅 **Date** : 2026-09-07 11:30 | 📍 **Lieu** : IHM / Automate
- 🎯 **Périmètre** : `ST_LocalIHM_StatusBlock.st`, `ST_LocalIHM_CtrlBlock.st`, `PRG_07_Supervision.st`
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai** :
  1. Les variables d'échange de page présentaient des ambiguïtés de nommage (`CtrlInt01_SetPage` vs retour réel automate `StatusInt01_ActualPage`).
  2. L'IHM locale requiert un bloc structuré de contrôle et de statut pour l'affichage synoptique et la commande de navigation.
- 🛠️ **Solution appliquée** :
  - Renommage explicite de `StatusInt01_ActualPage : INT;` dans `ST_LocalIHM_StatusBlock.st`.
  - Alignement des structures sous `GVL_IHM.LocalIHM`.
- 📦 **Commits associés** : `ba99abba`, `ccfc7a6f`, `acb7ec41`.

---

### MES-053 — Configuration au boot du bypass AU PowerCutOff & Création Tâche T264
- 📅 **Date** : 2026-09-07 13:45 | 📍 **Lieu** : Sécurité Automate / Essais
- 🎯 **Périmètre** : `GVL_BypassRetain.st`, `FB_Safety_EmergencyManagement.st`
- 🚦 **Statut** : 🟢 **Validé** (temporaire sous garde documentaire)
- 🔍 **Constat / Essai** :
  1. En phase de mise en service et d'essais préliminaires, la coupure dure par le PLC (`PowerCutOffRequest`) compliquait les diagnostics continus.
  2. L'utilisateur a demandé d'initialiser `BypassAuPowerCutOff := TRUE;` au boot tout en conservant la possibilité de le désactiver en ligne.
- 🛠️ **Solution appliquée** :
  - `BypassAuPowerCutOff : BOOL := TRUE;` dans `GVL_BypassRetain.st`.
  - Enregistrement immédiat de la tâche **`T264`** dans `DOC/WFLOW/TASKS.yaml` et rédaction du contrat `TASK_CONTRACT_T264_RETRAIT_BYPASS_POWER_CUTOFF_LIVRAISON.yaml` pour garantir son retrait impératif avant livraison machine.
- 📦 **Commits associés** : (Modifications en cours de session).

---

### MES-054 — Analyse et arbitrage de la polarité du capteur Fin de Course Haut M1/M2
- 📅 **Date** : 2026-09-07 14:10 | 📍 **Lieu** : Treuils M1/M2 / FdC
- 🎯 **Périmètre** : `PRG_04_Treuils_Benne.st`, `FB_Safety_Winch.st`
- 🚦 **Statut** : 🟡 **À surveiller** (revert conservateur pour analyse)
- 🔍 **Constat / Essai** :
  1. Le signal matériel `M1M2_TopPositionFree_DI` est un contact NC (Normalement Fermé) : `TRUE` = circuit fermé / zone haute libre, `FALSE` = capteur enclenché ou fil coupé.
  2. Suite à des tests d'inversion, une inversion a été temporairement testée puis immédiatement **revertée** à la demande de l'utilisateur pour préserver le comportement éprouvé du bloc `FB_Safety_Winch` en attente d'une analyse complète sur fiche d'anomalie.
  3. Création du contrat `TASK_CONTRACT_T268_TOP_SENSOR_POLARITY.yaml` et du script de vérification `G496_check_top_sensor_polarity.py`.
- 📦 **Commits associés** : `b1519957`, `acb7ec41`.

---

### MES-055 — Sélection automatique du mode machine sur changement de page IHM
- 📅 **Date** : 2026-09-07 14:30 | 📍 **Lieu** : Pilotage IHM / Modes de marche
- 🎯 **Périmètre** : `PRG_03_Modes_Cycle.st`, `GVL_IHM`
- 🚦 **Statut** : 🟢 **Validé**
- 🔍 **Constat / Essai** :
  1. Nécessité d'adapter le mode de fonctionnement sélectionné lorsque l'opérateur navigue sur les pages clés de l'IHM :
     - **Page 5** ➔ Mode `MAINT_N1` (`E_Mode.MAINT_N1`).
     - **Page 4** ➔ Mode `MAINT_N2` (`E_Mode.MAINT_N2`).
     - **Page 1** ➔ Mode `SEMI_AUTO` (`E_Mode.SEMI_AUTO`).
- 🛠️ **Solution appliquée** :
  - Ajout d'une détection sur front (`StatusInt01_ActualPage <> PrevActualPage`) en tête de `PRG_03_Modes_Cycle.st`.
  - Mise à jour immédiate de `GVL_IHM.Modes.Cmd.SelMode` avant l'évaluation par `instModes`.
  - Aucune incidence sur le déroulement séquentiel du cycle Semi-Auto ni sur les conditions de plongée (Diving).
- 📦 **Validation mécanique** : Bundle PLCopenXML régénéré avec succès, `G200_check_linkage.py` PASS (0 erreur).

---

## 4. 📜 Historique Git de la Séance (2026-09-06 ➔ 2026-09-07)

| Commit | Scope | Description |
|---|---|---|
| `b1519957` | `fix(treuils)` | Éviter le faux MecaD pendant ouverture benne au FdC |
| `acb7ec41` | `fix(mes)` | Correctif FdC haut PRG_04, renommage StatusInt01_ActualPage et BypassAuRedundancyTestA=TRUE au boot |
| `4c0c65d6` | `fix` | Verrouiller FDC et autorisations M3/M1-M2 |
| `ccfc7a6f` | `feat(ihm)` | Nommage explicite des registres de page CtrlInt01_SetPage et CtrlInt02_ActualPage |
| `e60eea54` | `fix(sync)` | Coupure instantanée instWinchSync sur commande benne et purge automatique WarnLatched |
| `ff15a114` | `wip(sync)` | Sauvegarde avant correction inhibition surveillance écart M1/M2 en ouverture benne |
| `d5510430` | `feat` | Ajouter image IOHW lecture seule IHM et ajuster cycle semi-auto |
| `ba99abba` | `feat` | Ajouter les blocs cycliques LocalIHM |
| `00776718` | `feat(ihm)` | Ajout commandes M3 maintenance N2, contrat T261 et troubleshooting codeurs AU |
| `3de7547f` | `feat(ihm)` | Préparation des structures ST_MaintenanceN2HMI sous GVL_IHM sans toucher aux sorties |
| `99313315` | `feat(wflow)` | Ajustement T259 - forçage par dérivation parallèle (OR //) sans toucher au flux nominal |
| `5fe37cb0` | `feat(benne)` | M2PositionCorrected sur offset nominal figé + flag validité (T260) |
| `c3648947` | `feat(wflow)` | Création de la tâche T259 et contrat associé pour shunt forçage direct N2 |

---

## 5. ✅ Actions de Clôture & Reste à Faire
- [x] Enregistrement de `T264` (retrait bypass PowerCutOff avant livraison).
- [x] Rédaction du registre MES du 2026-09-07 (`MES-051` à `MES-055`).
- [ ] Confirmation terrain de la navigation page 1 / page 5 et de l'activation des modes.
- [ ] Clôture formelle de `T268` après confirmation définitive du câblage FdC haut.

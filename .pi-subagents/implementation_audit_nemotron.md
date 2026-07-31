# Audit d'Implémentation - Fonctionnalités à Implémenter / Reliquats Actionnables
**Source unique** : `DOC/PLAN_TASK_v1.0.md` §3 (Reliquats, TBD & questions client) + `DOC/VERSION_HISTORY.md` + `DOC/AF_Partie-*.md` (1-13) + `CODE/MAIN/PRG_11_Troubleshooting.st`
**Date** : 2026-07-28
**Périmètre** : Code applicatif (`CODE/`) uniquement — hors essais terrain, hors IHM graphique (`visu/`)

---

## 📋 Synthèse par Criticité & Dépendances

| Criticité | Nb items | Description |
|-----------|----------|-------------|
| 🔴 **Bloquant sécurité / Étude préalable** | 5 | T91, T93, T87, T72, T73, T74 — nécessitent décision/étude avant code |
| 🟠 **Implémenté, validation CODESYS requise** | 9 | T84, T85, T86, T81, T82, T94, T95, T47 (désactivé), T64 |
| 🟠 **Prêt à coder / Spécifié** | 8 | T75, T76, T77, T78, T79, T52, T54, T55, T56, T57, T58, T59, T39 |
| 🟡 **Décision client / Config terrain** | 7 | T1, T4, T6, T8, T11, T15, T70, T92 |
| ⬜ **Différé assumé** | 2 | PRG_08 (T6), T63 |
| ✅ **Fait / Non-problème** | 12 | T2, T3, T5, T7, T10, T12, T13, T16, T18, T23, T24, T28, T29, T30, T31, T32, T33, T34, T35, T36, T37, T40, T41, T42, T44, T45, T46, T49, T50, T53, T60, T61, T62, T65, T66, T67, T68, T69, T71, T80, T83 |

---

## 🔴 BLOQUANTS SÉCURITÉ — Étude / Décision Requise AVANT Code

| ID | Sujet | Source | Dépendance | Action Requise |
|----|-------|--------|------------|----------------|
| **T91** | **Séquence frein/puissance asymétrique MONTÉE vs DESCENTE** | `PLAN_TASK` §3, `REGISTRE` MES-006, `FB_Brake`, `FB_Winch`, `FB_Ramp`, `AUDIT_Revue_Technique` §6 | **T87** (DelayMotorDecel mort), T93 (temporisations paliers) | 🔴 **ÉTUDE OBLIGATOIRE** — raisonner comme engin de levage : MONTÉE = frein d'abord puis puissance (qq ms) ; DESCENTE = immédiat. Mesurer chemin réel "joystick neutre → frein serré" dans les 2 sens. Tests en charge avec dragueur. |
| **T93** | **Remplacer rampe %/s par temporisations par palier (treuils)** | `PLAN_TASK` §3, Demande utilisateur 2026-07-27 | **T91** (décélération conditionne freinage), T47 (garde-fou vitesse) | 🔴 **ÉTUDE + CODE** — M1/M2 = contacteurs discrets (5 paliers), pas rampe continue. Cible : temps maintien réglable par palier. Impact : `FB_Winch`, `FB_SpeedStep`, `FB_Cycle`, IHM, `GVL_PERSISTENT`. Garde-fou T47 + temporisations T93 = complémentaires. |
| **T87** | **DelayMotorDecel : code mort (TON sur IN:=FALSE)** | `AUDIT_Revue_Technique_v1.0.md` §6, `FB_Brake` | **T91/T93** (lot étude frein/paliers) | Supprimer de l'interface **OU** réimplémenter la temporisation + corriger en-tête `FB_Brake`. Ne pas grouper avec T84/T85/T86. |
| **T72** | **Interverrouillage commande/frein : conditionner RelayFwd/Rev à BrakeCmd=TRUE** | `FB_Winch.st`, `FB_Translation.st`, REX 2026-07-23 | — | Interdire physiquement alimentation moteur sous frein serré par l'automate. |
| **T73** | **Winch : asymétrie fin course haute (bit5 + Méca D bit11 + PowerCutOff) vs basse (bit6, Forbid seul, AUCUNE escalade)** | `FB_Safety_Winch.st` bit6, REX 2026-07-23 | — | Ajouter équivalent Méca D pour limite basse : seuils/délais différents selon sens (montée = tolérance faible, descente = tolérance plus grande). |
| **T74** | **Translation : LimitSwitch (bit6) escalade PowerCutOff immédiat (pas délai confirmation) — harmoniser vers pattern Méca** | `FB_Safety_Translation.st` bit6, REX 2026-07-23 | — | Pattern Méca : dépassement transitoire toléré, escalade seulement si mouvement encore anormal après arrêt moteur attendu. |

---

## 🟠 IMPLÉMENTÉ — Validation CODESYS / Terrain Requise

| ID | Fonctionnalité | Fichiers Code | Spécification | Statut |
|----|----------------|---------------|---------------|--------|
| **T84** | `FB_Encoder_SpeedMeasure` : 6 positions horodatées / 5 intervalles, fenêtre fixe 50 ms, temps réel écoulé, sans PT1 | `CODE/CODEURS/FB_Encoder_SpeedMeasure.st`, `PRG_02_Encoders.st` | `AF_Partie-10` v1.11 §3.8, `AF_Partie-09` v1.13 | 🟠 **Implémenté 2026-07-28** — validation CODESYS requise |
| **T85** | Vitesse absolue/signée/validité produite uniquement par `PRG_02_Encoders` ; `FB_Safety_Winch` consomme. Pulse source `PRG_00_Inputs.WinchInputSourceChanged` | `PRG_02_Encoders.st`, `PRG_03_Safety.st`, `PRG_00_Inputs.st` | `AF_Partie-09` v1.13, `AF_Partie-10` v1.11 | 🟠 **Implémenté 2026-07-28** — validation CODESYS requise |
| **T86** | Gate `Enable=FALSE` de `FB_Safety_Winch` force `ForbidAscent=TRUE` (deterministe) | `FB_Safety_Winch.st` | `AF_Partie-09` v1.13 | 🟠 **Implémenté 2026-07-28** — validation CODESYS requise |
| **T81** | **Séquence détection fond Kobold** : départ ≥ +1,0 m ; front 0→1 attendu entre +0,5 et −0,5 m ; fond = front 1→0 APRÈS 0→1 confirmé. 3 bornes PERSISTENT + réglables IHM | `FB_DiveSearch.st`, `FB_ExtractionSequence.st`, `PRG_05_Cycle.st` | `PLAN_TASK` §3 T81, REX utilisateur 2026-07-27 | 🟠 **Implémenté** — tests PLC créés ; compilation/essais CODESYS requis |
| **T82** | **Arrêt sécurisé si séquence Kobold invalide** : sans activation ou sans front immersion → arrêt dans l'eau + défaut ; JAMAIS descente prolongée sans détection possible | `FB_Cycle.st:272`, `PRG_05_Cycle.st` | `PLAN_TASK` §3 T82, REX utilisateur 2026-07-27 | 🟠 **Implémenté** — tests PLC créés ; compilation/essais CODESYS requis |
| **T94** | **Garde-fou palier pilotable & persistant** : `SpeedGuardEnableM1/M2` locales `PRG_06_WinchControl:31-32` → passer `PERSISTENT` + exposer MAINT_N2 + afficher `SpeedGuardLimited` | `PRG_06_WinchControl.st`, `FB_SpeedStep.st`, `GVL_PERSISTENT.st` | `PLAN_TASK` §3 T94, lié T47 | 🟠 **Spécifié, pas encore codé** — prérequis mise en service |
| **T95** | **Outil calibration bandes vitesse** : étendre `FB_Diag_WinchSymmetry` (`PRG_11`) avec table `VitesseMax[1..5]` par axe, remise à zéro sur commande — mesure passive | `FB_Diag_WinchSymmetry.st`, `PRG_11_Troubleshooting.st`, `GVL_PERSISTENT._WinchSpeedConfig` | `PLAN_TASK` §3 T95, lié T45/T47 | 🟠 **Spécifié, pas encore codé** |
| **T47** | **Garde-fou passage palier** : implémenté (`FB_SpeedStep:230-238`), `SpeedGuardEnable` défaut `FALSE`, bandes `[0.4,0.8,1.2,1.6,2.0]` m/s provisoires. **Raison métier à documenter** (décrochage moteur = disjonction machine) | `FB_SpeedStep.st`, `FB_Winch.st`, `FB_Encoder_SpeedMonitor.st`, `GVL_PERSISTENT._WinchSpeedConfig` | `AF_Partie-09` v1.13 §T47, `PLAN_TASK` §3 T47 | 🟠 **Implémenté NON ACTIVÉ** — calibrer bandes en charge + activer après T84/T93 |
| **T64** | **Plafond palier vitesse réglé temporairement à 0** (essais 2026-07-23) — confirmer comportement, tracer essais, restaurer valeur exploitation | `PRG_06_WinchControl.st`, `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-003 | `PLAN_TASK` §3 T64 | 🟠 **En attente confirmation terrain** |

---

## 🟠 PRÊT À CODER / SPÉCIFIÉ — Dépendances Identifiées

| ID | Sujet | Fichiers Cibles | Spécification / Source | Dépendance / Note |
|----|-------|-----------------|------------------------|-------------------|
| **T75** | `check_code_style.py` : `KNOWN_VAR_OUTPUT_VIOLATIONS["MAIN/PRG_09_Supervision.st"]` obsolète (restructuration Winch/Translation 2026-07-22) | `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py` | `PLAN_TASK` §3 T75, REX 2026-07-23 | Mettre à jour liste précise (pas exemption globale) |
| **T76** | `FB_Cycle.st:112` : `DrainingTime := T#5s` jamais câblé depuis `GVL_IHM`/`GVL_PERSISTENT` | `FB_Cycle.st`, `PRG_09_Supervision.st`, `GVL_PERSISTENT.st` | `PLAN_TASK` §3 T76 | Paramètre en dur, hors audit persistance initial |
| **T77** | **Architecture Diagnostics POO** : remplacer pré-calcul booléen complexe dans entrées `PRG_01_Diagnostics` par transmission objets/statuts bruts (`GetDeviceState()`, `GetBusState()`, `SimulationModeActive`, `BypassGlobal`) — encapsulation dans `FB_Diag_CanOpen`/`FB_Diag_Ethercat` | `PRG_01_Diagnostics.st`, `FB_Diag_CanOpen.st`, `FB_Diag_Ethercat.st` | `PLAN_TASK` §3 T77, `REGISTRE` MES-005 | Refactoring architectural, 0 régression métier |
| **T78** | **Rampes treuils M1/M2** : 1) `CfgRampAccelRate` 50%/s → **10%/s** ; 2) Égalisation dynamique rampes M1/M2 en mode `Both`/couplé, dissociées sinon | `PRG_06_WinchControl.st`, `FB_Winch.st`, `GVL_PERSISTENT.st` | `PLAN_TASK` §3 T78, `REGISTRE` MES-007 | Attend décision T93 (temporisations paliers vs rampes %/s) |
| **T79** | **Config Trace CODESYS 10ms synchrone** : sorties relais M1/M2, retours physiques, positions codeurs, consigne rampée, écart synchro — documenter pour diagnostic arrêt différencié M1 vs M2 | Documentation seule (pas code) | `PLAN_TASK` §3 T79, `REGISTRE` MES-008 | Diagnostic terrain, pas implémentation PLC |
| **T52** | **Valider chaîne PowerCutOff physique** : câblage sorties A/B, contacteur puissance, retour confirmation, temps coupure réel | `PRG_10_Outputs.st:136-156`, électrique | `PLAN_TASK` §3 T52, `AUDIT_Winch_v1.0.md` §2.3 | 🔴 **Électricité + Projet** — P0.3 audit Winch |
| **T54** | **Documenter latence PRG_03→PRG_06→PRG_10 (~10 ms)** et l'intégrer au calcul temps d'arrêt | Doc seulement | `PLAN_TASK` §3 T54, `AUDIT_Winch_v1.0.md` §3.2 | Documentation |
| **T55** | **Stratégie synchronisme unique** (info / mineur / majeur / critique) — aligner DOC/CODE/IHM | `FB_WinchSync.st`, `PRG_06_WinchControl.st:329-338`, `AF_Partie-09` | `PLAN_TASK` §3 T55, `AUDIT_Winch_v1.0.md` §3.3 | Décision projet |
| **T56** | **Caractériser seuils sécurité terrain** (0,02 m/s, 2 m, 3 s, 800 ms, 500 ms) avec charge/vide/frein chaud | Terrain + Doc | `PLAN_TASK` §3 T56, `AUDIT_Winch_v1.0.md` §3.4, `FB_Safety_Winch:149-169` | 🔴 **Projet / Terrain** |
| **T57** | **Unifier limite haute M2 selon offset benne** : une seule limite active distribuée Winch/Safety/IHM | `PRG_06_WinchControl.st:379` vs `PRG_03:53,96` | `PLAN_TASK` §3 T57, `AUDIT_Winch_v1.0.md` §3.5 | Code existant divergent |
| **T58** | **Séparation Config/Commands/Status/Alarms** dans GVL_PERSISTENT (différé jusqu'à maquette IHM validée) | `GVL_PERSISTENT.st`, `PRG_09_Supervision.st` | `PLAN_TASK` §3 T58, `AUDIT_Winch_v1.0.md` §5.2 | Attend IHM |
| **T59** | **IHM afficher arrêt croisé effectif** (`ForbidAscentM1_Active`) pas seulement safety local | IHM (hors scope PLC) | `PLAN_TASK` §3 T59, `AUDIT_Winch_v1.0.md` §5.3 | Côté IHM supervision |
| **T39** | **Interfaces Homing nominale/unitaire réalisées** — essais opérateur CODESYS restants | `FB_Encoder_Homing.st`, `PRG_02_Encoders.st`, `ST_WinchHMI.st` | `PLAN_TASK` §3 T39, `AF_Partie-10` | 🟠 Validation CODESYS |
| **T25** | **Suite automatisée nominale Encoder/Homing** : gate simulation explicite, watchdog local, rapports TC-E1/TC-E2 corrigés | `SuiteEncoder = 4`, `AF_Partie-10` §10 | `PLAN_TASK` §3 T25 | 🟠 Essais CODESYS + scénarios unitaire/bornage/redémarrage |
| **T17** | **Checklist Joystick** : exécution terrain + verdict signé — limitations robustesse ajoutées sur `FB_AxisScale`, `FB_Ramp`, consigne finale M3 | `CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.1.md` | `PLAN_TASK` §3 T17 | Terrain |
| **T26** | **Checklist Translation AC600** : exécution terrain + verdict signé (EtherCAT, commande, fréquence, sens, arrêts, PV, 5 capteurs, Fdc, thermique, diagnostics) | `CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md` | `PLAN_TASK` §3 T26, `AF_Partie-11` §8 | Terrain |
| **T27** | **Benne : essais mise en service** (cinématique, offsets, Méca C couches 1/2) | `FB_Bucket.st`, `AF_Partie-12` §6 | `PLAN_TASK` §3 T27 | Terrain |
| **T21** | **Checklist validation Winch v1.7** non réalisée (inhibition, HomingApproachEnable, Méca B/D, diagnostics IHM, simulation) | `AF_Partie-09` §8 | `PLAN_TASK` §3 T21 | Terrain |
| **T92** | **Qualification bypass ciblés + homing 0 m** (MES-002) : comportement chaque bypass, persistance après redémarrage (RETAIN), homing M1/M2 à 0,0 m, cohérence position, réarmement sûr | `REGISTRE` MES-002, `CHECKLISTS/CHECKLIST_Essais_Persistance_Bypass_Frein` (11 tests) | `PLAN_TASK` §3 T92 | ⚠️ Invalidation RETAIN remet bypass à FALSE → réapparition blocage masqué |

---

## 🟡 DÉCISIONS CLIENT / CONFIG TERRAIN — En Attente Arbitrage

| ID | Sujet | Décideur | Source | Note |
|----|-------|----------|--------|------|
| **T1** | Détail séquence `INIT` (sous-vérifications position/cohérence) | Projet | `AF_Partie-04` §2, D22 | Spécification attendue |
| **T4** | Protocole registre AC600 (`DriveControlWord`/`StatusWord`) | **Constructeur variateur** | Translation/Safety_Translation | Bloquant pour `FB_Translation` finition |
| **T6** | Périmètre `PRG_08` Auxiliaire (casque, grille, centrale hydraulique) | **Client** (différé assumé) | `PLAN_TASK` v1.1 §3 | Seul thermique centrale reste en diagnostic |
| **T8** | Rôle de `CodeSeqTriggerCmd` (codeurs) | À vérifier terrain | `AF_Partie-10` | Inconnu — à lever sur site |
| **T11** | `EmergencyStopOk` : pas de confirmation temporisée post-réarmement, redondance A/B logicielle seulement | Projet | `AUDIT` D93 | Renforcement sécurité possible |
| **T15** | Validation câblage réel `EmergencyStopOk` (retour contacteur puissance) + comportement post-réarmement | Projet / Terrain | `AF_Partie-01` §Sécurité électrique, `PRG_00_Inputs` | Source logicielle clarifiée, câblage à valider |
| **T70** | `Modes.SelMode`/`SelJoystickWinch`/`TglJoystickMaster` repartent en valeur restrictive (MAINT_N1) au boot — voulu (sécurité) ou oubli ? | Projet / Client | `AF_Partie-15` §4 | À confirmer avant traitement |
| **T22** | Tolérance calibration `TopSensorPositionM` (contrôle visuel) à fixer sur site | Terrain | `AF_Partie-10` §7bis | Réglage mise en service |
| **T90** | **Hauteurs treuils à contrôler sur site** (MES-009) : capteur haut 8,0 m, arrêt réel ≈ 7,5 m. `CfgTopSensorPos_M=8.0`, `CfgCableLimitAscent_M=7.5`. Erreur sur `CfgTopSensorPos_M` décale TOUTES positions. À inscrire dans doc (`AF_Partie-09` §hauteurs, `AF_Partie-10` homing) : valeurs de base config persistante, pas réglages libres | Terrain / Sécurité | `REGISTRE` MES-009, `GVL_PERSISTENT`, `PLAN_TASK` T90 | ⚠️ Critique mise en service |
| **T89** | **Offset benne = ÉTAT benne** (MES-010) : `M1=M2` (offset 0) → benne OUVERTE ; `M2` décalé ≈ 15 m → benne FERMÉE. Valeur appliquée 2026-07-27 (`OffsetCloseM` 10.0→15.0). Valider cote premier essai en charge + vérifier ouverture/fermeture ET cycle complet fonctionnels/simulables | Terrain / Projet | `REGISTRE` MES-010, `GVL_PERSISTENT`, `FB_Bucket` | Détermine tout le cycle |

---

## ⚪ DIFFÉRÉ / HORS PÉRIMÈTRE IMMÉDIAT

| ID | Sujet | Raison | Référence |
|----|-------|--------|-----------|
| **PRG_08** (`T6`) | Commandes casque/grille/centrale retirées — seul thermique centrale en diagnostic | Différé assumé, décision client en cours | `PLAN_TASK` §2 ⏸️, `AF_Partie-02` §4 |
| **T63** | Persistance flags simulation + split `GVL_SimulationBench` | Bindings visualisation à maquetter avant import | `PLAN_TASK` §3 T63, REX session revertée |
| **IHM Visu graphique** | Dossier `visu/` vide, seule `GVL_IHM` existe | Hors périmètre livré, traité séparément avec IHM supervision | `PLAN_TASK` §2 ❌ |

---

## 📋 SPECS INCOMPLÈTES / AMBIGUËTES À LEVER

| Spécification | Section | Problème | Action |
|---------------|---------|----------|--------|
| `AF_Partie-04_Cycle_Sequenceur_v1.5.md` | Fichier **manquant** (ENOENT) | Référencée partout (`PLAN_TASK`, `PRG_05_Cycle`, `AF_Partie-09`, `AF_Partie-12`) mais absente de `DOC/` | **Critique** — recréer ou confirmer version archivée |
| `AF_Partie-09` §4undecies | Montée en charge / temporisation frein | "Investigations futures — validation terrain + réglages différés après essais de charge" | Lever après T91/T93 |
| `AF_Partie-10` §3.8 / T84-T85 | `FB_Encoder_SpeedMeasure` — fenêtre 50 ms, 6 positions, temps réel écoulé | Spécifié en v1.11 mais **pas de détail algorithme** (médiane ? moyenne ? pondération ?) | Préciser dans doc ou code commentaire |
| `AF_Partie-11` v1.12 | Mapping registres AC600 (`DriveControlWord`/`StatusWord`) | "Protocole registre AC600 — Constructeur variateur" (T4) | Bloquant finition `FB_Translation` |
| `AF_Partie-09` | Nommage "Safety Mouvement" par lettre (A/B/C...) vs rôle descriptif | Doc v1.13 §4novies : "utilise encore en interne l'ancien nom par lettre… Audit final : aucun identifiant de ce type ne subsiste dans le code actif" — **à vérifier dans `FB_Safety_Winch.st`** | Renommage code si résidus |
| `AF_Partie-03` §1bis | Profil FB réduit pour briques E/S/diag (`FB_Input`, `FB_Output`, `FB_Diag*`) | Interface "propre" non listée exhaustivement — risque d'incohérence si nouveau FB ajouté | Documenter profil minimal |
| `NAMING_CONVENTION.md` | Préfixes `Req`/`Cmd`/`Sensor`/`Position` | Audit 2026-07-22 : migration non retenue, code garde `BtnFwd`/`BtnRev`/`TglJoystickMaster`/`SelTarget` — blast radius large si appliqué | Planifier chantier dédié, jamais improvisé |

---

## 🔗 TRAÇABILITÉ DOC → CODE (Échantillon Vérifié)

| Doc / Section | Code Correspondant | État |
|---------------|-------------------|------|
| `AF_Partie-09` v1.13 §T84/T85/T86 | `FB_Encoder_SpeedMeasure.st`, `PRG_02_Encoders.st`, `FB_Safety_Winch.st`, `PRG_00_Inputs.st` | ✅ Implémenté 2026-07-28 |
| `AF_Partie-10` v1.11 §3.8 | `FB_Encoder_SpeedMeasure` (fenêtre 50 ms, 6 positions) | ✅ Cohérent |
| `AF_Partie-11` v1.12 §3bis | `FB_Translation_PositionDecoder` (5 capteurs, mots valides, incohérence) | ✅ Implémenté `PRG_00_Inputs` §2 |
| `AF_Partie-12` v1.4 §4 point 8 | `FB_Bucket` : offset dynamique `ActiveOffsetM`, butée M2 dynamique, `_BucketState` mémoire | ✅ Implémenté v1.4 |
| `AF_Partie-13` v2.0 §2 | Frontière unique `HwReal`/`HwSim`/`HwIn` dans `PRG_00_Inputs` | ✅ Implémenté §0/§0bis/§1 |
| `PLAN_TASK` T81/T82 | `FB_DiveSearch` (0→1→0), `FB_ExtractionSequence` (fermeture, palier 1 sur 2m, nominal) | 🟠 Code existant, tests PLC à valider |
| `PLAN_TASK` T47 | `FB_SpeedStep:230-238` garde-fou, `SpeedGuardEnable` défaut FALSE, bandes provisoires | 🟠 Implémenté non activé, raison métier à documenter |

---

## 🎯 ORDRE D'IMPLÉMENTATION RECOMMANDÉ (selon `PLAN_TASK` §4.0)

```
LOT 1 (AVANT ESSAIS)          → T84 + T85 + T86  (cœur sécurité, même chaîne)
LOT 2 (AVANT ESSAIS)          → T81 + T82        (Kobold : détection fond + arrêt sûr)
LOT 3 (OUTILS CALIBRATION)    → T94 + T95        (garde-fou persistant + table VitesseMax)
LOT 4 (ÉTUDE PARALLÈLE)       → T91 + T93 + T87  (frein asymétrique + temporisations paliers)
LOT 5 (RÉÉVALUATION)          → T72 + T73 + T74  (safety reliquats post-lots 1-4)
LOT 6 (SECONDAIRES)           → T75, T76, T77, T78, T79, T88
```

---

## 📌 RÉSIDUELS / RISQUES MAJEURS

1. **T91/T93 non décidés** : bloquent T78 (rampes), T47 (garde-fou), T87 (DelayMotorDecel). Toute implémentation prématurée = réécriture.
2. **T4 absent** (registres AC600) : `FB_Translation` incomplet côté EtherCAT — contacter constructeur variateur.
3. **`AF_Partie-04` manquante** : spécification cycle/séquenceur introuvable — risque dérive implémentation vs spec.
4. **T92 (bypass RETAIN)** : invalidation RETAIN remet bypass à FALSE → réapparition blocage masqué. Doit être testé explicitement.
5. **T83 (IhmHeartbeat bypass TRUE par défaut)** : survit aux downloads — **action livraison : repasser FALSE** dès visu opérationnelle.
6. **Nommage `SafeStop`/`PowerCutOff` suffixes A/B** : doc `AF_Partie-01` §Sécurité électrique : "suffixes conservés = canaux physiques redondants, pas rôles métier" — vérifier cohérence code (`PRG_10_Outputs`).
7. **`FB_CycleTime` T88** : bouclage `TIME()` ~49,7 jours non géré — garde-fou `IF DeltaTimeMs > 1000` existe mais non documenté en spec.

---

## 📂 FICHIERS CLÉS À SURVEILLER (Modifications Récentes / Points Chauds)

| Fichier | Rôle | Dernière Modif Significative |
|---------|------|------------------------------|
| `CODE/MAIN/PRG_00_Inputs.st` | Frontière unique HwReal/HwSim/HwIn, conditionnement, simulation, décodage M3 | 2026-07-28 (T84/T85/T86, WinchInputSourceChanged) |
| `CODE/MAIN/PRG_02_Encoders.st` | Producteur unique vitesse codeur (T84/T85), pipeline Abs→Scale→Homing→Safety→SpeedMeasure | 2026-07-28 |
| `CODE/MAIN/PRG_03_Safety.st` | Instances Safety Winch M1/M2 + Translation, SpeedMonitor, LoadEstimator | 2026-07-28 (Enable/MeasuredSpeedValid câblage) |
| `CODE/TREUILS/FB_Safety_Winch.st` | 7 mécanismes safety (Méca A-G), SafeStop/PowerCutOff, bits 14/15, T86 | 2026-07-28 (consommation vitesse PRG_02) |
| `CODE/CODEURS/FB_Encoder_SpeedMeasure.st` | **Nouveau** — mesure vitesse propriétaire chaîne codeur (T84) | 2026-07-28 |
| `CODE/TREUILS/FB_SpeedStep.st` | Garde-fou palier (T47), temporisations (T93 cible) | À modifier pour T93 |
| `CODE/COMMUN/FB_Brake.st` | Séquence frein, DelayMotorDecel mort (T87), T91/T93 cible | À réviser pour T91/T93 |
| `CODE/CYCLE/FB_DiveSearch.st` / `FB_ExtractionSequence.st` | Kobold T81/T82 — séquence 0→1→0, palier 1 sur 2m | 2026-07-28 (LOT2A) |
| `CODE/MAIN/PRG_11_Troubleshooting.st` | Observateur pur 5 fonctions machine, `FB_Diag_WinchSymmetry` + extension T95 cible | 2026-07-27 (v0.5.2) |
| `CODE/GVL_PERSISTENT.st` | Config persistante tous métiers — T90, T89, T94, T95 cibles | 2026-07-28 |
| `DOC/PLAN_TASK_v1.0.md` | **Source unique pilotage** — toutes tâches Txx, jalons, stratégie MES | 2026-07-28 (v1.0) |

---

## ✅ CRITÈRES D'ACCEPTATION AUDIT

- [x] Aucune modification code effectuée (lecture seule)
- [x] Findings concrets avec chemins fichiers et sections doc
- [x] Classification par criticité/dépendances
- [x] Spécifications incomplètes signalées
- [x] Rapport compact écrit vers `C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/.pi-subagents/implementation_audit_nemotron.md`
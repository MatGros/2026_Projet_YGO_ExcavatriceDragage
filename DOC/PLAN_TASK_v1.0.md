# 🗂️ PLAN_TASK — Suivi Planning & Reliquats (v1.0)

> 🎯 **Rôle** : seul document de pilotage projet (jalons, tâches, TBD, questions client). Les `AF_PartieN` restent **spec fonctionnelle pure** — tout ce qui est planning/organisationnel vit ici, pas dans les specs.
> 📥 **Remplace** : `PLAN_Finalisation_v1.0.md` + `v1.1.md` + `SAT_Protocole_Essais_v1.0.md` (les 3 archivés dans `DOC/Archives/`, contenu ingéré ci-dessous).
> 🗓️ Créé 2026-07-09.

---

## 🏁 1. Jalons connus de l'affaire

| Date | Jalon |
|---|---|
| 2026-07-15 | `v0.4.8` — IHM_MANU M1/M2 pilotés via `FB_Winch` (rampe/ralentissement natifs, retrait doctrine "Conditional Bypass"), nouvelle limite `CableLimitAscentM1/2_M`, correctifs Méca B (bit8) + grappin couplé + `FB_Safety_Chariot` (latch défaut) |
| 2026-07-09 | Audit complet + ce `PLAN_TASK` |
| 2026-07-09 | `PLAN_Finalisation_v1.1` (bloquants résolus + priorités actées) + `SAT_Protocole_Essais_v1.0` (protocole recette écrit) — ⚠️ pas encore commités |
| 2026-07-08/09 | `v0.4.4`/`v0.4.5` **IHM_MANU** — mise en service d'urgence (dérogation active, voir §3 ⏸️) |
| 2026-07-08 | `v0.4.0`→`v0.4.3` : simulation stable Winch/Grappin + synchro critique Méca E, pré-commissioning câble réel |
| 2026-07-07/08 | Réarchitecture `PRG_00`→`PRG_10` (abandon `PLC_PRG_MAIN`), campagne doc massive, audit cohérence documentaire |
| 2026-07-04 | `PLAN_Finalisation_v1.0` — 1er état des lieux (bloquants, écarts, TBD) |
| 2026-06-30 | Bootstrap projet (init CODESYS, skill workflow, convention nommage) |

---

## 🧩 2. Tâches / Features — état

### ✅ Fait
Joystick · Winch/SpeedStep · Grappin · Encoder (pipeline) · Safety_Winch (14 bits) · Modes · Diag CanOpen/EtherCAT · Brake/Ramp · GVL_Simulation

### 🎯 Priorisé (v1.1 §2 — sécurité, à coder en premier)
| # | Sujet |
|---|---|
| 2.A | Homme-mort joystick absent en `SEMI_AUTO` → asservir `StartStop` M1/M2/M3 à `DeadmanArmed` + déflexion |
| 2.B | `SafeStopActive` non intégré dans `FB_Cycle` → transition `ERROR_HOLD` manquante |

### 🟡 Partiel
| Brique | Manque |
|---|---|
| `FB_WinchSync` | Surveillance seule (assumé), pas de correction active |
| `FB_Chariot` | Mot de commande AC600 jamais câblé, `LIN_TRAFO` non vérifié, arrêt exact sur capteur non validé |
| `FB_Safety_Chariot` | 4 bits seulement (vs 14 côté Winch) |
| `FB_Cycle` | **Trouvé à l'audit, absent de v1.1** : `Error`/`ErrorId`/`StateAtError` jamais assignés, `ResetEdge` mort |
| `FB_Input`/`FB_Output` (_COMMON) | Existent mais pas intégrés dans Winch/Chariot (logique contacteur dupliquée) |

### ⏸️ Différé assumé (pas un trou béant)
`PRG_08_AuxiliaryControl` (crible/hydraulique/grille/casque) — code prêt (`ST_AuxiliaryHMI`), en attente validation client des specs fonctionnelles.

### ❌ Manquant
IHM visu graphique (dossier `visu/` vide, seule la couche d'échange `GVL_IHM` existe).

### 🗑️ Nettoyage dû
`GVL_BUS`, `GVL_Machine_Stub` (orphelins) · `ST_IHM_MANU` (post-qualification, v1.1 §4.3).

### 📄 Doc à mettre à jour
- Presque tous les `AF_PartieN` : en-tête "Dépend de Partie 2 vX.Y" obsolète → bumper vers `v2.10`
- `AF_Partie-07` (Interface IHM) : le plus en retard, référence encore `PRG_MAIN.st` (n'existe plus)
- `AF_Partie-07`/`AF_Partie-12` : titre interne ≠ nom de fichier
- `CLAUDE.md` : arborescence encore sur le modèle `PLC_PRG_MAIN` abandonné

---

## ❓ 3. Reliquats, TBD & questions client

| # | Sujet | Qui tranche | Source |
|---|---|---|---|
| T1 | Détail séquence `INIT` (sous-vérifications position/cohérence) | Projet | AF_Partie-04 §2, D22 |
| T2 | Statut `PRG_IP.st` dans la liste de tâches CODESYS | Projet (vérif config) | v1.0 §3.3 |
| T3 | Nom exact `FB_Filter_PT1` vs `FB_FilterPT1` | Vérif prochain export CODESYS | v1.0 §3.4 |
| T4 | Protocole registre AC600 (`DriveControlWord`/`StatusWord`) | **Constructeur variateur** | Chariot/Safety_Chariot |
| T5 | Priorités des tâches CODESYS (EtherCAT/CAN/Main) | Projet | AF_Partie-02 §Q7 |
| T6 | Périmètre `PRG_08` Auxiliaire | **Client** (en cours, différé assumé) | v1.1 §3 |
| T7 | Critère explicite de "machine qualifiée" pour retirer `IHM_MANU` | Projet | v1.1 §4.3 |
| T8 | Rôle de `CodeSeqTriggerCmd` (codeurs) | À vérifier terrain | AF_Partie-10 |
| T9 | Comportement frein en montée chargée | Différé après essais terrain | AF_Partie-09 §4undecies |
| T10 | `Safety_Winch` : cas sens opposé + absence de mouvement malgré commande | Projet | v1.0 |
| T11 | `EmergencyStopOk` : pas de confirmation temporisée post-réarmement, redondance A/B logicielle seulement | Projet | AUDIT D93 |
| T12 | `FB_Safety_Chariot`/domaine Chariot : pas de `ST_ContactorCheck` de puissance câblé pour M3, `PowerCutOff` des autres bits reste figé `FALSE` | Projet | AF_Partie-01, AF_Partie-11 |
| T13 | Renommage identifiants CODE Safety Mouvement (lettres A/B/C → `SafetyMotion<Role>`) | Projet | AF_Partie-01 |
| T15 | Source exacte de `EmergencyStopOk` selon métier (AU réarmé vs retour contacteur) à sécuriser en remise en service | Projet | AF_Partie-03 §1, AF_Partie-08 §7 |
| T16 | Vestige `PRG_JOY1` (nommage historique + header `.st`) à nettoyer, architecture pré `PRG_00-10` | Projet | AF_Partie-08 §6bis |
| T17 | Checklist mise en service Joystick non réalisée (calibration, deadband, coupure CAN) | Terrain | AF_Partie-08 §8 |
| T18 | GVL d'échange IHM à créer ou non (mapping paramètres/mesures) | Projet | AF_Partie-05 §6 |
| T19 | Mapping `ChannelOk` carte/voie E-S (diagnostic carte non exploité) à définir si besoin confirmé | Projet | AF_Partie-06 §4 |
| T20 | Sélecteur treuil IHM (M1/M2/Les deux) + bit « Prise de main IHM » jamais codés | Projet | AF_Partie-09 §1 |
| T21 | Checklist validation Winch v1.7 non réalisée (inhibition, HomingApproachEnable, Méca B/D, diagnostics IHM, simulation) | Terrain | AF_Partie-09 §8 |
| T22 | Tolérance de calibration `TopSensorPositionM` (contrôle visuel) à fixer sur site | Terrain | AF_Partie-10 §7bis |
| T23 | Mapping IHM Encoder/Homing restant non codé (`WinchSelect_IHM`, `HomingTargetM_IHM`, voyants) | Projet | AF_Partie-10 §8 |
| T24 | `FB_Encoder_Safety` (survitesse) orphelin depuis réécriture `FB_Encoder_Abs` — à retrancher/réintégrer | Projet | AF_Partie-10 §9bis |
| T25 | Checklist validation Encoder/Homing non réalisée (flux nominal/unitaire, bornage, redémarrage, verrou transition) | Terrain | AF_Partie-10 §10 |
| T26 | Checklist mise en service Chariot AC600 non réalisée (essai à vide, interlock sens, ETHERCAT, thermique frein) | Terrain | AF_Partie-11 §8 |
| T27 | Grappin : essais de mise en service non réalisés (cinématique, offsets, Méca C couches 1/2) | Terrain | AF_Partie-12 §6 |
| T28 | `GVL_IHM.IHM_MANU.WinchMaxStepFwd/Rev` (plafond palier "essais progressifs") : branchement **TEMPORAIRE** dans `FB_Winch`/`PRG_06_WinchControl` (`MaxStepAscent`) — à retirer une fois les vitesses définitives figées, cf. T7 (critère de retrait `IHM_MANU`) | Projet | Session 2026-07-15 |

✅ **Session 2026-07-09 (agent de scan doc)** : table complétée (T12-T27) — voir §5 pour le détail des renvois ajoutés dans chaque `AF_PartieN`.

---

## 📋 4. Recette

📥 **Ingéré depuis** `SAT_Protocole_Essais_v1.0.md` (archivé dans `DOC/Archives/`, contenu ci-dessous fait foi).

⚠️ **NO-GO mouvement** (diag EtherCAT + câblage CAN joystick, AUDIT D47) à lever formellement avant de dérouler ce protocole.

**Prérequis** : Homing M1/M2 fait (12.5m, `Homed=TRUE`) · Joystick calibré (deadband 10%) · `GVL_Simulation.SimulationModeActive = FALSE`.

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

---

## 🔗 5. Renvois AF_Partie → ce document

✅ **Scan complet effectué (2026-07-09)** — 12 des 13 `AF_PartieN` touchés (contenu organisationnel
extrait et/ou harmonisation titre/nom de fichier) ; `AF_Partie-03` laissé intact (aucun contenu
organisationnel trouvé). Détail fichier par fichier :

| Fichier | Ancien nom | Nouveau nom | Renvois ajoutés | Txx référencées |
|---|---|---|---|---|
| Partie 1 | `..._v1.5.md` | `..._v1.6.md` | 2 | T12, T13 |
| Partie 2 | `..._v2.10.md` | `..._v2.11.md` | 1 | T5 |
| Partie 3 | — | — (inchangé) | 0 | — |
| Partie 4 | `..._v1.2.md` | `..._v1.3.md` | 1 | T1 |
| Partie 5 | `..._v1.3.md` | `..._v1.5.md` | 1 | T18 |
| Partie 6 | `..._v1.5.md` | `..._v1.6.md` | 1 | T19 |
| Partie 7 | `..._v1.2.md` | `..._v1.3.md` | 0 (harmonisation titre/fichier uniquement) | — |
| Partie 8 | `..._v1.2.md` | `..._v1.3.md` | 3 | T15, T16, T17 |
| Partie 9 | `..._v1.9.md` | `..._v1.10.md` | 3 | T9, T20, T21 |
| Partie 10 | `..._v1.7.md` | `..._v1.9.md` | 8 | T4, T8, T22, T23, T24, T25 |
| Partie 11 | `..._v1.3.md` | `..._v1.4.md` | 5 | T4, T12, T26 |
| Partie 12 | `..._v1.2.md` | `..._v1.4.md` | 1 | T27 |
| Partie 13 | `..._v1.1.md` | `..._v1.2.md` | 0 (harmonisation titre/fichier uniquement) | — |

📌 Chaque fichier renommé a été archivé tel quel (version pré-nettoyage) dans `DOC/Archives/`
avant incrémentation, conformément à la convention de versionnage du projet. Toutes les
références croisées connues (`CLAUDE.md` + liens inter-`AF_PartieN`) ont été mises à jour vers les
nouveaux noms de fichier.

---

## 📎 Sources archivées
`DOC/Archives/PLAN_Finalisation_v1.0.md` · `DOC/Archives/PLAN_Finalisation_v1.1.md` · `DOC/Archives/SAT_Protocole_Essais_v1.0.md`

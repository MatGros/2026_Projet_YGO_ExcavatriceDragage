# Audit Read-Only — Implémentation restante (Txx actionnables)

Source: `DOC/PLAN_TASK_v1.0.md` (§ Plan orchestré, §2 Tâches/Features, §3 Reliquats Txx, §4 Recette), `DOC/VERSION_HISTORY.md`, `CODE/MAIN/PRG_11_Troubleshooting.st` (observateur pur, conforme au plan — RAS).

## 🧭 Plan orchestré — dépendances (ordre officiel, `PLAN_TASK_v1.0.md` lignes ~11-16)

| Lot | Contenu | État | Bloque |
|---|---|---|---|
| **1** | T84+T85+T86 (mesure vitesse Winch) | 🟠 Implémenté, **validation CODESYS/terrain requise** | Lot 3 (calibration paliers) |
| **2** | T81+T82 (Kobold: assistants maintenance implémentés `LOT2A_KoboldMaintenanceAssist`) | 🟠 Implémenté, tests PLC créés, compilation/essais requis | Qualification cycle semi-auto |
| **3** | T94+T95 (garde-fou palier pilotable/persistant + calibration) | ⬜ En attente lot 1 | Lot 4/6 |
| **4** | T91+T93+décision T87 (frein/paliers) | ⬜ **Étude à préparer avant code** — ne pas trancher arbitrairement | T78 (lot 6) |
| **5** | T72+T73+T74 (reliquats safety) | ⬜ À réévaluer après lots précédents | — |
| **6** | T75+T76+T77+T79+T88 (T78 attend décision T93) | ⬜ Différé | — |

## 🔴 Critiques / sécurité — actionnables immédiatement ou en étude

| Txx | Sujet | État | Chemin |
|---|---|---|---|
| **T91** | Séquence frein/puissance asymétrique montée/descente — **étude seule, pas de code avant décision**. Suspicion que `FB_Ramp`/`FB_SpeedStep`/`FB_Brake` retardent le freinage | 🔴 étude à mener, dépend T87 | `FB_Brake`, `FB_Winch`, `FB_Ramp`, `AUDIT_Revue_Technique_v1.0.md §6` |
| **T81/T82** | Séquence détection fond Kobold (immersion 0→1→0) + arrêt sécurisé si séquence invalide — implémenté lot 2, validation restante | 🔴→🟠 | `FB_DiveSearch`, `FB_Cycle.st:272`, `AF_Partie-04 v1.5` |
| **T52** | Validation chaîne `PowerCutOff` physique (câblage A/B, contacteur, retour, temps réel) | 🔴 non fait | `PRG_10_Outputs.st:136-156`, AUDIT_Winch §2.3 |
| **T87** | `DelayMotorDecel` : `TON` armé `IN:=FALSE` → sans effet, doc erronée. Reporté au lot 4 avec T91/T93 | 🟠 code mort à corriger/retirer | `FB_Brake`, `AUDIT_Revue_Technique_v1.0.md §6` |
| **T72** | Interverrouillage sécurité : contacteurs sens conditionnés au desserrage effectif du frein | 🟠 non fait | `FB_Winch.st`, `FB_Translation.st` |
| **T73** | Winch: absence d'escalade PowerCutOff sur limite basse câble (bit6) — asymétrie vs bit5 (Méca D) | 🟠 non fait, logique seule | `FB_Safety_Winch.st bit6` |
| **T74** | Translation: LimitSwitch (bit6) escalade sans fenêtre de confirmation — à harmoniser style Méca | 🟠 non fait | `FB_Safety_Translation.st bit6` |
| **T47** | Garde-fou passage de palier implémenté mais **non activé** (`SpeedGuardEnable=FALSE`) — anti-décrochage moteur/disjonction, pas confort. Raison métier pas encore inscrite dans AF_Partie-09 | 🔴 activation bloquée par calibration (T94/T95) | `FB_SpeedStep:230-238`, `GVL_PERSISTENT._WinchSpeedConfig` |
| **T94** | Rendre `SpeedGuardEnableM1/M2` PERSISTENT + exposés IHM MAINT_N2 (actuellement VAR locales PRG_06, perdues au download) | 🟠 non fait | `PRG_06_WinchControl:31-32` |
| **T95** | Outil calibration bandes vitesse (mesure `VitesseMax[1..5]` par palier, à vide/charge) — étendre `FB_WinchSymmetry` | 🟠 non fait | `FB_WinchSymmetry`, T45/T47 |
| **T83** | `IhmHeartbeat` défaut `TRUE` provisoire (RETAIN) — **repasser à FALSE avant livraison** sinon perte IHM ne déclenche plus SafeStop | 🟠 action livraison | `PRG_01_Diagnostics.st:64-67` |

## 🟠 Fonctionnel — validation terrain/CODESYS en attente (code déjà écrit)

| Txx | Sujet | Chemin |
|---|---|---|
| T17 | Checklist Joystick rédigée, exécution/verdict signé restants | `CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.1.md` |
| T21 | Checklist validation Winch v1.7 non réalisée | AF_Partie-09 §8 |
| T25 | Suite auto Encoder/Homing: essais CODESYS + scénarios restants | AF_Partie-10 §10 |
| T26 | Checklist Translation AC600: exécution/verdict restants | `CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md` |
| T27 | Benne: essais mise en service non réalisés (cinématique, offsets, Méca C) | AF_Partie-12 §6 |
| T39 | Interfaces Homing OK; essais opérateur CODESYS restants | AF_Partie-10 |
| T43 | Comparaison vitesse M1/M2 raccordée mais seuil/tempo=0 → **contrôle inactif** ; valeurs métier à définir | `FB_Cycle`, AF_Partie-04 §3quater |
| T48 | Matrice essais V1-V7 (charge, freinage, câble mou...) à rejouer simu/terrain | ex-AF_Partie-14 §7.4.4 archivée |
| T56 | Seuils sécurité terrain (0.02m/s, 2m, 3s, 800ms, 500ms) à caractériser en charge/vide/frein chaud | `FB_Safety_Winch:149-169` |
| T64 | Plafond palier vitesse à `0` temporairement — confirmer comportement, restaurer valeur exploitation | `REGISTRE_Suivi_MiseEnService MES-003` |
| T89 | Offset benne = état mécanique (0=ouvert,15m=fermé). Valider cote 1er essai charge | `GVL_PERSISTENT`, `FB_Bucket`, MES-010 |
| T90 | Hauteurs treuils à contrôler 1er homing (`CfgTopSensorPos_M`, `CfgCableLimitAscent_M`) — erreur décale toutes positions | `GVL_PERSISTENT`, MES-009 |
| T92 | Qualification bypass ciblés + homing 0m — persistance RETAIN après redémarrage à valider | `CHECKLISTS/CHECKLIST_Essais_Persistance_Bypass_Frein` |

## 🟡 Secondaire / différé (lot 6, `⬜ Différé`)

| Txx | Sujet | Chemin |
|---|---|---|
| T75 | `check_code_style.py` exemption obsolète, à corriger précisément | `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py` |
| T76 | `FB_Cycle.st:112` `DrainingTime` en dur, jamais câblé IHM/persistant | `FB_Cycle.st:112` |
| T77 | Refacto architecture diag: transmettre objets bruts au lieu d'expressions pré-calculées | `PRG_01_Diagnostics.st`, `FB_DiagCanOpen.st`, `FB_DiagEthercat.st` |
| T78 | Rampe accel 50%→10%/s + égalisation dynamique M1/M2 mode couplé — **attend décision T93** | `PRG_06_WinchControl.st`, `FB_Winch.st` |
| T79 | Config Trace CODESYS diagnostic arrêt différencié M1/M2 (à documenter, pas coder) | CODESYS Trace |
| T88 | `FB_CycleTime` bouclage `TIME()` ~49.7j non géré, garde-fou proposé | `AUDIT_Revue_Technique_v1.0.md §8` |

## ❌ Hors périmètre / manquant confirmé

- **Visu IHM graphique** : dossier `visu/` vide, seule couche d'échange `GVL_IHM` existe (§2 "❌ Manquant").
- **`PRG_08_AuxiliaryControl`** : casque/grille/centrale hydraulique retirés du PLC (différé assumé, T6/T37 résolu côté PLC — reste décision client scope final).

## ⚠️ Specs incomplètes / non tranchées à signaler

- **T87** : doc `FB_Brake` décrit un comportement (`DelayMotorDecel`) qui n'existe pas dans le code → doc erronée, à corriger indépendamment du choix (garder/retirer).
- **T91** : décision produit "montée serre frein avant coupure / descente immédiate" **non actée en code**, étude uniquement — ne pas implémenter avant validation terrain avec dragueur présent.
- **T93** : remplacement rampe %/s par temporisations palier — **impact large non chiffré** (`FB_Winch`, `FB_SpeedStep`, `FB_Cycle`, IHM, `GVL_PERSISTENT`), interaction directe avec T91, à étudier ensemble avant tout code.
- **T47** : bandes de vitesse `[0.4,0.8,1.2,1.6,2.0]` m/s sont **valeurs provisoires théoriques** (dérivées de `MaxMeasuredSpeedMps:=2.0` provisoire) — non calibrées terrain.
- **T4** : protocole registre AC600 (`DriveControlWord`/`StatusWord`) dépend du **constructeur variateur** — non résolu côté projet.
- **T19** : mapping `ChannelOk` carte/voie E-S à définir "si besoin confirmé" — pas de décision.
- **T70** : `Modes.SelMode` etc. repartent en MAINT_N1 au boot — à confirmer voulu ou oubli (question ouverte client).
- **T8** : rôle `CodeSeqTriggerCmd` (codeurs) à vérifier terrain, pas de réponse.
- **T9** : comportement frein en montée chargée — différé après essais terrain, lié à T91.
- **T11** : `EmergencyStopOk` sans confirmation temporisée post-réarmement, redondance A/B logicielle seulement — non résolu.
- **T63** : persistance flags simulation + split `GVL_SimulationBench` reportés (bindings visu à maquetter avant import).

## Recette / stratégie mise en service (`PLAN_TASK §4.0`, actée 2026-07-27)

Ordre imposé "on mesure avant de protéger" :
1. Lots code AVANT essais : **T84+T85+T86** (fait, à valider) → **T81+T82** (fait, à valider) → **T94+T95** (garde-fou pilotable + table calibration, non fait).
2. Déroulé machine : Phase 0 Preflight → Phase 1 simu par domaine → Phase 2 essais réels palier vide/charge (**garde-fou DÉSACTIVÉ**) → Phase 3 renseigner bandes mesurées → Phase 4 activer `SpeedGuardEnable` → Phase 5 bypass+homing+cycle complet.
3. Études parallèles sans décision: **T91** (frein) + **T93** (temporisation palier), à mener ensemble sur machine.
4. Avant livraison : simulation OFF, bypass RETAIN à zéro, `IhmHeartbeat:=FALSE` (T83), `SpeedGuardEnable` activé, valeurs persistantes archivées.

## Cohérence VERSION_HISTORY vs PLAN_TASK

- `LOT2A_KoboldMaintenanceAssist` (2026-07-28) et `T84-T85-T86_EncoderSpeedOwnership` (2026-07-28) confirment lots 1 et 2 codés, en attente validation CODESYS — cohérent avec table plan orchestré.
- `0.5.2_Troubleshooting_SignalChain` (2026-07-27) : `PRG_11_Troubleshooting` créé, lecture seule confirmée par relecture code (aucune écriture machine détectée, seulement `instPreflight`/`instWinchSymmetry` et remplissage `GVL_Troubleshooting`) — RAS, pas de dette identifiée ici.
- Aucune divergence trouvée entre VERSION_HISTORY et l'état "🟠 implémenté / validation requise" du PLAN_TASK pour les lots 1-2.

## Départage criticité (résumé priorisé)

1. **Sécurité bloquante avant essais en charge** : T91 (étude), T87 (code mort trompeur), T52 (validation PowerCutOff physique), T72/T73/T74 (interverrouillages/escalade).
2. **Outils indispensables avant calibration** : T94, T95 (sans eux T47 se calibre "au jugé").
3. **Activation différée mais actée** : T47 (garde-fou palier) — ne pas activer sans T94/T95/essais phase 2-3.
4. **Validation terrain en attente (code fait)** : T17, T21, T25, T26, T27, T39, T48, T56, T64, T89, T90, T92.
5. **Dette technique mineure / différée** : lot 6 (T75-T79, T88), sans risque sécurité immédiat.
6. **Hors scope confirmé** : visu graphique, PRG_08 auxiliaire.

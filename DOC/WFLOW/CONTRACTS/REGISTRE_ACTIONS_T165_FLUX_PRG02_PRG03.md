# Registre d'actions T165 — flux PRG_02 / PRG_03

> Registre C4 de conservation et de remappage. Une ligne n'est close qu'avec preuve nommée.

## 🧱 Checkpoints

| Jalon | Contenu | Sortie exigée |
|---|---|---|
| CP0 | Référence `54a5715c`, code inchangé | inventaire `rg`, tests de référence |
| CP1 | Publication complète PRG_02 | nouveaux champs visibles, aucun consommateur changé |
| CP2 | Consommateurs PRG_02 migrés | zéro accès externe à `PRG_02.inst*` |
| CP3 | Revue indépendante PRG_02 | verdict AC + manuel M1/M2/M3 conservé |
| CP3bis | Audit préalable FB_Cycle | profil AF‑03 réel et statut T164-5 réconciliés |
| CP4 | Publication complète PRG_03 | `Data` public, comportement cycle conservé hors décisions validées |
| CP5 | Consommateurs PRG_03 migrés | zéro accès à `instCycleSemiAuto` |
| CP6 | Revue indépendante PRG_03 | chaîne `Req→Tgt→Cmd→Act`, safety locale et diagnostics vérifiés |

## 📋 Remappage PRG_02

| ID | Source actuelle | Cible | Consommateurs principaux | Preuve fermeture |
|---|---|---|---|---|
| R02-01 | `instJoystick.AxisCmdX/Y` | `Data.Joystick.AxisX/Y` | PRG_03/04/05/07 | `rg` zéro accès externe |
| R02-02 | `instJoystick.AtNeutralXY` | `Data.Joystick.AtNeutralXY` | PRG_03/04/07 | idem |
| R02-03 | `instJoystick.Fault/Ready/ArmingPermitDenied/NeutralXAct/NeutralYAct` | `Data.Joystick.*` | PRG_07/diagnostic | comparaison IHM |
| R02-04 | `instDiagCanOpen.*` | `Data.Network.CanOpenMaster/Joystick` | PRG_04/05/07 | comparaison structure exacte |
| R02-05 | `instDiagEthercat.*` | `Data.Network.EthercatMaster/EncoderM1/EncoderM2/DriveM3` | PRG_04/05/07 | comparaison structure exacte |
| R02-06 | sorties `instEncoderM1/M2` | `Data.EncoderM1/M2` | PRG_03/04/07/simulation | tableau source→champ validé |
| R02-07 | `PRG_04.instWinch*` lu par PRG_02 | `PRG_04.Data.Winch*State` N‑1 | homing/simulation | zéro accès interne aval |

## 📋 Remappage PRG_03

| ID | Source actuelle | Cible | Consommateurs principaux | Preuve fermeture |
|---|---|---|---|---|
| R03-01 | `Auth` public séparé | `Data.Auth` | PRG_02/04/05/07 | zéro ancien accès |
| R03-02 | `instCycleSemiAuto.WinchM1Cmd/M2Cmd` | `Data.ReqProgram.ReqWinchM1/M2` | PRG_04/07 | valeurs avant/après identiques |
| R03-03 | `instCycleSemiAuto.TranslationCmd` | `Data.ReqProgram.ReqTranslation` | PRG_05/07 | valeurs avant/après identiques |
| R03-04 | `instCycleSemiAuto.BucketCmd` | `Data.ReqProgram.ReqBucket` | PRG_04/07 | valeurs avant/après identiques |
| R03-05 | lifecycle/error/step de l'instance | `Data.SequenceState` | PRG_07/troubleshooting | IHM et fault snapshot |
| R03-06 | internals PRG_04/05 lus par PRG_03 | `PRG_04.Data` / `PRG_05.Data` N‑1 | `FB_Cycle` | zéro accès instance/locale |

## ⚠️ Actions bloquantes

| ID | Sujet | Responsable décision | Statut |
|---|---|---|---|
| A-01 | Source réelle de `ArmingPermit` | humain + safety | OUVERT |
| A-02 | Deadman uniforme pour manuel/semi-auto/assistants | humain + safety | OUVERT |
| A-03 | `%` ou `SpeedStep 1..5` dans demande programme | humain + AF‑10 | OUVERT |
| A-04 | `Auth` courant dans cycle | humain | RECOMMANDÉ, non visé |
| A-05 | propriétaire DiveSearch/Extraction | humain + AF‑02/04/10 | OUVERT |
| A-06 | chronologie Kobold | humain + essai fonctionnel | BLOCK |
| A-07 | X11 ouverture/descente | humain + AF‑04 | BLOCK |
| A-08 | capture étape au défaut | architecture cycle | OUVERT |
| A-09 | rôle de `PowerContactorEngaged` dans séquenceurs | humain + AF‑03 | OUVERT |
| A-10 | consommation safety unique de `EncoderFault` | humain + safety | BLOCK |
| A-11 | polarité frein M3 AF‑06/code | humain + AF‑06/AF‑11 | BLOCK DOCUMENTAIRE |

## 🚫 Anti-débordement

- aucun seuil, tempo, polarité, rampe, interlock ou GRAFCET modifié pendant les remappages ;
- aucune édition `TASKS.yaml` par les agents d'exécution ;
- aucun `Device.export`, `PRJ_CODESYS/`, commit ou push ;
- un défaut fonctionnel découvert produit `fix:` + `guard:` dans une tâche séparée ;
- toute variable non inventoriée déclenche STOP et mise à jour du registre avant édition.

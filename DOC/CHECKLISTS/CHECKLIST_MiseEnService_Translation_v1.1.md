# ✅ Checklist Mise en Service — Translation M3 / AC600 (v1.1)

> 📌 Version terrain courte, alignée IHM 2026-07-22. Commandes : `GVL_IHM.TranslationM3.Cmd`. Retours : `.State`. Sécurité : `.Safety`.

## 1. Préparer

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 1 | Zone M3 évacuée, AU physique testé, personnel averti | Essai autorisé | ☐ |
| 2 | Vérifier `Modes.EmergencyStopOk` et `Modes.PowerCutOffActive` | `TRUE` / `FALSE` | ☐ |
| 3 | Vérifier `TranslationM3.State.Error` et `.Safety.Error` | `FALSE` / `FALSE` | ☐ |
| 4 | Mettre `Modes.SelMode := MAINT_N1` | `Modes.CurrentMode=MAINT_N1` | ☐ |
| 5 | Régler `.Cmd.SetFreq_Hz := 20.0` | Vitesse prudente | ☐ |

## 2. Valider EtherCAT et frein

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 6 | Vérifier `.State.DriveCommReady` et `.DrivePowerReady` | Les deux à `TRUE` | ☐ |
| 7 | Vérifier frein au repos | `.State.BrakeCmd=FALSE` et retour cohérent | ☐ |
| 8 | Contrôler `.State.SensorsWord` | Un des six mots valides : `11111`, `01111`, `00111`, `00011`, `00001`, `00000` | ☐ |
| 9 | Vérifier `.State.SensorWordIncoherent` | `FALSE` | ☐ |

## 3. Premier mouvement

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 10 | `.Cmd.TglJoystickMaster=FALSE`, armer homme-mort | `JOY1Joystick.DeadmanArmed=TRUE` | ☐ |
| 11 | Maintenir `.Cmd.BtnFwd` | Marche avant, fréquence réelle cohérente | ☐ |
| 12 | Relâcher `.Cmd.BtnFwd` | Rampe normale, puis frein serré | ☐ |
| 13 | Maintenir `.Cmd.BtnRev` | Marche arrière, fréquence réelle cohérente | ☐ |
| 14 | Inverser le sens en mouvement | Arrêt, délai 200 ms, puis inversion sans commande contradictoire | ☐ |

## 4. Joystick et positionneur

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 15 | `.Cmd.TglJoystickMaster=TRUE`, dévier axe X avec homme-mort | Sens/vitesse suivent l'axe X | ☐ |
| 16 | Activer `.Cmd.SelPositioning`, choisir cible 1/2/3 | `.State.PositionReached=TRUE` à la cible | ☐ |
| 17 | Choisir cible 4 hors MAINT_N2 | Refusée | ☐ |
| 18 | En MAINT_N2, choisir cible 4 | Autorisée si capteurs valides | ☐ |
| 19 | Atteindre une limite extrême | Arrêt, `.Safety.ErrorLimitSwitch=TRUE`, `PowerCutOffActive=TRUE` | ☐ |

## 5. Défauts et reset

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 20 | Déclencher un défaut sécurité contrôlé | `.Safety.ErrorId` mémorisé, arrêt sûr selon défaut | ☐ |
| 21 | Supprimer la cause puis front `Modes.BtnFaultReset` | Défaut effacé, pas de redémarrage automatique | ☐ |
| 22 | Appuyer AU physique en marche, selon procédure site | Puissance coupée, retour au repos sans redémarrage | ☐ |

## 6. Simulation vers réel

1. En simulation : exécuter les essais banc avant mouvement réel.
2. Valider un à un `BusVariateurM3IsReal`, `SensorTranslationPositionIsReal`, `SensorM3ContactorFeedbackIsReal`, `SensorPhaseRotationIsReal`, `SensorBrakeThermalIsReal`.
3. Seulement ensuite, passer `GVL_Simulation.SimulationModeActive := FALSE`.

**Verdict M3** : ☐ PASS · ☐ FAIL · ☐ Non testé (raison : __________)

📎 Détail historique : `../../ARCHIVES/Doc/CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.0.md`.
Références : `../AF_Partie-07_Interface_IHM_v1.7.md`, `../AF_Partie-11_Fonction_Translation_v1.11.md`.

# ✅ Checklist Mise en Service — Joystick JOY1 (v1.1)

> 📌 Version opérationnelle alignée IHM 2026-07-22. Référence : `GVL_IHM.JOY1Joystick`.

| # | Action | Attendu | Pass/Fail |
|---|---|---|---|
| 1 | `SimulationModeActive=TRUE`, valider `BusJoystickSignalIsReal=TRUE` puis `BusJoystickIsReal=TRUE` | Signaux bruts et CAN réels lus | ☐ |
| 2 | Passer `SimulationModeActive=FALSE` seulement après 1 | Aucun joystick simulé résiduel | ☐ |
| 3 | Manche au repos, front `JOY1Joystick.BtnCalibrate` | `NeutralXAct`/`NeutralYAct` suivent le brut | ☐ |
| 4 | Vérifier `RawX`/`RawY` au repos et en butées | Plage cohérente 0..10000 | ☐ |
| 5 | Appuyer homme-mort hors neutre | `DeadmanArmed=FALSE` | ☐ |
| 6 | Appuyer homme-mort au neutre | `DeadmanArmed=TRUE` | ☐ |
| 7 | Dévier X puis Y | `AxisCmdX`/`AxisCmdY` donnent sens et vitesse attendus | ☐ |
| 8 | Relâcher l'homme-mort en mouvement | Décélération puis aucune reprise automatique | ☐ |
| 9 | Repasser neutre puis réappuyer | Nouvelle action volontaire requise | ☐ |
| 10 | Couper CANopen | `.Online`/`.Operational` tombent, `.ErrorId` mémorise le défaut | ☐ |
| 11 | Rétablir CAN puis front `GVL_IHM.Modes.BtnFaultReset` | Défaut effacé seulement après disparition de la cause | ☐ |

**Verdict JOY1** : ☐ PASS · ☐ FAIL · ☐ Non testé (raison : __________)

📎 Détail technique : `../../ARCHIVES/Doc/CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.0.md`
(historique) et `../AF_Partie-08_Fonction_Joystick_v1.3.md`.

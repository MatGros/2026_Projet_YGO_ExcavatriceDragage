# 🧭 NAVBOARD — Mise en Service Joystick + Translation M3

> Fiche d'action. Checklists : `DOC/CHECKLISTS/`.

## 1. Ordre de bascule réel

1. Garder `GVL_Simulation.SimulationModeActive := TRUE`.
2. Valider et passer à `TRUE` : `BusJoystickSignalIsReal`, puis `BusJoystickIsReal`.
3. Valider M3 : `BusVariateurM3IsReal`, `SensorTranslationPositionIsReal`, `SensorM3ContactorFeedbackIsReal`, `SensorPhaseRotationIsReal`, `SensorBrakeThermalIsReal`.
4. Après tous les contrôles matériels : `SimulationModeActive := FALSE`.

## 2. Joystick JOY1

1. Manche physique au repos.
2. Front `GVL_IHM.JOY1Joystick.BtnCalibrate`.
3. Vérifier `JOY1Joystick.NeutralXAct` et `.NeutralYAct`.
4. Maintenir le manche au neutre, appuyer homme-mort.
5. Vérifier `JOY1Joystick.DeadmanArmed := TRUE`.
6. Dévier X pour M3, Y pour treuils.

| Défaut | Chemin |
|---|---|
| CAN / calibration | `GVL_IHM.JOY1Joystick.ErrorId` |
| Liaison | `GVL_IHM.JOY1Joystick.Online` / `.Operational` |
| Axes calculés | `GVL_IHM.JOY1Joystick.AxisCmdX` / `.AxisCmdY` |

## 3. Translation M3, boutons IHM

1. `GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1`.
2. Vérifier `GVL_IHM.Modes.EmergencyStopOk := TRUE`.
3. Régler `GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := 20.0`.
4. Régler `.Cmd.TglJoystickMaster := FALSE`.
5. Armer l'homme-mort joystick au neutre.
6. Maintenir `.Cmd.BtnFwd` ou `.Cmd.BtnRev`.
7. Relâcher pour arrêter.

## 4. Translation M3, joystick

1. `.Cmd.TglJoystickMaster := TRUE`.
2. Homme-mort armé au neutre.
3. Dévier axe X : positif = avant/Trémie, négatif = arrière/Maintenance.
4. Lire `.State.DriveFreqRef_Hz` et `.State.DriveActualFreq_Hz`.

## 5. Treuils et benne

| Fonction | Commande IHM actuelle |
|---|---|
| M1 boutons | `GVL_IHM.M1TreuilRetenue.Cmd.BtnUp` / `.BtnDown` |
| M2 boutons | `GVL_IHM.M2TreuilBenne.Cmd.BtnUp` / `.BtnDown` |
| Source treuils | `GVL_IHM.Modes.TglJoystickMaster` |
| Sélection M1/M2/couplé | `GVL_IHM.Modes.SelJoystickWinch` |
| Benne | `GVL_IHM.M2Benne.BtnOpen` / `.BtnClose` |
| Homing | `M1TreuilRetenue.Cmd.BtnHome` / `M2TreuilBenne.Cmd.BtnHome` |

Les boutons treuils et Translation exigent toujours l'homme-mort joystick armé.

## 6. Reset sûr

1. Arrêter la demande de mouvement.
2. Supprimer la cause physique.
3. Front `GVL_IHM.Modes.BtnFaultReset`.
4. Confirmer `Modes.AnyFaultActive = FALSE` et aucun `PowerCutOffActive`.
5. Recommencer avec une commande volontaire.

⚠️ Ne jamais forcer `SafeStop`, `PowerCutOff`, les retours de sécurité ou les sorties de commande.

# 🧭 NAVBOARD — Translation M3

> 🎯 Mémo action terrain. Référence IHM : `GVL_IHM.TranslationM3`.
> Commande = `.Cmd` · lecture = `.State` · sécurité = `.Safety`.

## 1. Avant mouvement

| Vérifier | Valeur attendue |
|---|---|
| Mode | `GVL_IHM.Modes.CurrentMode = MAINT_N1` (ou `MAINT_N2` pour Maintenance) |
| Puissance | `GVL_IHM.Modes.EmergencyStopOk = TRUE` |
| Défaut mouvement | `GVL_IHM.TranslationM3.State.Error = FALSE` |
| Défaut safety | `GVL_IHM.TranslationM3.Safety.Error = FALSE` |
| Coupure puissance | `GVL_IHM.Modes.PowerCutOffActive = FALSE` |
| Homme-mort | `GVL_IHM.JOY1Joystick.DeadmanArmed = TRUE` |

⚠️ `SafeStop`, `PowerCutOff` et les sorties M3 sont calculés : ne jamais les forcer.

## 2. Premier mouvement prudent

1. Régler `GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := 20.0`.
2. Choisir les boutons : `GVL_IHM.TranslationM3.Cmd.TglJoystickMaster := FALSE`.
3. Armer le joystick au neutre, puis maintenir le bouton homme-mort.
4. Maintenir `GVL_IHM.TranslationM3.Cmd.BtnFwd` **ou** `.BtnRev`.
5. Relâcher le bouton IHM ou l'homme-mort : arrêt normal sur rampe.
6. Contrôler `.State.DriveFreqRef_Hz`, puis `.State.DriveActualFreq_Hz`.

## 3. Pilotage joystick

| Réglage | Action |
|---|---|
| `.Cmd.TglJoystickMaster := TRUE` | Axe X pilote le sens et la vitesse |
| Homme-mort armé | Obligatoire |
| Axe X positif | Marche avant / Trémie (`Direction=+1`) |
| Axe X négatif | Marche arrière / Maintenance (`Direction=-1`) |

`SetFreq_Hz` reste la pleine échelle joystick. Le mouvement ne démarre pas avec le seul axe X sans homme-mort.

## 4. Positionneur

1. Activer `.Cmd.SelPositioning := TRUE`.
2. Choisir `.Cmd.SelTarget` : `1=Trémie`, `2=P2`, `3=P1`, `4=Maintenance`.
3. Demander le sens avec boutons ou joystick : le positionneur arrête sur la cible.
4. Lire `.State.PositionReached`.

⚠️ Cible `4` uniquement en `MAINT_N2`. PV n'est jamais une cible. Après une arrivée, repartir brièvement dans le sens opposé pour libérer le verrou d'arrivée.

## 5. Lecture rapide

| Besoin | Variable |
|---|---|
| État FB M3 | `TranslationM3.State.FBState` |
| Défaut variateur/mouvement | `TranslationM3.State.ErrorId` |
| Défaut sécurité | `TranslationM3.Safety.ErrorId` |
| Frein | `TranslationM3.State.BrakeCmd` / `.BrakeFeedback` |
| Position capteurs | `TranslationM3.State.SensorsWord` |
| Cohérence capteurs | `TranslationM3.State.SensorWordIncoherent` |
| Limites | `TranslationM3.State.LimitSwitchFwd` / `.LimitSwitchRev` |
| Variateur prêt | `TranslationM3.State.DriveCommReady` / `.DrivePowerReady` |

## 6. Reset et dépannage

1. Supprimer la cause.
2. Envoyer un front sur `GVL_IHM.Modes.BtnFaultReset`.
3. Vérifier que `.State.Error` et `.Safety.Error` sont retombés à `FALSE`.
4. Reprendre par une nouvelle commande volontaire et un homme-mort réarmé.

| Symptôme | Contrôle prioritaire |
|---|---|
| Aucun mouvement | Mode, `EmergencyStopOk`, homme-mort, `.Safety.Error` |
| Boutons inactifs | `.Cmd.TglJoystickMaster=FALSE` et homme-mort armé |
| Joystick inactif | `.Cmd.TglJoystickMaster=TRUE`, axe X hors deadband |
| Arrêt en limite | Commander le sens opposé |
| Défaut capteurs | `.State.SensorWordIncoherent` puis câblage des 5 capteurs |

## 7. Bascule simulation vers réel

Conserver `GVL_Simulation.SimulationModeActive := TRUE` pendant le câblage progressif, puis passer chaque device réellement validé à `TRUE` :

`BusVariateurM3IsReal` · `SensorTranslationPositionIsReal` · `SensorM3ContactorFeedbackIsReal` · `SensorPhaseRotationIsReal` · `SensorBrakeThermalIsReal`.

Mettre `SimulationModeActive := FALSE` seulement lorsque tous les équipements M3 requis sont réels et vérifiés.

📎 Détail : `DOC/CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md`.

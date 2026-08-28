# 🗺️ Migration Variables IHM — Chantier Persistance (Lot 1 & 2)

> 🎯 **But** : liste des chemins `GVL_IHM.*` qui ont changé pendant ce chantier, pour reparamétrer
> le mapping IHM (SCADA/pupitre). Mis à jour à chaque lot **committé** (pas avant vérification).
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `ARCHIVES/Doc/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> ⚠️ Rien ici n'est "peut-être" — chaque ligne = déjà committé et poussé sur `origin/main`.

---

## ✅ Lot 1a — Bypass (commit `303c44a`)

**Aucun chemin renommé/supprimé.** Uniquement des **nouveaux champs bypass** ajoutés (rien à
casser côté IHM existant, juste des interrupteurs en plus si tu veux les exposer) :

| Nouveau chemin | Rôle |
|---|---|
| `GVL_IHM.M1TreuilRetenue.Bypass.Safety` | Bypass groupé défauts critiques M1 (escaladent PowerCutOff) |
| `GVL_IHM.M1TreuilRetenue.Bypass.Process` | Bypass groupé défauts non-critiques M1 |
| `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch` | Bypass individuel fin de course haute M1 |
| `GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch` | Bypass individuel limite basse câble M1 |
| `GVL_IHM.M2TreuilBenne.Bypass.Safety` | Idem M2 |
| `GVL_IHM.M2TreuilBenne.Bypass.Process` | Idem M2 |
| `GVL_IHM.M2TreuilBenne.Bypass.TopLimitSwitch` | Idem M2 |
| `GVL_IHM.M2TreuilBenne.Bypass.CableLimitSwitch` | Idem M2 |
| `GVL_IHM.TranslationM3.Bypass.Safety` | Bypass groupé défauts critiques Translation |
| `GVL_IHM.TranslationM3.Bypass.Process` | Bypass groupé défauts non-critiques Translation |
| `GVL_IHM.Network.Bypass.Joystick` | Bypass diag réseau CANopen Joystick |
| `GVL_IHM.Network.Bypass.EncoderM1` | Bypass diag réseau EtherCAT COD1 |
| `GVL_IHM.Network.Bypass.EncoderM2` | Bypass diag réseau EtherCAT COD2 |
| `GVL_IHM.Network.Bypass.VariateurM3` | Bypass diag réseau EtherCAT AC600 |

Tous les chemins existants (`...Bypass.Global`, `...Bypass.EncoderFault`, etc.) restent identiques.

---

## ✅ Lot 2a — Sync → M1M2Sync (commit `70377f5`)

Groupe racine renommé : `GVL_IHM.Sync` → `GVL_IHM.M1M2Sync`.

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.Sync.SelSyncEnable` | `GVL_IHM.M1M2Sync.Cmd.SelSyncEnable` |
| `GVL_IHM.Sync.DeltaPos_M` | `GVL_IHM.M1M2Sync.State.DeltaPos_M` |
| `GVL_IHM.Sync.SyncActive` | `GVL_IHM.M1M2Sync.State.SyncActive` |
| `GVL_IHM.Sync.SyncWarn` | `GVL_IHM.M1M2Sync.State.SyncWarn` |
| `GVL_IHM.Sync.Ready` | `GVL_IHM.M1M2Sync.State.Ready` |
| `GVL_IHM.Sync.Error` | `GVL_IHM.M1M2Sync.State.Error` |
| `GVL_IHM.Sync.ErrorId` | `GVL_IHM.M1M2Sync.State.ErrorId` |
| `GVL_IHM.Sync.State` | `GVL_IHM.M1M2Sync.State.FBState` |
| `GVL_IHM.Sync.CfgSyncTolerance_M` | `GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M` |
| `GVL_IHM.Sync.BypassGlobal` | `GVL_IHM.M1M2Sync.Bypass.Global` |

---

## ✅ Lot 2b — M2Benne → M2TreuilBenne.Bucket (commit `70377f5`)

Groupe déplacé : `GVL_IHM.M2Benne` → nesté sous `GVL_IHM.M2TreuilBenne.Bucket`.

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.M2Benne.BtnOpen` | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen` |
| `GVL_IHM.M2Benne.BtnClose` | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose` |
| `GVL_IHM.M2Benne.BtnReset` | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset` |
| `GVL_IHM.M2Benne.BtnConfirmOpenPos` | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos` |
| `GVL_IHM.M2Benne.BtnConfirmClosePos` | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos` |
| `GVL_IHM.M2Benne.State` (mémoire ouverte/fermée) | `GVL_IHM.M2TreuilBenne.Bucket.State.MechState` |
| — (nouveau sous-champ `ST_fbBucket_State`) | `GVL_IHM.M2TreuilBenne.Bucket.State.MechState.ActiveOffsetValid` |
| `GVL_IHM.M2Benne.FBState` | `GVL_IHM.M2TreuilBenne.Bucket.State.FBState` |
| `GVL_IHM.M2Benne.ActiveOffset_M` | `GVL_IHM.M2TreuilBenne.Bucket.State.ActiveOffset_M` |
| `GVL_IHM.M2Benne.M2StartStop` | `GVL_IHM.M2TreuilBenne.Bucket.State.M2StartStop` |
| `GVL_IHM.M2Benne.M2Direction` | `GVL_IHM.M2TreuilBenne.Bucket.State.M2Direction` |
| `GVL_IHM.M2Benne.M2ForceSlowSpeed` | `GVL_IHM.M2TreuilBenne.Bucket.State.M2ForceSlowSpeed` |
| `GVL_IHM.M2Benne.Ready` | `GVL_IHM.M2TreuilBenne.Bucket.State.Ready` |
| `GVL_IHM.M2Benne.Busy` | `GVL_IHM.M2TreuilBenne.Bucket.State.Busy` |
| `GVL_IHM.M2Benne.Done` | `GVL_IHM.M2TreuilBenne.Bucket.State.Done` |
| `GVL_IHM.M2Benne.Error` | `GVL_IHM.M2TreuilBenne.Bucket.State.Error` |
| `GVL_IHM.M2Benne.ErrorId` | `GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId` |
| `GVL_IHM.M2Benne.RemainingTravel_M` | `GVL_IHM.M2TreuilBenne.Bucket.State.RemainingTravel_M` |
| `GVL_IHM.M2Benne.CloseActive` | `GVL_IHM.M2TreuilBenne.Bucket.State.CloseActive` |
| `GVL_IHM.M2Benne.OpenActive` | `GVL_IHM.M2TreuilBenne.Bucket.State.OpenActive` |
| `GVL_IHM.M2Benne.M2PositionCorrected` | `GVL_IHM.M2TreuilBenne.Bucket.State.M2PositionCorrected` |
| `GVL_IHM.M2Benne.Config` | `GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config` |
| `GVL_IHM.M2Benne.CfgTimeoutDuration` | `GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration` |
| `GVL_IHM.M2Benne.BypassGlobal` | `GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global` |

⚠️ `GVL_IHM.M1TreuilRetenue.Bucket.*` existe aussi maintenant (même type `ST_WinchHMI` partagé
M1/M2) mais **inerte côté M1** — ne pas le mapper sur l'IHM, il n'est jamais lu/écrit par le PLC
pour M1.

---

## ✅ Lot 2c — Commun (commit `70377f5`)

Extraction partielle : seuls les réglages numériques bougent, le reste de `ST_CommunHMI` est
**inchangé** (diagnostics, heartbeat, bypass, boutons Both Up/Down).

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.Commun.LimitLegalDepthMinAllowed_M` | `GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M` |
| `GVL_IHM.Commun.LimitLegalEnabled` | `GVL_IHM.Commun.Cfg.LimitLegalEnabled` |
| `GVL_IHM.Commun.SelHomingApproachEnable` | `GVL_IHM.Commun.Cfg.SelHomingApproachEnable` |

`GVL_IHM.Commun.LimitLegalReached` (calculé, lecture seule) **ne bouge pas** — reste à la racine.

---

## ✅ Lot 2d — Modes (vérifié)

Groupe **conservé** `GVL_IHM.Modes`, split interne en `Cmd`/`State` :

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.Modes.SelMode` | `GVL_IHM.Modes.Cmd.SelMode` |
| `GVL_IHM.Modes.BtnFaultReset` | `GVL_IHM.Modes.Cmd.BtnFaultReset` |
| `GVL_IHM.Modes.BtnModeReset` | `GVL_IHM.Modes.Cmd.BtnModeReset` |
| `GVL_IHM.Modes.BtnEmergencyArming` | `GVL_IHM.Modes.Cmd.BtnEmergencyArming` |
| `GVL_IHM.Modes.BtnEmergencyCutOff` | `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` |
| `GVL_IHM.Modes.SelJoystickWinch` | `GVL_IHM.Modes.Cmd.SelJoystickWinch` |
| `GVL_IHM.Modes.TglJoystickMaster` | `GVL_IHM.Modes.Cmd.TglJoystickMaster` |
| `GVL_IHM.Modes.CurrentMode` | `GVL_IHM.Modes.State.CurrentMode` |
| `GVL_IHM.Modes.EmergencyStopOk` | `GVL_IHM.Modes.State.EmergencyStopOk` |
| `GVL_IHM.Modes.AnyFaultActive` | `GVL_IHM.Modes.State.AnyFaultActive` |
| `GVL_IHM.Modes.PowerCutOffActive` | `GVL_IHM.Modes.State.PowerCutOffActive` |
| `GVL_IHM.Modes.EmergencyChainOk` | `GVL_IHM.Modes.State.EmergencyChainOk` |
| `GVL_IHM.Modes.PowerContactorOk` | `GVL_IHM.Modes.State.PowerContactorOk` |
| `GVL_IHM.Modes.EmergencyArmable` | `GVL_IHM.Modes.State.EmergencyArmable` |
| `GVL_IHM.Modes.EmergencyArmingBusy` | `GVL_IHM.Modes.State.EmergencyArmingBusy` |
| `GVL_IHM.Modes.RedundancyTestFailed` | `GVL_IHM.Modes.State.RedundancyTestFailed` |
| `GVL_IHM.Modes.EmergencyArmingFailed` | `GVL_IHM.Modes.State.EmergencyArmingFailed` |

---

## ✅ Lot 2e — Joystick (vérifié)

Groupe **conservé** `GVL_IHM.JOY1Joystick`, split interne en `Cmd`/`State` :

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.JOY1Joystick.BtnCalibrate` | `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` |
| `GVL_IHM.JOY1Joystick.RawX` | `GVL_IHM.JOY1Joystick.State.RawX` |
| `GVL_IHM.JOY1Joystick.RawY` | `GVL_IHM.JOY1Joystick.State.RawY` |
| `GVL_IHM.JOY1Joystick.RawButton` | `GVL_IHM.JOY1Joystick.State.RawButton` |
| `GVL_IHM.JOY1Joystick.AxisCmdX` | `GVL_IHM.JOY1Joystick.State.AxisCmdX` |
| `GVL_IHM.JOY1Joystick.AxisCmdY` | `GVL_IHM.JOY1Joystick.State.AxisCmdY` |
| `GVL_IHM.JOY1Joystick.NeutralXAct` | `GVL_IHM.JOY1Joystick.State.NeutralXAct` |
| `GVL_IHM.JOY1Joystick.NeutralYAct` | `GVL_IHM.JOY1Joystick.State.NeutralYAct` |
| `GVL_IHM.JOY1Joystick.DeadmanArmed` | `GVL_IHM.JOY1Joystick.State.DeadmanArmed` |
| `GVL_IHM.JOY1Joystick.Online` | `GVL_IHM.JOY1Joystick.State.Online` |
| `GVL_IHM.JOY1Joystick.Operational` | `GVL_IHM.JOY1Joystick.State.Operational` |
| `GVL_IHM.JOY1Joystick.Error` | `GVL_IHM.JOY1Joystick.State.Error` |
| `GVL_IHM.JOY1Joystick.ErrorId` | `GVL_IHM.JOY1Joystick.State.ErrorId` |

---

## ✅ Lot 2f — Cycle (vérifié) — clôt le Lot 2

⚠️ **Priorité sécurité (T66) corrigée** : ce lot a aussi créé un backing `GVL_PERSISTENT` réel pour
`SetDepth_M`/`SetOffset_M` (`_CycleSetDepth_M`/`_CycleSetOffset_M`), qui n'en avaient aucun avant
(juste un défaut compilé dans le DUT) — câblage restauration/sauvegarde identique au pattern
`M1M2Sync.Cfg`.

Groupe **conservé** `GVL_IHM.Cycle`, split interne en `Cmd`/`State`/`Cfg`/`Test` (`Test` existait
déjà, inchangé) :

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.Cycle.BtnStart` | `GVL_IHM.Cycle.Cmd.BtnStart` |
| `GVL_IHM.Cycle.BtnPause` | `GVL_IHM.Cycle.Cmd.BtnPause` |
| `GVL_IHM.Cycle.BtnAbort` | `GVL_IHM.Cycle.Cmd.BtnAbort` |
| `GVL_IHM.Cycle.BtnReset` | `GVL_IHM.Cycle.Cmd.BtnReset` |
| `GVL_IHM.Cycle.SetDepth_M` | `GVL_IHM.Cycle.Cfg.SetDepth_M` |
| `GVL_IHM.Cycle.SetOffset_M` | `GVL_IHM.Cycle.Cfg.SetOffset_M` |
| `GVL_IHM.Cycle.Ready` | `GVL_IHM.Cycle.State.Ready` |
| `GVL_IHM.Cycle.Busy` | `GVL_IHM.Cycle.State.Busy` |
| `GVL_IHM.Cycle.Done` | `GVL_IHM.Cycle.State.Done` |
| `GVL_IHM.Cycle.Error` | `GVL_IHM.Cycle.State.Error` |
| `GVL_IHM.Cycle.ErrorId` | `GVL_IHM.Cycle.State.ErrorId` |
| `GVL_IHM.Cycle.CycleStep` | `GVL_IHM.Cycle.State.CycleStep` |
| `GVL_IHM.Cycle.CycleStateStr` | `GVL_IHM.Cycle.State.CycleStateStr` |
| `GVL_IHM.Cycle.SelTarget` | `GVL_IHM.Cycle.State.SelTarget` |
| `GVL_IHM.Cycle.KoboldContactFond` | `GVL_IHM.Cycle.State.KoboldContactFond` |
| `GVL_IHM.Cycle.KoboldContactorCmd` | `GVL_IHM.Cycle.State.KoboldContactorCmd` |
| `GVL_IHM.Cycle.LimitLegalReached` | `GVL_IHM.Cycle.State.LimitLegalReached` |
| `GVL_IHM.Cycle.LimitLegalDepth_M` | `GVL_IHM.Cycle.State.LimitLegalDepth_M` |
| `GVL_IHM.Cycle.WinchSyncError` | `GVL_IHM.Cycle.State.WinchSyncError` |
| `GVL_IHM.Cycle.WinchSyncDelta_M` | `GVL_IHM.Cycle.State.WinchSyncDelta_M` |
| `GVL_IHM.Cycle.SpeedMismatch_Mps` | `GVL_IHM.Cycle.State.SpeedMismatch_Mps` |
| `GVL_IHM.Cycle.SpeedMismatchActive` | `GVL_IHM.Cycle.State.SpeedMismatchActive` |
| `GVL_IHM.Cycle.SpeedMismatchConfirmed` | `GVL_IHM.Cycle.State.SpeedMismatchConfirmed` |
| `GVL_IHM.Cycle.M1Position_M` | `GVL_IHM.Cycle.State.M1Position_M` |
| `GVL_IHM.Cycle.M2Position_M` | `GVL_IHM.Cycle.State.M2Position_M` |
| `GVL_IHM.Cycle.DeadmanArmed` | `GVL_IHM.Cycle.State.DeadmanArmed` |
| `GVL_IHM.Cycle.JoystickMotionActive` | `GVL_IHM.Cycle.State.JoystickMotionActive` |
| `GVL_IHM.Cycle.MotionPermit` | `GVL_IHM.Cycle.State.MotionPermit` |

`GVL_IHM.Cycle.Test.KoboldContactFond` **ne bouge pas** (déjà correctement isolé avant ce lot).

---

## ✅ Lot 3d-1 — Winch : 4 champs communs M1/M2 déplacés vers Commun.Cfg (vérifié)

⚠️ **Chemin très probablement câblé sur le pupitre IHM réel** (contrairement à la plupart des
lots précédents) — c'est le domaine du bug originel de ce chantier. Vérifier le pupitre avant
et après ce lot.

`M1TreuilRetenue.Cfg`/`M2TreuilBenne.Cfg` avaient CHACUN leur propre chemin pour 4 valeurs en
réalité PARTAGÉES (même valeur forcée des deux côtés) — un seul chemin les remplace tous les deux :

| Ancien chemin (×2, M1 et M2, valeur toujours identique) | Nouveau chemin (prévu) |
|---|---|
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente` / `GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente` | `GVL_IHM.Commun.Cfg.WinchMaxStepDescente` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent` / `GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepAscent` | `GVL_IHM.Commun.Cfg.WinchMaxStepAscent` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M` / `GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M` | `GVL_IHM.Commun.Cfg.WinchSlowdownDistance_M` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct` / `GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct` | `GVL_IHM.Commun.Cfg.WinchSlowSpeed_Pct` |

---

## ✅ Lot 3e — Translation M3 : TglJoystickMaster fusionné dans le switch machine unique (non commité)

⚠️ **Chemin très probablement câblé sur le pupitre IHM réel** — c'est une **suppression**, pas un
renommage : le champ n'existe plus dans `ST_TranslationCmd`. Si un bouton/indicateur du pupitre M3
pointe encore sur l'ancien chemin, il ne fera plus rien après import — le repointer vers le switch
machine (déjà migré Lot 2d) avant le prochain essai translation.

⚠️ **Changement de comportement au boot** : le switch machine démarre à `TRUE` (joystick).
Translation M3 démarrait avant en boutons IHM (`FALSE`) — après ce lot, M3 démarre en joystick
comme M1/M2.

| Ancien chemin (supprimé) | Nouveau chemin |
|---|---|
| `GVL_IHM.TranslationM3.Cmd.TglJoystickMaster` | `GVL_IHM.Modes.Cmd.TglJoystickMaster` (switch machine unique, pilote aussi M1/M2) |

---

## ✅ Lot 2f — Joystick refactor FB (Cfg IHM + renommages)

Groupe **conservé** `GVL_IHM.JOY1Joystick`. Split `Cmd`/`State`/**`Cfg`** (nouveau bloc).

| Ancien chemin | Nouveau chemin |
|---|---|
| `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` | `GVL_IHM.JOY1Joystick.Cmd.Calibrate` |
| _(nouveau)_ | `GVL_IHM.JOY1Joystick.Cfg.DeadbandRaw` / `.NeutralHoldTime` / `.DeadmanArmHoldTime` / `.DeadmanArmGraceTime` / `.RawOutOfRangeMargin` — bloc éditable IHM, ponté vers `GVL_PERSISTENT._JoystickCfgPersist` via `FB_CfgPersistBridge_fbJoystick_Cfg` |

**Sous-champs ajoutés** dans `GVL_IHM.JOY1Joystick.State.AxisCmdX/Y` (pas de rebinding, chemins parents inchangés) :
`.Direction` (INT -1/0/+1, anim flèche) et `.Deflection` (INT -100..+100 %, anim jauge).
Type interne renommé `ST_Joystick_AxisCmd` → `ST_fbJoystick_AxisCmd` (transparent IHM).

---

## 🔜 Lots à venir (pas encore de document de tâche)

_(Lot 2 sera complet une fois Cycle vérifié — reste ensuite la persistance généralisée, Lot 3.)_

Cette section sera complétée à chaque nouveau lot committé — une seule table par domaine, jamais
de réécriture des lots déjà ✅.

## 🆕 Lot T164-4B — Configuration technologique codeur

Nouveau chemin public commun M1/M2, sans migration des réglages métier des treuils :

| Nouveau chemin | Rôle | Persistance |
|---|---|---|
| `GVL_IHM.Commun.EncoderCfg.PresetConfirmMode` | Sélecteur de confirmation du preset (`READBACK_ONLY=0`, `READBACK_AND_STATUSBIT=1`, `STATUSBIT_ONLY=2`) | `GVL_PERSISTENT._EncoderCfgPersist.PresetConfirmMode` |

Le pont unique est `FB_CfgPersistBridge_fbEncoder_Cfg` dans `PRG_07_Supervision`.
`Initialized` est un drapeau interne de restauration et n'est pas un réglage IHM.
Les cibles `CfgHomingTarget_M` / `CfgTopSensorPos_M` restent sous
`GVL_IHM.M1TreuilRetenue.Cfg` / `GVL_IHM.M2TreuilBenne.Cfg`.

## 🆕 Lot T164-4C — Frontière HwIn/HwOut codeur (transaction preset)

Aucun chemin IHM renommé/supprimé. `PresetStatusBit` est une **entrée hardware**
réservée (`ST_fbEncoder_HwIn`), **pas un chemin IHM** : `PRG_02_Acquisition` la
force à `FALSE` tant qu'aucun bit d'état réel n'est identifié.

| Fait | Rôle | Source d'ownership |
|---|---|---|
| `FB_Encoder.Cfg` | `ST_fbEncoder_Cfg` (`PresetConfirmMode`) lu par la façade | `GVL_IHM.Commun.EncoderCfg` (IHM publique) → pont `FB_CfgPersistBridge_fbEncoder_Cfg` (PRG_07) → `GVL_PERSISTENT._EncoderCfgPersist`. La façade lit l'**IHM publique**, jamais le persistant directement. |
| `FB_Encoder.HwOut` | Ordres preset (type `ST_fbEncoder_HwOut`) | produit par `FB_Encoder`, relayé par `PRG_02` vers le device. |
| `FB_Encoder.HwIn` | Faits hardware d'entrée (type `ST_fbEncoder_HwIn`) | rempli par `PRG_02` depuis `HwIn.Winch.*` + `PresetStatusBit := FALSE`. |

## 🆕 Lot T164-4D — Façade `FB_Encoder` : `Status:ST_Status` → `Fault:ST_Fault`

**Inventaire consommateurs (AC6)** : la sortie `Status` de la **façade** `FB_Encoder` n'a
**aucun consommateur** (ni `instEncoderM1/M2.Status`, ni `.Ready`, ni `.Fault`). Les
consommateurs utilisent `Measurement.AbsStatus`/`HomingStatus`, `Homed`, `HomingSuspect`,
`EncoderFault`, `HomedAndReliable`, `HwOut.*` — tous **conservés**. → **Aucun chemin IHM à
remapper** ; `Fault` est un **nouveau diagnostic** (brique socle `FB_FaultCore`).

| Fait | Rôle | Source d'ownership |
|---|---|---|
| `FB_Encoder.Fault` | Brique défaut socle (`ST_Fault` : vue live `Error`/`ErrorId` + vue latchée `Latched`/`LatchedId`) | produit par `FB_Encoder` via `instFault:FB_FaultCore` + `instCauses` (3 causes : perte matériel live, incohérence live, échec preset latched). Texte IHM dérivé côté IHM depuis `ErrorId`/`LatchedId` (non stocké dans `ST_Fault`). |
| `FB_Encoder.Ready` | `Enable AND NOT Fault.Latched` | produit par `FB_Encoder` ; non consommé actuellement. |
| `FB_Encoder.Status` | **supprimé** (fusion OR des `ErrorId` sous-FB abandonnée, contrat AC1) | aucun consommateur → suppression sans remappage. |

---

## 🆕 Lot T166 / T167-R3-ter — Intention Couplée Opérateur (Cerveau unique PRG_03)

Découplage strict entre les champs synoptiques IHM / Diagnostic de séquence et l'intention de commande opérateur continue :

| Fait / Variable | Rôle | Source d'ownership & Évolution |
|---|---|---|
| `PRG_03.Data.ReqProgram.OperatorCoupledIntent` | `ST_OperatorCoupledIntent` (`Active : BOOL; Direction : INT`) | **Nouveau champ dédié** calculé inconditionnellement par `PRG_03` (tous modes) et consommé par `PRG_04` pour l'arbitrage treuils / benne. |
| `PRG_03.Data.SequenceState.RequestActive` | Synoptique IHM / Diagnostic attente séquence | **Rôle clarifié** : ne sert plus de canal de commande pour `PRG_04`. Représente l'état synoptique de la séquence (en `SEMI_AUTO`, porte `instCycleSemiAuto.RequestActive` ; en `MAINT`, reflète l'intention opérateur). |
| `PRG_03.Data.SequenceState.ExpectedDirection` | Synoptique IHM / Diagnostic direction attendue | **Rôle clarifié** : direction attendue par le séquenceur ou intention courante en maintenance. |

---

## 🆕 Lot T167-B — Diagnostic StepAtFault Plongée Kobold

| Nouveau chemin | Rôle | Source d'ownership |
|---|---|---|
| `GVL_IHM.DredgingAssist.State.DiveStepAtFault` | Mémorisation de l'étape active lors de l'apparition d'un défaut en plongée (`E_DiveSearchState`) | Produit par `FB_DiveSearch.StepAtFault` $\to$ exposé par `PRG_03.Data.SequenceState.DiveStepAtFault` $\to$ projeté exclusivement dans `PRG_07_Supervision`. |

---

## 🆕 Lot T167-C — Diagnostic StepAtFault Extraction

| Nouveau chemin | Rôle | Source d'ownership |
|---|---|---|
| `GVL_IHM.DredgingAssist.State.ExtractionStepAtFault` | Mémorisation de l'étape active lors de l'apparition d'un défaut d'extraction (`E_ExtractionSequenceState`) | Produit par `FB_ExtractionSequence.StepAtFault` $\to$ exposé par `PRG_03.Data.SequenceState.ExtractionStepAtFault` $\to$ projeté exclusivement dans `PRG_07_Supervision`. |



# 🗺️ Migration Variables IHM — Chantier Persistance (Lot 1 & 2)

> 🎯 **But** : liste des chemins `GVL_IHM.*` qui ont changé pendant ce chantier, pour reparamétrer
> le mapping IHM (SCADA/pupitre). Mis à jour à chaque lot **committé** (pas avant vérification).
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
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

## 🔜 Lots à venir (pas encore de document de tâche)

- **Joystick** — split Cmd/State prévu.
- **Cycle** — split Cmd/State/Cfg prévu (contient `SetDepth_M`/`SetOffset_M`, priorité 1).

Cette section sera complétée à chaque nouveau lot committé — une seule table par domaine, jamais
de réécriture des lots déjà ✅.

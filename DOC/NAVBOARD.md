# 🧭 NAVBOARD — Conditions de mouvement

## ✅ Commun à TOUT mouvement
`Enable=1`·`EmergencyStopOk=1`·`DeadmanArmed=1`·`SafeStop=0`·`Error=0`·`PowerCutOff=0`

## ↔️ Translation M3

| Action | ✅=1 | ❌=0 | 👉 détail |
|--------|------|------|-----------|
| Avancer | `StartStop`·`Dir=+1` | `TargetReached`·`ArrivalLock`·`LimitSwitchFwd` | cible Trémie=1 |
| Reculer | `StartStop`·`Dir=-1` | `LimitSwitchRev`·`TargetReached`·`ArrivalLock` | cible P2/P1/Maint |
| Frein serré | `BrakeCmd=0` par `StartStop=0` ou `SafeStop=1` | — | rampe decel normale/rapide |

## 🪣 Treuils M1/M2

| Action | ✅=1 | ❌=0 |
|--------|------|------|
| Descendre | `StartStop`·`Dir=+1` | `CableLimitDescent_M`·`SpeedStep bloque`·`MecaE_SyncCritique` |
| Monter | `StartStop`·`Dir=-1` | `CableLimitAscent_M`·`MecaE_SyncCritique` |
| Frein serré | `BrakeCmd=0` par `StartStop=0`·`SafeStop=1`·`PowerCutOff=1` | — |

## 🗜️ Benne

| Action | ✅=1 | ❌=0 |
|--------|------|------|
| Fermer | `CloseReq` | `GlissementM1`·`OffsetCloseM déjà`·M2 Ascent bloqué |
| Ouvrir | `OpenReq` | `OffsetOpenM déjà`·M1/M2 différence cohérente |
| Désynchro | `OffsetCloseM>0` et M2 bouge seul | `CoherenceLimitM` |

## 🔄 Modes

| Action | ✅=1 | ❌=0 |
|--------|------|------|
| Passer SEMI_AUTO | `ModeRequest=SEMI_AUTO`·`Ready=1`·`Not Busy` | tout mouvement en cours |
| Passer MAINT_N1 | `ModeRequest=MAINT_N1`·`AU réarmé` | cycle actif |
| Réarmer défaut | `Reset=↑` (front) | `cause défaut disparue` |

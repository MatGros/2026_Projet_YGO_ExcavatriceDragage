# 🧭 NAVBOARD — Translation M3

**COMMUN (toutes actions)** : ✅`Enable`(=`PRG_06_WinchControl.StubMachineEnableN1` AND Mode≠DISABLE)·✅`PRG_00_Inputs.EmergencyStopOk`·❌`instSafetyTranslationM3.SafeStop`·❌`instTranslationM3.Error`·❌`PowerCutOff`

**Fichiers** : `PRG_07_TranslationControl`·`FB_Translation`·`FB_Safety_Translation` (instance `PRG_03_Safety.instSafetyTranslationM3`)·`FB_Translation_PositionDecoder` (instance `PRG_00_Inputs.instPositionDecoder`)·`PRG_09_Supervision` L46-61
**IHM** : `ST_TranslationHMI` → `GVL_IHM.TranslationM3`
**Animation joystick M3** : `JoystickDeflectionPct` = axe X fonctionnel signé `-100..+100 %` ; 0=neutre
**PERSISTENT** : `_TranslationMaxFreq_Hz`(60)·`_TranslationRampAccelRate_Pct`(20)·`_TranslationRampDecelNormal_Pct`(40)·`_TranslationRampDecelFast_Pct`(100)·`_TranslationAutoSpeedCap_Pct`(40)
**Reset** : `PRG_09_Supervision.FaultMachineReset_IHM` = `GVL_IHM.Modes.FaultMachineReset` OR `CmdReset` M1/M2/Bucket — ⚠️ **pas de CmdReset propre à M3**
**📎 Diagrammes** : `DOC/DIAGRAMS/CODE/DIAG_CODE_TranslationM3_HiFi.png`

---

## 🎚️ Modes réels (`E_Mode` : DISABLE=0·MAINT_N1=1·MAINT_N2=2·SEMI_AUTO=3)

`MAINT_N1` et `MAINT_N2` sont les **modes manuels** ; aucun libellé d'énumération `MANUAL` séparé.

**🔄 SEMI_AUTO** — cycle choisit la cible, sens automatique, opérateur valide au joystick
- Cible : `PRG_05_Cycle.instCycle.CmdTranslationM3_Target` (1=Trémie→Dir+1 ; 2/3/4→Dir-1)
- Vitesse : `MIN(_TranslationAutoSpeedCap_Pct, ABS(AxisCmdX.SpeedRef))` — **MIN(40%, déflexion)**, pas un produit
- ✅ `instCycle.CmdTranslationM3_Start`·`FB_Joystick_0.DeadmanArmed`·`FB_Joystick_0.AxisCmdX.StartStop`
- ⚠️ `TranslationPosPV` (SlowdownSensor) ralentit si Dir=+1

**🎮 MAINT_N1/N2 — boutons IHM** (`GVL_IHM.TranslationM3.JoystickSelect=FALSE`)
- Direction : `ReqFwd`(=+1) ou `ReqRev`(=-1)
- Vitesse : `FreqSetpoint_Hz` (pleine consigne opérateur, convertie en % de `_TranslationMaxFreq_Hz`)
- ✅ `DeadmanArmed`·`ReqFwd`(ou `ReqRev`)
- ❌ `AxisCmdX.StartStop` PAS nécessaire (bypass si `JoystickSelect=FALSE`)
- ✅ Sans `ReqFwd` ni `ReqRev` : direction forcée à 0 ; aucune reprise joystick implicite

**🕹️ MAINT_N1/N2 — joystick** (`GVL_IHM.TranslationM3.JoystickSelect=TRUE`)
- Direction : `AxisCmdX.Direction`
- Vitesse : `Hz = déflexion joystick (%) × FreqSetpoint_Hz` (formule : `(ABS(SpeedRef)/100) × FreqPct`, `FreqPct = FreqSetpoint_Hz/_TranslationMaxFreq_Hz×100`)
- ✅ `DeadmanArmed`·`AxisCmdX.StartStop`·`AxisCmdX.Direction≠0`

**🎯 MAINT_N1/N2 — sous-mode positionneur** (`GVL_IHM.TranslationM3.PositioningSelect=TRUE`)
- `SelectedTargetNum` actif : arrêt sur la cible choisie ; sens toujours choisi manuellement (boutons ou joystick)
- `PositioningSelect=FALSE` : jog libre, cible forcée à 0 ; seuls les FdC extrêmes arrêtent
- ✅ Retour IHM : `GVL_IHM.TranslationM3.PositionReached` (non mémorisé, TRUE sur cible débouncée)

**🚫 DISABLE (branche ELSE PRG_07 L89-95)** : consignes joystick recopiées MAIS `Enable=FALSE` (Mode=DISABLE) → FB neutralisé, **aucun mouvement possible**. Branche morte — ne PAS croire à un "mode manuel sans deadman".

- Cible maintenance : `SelectedTargetNum` ← `GVL_IHM.TranslationM3.SelectedTargetNum` (via `StubTranslationPositionSelect_IHM`, PRG_09 L46)

---

**🚫 Bloqueurs communs à TOUS les modes** (en plus de COMMUN)
- ❌ `instPositionDecoder.LimitSwitchFwd` (si Dir=+1)·`LimitSwitchRev` (si Dir=-1)
- ❌ `ArrivalLock` (interne FB_Translation : arrêt verrouillé sur capteur cible tant que même direction)
- ❌ `TargetReached` (capteur cible sélectionnée actif, après debounce)
- ❌ Cible 4 (Maintenance) refusée si `NOT instModes.MaintenanceM3TargetEnable` (MAINT_N2 requis)
- ⏱️ Interlock changement de sens : `DirectionInterlockDelay` 200 ms à l'arrêt

**📌 Cibles** : 1=Trémie·2=P2·3=P1·4=Maintenance·PV=jamais une cible (ralentissement seul, Dir=+1)
**📌 Capteurs** : `PRG_00_Inputs.TranslationPosTremie/PosPV/PosP2/PosP1/PosMaintenance` → `instPositionDecoder.SensorsWord` bit4=Trémie bit3=PV bit2=P2 bit1=P1 bit0=Maint — mots valides `11111→01111→00111→00011→00001→00000`

## 🧩 Systèmes périphériques (impact M3)

**🔬 Simulation** (`GVL_Simulation`) : bit maître `SimulationModeActive` (défaut TRUE). Device simulé = `SimulationModeActive AND NOT <Device>_IsReal` → forcé sain
- `VariateurM3_IsReal` : AC600 EtherCAT (Online/Operational forcés OK sinon)
- `ContactorFeedbackM3_IsReal` : retour frein M3 — pilote `BypassContactorCheck` (PRG_07 L140) ET `GVL_IHM.TranslationM3.BypassContactorFeedback` (PRG_09 L274)
- `BrakeThermal_IsReal` : thermique frein commun M1/M2/M3 (bit3)
- `EmergencyStopChain_IsReal` : chaîne AU (`EmergencyStopOk`)
- `PhaseRotationOk_IsReal` : rotation phases (bit2)
- `Joystick_IsReal` : bus/nœud CANopen (bit0) — ≠ `JoystickSignal_IsReal` (signal brut RawX/RawY seul)
- `IhmHeartbeat_IsReal` : heartbeat simulé par `GVL_Global.BlinkClock` si FALSE
- `TranslationPosition_IsReal` : 5 capteurs position (sinon `FB_Sim_Translation`)

**🧪 Overrides test** (`GVL_IHM.TranslationM3.Test*` → `GVL_PLC_Tests.OverrideM3*`, PRG_09 L50-61 — forcés FALSE hors `SimulationModeActive`) :
- `TestSensorsWordActive`+`TestSensorsWord` → `OverrideM3SensorsWord` (test bit7 incohérence)
- `TestAtTremie` → `OverrideM3AtTremie` (test bit6 limite)
- `TestBrakeStuckOpen` → `OverrideM3BrakeStuckOpen` (test Méca B bit4)
- `TestPhantomFreq` → `OverrideM3PhantomFreq` (test Méca A bit5)

**📡 Périphériques externes** (entrées `FB_Safety_Translation`, câblées PRG_03_Safety L164+) :
- CAN joystick : `JoystickOnline`/`JoystickOperational` (instDiagCanOpen) → bit0
- Heartbeat IHM : `instIhmHeartbeat.HeartbeatIhmOk` (timeout `IhmTimeout`=2s sans front) → bit0
- EtherCAT variateur : `DriveOnline`/`DriveOperational` (instDiagEthercat.DeviceVariateur*) → bit1
- Chaîne AU : `EmergencyStopOk=FALSE` → `SafeStop` direct (L188 : `SafeStop := Error OR NOT EmergencyStopOk`)
- Rotation phases : `PhaseRotationOk` (PRG_00_Inputs) → bit2
- Thermique frein commun : `BrakeThermalFeedback=TRUE` → bit3
- Réarmement AU : `RedundancyTestFailed`/`EmergencyArmingFailed` (PRG_10_Outputs) bloquent le réarmement → `EmergencyStopOk` reste FALSE

**📊 Sévérité** : `PowerCutOff` (bits 3-7, masque `16#00F8`) > `SafeStop` (tout bit OU `NOT EmergencyStopOk`) > pas de mouvement sans défaut (`DeadmanArmed`/`StartStop`/`ReqFwd`/`ReqRev` absents)

## 🔧 Dépannage

| Problème | Voir |
|----------|------|
| Rien (DISABLED) | `StubMachineEnableN1`·Mode=DISABLE·`EmergencyStopOk` |
| StartStop validé mais rien | `SafeStop` actif → `instSafetyTranslationM3.ErrorId` |
| Erreur directe | `instTranslationM3.ErrorId` bit0=frein·bit3=variateur (DriveStatusWord.4)·bit6=FdC |
| Bloqué sur cible | `ArrivalLock` → repartir en sens inverse |
| Positionneur n'arrête pas | `PositioningSelect=TRUE`·`SelectedTargetNum` valide·capteur cible |
| Pas assez de vitesse | `_TranslationMaxFreq_Hz`=60·`_TranslationAutoSpeedCap_Pct`=40·`FreqSetpoint_Hz` IHM |
| Défaut ne s'efface pas | Reset = front `GVL_IHM.Modes.FaultMachineReset` (pas de CmdReset M3) + cause disparue |

## 🛡️ FB_Safety_Translation — ErrorId (sorties décapsulées pour IHM)

| bit | Sortie BOOL | Défaut | Effet |
|-----|-------------|--------|-------|
| 0 | `ErrorOperatorComm` | Perte opérateur (CAN joystick OU heartbeat IHM) | SafeStop |
| 1 | `ErrorDriveComm` | Perte EtherCAT variateur | SafeStop |
| 2 | `ErrorPhaseRotation` | Rotation phases | SafeStop |
| 3 | `ErrorBrakeThermal` | Surchauffe frein commun M1/M2/M3 | SafeStop + PowerCutOff |
| 4 | `ErrorMecaB` | Méca B — variateur tourne/frein ouvert malgré ordre arrêt (>3s) | SafeStop + PowerCutOff |
| 5 | `ErrorMecaA` | Méca A — fréquence >0.5 Hz à l'arrêt (>1s) | SafeStop + PowerCutOff |
| 6 | `ErrorLimitSwitch` | Fin de course extrême | SafeStop + PowerCutOff |
| 7 | `ErrorSensorIncoherent` | Mot capteurs hors progression valide | SafeStop + PowerCutOff |

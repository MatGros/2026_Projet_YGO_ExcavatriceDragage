# 🧭 NAVBOARD — Translation M3

**COMMUN** : ✅Enable·✅ESOk·❌SafeStop·❌Error·❌PwrCutOff·❌ModeDISABLE

**Fichiers** : `PRG_07_TranslationControl`·`FB_Translation`·`FB_Safety_Translation`·`FB_Translation_PositionDecoder`·`PRG_09_Supervision` §9
**IHM** : `ST_TranslationHMI` → `GVL_IHM.TranslationM3`
**PERSISTENT** : `_TranslationMaxFreq_Hz`·`_TranslationRamp*_Pct`·`_TranslationAutoSpeedCap_Pct`
**📎 Diagrammes** : `DOC/DIAGRAMS/CODE/DIAG_CODE_TranslationM3_HiFi.png`

---

**🔄 SEMI_AUTO** — cycle choisit la cible, sens automatique, opérateur valide au joystick
- Cible depuis `PRG_05_Cycle.instCycle.CmdTranslationM3_Target`
- Direction : cible=1(Trémie) → +1, cible={2,3,4} → -1
- Vitesse plafonnée à `_TranslationAutoSpeedCap_Pct` (40%) × déflexion joystick
- ✅ `CmdCycleStart`·`DeadmanArmed`·`AxisCmdX.StartStop`
- ❌ capteur cible déjà atteint·⚠️ PV ralentit si Dir=+1

**🎮 MAINT_N1/N2 — boutons IHM** (`JoystickSelect=FALSE`)
- Direction par `ReqFwd`(=+1) ou `ReqRev`(=-1)
- Vitesse = `FreqSetpoint_Hz` (100% de la consigne opérateur)
- ✅ `DeadmanArmed`·`ReqFwd`(ou `ReqRev`)·direction≠0
- ❌ `AxisCmdX.StartStop` PAS nécessaire

**🕹️ MAINT_N1/N2 — joystick** (`JoystickSelect=TRUE`)
- Direction depuis joystick axe X
- Vitesse = déflexion joystick (%) × `FreqSetpoint_Hz` × `_TranslationMaxFreq_Hz`
- ✅ `DeadmanArmed`·`AxisCmdX.StartStop`·`AxisCmdX.Direction≠0`

**🕹️ MANUAL** — joystick direct, pas de deadman
- Direction + vitesse depuis joystick (brut)
- ✅ `AxisCmdX.StartStop`·`AxisCmdX.Direction≠0`
- ❌ **pas de DeadmanArmed** (contrôle direct)

---

**🚫 Bloqueurs communs à TOUS les modes** (en plus de COMMUN)
- ❌ `LimitSwitchFwd` (si Dir=+1)·`LimitSwitchRev` (si Dir=-1)
- ❌ `ArrivalLock` (capteur cible verrouillé)
- ❌ `TargetReached` (cible déjà atteinte)
- ❌ Cible 4 (Maintenance) si pas MAINT_N2

**📌 Positions cibles** : 1=Trémie·2=P2·3=P1·4=Maintenance·PV=jamais une cible (ralentissement seul)
**📌 Capteurs** : `SensorsWord` bit4=Trémie bit3=PV bit2=P2 bit1=P1 bit0=Maint — mots valides `11111→01111→00111→00011→00001→00000`

## 🔧 Dépannage

| Problème | Voir |
|----------|------|
| Rien (DISABLED) | Enable/ESOk/Deadman manquants |
| StartStop validé mais rien | `SafeStop` actif → `FB_Safety_Translation.ErrorId` |
| Erreur directe | `FB_Translation.ErrorId` bit0=frein·bit3=variateur·bit6=FdC |
| Bloqué sur cible | `ArrivalLock` → repartir en sens inverse |
| Pas assez de vitesse | `_TranslationMaxFreq_Hz`=60Hz·`_TranslationAutoSpeedCap_Pct`=40% |

## 🛡️ FB_Safety_Translation — ErrorId

| bit | Défaut | Effet |
|-----|--------|-------|
| 0 | Perte opérateur (CAN joystick ou heartbeat IHM) | SafeStop |
| 1 | Perte EtherCAT variateur | SafeStop |
| 2 | Rotation phases | SafeStop |
| 3 | Surchauffe frein commun M1/M2/M3 | SafeStop + PwrCutOff |
| 4 | Méca B — incohérence arrêt (variateur tourne/frein ouvert malgré ordre arrêt) | SafeStop + PwrCutOff |
| 5 | Méca A — mouvement non commandé (fréquence >0.5Hz à l'arrêt) | SafeStop + PwrCutOff |
| 6 | Fin de course extrême | SafeStop + PwrCutOff |
| 7 | Incohérence mot capteurs position (hors progression valide) | SafeStop + PwrCutOff |

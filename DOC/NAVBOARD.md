# 🧭 NAVBOARD — Translation M3

**Fichiers** : `PRG_07_TranslationControl` · `FB_Translation` · `FB_Safety_Translation` · `FB_Translation_PositionDecoder`
**IHM** : `ST_TranslationHMI` → `GVL_IHM.TranslationM3`
**PERSISTENT** : `_TranslationMaxFreq_Hz`·`_TranslationRampAccelRate_Pct`·`_TranslationRampDecelNormal_Pct`·`_TranslationRampDecelFast_Pct`·`_TranslationAutoSpeedCap_Pct`
**📎 Diagrammes** : `DOC/DIAGRAMS/CODE/DIAG_CODE_TranslationM3_HiFi.png`

## ✅ Avancer / Reculer

**COMMUN** (toujours avant) : ✅Enable·✅ESOk·✅Deadman·❌SafeStop·❌Error·❌PwrCutOff·❌ModeDISABLE

**Avancer** (vers Trémie) : ✅StartStop·✅Dir=1·✅ModeOK  ❌LimitFwd·❌ArrivalLock·❌TargetReached·❌MaintTargetBlocked
**Reculer** (vers P2/P1/Maint) : ✅StartStop·✅Dir=-1·✅ModeOK  ❌LimitRev·❌ArrivalLock·❌TargetReached·❌MaintTargetBlocked

## 🔧 Commissioning — si ça bouge pas

| Problème | Vérifier |
|----------|----------|
| Rien ne se passe | `GVL_IHM.TranslationM3.FBState` = DISABLED ? → Enable/ESOk/Deadman manquants |
| StartStop validé mais pas de mouvement | `SafeStop` = 1 ? → Regarder `FB_Safety_Translation.ErrorId` |
| Défaut direct | `FB_Translation.ErrorId` → bit0=frein, bit3=variateur, bit6=FdC |
| Arrivé sur cible et bloqué | `ArrivalLock` actif → remettre en marche arrière pour dégager |
| Vitesse max trop faible | `_TranslationMaxFreq_Hz` (60 Hz) / `DriveFreqScaleMaxHz` = 60 |
| Ralentissement trop tôt / trop tard | `ApproachSpeedPct` (20%) / capteur PV en ligne ? |

## 📡 Capteurs position M3

Mot des 5 capteurs : `SensorsWord` (BYTE) : bit4=Trémie bit3=PV bit2=P2 bit1=P1 bit0=Maint
Mots valides (progression monotone) : `11111→01111→00111→00011→00001→00000`
Toute autre combinaison = `SensorWordIncoherent` → SafeStop + PowerCutOff

## 🛡️ FB_Safety_Translation — ErrorId bits

| bit | Défaut | Effet |
|-----|--------|-------|
| 0 | Perte opérateur (joystick CAN ou heartbeat IHM) | SafeStop |
| 1 | Perte EtherCAT variateur | SafeStop |
| 2 | Rotation phases | SafeStop |
| 3 | Surchauffe frein commun | SafeStop + PowerCutOff |
| 4 | Méca B — incohérence arrêt (variateur tourne ou frein ouvert malgré arrêt) | SafeStop + PowerCutOff |
| 5 | Méca A — mouvement non commandé (fréquence > 0.5 Hz à l'arrêt) | SafeStop + PowerCutOff |
| 6 | Fin de course extrême | SafeStop + PowerCutOff |
| 7 | Incohérence mot capteurs position | SafeStop + PowerCutOff |

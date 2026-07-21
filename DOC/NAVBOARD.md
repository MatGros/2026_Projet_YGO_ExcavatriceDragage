# 🧭 NAVBOARD

**Commun** ☐ `Enable·ESOk·Deadman=1  /  SafeStop·Error·PowerCutOff=0`

## ↔️ M3
☐ **Avancer** → ✅ `StartStop·Dir=+1`  ❌ `LimitFwd·ArrivalLock·TargetReached`
☐ **Reculer** → ✅ `StartStop·Dir=-1`  ❌ `LimitRev·ArrivalLock·TargetReached`

## 🪣 M1/M2
☐ **Descendre** → ✅ `StartStop·Dir=+1`  ❌ `CableLimitDescent·SpeedStepBloque·SyncCrit`
☐ **Monter** → ✅ `StartStop·Dir=-1`  ❌ `CableLimitAscent·SyncCrit`

## 🗜️ Benne
☐ **Fermer** → ✅ `CloseReq`  ❌ `GlissementM1·OffsetDeja·M2AscentBloque`
☐ **Ouvrir** → ✅ `OpenReq`  ❌ `OffsetDeja·Coherence`

## 🔄 Modes
☐ **→SEMI_AUTO** → ✅ `ModeRequest=SEMI_AUTO·Ready`  ❌ `Busy·mouvement en cours`
☐ **→MAINT_N1** → ✅ `ModeRequest=MAINT_N1·AU réarmé`  ❌ `cycle actif`
☐ **Réarmer** → ✅ `Reset↑(front)`  ❌ `cause défaut pas disparue`

# 🧭 NAVBOARD
COMMUN: ✅Enable·ESOk·Deadman ❌SafeStop·Error·PowerCutOff

M3 Avancer: ✅StartStop·Dir=1 ❌LimitFwd·ArrivalLock·TargetReached
M3 Reculer: ✅StartStop·Dir=-1 ❌LimitRev·ArrivalLock·TargetReached

M1/M2 Descendre: ✅StartStop·Dir=1 ❌CableLimitDescent·SpeedStepBloque·SyncCrit
M1/M2 Monter:    ✅StartStop·Dir=-1 ❌CableLimitAscent·SyncCrit

Benne Fermer: ✅CloseReq ❌GlissementM1·OffsetDeja·M2AscentBloque
Benne Ouvrir: ✅OpenReq ❌OffsetDeja·Coherence

→SEMI_AUTO: ✅ModeRequest=SEMI_AUTO·Ready ❌Busy·mouvement
→MAINT_N1:  ✅ModeRequest=MAINT_N1·AURearme ❌cycle actif
Réarmer:    ✅Reset↑(front) ❌causeDefautPresente

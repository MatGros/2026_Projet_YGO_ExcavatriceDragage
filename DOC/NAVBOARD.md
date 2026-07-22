# 🧭 NAVBOARD

COMMUN: ✅Enable·✅ESOk·✅Deadman  ❌SafeStop·❌Error·❌PwrCutOff·❌ModeDISABLE·❌Inhibit

↔️ M3 Avancer: ✅StartStop·✅Dir=1·✅ModeOK  ❌LimitFwd·❌ArrivalLock·❌TargetReached·❌MaintTarget
↔️ M3 Reculer: ✅StartStop·✅Dir=-1·✅ModeOK ❌LimitRev·❌ArrivalLock·❌TargetReached·❌MaintTarget

🪣 M1 Descendre: ✅StartStop·✅Dir=1·✅Homed·✅Jsy{1,3}  ❌ForbidDescent·❌CableDescent·❌LimitLegal·❌StepMax·❌BenneBusy·❌SyncBlkDn·❌EncoderKO
🪣 M1 Monter:    ✅StartStop·✅Dir=-1·✅Homed·✅Jsy{1,3} ❌ForbidAscent·❌CableAscent·❌HomingTarget·❌BenneBusy·❌SyncBlkUp·❌EncoderKO

🪣 M2 Descendre: ✅StartStop·✅Dir=-1·✅Homed·✅Jsy{2,3} ❌ForbidDescent·❌CableDescent·❌LimitLegal·❌StepMax·❌BenneBusy·❌SyncBlkUp·❌EncoderKO
🪣 M2 Monter:    ✅StartStop·✅Dir=1·✅Homed·✅Jsy{2,3}  ❌ForbidAscent·❌CableAscent·❌HomingTarget·❌M2Shift·❌BenneBusy·❌SyncBlkDn·❌EncoderKO

🗜️ Benne Fermer: ✅CloseReq·✅JsySS·✅JsyDir=1·✅Homed  ❌M1Busy·❌M2Busy·❌Incoherent·❌Timeout·❌Limites·❌Glissement·❌EncoderKO
🗜️ Benne Ouvrir: ✅OpenReq·✅JsySS·✅JsyDir=-1·✅Homed  ❌M1Busy·❌M2Busy·❌Incoherent·❌Timeout·❌Limites·❌Glissement·❌EncoderKO

🔄 →SEMI_AUTO: ✅ModeReq=SA·✅Ready·✅ESOk  ❌EncoderFault·❌Busy
🔄 →MAINT_N1:  ✅ModeReq=N1·✅Ready·✅ESOk  ❌Busy·❌cycle
🔄 →MAINT_N2:  ✅ModeReq=N2·✅Ready·✅ESOk  ❌Busy
🔄 Réarmer:    ✅frontReset  ❌causeDefaut

📌 Jsy{1,3}=JoystickWinchSelect {1,3}M1/{2,3}M2 · SyncBlk=écart synchro directionnel
📌 M2Shift=butée+OffsetCloseM · LimitLegal=_LimitLegalEnabled+pos≤_LimitLegalDepthMinAllowed
📌 EncoderKO=!Available ou !Homed/HomingSuspect · Incoherent=StateIncoherent/ErrorId.3

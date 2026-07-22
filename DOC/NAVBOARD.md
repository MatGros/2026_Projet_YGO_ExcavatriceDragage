# 🧭 NAVBOARD — Conditions de mouvement

COMMUN: ✅Enable·ESOk·Deadman·!SafeStop·!Error·!PwrCutOff·!ModeDISABLE·!Inhibit

↔️ M3 Avancer: ✅StartStop·Dir=+1·ModeOK ❌LimitFwd·ArrivalLock·TargetReached·!MaintTarget
↔️ M3 Reculer: ✅StartStop·Dir=-1·ModeOK ❌LimitRev·ArrivalLock·TargetReached·!MaintTarget

🪣 M1 Descendre: ✅StartStop·Dir=+1·Homed·Jsy{1,3}·!BenneBusy·!SyncBlkDn ❌ForbidDescent·CableLimDescent·LimitLegal·SpeedStepMax·EncoderKO
🪣 M1 Monter:    ✅StartStop·Dir=-1·Homed·Jsy{1,3}·!BenneBusy·!SyncBlkUp ❌ForbidAscent·CableLimAscent·HomingTarget·EncoderKO

🪣 M2 Descendre: ✅StartStop·Dir=-1·Homed·Jsy{2,3}·!BenneBusy·!SyncBlkUp ❌ForbidDescent·CableLimDescent·LimitLegal·SpeedStepMax·EncoderKO
🪣 M2 Monter:    ✅StartStop·Dir=+1·Homed·Jsy{2,3}·!BenneBusy·!SyncBlkDn ❌ForbidAscent·CableLimAscent·HomingTarget·M2Shift·EncoderKO

🗜️ Benne Fermer: ✅CloseReq·JsySS·JsyDir=+1·!M1Busy·!M2Busy·Homed·!Incoherent·!Confirm ❌Timeout·Limites·Glissement·EncoderKO
🗜️ Benne Ouvrir: ✅OpenReq·JsySS·JsyDir=-1·!M1Busy·!M2Busy·Homed·!Incoherent·!Confirm ❌Timeout·Limites·Glissement·EncoderKO

🔄 →SEMI_AUTO: ✅ModeRequest=SA·ESOk·!EncoderFault·Ready·!Busy·!Error ❌mouvement en cours
🔄 →MAINT_N1:  ✅ModeRequest=N1·ESOk·Ready·!Busy ❌cycle actif
🔄 →MAINT_N2:  ✅ModeRequest=N2·ESOk·Ready·!Busy ❌—
🔄 Réarmer:    ✅Reset↑(front)·!causeDefaut ❌causeDefaut pas disparue

📌 Jsy{1,3}=JoystickWinchSelect=1 ou 3 (M1 seul ou Couplé, forcé 3 hors N2)
📌 SyncBlk = déviation écartsynchro mineure bloquant le sens aggravant
📌 M2Shift = décalage butée M2 (benne fermé = +OffsetCloseM)
📌 LimitLegal = _LimitLegalEnabled AND CablePosM ≤ _LimitLegalDepthMinAllowed_M
📌 EncoderKO = NOT EncoderAvailable (codeur pas en ligne) OU NOT Homed/HomingSuspect
📌 Incoherent = BucketState.StateIncoherent (boot) OU ErrorId.3 (NOT Homed)
📌 Confirm = ConfirmOpen/ClosePosition actif (mais nécessite MAINT_N1/N2)

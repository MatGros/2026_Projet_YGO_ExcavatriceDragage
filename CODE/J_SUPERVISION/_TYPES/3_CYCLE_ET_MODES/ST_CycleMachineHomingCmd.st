(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleMachineHomingCmd — Commandes IHM du cycle de référencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Cycle homing machine (FB_MachineHomingCycle) — orchestré en MAINT_N2.
      Séparé de ST_CycleCmd (cycle SEMI_AUTO) et de ST_ModesCmd (modes de marche).
      Boutons momentanés uniquement ; réglages -> ST_CycleMachineHomingCfg.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleMachineHomingCmd :
STRUCT
    BtnStart          : BOOL; (* ▶️ Lancer le cycle de homing machine (MAINT_N2, front) — alternative au motif 3 appuis joystick *)
    BtnValidate       : BOOL; (* ✅ Validation depuis IHM (front) — équivaut à 1 appui du motif 3 appuis joystick *)
    BtnAbort          : BOOL; (* ⏹️ Quitter / abandonner le cycle homing (front) — retour HX0 sans mouvement *)
    TglCommissioning  : BOOL := FALSE; (* 🔧 Case mise en service : déverrouille le forçage de step (MAINT_N2). NON persisté (reset au reboot = sûr). *)
    BtnForceStepApply : BOOL; (* 🔧 Applique le forçage de step (front) — impulsion ; cible = ST_CycleMachineHomingCfg.ForceStepTarget *)
END_STRUCT
END_TYPE

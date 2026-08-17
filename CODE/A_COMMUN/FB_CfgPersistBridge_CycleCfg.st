(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_CycleCfg — Pont persistance générique pour ST_CycleCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_CycleCfg change.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_CycleCfg
VAR_IN_OUT
    Hmi     : ST_CycleCfg; (* 🖥️ ex. GVL_IHM.Cycle.Cfg *)
    Persist : ST_CycleCfg; (* 💾 ex. GVL_PERSISTENT._CycleCfgPersist *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL;
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;

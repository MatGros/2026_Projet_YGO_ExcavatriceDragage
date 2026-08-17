(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_CommunCfg — Pont persistance générique pour ST_CommunCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_CommunCfg change.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_CommunCfg
VAR_IN_OUT
    Hmi     : ST_CommunCfg; (* 🖥️ ex. GVL_IHM.Commun.Cfg *)
    Persist : ST_CommunCfg; (* 💾 ex. GVL_PERSISTENT._CommunCfgPersist *)
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

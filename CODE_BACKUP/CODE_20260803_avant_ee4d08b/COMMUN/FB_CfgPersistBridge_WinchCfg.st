(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_WinchCfg — Pont persistance générique pour ST_WinchCfg
   ───────────────────────────────────────────────────────────────
   🎯 Deux instances indépendantes : M1TreuilRetenue.Cfg et M2TreuilBenne.Cfg.
   Restaure Persist → Hmi au boot si nécessaire, puis sauvegarde Hmi → Persist.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_WinchCfg
VAR_IN_OUT
    Hmi     : ST_WinchCfg; (* 🖥️ Struct exposé à l'IHM *)
    Persist : ST_WinchCfg; (* 💾 Mémoire PERSISTENT *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL; (* 🔔 TRUE pendant le scan de restauration *)
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;

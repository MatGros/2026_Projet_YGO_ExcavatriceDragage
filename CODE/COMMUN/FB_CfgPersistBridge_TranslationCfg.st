(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_TranslationCfg — Pont persistance générique pour ST_TranslationCfg
   ───────────────────────────────────────────────────────────────
   🎯 Instance unique : TranslationM3.Cfg (un seul axe M3, contrairement à M1/M2).
   Restaure Persist → Hmi au boot si nécessaire, puis sauvegarde Hmi → Persist.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_TranslationCfg
VAR_IN_OUT
    Hmi     : ST_TranslationCfg; (* 🖥️ Struct exposé à l'IHM *)
    Persist : ST_TranslationCfg; (* 💾 Mémoire PERSISTENT *)
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

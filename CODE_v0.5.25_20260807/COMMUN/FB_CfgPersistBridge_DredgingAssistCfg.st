(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_DredgingAssistCfg — Pont IHM/persistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_DredgingAssistCfg
VAR_IN_OUT
    Hmi     : ST_DredgingAssistCfg;
    Persist : ST_DredgingAssistCfg;
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

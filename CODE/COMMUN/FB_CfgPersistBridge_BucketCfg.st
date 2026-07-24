(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_BucketCfg — Pont persistance générique pour ST_BucketCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_BucketCfg change. La copie struct-à-struct gère aussi le sous-struct imbriqué
   Config : ST_BucketConfig automatiquement (pas de traitement spécial nécessaire).
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_BucketCfg
VAR_IN_OUT
    Hmi     : ST_BucketCfg; (* 🖥️ ex. GVL_IHM.M2TreuilBenne.Bucket.Cfg *)
    Persist : ST_BucketCfg; (* 💾 ex. GVL_PERSISTENT._BucketCfgPersist *)
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

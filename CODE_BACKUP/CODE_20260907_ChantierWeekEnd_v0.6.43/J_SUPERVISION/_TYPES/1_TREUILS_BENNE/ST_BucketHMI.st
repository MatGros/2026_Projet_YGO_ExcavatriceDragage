(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_BucketHMI — Données d'échange IHM pour la benne (M2)
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Bypass , homogène avec ST_WinchHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketHMI :
STRUCT
    Cmd    : ST_BucketCmd;
    State  : ST_BucketHMIState;
    Cfg    : ST_BucketCfg;
    Bypass : ST_BypassBucket;
END_STRUCT
END_TYPE

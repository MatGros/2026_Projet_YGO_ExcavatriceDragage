(* ═══════════════════════════════════════════════════════════════
   🔄 ST_CycleHMI — Données d'échange IHM du cycle semi-automatique
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Test , homogène avec ST_WinchHMI.
   Cfg protégé par persistance GVL_PERSISTENT
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleHMI :
STRUCT
    Cmd   : ST_CycleCmd;
    State : ST_CycleState;
    Cfg   : ST_CycleCfg;
END_STRUCT
END_TYPE

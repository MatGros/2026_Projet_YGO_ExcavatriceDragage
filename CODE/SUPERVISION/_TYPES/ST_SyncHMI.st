(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_SyncHMI — Données d'échange IHM pour la synchronisation M1/M2
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Bypass (2026-07-23), homogène avec ST_WinchHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncHMI :
STRUCT
    Cmd    : ST_SyncCmd;
    State  : ST_SyncState;
    Cfg    : ST_SyncCfg;
    Bypass : ST_BypassSync;
END_STRUCT
END_TYPE

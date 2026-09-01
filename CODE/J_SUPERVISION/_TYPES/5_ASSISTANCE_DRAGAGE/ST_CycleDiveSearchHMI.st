(* ═══════════════════════════════════════════════════════════════
   🪨 ST_CycleDiveSearchHMI — Échange IHM cycle plongée (DiveSearch)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDiveSearchHMI :
STRUCT
    Cmd   : ST_CycleDiveSearchCmd;
    State : ST_CycleDiveSearchState;
    Cfg   : ST_CycleDiveSearchCfg;
END_STRUCT
END_TYPE

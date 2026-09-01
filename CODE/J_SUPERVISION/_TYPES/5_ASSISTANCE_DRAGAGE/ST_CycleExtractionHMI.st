(* ═══════════════════════════════════════════════════════════════
   🪨 ST_CycleExtractionHMI — Échange IHM cycle extraction
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleExtractionHMI :
STRUCT
    Cmd   : ST_CycleExtractionCmd;
    State : ST_CycleExtractionState;
    Cfg   : ST_CycleExtractionCfg;
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🪨 ST_CycleDumpAtTremieHMI — Échange IHM cycle vidage trémie (legacy)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDumpAtTremieHMI :
STRUCT
    Cmd   : ST_CycleDumpAtTremieCmd;
    State : ST_CycleDumpAtTremieState;
    Cfg   : ST_CycleDumpAtTremieCfg;
END_STRUCT
END_TYPE

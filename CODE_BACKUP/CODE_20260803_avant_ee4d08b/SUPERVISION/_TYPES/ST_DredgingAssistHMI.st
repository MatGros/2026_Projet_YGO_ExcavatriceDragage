(* ═══════════════════════════════════════════════════════════════
   🪨 ST_DredgingAssistHMI — Échange IHM assistants prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistHMI :
STRUCT
    Cmd   : ST_DredgingAssistCmd;
    Cfg   : ST_DredgingAssistCfg;
    State : ST_DredgingAssistState;
END_STRUCT
END_TYPE

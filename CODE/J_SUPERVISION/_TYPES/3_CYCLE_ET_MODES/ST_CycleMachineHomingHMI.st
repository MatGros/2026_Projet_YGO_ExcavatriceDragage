(* ═══════════════════════════════════════════════════════════════
   🎯 ST_CycleMachineHomingHMI — Données d'échange IHM du cycle de référencement machine
   ───────────────────────────────────────────────────────────────
   📄 Structuration Cmd / State / Cfg , homogène avec ST_CycleHMI /
      ST_CycleDiveSearchHMI / ST_CycleExtractionHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleMachineHomingHMI :
STRUCT
    Cmd   : ST_CycleMachineHomingCmd;
    State : ST_MachineHoming;      (* Image publiée du FB_MachineHomingCycle (SeqStep, Step, Instruction, Failed, ordres, …) *)
    Cfg   : ST_CycleMachineHomingCfg;
END_STRUCT
END_TYPE

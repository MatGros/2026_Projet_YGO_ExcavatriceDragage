(* =======================================================================
   📦 ST_ModesCycleInterPrg — Bus public d'autorisations et demandes de cycle
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de données globale publiée par PRG_03_Modes_Cycle
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ModesCycleInterPrg :
STRUCT
    Auth          : ST_fbModes_Autorisations; // Bus d'autorisations machine
    ReqProgram    : ST_ProgramRequest;        // Demandes programme vers PRG_04 / PRG_05
    SequenceState : ST_SequencePublicState;   // État public de la séquence
END_STRUCT
END_TYPE

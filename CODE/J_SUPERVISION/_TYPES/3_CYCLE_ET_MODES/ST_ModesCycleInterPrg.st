(* =======================================================================
   📦 ST_ModesCycleInterPrg — Bus public d'autorisations et demandes de cycle
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de données globale publiée par PRG_03_Modes_Cycle
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ModesCycleInterPrg :
STRUCT
    Auth          : ST_fbModes_Autorisations; // Bus d'autorisations machine
    WinchBothIntent : ST_WinchBothIntent;     // 🎮 Intention both continue opérateur (source unique PRG_03, TOUS modes)
    ReqProgram    : ST_ProgramRequest;        // Demandes programme vers PRG_04 / PRG_05
    SequenceState : ST_SequencePublicState;   // État public de la séquence
    // 🧩 Défaut de l'arbitre de mode (FB_Modes), forme cible ST_Fault (AF03 §3).
    // Producteur unique : FB_Modes (instancié par PRG_03_Modes_Cycle).
    // Causes : [0] refus Semi-Auto pour défaut codeur (latchée) ;
    //          [1] changement de mode refusé, treuils non à l'arrêt confirmé (live) ;
    //          [2] refus Semi-Auto pour re-homing obligatoire (latchée).
    // ⚠️ Sans cette publication, les refus de mode restaient invisibles de l'IHM :
    //    un interlock qu'on ne voit pas est un interlock qu'on contourne.
    ModesFault    : ST_Fault;                 // 🚨 Défauts d'arbitrage de mode (consommé PRG_07 → IHM)
END_STRUCT
END_TYPE

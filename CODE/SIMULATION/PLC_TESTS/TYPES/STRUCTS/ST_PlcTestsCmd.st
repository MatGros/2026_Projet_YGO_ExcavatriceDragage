// ═══════════════════════════════════════════════════════════════
// 🧪 ST_PlcTestsCmd — Commandes de pilotage du banc de validation
// ═══════════════════════════════════════════════════════════════

TYPE ST_PlcTestsCmd :
STRUCT
    RunAll        : BOOL;   // Lance tous les tests
    RunSuite      : INT;    // >0 : lance uniquement la suite N
    RunCase       : INT;    // >0 (avec RunSuite) : lance le cas N
    Abort         : BOOL;   // Abandonne le test en cours
    ClearReport   : BOOL;   // Efface les rapports de tests
END_STRUCT
END_TYPE

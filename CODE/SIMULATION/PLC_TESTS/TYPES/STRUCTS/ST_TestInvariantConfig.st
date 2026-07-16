// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestInvariantConfig — Configuration d'un invariant multi-étapes
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestInvariantConfig :
STRUCT
    Check          : ST_TestCheckConfig; // Configuration du check (Kind/sonde/valeur attendue)
    ArmAtStepId    : INT;                // Étape qui arme cet invariant
    DisarmAtStepId : INT;                // Étape qui désarme cet invariant (0 = jusqu'à la fin de la suite)
END_STRUCT
END_TYPE

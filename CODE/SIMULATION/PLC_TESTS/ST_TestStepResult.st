// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestStepResult — Résultat d'une étape de test
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestStepResult :
STRUCT
    Executed          : BOOL;             // L'étape a-t-elle été exécutée ?
    Passed            : BOOL;             // L'étape a-t-elle été validée ?
    FailReason        : E_TestFailReason; // Raison de l'échec (FAIL_NONE si OK)
    FailedCheckIdx    : INT;              // Index du check fautif (0 si aucun)
    FailedInvariantId : INT;              // Index de l'invariant violé (0 si aucun)
    Duration          : TIME;             // Durée mesurée de l'étape
    ObservedBool      : BOOL;             // Valeur observée de la sonde BOOL en échec au verdict
    ObservedDint      : DINT;             // Valeur observée de la sonde DINT en échec au verdict
    ObservedReal      : REAL;             // Valeur observée de la sonde REAL en échec au verdict
END_STRUCT
END_TYPE

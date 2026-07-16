// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestCaseConfig — Configuration d'un cas de test
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestCaseConfig :
STRUCT
    Name      : STRING(32);          // Libellé (ex. 'TC-01 Armement nominal')
    FirstStep : INT;                 // Première étape (SETUP) du cas de test
END_STRUCT
END_TYPE

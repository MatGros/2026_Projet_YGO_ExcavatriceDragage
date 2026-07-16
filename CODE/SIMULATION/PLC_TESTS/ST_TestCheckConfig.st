// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestCheckConfig — Configuration d'un check (une assertion)
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestCheckConfig :
STRUCT
    Kind         : E_TestCheckKind;  // Type de check
    Mode         : E_TestCheckMode;  // Mode d'évaluation
    ProbeIdx     : INT;              // Index de la sonde dans le tableau correspondant
    ExpectedBool : BOOL;             // Valeur attendue pour BOOL_EQUAL
    ExpectedDint : DINT;             // Valeur attendue pour DINT_EQUAL / DINT_NOT_EQUAL
    ExpectedMin  : DINT;             // Bornes pour DINT_IN_RANGE
    ExpectedMax  : DINT;
    Mask         : WORD;             // Masque pour WORD_MASK_*
    RealMin      : REAL;             // Bornes pour REAL_IN_RANGE
    RealMax      : REAL;
    StablePT     : TIME;             // Durée de stabilité requise pour CHECK_WAIT_UNTIL
END_STRUCT
END_TYPE

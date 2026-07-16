// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestCheckKind — Enumération des types de checks
// ═══════════════════════════════════════════════════════════════

TYPE E_TestCheckKind :
(
    BOOL_EQUAL     := 0,   // ProbeBool[i] = ExpectedBool
    BOOL_RISING    := 1,   // Front montant de ProbeBool[i]
    BOOL_FALLING   := 2,   // Front descendant de ProbeBool[i]
    DINT_EQUAL     := 3,   // ProbeDint[i] = ExpectedDint
    DINT_NOT_EQUAL := 4,   // ProbeDint[i] <> ExpectedDint
    DINT_IN_RANGE  := 5,   // ExpectedMin <= ProbeDint[i] <= ExpectedMax
    WORD_MASK_ALL  := 6,   // (DINT_TO_WORD(ProbeDint[i]) AND Mask) = Mask
    WORD_MASK_ANY  := 7,   // (DINT_TO_WORD(ProbeDint[i]) AND Mask) <> 0
    WORD_MASK_NONE := 8,   // (DINT_TO_WORD(ProbeDint[i]) AND Mask) = 0
    REAL_IN_RANGE  := 9    // RealMin <= ProbeReal[i] <= RealMax
);
END_TYPE

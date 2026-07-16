// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TestEdgeCounter — Comptage de fronts sur un signal
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK FB_TestEdgeCounter
VAR_INPUT
    Arm         : BOOL;
    Signal      : BOOL;
    CountRising : BOOL; // TRUE pour fronts montants, FALSE pour descendants
    ExpectedMin : DINT;
    ExpectedMax : DINT;
END_VAR
VAR_OUTPUT
    Count       : DINT;
    InRange     : BOOL;
END_VAR
VAR
    TrigRising  : R_TRIG;
    TrigFalling : F_TRIG;
END_VAR

TrigRising(CLK := Signal);
TrigFalling(CLK := Signal);

IF NOT Arm THEN
    Count := 0;
    InRange := FALSE;
    RETURN;
END_IF;

IF CountRising AND TrigRising.Q THEN
    Count := Count + 1;
ELSIF NOT CountRising AND TrigFalling.Q THEN
    Count := Count + 1;
END_IF;

InRange := (Count >= ExpectedMin AND Count <= ExpectedMax);

END_FUNCTION_BLOCK

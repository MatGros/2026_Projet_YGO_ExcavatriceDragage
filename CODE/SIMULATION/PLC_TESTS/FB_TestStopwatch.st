// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TestStopwatch — Mesure déterministe en cycles automate
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK FB_TestStopwatch
VAR_INPUT
    Arm             : BOOL;
    StartEvent      : BOOL;
    StopEvent       : BOOL;
    ExpectedMinMs   : DINT;
    ExpectedMaxMs   : DINT;
END_VAR
VAR_OUTPUT
    ElapsedMs       : DINT;
    Done            : BOOL;
    InWindow        : BOOL;
END_VAR
VAR
    StartTrig       : R_TRIG;
    StopTrig        : R_TRIG;
    Running         : BOOL;
    CycleCount      : UDINT;
END_VAR

StartTrig(CLK := StartEvent);
StopTrig(CLK := StopEvent);

IF NOT Arm THEN
    Running := FALSE;
    Done := FALSE;
    InWindow := FALSE;
    ElapsedMs := 0;
    CycleCount := 0;
    RETURN;
END_IF;

IF StartTrig.Q AND NOT Running AND NOT Done THEN
    Running := TRUE;
    CycleCount := 0;
END_IF;

IF Running THEN
    // Incrémente le compteur de cycles
    CycleCount := CycleCount + 1;
    ElapsedMs := UDINT_TO_DINT(CycleCount * INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
    
    IF StopTrig.Q THEN
        Running := FALSE;
        Done := TRUE;
        InWindow := (ElapsedMs >= ExpectedMinMs AND ElapsedMs <= ExpectedMaxMs);
    END_IF;
END_IF;

END_FUNCTION_BLOCK

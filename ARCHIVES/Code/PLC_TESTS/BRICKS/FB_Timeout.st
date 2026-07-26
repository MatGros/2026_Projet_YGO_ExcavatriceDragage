FUNCTION_BLOCK FB_Timeout
VAR_INPUT
    Active : BOOL;
    PT : TIME;
END_VAR
VAR_OUTPUT
    Elapsed : BOOL;
END_VAR
VAR
    Timer : TON;
END_VAR
// === IMPLEMENTATION ===
Timer(IN := Active, PT := PT);
Elapsed := Timer.Q;

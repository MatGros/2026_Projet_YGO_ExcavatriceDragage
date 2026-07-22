// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TestFrameworkValidation — Smoke test sûr du manager
// ───────────────────────────────────────────────────────────────
// 🎯 Étape de diagnostic volontairement minimale : valide uniquement
//    Start → Busy → Done et la publication du résultat.
// ⚠️ Aucun runtime, tableau dynamique ou fixture dans cette version.
//    Les scénarios seront réintroduits un par un après preuve CPU stable.
// ═══════════════════════════════════════════════════════════════
FUNCTION_BLOCK PUBLIC FB_TestFrameworkValidation
VAR_INPUT
    Start : BOOL;
END_VAR
VAR_OUTPUT
    Busy   : BOOL;
    Done   : BOOL;
    Result : ST_TestFrameworkResult;
END_VAR
VAR
    StartTrig : R_TRIG;
    ScanCount : INT;
END_VAR
// === IMPLEMENTATION ===
StartTrig(CLK := Start);

IF StartTrig.Q AND NOT Busy THEN
    Busy := TRUE;
    Done := FALSE;
    ScanCount := 0;
    Result.InProgress := TRUE;
    Result.AllPassed := FALSE;
    Result.AnyFailed := FALSE;
    Result.CurrentTestId := 1;
    Result.FailedTestId := 0;
    Result.TestsPassed := 0;
    Result.TestsFailed := 0;
    Result.ErrorMessage := '';
    Result.RunCounter := Result.RunCounter + 1;
END_IF;

IF Busy THEN
    ScanCount := ScanCount + 1;
    IF ScanCount >= 3 THEN
        Busy := FALSE;
        Done := TRUE;
        Result.InProgress := FALSE;
        Result.AllPassed := TRUE;
        Result.AnyFailed := FALSE;
        Result.TestsPassed := 1;
        Result.TestsFailed := 0;
    END_IF;
END_IF;

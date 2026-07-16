// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TestCheck — Évalue un check de test (10 types x 4 modes)
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK FB_TestCheck
VAR_INPUT
    Config      : ST_TestCheckConfig;
    Evaluate    : BOOL;
END_VAR
VAR_IN_OUT
    ProbeBool   : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool] OF BOOL;
    ProbeDint   : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint] OF DINT;
    ProbeReal   : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal] OF REAL;
END_VAR
VAR_OUTPUT
    Passed       : BOOL;
    Failed       : BOOL;
    Pending      : BOOL;
    FailReason   : E_TestFailReason;
    ObservedBool : BOOL;
    ObservedDint : DINT;
    ObservedReal : REAL;
END_VAR
VAR
    RisingTrig   : R_TRIG;
    FallingTrig  : F_TRIG;
    StableTimer  : TON;
    EvaluateTrig : R_TRIG;
    Cond         : BOOL;
END_VAR

// Toujours mettre à jour les triggers des sondes TOR pour ne pas rater de transition
IF Config.ProbeIdx >= 1 AND Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
    RisingTrig(CLK := ProbeBool[Config.ProbeIdx]);
    FallingTrig(CLK := ProbeBool[Config.ProbeIdx]);
ELSE
    RisingTrig(CLK := FALSE);
    FallingTrig(CLK := FALSE);
END_IF;

EvaluateTrig(CLK := Evaluate);

IF EvaluateTrig.Q THEN
    Passed := FALSE;
    Failed := FALSE;
    Pending := FALSE;
    FailReason := E_TestFailReason.FAIL_NONE;
    StableTimer(IN := FALSE);
END_IF;

// Mise à jour des valeurs observées
IF Config.ProbeIdx >= 1 THEN
    CASE Config.Kind OF
        E_TestCheckKind.BOOL_EQUAL, E_TestCheckKind.BOOL_RISING, E_TestCheckKind.BOOL_FALLING:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
                ObservedBool := ProbeBool[Config.ProbeIdx];
            END_IF;
        E_TestCheckKind.DINT_EQUAL, E_TestCheckKind.DINT_NOT_EQUAL, E_TestCheckKind.DINT_IN_RANGE,
        E_TestCheckKind.WORD_MASK_ALL, E_TestCheckKind.WORD_MASK_ANY, E_TestCheckKind.WORD_MASK_NONE:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                ObservedDint := ProbeDint[Config.ProbeIdx];
            END_IF;
        E_TestCheckKind.REAL_IN_RANGE:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeReal THEN
                ObservedReal := ProbeReal[Config.ProbeIdx];
            END_IF;
    END_CASE;
END_IF;

// Évaluation de la condition logique (Cond)
Cond := FALSE;
IF Config.ProbeIdx >= 1 THEN
    CASE Config.Kind OF
        E_TestCheckKind.BOOL_EQUAL:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
                Cond := (ObservedBool = Config.ExpectedBool);
            END_IF;
            
        E_TestCheckKind.BOOL_RISING:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
                Cond := RisingTrig.Q;
            END_IF;
            
        E_TestCheckKind.BOOL_FALLING:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
                Cond := FallingTrig.Q;
            END_IF;
            
        E_TestCheckKind.DINT_EQUAL:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := (ObservedDint = Config.ExpectedDint);
            END_IF;
            
        E_TestCheckKind.DINT_NOT_EQUAL:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := (ObservedDint <> Config.ExpectedDint);
            END_IF;
            
        E_TestCheckKind.DINT_IN_RANGE:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := (ObservedDint >= Config.ExpectedMin AND ObservedDint <= Config.ExpectedMax);
            END_IF;
            
        E_TestCheckKind.WORD_MASK_ALL:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := ((DINT_TO_WORD(ObservedDint) AND Config.Mask) = Config.Mask);
            END_IF;
            
        E_TestCheckKind.WORD_MASK_ANY:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := ((DINT_TO_WORD(ObservedDint) AND Config.Mask) <> 0);
            END_IF;
            
        E_TestCheckKind.WORD_MASK_NONE:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                Cond := ((DINT_TO_WORD(ObservedDint) AND Config.Mask) = 0);
            END_IF;
            
        E_TestCheckKind.REAL_IN_RANGE:
            IF Config.ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeReal THEN
                Cond := (ObservedReal >= Config.RealMin AND ObservedReal <= Config.RealMax);
            END_IF;
    END_CASE;
END_IF;

// Application du mode d'évaluation
IF Evaluate THEN
    CASE Config.Mode OF
        E_TestCheckMode.CHECK_INSTANT:
            IF EvaluateTrig.Q THEN
                IF Cond THEN
                    Passed := TRUE;
                    Failed := FALSE;
                    Pending := FALSE;
                ELSE
                    Passed := FALSE;
                    Failed := TRUE;
                    Pending := FALSE;
                    FailReason := E_TestFailReason.FAIL_CHECK;
                END_IF;
            END_IF;

        E_TestCheckMode.CHECK_WAIT_UNTIL:
            IF NOT Passed AND NOT Failed THEN
                StableTimer(IN := Cond, PT := Config.StablePT);
                IF StableTimer.Q THEN
                    Passed := TRUE;
                    Failed := FALSE;
                    Pending := FALSE;
                ELSE
                    Pending := TRUE;
                END_IF;
            END_IF;

        E_TestCheckMode.CHECK_INVARIANT:
            IF NOT Cond THEN
                Passed := FALSE;
                Failed := TRUE;
                Pending := FALSE;
                FailReason := E_TestFailReason.FAIL_INVARIANT;
            ELSE
                Passed := TRUE;
                Failed := FALSE;
                Pending := FALSE;
            END_IF;

        E_TestCheckMode.CHECK_NEVER_DURING:
            IF NOT Failed THEN
                IF Cond THEN
                    Passed := FALSE;
                    Failed := TRUE;
                    Pending := FALSE;
                    FailReason := E_TestFailReason.FAIL_CHECK;
                ELSE
                    Pending := TRUE;
                END_IF;
            END_IF;
    END_CASE;
ELSE
    Passed := FALSE;
    Failed := FALSE;
    Pending := FALSE;
    StableTimer(IN := FALSE);
END_IF;

END_FUNCTION_BLOCK

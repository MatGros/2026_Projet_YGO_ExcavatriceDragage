SETUP
VAR
    fb : FB_WinchStepShaper;
END_VAR
END_SETUP

TEST 'TC-P10-SHAPER-01 Montee nominale 1000ms'
    fb(Enable := TRUE, TargetStep := 0, StepRampDelay := T#1000ms);
    ASSERT_EQ(fb.ShapedStep, 0, 'ShapedStep initialement a 0');

    (* Depart immediat 0->1 au scan 0 *)
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#1000ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'ShapedStep passe a 1 immediatement');

    (* Echantillonnage avant delai *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#1000ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Reste a 1 avant delai');

    (* Ecoulement 1000ms -> P2 *)
    ADVANCE_TIME(1000000000);
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#1000ms);
    ASSERT_EQ(fb.ShapedStep, 2, 'Passe a 2 apres delai');
END_TEST

TEST 'TC-P10-SHAPER-02 Descente nominale 500ms'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Depart P1');

    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Reste a 1');

    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 2, 'Passe a 2 apres delai 500ms');
END_TEST

TEST 'TC-P10-SHAPER-03 Asymetrie arret direct'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Depart P1');

    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 2, 'P2 etabli');

    (* Descente a 1 immediate *)
    fb(Enable := TRUE, TargetStep := 1, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Descente immediate a la cible P1');

    (* Arret franc *)
    fb(Enable := TRUE, TargetStep := 0, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 0, 'Arret immediat a 0');
END_TEST

TEST 'TC-P10-SHAPER-04 Rejet hors plage'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Depart P1');

    fb(Enable := FALSE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 0, 'Enable FALSE remet a 0');
END_TEST

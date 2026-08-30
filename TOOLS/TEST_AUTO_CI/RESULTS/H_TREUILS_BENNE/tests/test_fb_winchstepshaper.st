(* =======================================================================
   test_fb_winchstepshaper.st — T181-18 D11 : macro TC FB_WinchStepShaper
   ======================================================================= *)

SETUP
VAR
    fb : FB_WinchStepShaper;
END_VAR
END_SETUP

TEST 'TC-P10-T181-18a Depart immediat 0 vers 1'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'ShapedStep passe a 1 immediatement');
END_TEST

TEST 'TC-P10-T181-18b Montee 1 vers 2 seulement apres StepRampDelay'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Depart immediat a 1');
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Reste a 1 avant le delai');
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 2, 'Passe a 2 apres le delai');
END_TEST

TEST 'TC-P10-T181-18c Descente immediate : aucune rampe descendante'
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#0ms);   (* 0 -> 1 *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#0ms);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, TargetStep := 5, StepRampDelay := T#0ms);
    (* Au moins un cran depasse : on demande maintenant la descente franche *)
    fb(Enable := TRUE, TargetStep := 1, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Descente immediate a la cible (aucune tempo descendante)');
END_TEST

TEST 'TC-P10-T181-18d Enable FALSE force le palier 0'
    fb(Enable := TRUE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 1, 'Depart');
    fb(Enable := FALSE, TargetStep := 2, StepRampDelay := T#500ms);
    ASSERT_EQ(fb.ShapedStep, 0, 'Enable FALSE remet a 0');
END_TEST

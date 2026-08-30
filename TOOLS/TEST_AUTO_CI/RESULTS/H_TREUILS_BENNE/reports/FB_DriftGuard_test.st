(* =======================================================================
   test_fb_driftguard.st — T181-18 D11 : macro TC FB_DriftGuard
   ======================================================================= *)

SETUP
VAR
    fb : FB_DriftGuard;
END_VAR
END_SETUP

TEST 'TC-P10-T181-18a Armement capture la position de reference'
    fb(Arm := FALSE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 10.0, ToleranceM := 1.0);
    ASSERT_EQ(fb.RefPosM, 10.0, 'Reference capturee');
    ASSERT_EQ(fb.DriftM, 0.0, 'Derive nulle a la capture');
    ASSERT_FALSE(fb.Violation, 'Pas de violation');
END_TEST

TEST 'TC-P10-T181-18b Derive sous tolerance : pas de violation'
    fb(Arm := FALSE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 10.5, ToleranceM := 1.0);
    ASSERT_EQ(fb.DriftM, 0.5, 'Derive = 0.5 m');
    ASSERT_FALSE(fb.Violation, 'Sous tolerance');
END_TEST

TEST 'TC-P10-T181-18c Derive au-dela de la tolerance : violation'
    fb(Arm := FALSE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 11.2, ToleranceM := 1.0);
    ASSERT_TRUE(fb.Violation, 'Violation detectee au-dela de 1.0 m');
END_TEST

TEST 'TC-P10-T181-18d Desarmement puis rearmement : nouvelle reference'
    fb(Arm := FALSE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := TRUE, PositionM := 10.0, ToleranceM := 1.0);
    fb(Arm := FALSE, PositionM := 20.0, ToleranceM := 1.0);
    ASSERT_EQ(fb.DriftM, 0.0, 'Desarme : derive remise a zero');
    ASSERT_FALSE(fb.Violation, 'Desarme : pas de violation');
    fb(Arm := TRUE, PositionM := 20.0, ToleranceM := 1.0);
    ASSERT_EQ(fb.RefPosM, 20.0, 'Nouvelle reference a 20.0 m');
END_TEST

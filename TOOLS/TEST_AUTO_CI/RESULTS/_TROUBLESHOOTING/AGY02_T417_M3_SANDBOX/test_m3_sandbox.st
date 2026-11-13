SETUP
VAR
    FB : FB_TestHarnessT417_M3;
    RawPosM1 : UDINT := 0;
    RawPosM2 : UDINT := 0;
END_VAR
END_SETUP

TEST 'SANDBOX-M3-01 Approche Manu vers Tremie (baseline simu)'
VAR
    i : INT;
END_VAR
    FOR i := 1 TO 320 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, SimM3Slope_Mps2 := 0.0, BenneDone := FALSE, BenneIsOpen := FALSE);
    END_FOR;
    ASSERT_NEAR(FB.M3PositionTrue_M, 5.0, 0.05, 'Depart P1');

    (* Deplacement vers Tremie en Manu (JoystickLeft) *)
    FOR i := 1 TO 1200 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, JoystickLeft := TRUE, SimM3Slope_Mps2 := 0.0, BenneDone := FALSE, BenneIsOpen := FALSE);
    END_FOR;
    ASSERT_TRUE(FB.M3AtTremie, 'Capteur Tremie atteint');
    ASSERT_GT(FB.M3PositionTrue_M, -0.45, 'Simu actuelle s arrete avant la butee mecanique -0.50m');
END_TEST

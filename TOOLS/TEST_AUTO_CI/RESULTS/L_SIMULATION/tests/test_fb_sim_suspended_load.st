TEST 'TC-T300-MEC-010 Charge au repos ne cree pas d energie'
VAR
    fb : FB_Sim_SuspendedLoad;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.CycleTime_S := 0.01;
    FOR i := 1 TO 6000 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.Angle_Rad, 0.0, 'Angle nul sans excitation pendant 60 s');
    ASSERT_EQ(fb.AngularVelocity_RadPerS, 0.0, 'Vitesse angulaire nulle sans excitation');
END_TEST

TEST 'TC-T300-MEC-040 Acceleration excite charge et reaction reste conditionnee au frein'
VAR
    fb : FB_Sim_SuspendedLoad;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.CartAcceleration_Mps2 := 1.0;
    fb.BrakeMechanicallyOpen := FALSE;
    fb.CycleTime_S := 0.01;
    fb();
    ASSERT_TRUE(ABS(fb.Angle_Rad) > 0.0, 'Acceleration excite le pendule');
    ASSERT_EQ(fb.VelocityReaction_Mps, 0.0, 'Frein serre bloque reaction chariot');
    fb.BrakeMechanicallyOpen := TRUE;
    fb.CartAcceleration_Mps2 := 0.0;
    FOR i := 1 TO 10 DO
        fb();
    END_FOR;
    ASSERT_TRUE(ABS(fb.VelocityReaction_Mps) > 0.0, 'Frein ouvert publie reaction charge');
END_TEST

TEST 'TC-T300-MEC-020 Convergence pendule entre pas 10 ms et 5 ms'
VAR
    fb10 : FB_Sim_SuspendedLoad;
    fb5 : FB_Sim_SuspendedLoad;
    i : INT;
END_VAR
    fb10.Enable := TRUE;
    fb10.BrakeMechanicallyOpen := TRUE;
    fb10.CartAcceleration_Mps2 := 1.0;
    fb10.CycleTime_S := 0.01;
    fb5.Enable := TRUE;
    fb5.BrakeMechanicallyOpen := TRUE;
    fb5.CartAcceleration_Mps2 := 1.0;
    fb5.CycleTime_S := 0.005;
    fb10();
    fb5();
    fb5();
    fb10.CartAcceleration_Mps2 := 0.0;
    fb5.CartAcceleration_Mps2 := 0.0;
    FOR i := 1 TO 100 DO
        fb10();
        fb5();
        fb5();
    END_FOR;
    ASSERT_LT(ABS(fb10.Angle_Rad - fb5.Angle_Rad), 0.01,
        'Ecart angle inferieur a 10 mrad apres 1 s');
    ASSERT_LT(ABS(fb10.VelocityReaction_Mps - fb5.VelocityReaction_Mps), 0.001,
        'Ecart reaction inferieur a 1 mm/s apres 1 s');
END_TEST

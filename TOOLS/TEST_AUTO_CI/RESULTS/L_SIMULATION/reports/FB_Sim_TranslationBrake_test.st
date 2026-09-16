TEST 'TC-T300-BRK-010 Bobine mecanique et contact restent distincts'
VAR
    fb : FB_Sim_TranslationBrake;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReleaseCmd := TRUE;
    fb.OpenDelay_S := 0.10;
    fb.ContactDelay_S := 0.01;
    fb.CycleTime_S := 0.01;
    FOR i := 1 TO 9 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.CoilEnergized, 'Bobine immediate');
    ASSERT_FALSE(fb.MechanicallyOpen, 'Effet mecanique pas avant delai');
    fb();
    fb();
    ASSERT_TRUE(fb.MechanicallyOpen, 'Ouverture mecanique apres 100 ms');
    fb();
    ASSERT_TRUE(fb.ContactOpen, 'Contact apres effet mecanique');
END_TEST

TEST 'TC-T300-BRK-020 Serrage attend vitesse nulle'
VAR
    fb : FB_Sim_TranslationBrake;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReleaseCmd := TRUE;
    fb.OpenDelay_S := 0.0;
    fb.CycleTime_S := 0.01;
    fb();
    fb.ReleaseCmd := FALSE;
    fb.ActualFrequency_Hz := 2.0;
    FOR i := 1 TO 20 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.MechanicallyOpen, 'Frein reste ouvert tant que vitesse non nulle');
    fb.ActualFrequency_Hz := 0.0;
    FOR i := 1 TO 10 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.MechanicallyOpen, 'Frein serre apres 90 ms a vitesse nulle');
END_TEST

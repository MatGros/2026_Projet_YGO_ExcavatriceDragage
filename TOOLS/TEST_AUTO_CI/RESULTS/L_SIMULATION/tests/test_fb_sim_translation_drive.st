TEST 'TC-T300-DRV-010 Drive rampe et reponse premier ordre'
VAR
    fb : FB_Sim_TranslationDrive;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.FrequencyTgt_Hz := 40.0;
    fb.CycleTime_S := 0.01;
    FOR i := 1 TO 100 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.FrequencyCmd_Hz, 19.7, 'Rampe 20 Hz/s apres 1 s');
    ASSERT_LT(fb.FrequencyCmd_Hz, 20.3, 'Rampe bornee apres 1 s');
    ASSERT_LT(fb.ActualFrequency_Hz, fb.FrequencyCmd_Hz, 'Retour derriere la consigne');
    ASSERT_TRUE(fb.Ready, 'Brique prete sous Enable');
END_TEST

TEST 'TC-T300-DRV-030 Charge reduit retour sans inverser la frequence'
VAR
    fb : FB_Sim_TranslationDrive;
    i : INT;
    unloaded_Hz : REAL;
END_VAR
    fb.Enable := TRUE;
    fb.FrequencyTgt_Hz := 40.0;
    fb.CycleTime_S := 0.01;
    FOR i := 1 TO 300 DO
        fb();
    END_FOR;
    unloaded_Hz := fb.ActualFrequency_Hz;
    fb.LoadAngularVelocity_RadPerS := 8.0;
    fb();
    ASSERT_LT(fb.ActualFrequency_Hz, unloaded_Hz, 'Droop charge visible au PDO');
    ASSERT_GE(fb.ActualFrequency_Hz, 0.0, 'Frequence jamais negative');
END_TEST

TEST 'TC-T300-DRV-050 Pas de 100 ms conserve le temps physique'
VAR
    fb : FB_Sim_TranslationDrive;
END_VAR
    fb.Enable := TRUE;
    fb.FrequencyTgt_Hz := 40.0;
    fb.AccelRate_HzPerS := 20.0;
    fb.CycleTime_S := 0.100;
    fb();
    ASSERT_NEAR(fb.FrequencyCmd_Hz, 2.0, 0.001,
        'A 100 ms, la rampe 20 Hz/s avance de 2 Hz');
    fb();
    ASSERT_NEAR(fb.FrequencyCmd_Hz, 4.0, 0.001,
        'Le deuxieme cycle conserve la meme duree physique');
END_TEST

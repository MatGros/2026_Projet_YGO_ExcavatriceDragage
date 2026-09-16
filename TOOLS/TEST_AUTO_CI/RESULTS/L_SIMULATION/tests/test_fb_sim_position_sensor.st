(* T300 - Tests unitaires du capteur cumulatif M3. *)
TEST 'TC-T300-SEN-010 Hysteresis cumulative conserve le mot thermometre'
VAR
    fb : FB_Sim_PositionSensor;
END_VAR
    fb.Enable := TRUE;
    fb.Threshold_M := 5.0;
    fb.Hysteresis_M := 0.02;
    fb.Position_M := 4.99;
    fb();
    ASSERT_TRUE(fb.ElectricalOutput, 'Position sous seuil active DI cumulative');
    fb.Position_M := 5.01;
    fb();
    ASSERT_TRUE(fb.ElectricalOutput, 'Hysteresis maintient DI dans la bande');
    fb.Position_M := 5.03;
    fb();
    ASSERT_FALSE(fb.ElectricalOutput, 'Sortie au-dessus de seuil+hysteresis');
    fb.Position_M := 4.99;
    fb();
    ASSERT_FALSE(fb.ElectricalOutput, 'Retour dans bande ne re-declenche pas');
    fb.Position_M := 4.97;
    fb();
    ASSERT_TRUE(fb.ElectricalOutput, 'Retour sous seuil-hysteresis re-declenche');
END_TEST

TEST 'TC-T300-SEN-030 Episode intermittent est borne et rejoint la position'
VAR
    fb : FB_Sim_PositionSensor;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.Threshold_M := 5.0;
    fb.Position_M := 4.0;
    fb.IntermittenceActive := TRUE;
    fb.IntermittenceDurationS := 1.0;
    fb.IntermittencePeriodS := 0.12;
    fb.CycleTimeS := 0.01;
    fb();
    fb.Position_M := 6.0;
    FOR i := 1 TO 120 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.EpisodeActive, 'Episode termine avant 1.2 s');
    ASSERT_FALSE(fb.ElectricalOutput, 'DI rejoint l etat mecanique final');
    ASSERT_GT(fb.TransitionCount, 2, 'Pertes/reprises publiees, sans front permanent');
END_TEST

TEST 'TC-T300-SEN-031 Recroisements mecaniques ne reinitialisent pas episode'
VAR
    fb : FB_Sim_PositionSensor;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.Threshold_M := 5.0;
    fb.Position_M := 4.0;
    fb.IntermittenceActive := TRUE;
    fb.IntermittenceDurationS := 1.0;
    fb.IntermittencePeriodS := 0.12;
    fb.CycleTimeS := 0.01;
    fb();
    FOR i := 1 TO 40 DO
        IF (i MOD 2) = 0 THEN
            fb.Position_M := 4.0;
        ELSE
            fb.Position_M := 6.0;
        END_IF;
        fb();
    END_FOR;
    fb.Position_M := 6.0;
    FOR i := 1 TO 70 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.EpisodeActive, 'Recroisements ne prolongent pas episode au-dela de 1 s');
    ASSERT_FALSE(fb.ElectricalOutput, 'Etat final suit dernier franchissement mecanique');
END_TEST

TEST 'TC-T300-SEN-040 Cent graines deterministes bornent la stabilisation'
VAR
    fb : FB_Sim_PositionSensor;
    i : INT;
    j : INT;
END_VAR
    FOR i := 1 TO 100 DO
        fb.Enable := FALSE;
        fb();
        fb.Enable := TRUE;
        fb.Threshold_M := 5.0;
        fb.Position_M := 4.0;
        fb.IntermittenceActive := TRUE;
        fb.IntermittenceDurationS := 1.0;
        fb.IntermittencePeriodS := 0.12;
        fb.CycleTimeS := 0.01;
        fb.ScenarioSeed := DINT_TO_UDINT(i);
        fb();
        fb.Position_M := 6.0;
        FOR j := 1 TO 120 DO
            fb();
        END_FOR;
        ASSERT_FALSE(fb.EpisodeActive, 'Chaque graine termine son episode avant 1.2 s');
        ASSERT_FALSE(fb.ElectricalOutput, 'Chaque graine rejoint la position finale');
        ASSERT_GE(fb.EpisodeTogglePeriodS, 0.084, 'Periode aleatoire >= 70 % nominal');
        ASSERT_LE(fb.EpisodeTogglePeriodS, 0.156, 'Periode aleatoire <= 130 % nominal');
    END_FOR;
END_TEST

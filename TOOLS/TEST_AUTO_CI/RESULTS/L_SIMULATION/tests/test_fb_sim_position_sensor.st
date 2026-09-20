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

(* T300 P-A / C1-C2 — profil « BLIP COURT » : excursions electriques courtes, parametrables,
   independantes du train ~1 s ci-dessus. Signatures de la trace terrain du 2026-09-04 :
   Tremie contradictoire pendant 2 echantillons a 12,24 s ; PV reactive 1 echantillon a 14,94 s.
   Grille de test = 100 ms, celle de la trace. *)
TEST 'TC-T300-SEN-050 Blip court : largeur parametrable, deux sens, profil 1 s intact'
VAR
    fb : FB_Sim_PositionSensor;
    i : INT;
    excursions : INT;
    baseCount : UDINT;
END_VAR
    (* ---- (1) Sortie de zone, excursion 0,1 s => 1 echantillon (signature PV) ---- *)
    fb.Enable := TRUE;
    fb.Threshold_M := 5.0;
    fb.Hysteresis_M := 0.02;
    fb.CycleTimeS := 0.1;
    fb.ElectricalDelayS := 0.0;
    fb.Position_M := 4.0;
    fb();
    ASSERT_TRUE(fb.ElectricalOutput, 'Depart : dans la zone capteur');
    baseCount := fb.TransitionCount;
    fb.BlipTransitions := 1;
    fb.BlipDurationS := 0.1;
    fb.Position_M := 6.0;
    fb();
    excursions := 0;
    FOR i := 1 TO 6 DO
        fb();
        IF fb.ElectricalOutput <> fb.RawDetected THEN
            excursions := excursions + 1;
        END_IF;
    END_FOR;
    ASSERT_EQ(excursions, 1, 'Blip 0,1 s a 100 ms = 1 echantillon contradictoire');
    ASSERT_EQ(fb.TransitionCount - baseCount, 3, '1 front nominal + 2 fronts du blip');
    ASSERT_FALSE(fb.BlipActive, 'Blip borne et termine');
    ASSERT_FALSE(fb.ElectricalOutput, 'Sortie rendue a l etat mecanique final');

    (* ---- (2) Meme sens, excursion 0,2 s => 2 echantillons (signature Tremie) ---- *)
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.BlipTransitions := 1;
    fb.BlipDurationS := 0.2;
    fb.Position_M := 4.0;
    fb();
    fb.Position_M := 6.0;
    fb();
    excursions := 0;
    FOR i := 1 TO 8 DO
        fb();
        IF fb.ElectricalOutput <> fb.RawDetected THEN
            excursions := excursions + 1;
        END_IF;
    END_FOR;
    ASSERT_EQ(excursions, 2, 'Blip 0,2 s a 100 ms = 2 echantillons contradictoires');
    ASSERT_FALSE(fb.ElectricalOutput, 'Sortie rendue a l etat mecanique final');

    (* ---- (3) Sens INVERSE : entree en zone (front montant) — symetrie AC5 ---- *)
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.BlipTransitions := 1;
    fb.BlipDurationS := 0.2;
    fb.Position_M := 6.0;
    fb();
    ASSERT_FALSE(fb.ElectricalOutput, 'Depart : hors zone capteur');
    fb.Position_M := 4.0;
    fb();
    excursions := 0;
    FOR i := 1 TO 8 DO
        fb();
        IF fb.ElectricalOutput <> fb.RawDetected THEN
            excursions := excursions + 1;
        END_IF;
    END_FOR;
    ASSERT_EQ(excursions, 2, 'Symetrie : excursion equivalente a l entree en zone');
    ASSERT_TRUE(fb.ElectricalOutput, 'Sortie rendue a l etat mecanique final (dans la zone)');

    (* ---- (4) Blip DESACTIVE : le profil historique reste strictement inchange ---- *)
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.BlipTransitions := 0;
    fb.Position_M := 4.0;
    fb();
    baseCount := fb.TransitionCount;
    fb.Position_M := 6.0;
    fb();
    excursions := 0;
    FOR i := 1 TO 10 DO
        fb();
        IF fb.ElectricalOutput <> fb.RawDetected THEN
            excursions := excursions + 1;
        END_IF;
    END_FOR;
    ASSERT_EQ(excursions, 0, 'Blip desactive : aucune excursion inventee');
    ASSERT_EQ(fb.TransitionCount - baseCount, 1, 'Blip desactive : seul le front nominal');
END_TEST

(* =======================================================================
   Automated Unit Test - FB_Translation_OdometryGain (T301, contrat V2)
   -----------------------------------------------------------------------
   Gain actif = |PosP2 - PosPV| / (CalibFreq x CalibTime), repli sinon.
   Mesure PROPOSEE P2 <-> PV (jamais appliquee) dans les deux sens.
   Geometrie : PV 1,5 m, P2 3,5 m (2 m). Mot thermometre : TRUE si pos <= cote.
   dt deterministe : ADVANCE_TIME(10000000) = 10 ms avant chaque appel.
   ======================================================================= *)
TEST 'TC-T301-ODO-001 Gain actif calcule depuis le reglage site (2 m, 50 Hz, 2 s -> 0,02)'
VAR
    fb : FB_Translation_OdometryGain;
END_VAR
    fb.PosPV_M := 1.5;
    fb.PosP2_M := 3.5;
    fb.CalibFreq_Hz := 50.0;
    fb.CalibTime_S := 2.0;
    fb.FallbackGain := 0.03;
    fb();
    ASSERT_TRUE(fb.CalibValid, 'Reglage complet et plausible -> CalibValid');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.0001, '2 / (50 x 2) = 0,02');
    fb.CalibTime_S := 2.86;
    fb();
    ASSERT_NEAR(fb.GainActive, 0.014, 0.0001, '2 / (50 x 2,86) = 0,014');
END_TEST

TEST 'TC-T301-ODO-002 Reglage absent ou incoherent -> repli, jamais de division par zero'
VAR
    fb : FB_Translation_OdometryGain;
END_VAR
    fb.PosPV_M := 1.5;
    fb.PosP2_M := 3.5;
    fb.CalibFreq_Hz := 50.0;
    fb.FallbackGain := 0.02;
    fb.CalibTime_S := 0.0;
    fb();
    ASSERT_FALSE(fb.CalibValid, 'Temps 0 -> repli');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.00001, 'Temps 0 -> gain de repli');
    fb.CalibTime_S := 2.0;
    fb.CalibFreq_Hz := 0.0;
    fb();
    ASSERT_FALSE(fb.CalibValid, 'Frequence 0 -> repli');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.00001, 'Frequence 0 -> gain de repli');
    fb.CalibFreq_Hz := 50.0;
    fb.PosPV_M := 3.5;
    fb.PosP2_M := 3.5;
    fb();
    ASSERT_FALSE(fb.CalibValid, 'PV = P2 -> repli');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.00001, 'PV = P2 -> gain de repli');
    fb.PosPV_M := 1.5;
    fb.CalibTime_S := 0.2;
    fb();
    ASSERT_FALSE(fb.CalibValid, 'Gain 0,2 hors plage -> repli');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.00001, 'Gain hors plage -> gain de repli');
END_TEST

TEST 'TC-T301-ODO-003 Mesure proposee vers la Tremie : temps, frequence moyenne, gain, jamais appliquee'
VAR
    fb : FB_Translation_OdometryGain;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PosPV_M := 1.5;
    fb.PosP2_M := 3.5;
    fb.CalibFreq_Hz := 50.0;
    fb.CalibTime_S := 0.0;
    fb.FallbackGain := 0.02;
    fb.DriveActualFreq_Hz := 50.0;
    fb.SensorP2 := FALSE;
    fb.SensorPV := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorP2 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.MeasureActive, 'Front montant P2 -> mesure lancee');
    fb.SensorP2 := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorP2 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.MeasureActive, 'Rebond P2 ignore, mesure toujours en cours');
    FOR i := 1 TO 197 DO
        ADVANCE_TIME(10000000);
        fb();
    END_FOR;
    fb.SensorPV := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.MeasureActive, 'Front montant PV -> fin de mesure');
    ASSERT_NEAR(fb.MeasuredTime_S, 2.0, 0.011, 'Temps mesure ~2,0 s');
    ASSERT_NEAR(fb.MeasuredFreqAvg_Hz, 50.0, 0.01, 'Frequence moyenne 50 Hz');
    ASSERT_NEAR(fb.MeasuredFreqSpread_Hz, 0.0, 0.01, 'Vitesse constante -> ecart nul');
    ASSERT_NEAR(fb.MeasuredGain, 0.02, 0.0002, 'Gain propose 2 / (50 x 2) = 0,02');
    ASSERT_EQ(fb.MeasureCount, 1, 'Une mesure aboutie');
    ASSERT_FALSE(fb.CalibValid, 'Mesure JAMAIS appliquee : reglage toujours non saisi');
    ASSERT_NEAR(fb.GainActive, 0.02, 0.00001, 'Gain actif = repli, inchange par la mesure');
END_TEST

TEST 'TC-T301-ODO-004 Mesure proposee vers la Maintenance (PV descend puis P2 descend)'
VAR
    fb : FB_Translation_OdometryGain;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PosPV_M := 1.5;
    fb.PosP2_M := 3.5;
    fb.FallbackGain := 0.02;
    fb.DriveActualFreq_Hz := 40.0;
    fb.SensorP2 := TRUE;
    fb.SensorPV := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorPV := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.MeasureActive, 'Front descendant PV -> mesure lancee');
    FOR i := 1 TO 249 DO
        ADVANCE_TIME(10000000);
        fb();
    END_FOR;
    fb.SensorP2 := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.MeasureActive, 'Front descendant P2 -> fin');
    ASSERT_NEAR(fb.MeasuredTime_S, 2.5, 0.011, 'Temps mesure ~2,5 s');
    ASSERT_NEAR(fb.MeasuredGain, 0.02, 0.0002, 'Gain propose 2 / (40 x 2,5) = 0,02');
END_TEST

TEST 'TC-T301-ODO-005 Arret pendant la mesure -> abandon, aucun resultat publie'
VAR
    fb : FB_Translation_OdometryGain;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PosPV_M := 1.5;
    fb.PosP2_M := 3.5;
    fb.DriveActualFreq_Hz := 50.0;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorP2 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.MeasureActive, 'Mesure lancee');
    FOR i := 1 TO 50 DO
        ADVANCE_TIME(10000000);
        fb();
    END_FOR;
    fb.DriveActualFreq_Hz := 0.0;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.MeasureActive, 'Arret -> mesure abandonnee');
    ASSERT_EQ(fb.MeasureCount, 0, 'Aucune mesure aboutie');
    ASSERT_NEAR(fb.MeasuredTime_S, 0.0, 0.0001, 'Aucun resultat publie');
END_TEST

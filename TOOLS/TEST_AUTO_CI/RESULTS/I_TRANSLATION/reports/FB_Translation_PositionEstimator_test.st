(* =======================================================================
   Automated Unit Test - FB_Translation_PositionEstimator
   ======================================================================= *)
TEST 'TC-P11-EST-001 Reprise sur ColdStart avec position persistee'
VAR
    fb : FB_Translation_PositionEstimator;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 12.5;
    fb();
    ASSERT_TRUE(fb.Initialized, 'PersistedInitialized -> Initialized TRUE');
    ASSERT_EQ(fb.PositionEstimatedM, 12.5, 'ColdStart -> Position restauree a 12.5m');
END_TEST

TEST 'TC-P11-EST-002 Recalage absolu instantane sur front montant capteur P1 (20.0m)'
VAR
    fb : FB_Translation_PositionEstimator;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 18.0;
    fb();
    
    (* Franchissement capteur P1 *)
    fb.SensorP1 := TRUE;
    fb();
    ASSERT_EQ(fb.PositionEstimatedM, 20.0, 'Front SensorP1 -> Position recalee a 20.0m');
    ASSERT_TRUE(fb.Recalibrated, 'Recalage actif');
    ASSERT_EQ(fb.RecalibratedSensorId, 1, 'Id capteur P1 = 1');
END_TEST

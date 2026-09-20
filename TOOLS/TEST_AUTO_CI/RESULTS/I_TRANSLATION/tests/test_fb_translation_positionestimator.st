(* =======================================================================
   Automated Unit Test - FB_Translation_PositionEstimator
   -----------------------------------------------------------------------
   T333 : recalage dans les DEUX sens.
   Geometrie de reference (FB_Translation_PositionDecoder.st:10-12,78-88) :
   le mot des 5 capteurs est un thermometre CUMULATIF -> bit_X = TRUE ssi
   position <= cote_X. Chaque capteur bascule donc a SA cote dans les deux
   sens : front MONTANT en venant de Maintenance (trajet vers la Tremie),
   front DESCENDANT en allant vers la Maintenance.
   Cotes calibrees : Tremie 0.0 m, PV 5.0 m, P2 15.0 m, P1 20.0 m,
   Maintenance 30.0 m. Identifiants : 0=Maint, 1=P1, 2=P2, 3=PV, 4=Tremie.

   Odometrie deterministe : ADVANCE_TIME(10000000) avant chaque appel fixe
   dt = 10 ms (FB_CycleTime) ; avec la frequence 40 Hz et le gain de
   production 0.008333 m/(Hz.s), chaque scan ajoute exactement 3,33 mm.
   Toute assertion de position sur un scan de front tolere donc 0,005 m.
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

TEST 'TC-P11-EST-004 Recalage a CHAQUE capteur sur front DESCENDANT (trajet Tremie vers Maintenance)'
VAR
    fb : FB_Translation_PositionEstimator;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 0.0;
    (* Trajet vers la Maintenance : les capteurs s'ETEIGNENT un par un (fronts descendants) *)
    fb.ReqMaintenance := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.PosMaintenanceM := 30.0;
    fb.PosP1M := 20.0;
    fb.PosP2M := 15.0;
    fb.PosPVM := 5.0;
    fb.PosTremieM := 0.0;
    (* Mot thermometre au depart : 11111, chariot a la Tremie *)
    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-004 : capteurs deja actifs au 1er scan -> aucun recalage');

    (* --- Capteur Tremie (cote 0.0 m) : front descendant = depart vers la Maintenance --- *)
    fb.SensorTremie := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-004 : front DESCENDANT Tremie -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 4, 'TC-P11-EST-004 : front descendant Tremie -> id 4');
    ASSERT_NEAR(fb.PositionEstimatedM, 0.0, 0.005, 'TC-P11-EST-004 : front descendant Tremie -> position 0.0 m');

    (* Roule vers P2 : l'odometrie fait deriver l'estimation *)
    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-004 : aucun front entre deux capteurs -> pas de recalage');

    (* --- Capteur PV (cote 5.0 m) --- *)
    fb.SensorPV := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-004 : front DESCENDANT PV -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 3, 'TC-P11-EST-004 : front descendant PV -> id 3');
    ASSERT_NEAR(fb.PositionEstimatedM, 5.0, 0.005, 'TC-P11-EST-004 : front descendant PV -> position 5.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur P2 (cote 15.0 m) --- *)
    fb.SensorP2 := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-004 : front DESCENDANT P2 -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 2, 'TC-P11-EST-004 : front descendant P2 -> id 2');
    ASSERT_NEAR(fb.PositionEstimatedM, 15.0, 0.005, 'TC-P11-EST-004 : front descendant P2 -> position 15.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur P1 (cote 20.0 m) --- *)
    fb.SensorP1 := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-004 : front DESCENDANT P1 -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 1, 'TC-P11-EST-004 : front descendant P1 -> id 1');
    ASSERT_NEAR(fb.PositionEstimatedM, 20.0, 0.005, 'TC-P11-EST-004 : front descendant P1 -> position 20.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur Maintenance (cote 30.0 m) : mot thermometre 00000 --- *)
    fb.SensorMaintenance := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-004 : front DESCENDANT Maintenance -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 0, 'TC-P11-EST-004 : front descendant Maintenance -> id 0');
    ASSERT_NEAR(fb.PositionEstimatedM, 30.0, 0.005, 'TC-P11-EST-004 : front descendant Maintenance -> position 30.0 m');
END_TEST

TEST 'TC-P11-EST-005 Recalage a CHAQUE capteur sur front MONTANT (trajet Maintenance vers Tremie)'
VAR
    fb : FB_Translation_PositionEstimator;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 30.0;
    (* Trajet vers la Tremie : les capteurs s'ALLUMENT un par un (fronts montants) *)
    fb.ReqTremie := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.PosMaintenanceM := 30.0;
    fb.PosP1M := 20.0;
    fb.PosP2M := 15.0;
    fb.PosPVM := 5.0;
    fb.PosTremieM := 0.0;
    (* Mot thermometre au depart : 00000, chariot a la Maintenance *)
    fb.SensorTremie := FALSE;
    fb.SensorPV := FALSE;
    fb.SensorP2 := FALSE;
    fb.SensorP1 := FALSE;
    fb.SensorMaintenance := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-005 : capteurs absents au 1er scan -> aucun recalage');

    (* --- Capteur Maintenance (cote 30.0 m) --- *)
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-005 : front MONTANT Maintenance -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 0, 'TC-P11-EST-005 : front montant Maintenance -> id 0');
    ASSERT_NEAR(fb.PositionEstimatedM, 30.0, 0.005, 'TC-P11-EST-005 : front montant Maintenance -> position 30.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur P1 (cote 20.0 m) --- *)
    fb.SensorP1 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-005 : front MONTANT P1 -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 1, 'TC-P11-EST-005 : front montant P1 -> id 1');
    ASSERT_NEAR(fb.PositionEstimatedM, 20.0, 0.005, 'TC-P11-EST-005 : front montant P1 -> position 20.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur P2 (cote 15.0 m) --- *)
    fb.SensorP2 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-005 : front MONTANT P2 -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 2, 'TC-P11-EST-005 : front montant P2 -> id 2');
    ASSERT_NEAR(fb.PositionEstimatedM, 15.0, 0.005, 'TC-P11-EST-005 : front montant P2 -> position 15.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur PV (cote 5.0 m) --- *)
    fb.SensorPV := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-005 : front MONTANT PV -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 3, 'TC-P11-EST-005 : front montant PV -> id 3');
    ASSERT_NEAR(fb.PositionEstimatedM, 5.0, 0.005, 'TC-P11-EST-005 : front montant PV -> position 5.0 m');

    (* roule entre deux capteurs : dt nul entre deux scans -> FB_CycleTime publie
       DefaultValueS = 0.010 s, odometrie deterministe a 3,33 mm par scan *)
    FOR i := 1 TO 40 DO
        fb();
    END_FOR;

    (* --- Capteur Tremie (cote 0.0 m) : mot thermometre 11111 --- *)
    fb.SensorTremie := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-005 : front MONTANT Tremie -> Recalibrated TRUE');
    ASSERT_EQ(fb.RecalibratedSensorId, 4, 'TC-P11-EST-005 : front montant Tremie -> id 4');
    ASSERT_NEAR(fb.PositionEstimatedM, 0.0, 0.005, 'TC-P11-EST-005 : front montant Tremie -> position 0.0 m');
END_TEST

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
    fb.GainMetersPerHzSec := 0.008333;   (* gain de production pose explicitement : le test ne depend pas du defaut du FB *)
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
    fb.GainMetersPerHzSec := 0.008333;   (* gain de production pose explicitement : le test ne depend pas du defaut du FB *)
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

TEST 'TC-P11-EST-006 Continuite de la position entre deux fronts (seuil Q3 : |Freq| x Gain x dt + 1 mm)'
VAR
    fb : FB_Translation_PositionEstimator;
    prevM   : REAL;
    deltaM  : REAL;
    limitM  : REAL;
END_VAR
    (* Regle tranchee en Q3 : hors front capteur, la position ne saute jamais plus que ce que
       l'odometrie d'un scan peut produire ; un saut n'est admis que sur le scan ou
       Recalibrated=TRUE (c'est le recalage lui-meme). *)
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 0.0;
    fb.ReqMaintenance := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.GainMetersPerHzSec := 0.008333;   (* gain de production pose explicitement : le test ne depend pas du defaut du FB *)
    limitM := fb.DriveActualFreqHz * fb.GainMetersPerHzSec * 0.010 + 0.001;

    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();

    (* scan 2 : front descendant Tremie (recalage attendu, saut autorise) *)
    prevM := fb.PositionEstimatedM;
    fb.SensorTremie := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan front Tremie -> saut admis seulement si Recalibrated');

    (* scan 3 : aucun front *)
    prevM := fb.PositionEstimatedM;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan 3 sans front -> variation bornee par l odometrie');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-006 : scan 3 -> aucun recalage hors front (assertion non vacuant)');
    ASSERT_GT(deltaM, 0.0, 'TC-P11-EST-006 : scan 3 -> l odometrie progresse bien (test non tautologique)');

    (* scan 4 : aucun front *)
    prevM := fb.PositionEstimatedM;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan 4 sans front -> variation bornee');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-006 : scan 4 -> aucun recalage hors front');

    (* scan 5 : aucun front *)
    prevM := fb.PositionEstimatedM;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan 5 sans front -> variation bornee');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-006 : scan 5 -> aucun recalage hors front');

    (* scan 6 : front descendant PV (recalage a 5,0 m) *)
    prevM := fb.PositionEstimatedM;
    fb.SensorPV := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-006 : scan front PV -> Recalibrated TRUE');
    ASSERT_NEAR(fb.PositionEstimatedM, 5.0, 0.005, 'TC-P11-EST-006 : front PV -> position 5.0 m');

    (* scan 7 : aucun front *)
    prevM := fb.PositionEstimatedM;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan 7 sans front -> variation bornee');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-006 : scan 7 -> aucun recalage hors front');

    (* scan 8 : aucun front *)
    prevM := fb.PositionEstimatedM;
    ADVANCE_TIME(10000000);
    fb();
    deltaM := ABS(fb.PositionEstimatedM - prevM);
    ASSERT_TRUE((deltaM <= limitM) OR fb.Recalibrated, 'TC-P11-EST-006 : scan 8 sans front -> variation bornee');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-006 : scan 8 -> aucun recalage hors front');
END_TEST

TEST 'TC-P11-EST-007 Blip capteur court (1 scan) en s eloignant : comportement defini (decision Q2 = recaler)'
VAR
    fb : FB_Translation_PositionEstimator;
    i  : INT;
END_VAR
    (* Rejoue le cas terrain de la trace du 2026-09-04 a 12,237 s (200 ms) : la Tremie se
       reactive brievement alors que le chariot vient de partir vers la Maintenance. Decision Q2 :
       re-calibrer SANS gate (le gate de plausibilite est inexploitable avant T301, le gain
       configure etant ÷6,6 trop lent). Comportement attendu et teste : l'echantillon est ancre a
       la cote Tremie, la distance parcourue pendant le blip restant de l'ordre du centimetre, et
       la position REPART ensuite normalement (aucun blocage a 0 m).
       Meme code, meme regle en simulation et sur machine reelle : un seul chemin d'execution. *)
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 0.0;
    fb.ReqMaintenance := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.GainMetersPerHzSec := 0.008333;   (* gain de production pose explicitement : le test ne depend pas du defaut du FB *)
    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();

    (* depart de la zone Tremie (front descendant) *)
    fb.SensorTremie := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-007 : depart Tremie -> recalage');

    (* roule vers la Maintenance : ~2 cm parcourus *)
    FOR i := 1 TO 5 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.PositionEstimatedM, 0.005, 'TC-P11-EST-007 : le chariot s est bien eloigne de la cote Tremie avant le blip');
    ASSERT_FALSE(fb.Recalibrated, 'TC-P11-EST-007 : hors front -> aucun recalage');

    (* BLIP : la Tremie se reactive 1 scan, alors que le chariot s'eloigne *)
    fb.SensorTremie := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-007 : blip Tremie -> comportement defini : recaler (Q2)');
    ASSERT_EQ(fb.RecalibratedSensorId, 4, 'TC-P11-EST-007 : blip Tremie -> id 4');
    ASSERT_NEAR(fb.PositionEstimatedM, 0.0, 0.005, 'TC-P11-EST-007 : blip Tremie -> ancrage a la cote 0.0 m');

    (* fin du blip : nouveau front descendant Tremie, meme cote -> idempotent *)
    fb.SensorTremie := FALSE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-P11-EST-007 : fin de blip -> recalage a la meme cote');
    ASSERT_NEAR(fb.PositionEstimatedM, 0.0, 0.005, 'TC-P11-EST-007 : fin de blip -> toujours 0.0 m');

    (* la position repart : aucun ecrasement permanent a 0 m *)
    FOR i := 1 TO 5 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.PositionEstimatedM, 0.005, 'TC-P11-EST-007 : apres le blip la position repart vers la Maintenance');
END_TEST

(* =========================================================================
   T361 VOLET B — TEMOIN D'ANOMALIE DE RECALAGE (observer, JAMAIS bloquer)
   =========================================================================
   DECISION UTILISATEUR 2026-09-21 : 5 capteurs conserves, recalage TOUJOURS applique,
   AUCUNE zone morte (la decision Q2 du lot T333 reste la regle : recaler sans garde tant
   que T301 n'a pas calibre le gain), et un simple TEMOIN lorsque la correction depasse
   CST_RecalibrationAnomalyM = 0,50 m.
   Ces cas verrouillent les DEUX moities de l'invariant :
     - le temoin se leve quand la correction est grande (ANOM-002) ;
     - la correction est APPLIQUEE malgre le temoin (ANOM-002, position recalee) ;
     - le temoin est un PULSE, pas un latch (ANOM-003) ;
     - un petit ecart reste recale SANS temoin (ANOM-004 = scenario du blip de 2 cm,
       exactement ce qu'une bande morte aurait casse).
   Le gate G520 interdit statiquement que ce seuil devienne une condition du recalage. *)

TEST 'TC-T361-ANOM-001 Correction ordinaire sous le seuil : temoin NON leve'
VAR
    fb : FB_Translation_PositionEstimator;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 0.0;
    fb.ReqMaintenance := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.GainMetersPerHzSec := 0.008333;   (* gain pose explicitement : le cas ne depend pas du defaut *)
    fb.PosPVM := 5.0;
    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();                                 (* 1er scan utile : aucun recalage *)
    fb.SensorTremie := FALSE;             (* depart Tremie : recalage a la cote 0,0 m *)
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-T361-ANOM-001 : recalage au depart Tremie');
    ASSERT_FALSE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-001 : ecart nul -> aucun temoin');

    (* Roule jusqu'a la cote PV : 1500 scans a 3,33 mm = 4,9998 m -> l'odometrie est
       quasiment JUSTE au franchissement, c'est le regime nominal. *)
    FOR i := 1 TO 1500 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.Recalibrated, 'TC-T361-ANOM-001 : hors front -> aucun recalage');
    fb.SensorPV := FALSE;                 (* front descendant PV : cote 5,0 m *)
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-T361-ANOM-001 : recalage au franchissement PV');
    ASSERT_NEAR(fb.PositionEstimatedM, 5.0, 0.005, 'TC-T361-ANOM-001 : position recalee a 5,0 m');
    ASSERT_FALSE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-001 : correction < 0,50 m -> temoin NON leve');
    ASSERT_LT(fb.RecalibrationCorrectionM, 0.05, 'TC-T361-ANOM-001 : correction nominale ~2 mm');
END_TEST

TEST 'TC-T361-ANOM-002 Correction ANORMALE : temoin leve ET correction quand meme APPLIQUEE'
VAR
    fb : FB_Translation_PositionEstimator;
END_VAR
    (* Scenario d'incident : le gain configure est faux (cas 0,02 vs 0,0551, alerte T361), la
       position persistee est 10,0 m alors que le chariot franchit reellement P1 a 20,0 m.
       La correction vaut 10,0 m : elle doit etre APPLIQUEE (le capteur est la meilleure
       reference absolue disponible) ET SIGNALEE. Refuser la correction laisserait une
       position fausse ET non corrigee — c'est l'erreur que ce cas interdit. *)
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 10.0;
    fb.PosP1M := 20.0;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_FALSE(fb.Recalibrated, 'TC-T361-ANOM-002 : 1er scan utile -> aucun recalage');
    fb.SensorP1 := TRUE;                  (* front montant P1 *)
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-T361-ANOM-002 : recalage sur P1');
    ASSERT_NEAR(fb.PositionEstimatedM, 20.0, 0.005,
        'TC-T361-ANOM-002 : CORRECTION APPLIQUEE malgre le temoin (invariant du lot)');
    ASSERT_TRUE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-002 : ecart de 10,0 m > 0,50 m -> temoin leve');
    ASSERT_NEAR(fb.RecalibrationCorrectionM, 10.0, 0.005, 'TC-T361-ANOM-002 : amplitude publiee 10,0 m');
END_TEST

TEST 'TC-T361-ANOM-003 Le temoin est un PULSE, l amplitude est MAINTENUE'
VAR
    fb : FB_Translation_PositionEstimator;
END_VAR
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 10.0;
    fb.PosP1M := 20.0;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorP1 := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-003 : precondition : temoin leve au recalage');

    ADVANCE_TIME(10000000);
    fb();                                  (* scan suivant : aucun front *)
    ASSERT_FALSE(fb.Recalibrated, 'TC-T361-ANOM-003 : hors front -> aucun recalage');
    ASSERT_FALSE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-003 : temoin a PULSE -> retombe au scan suivant');
    ASSERT_NEAR(fb.RecalibrationCorrectionM, 10.0, 0.005,
        'TC-T361-ANOM-003 : l amplitude de la derniere correction est MAINTENUE (lecture trace/IHM)');
END_TEST

TEST 'TC-T361-ANOM-004 Blip de 2 cm : recale SANS temoin (aucune zone morte)'
VAR
    fb : FB_Translation_PositionEstimator;
    i  : INT;
END_VAR
    (* Rejoue le scenario du blip Tremie de TC-P11-EST-007 : un ecart de ~2 cm est RECALE.
       C'est la preuve qu'aucune bande morte n'a ete introduite — une bande morte a 0,05 m
       aurait supprime ce recalage et fait echouer la decision Q2 du lot T333. *)
    fb.Enable := TRUE;
    fb.PersistedInitialized := TRUE;
    fb.PersistedPositionM := 0.0;
    fb.ReqMaintenance := TRUE;
    fb.DriveActualFreqHz := 40.0;
    fb.GainMetersPerHzSec := 0.008333;
    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    ADVANCE_TIME(10000000);
    fb();
    fb.SensorTremie := FALSE;              (* depart Tremie *)
    ADVANCE_TIME(10000000);
    fb();
    FOR i := 1 TO 5 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.PositionEstimatedM, 0.005, 'TC-T361-ANOM-004 : le chariot s est eloigne avant le blip');
    fb.SensorTremie := TRUE;               (* BLIP : la Tremie se reactive 1 scan *)
    ADVANCE_TIME(10000000);
    fb();
    ASSERT_TRUE(fb.Recalibrated, 'TC-T361-ANOM-004 : blip -> recalage APPLIQUE (aucune zone morte)');
    ASSERT_NEAR(fb.PositionEstimatedM, 0.0, 0.005, 'TC-T361-ANOM-004 : ancrage a la cote Tremie');
    ASSERT_FALSE(fb.RecalibrationAnomaly, 'TC-T361-ANOM-004 : 2 cm < 0,50 m -> aucun temoin');
END_TEST

(* T300 - Tests du modele dynamique M3. *)
TEST 'TC-T300-TR-001 Etat sur desactive est P1 sans mouvement'
VAR
    fb : FB_Sim_Translation;
END_VAR
    fb.Enable := FALSE;
    fb();
    ASSERT_FALSE(fb.PosTremie, 'P1 ne doit pas annoncer Tremie');
    ASSERT_TRUE(fb.PosP1, 'Etat de repli deterministe sur P1');
    ASSERT_TRUE(fb.PosMaintenance, 'Mot thermometre P1 attendu');
    ASSERT_EQ(fb.ActualFrequency_Hz, 0.0, 'Frequence nulle');
    ASSERT_FALSE(fb.BrakeContactOpen, 'Frein ferme');
END_TEST

TEST 'TC-T300-SEN-010 Les deux extremites publient les mots thermometres valides'
VAR
    fb : FB_Sim_Translation;
    i : INT;
END_VAR
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.ReqTremie := TRUE;
    fb.SpeedTgt_Pct := 100.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb.FullTravelTimeS := 0.5;
    fb.SensorElectricalDelayS := 0.0;
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.PosTremie, 'Tremie active a la butee 0 m');
    ASSERT_TRUE(fb.PosPV, 'PV cumulatif actif a Tremie');
    ASSERT_TRUE(fb.PosP2, 'P2 cumulatif actif a Tremie');
    ASSERT_TRUE(fb.PosP1, 'P1 cumulatif actif a Tremie');
    ASSERT_TRUE(fb.PosMaintenance, 'Maintenance cumulatif actif a Tremie');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Butee Tremie absorbe la vitesse chariot');

    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.ReqTremie := FALSE;
    fb.ReqMaintenance := TRUE;
    fb.SpeedTgt_Pct := 100.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb.FullTravelTimeS := 0.5;
    fb.SensorElectricalDelayS := 0.0;
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.PosTremie, 'Tremie inactif a Maintenance');
    ASSERT_FALSE(fb.PosPV, 'PV inactif a Maintenance');
    ASSERT_FALSE(fb.PosP2, 'P2 inactif a Maintenance');
    ASSERT_FALSE(fb.PosP1, 'P1 inactif a Maintenance');
    ASSERT_FALSE(fb.PosMaintenance, 'Maintenance inactif a la butee pour mot 00000');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Butee Maintenance absorbe la vitesse chariot');
END_TEST

TEST 'TC-T300-SEN-011 Le capteur PV commute au franchissement vers Tremie'
VAR
    fb : FB_Sim_Translation;
    i : INT;
    pvWasFalse : BOOL;
    pvTurnedTrue : BOOL;
END_VAR
    fb.Enable := TRUE;
    fb.ReqTremie := TRUE;
    fb.SpeedTgt_Pct := 100.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.FullTravelTimeS := 8.0;
    fb.SensorElectricalDelayS := 0.0;
    pvWasFalse := FALSE;
    pvTurnedTrue := FALSE;
    FOR i := 1 TO 700 DO
        fb();
        IF NOT fb.PosPV THEN
            pvWasFalse := TRUE;
        END_IF;
        IF pvWasFalse AND fb.PosPV THEN
            pvTurnedTrue := TRUE;
        END_IF;
    END_FOR;
    ASSERT_TRUE(pvWasFalse, 'PV initialement inactif a P1');
    ASSERT_TRUE(pvTurnedTrue, 'PV actif apres franchissement vers Tremie');
END_TEST

TEST 'TC-T300-DRV-020 Rampe terrain 20 Hz par seconde'
VAR
    fb : FB_Sim_Translation;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReqTremie := TRUE;
    fb.SpeedTgt_Pct := 0.0;
    fb.BrakeReleaseCmd := TRUE;
    fb();
    fb.SpeedTgt_Pct := 100.0;
    FOR i := 1 TO 100 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.FrequencyCmd_Hz, 19.7, 'Rampe apres 1 s >= 19.7 Hz');
    ASSERT_LT(fb.FrequencyCmd_Hz, 20.3, 'Rampe apres 1 s <= 20.3 Hz');
    ASSERT_LT(fb.ActualFrequency_Hz, fb.FrequencyCmd_Hz, 'Retour dynamique derriere la consigne');
    ASSERT_GT(fb.ActualFrequency_Hz, 16.0, 'Retour coherent avec tau 150 ms');
END_TEST

TEST 'TC-T300-BRK-025 Frein temporise et retour distinct'
VAR
    fb : FB_Sim_Translation;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.10;
    fb();
    ASSERT_TRUE(fb.BrakeCoilEnergized, 'Bobine active immediatement sur ordre');
    FOR i := 1 TO 8 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.BrakeContactOpen, 'Pas de confirmation avant 90 ms');
    fb();
    fb();
    ASSERT_TRUE(fb.BrakeMechanicallyOpen, 'Ouverture mecanique apres delai');
    ASSERT_TRUE(fb.BrakeContactOpen, 'Retour auxiliaire apres delai');
END_TEST

TEST 'TC-T300-MEC-010 Le chariot suit la frequence et excite la charge'
VAR
    fb : FB_Sim_Translation;
    i : INT;
    startPosition_M : REAL;
END_VAR
    fb.Enable := TRUE;
    fb.ReqTremie := TRUE;
    fb.SpeedTgt_Pct := 100.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb();
    startPosition_M := fb.PositionTrue_M;
    FOR i := 1 TO 100 DO
        fb();
    END_FOR;
    ASSERT_LT(fb.PositionTrue_M, startPosition_M, 'Deplacement reel vers Tremie');
    ASSERT_LT(fb.VelocityTrue_Mps, 0.0, 'Vitesse signee vers Tremie');
    ASSERT_TRUE(ABS(fb.LoadAngle_Rad) > 0.0001, 'Acceleration excite le pendule');
END_TEST

TEST 'TC-T300-MEC-030 Commandes contradictoires restent neutres'
VAR
    fb : FB_Sim_Translation;
    i : INT;
    startPosition_M : REAL;
END_VAR
    fb.Enable := TRUE;
    fb.ReqTremie := TRUE;
    fb.ReqMaintenance := TRUE;
    fb.SpeedTgt_Pct := 100.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb();
    startPosition_M := fb.PositionTrue_M;
    FOR i := 1 TO 50 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.FrequencyCmd_Hz, 0.0, 'Aucune excitation avec deux sens');
    ASSERT_EQ(fb.PositionTrue_M, startPosition_M, 'Position conservee');
END_TEST

TEST 'TC-T300-SEN-030 Episode capteur intermittent rejouable avant stabilisation'
VAR
    fb : FB_Sim_Translation;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReqMaintenance := TRUE;
    fb.SpeedTgt_Pct := 0.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb.FullTravelTimeS := 0.5;
    fb.SensorStabilizationS := 1.0;
    fb.SensorIntermittenceActive := TRUE;
    fb.SensorLoadAngleTriggerRad := 0.0;
    fb.SensorIntermittencePeriodS := 0.12;
    fb();
    fb.SpeedTgt_Pct := 100.0;
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.SensorTransitionCount, 1, 'Au moins deux fronts DI sont publies pendant episode');
    ASSERT_FALSE(fb.PosP1, 'DI rejoint la position mecanique apres episode');
END_TEST

TEST 'TC-T300-CAM-100 Matrice 48 scenarios par 100 graines respecte invariants'
VAR
    fb : FB_Sim_Translation;
    direction : INT;
    loadProfile : INT;
    regime : INT;
    perturbation : INT;
    seed : INT;
    i : INT;
END_VAR
    FOR direction := 1 TO 2 DO
        FOR loadProfile := 1 TO 2 DO
            FOR regime := 1 TO 3 DO
                FOR perturbation := 1 TO 4 DO
                    FOR seed := 1 TO 100 DO
                        fb.Enable := FALSE;
                        fb();
                        fb.Enable := TRUE;
                        fb.ReqTremie := direction = 1;
                        fb.ReqMaintenance := direction = 2;
                        fb.SpeedTgt_Pct := 100.0;
                        fb.BrakeReleaseCmd := TRUE;
                        fb.FullTravelTimeS := 0.5;
                        fb.SensorElectricalDelayS := 0.0;
                        fb.SensorScenarioSeed := DINT_TO_UDINT(seed);
                        fb.SensorIntermittenceActive := perturbation = 3;
                        fb.SensorLoadAngleTriggerRad := 0.0;
                        IF loadProfile = 1 THEN
                            fb.LoadReactionGain_Mps2 := 0.0;
                        ELSE
                            fb.LoadReactionGain_Mps2 := 0.20;
                        END_IF;
                        IF perturbation = 4 THEN
                            fb.BrakeOpenDelayS := 0.30;
                        ELSE
                            fb.BrakeOpenDelayS := 0.0;
                        END_IF;
                        fb();
                        FOR i := 1 TO 200 DO
                            IF (regime = 2) AND (i = 80) THEN
                                fb.SpeedTgt_Pct := 0.0;
                            ELSIF (regime = 3) AND (i = 80) THEN
                                fb.SpeedTgt_Pct := 0.0;
                                fb.BrakeReleaseCmd := FALSE;
                            END_IF;
                            fb();
                            ASSERT_GE(fb.PositionTrue_M, 0.0, 'Course mecanique jamais inferieure a Tremie');
                            ASSERT_LE(fb.PositionTrue_M, 30.0, 'Course mecanique jamais superieure a Maintenance');
                            ASSERT_GE(fb.ActualFrequency_Hz, 0.0, 'Retour variateur non negatif');
                            ASSERT_LE(fb.ActualFrequency_Hz, 40.0, 'Retour variateur borne a 40 Hz');
                            IF perturbation <> 3 THEN
                                ASSERT_TRUE((NOT fb.PosTremie) OR fb.PosPV,
                                    'Mot thermometre : Tremie implique PV');
                                ASSERT_TRUE((NOT fb.PosPV) OR fb.PosP2,
                                    'Mot thermometre : PV implique P2');
                                ASSERT_TRUE((NOT fb.PosP2) OR fb.PosP1,
                                    'Mot thermometre : P2 implique P1');
                                ASSERT_TRUE((NOT fb.PosP1) OR fb.PosMaintenance,
                                    'Mot thermometre : P1 implique Maintenance');
                            END_IF;
                        END_FOR;
                    END_FOR;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
END_TEST

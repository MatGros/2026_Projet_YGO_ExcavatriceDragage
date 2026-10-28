(* Scenarios fonctionnels du ST reel : aucune copie du modele mecanique. *)
SETUP
VAR
    fb : FB_Sim_Translation;
    reverse : FB_Sim_Translation;
    reference : FB_Sim_Translation;
    clockProbe : FB_CycleTime;
    sensor : FB_Sim_PositionSensor;
    frequencyBefore_Hz : REAL;
    positionBefore_M : REAL;
    peakEarly_Rad : REAL;
    peakLate_Rad : REAL;
END_VAR
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.ReqMaintenance := TRUE;
    fb.SpeedTgt_Pct := 40.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb.BrakeContactDelayS := 0.0;
    fb.BrakePhysicalActive := TRUE;
    fb.CartFreeActive := TRUE;
    fb.RollingFriction_Mps2 := 0.1;
    fb.SensorJitterAmplitude_M := 0.0;
END_SETUP

TEST 'M3-DYN-010 Retrait de commande a 20 Hz conserve la deceleration pilotee'
VAR
    i : INT;
END_VAR
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    ASSERT_NEAR(fb.ActualFrequency_Hz, 20.0, 0.1, 'Regime etabli a 20 Hz');
    frequencyBefore_Hz := fb.ActualFrequency_Hz;
    positionBefore_M := fb.PositionTrue_M;
    fb.ReqMaintenance := FALSE;
    fb();
    ASSERT_GT(fb.ActualFrequency_Hz, 19.0, 'Le mot nul ne supprime pas le retour frequence');
    ASSERT_GT(fb.PositionTrue_M, positionBefore_M, 'Sens memorise pendant la deceleration');
    ASSERT_FALSE(fb.ObsCartFree, 'Pas de roue libre pendant la rampe variateur');
    FOR i := 1 TO 50 DO
        fb();
    END_FOR;
    ASSERT_LT(fb.ActualFrequency_Hz, frequencyBefore_Hz, 'Frequence decroissante');
    FOR i := 1 TO 300 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.ActualFrequency_Hz, 0.0, 'Rampe terminee');
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.0, 0.00001, 'Arret sans oscillation artificielle');
END_TEST

TEST 'M3-DYN-100 Retour frequence electrique independant du balancement'
VAR
    drive : FB_Sim_TranslationDrive;
    i : INT;
END_VAR
    drive.Enable := TRUE;
    drive.FrequencyTgt_Hz := 20.0;
    drive.CycleTime_S := 0.01;
    FOR i := 1 TO 250 DO
        drive();
    END_FOR;
    drive.LoadAngularVelocity_RadPerS := 8.0;
    drive();
    ASSERT_NEAR(drive.ActualFrequency_Hz, drive.ElectricalFrequency_Hz, 0.00001,
        'Le retour PDO conserve la frequence electrique sous balancement');
    drive.LoadAngularVelocity_RadPerS := -8.0;
    drive();
    ASSERT_NEAR(drive.ActualFrequency_Hz, drive.ElectricalFrequency_Hz, 0.00001,
        'Pas de biais redresse par la valeur absolue du balancement');
END_TEST

TEST 'M3-DYN-110 Deceleration sans second retard sur la vitesse chariot'
VAR
    i : INT;
END_VAR
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    fb.ReqMaintenance := FALSE;
    FOR i := 1 TO 50 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.ObsCartFree, 'Mesure pendant la deceleration controlee');
    ASSERT_GT(fb.ActualFrequency_Hz, 5.0, 'Le variateur decelere encore');
    ASSERT_NEAR(fb.VelocityTrue_Mps, fb.ActualFrequency_Hz * 0.02, 0.001,
        'La vitesse suit le retour variateur, avec seule faible reaction mecanique');
END_TEST

TEST 'M3-DYN-120 Fin de rampe a 0.5 Hz sans supprimer consigne basse non nulle'
VAR
    drive : FB_Sim_TranslationDrive;
    i : INT;
END_VAR
    drive.Enable := TRUE;
    drive.FrequencyTgt_Hz := 20.0;
    drive.CycleTime_S := 0.01;
    FOR i := 1 TO 250 DO
        drive();
    END_FOR;
    drive.FrequencyTgt_Hz := 0.0;
    FOR i := 1 TO 120 DO
        drive();
    END_FOR;
    ASSERT_EQ(drive.ActualFrequency_Hz, 0.0, 'Fin d arret sans longue traine sous 0.5 Hz');
    drive.FrequencyTgt_Hz := 0.2;
    FOR i := 1 TO 100 DO
        drive();
    END_FOR;
    ASSERT_NEAR(drive.ActualFrequency_Hz, 0.2, 0.001,
        'Une consigne basse maintenue ne doit pas etre effacee');
END_TEST

TEST 'M3-DYN-020 Retrait brutal a 50 Hz reste limite par le variateur'
VAR
    i : INT;
END_VAR
    fb.SpeedTgt_Pct := 100.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_NEAR(fb.ActualFrequency_Hz, 50.0, 0.1, 'Regime etabli a 50 Hz');
    fb.ReqMaintenance := FALSE;
    positionBefore_M := fb.PositionTrue_M;
    fb();
    ASSERT_GT(fb.ActualFrequency_Hz, 49.0, 'Retour conserve apres retrait');
    ASSERT_GT(fb.PositionTrue_M, positionBefore_M, 'Pas de gel de position au retrait');
    ASSERT_FALSE(fb.ObsCartFree, 'Variateur encore en deceleration');
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.ActualFrequency_Hz, 0.0, 'Frequence finalement nulle');
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.0, 0.00001, 'Arret final');
    ASSERT_FALSE(fb.HardStopMaintenanceActive, 'Arret observe hors butee');
END_TEST

TEST 'M3-DYN-030 Frottement seul a 100 ms sans inversion dans les deux sens'
    fb.SpeedTgt_Pct := 0.4;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    reverse(Enable := TRUE, ReqTremie := TRUE, SpeedTgt_Pct := 0.4,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, RollingFriction_Mps2 := 0.1, LoadMassRatio := 0.0,
        LoadReactionGain_Mps2 := 0.0, LoadFrequencyDroopGain_Hz := 0.0);
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.004, 0.00001, 'Petite vitesse positive initiale');
    ASSERT_NEAR(reverse.VelocityTrue_Mps, -0.004, 0.00001, 'Petite vitesse negative initiale');
    clockProbe();
    fb.ReqMaintenance := FALSE;
    reverse.ReqTremie := FALSE;
    ADVANCE_TIME(100000000);
    clockProbe();
    ASSERT_NEAR(clockProbe.CycleTimeS, 0.1, 0.00001, 'Pas reel de 100 ms');
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Frottement arrete le sens positif sans inversion');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Frottement arrete le sens negatif sans inversion');
    ASSERT_TRUE(fb.ObsCartFree, 'Le calcul libre est effectivement exerce');
    ADVANCE_TIME(100000000);
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Pas de redemarrage numerique positif');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Pas de redemarrage numerique negatif');
END_TEST

TEST 'M3-DYN-040 Frottement seul a 10 ms sans inversion dans les deux sens'
    fb.SpeedTgt_Pct := 0.04;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    reverse(Enable := TRUE, ReqTremie := TRUE, SpeedTgt_Pct := 0.04,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, RollingFriction_Mps2 := 0.1, LoadMassRatio := 0.0,
        LoadReactionGain_Mps2 := 0.0, LoadFrequencyDroopGain_Hz := 0.0);
    clockProbe();
    fb.ReqMaintenance := FALSE;
    reverse.ReqTremie := FALSE;
    ADVANCE_TIME(10000000);
    clockProbe();
    ASSERT_NEAR(clockProbe.CycleTimeS, 0.01, 0.00001, 'Pas reel de 10 ms');
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Immobilite positive conservee');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Immobilite negative conservee');
END_TEST

TEST 'M3-DYN-050 Adherence au repos et au seuil puis depart sous poussee'
    fb.ReqMaintenance := FALSE;
    fb.LoadMassRatio := 0.0;
    fb.Slope_Mps2 := 0.05;
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Poussee sous le frottement : immobile');
    fb.Slope_Mps2 := 0.1;
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Poussee au seuil : immobile');
    fb.Slope_Mps2 := 0.2;
    fb();
    ASSERT_GT(fb.VelocityTrue_Mps, 0.0, 'Poussee suffisante : depart physique');
END_TEST

TEST 'M3-DYN-060 Poussee opposee suffisante autorise une vraie inversion'
    fb.SpeedTgt_Pct := 0.4;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    ASSERT_GT(fb.VelocityTrue_Mps, 0.0, 'Vitesse initiale positive');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.2;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_LT(fb.VelocityTrue_Mps, 0.0, 'La correction ne bloque pas une vraie inversion');
END_TEST

TEST 'M3-DYN-070 Frein ferme en mouvement suit la bobine sans attendre les Hz'
VAR
    i : INT;
END_VAR
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.VelocityTrue_Mps, 0.3, 'Chariot initialement en mouvement');
    fb.BrakeReleaseCmd := FALSE;
    fb();
    ASSERT_FALSE(fb.BrakeCoilEnergized, 'Coupure bobine immediate');
    ASSERT_TRUE(fb.BrakeMechanicallyOpen, 'Delai mecanique conserve');
    FOR i := 1 TO 60 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.BrakeMechanicallyOpen, 'Frein serre malgre frequence non nulle');
    ASSERT_FALSE(fb.BrakeContactOpen, 'Retour frein ferme');
    ASSERT_GT(fb.ActualFrequency_Hz, 10.0, 'La sortie variateur est encore non nulle');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Frein immobilise le chariot');
    ASSERT_EQ(fb.ObsBrakeClosedMovingCount, 1, 'Fermeture en mouvement observable');
END_TEST

TEST 'M3-DYN-080 Balancement conserve secondaire sous controle puis amorti'
VAR
    i : INT;
END_VAR
    reference.Enable := TRUE;
    reference.ReqMaintenance := TRUE;
    reference.SpeedTgt_Pct := 40.0;
    reference.BrakeReleaseCmd := TRUE;
    reference.BrakeOpenDelayS := 0.0;
    reference.SuspendedLoadLength_M := 0.0;
    FOR i := 1 TO 300 DO
        fb();
        reference();
    END_FOR;
    ASSERT_TRUE(ABS(fb.LoadAngle_Rad) > 0.0001, 'Balancement present');
    ASSERT_LT(ABS(fb.PositionTrue_M - reference.PositionTrue_M), 0.05,
        'Contribution secondaire dans ce scenario fixe, sans plafonnement de distance');
    ASSERT_FALSE(fb.ObsCartFree, 'Comparaison effectuee sous controle variateur');
    fb.ReqMaintenance := FALSE;
    fb.BrakeReleaseCmd := FALSE;
    FOR i := 1 TO 800 DO
        fb();
        IF i <= 100 THEN
            peakEarly_Rad := MAX(peakEarly_Rad, ABS(fb.LoadAngle_Rad));
        END_IF;
        IF i > 700 THEN
            peakLate_Rad := MAX(peakLate_Rad, ABS(fb.LoadAngle_Rad));
        END_IF;
    END_FOR;
    ASSERT_GT(peakEarly_Rad, 0.001, 'Pendule excite par le freinage');
    ASSERT_LT(peakLate_Rad, peakEarly_Rad, 'Oscillations amorties');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Pendule ne deplace pas le frein serre');
END_TEST

TEST 'M3-DYN-090 Came spatiale vue perdue retrouvee stable sans blip ajoute'
    sensor(Enable := TRUE, Position_M := 0.2, Threshold_M := 0.0,
        CamDropoutActive := TRUE, CamDropoutStart_M := 0.02, CamDropoutWidth_M := 0.04,
        ElectricalDelayS := 0.0, IntermittenceActive := FALSE, BlipTransitions := 0);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Avant la detection');
    sensor(Position_M := -0.03);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible vue');
    sensor(Position_M := -0.06);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Interruption de cible');
    sensor(Position_M := -0.10);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible retrouvee');
    sensor();
    ASSERT_TRUE(sensor.ElectricalOutput, 'Etat stable sans intermittence temporelle');
    sensor(Position_M := -0.06);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Zone de perte aussi au retour');
    sensor(Position_M := -0.02);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible retrouvee au retour');
    sensor(Position_M := 0.03);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Sortie de cible');
END_TEST

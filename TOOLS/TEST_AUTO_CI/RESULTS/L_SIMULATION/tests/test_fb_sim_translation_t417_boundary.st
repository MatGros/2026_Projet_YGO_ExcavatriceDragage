(* T417 investigation : vitesse initiale opposee a une force inferieure au seuil
   statique. Apres passage a zero, cette force ne peut pas redemarrer le chariot.
   Parametres synthetiques explicites, aucune calibration terrain. *)
SETUP
VAR
    fb : FB_Sim_Translation;
    reverse : FB_Sim_Translation;
END_VAR
    fb(Enable := FALSE);
    reverse(Enable := FALSE);
    fb(Enable := TRUE, ReqMaintenance := TRUE, SpeedTgt_Pct := 0.4,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, RollingFriction_Mps2 := 0.1, StaticFriction_Mps2 := 0.35,
        LoadMassRatio := 0.0, LoadReactionGain_Mps2 := 0.0, SensorJitterAmplitude_M := 0.0);
    reverse(Enable := TRUE, ReqTremie := TRUE, SpeedTgt_Pct := 0.4,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, RollingFriction_Mps2 := 0.1, StaticFriction_Mps2 := 0.35,
        LoadMassRatio := 0.0, LoadReactionGain_Mps2 := 0.0, SensorJitterAmplitude_M := 0.0);
END_SETUP

TEST 'T417-BOUND-010 Force opposee sous seuil statique ne redemarre pas apres zero'
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.004, 0.00001, 'Vitesse initiale positive');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.2;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_TRUE(fb.ObsCartFree, 'Branche libre exercee');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Arret puis adherence : force 0.2 inferieure au seuil 0.35');
END_TEST

TEST 'T417-BOUND-040 Frottement banc 0.30 et pas 100 ms respectent adherence'
    fb.SpeedTgt_Pct := 0.2;
    fb.RollingFriction_Mps2 := 0.30;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.002, 0.00001, 'Vitesse avant arret');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.34;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_TRUE(fb.ObsCartFree, 'Branche libre exercee');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Force 0.34 sous seuil 0.35 : adherence apres zero');
END_TEST

TEST 'T417-BOUND-050 Meme scenario avec pas 20 ms'
    fb.SpeedTgt_Pct := 0.2;
    fb.RollingFriction_Mps2 := 0.30;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.002, 0.00001, 'Vitesse avant arret');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.34;
    ADVANCE_TIME(20000000);
    fb();
    ASSERT_TRUE(fb.ObsCartFree, 'Branche libre exercee');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Meme verdict adherence au pas 20 ms');
END_TEST

TEST 'T417-BOUND-020 Meme adherence dans le sens negatif'
    ASSERT_NEAR(reverse.VelocityTrue_Mps, -0.004, 0.00001, 'Vitesse initiale negative');
    reverse.ReqTremie := FALSE;
    reverse.Slope_Mps2 := 0.2;
    ADVANCE_TIME(100000000);
    reverse();
    ASSERT_TRUE(reverse.ObsCartFree, 'Branche libre exercee');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Arret puis adherence symetrique');
END_TEST

TEST 'T417-BOUND-030 Une force au dessus du seuil permet inversion'
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.6;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_TRUE(fb.ObsCartFree, 'Branche libre exercee');
    ASSERT_LT(fb.VelocityTrue_Mps, 0.0, 'Force 0.6 superieure au seuil 0.35 : inversion autorisee');
END_TEST

TEST 'T417-BOUND-060 Force exactement au seuil statique reste collee au croisement'
    fb.SpeedTgt_Pct := 0.4;
    fb.RollingFriction_Mps2 := 0.1;
    fb.StaticFriction_Mps2 := 0.35;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.004, 0.00001, 'Vitesse initiale positive');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.35;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Comparaison inclusive : egalite = adhesion');
END_TEST

TEST 'T417-BOUND-070 Prediction exactement nulle et force supra seuil'
    fb.SpeedTgt_Pct := 0.4;
    fb.RollingFriction_Mps2 := 0.1;
    fb.StaticFriction_Mps2 := 0.35;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.004, 0.00001, 'Vitesse initiale positive');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.04;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Prediction nulle garde le mouvement pour ce scan');
END_TEST

TEST 'T417-BOUND-080 Seuil de vitesse 0.001 distingue repos et mouvement'
    fb.SpeedTgt_Pct := 0.1;
    fb.RollingFriction_Mps2 := 0.0;
    fb.StaticFriction_Mps2 := 0.35;
    fb.Slope_Mps2 := 0.0;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.001, 0.00001, 'Vitesse au seuil');
    fb.SpeedTgt_Pct := 0.08;
    fb();
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.0008, 0.00001, 'Vitesse sous seuil');
END_TEST

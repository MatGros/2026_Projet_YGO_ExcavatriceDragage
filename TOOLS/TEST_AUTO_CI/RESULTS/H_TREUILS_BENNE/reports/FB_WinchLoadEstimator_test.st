(* =======================================================================
   test_fb_winchloadestimator.st — T181-18 D11 : macro TC FB_WinchLoadEstimator
   Estimateur informatif (aucune action securite). Couvre : gate, classement
   de vitesse par bande + hysteresis, direction montee/descente, validation table.
   (La lecture de la matrice 5x5 elle-meme n'est pas asserted ici : passthrough,
   et le harnais STruCpp ne supporte pas l'indexation [i][j] d'un ARRAY OF ARRAY.)
   ======================================================================= *)

SETUP
VAR
    fb  : FB_WinchLoadEstimator;
    Spd : ST_fbWinchLoadEstimator_SpeedCfg;
    Tbl : ST_fbWinchLoadEstimator_Table;
END_VAR
END_SETUP

TEST 'TC-P10-T181-18a Gate : Enable FALSE -> sorties neutres'
    Spd.MaxMeasuredSpeedMps := 2.0;
    Spd.SpeedBandMaxMps[1] := 0.4; Spd.SpeedBandMaxMps[2] := 0.8; Spd.SpeedBandMaxMps[3] := 1.2;
    Spd.SpeedBandMaxMps[4] := 1.6; Spd.SpeedBandMaxMps[5] := 2.0;
    Spd.SpeedBandHysteresisMps := 0.05;
    fb(Enable := FALSE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 3,
       MeasuredSpeedMps := 0.5, MeasuredSpeedSignedMps := 0.5,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_FALSE(fb.Ready, 'Enable FALSE -> Ready FALSE');
    ASSERT_EQ(fb.SpeedBand, 0, 'Enable FALSE -> SpeedBand 0');
    ASSERT_EQ(fb.EstimatedLoadPct, 0.0, 'Enable FALSE -> estimation 0');
END_TEST

TEST 'TC-P10-T181-18b Classement vitesse : 0.5 m/s -> bande 2, montee'
    Spd.MaxMeasuredSpeedMps := 2.0;
    Spd.SpeedBandMaxMps[1] := 0.4; Spd.SpeedBandMaxMps[2] := 0.8; Spd.SpeedBandMaxMps[3] := 1.2;
    Spd.SpeedBandMaxMps[4] := 1.6; Spd.SpeedBandMaxMps[5] := 2.0;
    Spd.SpeedBandHysteresisMps := 0.05;
    Tbl.IsConfigured := TRUE;
    fb(Enable := TRUE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 2,
       MeasuredSpeedMps := 0.5, MeasuredSpeedSignedMps := 0.5,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_EQ(fb.SpeedBand, 2, 'Vitesse 0.5 m/s (entre 0.4 et 0.8) -> bande 2');
    ASSERT_TRUE(fb.Ascending, 'Vitesse signee positive -> montee');
    ASSERT_TRUE(fb.Configured, 'Table validee -> Configured TRUE');
    ASSERT_TRUE(fb.Ready, 'Nominal -> Ready TRUE');
END_TEST

TEST 'TC-P10-T181-18c Classement vitesse : 1.5 m/s -> bande 4'
    Spd.MaxMeasuredSpeedMps := 2.0;
    Spd.SpeedBandMaxMps[1] := 0.4; Spd.SpeedBandMaxMps[2] := 0.8; Spd.SpeedBandMaxMps[3] := 1.2;
    Spd.SpeedBandMaxMps[4] := 1.6; Spd.SpeedBandMaxMps[5] := 2.0;
    Spd.SpeedBandHysteresisMps := 0.05;
    fb(Enable := TRUE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 4,
       MeasuredSpeedMps := 1.5, MeasuredSpeedSignedMps := 1.5,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_EQ(fb.SpeedBand, 4, 'Vitesse 1.5 m/s (entre 1.2 et 1.6) -> bande 4');
END_TEST

TEST 'TC-P10-T181-18d Descente : aucune estimation de charge'
    Spd.MaxMeasuredSpeedMps := 2.0;
    Spd.SpeedBandMaxMps[1] := 0.4; Spd.SpeedBandMaxMps[2] := 0.8; Spd.SpeedBandMaxMps[3] := 1.2;
    Spd.SpeedBandMaxMps[4] := 1.6; Spd.SpeedBandMaxMps[5] := 2.0;
    Spd.SpeedBandHysteresisMps := 0.05;
    Tbl.IsConfigured := TRUE;
    fb(Enable := TRUE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 2,
       MeasuredSpeedMps := 0.5, MeasuredSpeedSignedMps := -0.5,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_FALSE(fb.Ascending, 'Vitesse signee negative -> descente');
    ASSERT_EQ(fb.EstimatedLoadPct, 0.0, 'Descente : estimation non produite');
END_TEST

TEST 'TC-P10-T181-18e Vitesse mesuree negative -> defaut latche, bande 0'
    Spd.MaxMeasuredSpeedMps := 2.0;
    Spd.SpeedBandMaxMps[1] := 0.4; Spd.SpeedBandMaxMps[2] := 0.8; Spd.SpeedBandMaxMps[3] := 1.2;
    Spd.SpeedBandMaxMps[4] := 1.6; Spd.SpeedBandMaxMps[5] := 2.0;
    Spd.SpeedBandHysteresisMps := 0.05;
    fb(Enable := TRUE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 2,
       MeasuredSpeedMps := -0.1, MeasuredSpeedSignedMps := -0.1,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_EQ(fb.SpeedBand, 0, 'Vitesse mesuree < 0 -> bande 0');
    (* Le socle latche la cause au scan suivant (Active pose apres l'appel FB_FaultCore). *)
    fb(Enable := TRUE, PowerContactorEngaged := TRUE, ActiveSpeedStep := 2,
       MeasuredSpeedMps := -0.1, MeasuredSpeedSignedMps := -0.1,
       SpeedConfig := Spd, LoadTable := Tbl);
    ASSERT_TRUE(fb.Fault.Latched, 'Vitesse mesuree < 0 -> defaut latche');
END_TEST

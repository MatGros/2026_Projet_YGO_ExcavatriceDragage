(* =======================================================================
   test_fb_winch_symmetry.st -- T181-18 D11 : macro TC FB_Winch_Symmetry (F10.06)
   Observateur passif de symetrie / synchronisme M1-M2. Aucune action securite.
   Qualification : commande stable des 2 treuils, meme sens, au-dela de
   MinimumCommandTime_Ms (defaut 1000 ms) et vitesse au-dessus de MinimumSpeed_Mps.
   Les ecarts sont calcules a l arret.
   ======================================================================= *)

SETUP
VAR
    fb  : FB_Winch_Symmetry;
    Cfg : ST_fbWinch_Symmetry_Cfg;
    Dat : ST_fbWinch_Symmetry_Data;
END_VAR
END_SETUP

TEST 'TC-P10-T181-18a Cycle symetrique -> SymmetryValid et SymmetryOk'
    Cfg.MinimumCommandTime_Ms := 300;
    Cfg.MinimumSpeed_Mps := 0.05;
    Cfg.DeltaStartDelay_Ms := 100; Cfg.DeltaBrakeReleaseTime_Ms := 100;
    Cfg.DeltaBrakeApplyTime_Ms := 100; Cfg.DeltaStopDistance_Mm := 100;
    Cfg.DeltaStopTime_Ms := 200;
    fb(Reset := TRUE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 0, M2Direction := 0,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.10, Config := Cfg, Data := Dat);
    ADVANCE_TIME(500000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 0.5, M2Position_M := 0.5, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.10, Config := Cfg, Data := Dat);
    ADVANCE_TIME(500000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 1.0, M2Position_M := 1.0, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.10, Config := Cfg, Data := Dat);
    ADVANCE_TIME(500000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 1.5, M2Position_M := 1.5, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.10, Config := Cfg, Data := Dat);
    ADVANCE_TIME(500000000);
    fb(Reset := FALSE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 2.0, M2Position_M := 2.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    ADVANCE_TIME(10000000);
    fb(Reset := FALSE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 2.0, M2Position_M := 2.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    ASSERT_TRUE(fb.SymmetryValid, 'Cycle complet qualifie puis arrete -> mesure valide');
    ASSERT_TRUE(fb.SymmetryOk, 'M1 et M2 identiques -> tous les ecarts sous les seuils');
END_TEST

TEST 'TC-P10-T181-18b Reset remet les mesures a zero'
    Cfg.MinimumCommandTime_Ms := 300;
    Cfg.MinimumSpeed_Mps := 0.05;
    Cfg.DeltaStartDelay_Ms := 100; Cfg.DeltaBrakeReleaseTime_Ms := 100;
    Cfg.DeltaBrakeApplyTime_Ms := 100; Cfg.DeltaStopDistance_Mm := 100;
    Cfg.DeltaStopTime_Ms := 200;
    fb(Reset := TRUE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 0, M2Direction := 0,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.40, Config := Cfg, Data := Dat);
    ADVANCE_TIME(600000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 0.6, M2Position_M := 0.6, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.40, Config := Cfg, Data := Dat);
    ADVANCE_TIME(600000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := TRUE, M1Direction := 1, M2Direction := 1,
       M1BrakeCmd := TRUE, M2BrakeCmd := TRUE, M1BrakeApplied := FALSE, M2BrakeApplied := FALSE,
       M1Position_M := 1.2, M2Position_M := 1.2, M1Speed_Mps := 1.0, M2Speed_Mps := 1.0,
       SyncDeviation_M := 0.40, Config := Cfg, Data := Dat);
    fb(Reset := TRUE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 0, M2Direction := 0,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    ASSERT_EQ(Dat.DeltaStartDelay_Ms, 0, 'Reset -> DeltaStartDelay_Ms remis a 0');
    ASSERT_FALSE(Dat.MaxSyncDeviation_M > 0.0, 'Reset -> MaxSyncDeviation_M remis a 0');
END_TEST

TEST 'TC-P10-T181-18c Non qualifie si un seul treuil commande'
    Cfg.MinimumCommandTime_Ms := 300;
    Cfg.MinimumSpeed_Mps := 0.05;
    Cfg.DeltaStartDelay_Ms := 100; Cfg.DeltaBrakeReleaseTime_Ms := 100;
    Cfg.DeltaBrakeApplyTime_Ms := 100; Cfg.DeltaStopDistance_Mm := 100;
    Cfg.DeltaStopTime_Ms := 200;
    fb(Reset := TRUE, M1CommandActive := FALSE, M2CommandActive := FALSE, M1Direction := 0, M2Direction := 0,
       M1BrakeCmd := FALSE, M2BrakeCmd := FALSE, M1BrakeApplied := TRUE, M2BrakeApplied := TRUE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 0.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.0, Config := Cfg, Data := Dat);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := FALSE, M1Direction := 1, M2Direction := 0,
       M1BrakeCmd := TRUE, M2BrakeCmd := FALSE, M1BrakeApplied := FALSE, M2BrakeApplied := TRUE,
       M1Position_M := 0.0, M2Position_M := 0.0, M1Speed_Mps := 1.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.30, Config := Cfg, Data := Dat);
    ADVANCE_TIME(1500000000);
    fb(Reset := FALSE, M1CommandActive := TRUE, M2CommandActive := FALSE, M1Direction := 1, M2Direction := 0,
       M1BrakeCmd := TRUE, M2BrakeCmd := FALSE, M1BrakeApplied := FALSE, M2BrakeApplied := TRUE,
       M1Position_M := 1.5, M2Position_M := 0.0, M1Speed_Mps := 1.0, M2Speed_Mps := 0.0,
       SyncDeviation_M := 0.30, Config := Cfg, Data := Dat);
    ASSERT_FALSE(fb.SymmetryValid, 'Un seul treuil commande -> jamais qualifie');
END_TEST

(* =======================================================================
   test_fb_speedstep.st — T181-07 : bornes Min/Max du décodeur palier
   ======================================================================= *)

SETUP
VAR
    fb : FB_SpeedStep;
    Table : ST_SpeedStepTable;
END_VAR
END_SETUP

TEST 'TC-P10-T181-07a Defaut retro-compatible : demande 4 -> palier 4'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P4R1 := TRUE;

    fb(Enable := TRUE, SpeedStepReq := 4, Table := Table, MaxStepNumber := 5);
    ASSERT_EQ(fb.StepNumber, 4, 'Defaut Min=1 : demande 4 conservee');
    ASSERT_TRUE(fb.Contactor1, 'Table palier 4 lue');
END_TEST

TEST 'TC-P10-T181-07b Precedence plafond : plancher 3 + plafond 1 -> palier 1'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P1R1 := TRUE;

    fb(Enable := TRUE, SpeedStepReq := 5, Table := Table, MinStepNumber := 3, MaxStepNumber := 1);
    ASSERT_EQ(fb.StepNumber, 1, 'Le plafond securite gagne sur le plancher');
    ASSERT_TRUE(fb.Contactor1, 'Table palier 1 lue');
END_TEST

TEST 'TC-P10-T181-07c Relache : Enable FALSE force le palier 0'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P3R1 := TRUE;

    fb(Enable := FALSE, SpeedStepReq := 5, Table := Table, MinStepNumber := 3, MaxStepNumber := 5);
    ASSERT_EQ(fb.StepNumber, 0, 'Relache : le plancher ne maintient aucun palier');
    ASSERT_FALSE(fb.Contactor1, 'Relache : contacteur 1 coupe');
END_TEST

TEST 'TC-P10-T181-07d Bornes : requete hors plage reste dans 0..5'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P5R1 := TRUE;

    fb(Enable := TRUE, SpeedStepReq := 99, Table := Table, MinStepNumber := -3, MaxStepNumber := 99);
    ASSERT_EQ(fb.StepNumber, 5, 'Requete et plafond hauts bornes a 5');
    fb(Enable := TRUE, SpeedStepReq := -1, Table := Table, MinStepNumber := 5, MaxStepNumber := 5);
    ASSERT_EQ(fb.StepNumber, 0, 'Requete nulle ou negative reste a 0');
END_TEST

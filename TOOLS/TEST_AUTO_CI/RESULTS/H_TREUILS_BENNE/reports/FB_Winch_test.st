SETUP
VAR
    FB_Safety : FB_Safety_Winch;
    FB_W : FB_Winch;
    Table : ST_SpeedStepTable;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R2 := TRUE;
    Table.P4R3 := TRUE;
    Table.P5R4 := TRUE;

    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    FB_W(Enable := FALSE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Ready, 'Enable=TRUE etabli -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette et re-neutralisation *)
    FB_W(Enable := FALSE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P10-001 Safety_Winch : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'TC-P10-011 Treuil Nominal : consigne montee active les relais de sens et de vitesse'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R2 := TRUE;
    Table.P4R3 := TRUE;
    Table.P5R4 := TRUE;

    (* 1er scan init *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);

    ADVANCE_TIME(10000000);

    (* Treuil actif et pret *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Ready, 'Treuil pret a fonctionner');

    (* Commande de montee palier 1 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 20.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := FALSE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.RelayFwd, 'Ordre montee -> RelayFwd enclenche');
    ASSERT_FALSE(FB_W.RelayRev, 'Montee -> RelayRev reste inactif');
END_TEST

SETUP
VAR
    FB_Safety : FB_Safety_Translation;
    FB_T : FB_Translation;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    FB_T(Enable := FALSE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB_T.Ready, 'Enable=TRUE au repos -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette *)
    FB_T(Enable := FALSE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P11-001 Safety_Translation : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'TC-P11-010 Translation : commande variateur nominale'
    (* Scan 1 : initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : mise en service *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, PowerContactorEngaged := TRUE,
         SpeedTgt_Pct := 50.0, Direction := 1);
    ASSERT_TRUE(FB_T.Ready, 'Translation active et prete');
END_TEST

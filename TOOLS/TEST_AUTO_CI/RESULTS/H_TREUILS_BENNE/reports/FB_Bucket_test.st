SETUP
VAR
    FB : FB_Bucket;
    BucketState : ST_BucketState;
    Config : ST_BucketConfig;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;

    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete au repos *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P10-023 Benne : mise en service et verrouillage securite'
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne active et prete');
    ASSERT_FALSE(FB.M2_StartStop, 'Au repos -> Pas de mouvement benne');
END_TEST

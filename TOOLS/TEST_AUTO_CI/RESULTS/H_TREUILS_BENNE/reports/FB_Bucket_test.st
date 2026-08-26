SETUP
VAR
    FB : FB_Bucket;
    BucketState : ST_BucketState;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete au repos *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P10-023 Benne : mise en service et verrouillage securite'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, BucketState := BucketState);
    ASSERT_TRUE(FB.Ready, 'Benne active et prete');
    ASSERT_FALSE(FB.M2_StartStop, 'Au repos -> Pas de mouvement benne');
END_TEST

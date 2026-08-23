SETUP
VAR
    FB : FB_Bucket;
    BucketState : ST_BucketState;
END_VAR
END_SETUP

TEST 'Bucket : Enable=FALSE neutralise le pilotage benne'
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, BucketState := BucketState);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_FALSE(FB.M2_StartStop, 'M2_StartStop coupe');
END_TEST

SETUP
VAR
    FB : FB_Cycle;
    SampleCount : INT := 0;
END_VAR
END_SETUP

TEST 'Cycle : Enable=FALSE neutralise les commandes treuils/translation/benne'
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'M1 coupe');
    ASSERT_FALSE(FB.WinchM2Cmd.StartStop, 'M2 coupe');
    ASSERT_FALSE(FB.TranslationCmd.Start, 'M3 coupe');
    ASSERT_FALSE(FB.BucketCmd.Open, 'Benne Open coupe');
    ASSERT_FALSE(FB.BucketCmd.Close, 'Benne Close coupe');
END_TEST

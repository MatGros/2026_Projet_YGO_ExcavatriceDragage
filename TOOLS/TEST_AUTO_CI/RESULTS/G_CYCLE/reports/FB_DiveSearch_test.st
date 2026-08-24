SETUP
VAR
    FB : FB_DiveSearch;
END_VAR
END_SETUP

TEST 'DiveSearch : Enable=FALSE neutralise les permis'
    FB(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_FALSE(FB.DescendPermit, 'DescendPermit doit etre FALSE');
    ASSERT_FALSE(FB.KoboldMeasureEnable, 'KoboldMeasureEnable doit etre FALSE');
END_TEST

SETUP
VAR
    FB : FB_ExtractionSequence;
END_VAR
END_SETUP

TEST 'Extraction : Enable=FALSE neutralise les permis'
    FB(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_FALSE(FB.AscentPermit, 'AscentPermit doit etre FALSE');
    ASSERT_FALSE(FB.BucketCloseRequest, 'BucketCloseRequest doit etre FALSE');
END_TEST

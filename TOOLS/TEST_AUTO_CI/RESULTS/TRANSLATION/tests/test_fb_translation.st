SETUP
VAR
    FB_Safety : FB_Safety_Translation;
    FB_T : FB_Translation;
END_VAR
END_SETUP

TEST 'Safety_Translation : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'Translation : Enable=FALSE neutralise le variateur'
    FB_T(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 16#0000, 'ControlWord a 0');
END_TEST

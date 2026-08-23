SETUP
VAR
    FB_Safety : FB_Safety_Winch;
    FB_W : FB_Winch;
END_VAR
END_SETUP

TEST 'Safety_Winch : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'Winch : Enable=FALSE neutralise les sorties'
    FB_W(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_W.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_FALSE(FB_W.RelayFwd, 'RelayFwd coupe');
    ASSERT_FALSE(FB_W.RelayRev, 'RelayRev coupe');
END_TEST

SETUP
VAR
    FB_Banner : FB_Hmi_BannerFormatter;
    FB_AntiFlicker : FB_AntiFlickerText;
    WinchM1Safety : ST_SafetyWinch;
    WinchM2Safety : ST_SafetyWinch;
END_VAR
END_SETUP

TEST 'AntiFlickerText : affichage instantane force'
    FB_AntiFlicker(NewText := 'TEST_INSTANT', ForceInstant := TRUE);
    ASSERT_EQ(FB_AntiFlicker.Text, 'TEST_INSTANT', 'Texte instantane');
END_TEST

TEST 'BannerFormatter : formatage nominal'
    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety
    );
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'GlobalContextText non vide');
END_TEST

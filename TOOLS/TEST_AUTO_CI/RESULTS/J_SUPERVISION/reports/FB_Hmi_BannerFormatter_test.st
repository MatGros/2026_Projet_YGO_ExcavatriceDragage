SETUP
VAR
    FB_Banner : FB_Hmi_BannerFormatter;
    FB_AntiFlicker : FB_AntiFlickerText;
    WinchM1Safety : ST_SafetyWinch;
    WinchM2Safety : ST_SafetyWinch;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB_Banner(Enable := FALSE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety);
    ASSERT_FALSE(FB_Banner.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Formatage actif *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety);
    ASSERT_TRUE(FB_Banner.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB_Banner(Enable := FALSE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety);
    ASSERT_FALSE(FB_Banner.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P07-001 BannerFormatter : formatage nominal bandeau synoptique IHM'
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

TEST 'TC-P07-010 AntiFlickerText : affichage instantane force'
    FB_AntiFlicker(NewText := 'TEST_INSTANT', ForceInstant := TRUE);
    ASSERT_EQ(FB_AntiFlicker.Text, 'TEST_INSTANT', 'Texte instantane');
END_TEST

SETUP
VAR
    FB : FB_Modes;
END_VAR
END_SETUP

TEST 'Modes : Enable=FALSE desactive le FB'
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'Mode doit etre DISABLE');
END_TEST

TEST 'Modes : Nominal Maint N1'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1, EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'Ready doit etre TRUE');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode doit etre MAINT_N1');
END_TEST

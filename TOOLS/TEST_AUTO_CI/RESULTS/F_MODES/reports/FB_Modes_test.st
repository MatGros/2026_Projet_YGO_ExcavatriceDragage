SETUP
VAR
    FB : FB_Modes;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'Enable=FALSE -> Mode force DISABLE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode selectionne MAINT_N1');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'Coupure -> Mode retombe a DISABLE');
END_TEST

TEST 'TC-P05-010 Modes : selection et autorisation mode Maintenance N1'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'FB Modes pret');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode MAINT_N1 valide');
END_TEST

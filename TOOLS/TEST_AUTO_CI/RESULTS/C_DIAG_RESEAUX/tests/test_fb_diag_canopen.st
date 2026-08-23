SETUP
VAR
    FB : FB_Diag_CanOpen;
END_VAR
END_SETUP

TEST 'CanOpen : Enable=FALSE desactive le diagnostic'
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State doit etre DISABLED sans Enable');
END_TEST

TEST 'CanOpen : Enable=TRUE et Bus OK -> Ready et State=READY'
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING, SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Ready doit etre TRUE avec Enable');
    ASSERT_EQ(FB.State, E_Diag_State.READY, 'State doit etre READY quand bus et esclave OK');
    ASSERT_FALSE(FB.Error, 'Aucune erreur attendue');
END_TEST

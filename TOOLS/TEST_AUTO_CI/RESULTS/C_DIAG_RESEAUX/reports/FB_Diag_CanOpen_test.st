SETUP
VAR
    FB : FB_Diag_CanOpen;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State doit etre DISABLED sans Enable');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic pret et actif *)
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_EQ(FB.State, E_Diag_State.READY, 'State doit etre READY');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-001 CanOpen : surveillance bus et esclave'
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Bus et esclave sains');
    ASSERT_FALSE(FB.Error, 'Aucune erreur');
END_TEST

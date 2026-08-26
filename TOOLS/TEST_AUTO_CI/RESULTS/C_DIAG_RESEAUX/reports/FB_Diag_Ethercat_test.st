SETUP
VAR
    FB : FB_Diag_Ethercat;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.DISABLED, 'State=DISABLED');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic actif *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.READY, 'State=READY');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.DeviceEthercatMaster.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-010 EtherCAT : surveillance maitre et esclaves'
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'EtherCAT pret');
    ASSERT_FALSE(FB.DeviceEthercatMaster.Error, 'Pas d erreur bus');
    ASSERT_FALSE(FB.DeviceEncoderM1.Error, 'Pas d erreur encoder M1');
END_TEST

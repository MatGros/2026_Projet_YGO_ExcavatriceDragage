SETUP
VAR
    FB : FB_Diag_Ethercat;
END_VAR
END_SETUP

TEST 'Ethercat : Enable=FALSE desactive le diagnostic'
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Ready doit etre FALSE sans Enable');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State doit etre DISABLED sans Enable');
END_TEST

TEST 'Ethercat : Enable=TRUE et Esclaves OK -> Ready et State=READY'
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING, DeviceVariateurSimBypass := FALSE, DeviceEncoderM1SimBypass := FALSE, DeviceEncoderM2SimBypass := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Ready doit etre TRUE avec Enable');
    ASSERT_EQ(FB.State, E_Diag_State.READY, 'State doit etre READY quand tout est OK');
    ASSERT_FALSE(FB.Error, 'Aucune erreur attendue');
END_TEST

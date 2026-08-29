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

(* =========================================================================
   AF-12 — Diagnostic : TC-P12-030 (synthèse par device) & TC-P12-040 (bypass)
   ========================================================================= *)

TEST 'TC-P12-030 EtherCAT : State != RUNNING par device -> bits ErrorId + Error global'
    (* Variateur M3 hors RUNNING -> bit 4 (16#0010), M1/M2 sains *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceVariateur.Error, 'Variateur hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceVariateur.ErrorId, 16#0010, 'Variateur -> ErrorId bit 4 (16#0010)');
    ASSERT_FALSE(FB.DeviceEncoderM1.Error, 'M1 sain -> pas d erreur');
    ASSERT_FALSE(FB.DeviceEncoderM2.Error, 'M2 sain -> pas d erreur');
    ASSERT_TRUE(FB.DeviceEthercatMaster.Error, 'Un device en defaut -> Error maitre=TRUE');

    (* M1 hors RUNNING -> bit 5 (16#0020), variateur/M2 sains *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.STOPPED, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceEncoderM1.Error, 'M1 hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceEncoderM1.ErrorId, 16#0020, 'M1 -> ErrorId bit 5 (16#0020)');
    ASSERT_FALSE(FB.DeviceVariateur.Error, 'Variateur sain -> pas d erreur');

    (* M2 hors RUNNING -> 16#0030 (bug T159 documente, pas 16#0040) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.STOPPED,
       NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.DeviceEncoderM2.Error, 'M2 hors RUNNING -> Error=TRUE');
    ASSERT_EQ(FB.DeviceEncoderM2.ErrorId, 16#0030, 'M2 -> ErrorId 16#0030 (bug T159 documente)');
END_TEST

TEST 'TC-P12-040 EtherCAT : bypass sim/reseau vs etat reel (READY/SIMULATED/DISABLED)'
    (* Reel RUNNING sans bypass -> READY *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.READY, 'Reel RUNNING sans bypass -> READY');

    (* Bypass sans device reel -> SIMULATED *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := TRUE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.SIMULATED, 'Bypass sans device reel -> SIMULATED');

    (* Ni l un ni l autre -> ERROR (fiche attend INIT, code produit ERROR -- ecart documente AF12 TBD) *)
    FB(Enable := TRUE, DeviceVariateurStateRaw := DEVICE_STATE.STOPPED,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING,
       NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.ERROR, 'Ni bypass ni reel -> ERROR (ecart fiche INIT)');

    (* Enable=FALSE prioritaire -> DISABLED *)
    FB(Enable := FALSE, DeviceVariateurStateRaw := DEVICE_STATE.RUNNING,
       DeviceEncoderM1StateRaw := DEVICE_STATE.RUNNING, DeviceEncoderM2StateRaw := DEVICE_STATE.RUNNING);
    ASSERT_EQ(FB.DeviceVariateur.State, E_Diag_State.DISABLED, 'Enable=FALSE -> DISABLED');
END_TEST

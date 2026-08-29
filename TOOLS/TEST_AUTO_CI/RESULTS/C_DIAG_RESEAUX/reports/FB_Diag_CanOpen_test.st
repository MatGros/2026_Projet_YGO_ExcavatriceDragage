SETUP
VAR
    FB : FB_Diag_CanOpen;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_EQ(FB.DeviceCanOpenMaster.State, E_Diag_State.DISABLED, 'State doit etre DISABLED sans Enable');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic pret et actif *)
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_EQ(FB.DeviceCanOpenMaster.State, E_Diag_State.READY, 'State doit etre READY');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
    ASSERT_EQ(FB.DeviceCanOpenMaster.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-001 CanOpen : surveillance bus et esclave'
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Bus et esclave sains');
    ASSERT_FALSE(FB.DeviceCanOpenMaster.Error, 'Aucune erreur bus maitre');
    ASSERT_FALSE(FB.DeviceJoystick.Error, 'Aucune erreur joystick');
END_TEST

(* =========================================================================
   AF-12 — Diagnostic : TC-P12-040 (bypass sim/reseau vs etat reel)
   ========================================================================= *)

TEST 'TC-P12-040 CanOpen : bypass sim/reseau vs etat reel (READY/SIMULATED/DISABLED)'
    (* Reel RUNNING sans bypass -> READY *)
    FB(Enable := TRUE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceJoystick.State, E_Diag_State.READY, 'Reel RUNNING sans bypass -> READY');

    (* Bypass sans device reel -> SIMULATED *)
    FB(Enable := TRUE, CANbusStateRaw := 0, DeviceJoystickStateRaw := DEVICE_STATE.STOPPED,
       SimBypassActive := TRUE, NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceJoystick.State, E_Diag_State.SIMULATED, 'Bypass sans device reel -> SIMULATED');

    (* Ni l un ni l autre -> ERROR (fiche attend INIT, code produit ERROR -- ecart documente AF12 TBD) *)
    FB(Enable := TRUE, CANbusStateRaw := 0, DeviceJoystickStateRaw := DEVICE_STATE.STOPPED,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_EQ(FB.DeviceJoystick.State, E_Diag_State.ERROR, 'Ni bypass ni reel -> ERROR (ecart fiche INIT)');

    (* Enable=FALSE prioritaire -> DISABLED *)
    FB(Enable := FALSE, CANbusStateRaw := 2, DeviceJoystickStateRaw := DEVICE_STATE.RUNNING);
    ASSERT_EQ(FB.DeviceJoystick.State, E_Diag_State.DISABLED, 'Enable=FALSE -> DISABLED');
END_TEST

SETUP
VAR
    FB : FB_Diag_IhmHeartbeat;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, HeartbeatIn := 0, TimeoutCfg := T#2S);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State=DISABLED');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic pret *)
    FB(Enable := TRUE, HeartbeatIn := 1, TimeoutCfg := T#2S);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, HeartbeatIn := 1, TimeoutCfg := T#2S);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-020 IHM Heartbeat : detection activite'
    FB(Enable := TRUE, HeartbeatIn := 1, TimeoutCfg := T#2S);
    ASSERT_TRUE(FB.Ready, 'Heartbeat IHM valide');
END_TEST

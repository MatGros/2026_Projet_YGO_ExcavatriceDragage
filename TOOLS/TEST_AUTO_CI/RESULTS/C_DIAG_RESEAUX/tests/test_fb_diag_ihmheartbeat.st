SETUP
VAR
    FB : FB_Diag_IhmHeartbeat;
END_VAR
END_SETUP

TEST 'IhmHeartbeat : Enable=FALSE desactive la surveillance'
    FB(Enable := FALSE, TglHeartbeatIhm := FALSE);
    ASSERT_FALSE(FB.HeartbeatIhmOk, 'HeartbeatIhmOk doit etre FALSE');
    ASSERT_TRUE(FB.HeartbeatIhmTimeout, 'HeartbeatIhmTimeout doit etre TRUE');
END_TEST

TEST 'IhmHeartbeat : Front recu -> HeartbeatIhmOk=TRUE'
    FB(Enable := TRUE, TglHeartbeatIhm := FALSE);
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'HeartbeatIhmOk doit etre TRUE suite au front');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'Pas de timeout');
END_TEST

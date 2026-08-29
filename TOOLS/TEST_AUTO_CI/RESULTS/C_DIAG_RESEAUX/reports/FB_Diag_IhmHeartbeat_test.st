SETUP
VAR
    FB : FB_Diag_IhmHeartbeat;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition HeartbeatIhmOk, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, TglHeartbeatIhm := FALSE, IhmTimeout := T#2s);
    ASSERT_FALSE(FB.HeartbeatIhmOk, 'Enable=FALSE -> HeartbeatIhmOk=FALSE');
    ASSERT_TRUE(FB.HeartbeatIhmTimeout, 'Enable=FALSE -> HeartbeatIhmTimeout=TRUE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE, premier front toggle IHM -> Diagnostic OK *)
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'Enable=TRUE + edge -> HeartbeatIhmOk=TRUE');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'HeartbeatIhmTimeout=FALSE');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s);
    ASSERT_FALSE(FB.HeartbeatIhmOk, 'Coupure -> HeartbeatIhmOk retombe a FALSE');
    ASSERT_TRUE(FB.HeartbeatIhmTimeout, 'Coupure -> Timeout=TRUE');
END_TEST

TEST 'TC-P12-020 IHM Heartbeat : surveillance timeout apres 2s sans front'
    (* 1. Initialisation avec front IHM *)
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'Heartbeat IHM valide initialement');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'Pas de timeout');

    (* 2. Scan suivant : pas de front, le timer de surveillance démarre *)
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s);

    (* 3. Avance dans le temps de 2.5s sans nouveau front *)
    ADVANCE_TIME(2500000000);
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s);
    ASSERT_FALSE(FB.HeartbeatIhmOk, 'Heartbeat IHM tombe en echec apres timeout');
    ASSERT_TRUE(FB.HeartbeatIhmTimeout, 'HeartbeatIhmTimeout leve');

    (* 4. Reprise du toggle IHM -> Retabli *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, TglHeartbeatIhm := FALSE, IhmTimeout := T#2s);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'Heartbeat IHM retabli apres nouveau front');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'HeartbeatIhmTimeout retombe a FALSE');
END_TEST

(* =========================================================================
   AF-12 — Diagnostic : TC-P12-050 (timeout -> HeartbeatIhmTimeout + TimeSinceIhmEdge)
   ========================================================================= *)

TEST 'TC-P12-050 IHM Heartbeat : timeout -> HeartbeatIhmTimeout + TimeSinceIhmEdge, reprise sur front'
    (* 1. Front IHM initial -> OK *)
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s, PlcTogglePeriod := T#500ms);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'Front initial -> HeartbeatIhmOk=TRUE');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'Pas de timeout');

    (* 2. Scan suivant sans front -> timer de surveillance demarre *)
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s, PlcTogglePeriod := T#500ms);

    (* 3. Avance 2.5s sans front -> timeout, TimeSinceIhmEdge = IhmTimeout *)
    ADVANCE_TIME(2500000000);
    FB(Enable := TRUE, TglHeartbeatIhm := TRUE, IhmTimeout := T#2s, PlcTogglePeriod := T#500ms);
    ASSERT_TRUE(FB.HeartbeatIhmTimeout, 'Timeout apres 2s sans front');
    ASSERT_FALSE(FB.HeartbeatIhmOk, 'HeartbeatIhmOk=FALSE sous timeout');
    ASSERT_EQ(FB.TimeSinceIhmEdge, T#2s, 'TimeSinceIhmEdge = IhmTimeout (2s)');

    (* 4. Nouveau front -> restaure immediatement, TimeSinceIhmEdge repart de 0 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, TglHeartbeatIhm := FALSE, IhmTimeout := T#2s, PlcTogglePeriod := T#500ms);
    ASSERT_TRUE(FB.HeartbeatIhmOk, 'Nouveau front -> HeartbeatIhmOk restaure');
    ASSERT_FALSE(FB.HeartbeatIhmTimeout, 'Timeout retombe');
    ASSERT_EQ(FB.TimeSinceIhmEdge, T#0s, 'TimeSinceIhmEdge repart de 0');
END_TEST

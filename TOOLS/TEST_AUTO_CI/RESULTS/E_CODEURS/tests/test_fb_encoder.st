SETUP
VAR
    fb    : FB_Encoder;
    calib : ST_Encoder_Calib;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    fb(Enable := FALSE, Calib := calib);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    fb(Enable := TRUE, Calib := calib);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    fb(Enable := FALSE, Calib := calib);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P09-010 Acquisition codeur : mise en service nominale'
    fb(Enable := TRUE, PointsPerRev := 4096, CableM_PerRev := 0.5, PositionMinM := -50.0, PositionMaxM := 50.0, Calib := calib);
    ASSERT_TRUE(fb.Ready, 'Codeur actif et pret');
END_TEST

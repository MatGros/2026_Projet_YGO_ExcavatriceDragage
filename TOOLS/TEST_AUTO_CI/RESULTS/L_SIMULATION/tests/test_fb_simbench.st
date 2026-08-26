SETUP
VAR
    FB_Bench : FB_SimBench;
    FB_SimEnc : FB_Sim_Encoder;
    FB_SimJoy : FB_Sim_Joystick;
    FB_SimSafe : FB_Sim_Safety;
    FB_SimTrans : FB_Sim_Translation;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB_Bench(Enable := FALSE);
    ASSERT_FALSE(FB_Bench.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> SimBench actif *)
    FB_Bench(Enable := TRUE);
    ASSERT_TRUE(FB_Bench.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB_Bench(Enable := FALSE);
    ASSERT_FALSE(FB_Bench.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P13-001 Sim_Safety : neutralisation sans Enable'
    FB_SimSafe(Enable := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'AU non ferme');
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'Contacteur coupe');
END_TEST

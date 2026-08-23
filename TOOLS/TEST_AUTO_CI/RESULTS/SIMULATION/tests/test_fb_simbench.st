SETUP
VAR
    FB_Bench : FB_SimBench;
    FB_SimEnc : FB_Sim_Encoder;
    FB_SimJoy : FB_Sim_Joystick;
    FB_SimSafe : FB_Sim_Safety;
    FB_SimTrans : FB_Sim_Translation;
END_VAR
END_SETUP

TEST 'SimBench : instanciation et neutralisation sans Enable'
    FB_Bench(Enable := FALSE);
    ASSERT_FALSE(FB_Bench.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'Sim_Safety : neutralisation sans Enable'
    FB_SimSafe(Enable := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'AU non ferme');
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'Contacteur coupe');
END_TEST

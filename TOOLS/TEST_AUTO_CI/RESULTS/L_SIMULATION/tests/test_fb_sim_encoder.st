(* =======================================================================
   Automated Unit Test - FB_Sim_Encoder
   ======================================================================= *)
TEST 'TC-P13-ENC-001 Enable FALSE conserve la valeur passee par VAR_IN_OUT'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
END_VAR
    fb.Enable := FALSE;
    fb.StepNumber := 3;
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 1000, 'Enable FALSE -> RawPosOut conserve la valeur persistee');
END_TEST

TEST 'TC-P13-ENC-002 Simulation incrementation comptage en montee'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
    i      : INT;
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE; (* Sens montee *)
    fb.RelayRev := FALSE;
    fb.StepNumber := 3;
    
    FOR i := 1 TO 10 DO
        fb(RawPos := rawPos);
    END_FOR;
    
    ASSERT_TRUE(fb.RawPosOut > 1000, 'RelayFwd TRUE -> RawPosOut augmente');
END_TEST

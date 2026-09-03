(* =======================================================================
   Automated Unit Test - FB_Sim_Translation
   ======================================================================= *)
TEST 'TC-P13-TR-001 Enable FALSE -> capteurs tous a zero'
VAR
    fb : FB_Sim_Translation;
END_VAR
    fb.Enable := FALSE;
    fb();
    ASSERT_FALSE(fb.PosTremie, 'Enable FALSE -> PosTremie FALSE');
    ASSERT_FALSE(fb.PosMaintenance, 'Enable FALSE -> PosMaintenance FALSE');
END_TEST

TEST 'TC-P13-TR-002 Position initiale a Tremie (mot 11111)'
VAR
    fb : FB_Sim_Translation;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    FOR i := 1 TO 5 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.PosTremie, 'Init -> PosTremie TRUE (mot 11111)');
    ASSERT_TRUE(fb.PosPV, 'Init -> PosPV TRUE');
    ASSERT_TRUE(fb.PosP2, 'Init -> PosP2 TRUE');
    ASSERT_TRUE(fb.PosP1, 'Init -> PosP1 TRUE');
    ASSERT_TRUE(fb.PosMaintenance, 'Init -> PosMaintenance TRUE');
END_TEST

(* =======================================================================
   Automated Unit Test - FB_Sim_Joystick
   ======================================================================= *)
TEST 'TC-P13-JOY-001 Enable FALSE -> positionne les axes au neutre (5000)'
VAR
    fb : FB_Sim_Joystick;
END_VAR
    fb.Enable := FALSE;
    fb();
    ASSERT_EQ(fb.RawX, 5000, 'Enable FALSE -> RawX au neutre NeutralRaw=5000');
    ASSERT_EQ(fb.RawY, 5000, 'Enable FALSE -> RawY au neutre NeutralRaw=5000');
    ASSERT_FALSE(fb.RawButton, 'Enable FALSE -> RawButton FALSE');
END_TEST

TEST 'TC-P13-JOY-002 Simulation appui bouton directionnel et dynamique'
VAR
    fb : FB_Sim_Joystick;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.BtnFwd_Up_Close := TRUE; (* Commande montee *)
    
    FOR i := 1 TO 20 DO
        fb();
    END_FOR;
    
    ASSERT_TRUE(fb.RawButton, 'Bouton actif -> RawButton TRUE (Homme-mort simule)');
    ASSERT_TRUE(fb.RawY > 5000, 'BtnFwd -> RawY monte vers MaxRaw');
END_TEST

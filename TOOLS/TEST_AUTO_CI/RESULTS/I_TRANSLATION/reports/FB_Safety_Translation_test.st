(* =======================================================================
   Automated Unit Test - FB_Safety_Translation
   ======================================================================= *)
TEST 'TC-P11-SAF-001 Dynamique Enable : neutralisation initiale, transition Ready, coupure'
VAR
    fb : FB_Safety_Translation;
    i  : INT;
END_VAR
    (* Enable FALSE *)
    fb.Enable := FALSE;
    fb.PhaseRotationOk := TRUE;
    fb();
    ASSERT_FALSE(fb.Ready, 'Enable FALSE -> Ready FALSE');
    ASSERT_FALSE(fb.SafeStop, 'Enable FALSE -> SafeStop FALSE');
    ASSERT_FALSE(fb.PowerCutOff, 'Enable FALSE -> PowerCutOff FALSE');

    (* Enable TRUE nominal *)
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.HeartbeatIhmOk := TRUE;
    fb.JoystickOnline := TRUE;
    fb.JoystickOperational := TRUE;
    fb.PhaseRotationOk := TRUE;
    fb.DriveOnline := TRUE;
    fb.DriveOperational := TRUE;
    
    FOR i := 1 TO 350 DO
        fb();
    END_FOR;
    
    ASSERT_TRUE(fb.Ready, 'Conditions nominales post-warmup -> Ready TRUE');
    ASSERT_FALSE(fb.Fault.Latched, 'Nominal -> Pas de defaut latche');
    ASSERT_FALSE(fb.SafeStop, 'Nominal -> SafeStop FALSE');
END_TEST

TEST 'TC-P11-SAF-002 Defaut rotation de phase (defaut process sans PowerCutOff)'
VAR
    fb : FB_Safety_Translation;
    i  : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.HeartbeatIhmOk := TRUE;
    fb.JoystickOnline := TRUE;
    fb.JoystickOperational := TRUE;
    fb.PhaseRotationOk := TRUE;
    fb.DriveOnline := TRUE;
    fb.DriveOperational := TRUE;
    
    FOR i := 1 TO 350 DO
        fb();
    END_FOR;
    
    (* Defaut rotation de phase *)
    fb.PhaseRotationOk := FALSE;
    fb();
    fb();
    
    ASSERT_TRUE(fb.SafeStop, 'Mauvaise rotation phases -> SafeStop TRUE');
    ASSERT_FALSE(fb.PowerCutOff, 'Mauvaise rotation phases -> Pas de PowerCutOff');
    ASSERT_TRUE(fb.ErrorPhaseRotation, 'Mauvaise rotation phases -> ErrorPhaseRotation TRUE');
END_TEST

TEST 'TC-P11-SAF-003 Surchauffe thermique frein -> SafeStop + PowerCutOff (defaut dur)'
VAR
    fb : FB_Safety_Translation;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.HeartbeatIhmOk := TRUE;
    fb.JoystickOnline := TRUE;
    fb.JoystickOperational := TRUE;
    fb.PhaseRotationOk := TRUE;
    fb.DriveOnline := TRUE;
    fb.DriveOperational := TRUE;
    fb.BrakeThermalFeedback := TRUE; (* Defaut thermique frein *)
    fb();
    fb();
    ASSERT_TRUE(fb.SafeStop, 'Thermique frein -> SafeStop TRUE');
    ASSERT_TRUE(fb.PowerCutOff, 'Thermique frein -> PowerCutOff TRUE (securite materielle)');
    ASSERT_TRUE(fb.Fault.Latched, 'Thermique frein -> Defaut latche');
END_TEST

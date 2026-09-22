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

TEST 'TC-T300-SAF-060 Arret FDC sans requete persistante ne declenche pas l escalade'
VAR
    fb : FB_Safety_Translation;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.HeartbeatIhmOk := TRUE;
    fb.JoystickOnline := TRUE;
    fb.JoystickOperational := TRUE;
    fb.PhaseRotationOk := TRUE;
    fb.DriveOnline := TRUE;
    fb.DriveOperational := TRUE;
    fb.DriveStatusWord := 16#0080; (* Variateur arrete, bit0 inactif, frequence nulle *)
    fb.DriveActualFreqHz := 0.0;
    fb.LimitSwitchMaintenance := TRUE;
    fb.ReqMaintenance := FALSE;
    fb.RunRequest := FALSE;
    fb.BrakeCmd := FALSE;
    fb.BrakeFeedback := FALSE;
    fb();
    ADVANCE_TIME(1600000000); (* 1,6 s : au-dela de l escalade FDC 1,5 s *)
    fb();
    ASSERT_FALSE(fb.ErrorLimitSwitch, 'FDC atteint et variateur pret sans requete : aucune escalade');
    ASSERT_FALSE(fb.PowerCutOff, 'Arret final normal ne coupe pas la puissance');
END_TEST

TEST 'TC-T300-SAF-061 Requete persistante au FDC escalade meme frequence nulle'
VAR
    fb : FB_Safety_Translation;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.HeartbeatIhmOk := TRUE;
    fb.JoystickOnline := TRUE;
    fb.JoystickOperational := TRUE;
    fb.PhaseRotationOk := TRUE;
    fb.DriveOnline := TRUE;
    fb.DriveOperational := TRUE;
    fb.DriveStatusWord := 16#0081; (* Bit0 de marche/pret maintenu pour caracteriser l escalade *)
    fb.DriveActualFreqHz := 0.0;
    fb.LimitSwitchMaintenance := TRUE;
    fb.ReqMaintenance := TRUE;
    fb.RunRequest := TRUE;
    fb.BrakeCmd := FALSE;
    fb.BrakeFeedback := FALSE;
    fb();
    ADVANCE_TIME(1600000000); (* 1,6 s : au-dela de l escalade FDC 1,5 s *)
    fb();
    ASSERT_TRUE(fb.ErrorLimitSwitch, 'Requete maintenance maintenue au FDC -> escalade apres 1,5 s');
    ASSERT_EQ(fb.Fault.ErrorId, 16#0040, 'Cause 6 seule = ErrorId 64');
    ASSERT_TRUE(fb.PowerCutOff, 'Escalade FDC est une coupure puissance');
END_TEST

TEST 'TC-T386-M3-001 Defaut rotation de phase M3 => PowerCutOff (ROUGE avant / VERT apres)'
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
    (* Etat nominal stable : aucun defaut *)
    ASSERT_FALSE(fb.Fault.Latched, 'Nominal -> pas de defaut latche');
    ASSERT_FALSE(fb.PowerCutOff, 'Nominal -> PowerCutOff FALSE');
    (* Defaut rotation de phase : comportement CIBLE (lot T386) : coupure de puissance *)
    fb.PhaseRotationOk := FALSE;
    fb();
    fb();
    ASSERT_TRUE(fb.SafeStop, 'Defaut rotation phases -> SafeStop TRUE');
    ASSERT_TRUE(fb.PowerCutOff, 'Defaut rotation phases -> PowerCutOff TRUE (cible T386)');
    ASSERT_TRUE(fb.ErrorPhaseRotation, 'Defaut rotation phases -> ErrorPhaseRotation TRUE');
    (* Verrouillage : retour a TRUE sans front Reset => le defaut reste verrouille *)
    fb.PhaseRotationOk := TRUE;
    fb();
    fb();
    ASSERT_FALSE(fb.Reset, 'Pas de Reset');
    ASSERT_TRUE(fb.Fault.Latched, 'Retour phase OK sans Reset -> reste verrouille (pas de rearmement auto)');
END_TEST


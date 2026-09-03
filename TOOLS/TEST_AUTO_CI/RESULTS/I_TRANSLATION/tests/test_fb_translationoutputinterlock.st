(* =======================================================================
   Automated Unit Test - FB_TranslationOutputInterlock
   ======================================================================= *)
TEST 'TC-P11-INT-001 Enable FALSE coupe consignes variateur et ordre frein'
VAR
    fb : FB_TranslationOutputInterlock;
END_VAR
    fb.Enable := FALSE;
    fb.RequestedDriveControlWord := 1; (* Fwd *)
    fb.RequestedDriveFreqHz := 50.0;
    fb.BrakeReleaseRequest := TRUE;
    fb();
    ASSERT_FALSE(fb.Ready, 'Enable FALSE -> Ready FALSE');
    ASSERT_EQ(fb.DriveControlWord, 0, 'Enable FALSE -> Mot variateur 0');
    ASSERT_EQ(fb.DriveFreqCmd_Hz, 0.0, 'Enable FALSE -> Frequence 0.0');
    ASSERT_FALSE(fb.BrakeCmd, 'Enable FALSE -> Frein non desserre');
END_TEST

TEST 'TC-P11-INT-002 Blocage sens sans permis directionnel (fail-safe)'
VAR
    fb : FB_TranslationOutputInterlock;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.EffectivePermitM3_Tremie := FALSE; (* Permis Tremie refuse *)
    fb.RequestedDriveControlWord := 1; (* Demande Fwd Tremie *)
    fb.RequestedDriveFreqHz := 25.0;
    fb();
    ASSERT_EQ(fb.DriveControlWord, 0, 'Permis Tremie FALSE -> Mot bloque a 0');
    ASSERT_EQ(fb.DriveFreqCmd_Hz, 0.0, 'Permis Tremie FALSE -> Frequence bloquee a 0.0');
END_TEST

TEST 'TC-P11-INT-003 Mouvement nominal autorise avec permis et confirmation frein'
VAR
    fb : FB_TranslationOutputInterlock;
END_VAR
    fb.Enable := TRUE;
    fb.PowerContactorEngaged := TRUE;
    fb.EffectivePermitM3_Tremie := TRUE;
    fb.BrakeReleaseRequest := TRUE;
    fb.BrakeCommandOpenConfirmed := TRUE; (* Frein ouvert confirme *)
    fb.RequestedDriveControlWord := 1; (* Fwd Tremie *)
    fb.RequestedDriveFreqHz := 30.0;
    fb();
    ASSERT_TRUE(fb.Ready, 'Conditions OK -> Ready TRUE');
    ASSERT_EQ(fb.DriveControlWord, 1, 'Permis OK + Frein OK -> Mot Fwd emis');
    ASSERT_EQ(fb.DriveFreqCmd_Hz, 30.0, 'Permis OK + Frein OK -> Frequence 30.0');
    ASSERT_TRUE(fb.BrakeCmd, 'BrakeReleaseRequest -> BrakeCmd TRUE');
END_TEST

SETUP
VAR
    harness   : FB_TestHarness_PRG_05;
    acqData   : ST_AcquisitionInterPrg;
    modesAuth : ST_Modes_Autorisations;
END_VAR
END_SETUP

TEST 'PRG_05_Translation : Commande Translation Fwd (Joystick X + Hauteur Treuils OK)'
    // 1. Contexte : Mode Manuel N1, Câbles treuils hauts (sécurité interlock hauteur validée)
    modesAuth.Mode := E_Mode.MAINT_N1;
    
    // 2. Stimulus issu du bus PRG_02 : Joystick armé vers la droite (+X)
    acqData.JoystickDeadmanArmed := TRUE;
    acqData.JoystickDirectionX := 1;
    acqData.JoystickSpeedPctX := 75.0;
    acqData.M3_LimitSwitchFwd := FALSE; // Non en butée
    acqData.M3_LimitSwitchRev := FALSE;
    acqData.TranslationAtPV := FALSE;
    acqData.TranslationAtP1 := FALSE;
    acqData.TranslationAtP2 := FALSE;

    
    // 3. Exécution PRG_05 (3 scans : 1=FirstScanDone, 2=CommandedDirection, 3=SpeedRamp/Brake)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );


    
    // 4. Vérification du bus sortant ST_TranslationInterPrg vers PRG_06
    ASSERT_TRUE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Demande desserrage frein M3 generee');
    ASSERT_FALSE(harness.Data.TranslationSafety.SafeStop, 'Aucun SafeStop actif sur translation');
    ASSERT_EQ(harness.Data.TranslationState.ActiveDirection, 1, 'Sens translation avant arbitre');
END_TEST

TEST 'PRG_05_Translation : Interdiction Mouvement Translation si Treuils en Bas'
    // Stimulus : Treuil M1 descendu trop bas (< 2m)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 0.5,
        WinchM2CablePosM := 5.0,
        PowerContactorEngaged := TRUE
    );
    
    // Vérification : mouvement bloqué par l'interlock de hauteur
    ASSERT_FALSE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Frein reste serre');
    ASSERT_EQ(harness.Data.TranslationState.ActiveDirection, 0, 'Mouvement interdit');
END_TEST


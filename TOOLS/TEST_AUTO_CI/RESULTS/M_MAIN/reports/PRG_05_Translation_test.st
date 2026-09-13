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
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := 1;
    acqData.Joystick.AxisX.SpeedTgt := 75.0;
    
    // 3. Exécution PRG_05 (Position P2/P1/Maintenance = mot valide 00111, ni butée Trémie ni butée Maintenance)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ADVANCE_TIME(1000000000);
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE,
        M3_PosPV_DI := FALSE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );


    
    // 4. Vérification du bus sortant ST_TranslationInterPrg vers PRG_06
    ASSERT_TRUE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Demande desserrage frein M3 generee');
    ASSERT_FALSE(harness.Data.TranslationSafety.SafeStop, 'Aucun SafeStop actif sur translation');
    ASSERT_TRUE(harness.Data.TranslationState.ActiveTremie, 'Sens translation avant arbitre');
    ASSERT_GT(harness.Data.TranslationState.SpeedCmd_Pct, 0.0, 'Consigne vitesse M3 arbitree non nulle');
    ASSERT_NEQ(harness.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord, 16#0000, 'ControlWord variateur active pendant la commande');
END_TEST

TEST 'PRG_05_Translation : Commande Translation Rev (Joystick X negatif)'
    modesAuth.Mode := E_Mode.MAINT_N1;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := -1;
    acqData.Joystick.AxisX.SpeedTgt := 60.0;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ADVANCE_TIME(1000000000);
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchM1CablePosM := 5.0,
        WinchM2CablePosM := 5.0,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE,
        DriveOnline := TRUE,
        DriveOperational := TRUE
    );
    ASSERT_TRUE(harness.Data.TranslationState.ActiveMaintenance, 'Sens translation arriere arbitre');
    ASSERT_TRUE(harness.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest, 'Frein M3 desserre en arriere');
    ASSERT_FALSE(harness.Data.TranslationSafety.SafeStop, 'Aucun SafeStop en commande arriere nominale');
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
    ASSERT_FALSE(harness.Data.TranslationState.ActiveTremie, 'Mouvement interdit');
    ASSERT_FALSE(harness.Data.TranslationState.ActiveMaintenance, 'Mouvement interdit');
END_TEST


TEST 'PRG_05_Translation : FdC Tremie LATCHE - un rebond capteur ne libere pas (guard REX MES 2026-09-04)'
    // REGRESSION : un rebond du capteur de butee Tremie (mot 11111 -> 01111 -> 11111)
    // ne doit JAMAIS liberer le bistable M3_LimitSwitchTremieStable ni reautoriser la
    // translation vers la Tremie. On ne perd la butee QU'EN commandant le sens inverse.
    modesAuth.Mode := E_Mode.MAINT_N1;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisX.Direction := 0;
    acqData.Joystick.AxisX.SpeedTgt := 0.0;

    // 1. Pont sur la butee Tremie : mot 11111 -> bistable latche
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ADVANCE_TIME(500000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Butee Tremie latchee sur mot 11111');

    // 2. REBOND capteur Tremie : DI tombe 2 scans (mot 01111), AUCUNE commande sens inverse
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Rebond capteur -> butee Tremie RESTE latchee (pas de flicker autorisation)');

    // 3. Capteur revient : toujours latche
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := TRUE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_TRUE(harness.Data.TranslationState.LimitSwitchTremie, 'Capteur revenu -> toujours latchee');

    // 4. Commande SENS INVERSE (Maintenance, joystick X negatif) -> liberation legitime
    acqData.Joystick.AxisX.Direction := -1;
    acqData.Joystick.AxisX.SpeedTgt := 50.0;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchM1CablePosM := 5.0, WinchM2CablePosM := 5.0,
        M3_PosTremie_DI := FALSE, M3_PosPV_DI := TRUE, M3_PosPVP2_DI := TRUE, M3_PosP1_DI := TRUE, M3_PosMaintenance_DI := TRUE,
        PowerContactorEngaged := TRUE, DriveOnline := TRUE, DriveOperational := TRUE);
    ASSERT_FALSE(harness.Data.TranslationState.LimitSwitchTremie, 'Commande sens inverse (Maintenance) -> butee Tremie liberee');
END_TEST

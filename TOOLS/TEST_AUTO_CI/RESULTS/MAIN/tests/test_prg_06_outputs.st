SETUP
VAR
    harness         : FB_TestHarness_PRG_06;
    winchData       : ST_WinchInterPrg;
    translationData : ST_TranslationInterPrg;
END_VAR
END_SETUP

TEST 'PRG_06_Outputs : Transmission Ordres M1 et M3 en Marche Normale'
    // 1. Contexte M1 : Demande de montée active avec contacteur 1
    winchData.WinchM1FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM1FinalInterlockRequest.SafeStop := FALSE;
    winchData.WinchM1FinalInterlockRequest.PowerCutOff := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedContactor1 := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedStep := 1;
    winchData.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := TRUE;

    
    // 2. Contexte M3 : Demande de frein relâché
    translationData.TranslationFinalInterlockRequest.Enable := TRUE;
    translationData.TranslationFinalInterlockRequest.PowerContactorEngaged := TRUE;
    translationData.TranslationFinalInterlockRequest.SafeStop := FALSE;
    translationData.TranslationFinalInterlockRequest.PowerCutOff := FALSE;
    translationData.TranslationFinalInterlockRequest.BrakeReleaseRequest := TRUE;
    
    // 3. Exécution PRG_06
    harness(
        WinchData := winchData,
        TranslationData := translationData
    );
    
    // 4. Vérification des sorties réelles sur le bus ST_OutputsInterPrg
    ASSERT_TRUE(harness.Data.M1RelayFwd, 'Contacteur montee M1 active');
    ASSERT_TRUE(harness.Data.M1SpeedContactor1, 'Palier 1 M1 active');
    ASSERT_TRUE(harness.Data.M1BrakeCmd, 'Commande desserrage frein M1 active');
    ASSERT_TRUE(harness.Data.TranslationBrakeCmd, 'Commande desserrage frein M3 active');
END_TEST

TEST 'PRG_06_Outputs : Barriere de Securite Coupure Brutale PowerCutOff sur M1'
    // Stimulus : Demande de montée avec PowerCutOff actif sur M1
    winchData.WinchM1FinalInterlockRequest.PowerCutOff := TRUE;
    
    harness(
        WinchData := winchData,
        TranslationData := translationData
    );
    
    // Vérification : toutes les sorties M1 doivent être immédiatement neutralisées
    ASSERT_FALSE(harness.Data.M1RelayFwd, 'Relais montee M1 coupe');
    ASSERT_FALSE(harness.Data.M1SpeedContactor1, 'Contacteurs vitesse M1 coupes');
    ASSERT_FALSE(harness.Data.M1BrakeCmd, 'Frein M1 retombe');
END_TEST

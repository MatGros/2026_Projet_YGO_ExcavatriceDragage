SETUP
VAR
    harness         : FB_TestHarness_PRG_06;
    winchData       : ST_WinchInterPrg;
    translationData : ST_TranslationInterPrg;
END_VAR
END_SETUP

TEST 'PRG_06_Outputs : Transmission Ordres M1 et M3 en Marche Normale'
    // 1. Contexte M1 : Demande de montee active palier 1
    winchData.WinchM1FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM1FinalInterlockRequest.SafeStop := FALSE;
    winchData.WinchM1FinalInterlockRequest.PowerCutOff := FALSE;
    winchData.WinchM1FinalInterlockRequest.AscentPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.DescendPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.BrakeFeedback := TRUE;
    winchData.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayRev := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedContactor1 := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedStep := 1;
    
    // 2. Contexte M3 : Demande de frein relache
    translationData.TranslationFinalInterlockRequest.Enable := TRUE;
    translationData.TranslationFinalInterlockRequest.PowerContactorEngaged := TRUE;
    translationData.TranslationFinalInterlockRequest.SafeStop := FALSE;
    translationData.TranslationFinalInterlockRequest.PowerCutOff := FALSE;
    translationData.TranslationFinalInterlockRequest.BrakeReleaseRequest := TRUE;

    harness(WinchData := winchData, TranslationData := translationData);
    
    // 3. Verification des sorties reelles sur le bus ST_OutputsInterPrg
    ASSERT_TRUE(harness.Data.M1RelayFwd, 'Contacteur montee M1 active');
    ASSERT_TRUE(harness.Data.M1BrakeCmd, 'Commande desserrage frein M1 active');
    ASSERT_TRUE(harness.Data.TranslationBrakeCmd, 'Commande desserrage frein M3 active');
END_TEST

TEST 'PRG_06_Outputs : Transmission Ordre M2 en Marche Normale'
    // Contexte M2 : Demande de montee (fermeture) active palier 1
    winchData.WinchM2FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM2FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM2FinalInterlockRequest.SafeStop := FALSE;
    winchData.WinchM2FinalInterlockRequest.PowerCutOff := FALSE;
    winchData.WinchM2FinalInterlockRequest.AscentPermit := TRUE;
    winchData.WinchM2FinalInterlockRequest.DescendPermit := TRUE;
    winchData.WinchM2FinalInterlockRequest.BrakeFeedback := TRUE;
    winchData.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := TRUE;
    winchData.WinchM2FinalInterlockRequest.RequestedRelayFwd := TRUE;
    winchData.WinchM2FinalInterlockRequest.RequestedRelayRev := FALSE;
    winchData.WinchM2FinalInterlockRequest.RequestedContactor1 := FALSE;
    winchData.WinchM2FinalInterlockRequest.RequestedStep := 1;

    harness(WinchData := winchData, TranslationData := translationData);

    // Verification sorties M2
    ASSERT_TRUE(harness.Data.M2RelayFwd, 'Contacteur montee (fermeture) M2 active');
    ASSERT_TRUE(harness.Data.M2BrakeCmd, 'Commande desserrage frein M2 active');
END_TEST

TEST 'PRG_06_Outputs : Barriere de Securite Coupure Brutale PowerCutOff sur M1'
    // Stimulus : Commande active MAIS PowerCutOff = TRUE (Arret d'urgence ou defaut critique)
    winchData.WinchM1FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerCutOff := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedContactor1 := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedStep := 1;
    
    harness(
        WinchData := winchData,
        TranslationData := translationData
    );
    
    // Verification : barriere infranchissable, toutes sorties a zero
    ASSERT_FALSE(harness.Data.M1RelayFwd, 'Relais montee coupe');
    ASSERT_FALSE(harness.Data.M1SpeedContactor1, 'Contacteur de vitesse coupe');
    ASSERT_FALSE(harness.Data.M1BrakeCmd, 'Frein M1 force a l arret (non desserre)');
END_TEST

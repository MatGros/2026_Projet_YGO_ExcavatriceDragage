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

TEST 'PRG_06_Outputs : T417-C A1 Feature Latch TOP anti-martelage (descente seule libre, 1 geste refus, Reset ou 3s OK)'
    winchData.WinchM1FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM1FinalInterlockRequest.AscentPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.DescendPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.BrakeFeedback := TRUE;
    winchData.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedStep := 1;

    // 1. Contact TOP actif (DI = FALSE) -> latch arme, montee immediate coupee
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := FALSE);
    ASSERT_TRUE(harness.Data.TopHardStopLatched, 'Contact TOP -> TopHardStopLatched TRUE');
    ASSERT_FALSE(harness.Data.M1RelayFwd, 'Contact TOP -> M1RelayFwd coupe immediatement');

    // 2. Relachement came apres 1 court geste descente (500ms < 3s), sans Reset -> latch persiste et bloque re-montee
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayRev := TRUE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE);
    ASSERT_TRUE(harness.Data.M1RelayRev, 'Descente toujours libre apres contact TOP');
    ADVANCE_TIME(500000000);
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE);
    ASSERT_TRUE(harness.Data.TopHardStopLatched, 'Apres 0.5s descente sans Reset : latch reste arme');

    // Tentative de re-montee (anti-martelage) -> refusee
    winchData.WinchM1FinalInterlockRequest.RequestedRelayRev := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE);
    ASSERT_TRUE(harness.Data.TopHardStopLatched, 'Latch actif tant que non degage');
    ASSERT_FALSE(harness.Data.M1RelayFwd, 'Anti-martelage : re-montee refusee meme came relachee');

    // Reset SUR capteur -> ne doit pas rearmer, puis relachement neutre + frein ferme + Reset HORS capteur
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := FALSE, FaultReset := TRUE);
    ASSERT_TRUE(harness.Data.TopHardStopLatched, 'Reset interdit tant que capteur TOP actif');

    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := FALSE;
    winchData.WinchM1FinalInterlockRequest.BrakeFeedback := FALSE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE, FaultReset := FALSE);
    ADVANCE_TIME(1100000000);
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE, FaultReset := TRUE);
    ASSERT_FALSE(harness.Data.TopHardStopLatched, 'Reset hors capteur -> latch efface');

    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE, FaultReset := FALSE);
    winchData.WinchM1FinalInterlockRequest.BrakeFeedback := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE, FaultReset := FALSE);
    ASSERT_TRUE(harness.Data.M1RelayFwd, 'Apres Reset hors capteur : montee reautorisee');
END_TEST

TEST 'PRG_06_Outputs : T417-C A1 Non-Regression Bypass capteur TOP et descente continue 3s'
    winchData.WinchM1FinalInterlockRequest.Enable := TRUE;
    winchData.WinchM1FinalInterlockRequest.PowerContactorEngaged := TRUE;
    winchData.WinchM1FinalInterlockRequest.AscentPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.DescendPermit := TRUE;
    winchData.WinchM1FinalInterlockRequest.BrakeFeedback := TRUE;
    winchData.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := TRUE;
    winchData.WinchM1FinalInterlockRequest.RequestedStep := 1;

    // 1. Armer latch sur contact TOP
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := FALSE);
    ASSERT_TRUE(harness.Data.TopHardStopLatched, 'Latch arme');

    // 2. Descente continue >= 3s hors capteur -> latch efface sans Reset (compatible HX3 homing)
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayRev := TRUE;
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE);
    ADVANCE_TIME(3100000000);
    harness(WinchData := winchData, TranslationData := translationData, TopPositionFreeDI := TRUE);
    ASSERT_FALSE(harness.Data.TopHardStopLatched, 'Descente soutenue 3s hors capteur efface latch');

    // 3. Capteur bloque actif (casse) + BypassTopLimitSwitch -> montee possible (machine recuperable)
    winchData.WinchM1FinalInterlockRequest.RequestedRelayRev := FALSE;
    winchData.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    harness(WinchData := winchData, TranslationData := translationData,
            TopPositionFreeDI := FALSE, BypassTopLimitSwitch := TRUE);
    ASSERT_TRUE(harness.Data.M1RelayFwd, 'Sous BypassTopLimitSwitch, capteur TOP casse ne bloque pas');
END_TEST

SETUP
VAR
    harness         : FB_TestHarness_PRG_07;
    acqData         : ST_AcquisitionInterPrg;
    modesAuth       : ST_Modes_Autorisations;
    winchData       : ST_WinchInterPrg;
    translationData : ST_TranslationInterPrg;
END_VAR
END_SETUP

TEST 'PRG_07_Supervision : Formatage Bandeau IHM Mode Manuel Sans Defaut'
    // 1. Contexte : Mode Manuel N1
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 0; // Couplé
    
    // 2. Stimulus : Machine saine, puissance engagée
    acqData.JoystickDeadmanArmed := TRUE;
    acqData.JoystickYNeutral := TRUE;
    winchData.WinchM1Safety.DescendPermit := TRUE;
    winchData.WinchM1Safety.AscentPermit := TRUE;
    winchData.WinchM2Safety.DescendPermit := TRUE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    
    // 3. Exécution PRG_07
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE,
        EmergencyChainClosed := TRUE,
        PowerCutOffActive := FALSE
    );
    
    // 4. Vérification de la présence d'un bandeau IHM cohérent
    ASSERT_TRUE(harness.Banner.GlobalContextText <> '', 'Contexte global IHM renseigne');
END_TEST

TEST 'PRG_07_Supervision : Remontee Alarme Bandeau sur SafeStop Treuil'
    // Stimulus : SafeStop actif sur Treuil M1 avec défaut codeur
    winchData.WinchM1Safety.SafeStop := TRUE;
    winchData.WinchM1Safety.Error := TRUE;
    winchData.WinchM1Safety.ErrorEncoder := TRUE;
    winchData.WinchM1Safety.ErrorId := 16#0002; // Perte codeur

    
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE
    );
    
    // Vérification de la notification d'alarme dans le bandeau
    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'Alarme active visible sur le bandeau IHM');
END_TEST


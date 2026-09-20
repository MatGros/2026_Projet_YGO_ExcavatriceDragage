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
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AtNeutralXY := TRUE;
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

TEST 'PRG_07_Supervision : Coupure de Puissance AU (PowerCutOff) visible sur le bandeau'
    // Stimulus : coupure brutale de puissance propagee (PRG_06 -> barriere AU)
    winchData.WinchM1Safety.PowerCutOff := TRUE;
    winchData.WinchM2Safety.PowerCutOff := TRUE;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE,
        PowerCutOffActive := TRUE
    );

    // Coupure de puissance = action operateur PRIORITAIRE sur le bandeau
    // (PowerCutOff alimente OperatorActionText, pas AlarmBanner.HasAlarm qui ne
    //  reflete que les Error* decodes).
    ASSERT_TRUE(harness.Banner.OperatorActionText <> '', 'Action operateur renseignee en coupure puissance');
    ASSERT_TRUE(harness.Banner.GlobalContextText <> '', 'Contexte IHM reste renseigne meme en coupure');
END_TEST

TEST 'PRG_07_Supervision : T255-D limite basse cable M1 visible (alarme + action autorisee)'
    // Etat explicite : les tests precedents ont laisse des defauts dans winchData.
    winchData.WinchM1Safety.Error := TRUE;            // vu par AnyFaultActive (Safety.Error)
    winchData.WinchM1Safety.ErrorId := 16#0040;       // bit6 = limite basse cable (vue LIVE)
    winchData.WinchM1Safety.CableLimitDescent := TRUE;
    winchData.WinchM1Safety.DescendPermit := FALSE;   // interlock : descente interdite
    winchData.WinchM1Safety.AscentPermit := TRUE;     // remontee = action autorisee
    winchData.WinchM1Safety.SafeStop := FALSE;
    winchData.WinchM1Safety.PowerCutOff := FALSE;
    winchData.WinchM1Safety.ErrorEncoder := FALSE;
    winchData.WinchM2Safety.CableLimitDescent := FALSE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    acqData.Joystick.DeadmanArmed := FALSE;           // situation terrain : joystick relache
    acqData.Joystick.AtNeutralXY := TRUE;
    modesAuth.Mode := E_Mode.MAINT_N1;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);
    ADVANCE_TIME(600000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);

    // AC2 : au meme scan, la cause est nommee ET l'action autorisee est indiquee
    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'T255-D : la cause active doit etre au carrousel');
    ASSERT_EQ(harness.Banner.AlarmBanner.Count, 1, 'T255-D : une seule alarme attendue');
    ASSERT_EQ(harness.Banner.AlarmBanner.Text, '1/1 [M1] Limite basse cable atteinte',
              'T255-D : libelle alarme citant le treuil et la limite');
    ASSERT_EQ(harness.Banner.OperatorActionText, '[TREUIL] Limite basse cable M1 - remonter',
              'T255-D : action autorisee (remontee) indiquee sans commande de descente');
END_TEST

TEST 'PRG_07_Supervision : T255-D limite basse cable M2 visible (alarme + action autorisee)'
    winchData.WinchM2Safety.Error := TRUE;
    winchData.WinchM2Safety.ErrorId := 16#0040;
    winchData.WinchM2Safety.CableLimitDescent := TRUE;
    winchData.WinchM2Safety.DescendPermit := FALSE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    winchData.WinchM2Safety.SafeStop := FALSE;
    winchData.WinchM2Safety.PowerCutOff := FALSE;
    winchData.WinchM1Safety.CableLimitDescent := FALSE;
    winchData.WinchM1Safety.AscentPermit := TRUE;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);
    ADVANCE_TIME(600000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);

    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'T255-D : la cause active doit etre au carrousel');
    ASSERT_EQ(harness.Banner.AlarmBanner.Count, 1, 'T255-D : une seule alarme attendue');
    ASSERT_EQ(harness.Banner.AlarmBanner.Text, '1/1 [M2] Limite basse cable atteinte',
              'T255-D : libelle alarme citant le treuil M2 et la limite');
    ASSERT_EQ(harness.Banner.OperatorActionText, '[TREUIL] Limite basse cable M2 - remonter',
              'T255-D : action autorisee indiquee pour M2');
END_TEST


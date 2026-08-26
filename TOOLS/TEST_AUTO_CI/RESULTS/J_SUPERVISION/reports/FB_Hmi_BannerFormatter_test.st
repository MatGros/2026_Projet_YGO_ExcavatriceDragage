SETUP
VAR
    FB_Banner : FB_Hmi_BannerFormatter;
    FB_AntiFlicker : FB_AntiFlickerText;
    WinchM1Safety : ST_SafetyWinch;
    WinchM2Safety : ST_SafetyWinch;
    TranslationSafety : ST_SafetyTranslation;
    NetDiag : ST_NetworkDiagHMI;
END_VAR

// Initialisation réseau tout sain par défaut
NetDiag.InputModules.LocalDigitalIoOk := TRUE;
NetDiag.InputModules.Vh0800EndOk := TRUE;
NetDiag.InputModules.Vh0808EtpOk := TRUE;
NetDiag.InputModules.Vh0008ErOk := TRUE;
NetDiag.InputModules.Vh0008Er1Ok := TRUE;
NetDiag.BusCanOpen.Operational := TRUE;
NetDiag.Joystick.Operational := TRUE;
NetDiag.BusEthercat.Operational := TRUE;
NetDiag.EncoderM1.Operational := TRUE;
NetDiag.EncoderM2.Operational := TRUE;
NetDiag.VariateurM3.Operational := TRUE;
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB_Banner(Enable := FALSE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_EQ(FB_Banner.Banner.GlobalContextText, '', 'Enable=FALSE -> texte vide');

    (* Scan 1 : Enable=TRUE -> Demarrage boot *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ADVANCE_TIME(5000000000); // 5s pour depasser le BootInhibit (4s)

    (* Scan 2 : Formatage actif post-boot *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'Enable=TRUE -> non vide (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Re-neutralisation *)
    FB_Banner(Enable := FALSE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_EQ(FB_Banner.Banner.GlobalContextText, '', 'Coupure -> retombe a texte vide');
END_TEST

TEST 'TC-P07-001 BannerFormatter : formatage nominal bandeau synoptique IHM'
    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );
    ADVANCE_TIME(5000000000); // 5s BootInhibit
    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'GlobalContextText non vide');
END_TEST

TEST 'TC-P07-010 AntiFlickerText : affichage instantane force'
    FB_AntiFlicker(NewText := 'TEST_INSTANT', ForceInstant := TRUE);
    ASSERT_EQ(FB_AntiFlicker.Text, 'TEST_INSTANT', 'Texte instantane');
END_TEST

TEST 'TC-P07-020 RootCause : alarme fille visible quand materiel sain'
    // Boot initial
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    WinchM1Safety.SlackCable := TRUE; // Defaut mou de cable sur DI physique LocalDigitalIO
    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );
    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'Alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1, '1 alarme au carrousel');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [M1] mou de cable', 'Alarme fille correctement affichee');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.AlarmArray[0], '[M1] mou de cable', 'Tableau AlarmArray[0] correctement rempli');
END_TEST

TEST 'TC-P07-021 RootCause : masquage alarme fille sur panne module Local_Digital_IO'
    // Boot initial
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    WinchM1Safety.SlackCable := TRUE; // Mou de cable remonte (etat fail-safe du module HS)
    NetDiag.InputModules.LocalDigitalIoOk := FALSE; // Panne materielle coupleur/carte Local IO

    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );

    // L'alarme fille doit etre masquee, seule l'alarme parente doit apparaitre
    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'Alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1, '1 alarme (parent seul)');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [IO] Defaut module Local IO (DI8/DO8)', 'Alarme parente affichee');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.AlarmArray[0], '[IO] Defaut module Local IO (DI8/DO8)', 'AlarmArray[0] porte le parent');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[IO] Défaut module E/S - vérifier alimentation/coupleur', 'Consigne operateur cible la panne materielle');
END_TEST

TEST 'TC-P07-022 RootCause : masquage alarme fille sur panne module VH0800END'
    // Boot initial
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    WinchM1Safety.ErrorPhaseRotation := TRUE;
    WinchM1Safety.ErrorBrakeThermal := TRUE;
    NetDiag.InputModules.Vh0800EndOk := FALSE; // Panne module VH0800

    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'Alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1, '1 alarme (parent seul)');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [IO] Defaut module VH0800END (DI8)', 'Alarme parente VH0800');
END_TEST

TEST 'TC-P07-023 RootCause : masquage alarme fille sur perte codeur ECAT'
    // Boot initial
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    WinchM1Safety.ErrorEncoder := TRUE;
    WinchM1Safety.CableLimitDescent := TRUE;
    NetDiag.EncoderM1.Operational := FALSE; // Perte com EtherCAT codeur M1

    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'Alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1, '1 alarme (parent seul)');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [M1] Codeur absolu COD1 non detecte (ECAT)', 'Alarme parente codeur M1');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[ECAT] Codeurs non détectés - vérifier liaison', 'Action operateur codeurs');
END_TEST

TEST 'TC-P07-024 Priorite absolue AU sur defaut module E/S'
    // Boot initial
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    NetDiag.InputModules.LocalDigitalIoOk := FALSE;

    FB_Banner(
        Enable := TRUE,
        CurrentMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := FALSE, // AU ouvert
        PowerContactorEngaged := TRUE,
        WinchM1Safety := WinchM1Safety,
        WinchM2Safety := WinchM2Safety,
        Network := NetDiag
    );

    // L'AU reste prioritaire dans la consigne operateur
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[PUPITRE] Boucle urgence ouverte - réarmer', 'AU domine le defaut E/S');
END_TEST


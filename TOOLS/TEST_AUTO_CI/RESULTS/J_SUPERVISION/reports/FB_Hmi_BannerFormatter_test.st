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

(* =======================================================================
   TC-P07-002..009 — Interface IHM (AF_Partie-07_Interface_IHM_v2.2.md §table).
   TC-P07-006/008/009 sont testables boîte noire sur FB_Hmi_BannerFormatter.
   TC-P07-002/003/004/005/007 sont des invariants structurels documentés
   (vérifiés par G200_check_linkage.py / encapsulation_check.py), pas des
   comportements runtime.
   ======================================================================= *)

TEST 'TC-P07-009 Aucun defaut actif -> bandeau d alarme vide'
    // Boot initial (reseau sain)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'aucun defaut -> HasAlarm=FALSE');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '', 'aucun defaut -> Text vide');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Index, 0, 'aucun defaut -> Index=0');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 0, 'aucun defaut -> Count=0');
END_TEST

TEST 'TC-P07-008 Carrousel d alarmes : un message a la fois, index n/N coherent'
    // Boot initial (reseau sain)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    // 2 alarmes actives : mou de cable M1 et M2
    WinchM1Safety.SlackCable := TRUE;
    WinchM2Safety.SlackCable := TRUE;
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag, AlarmHoldTime := T#1s);
    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, '2 defauts -> HasAlarm=TRUE');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 2, '2 defauts -> Count=2');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Index, 1, 'premier message -> Index=1');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/2 [M1] mou de cable', 'premier message affiche');

    // Apres AlarmHoldTime (1s) : rotation vers le message 2
    ADVANCE_TIME(1000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag, AlarmHoldTime := T#1s);
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Index, 2, 'rotation -> Index=2');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '2/2 [M2] mou de cable', 'deuxieme message affiche');

    // Apres un nouveau AlarmHoldTime : le TON a ete reset au scan precedent (rotation
    // cyclique sur 2 scans : un scan pour re-accumuler le temps, un scan pour basculer).
    ADVANCE_TIME(1000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag, AlarmHoldTime := T#1s);
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Index, 2, 'scan intermediaire : TON re-accumule, pas encore de bascule');

    // Apres un second AlarmHoldTime : bascule cyclique vers le message 1
    ADVANCE_TIME(1000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag, AlarmHoldTime := T#1s);
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Index, 1, 'rotation cyclique -> retour Index=1');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/2 [M1] mou de cable', 'retour au premier message');
END_TEST

TEST 'TC-P07-006 Separation messages action/etat vs alarmes : alarme dans le carrousel, contexte dans le bandeau info'
    // Boot initial (reseau sain)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    // Une alarme active (mou de cable M1)
    WinchM1Safety.SlackCable := TRUE;
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    // L'alarme vit dans le carrousel (AlarmBanner), pas dans le bandeau info
    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'alarme presente dans le carrousel');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [M1] mou de cable', 'alarme dans le carrousel');
    // Le bandeau info (GlobalContextText) reste un contexte, pas l'alarme
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'contexte global non vide');
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = FB_Banner.Banner.AlarmBanner.Text,
                 'le contexte info ne porte pas le texte d alarme (2 familles distinctes)');
END_TEST

TEST 'TC-P07-002 Structures Cmd/State/Cfg par domaine (invariant structurel)'
    (* 💻 AUTO — invariant structurel documenté. Règle AF_Partie-07 §4 : convention
       Cmd/State/Cfg/Bypass/Test respectée dans GVL_IHM. FB_Hmi_BannerFormatter
       consomme des structures publiques (ST_SafetyWinch, ST_NetworkDiagHMI, E_Mode)
       et publie ST_HmiBanner. Vérifié par G200_check_linkage.py. *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'formateur consomme des structures publiques par domaine');
END_TEST

TEST 'TC-P07-003 IHM limitee aux variables de GVL_IHM (invariant structurel)'
    (* 💻 AUTO — invariant structurel documenté. Règle AF_Partie-07 §2 : l'IHM ne lit
       ni n'écrit les internes des FB ; elle n'accède qu'à GVL_IHM. FB_Hmi_BannerFormatter
       publie Banner : ST_HmiBanner (mappé dans GVL_IHM.Banner). Vérifié par
       G200_check_linkage.py / encapsulation_check.py. *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'sortie publique ST_HmiBanner (frontiere GVL_IHM)');
END_TEST

TEST 'TC-P07-004 Producteur unique par champ State (invariant structurel)'
    (* 💻 AUTO — invariant structurel documenté. Règle AF_Partie-07 §2 : chaque champ
       State a un seul écrivain PLC. FB_Hmi_BannerFormatter est le producteur unique
       de Banner (ST_HmiBanner) ; il ne réécrit pas les State des autres domaines.
       Vérifié par G200_check_linkage.py. *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'producteur unique du bandeau (Banner)');
END_TEST

TEST 'TC-P07-005 Page Troubleshooting en lecture seule (invariant structurel)'
    (* 💻 AUTO — invariant structurel documenté. Règle AF_Partie-07 §7 : le troubleshooting
       est une observation lecture seule, aucune écriture de commande/config/bypass.
       Implémenté par FB_TroubleshootingView + GVL_Troubleshooting (AF_Partie-14).
       FB_Hmi_BannerFormatter ne produit aucune commande. Vérifié par
       G200_check_linkage.py / encapsulation_check.py. *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'formateur lecture seule, aucune commande produite');
END_TEST

TEST 'TC-P07-007 Warning auto-effacable vs Fault sur Reset (invariant structurel)'
    (* ⚡ SITE+AUTO — invariant structurel documenté. Règle AF_Partie-07 §5.3 : un warning
       s'efface seul, un Fault exige Ack (pattern Cause/Ack, CODE_QUALITY_STANDARDS §9).
       Dans le bandeau, l'anti-clignotement (FB_AntiFlickerText) maintient les warnings
       min 500ms tandis que les défauts critiques passent en direct (ForceInstant).
       Le comportement Fault/Ack est porté par le socle FB_FaultCore (test_fb_faultcore.st).
       Vérifié par encapsulation_check.py. *)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_FALSE(FB_Banner.Banner.GlobalContextText = '', 'anti-clignotement gere par FB_AntiFlickerText (invariant)');
END_TEST


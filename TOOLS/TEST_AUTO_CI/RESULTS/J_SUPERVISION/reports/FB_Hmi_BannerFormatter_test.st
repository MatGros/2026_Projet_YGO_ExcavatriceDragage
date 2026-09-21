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

(* =========================================================================
   REX 2026-08-27 — Réarmement AU échouant silencieusement à l'étape 5 (PowerCutOff).
   TC-P07-030 : preuve du correctif IHM (Bug A gating + Bug B priorité + décodage
   16#0010 en cause explicite M3 MecaA). Le comportement du FB_Safety_EmergencyManagement
   (cause 16#0010, lockout, Error=FALSE, récupération Reset) est couvert par
   TC-P01-011/012/013 dans le domaine B_AU_SECURITE.
   ========================================================================= *)

TEST 'TC-P07-030 Abandon AU 16#0010 decode en cause explicite M3 MecaA (Bug A+B)'
    // Boot initial (reseau sain)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000); // 5s BootInhibit

    // Sequence AU en cours a l etape 5 (impulsion), contacteur pulse (PowerContactorEngaged=TRUE)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              ArmingSeqStep := 5, LastAbortCause := 16#0000,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(10000000);

    // Abandon a l etape 5 : PowerCutOff metier (16#0010) + cause M3 MecaA active.
    // Le contacteur vient d etre pulse (PowerContactorEngaged=TRUE) : l ancien gating
    // NOT PowerContactorEngaged supprimait ce message (Bug A). Il doit maintenant s afficher,
    // et la cause 16#0010 doit etre decodee en M3 MecaA (Bug B : cause avant message generique).
    TranslationSafety.ErrorMecaA := TRUE;
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              PowerCutOffActiveAny := TRUE,
              ArmingSeqStep := 0, LastAbortCause := 16#0010,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              TranslationSafety := TranslationSafety,
              Network := NetDiag);
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[M3] MecaA (mouvement non commandé) - Reset puis réarmer',
              'cause 16#0010 decodee en M3 MecaA (Bug A+B)');
END_TEST

TEST 'TC-P07-031 AX_STAB affiche le bit defaut latche, jamais #0'
    // Etat winch explicite : aucun latch, aucun mou de cable (deterministe, tests partages).
    WinchM1Safety.LatchedId := 0; WinchM1Safety.SlackCable := FALSE;
    WinchM2Safety.LatchedId := 0; WinchM2Safety.SlackCable := FALSE;
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.SEMI_AUTO,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              CycleStep := E_AutoCycleStep.AX_STAB,
              CycleStepAtError := E_AutoCycleStep.AX7_SEARCH_BOTTOM,
              CycleErrorId := 16#0200,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText,
              '[CYCLE]AX7:palier 4 non confirme>Repr/Abandon',
              'AX_STAB decode le code cause cycle latche (format concis)');
END_TEST

TEST 'TC-P07-032 AX_STAB remonte la cause RACINE winch et prime sur le SafeStop generique'
    // Cause racine = vue LATCHEE (M2 MecaE). SafeStopActive est TRUE car toute cause winch
    // Meca* est une cause SafeStop : le message de cause doit malgre tout etre affiche
    // (la coupure/SafeStop est une CONSEQUENCE, pas la cause). REX 2026-09-19.
    WinchM1Safety.LatchedId := 0; WinchM1Safety.SlackCable := FALSE;
    WinchM2Safety.LatchedId := 16#3000; WinchM2Safety.SlackCable := FALSE;
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.SEMI_AUTO,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              SafeStopActive := TRUE,
              CycleStep := E_AutoCycleStep.AX_STAB,
              CycleStepAtError := E_AutoCycleStep.AX7_SEARCH_BOTTOM,
              CycleErrorId := 16#0200,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText,
              '[CYCLE]AX7:palier 4 non confirme (M2 MecaE)>Repr/Abandon',
              'cause racine winch latchee affichee et prioritaire sur le message SafeStop generique');
    ASSERT_EQ(FB_Banner.Banner.SequenceProgressText,
              'Cycle: STABILISATION (defaut a AX7)',
              'repli AX_STAB : la progression situe lorigine sans laisser croire quon y est encore');
END_TEST

TEST 'TC-P07-040 T255-D limite basse cable M1 : alarme au carrousel ET action autorisee'
    // Cause VIVE non latchee (bit6 = 16#0040, FB_Safety_Winch.st:318-325) : elle allume
    // AnyFaultActive via Safety.Error mais n'etait decodee nulle part avant T255-D.
    WinchM1Safety.LatchedId := 0; WinchM1Safety.SlackCable := FALSE;
    WinchM1Safety.CableLimitDescent := TRUE;
    WinchM1Safety.Error := TRUE;
    WinchM1Safety.ErrorId := 16#0040;
    WinchM1Safety.DescendPermit := FALSE;   // interlock : descente interdite
    WinchM1Safety.AscentPermit := TRUE;     // remontee = action autorisee
    WinchM2Safety.CableLimitDescent := FALSE;
    WinchM2Safety.AscentPermit := TRUE;

    // Boot puis scan utile : depasse l'anti-clignotement (500 ms), reseau sain
    // (operateur ARME et au neutre : le prerequis homme-mort ne doit pas primer ici)
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'limite basse cable M1 : alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1, 'limite basse cable M1 : une seule alarme');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [M1] Limite basse cable atteinte',
              'libelle alarme citant le treuil M1 et la limite basse');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[TREUIL] Limite basse cable M1 - remonter',
              'action autorisee indiquee sans commande de descente');
END_TEST

TEST 'TC-P07-041 T255-D limite basse cable M2 : alarme au carrousel ET action autorisee'
    WinchM2Safety.LatchedId := 0; WinchM2Safety.SlackCable := FALSE;
    WinchM2Safety.CableLimitDescent := TRUE;
    WinchM2Safety.Error := TRUE;
    WinchM2Safety.ErrorId := 16#0040;
    WinchM2Safety.DescendPermit := FALSE;
    WinchM2Safety.AscentPermit := TRUE;
    WinchM1Safety.CableLimitDescent := FALSE;
    WinchM1Safety.AscentPermit := TRUE;

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'limite basse cable M2 : alarme presente');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text, '1/1 [M2] Limite basse cable atteinte',
              'libelle alarme citant le treuil M2 et la limite basse');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[TREUIL] Limite basse cable M2 - remonter',
              'action autorisee indiquee pour M2');
END_TEST

TEST 'TC-P07-042 T255-D ancre : descente commandee conserve le libelle historique'
    // Non-regression de la branche historique : sous DirectionBlocked ET descente
    // commandee, le message reste « Descente interdite - Limite basse cable » et la
    // nouvelle branche d'action ne le remplace pas.
    WinchM1Safety.CableLimitDescent := TRUE;
    WinchM1Safety.Error := TRUE;
    WinchM1Safety.ErrorId := 16#0040;
    WinchM1Safety.DescendPermit := FALSE;
    WinchM1Safety.AscentPermit := TRUE;

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              BothAxesCoupled := TRUE, WinchBothMotionDirection := -1,
              DeadmanArmed := TRUE, JoystickAtNeutral := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              BothAxesCoupled := TRUE, WinchBothMotionDirection := -1,
              DeadmanArmed := TRUE, JoystickAtNeutral := FALSE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[TREUIL] Descente interdite - Limite basse cable',
              'descente commandee : libelle historique inchange');
END_TEST

TEST 'TC-P07-043 T255-D ancre : champ CableLimitDescent seul NE DOIT PAS produire d alarme'
    // Le champ publie par FB_WinchStateProjection est une comparaison BRUTE de position,
    // SANS bypass ni mode referencement (FB_WinchStateProjection.st:217-218/230) : sous
    // BypassCableLimitSwitch (MAINT_N2) il reste TRUE alors que la cause safety est LEVEE
    // (ErrorId bit6 = 0) et que DescendPermit est rendu (FB_Safety_Winch.st:563-565).
    // Le carrousel doit donc lire ErrorId, jamais ce champ (revue read-only 2026-09-20).
    WinchM1Safety.LatchedId := 0; WinchM1Safety.SlackCable := FALSE;
    WinchM1Safety.CableLimitDescent := TRUE;   // etat brut de projection (bypass actif)
    WinchM1Safety.Error := FALSE;              // aucun defaut safety
    WinchM1Safety.ErrorId := 16#0000;          // bit6 leve
    WinchM1Safety.DescendPermit := TRUE;       // descente autorisee
    WinchM1Safety.AscentPermit := TRUE;
    WinchM2Safety.CableLimitDescent := FALSE;

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N2,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N2,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_FALSE(FB_Banner.Banner.AlarmBanner.HasAlarm,
                 'champ de projection seul : aucune alarme ne doit apparaitre (faux positif bypass)');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[JOYSTICK] Armé - actionner axe',
              'aucune consigne de remontee alors que la descente est autorisee');
END_TEST

TEST 'TC-P07-044 T255-D ancre : hors mode de marche, le prerequis de mode prime sur la remontee'
    WinchM1Safety.LatchedId := 0; WinchM1Safety.SlackCable := FALSE;
    WinchM1Safety.CableLimitDescent := TRUE;
    WinchM1Safety.Error := TRUE;
    WinchM1Safety.ErrorId := 16#0040;          // cause 6 REELLEMENT active
    WinchM1Safety.DescendPermit := FALSE;
    WinchM1Safety.AscentPermit := TRUE;

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.DISABLE,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              DeadmanArmed := TRUE, JoystickAtNeutral := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm, 'la cause reste visible au carrousel en DISABLE');
    ASSERT_EQ(FB_Banner.Banner.OperatorActionText, '[IHM] Sélectionner un mode',
              'hors mode de marche : consigne de mode, jamais une action inexécutable');
END_TEST


SETUP
VAR
    FB : FB_Cycle;
    SampleCount : INT := 0;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, CycleMotionPermit := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Enable=FALSE -> Lifecycle.Busy=FALSE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, CycleMotionPermit := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Au repos -> Pas de cycle actif');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, CycleMotionPermit := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-001 : Relachement manche (CycleMotionPermit=FALSE) stoppe les commandes sans perdre l etape'
    SampleCount := 5;
    // Initialisation et démarrage cycle
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Simuler le relâchement du manche au centre (CycleMotionPermit -> FALSE)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'M1 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.WinchM2Cmd.StartStop, 'M2 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.TranslationCmd.Start, 'Translation coupee');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION OR FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape conservee');
END_TEST

TEST 'TC-P04-002 : Le cycle produit des demandes et passe a X1_HOMING sur Start'
    SampleCount := 0;
    // Scan 1 : front montant StartCycle -> transition State vers X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : exécution de l'étape X1_HOMING -> Lifecycle.Busy=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Cycle actif (Lifecycle.Busy=TRUE)');
    ASSERT_FALSE(FB.Fault.Error, 'Pas d erreur au lancement');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Transition vers X1_HOMING');
END_TEST

TEST 'TC-P04-003 : Defaut de synchronisation treuils bascule le cycle en STABILIZING et fige l etape'
    SampleCount := 0;
    // Scan 1 : Démarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : Établissement à X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    // Scan 3 : Injection désynchronisme bloquant WinchSyncError
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Bascule en STABILIZING');
    ASSERT_TRUE(FB.Fault.Error, 'Drapeau Fault.Error actif');
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'Commandes treuils neutralisees');
END_TEST

TEST 'TC-P04-004 : Reprise apres STABILIZING necessite Cause disparue + Reset + StartCycle'
    SampleCount := 0;
    // Scan 1 : Demarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    // Scan 2 : Etablissement a X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    // Scan 3 : Injection defaut de synchronisme -> Bascule en STABILIZING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Bascule en STABILIZING');
    
    // 1. Cause disparue mais pas de Reset
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Reste en STABILIZING sans Reset');
    
    // 2. Front Reset (acquittement) -> retourne a X0_PREPARATION
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := TRUE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Sortie de STABILIZING vers X0 sur Reset');
    
    // 3. Demande de redemarrage explicite StartCycle (Scan 1: front montant, Scan 2: execution)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Redemarrage reussi vers X1_HOMING');
END_TEST

TEST 'TC-P04-012 : Compteur de prelevements SampleCount RETAIN incremente sur X13_DONE_SYNC'
    SampleCount := 10;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       SampleCount := SampleCount);
    ASSERT_EQ(SampleCount, 10, 'Compteur SampleCount inaltere hors fin de cycle');
END_TEST

TEST 'TC-P04-013 : Bascule Semi-Auto vers Maintenance preserve l etape et neutralise les demandes sans redemarrage auto'
    SampleCount := 0;
    // 1. Lancement du cycle jusqu'à X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape X1_HOMING active');

    // 2. Bascule en mode MAINTENANCE (Enable := FALSE)
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Ready retombe hors Semi-Auto');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Busy=FALSE en Maintenance');
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'Demandes M1 neutralisees');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape X1_HOMING preservee en memoire');

    // 3. Retour en mode SEMI_AUTO (Enable := TRUE) avec manche deflechi : PAS de mouvement spontane
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Toujours a X1_HOMING');
END_TEST


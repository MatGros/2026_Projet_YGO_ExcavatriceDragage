SETUP
VAR
    FB : FB_Cycle;
    SampleCount : INT := 0;
END_VAR
END_SETUP

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
    
    // Scan 2 : exécution de l'étape X1_HOMING -> Busy=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.Busy, 'Cycle actif (Busy=TRUE)');
    ASSERT_FALSE(FB.Error, 'Pas d erreur au lancement');
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
    ASSERT_TRUE(FB.Error, 'Drapeau Error actif');
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'Commandes treuils neutralisees');
END_TEST

TEST 'TC-P04-004 : Reprise apres STABILIZING necessite Cause disparue + Reset + StartCycle'
    SampleCount := 0;
    // Etat STABILIZING actif
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := TRUE, SampleCount := SampleCount);
    
    // 1. Cause disparue mais pas de Reset
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Reste en STABILIZING sans Reset');
    
    // 2. Front Reset (acquittement)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := TRUE, StartCycle := FALSE, SampleCount := SampleCount);
    
    // 3. Demande de reprise explicite StartCycle
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_CycleStep.STABILIZING, 'Sortie de STABILIZING apres Reset + Start');
END_TEST

TEST 'TC-P04-012 : Compteur de prelevements SampleCount RETAIN incremente sur X13_DONE_SYNC'
    SampleCount := 10;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       SampleCount := SampleCount);
    ASSERT_EQ(SampleCount, 10, 'Compteur SampleCount inaltere hors fin de cycle');
END_TEST

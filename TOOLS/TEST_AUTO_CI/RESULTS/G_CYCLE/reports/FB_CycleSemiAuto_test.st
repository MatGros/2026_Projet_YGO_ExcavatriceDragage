SETUP
VAR
    FB : FB_CycleSemiAuto;
    SampleCount : INT := 0;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Enable=FALSE -> Lifecycle.Busy=FALSE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Au repos -> Pas de cycle actif');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-001 : Relachement manche (JoystickDeflected=FALSE) stoppe les commandes sans perdre l etape'
    SampleCount := 5;
    // Initialisation et dÃƒÆ’Ã‚Â©marrage cycle
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Simuler le relÃƒÆ’Ã‚Â¢chement du manche au centre (JoystickDeflected -> FALSE)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'M1 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'M2 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart, 'Translation coupee');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS OR FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Etape conservee');
END_TEST

TEST 'TC-P04-002 : Le cycle produit des demandes et passe a AX1_INIT sur Start'
    SampleCount := 0;
    // Scan 1 : front montant StartCycle -> transition State vers AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : exÃƒÆ’Ã‚Â©cution de l'ÃƒÆ’Ã‚Â©tape AX1_INIT -> Lifecycle.Busy=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Cycle actif (Lifecycle.Busy=TRUE)');
    ASSERT_FALSE(FB.Fault.Error, 'Pas d erreur au lancement');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Transition vers AX1_INIT');
END_TEST

TEST 'TC-P04-003 : Defaut de synchronisation treuils bascule le cycle en AX_STAB et fige l etape'
    SampleCount := 0;
    // Scan 1 : DÃƒÆ’Ã‚Â©marrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : ÃƒÆ’Ã¢â‚¬Â°tablissement ÃƒÆ’Ã‚Â  AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    // Scan 3 : Injection dÃƒÆ’Ã‚Â©synchronisme bloquant WinchSyncError
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Bascule en AX_STAB');
    ASSERT_TRUE(FB.Fault.Error, 'Drapeau Fault.Error actif');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Commandes treuils neutralisees');
END_TEST

TEST 'TC-P04-004 : Reprise apres AX_STAB necessite Cause disparue + Reset + StartCycle'
    SampleCount := 0;
    // Scan 1 : Demarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    // Scan 2 : Etablissement a AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    // Scan 3 : Injection defaut de synchronisme -> Bascule en AX_STAB
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Bascule en AX_STAB');
    
    // 1. Cause disparue mais pas de Reset
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Reste en AX_STAB sans Reset');
    
    // 2. Front Reset (acquittement) -> retourne a AX0_REPOS
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := TRUE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Sortie de AX_STAB vers X0 sur Reset');
    
    // 3. Demande de redemarrage explicite StartCycle (Scan 1: front montant, Scan 2: execution)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Redemarrage reussi vers AX1_INIT');
END_TEST

TEST 'TC-P04-012 : Compteur de prelevements SampleCount RETAIN incremente sur AX18_DONE_SYNC'
    SampleCount := 10;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       SampleCount := SampleCount);
    ASSERT_EQ(FB.SampleCount, 10, 'Compteur SampleCount inaltere hors fin de cycle');
END_TEST

TEST 'TC-P04-013 : Bascule Semi-Auto vers Maintenance preserve l etape et neutralise les demandes sans redemarrage auto'
    SampleCount := 0;
    // 1. Lancement du cycle jusqu'ÃƒÆ’Ã‚Â  AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Etape AX1_INIT active');

    // 2. Bascule en mode MAINTENANCE (Enable := FALSE)
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Ready retombe hors Semi-Auto');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Busy=FALSE en Maintenance');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Demandes M1 neutralisees');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Etape AX1_INIT preservee en memoire');

    // 3. Retour en mode SEMI_AUTO (Enable := TRUE) avec manche deflechi : PAS de mouvement spontane
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Toujours a AX1_INIT');
END_TEST

TEST 'TC-P04-020 : Homme-mort relache en cours de plongee X4 -> commandes neutralisees, etape maintenue, PAS de redemarrage auto (T169-A S3)'
    SampleCount := 0;
    // === Progression vers AX4_DESCEND_DIVING (pattern chaine : un call pose State, le suivant observe CycleStep) ===
    (* Call 1 : front StartCycle -> X0->X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : observe X1, deja home -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : observe X2, cible P1 atteinte -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : observe X3, benne ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : observe AX4_DESCEND_DIVING, plongee sans contact fond *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en AX4_DESCEND_DIVING');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Descente M1 commandee avant relache');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Kobold PAS enclenche en AX4 - enclenche seulement des AX5');
    ASSERT_TRUE(FB.RequestActive, 'RequestActive=TRUE en X4 (plongee active, T186)');

    (* Call 6 : relache homme-mort / manche au centre pendant la plongee -> neutralisation, etape maintenue *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Descente M1 neutralisee au relache');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'Descente M2 neutralisee au relache');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Contacteur Kobold neutralise');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etape X4 maintenue (pas de retour X0)');
    ASSERT_FALSE(FB.RequestActive, 'Aucune demande active');

    (* Call 7 : maintient du relache 5 s -> PAS de redemarrage auto, etape figee *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etape X4 figee apres 5 s de relache');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Aucun redemarrage auto M1');
    ASSERT_FALSE(FB.Fault.Error, 'Pas de defaut (le relache homme-mort n est pas un defaut)');

    (* Call 8 : re-armement conscient (manche re-deflechi + homme-mort) -> reprise a X4 SANS repartir de X0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Reprise a X4 (pas de redemarrage depuis X0)');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Descente M1 commandee apres re-armement');
END_TEST

TEST 'TC-P04-021 : Fond jamais atteint -> maintien AX4 car tempo max etape desactivee'
    SampleCount := 0;
    (* === Progression vers AX4_DESCEND_DIVING (KoboldContactFond reste FALSE = fond non atteint) === *)
    (* Call 1 : front StartCycle -> X0->X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : observe X1, deja home -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : observe X2, cible P1 atteinte -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : observe X3, benne ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : observe AX4_DESCEND_DIVING, plongee sans contact fond (Kobold = FALSE) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en AX4_DESCEND_DIVING');

    (* Call 5bis : 1 scan de stabilisation en X4 -> StepMaxTimer armee (StepMaxPrevState = X4)
       apres le rearmement au changement d'etape. Sans ce scan, la tempo est encore a 0 et
       l'ADVANCE_TIME qui suit ne serait pas compte (IN passe FALSE->TRUE au scan d'avance). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);

    (* Call 6 : fond toujours pas atteint -> avance de 61 s (> StepMaxTimeout 60 s) -> timeout etape *)
    ADVANCE_TIME(61000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Tempo max desactivee : AX4 maintenue');
    ASSERT_FALSE(FB.Fault.Error, 'Aucun defaut temporel quand StepMaxTimer est desactive');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Commande M1 maintenue');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'Commande M2 maintenue');
    ASSERT_TRUE(FB.RequestActive, 'Demande de plongee active');
    ASSERT_FALSE(FB.Fault.Latched, 'Aucun defaut latche');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Kobold reste coupe en AX4');

END_TEST

TEST 'TC-P04-023 : StepMaxTimer NON cumulatif - 2 etapes de 40 s (total 80 s > 60 s) sans AX_STAB'
    SampleCount := 0;
    // Progression jusqu'a X4 (deja home).
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := TRUE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en X4');
    // 40 s en X4 (< 60 s) -> pas de timeout.
    ADVANCE_TIME(40000000000);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'X4 40 s : pas de timeout (< 60 s)');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Toujours X4');
    // Contact fond -> X5. Nouvelle etape -> StepMaxTimer REARMEE (pas de cumul des 40 s de X4).
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := TRUE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    // 1 scan de stabilisation en X5 pour armer StepMaxTimer sur la nouvelle etape.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en AX4 (plongee)');
    // 40 s en X5 (< 60 s) -> total cycle 80 s mais aucune etape > 60 s -> PAS de AX_STAB.
    ADVANCE_TIME(40000000000);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'X5 40 s : pas de timeout - StepMaxTimer non cumulatif sur le cycle');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Toujours AX4, pas de AX_STAB (StepMaxTimer non cumulatif)');
END_TEST

TEST 'TC-P04-026 : backstop anti-telescopage - ecart position M1/M2 > 0,5 m en phase couplee X4 -> AX_STAB'
    SampleCount := 0;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := TRUE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en X4');
    // Ecart de position M1/M2 = 1,0 m > 0,5 m en phase couplee -> defaut anti-telescopage.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -8.0, KoboldContactFond := FALSE, WinchSyncDeltaM := 2.0,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Ecart couple excessif -> AX_STAB');
    ASSERT_TRUE(FB.Fault.Error, 'Defaut anti-telescopage leve');
END_TEST

TEST 'TC-P04-022 : Abort+Start avec Fault.Latched actif -> cycle reste en X0 (pas de redemarrage) (T192-A S1)'
    SampleCount := 0;
    // Scan 1 : Demarrage (front StartCycle) -> X0 vers X1
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    // Scan 2 : StartCycle relache -> etablissement AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Etablissement a AX1_INIT');
    // Scan 3 : Injection defaut synchronisme -> AX_STAB + Fault.Latched=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := TRUE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Bascule en AX_STAB sur defaut');
    ASSERT_TRUE(FB.Fault.Latched, 'Defaut latche actif');
    // Scan 4 : Cause disparue (Error retombe) mais Latch persiste (pas de Reset)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch persiste sans Reset');
    // Scan 5 : AbortCycle -> retour X0 (mais Latch toujours actif)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := TRUE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Abort -> retour X0');
    // Scan 6 : StartCycle avec Fault.Latched actif -> RESTE EN X0 (gate NOT Fault.Latched)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Reste en X0 : Start bloque par Fault.Latched (S1)');
    // Scan 7 : StartCycle relache -> confirme X0, pas de redemarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Confirme X0 apres Start relache');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Pas de cycle en cours (Busy=FALSE)');
END_TEST

(* =======================================================================
   TC-P04-SCEN-NOM : Parcours nominal complet du Grafcet FB_CycleSemiAuto
   ScÃƒÆ’Ã‚Â¨ne nominale : traverse X0->X1->X2->X3->X4->X5->X6->X7->X8->X9->X10
   ->X11->X13->X0 (rebouclage), en changeant UNE variable de transition ÃƒÆ’Ã‚Â  la
   fois et en vÃƒÆ’Ã‚Â©rifiant les demandes produites ÃƒÆ’Ã‚Â  chaque ÃƒÆ’Ã‚Â©tape. VÃƒÆ’Ã‚Â©rifie
   l'incrÃƒÆ’Ã‚Â©ment strict de SampleCount (1/cycle). Pattern "settle + transition"
   (CycleStep retarde d'un scan sur State dans FB_CycleSemiAuto).
   Conforme ÃƒÆ’Ã‚Â  l'AF_Partie-04 v2.3 et au code FB_CycleSemiAuto (refactor actuel).
   ======================================================================= *)
TEST 'TC-P04-SCEN-NOM : Parcours nominal complet X0->X13->X0 avec rebouclage et compteur'
    SampleCount := 0;
    (* ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â Init : position haute, cible P1, homme-mort armÃƒÆ’Ã‚Â© *)

    (* ÃƒÂ°Ã…Â¸Ã…Â¡Ã¢â€šÂ¬ Call 1 : StartCycle ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 2 : X1 observÃƒÆ’Ã‚Â©, dÃƒÆ’Ã‚Â©jÃƒÆ’Ã‚Â  homÃƒÆ’Ã‚Â© ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'X1 observe : referencement (deja home)');

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 3 : X2 observÃƒÆ’Ã‚Â©, translation active *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX2_TRANSLATE_P1, 'X2 observe : selection position travail');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X2 : translation vers cible commandee');

    (* ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â¯ Call 4 : P1 atteinte ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 5 : X3 observÃƒÆ’Ã‚Â©, ouverture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX3_OPEN_BUCKET, 'X3 observe : ouverture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X3 : ouverture benne commandee');

    (* ÃƒÂ°Ã…Â¸Ã…â€™Ã…Â  Call 6 : benne ouverte ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 7 : AX4 observe, plongee palier 4 (au-dessus de l'altimetrie de lancement) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       DiveStartMinM := 4.0, KoboldContactFond := FALSE, KoboldImmersed := FALSE, KoboldContactorFeedback := FALSE,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := FB.SampleCount);
    FB(SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 observe : plongee palier 4');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'AX4 : descente M1+M2 commandee');
    ASSERT_TRUE(FB.WinchM1Cmd.StepTgt = 4, 'AX4 : palier 4');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'AX4 : Kobold PAS enclenche');

    (* ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â¯ Call 8 : altimetrie de lancement atteinte -> AX5 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, SampleCount := FB.SampleCount);
    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 9 : AX5 observe, retour contacteur Kobold OK -> AX6 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactorFeedback := TRUE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX5_KOBOLD_INIT, 'AX5 observe : init Kobold');
    ASSERT_TRUE(FB.BucketCmd.ReqKoboldMeasureEnable, 'AX5 : contacteur Kobold enclenche');
    ASSERT_TRUE(FB.WinchM1Cmd.StepTgt = 4, 'AX5 : palier 4 maintenu');

    (* ÃƒÂ°Ã…Â¸Ã…â€™Ã…Â  Call 10 : AX6 observe, front montant DI Kobold -> AX7 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactorFeedback := TRUE, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX6_SEARCH_IMMERSION, 'AX6 observe : recherche immersion');
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactorFeedback := TRUE, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬Â¢Ã‚Â³ÃƒÂ¯Ã‚Â¸Ã‚Â Call 11 : AX7 observe, front descendant DI Kobold -> AX8 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactorFeedback := TRUE, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    ADVANCE_TIME(500000000);
    FB(KoboldContactorFeedback := TRUE, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    FB(KoboldContactorFeedback := TRUE, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX7_SEARCH_BOTTOM, 'AX7 observe : recherche fond');
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactorFeedback := TRUE, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂºÃ¢â‚¬Ëœ Call 12 : AX8 observe -> coupure instantanee + memo -> AX9 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'AX8 : treuils coupes');
    ADVANCE_TIME(2000000000);
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 13 : AX9 observe, retente cables palier 1 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldContactFond := FALSE, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM, 'AX9 observe : retente cables');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'AX9 : remontee M1+M2 commandee');
    ASSERT_TRUE(FB.WinchM1Cmd.StepTgt = 1, 'AX9 : palier 1');

    (* ÃƒÂ¢Ã‚Â¬Ã¢â‚¬Â ÃƒÂ¯Ã‚Â¸Ã‚Â Call 10 : hauteur fermeture ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X6 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 11 : X6 observÃƒÆ’Ã‚Â©, fermeture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET, 'X6 observe : fermeture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'X6 : fermeture benne commandee');

    (* ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â¯ Call 12 : benne fermÃƒÆ’Ã‚Â©e ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X7 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 13 : X7 observÃƒÆ’Ã‚Â©, remontÃƒÆ’Ã‚Â©e contrÃƒÆ’Ã‚Â´le *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX11_CTRL_ASCENT, 'X7 observe : remontee controle');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X7 : remontee lente M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X7 : remontee lente M2 commandee');

    (* ÃƒÂ¢Ã‚Â¬Ã¢â‚¬Â ÃƒÂ¯Ã‚Â¸Ã‚Â Call 14 : palier contrÃƒÆ’Ã‚Â´le ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X8 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 15 : X8 observÃƒÆ’Ã‚Â©, remontÃƒÆ’Ã‚Â©e charge *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX12_LOADED_ASCENT, 'X8 observe : remontee en charge');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X8 : remontee nominale M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X8 : remontee nominale M2 commandee');

    (* ÃƒÂ¢Ã‚Â¬Ã¢â‚¬Â ÃƒÂ¯Ã‚Â¸Ã‚Â Call 16 : limite haute ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X9 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 17 : X9 observÃƒÆ’Ã‚Â©, ÃƒÆ’Ã‚Â©gouttage *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX13_DRAIN_PAUSE, 'X9 observe : egouttage');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X9 : treuil M1 arrete (egouttage)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X9 : treuil M2 arrete (egouttage)');

    (* ÃƒÂ¢Ã‚ÂÃ‚Â±ÃƒÂ¯Ã‚Â¸Ã‚Â Call 18 : ÃƒÆ’Ã‚Â©gouttage 5s ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X10 *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 19 : X10 observÃƒÆ’Ã‚Â©, translation trÃƒÆ’Ã‚Â©mie *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX14_TRANSLATE_DUMP, 'X10 observe : translation vers tremie');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X10 : translation vers tremie commandee');

    (* ÃƒÂ°Ã…Â¸Ã…Â¡Ã…Â¡ Call 20 : trÃƒÆ’Ã‚Â©mie atteinte ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X11 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 20b : X11a observÃƒÆ’Ã‚Â© (arrivÃƒÆ’Ã‚Â©e trÃƒÆ’Ã‚Â©mie, treuils arrÃƒÆ’Ã‚ÂªtÃƒÆ’Ã‚Â©s) -> X11b sur geste joystick *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE, 'X11a observe : arrivee tremie treuils arretes');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11a : M1 arrete');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11a : M2 arrete');

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 21 : X11b observÃƒÆ’Ã‚Â©, ouverture vidange *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'X11b observe : ouverture vidange');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X11b : ouverture benne commandee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11b : M1 arrete (pas de descente couplee)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11b : M2 arrete (pas de descente couplee)');

    (* ÃƒÂ¢Ã‚Â¬Ã¢â‚¬Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Call 21b : option repositionnement (BtnReposition) -> X11c *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := TRUE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 21c : X11c observe -> descente couplee M1+M2 symetrique palier lent *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := TRUE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15C_DUMP_REPOSITION, 'X11c observe : repositionnement couple');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'X11c : M1 ET M2 commandes');
    ASSERT_TRUE(FB.WinchM1Cmd.ReqDescend AND FB.WinchM2Cmd.ReqDescend, 'X11c : descente couplee symetrique');
    ASSERT_EQ(FB.WinchM1Cmd.StepTgt, FB.WinchM2Cmd.StepTgt, 'X11c : meme palier M1/M2');
    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â¼ Call 21d : relache l'option -> retour X11b *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := FALSE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ¢â€šÂ¬ Call 21e : X11b observe de nouveau *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := FALSE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'X11c -> X11b au relachement de l option');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Retour X11b : M1 de nouveau arrete');

    (* ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Call 22 : benne ouverte ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X13 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Call 23 : X13 observÃƒÆ’Ã‚Â©, Done + SampleCount+1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'X13 observe : cycle termine');
    ASSERT_TRUE(FB.Lifecycle.Done, 'X13 : Lifecycle.Done=TRUE');
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount incremente UNE fois (1er cycle)');
    ASSERT_TRUE(FB.LastCycleDuration > T#0s, 'X13 : duree du cycle figee (> 0) - chronometre');

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬â„¢ Call 24 : X13 2e scan, garde anti-double *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount reste 1 au 2e scan (garde anti-double increment)');

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Call 25 : StartCycle ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ X0 (rebouclage) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'X13 observe : rebouclage pose (front StartCycle)');

    (* ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Call 26 : rebouclage effectif -> AX2_TRANSLATE_P1 (GEL Q14 : pas de retour AX0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX2_TRANSLATE_P1, 'Rebouclage effectif : retour direct AX2 (pas AX0)');
    ASSERT_FALSE(FB.Lifecycle.Done, 'Lifecycle.Done retombe apres rebouclage');
END_TEST

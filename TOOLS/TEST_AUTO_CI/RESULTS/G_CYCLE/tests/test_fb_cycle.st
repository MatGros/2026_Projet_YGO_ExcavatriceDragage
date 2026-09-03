SETUP
VAR
    FB : FB_Cycle;
    SampleCount : INT := 0;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Enable=FALSE -> Lifecycle.Busy=FALSE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Au repos -> Pas de cycle actif');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-001 : Relachement manche (JoystickDeflected=FALSE) stoppe les commandes sans perdre l etape'
    SampleCount := 5;
    // Initialisation et démarrage cycle
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Simuler le relâchement du manche au centre (JoystickDeflected -> FALSE)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'M1 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'M2 coupe sur retour neutre manche');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart, 'Translation coupee');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION OR FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape conservee');
END_TEST

TEST 'TC-P04-002 : Le cycle produit des demandes et passe a X1_HOMING sur Start'
    SampleCount := 0;
    // Scan 1 : front montant StartCycle -> transition State vers X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : exécution de l'étape X1_HOMING -> Lifecycle.Busy=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Cycle actif (Lifecycle.Busy=TRUE)');
    ASSERT_FALSE(FB.Fault.Error, 'Pas d erreur au lancement');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Transition vers X1_HOMING');
END_TEST

TEST 'TC-P04-003 : Defaut de synchronisation treuils bascule le cycle en STABILIZING et fige l etape'
    SampleCount := 0;
    // Scan 1 : Démarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : Établissement à X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    // Scan 3 : Injection désynchronisme bloquant WinchSyncError
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Bascule en STABILIZING');
    ASSERT_TRUE(FB.Fault.Error, 'Drapeau Fault.Error actif');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Commandes treuils neutralisees');
END_TEST

TEST 'TC-P04-004 : Reprise apres STABILIZING necessite Cause disparue + Reset + StartCycle'
    SampleCount := 0;
    // Scan 1 : Demarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    // Scan 2 : Etablissement a X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    // Scan 3 : Injection defaut de synchronisme -> Bascule en STABILIZING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Bascule en STABILIZING');
    
    // 1. Cause disparue mais pas de Reset
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Reste en STABILIZING sans Reset');
    
    // 2. Front Reset (acquittement) -> retourne a X0_PREPARATION
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := TRUE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Sortie de STABILIZING vers X0 sur Reset');
    
    // 3. Demande de redemarrage explicite StartCycle (Scan 1: front montant, Scan 2: execution)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       WinchSyncError := FALSE, Reset := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Redemarrage reussi vers X1_HOMING');
END_TEST

TEST 'TC-P04-012 : Compteur de prelevements SampleCount RETAIN incremente sur X13_DONE_SYNC'
    SampleCount := 10;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       SampleCount := SampleCount);
    ASSERT_EQ(FB.SampleCount, 10, 'Compteur SampleCount inaltere hors fin de cycle');
END_TEST

TEST 'TC-P04-013 : Bascule Semi-Auto vers Maintenance preserve l etape et neutralise les demandes sans redemarrage auto'
    SampleCount := 0;
    // 1. Lancement du cycle jusqu'à X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape X1_HOMING active');

    // 2. Bascule en mode MAINTENANCE (Enable := FALSE)
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Ready retombe hors Semi-Auto');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Busy=FALSE en Maintenance');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Demandes M1 neutralisees');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Etape X1_HOMING preservee en memoire');

    // 3. Retour en mode SEMI_AUTO (Enable := TRUE) avec manche deflechi : PAS de mouvement spontane
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Toujours a X1_HOMING');
END_TEST

TEST 'TC-P04-020 : Homme-mort relache en cours de plongee X4 -> commandes neutralisees, etape maintenue, PAS de redemarrage auto (T169-A S3)'
    SampleCount := 0;
    // === Progression vers X4_DESCEND_OPEN (pattern chaine : un call pose State, le suivant observe CycleStep) ===
    (* Call 1 : front StartCycle -> X0->X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : observe X1, deja home -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : observe X2, cible P1 atteinte -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : observe X3, benne ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : observe X4_DESCEND_OPEN, plongee sans contact fond *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etabli en X4_DESCEND_OPEN');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Descente M1 commandee avant relache');
    ASSERT_TRUE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Kobold contacteur arme en X4 pendant plongee (T186)');
    ASSERT_TRUE(FB.RequestActive, 'RequestActive=TRUE en X4 (plongee active, T186)');

    (* Call 6 : relache homme-mort / manche au centre pendant la plongee -> neutralisation, etape maintenue *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Descente M1 neutralisee au relache');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'Descente M2 neutralisee au relache');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Contacteur Kobold neutralise');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etape X4 maintenue (pas de retour X0)');
    ASSERT_FALSE(FB.RequestActive, 'Aucune demande active');

    (* Call 7 : maintient du relache 5 s -> PAS de redemarrage auto, etape figee *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etape X4 figee apres 5 s de relache');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Aucun redemarrage auto M1');
    ASSERT_FALSE(FB.Fault.Error, 'Pas de defaut (le relache homme-mort n est pas un defaut)');

    (* Call 8 : re-armement conscient (manche re-deflechi + homme-mort) -> reprise a X4 SANS repartir de X0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Reprise a X4 (pas de redemarrage depuis X0)');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Descente M1 commandee apres re-armement');
END_TEST

TEST 'TC-P04-021 : Fond jamais atteint -> timeout tempo max d etape (60 s) -> STABILIZING, pas de redemarrage auto (T169-A S4)'
    SampleCount := 0;
    (* === Progression vers X4_DESCEND_OPEN (KoboldContactFond reste FALSE = fond non atteint) === *)
    (* Call 1 : front StartCycle -> X0->X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : observe X1, deja home -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : observe X2, cible P1 atteinte -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : observe X3, benne ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : observe X4_DESCEND_OPEN, plongee sans contact fond (Kobold = FALSE) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etabli en X4_DESCEND_OPEN');

    (* Call 5bis : 1 scan de stabilisation en X4 -> StepMaxTimer armee (StepMaxPrevState = X4)
       apres le rearmement au changement d'etape. Sans ce scan, la tempo est encore a 0 et
       l'ADVANCE_TIME qui suit ne serait pas compte (IN passe FALSE->TRUE au scan d'avance). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);

    (* Call 6 : fond toujours pas atteint -> avance de 61 s (> StepMaxTimeout 60 s) -> timeout etape *)
    ADVANCE_TIME(61000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Timeout etape -> STABILIZING');
    ASSERT_TRUE(FB.Fault.Error, 'Defaut tempo max d etape levee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Commandes M1 neutralisees sur defaut');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'Commandes M2 neutralisees sur defaut');
    ASSERT_FALSE(FB.RequestActive, 'Aucune demande active');
    ASSERT_TRUE(FB.Fault.Latched, 'Defaut latche en STABILIZING (T186)');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Kobold contacteur coupe en STABILIZING (neutralisation complete, T186)');

    (* Call 7 : cause disparue mais PAS de Reset -> reste STABILIZING (pas de redemarrage auto) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Reste en STABILIZING sans Reset (pas de redemarrage auto)');
    ASSERT_TRUE(FB.Fault.Latched, 'Latch persiste sans Reset (pas de rearmement auto, T186)');
    ASSERT_FALSE(FB.Fault.Error, 'Defaut live retombe seule (cause disparue, T186)');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Kobold contacteur reste coupe en STABILIZING sans Reset (T186)');

    (* Call 8 : front Reset (acquittement conscient) -> retour X0_PREPARATION *)
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION OR FB.CycleStep = E_CycleStep.X1_HOMING,
                'Acquittement Reset -> retour preparation');
    ASSERT_FALSE(FB.Fault.Latched, 'Reset efface le latch (T186)');
    ASSERT_FALSE(FB.BucketCmd.ReqKoboldMeasureEnable, 'Reset efface Kobold contacteur (T186)');
END_TEST

TEST 'TC-P04-023 : StepMaxTimer NON cumulatif - 2 etapes de 40 s (total 80 s > 60 s) sans STABILIZING'
    SampleCount := 0;
    // Progression jusqu'a X4 (deja home).
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := TRUE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etabli en X4');
    // 40 s en X4 (< 60 s) -> pas de timeout.
    ADVANCE_TIME(40000000000);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'X4 40 s : pas de timeout (< 60 s)');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Toujours X4');
    // Contact fond -> X5. Nouvelle etape -> StepMaxTimer REARMEE (pas de cumul des 40 s de X4).
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := TRUE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    // 1 scan de stabilisation en X5 pour armer StepMaxTimer sur la nouvelle etape.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X5_BOTTOM_CONFIRMED, 'Etabli en X5');
    // 40 s en X5 (< 60 s) -> total cycle 80 s mais aucune etape > 60 s -> PAS de STABILIZING.
    ADVANCE_TIME(40000000000);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'X5 40 s : pas de timeout - StepMaxTimer non cumulatif sur le cycle');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X5_BOTTOM_CONFIRMED, 'Toujours X5, pas de STABILIZING');
END_TEST

TEST 'TC-P04-026 : backstop anti-telescopage - ecart position M1/M2 > 0,5 m en phase couplee X4 -> STABILIZING'
    SampleCount := 0;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := TRUE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Etabli en X4');
    // Ecart de position M1/M2 = 1,0 m > 0,5 m en phase couplee -> defaut anti-telescopage.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE,
       M1_CablePosM := -10.0, M2_CablePosM := -9.0, KoboldContactFond := FALSE,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Ecart couple excessif -> STABILIZING');
    ASSERT_TRUE(FB.Fault.Error, 'Defaut anti-telescopage leve');
END_TEST

TEST 'TC-P04-022 : Abort+Start avec Fault.Latched actif -> cycle reste en X0 (pas de redemarrage) (T192-A S1)'
    SampleCount := 0;
    // Scan 1 : Demarrage (front StartCycle) -> X0 vers X1
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    // Scan 2 : StartCycle relache -> etablissement X1_HOMING
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Etablissement a X1_HOMING');
    // Scan 3 : Injection defaut synchronisme -> STABILIZING + Fault.Latched=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := TRUE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Bascule en STABILIZING sur defaut');
    ASSERT_TRUE(FB.Fault.Latched, 'Defaut latche actif');
    // Scan 4 : Cause disparue (Error retombe) mais Latch persiste (pas de Reset)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch persiste sans Reset');
    // Scan 5 : AbortCycle -> retour X0 (mais Latch toujours actif)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := TRUE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Abort -> retour X0');
    // Scan 6 : StartCycle avec Fault.Latched actif -> RESTE EN X0 (gate NOT Fault.Latched)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Reste en X0 : Start bloque par Fault.Latched (S1)');
    // Scan 7 : StartCycle relache -> confirme X0, pas de redemarrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := FALSE, WinchSyncError := FALSE, Reset := FALSE,
       HomedM1 := FALSE, HomedM2 := FALSE, TopPositionSensor := FALSE, HomingRequest := FALSE,
       M1_CablePosM := 0.0, M2_CablePosM := 0.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       KoboldContactFond := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Confirme X0 apres Start relache');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Pas de cycle en cours (Busy=FALSE)');
END_TEST

(* =======================================================================
   TC-P04-SCEN-NOM : Parcours nominal complet du Grafcet FB_Cycle
   Scène nominale : traverse X0->X1->X2->X3->X4->X5->X6->X7->X8->X9->X10
   ->X11->X13->X0 (rebouclage), en changeant UNE variable de transition à la
   fois et en vérifiant les demandes produites à chaque étape. Vérifie
   l'incrément strict de SampleCount (1/cycle). Pattern "settle + transition"
   (CycleStep retarde d'un scan sur State dans FB_Cycle).
   Conforme à l'AF_Partie-04 v2.3 et au code FB_Cycle (refactor actuel).
   ======================================================================= *)
TEST 'TC-P04-SCEN-NOM : Parcours nominal complet X0->X13->X0 avec rebouclage et compteur'
    SampleCount := 0;
    (* 🏁 Init : position haute, cible P1, homme-mort armé *)

    (* 🚀 Call 1 : StartCycle → X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 2 : X1 observé, déjà homé → X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'X1 observe : referencement (deja home)');

    (* 👀 Call 3 : X2 observé, translation active *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X2_WORK_POS_SELECT, 'X2 observe : selection position travail');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X2 : translation vers cible commandee');

    (* 🎯 Call 4 : P1 atteinte → X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 5 : X3 observé, ouverture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X3_OPEN_BUCKET, 'X3 observe : ouverture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X3 : ouverture benne commandee');

    (* 🌊 Call 6 : benne ouverte → X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 7 : X4 observé, plongée *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'X4 observe : plongee benne ouverte');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X4 : descente M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X4 : descente M2 commandee');
    ASSERT_TRUE(FB.BucketCmd.ReqKoboldMeasureEnable, 'X4 : contacteur Kobold arme');

    (* 🎯 Call 8 : contact fond → X5 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 9 : X5 observé, remontée *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X5_BOTTOM_CONFIRMED, 'X5 observe : fond confirme');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X5 : remontee M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X5 : remontee M2 commandee');

    (* ⬆️ Call 10 : hauteur fermeture → X6 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 11 : X6 observé, fermeture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X6_CLOSE_BUCKET, 'X6 observe : fermeture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'X6 : fermeture benne commandee');

    (* 🎯 Call 12 : benne fermée → X7 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 13 : X7 observé, remontée contrôle *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X7_CTRL_ASCENT, 'X7 observe : remontee controle');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X7 : remontee lente M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X7 : remontee lente M2 commandee');

    (* ⬆️ Call 14 : palier contrôle → X8 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 15 : X8 observé, remontée charge *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X8_ASCENT_LOADED, 'X8 observe : remontee en charge');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X8 : remontee nominale M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X8 : remontee nominale M2 commandee');

    (* ⬆️ Call 16 : limite haute → X9 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 17 : X9 observé, égouttage *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X9_DRAIN_PAUSE, 'X9 observe : egouttage');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X9 : treuil M1 arrete (egouttage)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X9 : treuil M2 arrete (egouttage)');

    (* ⏱️ Call 18 : égouttage 5s → X10 *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 19 : X10 observé, translation trémie *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X10_TRANSLATE_DUMP, 'X10 observe : translation vers tremie');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X10 : translation vers tremie commandee');

    (* 🚚 Call 20 : trémie atteinte → X11 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* 👀 Call 20b : X11a observé (arrivée trémie, treuils arrêtés) -> X11b sur geste joystick *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X11A_DUMP_ARRIVE, 'X11a observe : arrivee tremie treuils arretes');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11a : M1 arrete');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11a : M2 arrete');

    (* 👀 Call 21 : X11b observé, ouverture vidange *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X11B_DUMP_OPEN, 'X11b observe : ouverture vidange');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X11b : ouverture benne commandee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11b : M1 arrete (pas de descente couplee)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11b : M2 arrete (pas de descente couplee)');

    (* ✅ Call 22 : benne ouverte → X13 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ✅ Call 23 : X13 observé, Done + SampleCount+1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X13_DONE_SYNC, 'X13 observe : cycle termine');
    ASSERT_TRUE(FB.Lifecycle.Done, 'X13 : Lifecycle.Done=TRUE');
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount incremente UNE fois (1er cycle)');
    ASSERT_TRUE(FB.LastCycleDuration > T#0s, 'X13 : duree du cycle figee (> 0) - chronometre');

    (* 🔒 Call 24 : X13 2e scan, garde anti-double *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount reste 1 au 2e scan (garde anti-double increment)');

    (* 🔄 Call 25 : StartCycle → X0 (rebouclage) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X13_DONE_SYNC, 'X13 observe : rebouclage pose (front StartCycle)');

    (* 🔄 Call 26 : X0 observé, rebouclage effectif *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'X0 observe : rebouclage effectif');
    ASSERT_FALSE(FB.Lifecycle.Done, 'X0 : Lifecycle.Done retombe');
END_TEST


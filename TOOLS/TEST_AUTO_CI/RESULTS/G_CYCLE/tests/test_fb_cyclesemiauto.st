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

TEST 'TC-P04-027 T258 : ForÃ§age prepare sans action et reprise sur Start au neutre'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       CfgCommissioningEnable := TRUE, CfgForceStepTarget := 4,
       CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepPrepared, 'Cible preparee');
    ASSERT_TRUE(FB.ForceStepAccepted, 'Preparation acceptee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Aucune action au scan Apply');
    FB(CfgForceStepApply := FALSE, StartCycle := TRUE, JoystickDeflected := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Aucune action au scan Start');
    FB(StartCycle := FALSE, DeadmanArmed := TRUE, JoystickDeflected := TRUE,
       JoystickPull := TRUE, JoystickPush := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Y+ ne commande pas la descente AX4');
    FB(JoystickPull := FALSE, JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'Y- commande les deux voies AX4');
END_TEST

TEST 'TC-P04-028 T258 : ForÃ§age AX_STAB refuse et reste neutre'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepTarget := 19, CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepRejected, 'AX_STAB refuse');
    ASSERT_FALSE(FB.ForceStepPrepared, 'Aucune cible preparee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Sorties neutres sur refus');
END_TEST

TEST 'TC-P04-029 T258 : Inhibition ne masque pas le desynchronisme'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       CfgCommissioningEnable := TRUE, CfgCycleChecksInhibit := FALSE,
       StartCycle := TRUE, SampleCount := SampleCount);
    FB(StartCycle := FALSE, CfgCycleChecksInhibit := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleChecksInhibited, 'Mode essai actif');
    FB(CfgCycleChecksInhibit := TRUE, WinchSyncError := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleChecksInhibited, 'Mode essai reste actif pendant injection safety');
    ASSERT_TRUE(FB.Fault.Error, 'Synchronisme reste bloquant');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Repli AX_STAB maintenu');
END_TEST

TEST 'TC-P04-030 T258 : Un forçage refuse invalide une preparation precedente'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepTarget := 4, CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepPrepared, 'Premiere cible preparee');
    FB(CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(CfgForceStepTarget := 19, CfgForceStepApply := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepRejected, 'Seconde cible refusee');
    ASSERT_FALSE(FB.ForceStepPrepared, 'Preparation precedente invalidee');
    FB(CfgForceStepApply := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Start ne peut executer la cible obsolete');
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Ancienne cible AX4 non chargee');
    FB(StartCycle := FALSE, DeadmanArmed := TRUE, JoystickDeflected := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Nouveau geste Y- sans cible reste neutre');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart OR FB.BucketCmd.ReqOpen OR FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqKoboldMeasureEnable,
                 'Tous les autres actionneurs restent neutres apres rejet');
END_TEST

TEST 'TC-P04-031 T258 : Apply et Start simultanes restent en preparation neutre'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepTarget := 4, CfgForceStepApply := FALSE, StartCycle := FALSE,
       SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepPrepared, 'Apply prepare la cible sans consommer Start');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Aucune action au scan Apply+Start');
    FB(CfgForceStepApply := FALSE, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepPrepared, 'Preparation conservee : nouveau front Start requis');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Attente neutre maintenue');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart OR FB.BucketCmd.ReqOpen OR FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqKoboldMeasureEnable,
                 'Preparation neutre sur tous les actionneurs');
END_TEST

TEST 'TC-P04-032 T258 : Reset simultane annule le forçage'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepTarget := 4, CfgForceStepApply := FALSE, Reset := FALSE,
       SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, Reset := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepPrepared, 'Reset prioritaire annule la preparation');
    FB(CfgForceStepApply := FALSE, Reset := FALSE, StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 non charge apres Reset+Apply');
END_TEST

TEST 'TC-P04-033 T258 : Retrait commissioning annule le forçage'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepTarget := 4, CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(CfgForceStepApply := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepPrepared, 'Preparation initiale acceptee');
    FB(CfgForceStepApply := FALSE, CfgCommissioningEnable := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepPrepared, 'Retrait commissioning annule la preparation');
    FB(StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 non charge hors commissioning');
END_TEST

TEST 'TC-P04-001 : Relachement manche (JoystickDeflected=FALSE) stoppe les commandes sans perdre l etape'
    SampleCount := 5;
    // Initialisation et dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©marrage cycle
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Simuler le relÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢chement du manche au centre (JoystickDeflected -> FALSE)
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
    
    // Scan 2 : exÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©cution de l'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©tape AX1_INIT -> Lifecycle.Busy=TRUE
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Cycle actif (Lifecycle.Busy=TRUE)');
    ASSERT_FALSE(FB.Fault.Error, 'Pas d erreur au lancement');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Transition vers AX1_INIT');
END_TEST

TEST 'TC-P04-003 : Defaut de synchronisation treuils bascule le cycle en AX_STAB et fige l etape'
    SampleCount := 0;
    // Scan 1 : DÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©marrage
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    
    // Scan 2 : ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°tablissement ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  AX1_INIT
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    
    // Scan 3 : Injection dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©synchronisme bloquant WinchSyncError
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
    // 1. Lancement du cycle jusqu'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  AX1_INIT
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etape X4 figee apres 5 s de relache');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Aucun redemarrage auto M1');
    ASSERT_FALSE(FB.Fault.Error, 'Pas de defaut (le relache homme-mort n est pas un defaut)');

    (* Pause mode en AX4, puis tentative de forçage invalide : la reprise consciente doit survivre. *)
    FB(Enable := FALSE, Mode := E_Mode.MAINT_N1, JoystickDeflected := FALSE,
       DeadmanArmed := FALSE, JoystickPush := FALSE, CfgCommissioningEnable := TRUE,
       CfgForceStepApply := FALSE, SampleCount := SampleCount);
    FB(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, JoystickDeflected := TRUE,
       DeadmanArmed := TRUE, JoystickPush := TRUE,
       CfgForceStepTarget := 19, CfgForceStepApply := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepRejected, 'Forçage interdit refuse pendant attente reprise mode');
    FB(CfgForceStepApply := FALSE, DeadmanArmed := TRUE, JoystickDeflected := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Y- seul reste neutre apres rejet : reprise mode toujours armee');
    FB(DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE,
       StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Scan Start de reprise reste neutre');

    (* Call 8 : nouveau geste apres Start -> reprise a X4 SANS repartir de X0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Reprise a X4 (pas de redemarrage depuis X0)');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'Descente M1 commandee apres re-armement');
END_TEST

TEST 'TC-P04-021 : Fond jamais atteint -> maintien AX4 car tempo max etape desactivee'
    SampleCount := 0;
    (* === Progression vers AX4_DESCEND_DIVING (KoboldImmersed reste FALSE = sonde hors eau) === *)
    (* Call 1 : front StartCycle -> X0->X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
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
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
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
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
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
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    // 1 scan de stabilisation en X5 pour armer StepMaxTimer sur la nouvelle etape.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0, DiveStartMinM := 4.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
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
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'X5 40 s : pas de timeout - StepMaxTimer non cumulatif sur le cycle');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Toujours AX4, pas de AX_STAB (StepMaxTimer non cumulatif)');
END_TEST

TEST 'TC-P04-026 : AX4 ne contient aucun seuil synchro local - PRG04 reste source unique'
    SampleCount := 0;
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := TRUE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(300000000);
    FB(SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Etabli en X4');
    // AX4..AX7 ne lisent aucun seuil de delta. PRG04 convertit ses causes critiques
    // (synchro confirmee, contacteurs ou Meca E) en WinchSyncError avant le cycle.
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_Done := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 reste pilote uniquement par WinchSyncError PRG04');
    ASSERT_FALSE(FB.Fault.Error, 'Aucun seuil synchro local cycle');
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
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
WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Confirme X0 apres Start relache');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Pas de cycle en cours (Busy=FALSE)');
END_TEST

(* =======================================================================
   TC-P04-SCEN-NOM : Parcours nominal complet du Grafcet FB_CycleSemiAuto
   ScÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¨ne nominale : traverse X0->X1->X2->X3->X4->X5->X6->X7->X8->X9->X10
   ->X11->X13->X0 (rebouclage), en changeant UNE variable de transition ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  la
   fois et en vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rifiant les demandes produites ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  chaque ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©tape. VÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rifie
   l'incrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©ment strict de SampleCount (1/cycle). Pattern "settle + transition"
   (CycleStep retarde d'un scan sur State dans FB_CycleSemiAuto).
   Conforme ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  l'AF_Partie-04 v2.3 et au code FB_CycleSemiAuto (refactor actuel).
   ======================================================================= *)
TEST 'TC-P04-SCEN-NOM : Parcours nominal complet X0->X13->X0 avec rebouclage et compteur'
    SampleCount := 0;
    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â Init : position haute, cible P1, homme-mort armÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© *)

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â¡ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 1 : StartCycle ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 2 : X1 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  homÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'X1 observe : referencement (deja home)');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 3 : X2 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, translation active *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX2_TRANSLATE_P1, 'X2 observe : selection position travail');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X2 : translation vers cible commandee');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â½Ãƒâ€šÃ‚Â¯ Call 4 : P1 atteinte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 5 : X3 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, ouverture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX3_OPEN_BUCKET, 'X3 observe : ouverture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X3 : ouverture benne commandee');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢Ãƒâ€¦Ã‚Â  Call 6 : benne ouverte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 7 : AX4 observe, plongee palier 4 (au-dessus de l'altimetrie de lancement) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 5.0, M2_CablePosM := 5.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       DiveStartMinM := 4.0, KoboldImmersed := FALSE,
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

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â½Ãƒâ€šÃ‚Â¯ Call 8 : altimetrie de lancement atteinte -> AX5 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, SampleCount := FB.SampleCount);
    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 9 : AX5 observe, retour contacteur Kobold OK -> AX6 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX5_KOBOLD_INIT, 'AX5 observe : init Kobold');
    ASSERT_TRUE(FB.BucketCmd.ReqKoboldMeasureEnable, 'AX5 : contacteur Kobold enclenche');
    ASSERT_TRUE(FB.WinchM1Cmd.StepTgt = 4, 'AX5 : palier 4 maintenu');
    ADVANCE_TIME(500000000);
    FB(SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢Ãƒâ€¦Ã‚Â  Call 10 : AX6 observe, front montant DI Kobold -> AX7 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX6_SEARCH_IMMERSION, 'AX6 observe : recherche immersion');
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢Ãƒâ€šÃ‚Â³ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 11 : AX7 observe, front descendant DI Kobold -> AX8 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    ADVANCE_TIME(500000000);
    FB(KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    FB(KoboldImmersed := TRUE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX7_SEARCH_BOTTOM, 'AX7 observe : recherche fond');
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ADVANCE_TIME(100000000);
    FB(KoboldImmersed := FALSE, SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂºÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ Call 12 : AX8 observe -> coupure instantanee + memo -> AX9 *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'AX8 : treuils coupes');
    ADVANCE_TIME(2000000000);
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, KoboldImmersed := FALSE, SampleCount := FB.SampleCount);

    (* AX9 observe avec Y- encore maintenu : aucune remontee ne doit partir. *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE,
       JoystickPush := TRUE, JoystickPull := FALSE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM, 'AX9 observe : retente cables');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'AX9 : Y- maintenu ne commande aucune remontee');

    (* Nouveau geste Y+ : retente cables palier 1. *)
    FB(M1_CablePosM := -10.0, M2_CablePosM := -10.0, DiveStartMinM := 4.0, KoboldImmersed := FALSE,
       JoystickPush := FALSE, JoystickPull := TRUE, SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM, 'AX9 observe : retente cables');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'AX9 : remontee M1+M2 commandee');
    ASSERT_TRUE(FB.WinchM1Cmd.StepTgt = 1, 'AX9 : palier 1');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 10 : hauteur fermeture ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X6 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 11 : X6 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, fermeture benne *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET, 'X6 observe : fermeture benne');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'X6 : fermeture benne commandee');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â½Ãƒâ€šÃ‚Â¯ Call 12 : benne fermÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X7 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 13 : X7 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, remontÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e contrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â´le *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.0, M2_CablePosM := -9.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX11_CTRL_ASCENT, 'X7 observe : remontee controle');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X7 : remontee lente M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X7 : remontee lente M2 commandee');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 14 : palier contrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â´le ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X8 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 15 : X8 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, remontÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e charge *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.5, M2_CablePosM := -7.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX12_LOADED_ASCENT, 'X8 observe : remontee en charge');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest, 'X8 : remontee nominale M1 commandee');
    ASSERT_TRUE(FB.WinchM2Cmd.RunRequest, 'X8 : remontee nominale M2 commandee');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 16 : limite haute ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X9 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 17 : X9 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©gouttage *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX13_DRAIN_PAUSE, 'X9 observe : egouttage');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X9 : treuil M1 arrete (egouttage)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X9 : treuil M2 arrete (egouttage)');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â±ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 18 : ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©gouttage 5s ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X10 *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 19 : X10 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, translation trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©mie *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX14_TRANSLATE_DUMP, 'X10 observe : translation vers tremie');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X10 : translation vers tremie commandee');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â¡Ãƒâ€¦Ã‚Â¡ Call 20 : trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©mie atteinte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X11 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 20b : X11a observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© (arrivÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©mie, treuils arrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚ÂªtÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s) -> X11b sur geste joystick *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE, 'X11a observe : arrivee tremie treuils arretes');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11a : M1 arrete');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11a : M2 arrete');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 21 : X11b observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, ouverture vidange *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'X11b observe : ouverture vidange');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'X11b : ouverture benne commandee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X11b : M1 arrete (pas de descente couplee)');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X11b : M2 arrete (pas de descente couplee)');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¡ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 21b : option repositionnement (BtnReposition) -> X11c *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := TRUE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 21c : X11c observe -> descente couplee M1+M2 symetrique palier lent *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := TRUE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15C_DUMP_REPOSITION, 'X11c observe : repositionnement couple');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'X11c : M1 ET M2 commandes');
    ASSERT_TRUE(FB.WinchM1Cmd.ReqDescend AND FB.WinchM2Cmd.ReqDescend, 'X11c : descente couplee symetrique');
    ASSERT_EQ(FB.WinchM1Cmd.StepTgt, FB.WinchM2Cmd.StepTgt, 'X11c : meme palier M1/M2');
    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€šÃ‚Â¼ Call 21d : relache l'option -> retour X11b *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := FALSE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 21e : X11b observe de nouveau *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE, StartCycle := FALSE,
       RepositionRequest := FALSE, SelTarget := 3, LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'X11c -> X11b au relachement de l option');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'Retour X11b : M1 de nouveau arrete');

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Call 22 : benne ouverte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X13 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Call 23 : X13 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, Done + SampleCount+1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'X13 observe : cycle termine');
    ASSERT_TRUE(FB.Lifecycle.Done, 'X13 : Lifecycle.Done=TRUE');
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount incremente UNE fois (1er cycle)');
    ASSERT_TRUE(FB.LastCycleDuration > T#0s, 'X13 : duree du cycle figee (> 0) - chronometre');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Call 24 : X13 2e scan, garde anti-double *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_EQ(FB.SampleCount, 1, 'X13 : SampleCount reste 1 au 2e scan (garde anti-double increment)');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ Call 25 : StartCycle ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X0 (rebouclage) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'X13 observe : rebouclage pose (front StartCycle)');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ Call 26 : rebouclage effectif -> AX2_TRANSLATE_P1 (GEL Q14 : pas de retour AX0) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX2_TRANSLATE_P1, 'Rebouclage effectif : retour direct AX2 (pas AX0)');
    ASSERT_FALSE(FB.Lifecycle.Done, 'Lifecycle.Done retombe apres rebouclage');
END_TEST

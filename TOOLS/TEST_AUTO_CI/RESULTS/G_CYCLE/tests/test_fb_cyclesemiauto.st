SETUP
VAR
    FB : FB_CycleSemiAuto;
    SampleCount : INT := 0;
    SampleCountTotal : UDINT := 0;
END_VAR
END_SETUP

TEST 'T262-002 AX10B : transfert Both P1 sans coupure M2 puis AX11 P2'
    (* Chargement securise de AX10B : consigne de forcage ecrite par l'operateur (T358). *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       CfgCommissioningEnable := TRUE, CfgCtrlAscentMaxStep := 2,
       CfgCtrlAscentDistanceM := 2.0, SampleCount := SampleCount, StepForceTgt := 22);
    ASSERT_TRUE(FB.ForceStepAccepted, 'AX10B forcee immediatement (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');

    (* Scans d acquittement puis d execution : aucun mouvement au chargement. *)
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Chargement AX10B sans mouvement');

    (* Nouveau geste Y+ : M1 et M2 sont publies simultanement a P1. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPull := TRUE, M2_SpeedStepApplied := 1,
       M1FinalAscentStartReady := TRUE, Benne_CloseReached := TRUE,
       Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10B_RACCORDEMENT_P1,
                'Scan transfert execute en AX10B');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest,
                'AX10B publie Both sans trou de commande');
    ASSERT_TRUE((FB.WinchM1Cmd.StepTgt = 1) AND (FB.WinchM2Cmd.StepTgt = 1),
                'AX10B publie M1 P1 et M2 P1');
    ASSERT_TRUE(FB.WinchM1Cmd.ReqAscent AND FB.WinchM2Cmd.ReqAscent,
                'AX10B conserve le sens montee des deux treuils');

    (* Scan suivant : AX11 reprend avec le plafond commun configure P2. *)
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX11_CTRL_ASCENT,
                'AX11 prend le relais apres transfert P1/P1');
    ASSERT_TRUE((FB.WinchM1Cmd.StepTgt = 2) AND (FB.WinchM2Cmd.StepTgt = 2),
                'AX11 applique le plafond commun P2');
END_TEST

(* ============================================================================
   T345-L2 - AX14->AX15A instantane, neutre obligatoire avant AX15B
   Contrat : TASK_CONTRACT_T345_L2_AX14_AX15A_INSTANTANEE.yaml
   ============================================================================ *)

TEST 'T345-L2-001 : arrivee AX14 neutre, puis nouveau push autorise AX15B'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickLeft := FALSE, JoystickRight := FALSE,
       SampleCount := SampleCount, StepForceTgt := 14);
    ASSERT_TRUE(FB.ForceStepAccepted, 'T345-L2-001 : AX14 force');
    FB(StepForceTgt := -1, Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickPush := FALSE,
       SampleCount := SampleCount);
    ADVANCE_TIME(600000000);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickPush := FALSE,
       SampleCount := SampleCount);

    (* Premier scan AX15A au neutre : le latch s'arme, sans transition dans ce meme scan. *)
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickPush := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-001 : AX15A atteint apres confirmation arret');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen OR FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest OR FB.TranslationCmd.ReqStart,
                 'T345-L2-001 : aucune commande au scan neutre AX15A');
    ASSERT_EQ(FB.OperatorAction, 'AX15a - Pousser vers le bas pour ouvrir et vider.',
              'T345-L2-001 : guide push publie apres neutre');

    (* Nouveau geste : changement d'etat, puis commande seulement au scan AX15B. *)
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-001 : transition demandee depuis AX15A');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'T345-L2-001 : aucune ouverture au scan de transition');
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN,
                'T345-L2-001 : AX15B execute au scan suivant');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'T345-L2-001 : ouverture autorisee apres neutre puis nouveau push');
END_TEST

TEST 'T345-L2-002 : push Y maintenu a l arrivee passe AX15A mais reste bloque avant neutre'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, JoystickPull := FALSE, JoystickLeft := FALSE, JoystickRight := FALSE,
       SampleCount := SampleCount, StepForceTgt := 14);
    FB(StepForceTgt := -1, Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ADVANCE_TIME(600000000);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-002 : transition AX14->AX15A sans attendre neutre');
    ASSERT_TRUE(FB.WaitingForOperator, 'T345-L2-002 : relachement operateur attendu');
    ASSERT_EQ(FB.OperatorAction, 'AX15a - Relacher le joystick avant ouverture.',
              'T345-L2-002 : message de relachement explicite');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen OR FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest OR FB.TranslationCmd.ReqStart,
                 'T345-L2-002 : Y maintenu ne commande aucun mouvement avant neutre');
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-002 : AX15A maintenu tant que Y reste pousse');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'T345-L2-002 : ReqOpen reste faux avant neutre');
END_TEST

TEST 'T345-L2-003 : diagonale X plus Y maintenue ne contourne pas le neutre AX15A'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, JoystickPull := FALSE, JoystickLeft := TRUE, JoystickRight := FALSE,
       SampleCount := SampleCount, StepForceTgt := 14);
    FB(StepForceTgt := -1, Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    ADVANCE_TIME(600000000);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    FB(Translation_At_Tremie := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-003 : diagonale n empeche pas l arrivee AX15A');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen OR FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest OR FB.TranslationCmd.ReqStart,
                 'T345-L2-003 : diagonale ne produit aucun mouvement avant neutre');
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickLeft := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-003 : diagonale maintenue reste bloquee en AX15A');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'T345-L2-003 : ReqOpen reste faux sous diagonale');
END_TEST

TEST 'T345-L2-004 : forcage repete cible 15 efface un latch neutre precedent'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickPush := FALSE,
       SampleCount := SampleCount, StepForceTgt := 15);
    FB(StepForceTgt := -1, JoystickDeflected := FALSE, DeadmanArmed := TRUE, JoystickPush := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-004 : AX15A execute au neutre et latch arme');

    (* Meme cible forcee pendant un push : le reset doit avoir lieu meme sans changement d enum. *)
    FB(StepForceTgt := 15, JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'T345-L2-004 : forcage repete 15 accepte et neutre en commandes');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'T345-L2-004 : scan de forcage sans ouverture');
    FB(StepForceTgt := -1, JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
                'T345-L2-004 : latch perime ne survit pas au forcage repete');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'T345-L2-004 : push deja actif reste bloque sans nouveau neutre');
END_TEST

TEST 'T345-L2-005 : non regression AX2 vers AX3 conserve le geste PushOnly existant'
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       Translation_At_P1 := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, JoystickPull := FALSE, JoystickLeft := FALSE, JoystickRight := FALSE,
       SampleCount := SampleCount, StepForceTgt := 2);
    FB(StepForceTgt := -1, Translation_At_P1 := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       JoystickLeft := FALSE, JoystickRight := FALSE, SampleCount := SampleCount);
    ADVANCE_TIME(600000000);
    FB(Translation_At_P1 := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       JoystickLeft := FALSE, JoystickRight := FALSE, SampleCount := SampleCount);
    FB(Translation_At_P1 := TRUE, Translation_Busy := FALSE,
       JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       JoystickLeft := FALSE, JoystickRight := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX3_OPEN_BUCKET,
                'T345-L2-005 : AX2->AX3 PushOnly inchange');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'T345-L2-005 : AX3 ouvre comme avant');
END_TEST

TEST 'T262-003 AX10B : timeout M1 borne a 2 s puis repli sans redemarrage implicite'
    (* Preparation AX10B au neutre, comme pour le test nominal (T358). *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       CfgCommissioningEnable := TRUE, CfgCtrlAscentMaxStep := 2,
       CfgCtrlAscentDistanceM := 2.0, SampleCount := SampleCount, StepForceTgt := 22);
    ASSERT_TRUE(FB.ForceStepAccepted, 'AX10B forcee pour test timeout (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);

    (* M1 indisponible : M2 est tenu en P1 pendant la fenetre bornee. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPull := TRUE, M2_SpeedStepApplied := 1,
       M1FinalAscentStartReady := FALSE, Benne_CloseReached := TRUE,
       Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.BucketCmd.ReqHoldAscentP1AfterClose,
                'Fenetre AX10B : maintien P1 actif avant timeout');

    ADVANCE_TIME(2100000000);
    FB(SampleCount := SampleCount);
    ASSERT_FALSE(FB.BucketCmd.ReqHoldAscentP1AfterClose,
                 'Timeout : maintien M2 libere');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Timeout : aucun redemarrage pendant arret de repli');

    ADVANCE_TIME(600000000);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10B_RACCORDEMENT_P1,
                'Repli : AX10B conserve la main pendant la confirmation arret');
    ADVANCE_TIME(600000000);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10B_RACCORDEMENT_P1,
                'Repli : dernier scan AX10B avant reprise');
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX11_CTRL_ASCENT,
                'Repli : reprise explicite par AX11');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest,
                'Repli : AX11 reprend les deux treuils ensemble');
END_TEST

TEST 'T331-001 AX15d micro-step benne : tirer ouvre le module, pousser ouvrir, relacher retour AX15B'
    SampleCount := 0;

    (* Chargement securise de l etape de vidage au joystick neutre, machine arretee. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       SampleCount := SampleCount);
    FB(StepForceTgt := 16, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Etape de vidage forcee (T331-001)');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);

    (* Geste nominal maintenu Y- : vidage, treuils neutralises, aucune transition. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'Vidage observe');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'Vidage : ouverture benne commandee');
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'Vidage : aucune fermeture benne commandee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Vidage : les deux treuils restent neutralises');

    (* T383 : tirer ne fait PLUS de saut AX15B -> AX10. Il entre dans le micro-step AX15D. *)
    FB(JoystickPush := FALSE, JoystickPull := TRUE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG,
                'T383 : tirer entre dans le micro-step benne AX15D');
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET,
                 'T383 : AUCUN saut vers AX10 (decharge non declaree retiree)');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'AX15D : ouverture neutralisee au tirer');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'AX15D : tirer ferme la benne');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'AX15D : les deux treuils restent a 0 (aucun mouvement)');

    (* Module : pousser dans AX15D rouvre la benne, treuils toujours 0. *)
    FB(JoystickPush := TRUE, JoystickPull := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG,
                'AX15D : on reste dans le micro-step pendant la manipulation');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'AX15D : pousser ouvre la benne');
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'AX15D : aucune fermeture simultanee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'AX15D : treuils neutralises pendant le module');

    (* Retour au centre mort : on reprend le vidage (AX15B) sans remontee. *)
    FB(JoystickPush := FALSE, JoystickPull := FALSE, JoystickDeflected := FALSE,
       SampleCount := SampleCount);
    FB(SampleCount := SampleCount);   // AX15D assigne State:=AX15B -> CycleStep au scan suivant
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN,
                'AX15D : relachement -> retour au vidage AX15B');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen OR FB.BucketCmd.ReqClose,
                 'AX15D : neutre = les deux demandes benne a zero');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'AX15D : aucun treuil commande au relachement');

    (* Fin de vidage : la benne ouverte amene AX18 sur geste pousse, inchange. *)
    FB(Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE,
       Benne_IsRoughlyClosed := FALSE, JoystickDeflected := TRUE, JoystickPush := TRUE,
       SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC,
                'Fin de vidage apres module : AX18 inchange');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'Fin de vidage : ouverture relachee');
END_TEST

TEST 'T331-002 AX15b/AX15c non-regression : vidage nominal et repositionnement inchanges'
    SampleCount := 0;

    (* Chargement securise de l etape de vidage au joystick neutre. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       SampleCount := SampleCount);
    FB(StepForceTgt := 16, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Etape de vidage forcee (non-regression T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount);

    (* Vidage nominal Y- : ouverture seule, treuils neutralises. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'Vidage nominal inchange');
    ASSERT_TRUE(FB.BucketCmd.ReqOpen, 'Vidage nominal : ouverture commandee');
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'Vidage nominal : aucune fermeture');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Vidage nominal : treuils a l arret');

    (* Option IHM maintenue : repositionnement couple en descente, inchange. *)
    FB(RepositionRequest := TRUE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15C_DUMP_REPOSITION,
                'Repositionnement inchange : AX15c atteint');
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest,
                'Repositionnement : M1 et M2 commandes');
    ASSERT_TRUE(FB.WinchM1Cmd.ReqDescend AND FB.WinchM2Cmd.ReqDescend,
                'Repositionnement : descente couplee conservee');
    ASSERT_FALSE(FB.WinchM1Cmd.ReqAscent OR FB.WinchM2Cmd.ReqAscent,
                 'Repositionnement : aucune montee commandee');
    ASSERT_EQ(FB.WinchM1Cmd.StepTgt, FB.WinchM2Cmd.StepTgt,
              'Repositionnement : meme palier M1/M2');

    (* Relachement de l option : retour au vidage, treuils de nouveau a l arret. *)
    FB(RepositionRequest := FALSE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN,
                'Retour au vidage inchange au relachement de l option');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Retour vidage : treuils arretes');

    (* Vidage termine : la benne ouverte amene la fin de passe, inchange. *)
    FB(Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE,
       Benne_IsRoughlyClosed := FALSE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'Fin de vidage inchangee');
    ASSERT_FALSE(FB.BucketCmd.ReqOpen, 'Fin de vidage : ouverture relachee');
    ASSERT_EQ(FB.SampleCount, 1, 'Fin de vidage : compteur incremente une seule fois');
END_TEST

TEST 'T331-003 AX15d micro-step : perte du geste, de l homme-mort ou defaut neutralise sans reprise'
    SampleCount := 0;

    (* Chargement securise de l etape de vidage au joystick neutre. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       SampleCount := SampleCount);
    FB(StepForceTgt := 16, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Etape de vidage forcee (T331-003)');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);

    (* Vidage puis tirer maintenu : entre dans le micro-step AX15D, fermeture commandee. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    FB(JoystickPush := FALSE, JoystickPull := TRUE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG,
                'Micro-step : entree dans AX15D au tirer');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'Micro-step : fermeture benne commandee au tirer');

    (* Relachement du manche : plus aucune demande, retour au vidage AX15B. *)
    FB(JoystickDeflected := FALSE, JoystickPull := FALSE, DeadmanArmed := TRUE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'Relachement : fermeture benne neutralisee');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Relachement : treuils neutralises');
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN,
                'Relachement : retour a AX15B (reprendre le vidage)');
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'Relachement : aucune reprise automatique');

    (* Geste repris (tirer) : retour dans le micro-step sous commande maintenue. *)
    FB(JoystickDeflected := TRUE, JoystickPull := TRUE, SampleCount := SampleCount);
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG,
                'Geste repris : retour dans AX15D');
    ASSERT_TRUE(FB.BucketCmd.ReqClose, 'Geste repris : fermeture benne reprise');

    (* Perte de l homme-mort : neutralisation complete, etape conservee. *)
    FB(DeadmanArmed := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqOpen
                 OR FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Homme-mort perdu : plus aucune demande de mouvement');
    FB(SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG,
                'Homme-mort perdu : etape conservee, aucune reprise automatique');

    (* Defaut pendant le micro-step : repli AX_STAB, sorties neutralisees. *)
    FB(DeadmanArmed := TRUE, HeartbeatIhmOk := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Defaut : repli AX_STAB');
    ASSERT_FALSE(FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqOpen
                 OR FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Defaut : toutes les demandes neutralisees');
    ASSERT_FALSE(FB.Lifecycle.Busy, 'Defaut : cycle non actif');

    (* Acquittement conscient : cause disparue puis Reset. *)
    FB(HeartbeatIhmOk := TRUE, JoystickDeflected := FALSE, JoystickPull := FALSE,
       DeadmanArmed := FALSE, Reset := TRUE, SampleCount := SampleCount);
    FB(Reset := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Latched, 'Acquittement : defaut efface apres cause disparue');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Acquittement : retour au repos');
END_TEST

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
    (* T358 : consigne unique ecrite par l'operateur — AUCUNE condition de contexte,
       aucune confirmation. Le joystick est volontairement DEFLECHI pour prouver que la
       garde « joystick au neutre » a bien disparu, et l'homme-mort reste absent pour
       verifier que le forcage lui-meme ne cree AUCUN mouvement. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := TRUE, DeadmanArmed := FALSE,
       CfgCommissioningEnable := TRUE, SampleCount := SampleCount, StepForceTgt := 4);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Saut accepte joystick deflechi, sans aucune condition (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Aucune action au scan du forcage');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 chargee au scan suivant (T358)');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Le forcage ne cree aucun mouvement');
    FB(StartCycle := FALSE, DeadmanArmed := TRUE, JoystickDeflected := TRUE,
       JoystickPull := TRUE, JoystickPush := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Y+ ne commande pas la descente AX4');
    FB(JoystickPull := FALSE, JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.WinchM1Cmd.RunRequest AND FB.WinchM2Cmd.RunRequest, 'Y- commande les deux voies AX4');
END_TEST

TEST 'TC-P04-028 T258 : ForÃ§age AX_STAB refuse et reste neutre'
    (* T358 : AX_STAB (19) etait explicitement REFUSE par l ancienne garde « <> 19 »
       alors que c est une valeur d enum valide : elle est desormais forcable. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE, SampleCount := SampleCount,
       StepForceTgt := 19);
    ASSERT_TRUE(FB.ForceStepAccepted, 'AX_STAB desormais forcable : 19 est dans la plage enum (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.ForceStepRejected, 'Aucun rejet d une valeur d enum valide (T358)');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Sorties neutres au scan du forcage');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'AX_STAB chargee au scan suivant (T358)');
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
    (* T358 : la SEULE validation restante est la plage de l enum. Hors plage = rejet,
       etape inchangee, consigne acquittee (donc jamais rejouee en boucle). *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount, StepForceTgt := 40);
    ASSERT_TRUE(FB.ForceStepRejected, 'Cible hors plage refusee (T358)');
    ASSERT_FALSE(FB.ForceStepAccepted, 'Aucune consigne appliquee hors plage');
    ASSERT_TRUE(FB.ForceStepResult <> '', 'Motif de rejet publie (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Aucune etape chargee apres rejet');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Start ne peut executer aucune cible');
    (* La consigne acquittee, le scan suivant repart de la sentinelle : aucun rejeu. *)
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepRejected, 'Impulsion de rejet d un seul scan (T358)');
    FB(StartCycle := FALSE, DeadmanArmed := TRUE, JoystickDeflected := TRUE,
       JoystickPush := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Nouveau geste Y- sans cible reste neutre');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart OR FB.BucketCmd.ReqOpen OR FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqKoboldMeasureEnable,
                 'Tous les autres actionneurs restent neutres apres rejet');
END_TEST

TEST 'TC-P04-031 T258 : Apply et Start simultanes restent en preparation neutre'
    (* T358 : AX18_DONE_SYNC (18) etait explicitement REFUSE par l ancienne garde
       « <> 18 » alors que c est une valeur d enum valide : elle est desormais forcable. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount, StepForceTgt := 18);
    ASSERT_TRUE(FB.ForceStepAccepted, 'AX18 forcee : 18 est dans la plage enum (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.ForceStepRejected, 'Aucun rejet d une valeur d enum valide (T358)');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest, 'Aucune commande au scan du forcage');
    FB(StepForceTgt := -1, StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'AX18 chargee au scan suivant (T358)');
    ASSERT_FALSE(FB.TranslationCmd.ReqStart OR FB.BucketCmd.ReqOpen OR FB.BucketCmd.ReqClose OR FB.BucketCmd.ReqKoboldMeasureEnable,
                 'Aucun autre actionneur commande par le forcage (T358)');
END_TEST

TEST 'TC-P04-032 T258 : Reset simultane annule le forçage'
    (* T358 : une consigne ecrite sur le MEME scan qu un Reset est effacee par le Reset
       (l abandon et l acquittement precedent le bloc de forcage dans l ordre intra-scan) :
       aucun saut d etape ne peut survivre a un acquittement. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE, Reset := TRUE,
       SampleCount := SampleCount, StepForceTgt := 4);
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.ForceStepAccepted, 'Aucun forcage applique : le Reset du meme scan neutralise la consigne');
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 non chargee apres Reset + consigne');
    FB(StepForceTgt := -1, Reset := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Aucun saut differe au scan suivant (T358)');
END_TEST

TEST 'TC-P04-033 T258 : Forcage semi-auto independant du bit commissioning'
    (* T358 : une consigne ecrite alors que le CYCLE est inactif (hors SEMI_AUTO) est
       ECARTEE — acquittee et motif publie. Elle n est JAMAIS honoree plus tard, a la
       reactivation du cycle : ce serait un saut d etape sans geste nouveau. *)
    FB(Enable := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, CfgCommissioningEnable := TRUE, SampleCount := SampleCount,
       StepForceTgt := 4);
    ASSERT_TRUE(FB.ForceStepRejected, 'Consigne ecartee : cycle inactif (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    ASSERT_TRUE(FB.ForceStepResult <> '', 'Motif d ecart publie (T358)');
    FB(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'Aucun saut differe a la reactivation (T358)');
    (* Le forcage reste possible des que le cycle est actif : meme cible, meme scan. *)
    FB(StepForceTgt := 4, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Forcage effectif une fois le cycle actif (T358)');
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
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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

    (* T358 : la reprise consciente apres bascule de mode est CONSERVEE — elle ne passe
       plus par le chemin du forçage, et le scenario « forçage refuse pendant l attente »
       n existe plus : la consigne 19 (AX_STAB) est desormais ACCEPTEE (test T358 dedie).
       Ce bloc verifie donc la reprise consciente SANS aucune consigne de forçage. *)
    FB(Enable := FALSE, Mode := E_Mode.MAINT_N1, JoystickDeflected := FALSE,
       DeadmanArmed := FALSE, JoystickPush := FALSE, CfgCommissioningEnable := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, JoystickDeflected := FALSE,
       DeadmanArmed := FALSE, JoystickPush := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING,
                'Etape X4 memorisee : attente de reprise consciente');
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Retour en SEMI_AUTO sans geste : aucune remise en mouvement');
    FB(DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE,
       StartCycle := TRUE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest OR FB.WinchM2Cmd.RunRequest,
                 'Scan Start de reprise reste neutre');

    (* Call 8 : nouveau geste apres Start -> reprise a X4 SANS repartir de X0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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

    (* Laisser expirer la pause inter-etapes AX9 avant d'atteindre la cible. *)
    ADVANCE_TIME(1100000000);

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 10 : hauteur fermeture ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X6 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
    ASSERT_FALSE(FB.BucketCmd.ReqClose, 'X6 : pause inter-etape avant fermeture benne');
    // Premier scan stable AX10 : arme le TON apres mise a jour de ExtractionDelayState.
    FB();
    ADVANCE_TIME(1100000000);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â½Ãƒâ€šÃ‚Â¯ Call 12 : benne fermÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X7 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := FALSE, JoystickPull := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := FALSE, JoystickPull := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
    ASSERT_FALSE(FB.WinchM1Cmd.RunRequest, 'X7 : pause inter-etape M1 avant remontee controlee');
    ASSERT_FALSE(FB.WinchM2Cmd.RunRequest, 'X7 : pause inter-etape M2 avant remontee controlee');
    // Premier scan stable AX11 puis ecoulement de la temporisation de debug.
    FB();
    ADVANCE_TIME(1100000000);

    (* ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â Call 14 : palier contrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â´le ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X8 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := FALSE, JoystickPull := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.0, M2_CablePosM := -7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 15 : X8 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, remontÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©e charge *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := FALSE, JoystickPull := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -7.0, M2_CablePosM := -7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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

    (* Call 18 : egouttage 5s au joystick neutre ; verifier le decompte avant AX14 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickDeflected := FALSE, JoystickPush := FALSE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.DrainTimeRemaining = T#5s, 'AX13 : consigne restante publiee au demarrage du TON');
    ADVANCE_TIME(2000000000);
    FB();
    ASSERT_TRUE(FB.DrainTimeRemaining = T#3s, 'AX13 : temps restant decremente de 5s a 3s');
    ADVANCE_TIME(3000000000);

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‹Å“ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Call 19 : X10 observÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©, translation trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©mie *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := FB.SampleCount);
    ASSERT_TRUE(FB.DrainTimeRemaining = T#0s, 'AX13 : temps restant remis a zero a expiration TON');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX14_TRANSLATE_DUMP, 'X10 observe : translation vers tremie');
    ASSERT_TRUE(FB.TranslationCmd.ReqStart, 'X10 : translation vers tremie commandee');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã‚Â¡Ãƒâ€¦Ã‚Â¡ Call 20 : trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©mie atteinte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ X11 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
    ASSERT_TRUE((FB.LastCycleDuration_Min > 0) OR (FB.LastCycleDuration_S > 0),
                'X13 : duree du cycle figee (> 0) - chronometre min/sec (T347)');
    ASSERT_TRUE((FB.LastCycleDuration_Min = FB.CurrentCycleElapsed_Min)
                AND (FB.LastCycleDuration_S = FB.CurrentCycleElapsed_S),
                'X13 : paire min/sec figee depuis le chrono courant (T347)');

    (* ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Call 24 : X13 2e scan, garde anti-double *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0,
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
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0,
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

TEST 'TC-P04-034 T299 : journalier ET totalisateur incrementes au MEME evenement AX18 (1 fois par cycle)'
    SampleCount := 0;
    SampleCountTotal := 4;

    (* Chargement securise de l etape de vidage AX15b au joystick neutre, machine arretee. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE, ResetSampleCountRequest := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(StepForceTgt := 16, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Etape de vidage forcee (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'Chargement de l etape : journalier non compte');
    ASSERT_TRUE(SampleCountTotal = 4, 'Chargement de l etape : totalisateur inchange');

    (* Geste Y- maintenu avec benne deja ouverte : AX15b bascule vers AX18 au scan suivant. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'Vidage observe avant bascule AX18');

    (* Scan suivant : AX18 s execute et incremente les DEUX compteurs sur le meme evenement. *)
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'AX18 execute');
    ASSERT_TRUE(SampleCount = 1, 'Journalier : +1 sur AX18');
    ASSERT_TRUE(SampleCountTotal = 5, 'Totalisateur : +1 sur le MEME evenement AX18');

    (* Conditions maintenues : aucun second comptage (garde de front SampleCountDone). *)
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'AX18 toujours actif');
    ASSERT_TRUE(SampleCount = 1, 'Journalier : pas de second increment sur le meme cycle');
    ASSERT_TRUE(SampleCountTotal = 5, 'Totalisateur : pas de second increment sur le meme cycle');
END_TEST

TEST 'TC-P04-035 T299 : RAZ manuelle IHM du journalier sur FRONT montant, totalisateur intact'
    SampleCount := 7;
    SampleCountTotal := 12;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE, StartCycle := FALSE,
       ResetSampleCountRequest := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 7, 'Aucune RAZ sans appui sur le bouton');
    ASSERT_TRUE(SampleCountTotal = 12, 'Aucune RAZ sans appui : totalisateur inchange');

    (* Front montant : le journalier passe a zero, le totalisateur ne bouge pas. *)
    FB(ResetSampleCountRequest := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'RAZ IHM : journalier remis a zero sur front montant');
    ASSERT_TRUE(SampleCountTotal = 12, 'RAZ IHM : totalisateur INTACT');

    (* Bouton MAINTENU a l etat haut : aucune RAZ repetee (jamais un niveau, toujours un front). *)
    SampleCount := 5;
    FB(ResetSampleCountRequest := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 5, 'Bouton maintenu : aucune RAZ sans nouveau front');
    ASSERT_TRUE(SampleCountTotal = 12, 'Bouton maintenu : totalisateur toujours intact');

    (* Nouveau front : la RAZ redevient effective. *)
    FB(ResetSampleCountRequest := FALSE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(ResetSampleCountRequest := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'Nouveau front : RAZ de nouveau effective');
    ASSERT_TRUE(SampleCountTotal = 12, 'Totalisateur : jamais ecrit par la RAZ manuelle');
END_TEST

TEST 'TC-P04-036 T299 : mode NEVER (defaut) — aucun auto-reset au demarrage de cycle'
    SampleCount := 9;
    SampleCountTotal := 30;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, HeartbeatIhmOk := TRUE,
       M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       StartCycle := TRUE, ResetSampleCountRequest := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CfgSampleCountResetMode = E_CycleSampleCountResetMode.NEVER, 'Mode configure = NEVER');
    ASSERT_TRUE(SampleCount = 9, 'Mode NEVER : le demarrage ne remet PAS le journalier a zero');
    ASSERT_TRUE(SampleCountTotal = 30, 'Mode NEVER : totalisateur inchange');
END_TEST

TEST 'TC-P04-037 T299 : mode ON_FIRST_START — RAZ au 1er demarrage de cycle, une seule fois'
    SampleCount := 9;
    SampleCountTotal := 30;

    (* Scan sans demarrage : aucun armement consomme, aucune RAZ. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, HeartbeatIhmOk := TRUE,
       M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       StartCycle := FALSE, ResetSampleCountRequest := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.ON_FIRST_START,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 9, 'Aucun demarrage : journalier conserve');

    (* Premier demarrage depuis la mise sous tension (instance neuve = boot) : RAZ du journalier. *)
    FB(StartCycle := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'ON_FIRST_START : journalier remis a zero au 1er demarrage');
    ASSERT_TRUE(SampleCountTotal = 30, 'ON_FIRST_START : totalisateur JAMAIS remis a zero');

    (* Demarrages suivants : la RAZ automatique ne se reproduit pas. *)
    SampleCount := 4;
    FB(StartCycle := FALSE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(StartCycle := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 4, 'ON_FIRST_START : une seule RAZ auto par mise sous tension');
    ASSERT_TRUE(SampleCountTotal = 30, 'ON_FIRST_START : totalisateur toujours intact');
END_TEST

TEST 'TC-P04-038 T299 : mode ON_SAFETY_REARM — RAZ au rearmement AU, sur front'
    SampleCount := 6;
    SampleCountTotal := 21;

    (* Chaine AU non rearmee : aucune RAZ. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, HeartbeatIhmOk := TRUE,
       M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       StartCycle := FALSE, ResetSampleCountRequest := FALSE, SafetyRearmed := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.ON_SAFETY_REARM,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 6, 'AU non rearmee : journalier conserve');

    (* Rearmement AU (front montant) : RAZ du journalier seul. *)
    FB(SafetyRearmed := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'ON_SAFETY_REARM : journalier remis a zero au rearmement AU');
    ASSERT_TRUE(SampleCountTotal = 21, 'ON_SAFETY_REARM : totalisateur JAMAIS remis a zero');

    (* Signal de rearmement MAINTENU : aucune RAZ repetee. *)
    SampleCount := 3;
    FB(SafetyRearmed := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 3, 'Rearmement maintenu : aucune RAZ sans nouveau front');
    ASSERT_TRUE(SampleCountTotal = 21, 'Rearmement maintenu : totalisateur intact');
END_TEST

TEST 'TC-P04-039 T299 : totalisateur — test NEGATIF, aucun chemin ne peut l ecrire (RAZ, reset, mode)'
    SampleCount := 50;
    SampleCountTotal := 1000;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, HeartbeatIhmOk := TRUE,
       M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE, ResetSampleCountRequest := FALSE, SafetyRearmed := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 50, 'Etat initial du journalier');
    ASSERT_TRUE(SampleCountTotal = 1000, 'Etat initial du totalisateur');

    (* Tentative 1 : bouton de RAZ IHM (front) — efface le journalier, jamais le totalisateur.
       Le journalier est RE-SEME avant chaque tentative suivante : chaque assertion est discriminante. *)
    FB(ResetSampleCountRequest := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'RAZ IHM : journalier efface (50 -> 0)');
    ASSERT_TRUE(SampleCountTotal = 1000, 'RAZ IHM : totalisateur inchange');

    (* Tentative 2 : RAZ automatique par mode ON_FIRST_START + demarrage de cycle. *)
    SampleCount := 30;
    FB(ResetSampleCountRequest := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.ON_FIRST_START,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 30, 'Mode (b) arme : aucune RAZ avant demarrage');
    FB(StartCycle := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'Mode (b) : journalier efface au 1er demarrage (30 -> 0)');
    ASSERT_TRUE(SampleCountTotal = 1000, 'Mode (b) : totalisateur inchange');

    (* Tentative 3 : RAZ automatique par mode ON_SAFETY_REARM (front de rearmement AU). *)
    SampleCount := 20;
    FB(StartCycle := FALSE, CfgSampleCountResetMode := E_CycleSampleCountResetMode.ON_SAFETY_REARM,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 20, 'Mode (c) arme : aucune RAZ avant rearmement');
    FB(SafetyRearmed := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 0, 'Mode (c) : journalier efface au rearmement AU (20 -> 0)');
    ASSERT_TRUE(SampleCountTotal = 1000, 'Mode (c) : totalisateur inchange');

    (* Tentative 4 : reset machine, abandon, sortie de mode (Enable FALSE) — aucun effet, sur AUCUN
       des deux compteurs : aucune RAZ parasite ne doit exister hors des chemins volontaires. *)
    SampleCount := 11;
    FB(SafetyRearmed := FALSE, Reset := TRUE, AbortCycle := TRUE,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(Reset := FALSE, AbortCycle := FALSE, Enable := FALSE, Mode := E_Mode.MAINT_N1,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 11, 'Reset/Abandon/sortie de mode : journalier non remis a zero');
    ASSERT_TRUE(SampleCountTotal = 1000, 'Reset/Abandon/sortie de mode : totalisateur inchange');

    (* Contre-preuve : le SEUL chemin d ecriture reste l increment AX18 de fin de cycle. *)
    FB(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, Reset := FALSE,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 11, 'Totalisateur non ecrit hors AX18 : journalier egalement intact');
    ASSERT_TRUE(SampleCountTotal = 1000, 'Totalisateur toujours a sa valeur avant la fin de cycle');
END_TEST

TEST 'TC-P04-040 T299 : mode (b) active EN COURS DE POSTE — aucune RAZ differee (drapeau consomme)'
    SampleCount := 42;
    SampleCountTotal := 500;

    (* 1. Premier demarrage du poste, mode NEVER : le drapeau "1er demarrage deja vu" est consomme
       meme si aucun mode de RAZ automatique n'est actif. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, HeartbeatIhmOk := TRUE,
       M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       StartCycle := TRUE, AbortCycle := FALSE, ResetSampleCountRequest := FALSE, SafetyRearmed := FALSE,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 42, 'Mode NEVER au 1er demarrage : journalier conserve');

    (* 2. L operateur active le mode ON_FIRST_START en cours de poste. *)
    FB(StartCycle := FALSE, CfgSampleCountResetMode := E_CycleSampleCountResetMode.ON_FIRST_START,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 42, 'Bascule de mode : aucune RAZ immediate');

    (* 3. Retour au repos (Abandon) puis NOUVEAU demarrage : le 1er demarrage du poste a deja eu
       lieu, la RAZ automatique NE doit PAS se declencher -> aucun comptage du poste n est perdu. *)
    FB(StartCycle := FALSE, AbortCycle := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(AbortCycle := FALSE, StartCycle := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(SampleCount = 42, 'Mode (b) active en cours de poste : aucune RAZ differee');
    ASSERT_TRUE(SampleCountTotal = 500, 'Totalisateur inchange par la bascule de mode');
END_TEST

TEST 'T347-001 : duree de cycle exposee en minutes/secondes entieres (chrono, figeage AX18, RAZ hors cycle)'
    SampleCount := 0;
    SampleCountTotal := 0;

    (* Chargement securise de l etape de vidage AX15b au joystick neutre, machine arretee
       (meme montage que TC-P04-034 : le FB n atteint AX18 qu apres un vidage engage). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE, ResetSampleCountRequest := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(StepForceTgt := 16, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.ForceStepAccepted, 'T347 : etape de vidage forcee (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);

    (* Scan de stabilisation n°1 : geste Y- maintenu, fin de vidage PAS encore confirmee -> AX15b
       maintenue, Lifecycle.Busy passe a TRUE. *)
    FB(StartCycle := FALSE, JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN, 'T347 : vidage observe avant bascule AX18');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'T347 : chronometre arme des que Lifecycle.Busy est actif');

    (* Scan de stabilisation n°2 : le chrono interne (TON sur Lifecycle.Busy) demarre sur CE scan
       (IN passe FALSE->TRUE ici). Sans ce scan, l avance de temps qui suit serait perdue : le TON
       capturerait son origine APRES l avance et resterait a zero. *)
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);

    (* 65 s de cycle simulees AVANT l observation de AX18 : la conversion TIME -> min/sec devient
       discriminante (65 s = 1 minute entiere + 5 secondes ; ni 65 dans un champ unique, ni 65000 ms).
       ADVANCE_TIME avance l horloge simulee, le TON interne l integre au scan suivant. *)
    ADVANCE_TIME(65000000000);
    FB(Benne_Done := TRUE, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX15B_DUMP_OPEN,
                'T347 : fin de vidage confirmee, bascule AX18 demandee');
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX18_DONE_SYNC, 'T347 : AX18 execute');
    ASSERT_EQ(FB.CurrentCycleElapsed_Min, 1, 'T347 : chrono 65 s -> 1 minute entiere');
    ASSERT_EQ(FB.CurrentCycleElapsed_S, 5, 'T347 : chrono 65 s -> 5 secondes (plage 0..59)');
    ASSERT_EQ(FB.LastCycleDuration_Min, 1, 'T347 : duree figee a AX18 -> minutes');
    ASSERT_EQ(FB.LastCycleDuration_S, 5, 'T347 : duree figee a AX18 -> secondes');

    (* Scan suivant : le chrono repart de zero (Lifecycle.Busy retombe), la duree figee persiste. *)
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_EQ(FB.CurrentCycleElapsed_Min, 0, 'T347 : chrono remis a zero hors cycle (minutes)');
    ASSERT_EQ(FB.CurrentCycleElapsed_S, 0, 'T347 : chrono remis a zero hors cycle (secondes)');
    ASSERT_EQ(FB.LastCycleDuration_Min, 1, 'T347 : duree figee conservee apres retombee de Busy (minutes)');
    ASSERT_EQ(FB.LastCycleDuration_S, 5, 'T347 : duree figee conservee apres retombee de Busy (secondes)');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════════════
   T358 — FORCAGE DE STEP SANS GARDE : saut immediat, consigne acquittee par le FB.
   Les cas ci-dessous verrouillent le contrat TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE :
   aucune condition de contexte, plage d'enumeration seule validation, acquittement,
   meme valeur immediatement re-jouable, et aucun forcage sans ecriture d'operateur.
   ═══════════════════════════════════════════════════════════════════════════════ *)

TEST 'TC-T358-001 : consigne traitee en un scan, meme valeur re-jouable, aucun rejeu en boucle'
    (* Consigne 4 : saut immediat, un seul scan, aucune confirmation. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       SampleCount := SampleCount, StepForceTgt := 4);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Consigne 4 appliquee au scan de l ecriture (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');

    (* Scan suivant : le test reproduit l acquittement de PRG_03, puis l etape s execute. *)
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX4_DESCEND_DIVING, 'AX4 active au scan suivant (T358)');

    (* Scans libres : aucun rejeu automatique, le GRAFCET se comporte normalement.
       (Un declenchement sur « cible <> etape courante » aurait ramene l etape en boucle.) *)
    FB(JoystickDeflected := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepAccepted, 'Aucun rejeu automatique du forcage (T358)');
    FB(SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepAccepted, 'Aucun rejeu automatique au scan suivant (T358)');

    (* La MEME valeur est re-jouable immediatement : la consigne avait ete acquittee. *)
    FB(StepForceTgt := 4, SampleCount := SampleCount);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Meme valeur re-jouable sans valeur intermediaire (T358)');
END_TEST

TEST 'TC-T358-002 : un defaut DEJA LATCHE ne bloque plus le forcage de step'
    (* Sequence d etablissement et de latch reprise du test TC-P04-003. *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SampleCount := SampleCount);
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, JoystickDeflected := TRUE, JoystickPush := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE, M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE, M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE, M1_SpeedStepApplied := 4, M2_SpeedStepApplied := 4, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX1_INIT, 'Etabli en AX1 avant injection');
    FB(StartCycle := FALSE, WinchSyncError := TRUE, SampleCount := SampleCount);
    ASSERT_TRUE(FB.Fault.Error, 'Defaut LIVE actif');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX_STAB, 'Repli AX_STAB sur defaut live');

    (* La cause disparait : le defaut reste LATCHE (socle defaut inchange par T358). *)
    FB(WinchSyncError := FALSE, DeadmanArmed := FALSE, JoystickDeflected := FALSE,
       JoystickPush := FALSE, SampleCount := SampleCount);
    ASSERT_FALSE(FB.Fault.Error, 'Cause disparue : plus de defaut live');
    ASSERT_TRUE(FB.Fault.Latched, 'Defaut toujours latche : etat de repli maintenu');

    (* T358 : la garde « NOT Fault.Latched » a ete retiree du forcage — le saut a lieu. *)
    FB(SampleCount := SampleCount, StepForceTgt := 10);
    ASSERT_TRUE(FB.ForceStepAccepted, 'Forcage accepte malgre un defaut LATCHE (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue par le FB : PRG_03 l acquitte (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET,
                'AX10 chargee avec un defaut latche : sortie de AX_STAB par forcage (T358)');
END_TEST

TEST 'TC-T358-003 : sans ecriture d operateur, aucun forcage (sentinelle respectee)'
    (* Aucune consigne n'est passee : l'entree garde sa sentinelle par defaut (-1). *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.ForceStepAccepted, 'Aucun forcage sans ecriture operateur (T358)');
    ASSERT_FALSE(FB.StepForceTgtTaken, 'Aucune consigne vue : PRG_03 n a rien a acquitter (T358)');
    ASSERT_FALSE(FB.ForceStepRejected, 'Sentinelle = aucune demande : aucun rejet publie');
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX0_REPOS, 'Cycle au repos : aucun saut (T358)');
END_TEST

TEST 'TC-T358-004 : un Abandon du meme scan neutralise la consigne de forcage'
    (* T358 : l Abandon et l acquittement precedent le bloc de forcage dans l ordre
       intra-scan — la consigne du MEME scan est neutralisee (arbitrage humain : aucun
       saut d etape ne peut survivre a un abandon). *)
    FB(Enable := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       SampleCount := SampleCount, AbortCycle := TRUE, StepForceTgt := 10);
    ASSERT_FALSE(FB.ForceStepAccepted, 'Consigne neutralisee par l Abandon du meme scan (T358)');
    ASSERT_TRUE(FB.StepForceTgtTaken, 'Consigne vue ce scan : PRG_03 l acquitte (T358)');
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET, 'Aucune etape chargee apres Abandon');
    FB(AbortCycle := FALSE, StepForceTgt := -1, SampleCount := SampleCount);
    ASSERT_FALSE(FB.CycleStep = E_AutoCycleStep.AX10_CLOSE_BUCKET, 'Aucun saut differe au scan suivant (T358)');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════════════
   T368 - DUREE DANS LE MESSAGE D ETAPE AX13 (temps RESTANT d egouttage)
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T368_TEMPS_ECOULE_BANDEAU_AX13.yaml (AC3).
   Arbitrage : AX13 est une ATTENTE TEMPORISEE - l operateur doit savoir combien de temps
   il attend ENCORE (et peut couper court via "passer egouttage"). Le temps ECOULE du cycle
   vit sur le bandeau mode (FB_Hmi_BannerFormatter section 1), jamais duplique ici.
   Aucun chronometre nouveau : DrainTimeRemaining est la source unique deja publiee a l IHM.
   ═══════════════════════════════════════════════════════════════════════════════ *)

TEST 'T368-002 : message AX13 porteur du temps restant d egouttage, non fige'
    SampleCount := 0;
    SampleCountTotal := 0;

    (* Chargement securise de l etape d egouttage AX13, machine arretee, joystick au neutre
       (meme montage que T347-001 : forcage de step T358, CfgDrainTime=0 -> defaut interne 5 s). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       HeartbeatIhmOk := TRUE, M1_SpeedValid := TRUE, M2_SpeedValid := TRUE,
       M1_ContactorsReleased := TRUE, M2_ContactorsReleased := TRUE,
       M1_BrakeApplied := TRUE, M2_BrakeApplied := TRUE,
       M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       M1_SpeedStepApplied := 1, M2_SpeedStepApplied := 1,
       JoystickDeflected := FALSE, DeadmanArmed := FALSE,
       JoystickPush := FALSE, JoystickPull := FALSE, JoystickRight := FALSE, JoystickLeft := FALSE,
       StartCycle := FALSE, AbortCycle := FALSE, ResetSampleCountRequest := FALSE,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       HomedM1 := TRUE, HomedM2 := TRUE, InitPositionOk := TRUE, WinchesAtTopWindow := TRUE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_CloseReached := FALSE,
       Benne_IsOpen := FALSE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       RepositionRequest := FALSE, SkipDrainRequest := FALSE, CfgDrainTime := T#0s,
       CfgCommissioningEnable := TRUE,
       CfgCtrlAscentMaxStep := 1, CfgCtrlAscentDistanceM := 2.0,
       CfgSampleCountResetMode := E_CycleSampleCountResetMode.NEVER,
       SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    FB(StepForceTgt := 13, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.ForceStepAccepted, 'T368 : etape d egouttage forcee (T358)');
    FB(StepForceTgt := -1, SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);

    (* Scan d execution de AX13 : consigne pleine, le message doit porter 5 s restantes. *)
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.CycleStep = E_AutoCycleStep.AX13_DRAIN_PAUSE, 'T368 : etape egouttage executee');
    ASSERT_TRUE(FB.DrainTimeRemaining = T#5s, 'T368 : consigne d egouttage pleine au 1er scan AX13');
    ASSERT_EQ(FB.CycleStateStr, 'AX13 - Egouttage du godet : 5s restantes',
              'T368 : message AX13 porteur du temps RESTANT (5 s)');

    (* 2 s d horloge simulee : le message suit le decompte, il ne reste pas fige. *)
    ADVANCE_TIME(2000000000);
    FB(SampleCount := SampleCount, SampleCountTotal := SampleCountTotal);
    ASSERT_TRUE(FB.DrainTimeRemaining = T#3s, 'T368 : temps restant decremente (3 s)');
    ASSERT_EQ(FB.CycleStateStr, 'AX13 - Egouttage du godet : 3s restantes',
              'T368 : message AX13 suit le decompte (3 s restantes)');
END_TEST

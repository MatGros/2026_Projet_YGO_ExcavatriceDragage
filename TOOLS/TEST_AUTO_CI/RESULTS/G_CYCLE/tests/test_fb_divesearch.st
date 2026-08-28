SETUP
VAR
    FB : FB_DiveSearch;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       DiveStartMin_M := 20.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       DiveStartMin_M := 20.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       DiveStartMin_M := 20.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-010 DiveSearch : mise en service recherche de couche'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE);
    ASSERT_TRUE(FB.Ready, 'Module DiveSearch pret');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.READY_TO_DESCEND, 'Pret a descendre');

    (* Demarrage de la descente : passe a SEARCHING_IMMERSION *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_IMMERSION, 'Passe en recherche immersion');

    (* Scan suivant dans SEARCHING_IMMERSION : activation du permis et de Busy *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    ASSERT_TRUE(FB.DescendPermit, 'Permis descente actif en recherche immersion');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Recherche en cours -> Busy');
    ASSERT_TRUE(FB.KoboldContactorCmd, 'Contacteur Kobold alimente a la volee');
END_TEST

TEST 'TC-P04-011 : Sequence complete Kobold 4 temps avec coupure contacteur sur contact fond'
    // 1. Initialisation avec seuils réalistes -> READY_TO_DESCEND
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 20.0, M2Position_M := 20.0, CurrentSpeedStep := 4,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.Ready, 'Pret a descendre');

    // 2. Demarrage descente (Scan 1: transition -> SEARCHING_IMMERSION, Scan 2: execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 12.0, M2Position_M := 12.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 12.0, M2Position_M := 12.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.KoboldContactorCmd, 'Contacteur Kobold alimente');

    // 3. Entree dans la fenetre eau -> Front montant KoboldImmersed (0 -> 1)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 8.0, M2Position_M := 8.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_BOTTOM, 'Passe en recherche du fond');

    // 4. Contact fond -> Front descendant KoboldImmersed (1 -> 0)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := -5.0, M2Position_M := -5.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.BOTTOM_CONFIRMED, 'Fond confirme');
    ASSERT_TRUE(FB.BottomTouchConfirmed, 'Contact fond valide');
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Coupure contacteur Kobold pour eviter surchauffe');
END_TEST

TEST 'TC-P04-012 : Tentative descente en Palier 5 sous Kobold declenche defaut bloquant'
    // Scan 1 : Passage a READY_TO_DESCEND
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := FALSE);
    // Scan 2 : Demarrage descente vers SEARCHING_IMMERSION
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 4);
    // Scan 3 : Passage interdit en Palier 5 -> Declenchement defaut
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 5);
    // Scan 4 : Evaluation socle de defaut
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 5);
    ASSERT_TRUE(FB.Fault.Error, 'Defaut Palier 5 interdit');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.StepAtFault, E_DiveSearchState.SEARCHING_IMMERSION, 'StepAtFault mémorise SEARCHING_IMMERSION');
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Contacteur coupe sur defaut');
END_TEST

TEST 'TC-P04-013 : Depassement tempo recherche immersion Kobold -> ERROR_HOLD et capture StepAtFault'
    // 1. Initialisation -> SEARCHING_IMMERSION. Course plancher (CableLimitAscent_M=0.15 -> MAX(1.0,..)=1.0m),
    //    timeout dynamique = 1.0/0.15*1.5 = 10s ; CycleTime=4s -> depassement au 3e scan d'accumulation.
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_IMMERSION, 'En recherche immersion');

    // 2. Avance du temps : 5 scans de 4s = 20s (> 10s timeout)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);

    ASSERT_TRUE(FB.Fault.Error, 'Defaut timeout immersion declenche');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.StepAtFault, E_DiveSearchState.SEARCHING_IMMERSION, 'StepAtFault memorise SEARCHING_IMMERSION');
    ASSERT_FALSE(FB.DescendPermit, 'Permis descente coupe');
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Contacteur Kobold coupe');
END_TEST

TEST 'TC-P04-014 : Depassement tempo recherche fond Kobold -> ERROR_HOLD et capture StepAtFault'
    // 1. Mise en condition SEARCHING_BOTTOM (immersion validee). Course fond plancher
    //    (ImmersionLower 5.0 - LimitLegalDepthMin 4.996 = 0.004 -> MAX(1.0,..)=1.0m), timeout = 10s ; CycleTime=4s.
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 20.0, M2Position_M := 20.0, CurrentSpeedStep := 4,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 12.0, M2Position_M := 12.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 8.0, M2Position_M := 8.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_BOTTOM, 'Passe en recherche fond');

    // 2. Avance du temps : 5 scans de 4s = 20s (> 10s timeout)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 7.0, M2Position_M := 7.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 6.5, M2Position_M := 6.5, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 6.0, M2Position_M := 6.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 5.5, M2Position_M := 5.5, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 5.2, M2Position_M := 5.2, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       LimitLegalDepthMin_M := 4.996, CycleTime := T#4s);

    ASSERT_TRUE(FB.Fault.Error, 'Defaut timeout fond declenche');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_EQ(FB.StepAtFault, E_DiveSearchState.SEARCHING_BOTTOM, 'StepAtFault memorise SEARCHING_BOTTOM');
    ASSERT_FALSE(FB.DescendPermit, 'Permis descente coupe');
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Contacteur coupe anti-chauffe');
END_TEST

TEST 'TC-P04-015 : Latch timeout survit au cycle Enable OFF/ON, acquitte seulement sur front Reset'
    // 1. Declenche un timeout immersion -> latch arme
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 0.005, ImmersionUpper_M := 0.0, ImmersionLower_M := 0.0,
       CableLimitAscent_M := 0.15, CycleTime := T#4s);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch timeout immersion arme');

    // 2. Enable OFF : neutralisation, mais latch conserve
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch conserve sous Enable=FALSE (pas de redemarrage auto)');

    // 3. Enable ON sans Reset : defaut toujours latche ET l'automate reste verrouille en ERROR_HOLD
    //    (garde-fou non-redemarrage auto : le latch interne TimeoutImmersionFault realimente Fault.Error).
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 20.0, M2Position_M := 20.0,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0,
       MotionRequestActive := FALSE);
    ASSERT_TRUE(FB.Fault.Latched, 'Latch toujours actif sur retour Enable=TRUE sans acquittement');
    ASSERT_TRUE(FB.Fault.Error, 'Cause interne realimente Fault.Error au retour Enable');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.ERROR_HOLD, 'Verrouille ERROR_HOLD, aucun redemarrage vers READY_TO_DESCEND');
    ASSERT_FALSE(FB.DescendPermit, 'Aucun permis descente au retour Enable sans reset');

    // 4. Front Reset (conditions de garde reunies) : acquittement effectif
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
       KoboldImmersed := FALSE, MotionRequestActive := FALSE);
    ASSERT_FALSE(FB.Fault.Latched, 'Front Reset acquitte le latch timeout');
END_TEST




TEST 'TC-P04-016 : Contacteur Kobold coupe des le relachement de la descente (anti-chauffe, H1)'
    // Entree en SEARCHING_IMMERSION sous descente active (WAIT->READY->SEARCHING puis execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_IMMERSION, 'En recherche immersion');
    ASSERT_TRUE(FB.KoboldContactorCmd, 'Contacteur alimente sous descente active');

    // Relachement de la demande de descente : contacteur et permis coupes le meme scan, sans defaut
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       BypassPreconditions := TRUE, MotionRequestActive := FALSE, MotionDirection := 0);
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Contacteur coupe des le relachement (anti-chauffe)');
    ASSERT_FALSE(FB.DescendPermit, 'Permis descente coupe des le relachement');
    ASSERT_FALSE(FB.Fault.Error, 'Aucun defaut sur simple relachement');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_IMMERSION, 'Reste en recherche (pas de bascule)');
END_TEST

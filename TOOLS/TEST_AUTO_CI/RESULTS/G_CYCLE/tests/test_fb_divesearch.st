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
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       DiveStartMin_M := 20.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       DiveStartMin_M := 20.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-010 DiveSearch : mise en service recherche de couche'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE);
    ASSERT_TRUE(FB.Ready, 'Module DiveSearch pret');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.READY_TO_DESCEND, 'Pret a descendre');

    (* Demarrage de la descente : passe a SEARCHING_IMMERSION *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_IMMERSION, 'Passe en recherche immersion');

    (* Scan suivant dans SEARCHING_IMMERSION : activation du permis et de Busy *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1);
    ASSERT_TRUE(FB.DescendPermit, 'Permis descente actif en recherche immersion');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Recherche en cours -> Busy');
    ASSERT_TRUE(FB.KoboldContactorCmd, 'Contacteur Kobold alimente a la volee');
END_TEST

TEST 'TC-P04-011 : Sequence complete Kobold 4 temps avec coupure contacteur sur contact fond'
    // 1. Initialisation avec seuils réalistes -> READY_TO_DESCEND
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 20.0, M2Position_M := 20.0, CurrentSpeedStep := 4,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.Ready, 'Pret a descendre');

    // 2. Demarrage descente (Scan 1: transition -> SEARCHING_IMMERSION, Scan 2: execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 12.0, M2Position_M := 12.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := FALSE,
       M1Position_M := 12.0, M2Position_M := 12.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_TRUE(FB.KoboldContactorCmd, 'Contacteur Kobold alimente');

    // 3. Entree dans la fenetre eau -> Front montant KoboldImmersed (0 -> 1)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BucketIsOpen := TRUE, PositionsValid := TRUE, KoboldImmersed := TRUE,
       M1Position_M := 8.0, M2Position_M := 8.0, CurrentSpeedStep := 4,
       MotionRequestActive := TRUE, MotionDirection := -1,
       DiveStartMin_M := 15.0, ImmersionUpper_M := 10.0, ImmersionLower_M := 5.0);
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.SEARCHING_BOTTOM, 'Passe en recherche du fond');

    // 4. Contact fond -> Front descendant KoboldImmersed (1 -> 0)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
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
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := FALSE);
    // Scan 2 : Demarrage descente vers SEARCHING_IMMERSION
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 4);
    // Scan 3 : Passage interdit en Palier 5 -> Declenchement defaut
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 5);
    // Scan 4 : Evaluation socle de defaut
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       BypassPreconditions := TRUE, MotionRequestActive := TRUE, MotionDirection := -1,
       CurrentSpeedStep := 5);
    ASSERT_TRUE(FB.Fault.Error, 'Defaut Palier 5 interdit');
    ASSERT_EQ(FB.DiveState, E_DiveSearchState.ERROR_HOLD, 'Verrouille en ERROR_HOLD');
    ASSERT_FALSE(FB.KoboldContactorCmd, 'Contacteur coupe sur defaut');
END_TEST


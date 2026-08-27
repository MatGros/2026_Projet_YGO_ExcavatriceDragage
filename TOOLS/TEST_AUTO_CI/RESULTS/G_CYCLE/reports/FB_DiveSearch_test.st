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
END_TEST

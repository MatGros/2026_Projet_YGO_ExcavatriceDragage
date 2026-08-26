SETUP
VAR
    FB : FB_DiveSearch;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_FALSE(FB.DescendPermit, 'Enable=FALSE -> DescendPermit=FALSE');
    ASSERT_FALSE(FB.KoboldMeasureEnable, 'Enable=FALSE -> KoboldMeasureEnable=FALSE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_FALSE(FB.DescendPermit, 'Coupure -> DescendPermit=FALSE');
END_TEST

TEST 'TC-P04-010 DiveSearch : mise en service recherche de couche'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB.Ready, 'Module DiveSearch pret');
END_TEST

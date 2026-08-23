SETUP
VAR
    harness : FB_TestHarness_PRG_03;
END_VAR
END_SETUP

TEST 'PRG_03_Modes_Cycle : Mode Manuel MAINT_N1 (autorisations unitaires et arbitrage)'
    harness(
        SelMode := E_Mode.MAINT_N1,
        PowerContactorEngaged := TRUE,
        SelJoystickWinch := 1 // M1
    );
    ASSERT_EQ(harness.Auth.Mode, E_Mode.MAINT_N1, 'Mode MAINT_N1 arbitre');
    ASSERT_EQ(harness.Auth.JoystickWinchSelectArbitrated, 1, 'Selection Joystick M1 arbitree');
    ASSERT_FALSE(harness.Auth.InhibitM1, 'Inhibition M1 interdite en N1');
END_TEST

TEST 'PRG_03_Modes_Cycle : Mode Semi-Auto (activation sequenceur et etape initiale)'
    harness(
        SelMode := E_Mode.SEMI_AUTO,
        PowerContactorEngaged := TRUE,
        HomedM1 := TRUE,
        HomedM2 := TRUE
    );
    ASSERT_EQ(harness.Auth.Mode, E_Mode.SEMI_AUTO, 'Mode SEMI_AUTO arbitre');
    ASSERT_EQ(harness.CycleStep, E_CycleStep.X0_PREPARATION, 'Sequenceur pret a l etape X0_PREPARATION');
END_TEST


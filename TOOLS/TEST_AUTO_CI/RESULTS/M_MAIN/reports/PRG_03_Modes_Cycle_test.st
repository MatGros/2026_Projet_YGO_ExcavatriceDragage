SETUP
VAR
    harness : FB_TestHarness_PRG_03;
END_VAR
END_SETUP

TEST 'PRG_03_Modes_Cycle : Mode Manuel MAINT_N1 (arbitrage + autorisations unitaires)'
    harness(
        SelMode := E_Mode.MAINT_N1,
        PowerContactorEngaged := TRUE,
        SelJoystickWinch := 1,        // Selection Joystick M1
        TglMaintenanceZoneAccess := TRUE
    );
    // ---- ST_fbModes_Autorisations : arbitrage mode ----
    ASSERT_EQ(harness.Auth.Mode, E_Mode.MAINT_N1, 'Auth.Mode: MAINT_N1 arbitre');
    // SyncEnable actif par defaut en MAINT_N1 (case IHM cochee par defaut TRUE)
    ASSERT_TRUE(harness.Auth.SyncEnable, 'Auth.SyncEnable vrai en N1 par defaut');
    // Pas d inhibition en MAINT_N1 (N2 only)
    ASSERT_FALSE(harness.Auth.InhibitM1, 'Auth.InhibitM1 faux en N1');
    ASSERT_FALSE(harness.Auth.InhibitM2, 'Auth.InhibitM2 faux en N1');
    // Selection Joystick unitaire autorisee en N1
    ASSERT_EQ(harness.Auth.JoystickWinchSelectArbitrated, 1, 'Auth.JoystickWinchSelectArbitrated = 1 (M1) en N1');
    // HomingApproach : MAINT_N2 only -> faux en N1
    ASSERT_FALSE(harness.Auth.HomingApproachEnable, 'Auth.HomingApproachEnable faux en N1 (N2 only)');
    // Cible Translation Maintenance : N1 OU N2 + bit IHM -> vrai ici
    ASSERT_TRUE(harness.Auth.MaintenanceM3TargetEnable, 'Auth.MaintenanceM3TargetEnable vrai (N1 + bit)');
END_TEST

TEST 'PRG_03_Modes_Cycle : Mode MAINT_N2 (inhibitions exclusives + homing + maintenance)'
    harness(
        SelMode := E_Mode.MAINT_N2,
        PowerContactorEngaged := TRUE,
        SelHomingApproachEnable := TRUE,
        TglMaintenanceZoneAccess := TRUE,
        InhibitM1Request := TRUE,   // front inhibition M1
        SelJoystickWinch := 2        // M2
    );
    // ---- Arbitrage ----
    ASSERT_EQ(harness.Auth.Mode, E_Mode.MAINT_N2, 'Auth.Mode MAINT_N2 arbitre');
    // ---- Inhibitions ----
    ASSERT_TRUE(harness.Auth.InhibitM1, 'Auth.InhibitM1 actif en N2 (demande M1)');
    ASSERT_FALSE(harness.Auth.InhibitM2, 'Auth.InhibitM2 inactif (exclusion mutuelle)');
    // ---- HomingApproach (N2 only) ----
    ASSERT_TRUE(harness.Auth.HomingApproachEnable, 'Auth.HomingApproachEnable vrai en N2');
    // ---- Cible Maintenance ----
    ASSERT_TRUE(harness.Auth.MaintenanceM3TargetEnable, 'Auth.MaintenanceM3TargetEnable vrai en N2 + bit');
    // ---- Selection Joystick unitaire ----
    ASSERT_EQ(harness.Auth.JoystickWinchSelectArbitrated, 2, 'Auth.JoystickWinchSelectArbitrated M2 en N2');
END_TEST

TEST 'PRG_03_Modes_Cycle : Exclusion mutuelle inhibition M1/M2 (jamais les deux actives)'
    harness(
        SelMode := E_Mode.MAINT_N2,
        PowerContactorEngaged := TRUE,
        InhibitM1Request := TRUE,
        InhibitM2Request := TRUE
    );
    // Deux demandes montantes simultanees -> un seul front traite (M1 prioritaire au 1er scan),
    // l autre est rejete. Garantie de securite : JAMAIS les 2 inhibitions actives a la fois.
    ASSERT_TRUE(harness.Auth.InhibitM1 OR harness.Auth.InhibitM2, 'Exactement une inhibition devenue active');
    ASSERT_FALSE(harness.Auth.InhibitM1 AND harness.Auth.InhibitM2, 'Exclusion mutuelle : les 2 inhibitions jamais simultanees');
END_TEST

TEST 'PRG_03_Modes_Cycle : Defaut codeur - SEMI_AUTO selectionne mais cycle non autorise (T207)'
    harness(
        SelMode := E_Mode.SEMI_AUTO,
        PowerContactorEngaged := TRUE,
        EncoderFaultPresent := TRUE,     // defaut codeur agrege
        HomedM1 := TRUE,
        HomedM2 := TRUE
    );
    // T207 : le defaut codeur ne force plus le repli MAINT_N1 ; le mode reste SEMI_AUTO.
    ASSERT_EQ(harness.Auth.Mode, E_Mode.SEMI_AUTO, 'Auth.Mode reste SEMI_AUTO (T207, pas de repli)');
    // Le cycle ne tourne pas : gate codeur FB_Cycle -> sequenceur non Busy.
    ASSERT_FALSE(harness.CycleBusy, 'Cycle non Busy (gate defaut codeur FB_Cycle)');
END_TEST

TEST 'PRG_03_Modes_Cycle : Mode Semi-Auto nominal (sequenceur active, etape initiale)'
    harness(
        SelMode := E_Mode.SEMI_AUTO,
        PowerContactorEngaged := TRUE,
        EncoderFaultPresent := FALSE,
        HomedM1 := TRUE,
        HomedM2 := TRUE,
        DeadmanArmed := TRUE,
        JoystickDeflected := TRUE,
        HeartbeatIhmOk := TRUE
    );
    ASSERT_EQ(harness.Auth.Mode, E_Mode.SEMI_AUTO, 'Auth.Mode SEMI_AUTO arbitre');
    // Sequenceur de cycle prete (etape initiale de preparation)
    ASSERT_EQ(harness.CycleStep, E_CycleStep.X0_PREPARATION, 'Sequenceur a l etape X0_PREPARATION');
    ASSERT_FALSE(harness.CycleBusy, 'Sequenceur non Busy initialement');
    ASSERT_FALSE(harness.CycleError, 'Sequenceur sans erreur');
END_TEST

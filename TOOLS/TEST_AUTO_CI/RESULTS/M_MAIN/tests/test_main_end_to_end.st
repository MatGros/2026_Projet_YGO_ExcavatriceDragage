SETUP
VAR
    mainMachine : FB_Main_EndToEnd;
END_VAR
END_SETUP

TEST 'MAIN_GLOBAL : Chaine Complete - Qualification Neutre vers Montee Treuils Couples'
    // 1. Initialisation boot au neutre (Raw = 5000)
    mainMachine(
        JoyRawX := 5000,
        JoyRawY := 5000,
        JoyDeadmanBtn := FALSE,
        CmdMode := E_Mode.MAINT_N1,
        CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE
    );
    mainMachine(
        JoyRawX := 5000,
        JoyRawY := 5000,
        JoyDeadmanBtn := TRUE, // Début appui homme-mort au neutre
        CmdMode := E_Mode.MAINT_N1,
        CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE
    );
    ADVANCE_TIME(150000000); // 150 ms (> 100 ms DeadmanArmHoldTime)
    mainMachine(
        JoyRawX := 5000,
        JoyRawY := 5000,
        JoyDeadmanBtn := TRUE, // Confirmation maintien homme-mort -> Armé
        CmdMode := E_Mode.MAINT_N1,
        CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE
    );
    
    // 2. Stimulus Opérateur : Poussée Manche vers le Haut (+Y = 8000) avec Homme-mort maintenu
    mainMachine(
        JoyRawX := 5000,
        JoyRawY := 8000, // Déviation Y Montée
        JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.MAINT_N1,
        CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE
    );
    mainMachine(
        JoyRawX := 5000,
        JoyRawY := 8000,
        JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.MAINT_N1,
        CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE,
        PowerContactorEngaged := TRUE
    );







    
    // 3. Vérification des flux à travers toute la machine (PRG_02 -> PRG_07)
    // - Bus PRG_02 : Joystick armé et qualifié
    ASSERT_TRUE(mainMachine.BusAcq.JoystickDeadmanArmed, 'PRG_02: Homme-mort qualifie');
    
    // - Bus PRG_03 : Mode Manuel N1 arbitré
    ASSERT_EQ(mainMachine.BusModes.Mode, E_Mode.MAINT_N1, 'PRG_03: Mode MAINT_N1 arbitre');
    
    // - Bus PRG_04 : Demande de montée et sécurité nominale
    ASSERT_FALSE(mainMachine.BusWinch.WinchM1Safety.SafeStop, 'PRG_04: Aucun SafeStop actif');
    
    // - Bus PRG_07 : Bandeau IHM informé sans défaut
    ASSERT_TRUE(mainMachine.BusBanner.GlobalContextText <> '', 'PRG_07: Bandeau IHM present');
    ASSERT_FALSE(mainMachine.BusBanner.AlarmBanner.HasAlarm, 'PRG_07: Aucune alarme bloqueuse');
END_TEST


TEST 'MAIN_GLOBAL : Coupure Puissance AU Propagee a tous les Actionneurs'
    // Stimulus : Chute de la boucle AU physique
    mainMachine(
        JoyRawX := 0,
        JoyRawY := 1000,
        JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.MAINT_N1,
        EmergencyChainClosed := FALSE, // Chaîne AU ouverte
        PowerContactorEngaged := FALSE
    );
    
    // Vérification : toutes les sorties physiques sont instantanément coupées
    ASSERT_FALSE(mainMachine.BusOutputs.M1RelayFwd, 'Coupure immediate relais M1');
    ASSERT_FALSE(mainMachine.BusOutputs.M1BrakeCmd, 'Frein M1 retombe');
    ASSERT_FALSE(mainMachine.BusOutputs.TranslationBrakeCmd, 'Frein M3 bloque');
END_TEST

TEST 'MAIN_GLOBAL : Relachement homme-mort en contexte cycle -> sequenceur observe + demande actionneur neutralisee (T169-A S3)'
    // 1. Armement homme-mort + passage Semi-Auto : le séquenceur FB_Cycle quitte X0
    mainMachine(
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );
    mainMachine(
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );
    ADVANCE_TIME(150000000); // > 100 ms DeadmanArmHoldTime
    mainMachine(
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );
    mainMachine(
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );

    // 2. Le séquenceur est observé actif (diag e2e) et le mode arbitre est SEMI_AUTO
    ASSERT_TRUE(mainMachine.CycleStep <> E_CycleStep.X0_PREPARATION, 'Sequenceur sorti de X0 en Semi-Auto');
    ASSERT_TRUE(mainMachine.BusModes.Mode = E_Mode.SEMI_AUTO, 'Mode SEMI_AUTO arbitre');

    // 3. Relâchement homme-mort / manche au neutre -> demande actionneur neutralisée
    mainMachine(
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );
    ASSERT_FALSE(mainMachine.BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'Demande M1 coupee au relache homme-mort');
    ASSERT_FALSE(mainMachine.BusWinch.WinchM1FinalInterlockRequest.RequestedContactor1, 'Contactor M1 coupe au relache');
END_TEST

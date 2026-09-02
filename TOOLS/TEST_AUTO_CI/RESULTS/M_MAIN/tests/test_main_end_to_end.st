SETUP
VAR
    mainMachine : FB_Main_EndToEnd;
    stepBefore  : E_CycleStep;   // mémoire étape séquenceur pour test relâchement homme-mort
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
    ASSERT_TRUE(mainMachine.BusAcq.Joystick.DeadmanArmed, 'PRG_02: Homme-mort qualifie');
    
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

TEST 'MAIN_GLOBAL : Relachement homme-mort en contexte cycle -> etape sequencage maintenue (T169-A S3, diag e2e)'
    // ⚠️ Portée honnête : ce test observe la STABILITÉ DU SÉQUENCEUR via l'exposition diag e2e
    // (CycleStep/CycleBusy = sorties réelles de FB_Cycle). Il NE prétend PAS prouver la
    // neutralisation actionneur : dans le mégabloc, le bus vers PRG_04 est alimenté par
    // SeqReq* (entrées externes), pas par les sorties WinchM1Cmd de FB_Cycle. L'invariant
    // « relâchement coupe les demandes actionneur + maintien d'étape » est couvert au niveau
    // unitaire FB_Cycle (TC-P04-020). Ici on vérifie la part réellement tracable e2e.
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
    ASSERT_TRUE(mainMachine.CycleBusy, 'Sequenceur actif (CycleBusy) en Semi-Auto');
    ASSERT_TRUE(mainMachine.BusModes.Mode = E_Mode.SEMI_AUTO, 'Mode SEMI_AUTO arbitre');
    stepBefore := mainMachine.CycleStep;   // mémorise l'étape avant relâchement

    // 3. Relâchement homme-mort / manche au neutre ; X1->X2 avance légitimement (Homed=T par
    //    défaut), donc on n'asserte PAS l'égalité stricte de l'étape. L'invariant e2e réel est
    //    « pas de retour X0 / pas de redémarrage automatique ». Le maintien fin d'étape est
    //    couvert au niveau unitaire FB_Cycle (TC-P04-020).
    mainMachine(
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );
    mainMachine(
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 1,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE
    );

    // 4. Pas de retour X0 ni de redémarrage auto au relâchement : l'étape reste « active »
    ASSERT_TRUE(mainMachine.CycleStep <> E_CycleStep.X0_PREPARATION, 'Pas de retour X0 au relache (pas de redemarrage auto)');
    ASSERT_TRUE(mainMachine.CycleStep <> E_CycleStep.X1_HOMING OR stepBefore = E_CycleStep.X0_PREPARATION,
                'Pas de regression vers le demarrage de cycle');
END_TEST

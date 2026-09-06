(* =======================================================================
   🧪 test_winch_integ.st — Harnais d'intégration treuil (T181-00)
   ───────────────────────────────────────────────────────────────
   Cible : FB_Main_EndToEnd v2 (chaîne PRG_02→03→04[MIROIR §1-§8]→05→06→07
   + modèle physique minimal paire M1/M2). 1 appel machine() = 1 scan ;
   ADVANCE_TIME(10000000) = 10 ms entre les scans quand la temporisation compte.

   📋 TABLE DE RÉFÉRENCE (écrite à la main — oracles, JAMAIS de comparaison
      contre l'ancien calcul, B4) :
      - Seuils paliers (table production AF-10)   : 10 / 30 / 50 / 70 / 90 %
      - Vitesses modèle par palier (fixtures)     : {0, 0.2, 0.5, 0.9, 1.4, 2.0} m/s
      - Limite haute / zone ralentissement        : 7.5 m / 1.0 m → plafond palier 1
      - Limite basse                              : -20.0 m
      - Sync Warn / Critical                      : 0.10 m / 0.50 m
      - Plafond montée / descente effectifs       : 5 / 3 (fallbacks PRG_04)
      - Timeout retombée contacteurs (modèle)     : 500 ms

   🔴 BASELINE (T181-00) : les vecteurs dont la cible n'existe pas encore dans
      CODE/ sont ROUGES et servent de référence figée (contrat AC7) :
      HARN-31, HARN-33 (plancher/précédence dive → T181-12/16),
      HARN-51 (interlock de cadence PRG_06 → T181-01),
      HARN-71/73/75 (redémarrage auto + temps mort directionnel D18 → T175/T181-05),
      HARN-74b (Méca B 3 s → T178), HARN-80/81 (T180 CAS-001/012 → T181-01/T175).

   ⚙️ Pattern dialecte : les structs de config sont des VAR de SETUP mutables,
      affectés en début de TEST puis passés ENTIERS aux appels (pas de
      membre.cfg := x en argument nommé).
   =======================================================================
   NOTE CALIBRATION : chaque appel machine() doit répéter le contexte complet
   (mode, homme-mort et chaîne puissance) ; une convergence qui ne le fait pas
   réinitialise le mouvement. Marqueur de calibration interdit avant reprise
   exhaustive des 32 vecteurs. *)

SETUP
VAR
    machine      : FB_Main_EndToEnd;
    speedTable   : ST_SpeedStepTable;
    modelSpeeds  : ARRAY[0..5] OF REAL;
    seqReqM1     : ST_ProgramWinchRequest;
    seqReqM2     : ST_ProgramWinchRequest;
    seqReqBucket : ST_ProgramBucketRequest;
    i            : INT;
END_VAR
END_SETUP

(* ═══════════════ FAMILLE 1 — Grafcet ↔ Winch (HARN-1x, pont SEMI_AUTO injecté) ═══════════════ *)

TEST 'HARN-10 : Cycle semi-auto descente 50 pourcent -> palier 3 M1 ET M2, RelayRev'
    (* Config référence + reset demandes séquenceur *)
    speedTable.P1R1 := TRUE; speedTable.P2R1 := TRUE; speedTable.P3R1 := TRUE;
    speedTable.P4R1 := TRUE; speedTable.P5R1 := TRUE;
    speedTable.StepThreshold_Pct[1] := 10.0; speedTable.StepThreshold_Pct[2] := 30.0;
    speedTable.StepThreshold_Pct[3] := 50.0; speedTable.StepThreshold_Pct[4] := 70.0;
    speedTable.StepThreshold_Pct[5] := 90.0;
    modelSpeeds[0] := 0.0; modelSpeeds[1] := 0.2; modelSpeeds[2] := 0.5;
    modelSpeeds[3] := 0.9; modelSpeeds[4] := 1.4; modelSpeeds[5] := 2.0;
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        CfgAscentLimitM := 7.5, CfgDescentLimitM1 := -20.0, CfgDescentLimitM2 := -20.0,
        SyncToleranceM := 0.10, SyncCriticalToleranceM := 0.50,
        SlowdownDistanceM := 1.0, SlowdownMaxStep := 1,
        ModelM2SpeedFactor := 1.0,
        InjectRateBypassFbWinch := FALSE,
        ModelBrakeFeedbackFaultM1 := FALSE, ModelBrakeFeedbackFaultM2 := FALSE,
        ModelContactorsReleaseFaultM1 := FALSE, ModelContactorsReleaseFaultM2 := FALSE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        BtnWinchM1Up := FALSE, BtnWinchM1Down := FALSE,
        BtnWinchM2Up := FALSE, BtnWinchM2Down := FALSE,
        BtnWinchBothUp := FALSE, BtnWinchBothDown := FALSE,
        BucketCmdOpen := FALSE, BucketCmdClose := FALSE,
        KoboldImmersed := FALSE, TglEnableKoboldAutoStopDescent := FALSE,
        TglJoystickMaster := FALSE, TglEnableCoupledBucketSequencing := FALSE,
        TglManualBucketLimits := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* Armement homme-mort au neutre avant toute intention de mouvement. *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime
       de la barriere PRG_06 avant toute demande nominale (jamais un forcage). *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-10: precondition homme-mort arme');
    (* Demande séquenceur : descente couplée 50 %, permis descente dive/benne ouvert *)
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := FALSE; seqReqM1.ReqDescend := TRUE; seqReqM1.StepTgt := 3;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := FALSE; seqReqM2.ReqDescend := TRUE; seqReqM2.StepTgt := 3;
    seqReqBucket.DescendPermitDiveBucketOpen := TRUE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* Convergence 10 × 300 ms : le dialecte test ne permet pas ADVANCE_TIME dans FOR. *)
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);

    (* ORACLE (main) : 50 % -> palier 3 sur LES DEUX treuils (pont SEMI_AUTO des deux branches) *)
    ASSERT_EQ(machine.BusModes.Mode, E_Mode.SEMI_AUTO, 'HARN-10: SEMI_AUTO doit etre arbitre');
    ASSERT_EQ(machine.BusWinch.WinchM1Safety.ErrorId, 0, 'HARN-10: ErrorId M1 nominal');
    ASSERT_TRUE(machine.BusWinch.WinchM1FinalInterlockRequest.RequestedStep > 0, 'HARN-10: la demande doit atteindre FB_Winch M1');
    ASSERT_EQ(machine.M1_StepNumber, 3, 'HARN-10: M1 palier 3 attendu pour 50 pourcent');
    ASSERT_EQ(machine.M2_StepNumber, 3, 'HARN-10: M2 palier 3 attendu pour 50 pourcent');
    ASSERT_TRUE(machine.BusOutputs.M1RelayRev, 'HARN-10: RelayRev M1 commande la descente');
    ASSERT_TRUE(machine.BusOutputs.M2RelayRev, 'HARN-10: RelayRev M2 commande la descente');
    ASSERT_TRUE(machine.FinalInterlockGovernedM1 = FALSE, 'HARN-10: filet PRG_06 passif en nominal');
END_TEST

TEST 'HARN-11 : Extraction montee ExtractionControlActive -> plafond palier 1 M1 ET M2'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-11: precondition homme-mort arme');
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := TRUE; seqReqM1.ReqDescend := FALSE; seqReqM1.StepTgt := 5;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := TRUE; seqReqM2.ReqDescend := FALSE; seqReqM2.StepTgt := 5;
    seqReqBucket.ExtractionControlActive := TRUE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);

    (* ORACLE (main) : plafond ascension effectif = 1 sur M1 ET M2 malgré demande 100 % *)
    ASSERT_EQ(machine.M1_StepNumber, 1, 'HARN-11: M1 plafonne palier 1 (ExtractionControlActive)');
    ASSERT_EQ(machine.M2_StepNumber, 1, 'HARN-11: M2 plafonne palier 1 (ExtractionControlActive)');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-11: montee maintenue au palier 1');
END_TEST

TEST 'HARN-12 : Zone ralentissement bordure haute -> plafond palier 1, jamais au-dela de 7.5 m'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 6.8, ModelSeedPosM2 := 6.8, ModelReloadPositions := TRUE,
        CfgAscentLimitM := 7.5, CfgDescentLimitM1 := -20.0, CfgDescentLimitM2 := -20.0,
        SlowdownDistanceM := 1.0, SlowdownMaxStep := 1,
        ModelM2SpeedFactor := 1.0
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-12: precondition homme-mort arme');
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := TRUE; seqReqM1.ReqDescend := FALSE; seqReqM1.StepTgt := 5;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := TRUE; seqReqM2.ReqDescend := FALSE; seqReqM2.StepTgt := 5;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    ADVANCE_TIME(500000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);

    (* PRECOND (durcissement T181-00b) : le treuil doit reellement monter en zone avant qu'on
       puisse tester le plafond. Sans mouvement, StepNumber=0 rend l'oracle triviale/creuse. *)
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-12: precondition - montee en zone haute engagee M1');
    ASSERT_TRUE(machine.M2_StepNumber >= 1, 'HARN-12: precondition - montee en zone haute engagee M2');
    (* ORACLE (main) : en zone (pos >= limite - 1.0 m) le palier est plafonne a SlowdownMaxStep ;
       la butee haute (7.5) n'est jamais depassee une fois atteinte (coupe propre). *)
    ASSERT_TRUE(machine.M1_StepNumber <= 1, 'HARN-12: M1 plafonne au SlowdownMaxStep en zone haute');
    ASSERT_TRUE(machine.M2_StepNumber <= 1, 'HARN-12: M2 plafonne au SlowdownMaxStep en zone haute');
    ASSERT_TRUE(machine.M1_CablePosM_Model <= 7.5, 'HARN-12: position M1 jamais au-dela de la limite haute');
    ASSERT_TRUE(machine.M2_CablePosM_Model <= 7.5, 'HARN-12: position M2 jamais au-dela de la limite haute');
END_TEST

TEST 'HARN-13a : Table de verite etape remontee 20 pourcent -> palier 2'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 17.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        BucketSeedOpen := FALSE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-13a: precondition homme-mort arme');
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := TRUE; seqReqM1.ReqDescend := FALSE; seqReqM1.StepTgt := 3;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := TRUE; seqReqM2.ReqDescend := FALSE; seqReqM2.StepTgt := 3;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket
    );
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_EQ(machine.M1_StepNumber, 2, 'HARN-13a: 20 pourcent -> palier 2 (table reference)');
    ASSERT_EQ(machine.M2_StepNumber, 2, 'HARN-13a: 20 pourcent -> palier 2 M2');
END_TEST

TEST 'HARN-13b : Table de verite etape descente 70 pourcent -> palier 3 (clamp descente effective)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-13b: precondition homme-mort arme');
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := FALSE; seqReqM1.ReqDescend := TRUE; seqReqM1.StepTgt := 3;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := FALSE; seqReqM2.ReqDescend := TRUE; seqReqM2.StepTgt := 3;
    seqReqBucket.DescendPermitDiveBucketOpen := TRUE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket
    );
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* ORACLE (main) : 70 % demandé, clamp descente effectif = 3 (fallback PRG_04) -> palier 3 *)
    ASSERT_EQ(machine.M1_StepNumber, 3, 'HARN-13b: 70 pourcent descendu au clamp descente 3');
    ASSERT_EQ(machine.M2_StepNumber, 3, 'HARN-13b: idem M2');
END_TEST

TEST 'HARN-13c : Table de verite etape remontee 90 pourcent -> palier 5'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 17.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        BucketSeedOpen := FALSE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, CmdMode := E_Mode.SEMI_AUTO,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusAcq.Joystick.DeadmanArmed, 'HARN-13c: precondition homme-mort arme');
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := TRUE; seqReqM1.ReqDescend := FALSE; seqReqM1.StepTgt := 3;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := TRUE; seqReqM2.ReqDescend := FALSE; seqReqM2.StepTgt := 3;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        ModelReloadPositions := FALSE,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket
    );
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 4200, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(300000000); machine(CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket, CmdMode := E_Mode.SEMI_AUTO, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_EQ(machine.M1_StepNumber, 5, 'HARN-13c: 90 pourcent -> palier 5 (table reference)');
    ASSERT_EQ(machine.M2_StepNumber, 5, 'HARN-13c: 90 pourcent -> palier 5 M2');
END_TEST

(* ═══════════════ FAMILLE 2 — Joystick ↔ Winch (HARN-2x, MAINT_N1 joystick maître) ═══════════════ *)

TEST 'HARN-20 : Rampe deflexion 0 a 100 pourcent -> paliers monotones, jamais de saut brutal'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 17.0, ModelReloadPositions := TRUE,
        CfgAscentLimitM := 7.5, SyncToleranceM := 0.10, SyncCriticalToleranceM := 0.50,
        SlowdownDistanceM := 1.0, SlowdownMaxStep := 1,
        ModelM2SpeedFactor := 1.0, InjectRateBypassFbWinch := FALSE,
        ModelBrakeFeedbackFaultM1 := FALSE, ModelBrakeFeedbackFaultM2 := FALSE,
        ModelContactorsReleaseFaultM1 := FALSE, ModelContactorsReleaseFaultM2 := FALSE,
        BucketSeedOpen := FALSE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* Armement homme-mort (hold 50 ms harnais PRG_02) *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* Rampe : 20% -> 40% -> 75% ; 6 cycles (60 ms) par pas *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5800, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(60000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* ORACLE (main) : 20 % -> jamais au-dela du palier 2 à ce pas (pas d'accostage brutal) *)
    ASSERT_TRUE(machine.M1_StepNumber <= 2, 'HARN-20: pas de saut au-dela du palier cible (20%)');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 6600, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(60000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.M1_StepNumber <= 3, 'HARN-20: montee monotone (40%)');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(400000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* ORACLE (main) : 75 % -> palier 4 (entre 70 et 90) *)
    ASSERT_EQ(machine.M1_StepNumber, 4, 'HARN-20: 75 pourcent -> palier 4 (table reference)');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-20: montee commandee');
END_TEST

TEST 'HARN-21 : Rampe retour 100 a 0 -> decroissance propre, neutre -> palier 0'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-21: precondition - en montee avant rampe retour');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5800, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(20000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : neutre -> palier 0 en <= 2 cycles *)
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-21: relache -> palier 0');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-21: plus de commande de montee');
END_TEST

TEST 'HARN-22 : Effleurement maintenu (juste au-dessus du seuil 1) -> palier 1 stable, pas de plancher'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5480, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5480, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5480, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : déflexion mini constante -> palier 1 stable, hors plongée pas de plancher forcé au-delà *)
    ASSERT_EQ(machine.M1_StepNumber, 1, 'HARN-22: effleurement -> palier 1 stable (pas de plancher hors plongee)');
END_TEST

TEST 'HARN-23 : Homme-mort relache en mouvement -> arret immediat, frein retombe'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-23: precondition - montee active');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := FALSE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : perte homme-mort -> tout retombe *)
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-23: homme-mort relache -> palier 0');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-23: RelayFwd retombe');
    ASSERT_TRUE(machine.BusOutputs.M1BrakeCmd = FALSE, 'HARN-23: frein M1 retombe (plus de sens commande)');
END_TEST

(* ═══════════════ FAMILLE 3 — Plongée Kobold (HARN-3x) ═══════════════ *)

TEST 'HARN-30 : Descente couplee benne ouverte + toucher fond Kobold -> immersion confirmee puis arret latche'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N2, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        TglEnableKoboldAutoStopDescent := TRUE, ImmersionLowerM := 1.0, ImmersionUpperM := 3.0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0, BucketSeedOpen := TRUE,
        KoboldImmersed := FALSE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    (* Descente couplée douce (palier 1) — benne ouverte (seed) *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);

    (* Front montant Kobold dans la fenêtre d'immersion *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, KoboldImmersed := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(10000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ASSERT_TRUE(machine.KoboldImmersionConfirmed, 'HARN-30: immersion confirmee au front montant en fenetre');

    (* Front descendant = toucher fond -> latch + arrêt descente *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, KoboldImmersed := FALSE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);

    (* ORACLE (main) : fond latché -> descente coupée sur LES DEUX treuils *)
    ASSERT_TRUE(machine.KoboldBottomTouchLatched, 'HARN-30: fond latche au front descendant');
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-30: descente M1 arretee (permits FALSE)');
    ASSERT_EQ(machine.M2_StepNumber, 0, 'HARN-30: descente M2 arretee');
    ASSERT_TRUE(machine.BusOutputs.M1RelayRev = FALSE, 'HARN-30: plus de RelayRev M1');
END_TEST

TEST 'HARN-31 : Interdiction palier 5 en Kobold (D12) -> plafond 4 (CIBLE T181-12/16, ROUGE baseline)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N2, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        TglEnableKoboldAutoStopDescent := TRUE, ImmersionLowerM := 1.0, ImmersionUpperM := 3.0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0, BucketSeedOpen := TRUE, KoboldImmersed := TRUE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* Descente couplée plongée réelle (benne ouverte seed) à pleine vitesse : la cible D12
       doit être exercée — pas de joystick neutre qui laisse StepNumber=0. *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    (* ORACLE (main) : la plongée s'exerce réellement (StepNumber >= 1) ET en contexte Kobold
       le palier est plafonné à 4 (cible D12). Un StepNumber=0 par joystick neutre = FAIL. *)
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-31: la plongee Kobold est reellement exercee (StepNumber >= 1)');
    ASSERT_TRUE(machine.M1_StepNumber <= 4, 'HARN-31: palier plafonne a 4 en Kobold (cible D12)');
END_TEST

TEST 'HARN-32 : Relache joystick en contexte plongee -> palier 0 immediat, pas de plancher residuel'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N2, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        TglEnableKoboldAutoStopDescent := TRUE, ImmersionLowerM := 1.0, ImmersionUpperM := 3.0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0, BucketSeedOpen := TRUE, KoboldImmersed := TRUE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-32: precondition - descente active en plongee');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(30000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);

    (* ORACLE (main) : relâche -> 0 immédiat ; re-demande -> repart du palier bas (pas de plancher collant) *)
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-32: relache -> palier 0 immediat');
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(10000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, KoboldImmersed := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ASSERT_TRUE(machine.M1_StepNumber <= 1, 'HARN-32: reprise depuis palier bas (pas de plancher residuel)');
END_TEST

TEST 'HARN-33 : Precedence plancher Min vs plafond Max pres bordure basse (amendement B, CIBLE T181-12, ROUGE baseline)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N2, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := -19.2, ModelSeedPosM2 := -19.2, ModelReloadPositions := TRUE,
        SlowdownDistanceM := 1.0, SlowdownMaxStep := 1,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 4200, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N2);
    (* ORACLE (main) : plafond zone basse (1) gagne sur plancher plongee (3) — amendement B *)
    ASSERT_EQ(machine.M1_StepNumber, 1, 'HARN-33: plafond zone basse gagne sur plancher plongee (amendement B)');
END_TEST

(* ═══════════════ FAMILLE 4 — Régression / asymétrie M1↔M2 (HARN-4x) ═══════════════ *)

TEST 'HARN-40 : Jog benne -> M2 bride palier 1, treuils coupes pendant Busy (anti-traversee amont)'
    (* Variante baseline : le jog benne (Busy) coupe les treuils (NOT instBucket.Busy).
       Le clamp M2-only sans conflit Busy est couvert par HARN-42. Oracle baseline écrit à la main. *)
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 17.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0, BucketSeedOpen := FALSE,
        BucketOffsetOpenM := 0.0, BucketOffsetCloseM := 15.0,
        BucketCoherenceLimitM := 1.0, BucketOpenAnticipationM := 0.2, BucketCloseAnticipationM := 0.2,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* M1 demande palier 4 (75 %) *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_EQ(machine.M1_StepNumber, 4, 'HARN-40: precondition - M1 au palier 4');

    (* Jog fermeture benne maintenu -> Busy -> treuils coupes, M2 force lent *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BucketCmdClose := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BucketCmdClose := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : benne busy -> M1 coupe (anti-traversée amont), M2 <= 1 (clamp benne propre) *)
    ASSERT_TRUE(machine.BusWinch.BucketBusy, 'HARN-40: benne en jog (Busy)');
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-40: M1 coupe pendant jog benne (anti-traversee amont)');
    ASSERT_TRUE(machine.M2_StepNumber <= 1, 'HARN-40: M2 bride palier 1 (clamp benne M2-propre)');
END_TEST

TEST 'HARN-41 : SyncDeviationWarn -> plafond palier 1 sur M1 ET M2 (bornes communes identiques)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.3, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* Montée couplée demandée plein pot -> écart 0.3 m > warn 0.10 -> clamp 1 sur les deux *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : SyncDeviationWarn -> plafond 1 sur M1 ET M2 (clamp commun, pas juste M2) *)
    ASSERT_TRUE(machine.BusWinch.SyncState.SyncDeviationWarn, 'HARN-41: SyncDeviationWarn actif (ecart 0.3 > 0.10)');
    ASSERT_EQ(machine.M1_StepNumber, 1, 'HARN-41: M1 plafonne palier 1 par la sync');
    ASSERT_EQ(machine.M2_StepNumber, 1, 'HARN-41: M2 plafonne palier 1 par la sync');
END_TEST

TEST 'HARN-42 : Plafond M2 propre (ManualBucketLimits) bride M2 a 1, M1 libre'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 2, TglJoystickMaster := FALSE,
        TglManualBucketLimits := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 17.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        BucketSeedOpen := FALSE,
        BucketOffsetOpenM := 0.0, BucketOffsetCloseM := 15.0,
        BucketOpenAnticipationM := 0.2, BucketCloseAnticipationM := 0.2,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglManualBucketLimits := TRUE, CmdWinchSelect := 2, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglManualBucketLimits := TRUE, CmdWinchSelect := 2, CmdMode := E_Mode.MAINT_N1);

    (* Boutons : M1 monte plein pot ET M2 monte plein pot, M2-only clamp actif *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BtnWinchM1Up := TRUE, BtnWinchM2Up := TRUE, JoyDeadmanBtn := TRUE, TglManualBucketLimits := TRUE, CmdWinchSelect := 2, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BtnWinchM1Up := TRUE, BtnWinchM2Up := TRUE, TglManualBucketLimits := TRUE, CmdWinchSelect := 2, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : M1 libre (5), M2 plafonné 1 — la portée M2-only est respectée *)
    ASSERT_EQ(machine.M1_StepNumber, 5, 'HARN-42: M1 libre jusqu au plafond general (5)');
    ASSERT_EQ(machine.M2_StepNumber, 1, 'HARN-42: M2 plafonne palier 1 (clamp M2-propre)');
END_TEST

(* ═══════════════ FAMILLE 5 — Autorité des 2 interlocks (HARN-5x) ═══════════════ *)

TEST 'HARN-50 : Nominal filet passif -> FinalInterlockGoverned FALSE sur toute la montee couplee'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0, InjectRateBypassFbWinch := FALSE,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* PRECOND (durcissement T181-00b) : sans montee couplee reellement etablie,
       FinalInterlockGoverned=FALSE est une tautologie (aucune demande n'atteint FB_Winch).
       Le filet passif n'a de sens qu'en regime etabli. *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-50: precondition - montee couplee M1 etablie');
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-50: precondition - pas M1 >= 1 en montee');
    (* ORACLE (main) : à mi-course la barrière est passive *)
    ASSERT_TRUE(machine.FinalInterlockGovernedM1 = FALSE, 'HARN-50: filet passif M1 a mi-course');
    ASSERT_TRUE(machine.FinalInterlockGovernedM2 = FALSE, 'HARN-50: filet passif M2 a mi-course');
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.FinalInterlockGovernedM1 = FALSE, 'HARN-50: filet passif M1 en regime');
    ASSERT_TRUE(machine.FinalInterlockGovernedM2 = FALSE, 'HARN-50: filet passif M2 en regime');
END_TEST

TEST 'HARN-51 : Injection cadence hors instance FB_Winch -> barriere PRG_06 coupe (CIBLE T181-01, ROUGE baseline)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := FALSE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        InjectRateBypassFbWinch := TRUE, InjectRateStep := 5,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* Phase A — etablir une montee NOMINALE reelle (bouton M1Up) et prouver la barriere PERMISSIVE.
       Le faux vert HARN-51 vient de ce qu'on injectait depuis le neutre : le 1er appel prg06 de
       chaque scan relatchait RestartRequired (gate §2-§3) -> FinalInterlockGovernedM1=TRUE par
       temps-mort, PAS par l'interlock de cadence. Il faut d'abord demontrer une barriere permissive. *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, BtnWinchM1Up := TRUE, TglJoystickMaster := FALSE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);
    ADVANCE_TIME(400000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, BtnWinchM1Up := TRUE, TglJoystickMaster := FALSE, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);
    (* PRECOND (durcissement T181-00b) : montee nominale etablie ET barriere permissive. *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-51: precondition - montee nominale M1 etablie');
    ASSERT_TRUE(machine.FinalInterlockGovernedM1 = FALSE, 'HARN-51: precondition - barriere permissive en nominal');

    (* Phase B — injecter une cadence survitesse hors FB_Winch tout en gardant la montee active
       (MotorRequest reste TRUE -> pas de relatch RestartRequired). Seule l'interlock de CADENCE
       (T181-01) peut couper cette cadence. A la baseline elle n'existe pas -> la barriere permissive
       la laisse passer -> FinalInterlockGovernedM1=FALSE -> ROUGE reference figee. *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, BtnWinchM1Up := TRUE, TglJoystickMaster := FALSE, InjectRateBypassFbWinch := TRUE, InjectRateStep := 5, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);
    ADVANCE_TIME(20000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, BtnWinchM1Up := TRUE, TglJoystickMaster := FALSE, InjectRateBypassFbWinch := TRUE, InjectRateStep := 5, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);

    (* ORACLE (main) : la barrière de CADENCE (T181-01) coupe la cadence injectée.
       À la baseline l'interlock de cadence n'existe pas -> elle passe -> ROUGE référence figée. *)
    ASSERT_TRUE(machine.BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'HARN-51: injection cadence presente en amont barriere');
    ASSERT_TRUE(machine.FinalInterlockGovernedM1, 'HARN-51: la cadence injectee est gouvernee par la cadence (T181-01)');
END_TEST

TEST 'HARN-52 : Pas de double-freinage -> barriere PRG_06 passive en marge interne FB_Winch'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 6200, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 6200, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : mouvement nominal -> barrière passive + cohérence frein = OR sens *)
    ASSERT_TRUE(machine.FinalInterlockGovernedM1 = FALSE, 'HARN-52: pas de coupure non voulue');
    ASSERT_TRUE(machine.BusOutputs.M1BrakeCmd = (machine.BusOutputs.M1RelayFwd OR machine.BusOutputs.M1RelayRev),
                'HARN-52: BrakeCmd = RelayFwd OR RelayRev (pas de double-freinage)');
    ASSERT_TRUE(machine.M1_StepNumber >= 1, 'HARN-52: precondition - mouvement etabli');
END_TEST

(* ═══════════════ FAMILLE 6 — Sync paire (HARN-6x) ═══════════════ *)

TEST 'HARN-60 : Deviation croissante -> warn plafond 1 puis critique SafeStop des 2'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 0.5, (* biais M2 : l'ecart croit *)
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) phase warn : écart > 0.10 -> plafond 1 sur les deux *)
    ASSERT_TRUE(machine.SyncDeviationM_Model > 0.10, 'HARN-60: ecart modelise a depasse le seuil warn');
    ASSERT_TRUE(machine.BusWinch.SyncState.SyncDeviationWarn, 'HARN-60: SyncDeviationWarn actif');
    ASSERT_EQ(machine.M1_StepNumber, 1, 'HARN-60: warn -> plafond 1 M1');
    ASSERT_EQ(machine.M2_StepNumber, 1, 'HARN-60: warn -> plafond 1 M2');

    (* Laisser l'écart dépasser 0.50 -> critique -> SafeStop des 2 *)
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* ORACLE (main) phase critique : écart > 0.50 -> coupure des deux (couplage croisé SafeStop) *)
    ASSERT_TRUE(machine.SyncDeviationM_Model > 0.50, 'HARN-60: ecart a depasse le seuil critique');
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.SafeStop, 'HARN-60: critique -> SafeStop M1');
    ASSERT_TRUE(machine.BusWinch.WinchM2Safety.SafeStop, 'HARN-60: critique -> SafeStop M2 (couplage croise)');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-60: montee M1 coupee au critique');
    ASSERT_TRUE(machine.BusOutputs.M2RelayFwd = FALSE, 'HARN-60: montee M2 coupee au critique');
END_TEST

TEST 'HARN-61 : Retour dans la tolerance -> plafond relache, pas de latch intempestif'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.3, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 2.0, (* M2 remonte plus vite : re-alignement *)
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(400000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : M2 (factor 2.0) a rattrapé -> écart < 0.10 -> warn retombe -> plafond relâché *)
    ASSERT_TRUE(machine.SyncDeviationM_Model < 0.10, 'HARN-61: re-alignement dans la tolerance');
    ASSERT_TRUE(machine.BusWinch.SyncState.SyncDeviationWarn = FALSE, 'HARN-61: warn relache (hysteresis, pas de latch)');
    ASSERT_TRUE(machine.M1_StepNumber > 1, 'HARN-61: plafond relache -> palier > 1');
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.SafeStop = FALSE, 'HARN-61: aucun SafeStop residuel');
END_TEST

(* ═══════════════ FAMILLE 7 — Sécurité (HARN-7x) ═══════════════ *)

TEST 'HARN-70 : Chute chaine AU en mouvement couple -> relais FALSE immediat, freins retombent'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-70: precondition - montee couplee active');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(10000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : coupure immédiate des 2 treuils + freins *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-70: RelayFwd M1 FALSE immediat');
    ASSERT_TRUE(machine.BusOutputs.M2RelayFwd = FALSE, 'HARN-70: RelayFwd M2 FALSE immediat');
    ASSERT_TRUE(machine.BusOutputs.M1BrakeCmd = FALSE, 'HARN-70: frein M1 retombe');
    ASSERT_TRUE(machine.BusOutputs.M2BrakeCmd = FALSE, 'HARN-70: frein M2 retombe');
END_TEST

TEST 'HARN-71 : Enable=FALSE sur FB_Winch en marche -> sorties sures ; re-Enable sans relache'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-71: precondition - montee active');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.DISABLE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    ADVANCE_TIME(20000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-71: Enable=FALSE -> sorties sures');
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-71: palier neutralise');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.MAINT_N1, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    (* ORACLE (main) : la reprise exige une NOUVELLE intention — l'adoption immédiate
       au ré-Enable = défaut D18 (rouge baseline attendu, cible T181-05) *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-71: pas de redemarrage auto au re-Enable (cible D18)');
END_TEST

TEST 'HARN-72 : Watchdog frein (retour frein ne suit pas) -> barriere coupe apres timeout'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        ModelBrakeFeedbackFaultM1 := TRUE, (* retour frein M1 ne s ouvre jamais *)
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(5000000000); (* 5 s : tout timeout frein realiste a expire *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : frein incohérent -> la barrière coupe la commande de sens (TC-P10-012) *)
    ASSERT_TRUE(machine.BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'HARN-72: FB_Winch demande toujours le sens (defaut cote barriere)');
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-72: barriere a coupe (watchdog frein)');
    ASSERT_TRUE(machine.FinalInterlockGovernedM1, 'HARN-72: FinalInterlockGoverned TRUE');
END_TEST

TEST 'HARN-73 : Temps mort directionnel apres arret (inversion 200 ms) -> RelayRev retenu (CIBLE T175/T181-05)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(20000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* Inversion 200 ms après l'arrêt *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 2000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 2000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* PRECOND (durcissement T181-00b) : la barriere ne doit etre testee que si la demande de
       descente est REELlement presente en amont (RequestedRelayRev). Sans elle, M1RelayRev=FALSE
       est une tautologie (aucune demande a retenir). *)
    ASSERT_TRUE(machine.BusWinch.WinchM1FinalInterlockRequest.RequestedRelayRev, 'HARN-73: precondition - inversion descente reellement demandee');
    (* ORACLE (main) : délai interlock descente (400 ms) non écoulé -> la barriere retient RelayRev *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayRev = FALSE, 'HARN-73: temps mort directionnel respecte (cible T175)');
END_TEST

TEST 'HARN-74a : Coast-down apres relache lourd -> PAS de faux PowerCutOff pendant la fenetre contacteurs (T178)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-74a: precondition - montee plein pot');

    (* Relâche homme-mort plein déflexion : coast 500 ms (contacteurs pas encore retombés, v > 0) *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := FALSE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(100000000); (* 100 ms au coeur de la fenêtre coast *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : pendant le coast — mouvement résiduel SANS commande : Méca A ne doit PAS armer *)
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.PowerCutOff = FALSE, 'HARN-74a: PAS de faux PowerCutOff pendant le coast (T178)');
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.SafeStop = FALSE, 'HARN-74a: PAS de SafeStop pendant le coast (Meca A)');
END_TEST

TEST 'HARN-74b : Coast-down prolonge -> Meca B arme a 3 s (CIBLE T178, ROUGE baseline)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := FALSE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(4000000000); (* 4 s > 3 s *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    (* ORACLE (main) : Méca B (absence confirmation arrêt) arme à 3 s -> SafeStop *)
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.SafeStop, 'HARN-74b: Meca B arme a 3 s (cible T178)');
END_TEST

TEST 'HARN-75 : Redemarrage a chaud (FirstScanDone) -> temps mort directionnel NON bypassse (D18, ROUGE baseline)'
    (* Scénario D18 : direction ≠ 0 maintenue à travers une ré-init (Enable FALSE->TRUE) ;
       l'interlock directionnel doit s'appliquer au front montant Enable — PAS via FirstScanDone. *)
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-75: precondition - montee active');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.DISABLE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    ADVANCE_TIME(20000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.MAINT_N1, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : après hot-restart avec direction maintenue, un signal D18 REEL
       (DirectionChangePending ou FinalRestartInhibit) doit etre pose. Retire l'echappatoire
       "OR M1RelayFwd=FALSE" qui rendait l'assertion vraie par defaut (faux vert D18). *)
    ASSERT_TRUE(machine.BusWinch.WinchM1State.DirectionChangePending
                OR machine.BusWinch.WinchM1State.FinalRestartInhibit,
                'HARN-75: temps mort applique au hot-restart (D18, cible T181-05)');
END_TEST

(* ═══════════════ FAMILLE 8 — Croisement audit T180 (HARN-8x) ═══════════════ *)

TEST 'HARN-80 : CAS-001 retombee contacteur EN MARCHE (feedback incoherent) -> defaut + neutralisation (CIBLE T180)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 1, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        ModelContactorsReleaseFaultM1 := TRUE, (* contacteurs declares retombes ALORS qu on commande *)
        JoyRawX := 5000, JoyRawY := 8000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 5000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(300000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 1, CmdMode := E_Mode.MAINT_N1);

    (* PRECOND (durcissement T181-00b) : le defaut CAS-001 ne se teste qu en montee REELlement
       commandee (sinon RelayFwd=FALSE est une tautologie : rien ne bouge -> rien a neutraliser). *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-80: precondition - montee M1 commandee');
    (* ORACLE (main) : en marche, retombee contacteur incoherente -> defaut Error DETECTE.
       Retire "OR RelayFwd=FALSE" (vrai par defaut). CAS-001 / T180. *)
    ASSERT_TRUE(machine.BusWinch.WinchM1Safety.Error, 'HARN-80: CAS-001 detecte (defaut Error, cible T180)');
END_TEST

TEST 'HARN-81 : CAS-012 demande benne pendant mouvement treuil -> demande REFUSEE (CIBLE T175 AC3)'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.MAINT_N1, CmdWinchSelect := 0, TglJoystickMaster := TRUE,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        BucketCmdOpen := FALSE, BucketCmdClose := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ASSERT_TRUE(machine.M1_StepNumber > 0, 'HARN-81: precondition - treuils en mouvement');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BucketCmdClose := TRUE, JoyDeadmanBtn := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BucketCmdClose := TRUE, TglJoystickMaster := TRUE, JoyRawY := 8000, CmdWinchSelect := 0, CmdMode := E_Mode.MAINT_N1);

    (* ORACLE (main) : anti-traversée — la demande benne est refusée tant que les treuils agissent *)
    ASSERT_TRUE(machine.BusWinch.BucketBusy = FALSE, 'HARN-81: CAS-012 demande benne refusee (cible T175 AC3)');
END_TEST

TEST 'HARN-82 : CAS-002 AU pendant transition d etape -> coupure propre, pas d etat incoherent au rearmement'
    seqReqM1.RunRequest := FALSE; seqReqM1.ReqAscent := FALSE; seqReqM1.StepTgt := 0;
    seqReqM2.RunRequest := FALSE; seqReqM2.ReqAscent := FALSE; seqReqM2.StepTgt := 0;
    seqReqBucket.ExtractionControlActive := FALSE; seqReqBucket.DescendPermitDiveBucketOpen := FALSE;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE,
        CmdMode := E_Mode.SEMI_AUTO, CmdWinchSelect := 0,
        SpeedTable := speedTable, ModelStepSpeedMps := modelSpeeds,
        SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        ModelSeedPosM1 := 2.0, ModelSeedPosM2 := 2.0, ModelReloadPositions := TRUE,
        ModelM2SpeedFactor := 1.0,
        JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := FALSE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE
    );
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, ModelReloadPositions := FALSE, CmdMode := E_Mode.SEMI_AUTO);
    (* T181-00b : retour neutre sans commande >= 1500 ms pour purger RestartRequired/DeadTime *)
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.SEMI_AUTO, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);
    ADVANCE_TIME(2000000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, CmdMode := E_Mode.SEMI_AUTO, JoyDeadmanBtn := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE);
    seqReqM1.RunRequest := TRUE; seqReqM1.ReqAscent := TRUE; seqReqM1.ReqDescend := FALSE; seqReqM1.StepTgt := 3;
    seqReqM2.RunRequest := TRUE; seqReqM2.ReqAscent := TRUE; seqReqM2.ReqDescend := FALSE; seqReqM2.StepTgt := 3;
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ADVANCE_TIME(200000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd, 'HARN-82: precondition - mouvement semi-auto');

    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, EmergencyChainClosed := FALSE, PowerContactorEngaged := FALSE);
    ADVANCE_TIME(50000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-82: coupure propre a l AU');

    seqReqM1.RunRequest := FALSE; seqReqM2.RunRequest := FALSE;
    machine(CanBusOperational := TRUE, JoyOperational := TRUE, EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE, BtnResetMachine := TRUE,
            SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket);
    ADVANCE_TIME(10000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, BtnResetMachine := FALSE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket);
    ADVANCE_TIME(100000000);
    machine(HeartbeatIhmOk := TRUE, CanBusOperational := TRUE, JoyOperational := TRUE, SeqReqWinchM1 := seqReqM1, SeqReqWinchM2 := seqReqM2, SeqReqBucket := seqReqBucket,
        CmdMode := E_Mode.SEMI_AUTO, JoyRawX := 5000, JoyRawY := 5000, JoyDeadmanBtn := TRUE,
        EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE, HeartbeatIhmOk := TRUE);

    (* ORACLE (main) : après réarmement, aucune reprise sans ordre explicite *)
    ASSERT_TRUE(machine.BusOutputs.M1RelayFwd = FALSE, 'HARN-82: pas de reprise apres rearmement sans ordre');
    ASSERT_TRUE(machine.BusOutputs.M2RelayFwd = FALSE, 'HARN-82: idem M2');
    ASSERT_EQ(machine.M1_StepNumber, 0, 'HARN-82: etat coherent (palier 0)');
END_TEST

(* =======================================================================
   FB_CycleMachineHoming -- GRAFCET de homing machine (T364 Refonte 2026-09-21)
   Séquence : HX0_REPOS -> HX1_BUCKET_PREPARE -> HX1A_COUPLING_INTERLOCK
             -> HX2_CLIMB_COUPLED -> HX3_FLYING_REFERENCE -> HX4_STABILIZATION_CHECK
             -> HX5_RELEASE_CLEARANCE -> HX6_HOMED_SUCCESS (+ HX7_FAILED)
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_REFONTE_SEQUENCE_HOMING.yaml
   Couverture : AC1 (HX1), AC2 (HX1a E1), AC3 (HX2), AC4 (HX3), AC5 (HX4 retry),
                AC6 (HX5/HX6), AC7 (HX7_FAILED unifié), AC8 (non-régression).
   ======================================================================= *)

SETUP
VAR
    Fb      : FB_CycleMachineHoming;
    Cfg     : ST_fbMachineHomingCycle_Cfg;
    StNone  : ST_fbMachineHomingCycle_AxisHomingStatus;
    StHomed : ST_fbMachineHomingCycle_AxisHomingStatus;
    StErr   : ST_fbMachineHomingCycle_AxisHomingStatus;
END_VAR
    Cfg.CfgTopHomingTarget_M := 8.5;
    Cfg.CfgOffsetClose_M     := 0.2;
    Cfg.CfgOffsetOpen_M      := 1.0;
    Cfg.CfgTimeoutClimb      := T#120s;
    Cfg.CfgTimeoutHomeAxes   := T#60s;
    Cfg.CfgTimeoutBucketClose:= T#8s;
    Cfg.CfgStabilizationMinM := 8.50;
    Cfg.CfgStabilizationMaxM := 8.80;
    StHomed.HomedAndReliable := TRUE;
    StErr.HomingError        := TRUE;
END_SETUP


(* ================= AC1 : HX0 etape initiale pure ===================== *)
TEST 'TC-P09-H001 : HX0 n emet aucune sortie (hors maintenance, pas d auto-armement)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       TopPositionSensor := TRUE, WinchesMechanicallyStopped := FALSE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := FALSE, Cfg := Cfg);
    ADVANCE_TIME(500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'reste en HX0 hors maintenance');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'HX0 : aucun ordre treuil M1');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'HX0 : aucun ordre treuil M2');
    ASSERT_FALSE(Fb.CmdBucketOpen, 'HX0 : aucun ordre benne ouverture');
    ASSERT_FALSE(Fb.CmdBucketClose, 'HX0 : aucun ordre benne fermeture');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'HX0 : aucun HomeReq M1');
    ASSERT_FALSE(Fb.M2Demand.HomeReq, 'HX0 : aucun HomeReq M2');
    ASSERT_FALSE(Fb.M3Locked, 'HX0 : translation M3 non verrouillee');
    ASSERT_EQ(Fb.CmdWinchSelect, -1, 'HX0 : CmdWinchSelect au neutre (-1)');
END_TEST


(* ================= AC1 : auto-armement HX0 -> HX1 =================== *)
TEST 'TC-P09-H002 : auto-armement HX0 -> HX1 en maintenance non-homed'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'SEMI_AUTO : reste HX0');
    // Passage en MAINT_N2 non-homed : debounce 300ms puis auto-armement
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'MAINT_N2 non-homed : auto -> HX1');
    ASSERT_TRUE(Fb.M3Locked, 'HX1 : M3 verrouillee');
    ASSERT_TRUE(Fb.MachineHomingActive, 'HX1 : cycle actif');
    ASSERT_EQ(Fb.CmdWinchSelect, 2, 'HX1 : force WinchSel=2 pour benne');
END_TEST


(* ================= AC1 : HX1 fermeture benne sous permis et garde 8s = *)
TEST 'TC-P09-H003 : HX1 fermeture benne sous permis et timeout 8s'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'auto -> HX1');
    // Homme-mort + manche tire -> fermeture benne commandee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdBucketClose, 'HX1 : fermeture benne active sous permis');
    ASSERT_FALSE(Fb.CmdBucketOpen, 'HX1 : ouverture benne inactive');
    // Ecoulement du timeout 8s sans confirmation
    ADVANCE_TIME(8500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'HX1 timeout 8s -> HX7_FAILED');
    ASSERT_TRUE(Fb.Fault.Latched, 'Defaut latche sur timeout fermeture benne');
END_TEST


(* ================= AC1 / AC2 : Confirmation benne -> HX1A_COUPLING_INTERLOCK = *)
TEST 'TC-P09-H004 : Confirmation benne -> HX1a et attente interlock couplage'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'auto -> HX1');
    // Appui BP confirmation fermeture benne (joystick au neutre)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK, 'BP confirmation -> HX1a');
    ASSERT_EQ(Fb.CmdWinchSelect, 0, 'HX1a : commande selecteur couple (0)');
    // Tant que le selecteur arbitre en aval n'est pas a 0, le cycle reste bloque en HX1a
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 2,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 2, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK, 'Selecteur <> 0 bloque HX1a');
END_TEST


(* ================= AC2 / AC3 : Interlock E1 couplage M1/M2 vers HX2 = *)
TEST 'TC-P09-H005 : Interlock E1 valide dwell 300ms -> HX2, et securite couplage en HX2'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK, '-> HX1a');
    // Selecteur arbitre a 0 : dwell 300ms
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_COUPLED, 'Dwell couplage ecoule -> HX2');
    // Si pendant HX2 le selecteur arbitre quitte 0 -> defaut immediat HX7_FAILED (securite E1)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 1, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'Violation couplage en HX2 -> HX7_FAILED');
    ASSERT_TRUE(Fb.Fault.Latched, 'Defaut couplage latche');
END_TEST


(* ================= AC3 : HX2 montee couplee M1+M2 palier 1 MAX ====== *)
TEST 'TC-P09-H006 : HX2 montee couplee palier 1 sous permis'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_COUPLED, '-> HX2');
    // Commande sous homme-mort + manche tire
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'HX2 : ordre treuil M1 actif');
    ASSERT_TRUE(Fb.CmdWinchM2.RunRequest, 'HX2 : ordre treuil M2 actif');
    ASSERT_EQ(Fb.CmdWinchM1.StepTgt, 1, 'HX2 : palier 1 M1');
    ASSERT_EQ(Fb.CmdWinchM2.StepTgt, 1, 'HX2 : palier 1 M2');
    ASSERT_TRUE(Fb.CmdWinchM1.ReqAscent, 'HX2 : sens montee M1');
    ASSERT_TRUE(Fb.CmdWinchM2.ReqAscent, 'HX2 : sens montee M2');
    ASSERT_FALSE(Fb.CmdWinchM1.ReqDescend, 'HX2 : jamais de descente');
    ASSERT_FALSE(Fb.CmdWinchM2.ReqDescend, 'HX2 : jamais de descente');
    // Relachement homme-mort -> arret immediat, etape conservee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickDeflected := FALSE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'Relachement : arret M1');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'Relachement : arret M2');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_COUPLED, 'Etape conservee a l arret');
END_TEST


(* ================= AC4 : HX3 prise de reference a la volee ========= *)
TEST 'TC-P09-H007 : Franchissement capteur haut -> HX3 HomeReq a la volee'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_COUPLED, '-> HX2');
    // Capteur haut franchi -> transition HX3 et emission immediate HomeReq
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_FLYING_REFERENCE, 'Capteur haut -> HX3');
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'HX3 : HomeReq M1 emis');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'HX3 : HomeReq M2 emis');
    // Statuts codeurs passent a Homed -> passage automatique en HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, 'Axes homes -> HX4');
END_TEST


(* ================= AC5 : HX4 controle stabilisation conforme ======= *)
TEST 'TC-P09-H008 : HX4 controle arret et inertie [8.50..8.80m] conforme -> HX5'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    // Etape HX1a -> HX2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_COUPLED, '-> HX2');
    // Franchissement capteur -> HX3
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_FLYING_REFERENCE, '-> HX3');
    // Reponse codeurs Homed -> HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, '-> HX4');
    // Treuils non encore arretes mecaniquement : reste en HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       CablePosM1 := 8.65, CablePosM2 := 8.65, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, 'Treuils en mvt -> reste HX4');
    // Arret confirme + joystick neutre + positions dans [8.50..8.80m] -> HX5
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.65, CablePosM2 := 8.66, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX5_RELEASE_CLEARANCE, 'Stabilisation ok -> HX5');
END_TEST


(* ================= AC5 : HX4 retry max 3 fois puis HX7_FAILED ======= *)
TEST 'TC-P09-H009 : HX4 inertie hors plage -> retry vers HX1 puis echec HX7'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    // HX1a -> HX2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // HX2 -> HX3
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // HX3 -> HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, '-> HX4');
    // Echec 1 : position hors tolerance (> 8.80m) -> retour HX1 (retry 1)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.95, CablePosM2 := 8.95, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Echec 1 -> retry 1 vers HX1');
    // Re-validation benne -> HX1a -> dwell -> HX2 -> capteur -> HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, '-> HX4');
    // Echec 2 -> retry 2 vers HX1
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.95, CablePosM2 := 8.95, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Echec 2 -> retry 2 vers HX1');
    // Re-validation benne -> HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, '-> HX4');
    // Echec 3 : 3 tentatives max atteintes -> echec definitif HX7_FAILED
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.95, CablePosM2 := 8.95, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, '3eme echec (max 3 tentatives) -> HX7_FAILED');
    // Scan suivant en HX7_FAILED : defaut latche par instFault
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.95, CablePosM2 := 8.95, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.Fault.Latched, 'Defaut stabilisation latche');
END_TEST


(* ================= AC6 : HX5 -> HX6 qualification MachineHomed ===== *)
TEST 'TC-P09-H010 : HX5 neutre -> HX6 MachineHomed et commit benne atomique'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnConfirmHomingBucket := FALSE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    // HX1a -> HX2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickWinchSelectArbitrated := 0, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // HX2 -> HX3
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // HX3 -> HX4
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := FALSE,
       TopPositionSensor := TRUE, JoystickWinchSelectArbitrated := 0,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_STABILIZATION_CHECK, '-> HX4');
    // HX4 -> HX5 (arret + neutre + positions conformes)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       CablePosM1 := 8.65, CablePosM2 := 8.65, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX5_RELEASE_CLEARANCE, '-> HX5');
    // En HX5 avec neutre confirme -> transition vers HX6
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickDeflected := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX6_HOMED_SUCCESS, '-> HX6');
    // Scan d execution en HX6 : publication atomique et qualification MachineHomed
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickDeflected := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomed, 'HX6 : MachineHomed TRUE');
    ASSERT_TRUE(Fb.BucketCommit.CommitClose, 'HX6 : CommitClose atomique publie');
    // Scan suivant -> retour automatique en HX0_REPOS, M3Locked relache
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       JoystickDeflected := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Scan suivant : retour HX0');
    ASSERT_TRUE(Fb.MachineHomed, 'Machine reste Homed en HX0');
    ASSERT_FALSE(Fb.M3Locked, 'M3Locked relache en HX0');
END_TEST


(* ================= AC8 : NOT Enable -> sorties sures =============== *)
TEST 'TC-P09-H011 : NOT Enable -> sorties sures + MachineHomed FALSE + HX0'
    Fb(Enable := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomed, 'NOT Enable : MachineHomed FALSE');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'NOT Enable : treuil M1 sur');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'NOT Enable : treuil M2 sur');
    ASSERT_FALSE(Fb.M3Locked, 'NOT Enable : verrou M3 relache');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'NOT Enable : HX0');
END_TEST


(* ================= AC8 : perte de datum en mouvement ============== *)
TEST 'TC-P09-H012 : perte de datum EN MOUVEMENT -> SafeStop latche jusqu a arret + Reset'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomed, 'datum initial valide');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := FALSE,
       M1Status := StNone, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomingLossSafeStop, 'SafeStop demande sur perte en mouvement');
    ASSERT_FALSE(Fb.MachineHomed, 'MachineHomed retombe');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingLossSafeStop, 'SafeStop retombe a l arret');
    ASSERT_FALSE(Fb.MachineHomed, 'pas de redemarrage auto : MachineHomed reste FALSE');
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomed, 'Reset conscient : datum de nouveau valide');
END_TEST


(* ================= AC7 : Defaut axe -> HX7_FAILED et sortie sur Reset = *)
TEST 'TC-P09-H013 : HomingError axe -> HX7_FAILED et sortie uniquement sur Reset en MAINT_N2'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2,
       DeadmanArmed := FALSE, JoystickPull := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BtnConfirmHomingBucket := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0, JoystickWinchSelectArbitrated := 0,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    // Etape HX0 -> HX1 effectuee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, '-> HX1');
    // Injection defaut axe pendant le cycle
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StErr, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'HomingError -> HX7_FAILED');
    ASSERT_TRUE(Fb.Fault.Latched, 'Defaut latche');
    // Pas de sortie automatique
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'Reste en HX7 sans Reset');
    // Reset en MAINT_N2 -> retour HX0
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Reset en MAINT_N2 -> HX0_REPOS');
    ASSERT_FALSE(Fb.Fault.Latched, 'Defaut acquitte');
END_TEST

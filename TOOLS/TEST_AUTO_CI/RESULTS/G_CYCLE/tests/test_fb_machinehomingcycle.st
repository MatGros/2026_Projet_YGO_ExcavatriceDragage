(* =======================================================================
   FB_MachineHomingCycle -- GRAFCET de homing machine (HX0..HX6 + HXF)
   Spec : DOC/WFLOW/CONTRACTS/GEL_GRAFCET_HOMING_CYCLE_20260903.md (partie 1)
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T233_IMPL_GRAFCET_HOMING_MACHINE.yaml
   Couverture : AC1, AC2, AC4, AC6, AC10, AC11, AC12 (AC13 = linkage/gates).
   Note : le parser de test n'accepte pas ADVANCE_TIME dans un FOR -> motif
          3 appuis deroule a plat (helper VAR-less).
   ======================================================================= *)

SETUP
VAR
    Fb      : FB_MachineHomingCycle;
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
    StHomed.HomedAndReliable := TRUE;
    StErr.HomingError        := TRUE;
END_SETUP


(* ================= AC1 : HX0 etape initiale pure ===================== *)
TEST 'TC-P09-H001 : HX0 n emet aucune sortie quel que soit l etat des entrees'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2,
       TopPositionSensor := TRUE, WinchesMechanicallyStopped := FALSE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'reste en HX0');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'HX0 : aucun ordre treuil M1');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'HX0 : aucun ordre treuil M2');
    ASSERT_FALSE(Fb.CmdBucketOpen, 'HX0 : aucun ordre benne ouverture');
    ASSERT_FALSE(Fb.CmdBucketClose, 'HX0 : aucun ordre benne fermeture');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'HX0 : aucun HomeReq');
    ASSERT_FALSE(Fb.M3Locked, 'AC11 : HX0 -> translation M3 non verrouillee');
END_TEST


(* ================= AC2 : HT0 par motif 3 appuis en N2 =============== *)
TEST 'TC-P09-H010 : HT0 franchi apres 3 appuis valides, en MAINT_N2'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    // appui 1
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // appui 2
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    // appui 3
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'HT0 franchi -> HX1');
    ASSERT_FALSE(Fb.M3Locked, 'AC11 : HX1 (choix, aucun mvt) -> M3 pas encore verrouillee');
END_TEST

TEST 'TC-P09-H012 : HT0 franchi sur front commande IHM StartRequest, en MAINT_N2'
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       StartRequest := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'repos HX0');
    // front montant StartRequest
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'front StartRequest -> HX1');
    // refuse hors MAINT_N2
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.MAINT_N1, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       StartRequest := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'StartRequest hors N2 : reste HX0');
END_TEST

TEST 'TC-P09-H011 : HT0 refuse hors MAINT_N2 (meme motif)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N1, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'hors N2 : reste en HX0');
END_TEST


(* ================= AC10 : NOT Enable -> sorties sures =============== *)
TEST 'TC-P09-H080 : NOT Enable -> sorties sures + MachineHomed FALSE + HX0'
    Fb(Enable := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomed, 'NOT Enable : MachineHomed FALSE');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'NOT Enable : treuil M1 sur');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'NOT Enable : treuil M2 sur');
    ASSERT_FALSE(Fb.M3Locked, 'NOT Enable : verrou M3 relache');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'NOT Enable : HX0');
END_TEST


(* ================= AC10 : perte de datum en mouvement ============== *)
TEST 'TC-P09-H082 : perte de datum EN MOUVEMENT -> SafeStop latche jusqu a arret + Reset'
    // NB : le harness conserve la valeur des entrees omises -> Reset explicite a CHAQUE call.
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
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


(* ================= AC12 : guide operateur ========================== *)
TEST 'TC-P09-H090 : guide hors cycle = BOTH_NOT_HOMED, et FAILED sur Fault.Latched'
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.BOTH_NOT_HOMED, 'BOTH_NOT_HOMED hors cycle');
    // amener en cycle (motif 3 appuis) puis HomingError -> Fault.Latched
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'en HX1');
    // HT1b : pas sur capteur + 3 appuis -> HX2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       DeadmanArmed := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB, 'HT1b -> HX2');
    ASSERT_TRUE(Fb.M3Locked, 'AC11 : M3 verrouillee des HX2 (cycle engage)');
    // AC4 : montee sous permis
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'AC4 : montee M1 sous permis');
    ASSERT_TRUE(Fb.CmdWinchM1.ReqAscent, 'AC4 : sens montee M1');
    ASSERT_EQ(Fb.CmdWinchM1.StepTgt, 1, 'AC4 : palier 1');
    // relachement -> coupure, etape conservee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'AC4 : coupure au relachement permis');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB, 'AC4 : etape conservee');
    // HomingError -> HXF (AC6/AC10) puis guide FAILED (Fault.Latched)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, M1Status := StErr, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HXF_FAILED, 'AC6 : HomingError -> HXF');
    ASSERT_TRUE(Fb.Fault.Latched, 'defaut latche');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.FAILED, 'AC12 : guide FAILED sur Fault.Latched');
    // sortie HXF uniquement sur front Reset (AC10)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HXF_FAILED, 'AC10 : pas de sortie auto');
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.MAINT_N2, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'AC10 : Reset -> HX0');
END_TEST

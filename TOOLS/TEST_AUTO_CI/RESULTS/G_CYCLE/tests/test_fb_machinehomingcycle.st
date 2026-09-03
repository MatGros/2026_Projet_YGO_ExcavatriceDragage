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
(* Auto-armement HX0->HX1 des qu'on est en maintenance (N1/N2) non-homed : pour
   tester l'inertie de HX0 on reste hors maintenance (SEMI_AUTO). *)
TEST 'TC-P09-H001 : HX0 n emet aucune sortie (hors maintenance, pas d auto-armement)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       TopPositionSensor := TRUE, WinchesMechanicallyStopped := FALSE,
       DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := FALSE, Cfg := Cfg);
    ADVANCE_TIME(500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'reste en HX0 hors maintenance');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'HX0 : aucun ordre treuil M1');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'HX0 : aucun ordre treuil M2');
    ASSERT_FALSE(Fb.CmdBucketOpen, 'HX0 : aucun ordre benne ouverture');
    ASSERT_FALSE(Fb.CmdBucketClose, 'HX0 : aucun ordre benne fermeture');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'HX0 : aucun HomeReq');
    ASSERT_FALSE(Fb.M3Locked, 'AC11 : HX0 -> translation M3 non verrouillee');
END_TEST


(* ================= AC2 : auto-armement + entree cycle ============== *)
TEST 'TC-P09-H002 : auto-armement HX0 -> HX1 en maintenance (N1) non-homed'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'SEMI_AUTO : reste HX0');
    // passage en MAINT_N1 non-homed : debounce puis auto-armement
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'MAINT_N1 non-homed : auto -> HX1');
    ASSERT_FALSE(Fb.M3Locked, 'HX1 : M3 pas encore verrouillee (aucun mvt)');
    ASSERT_FALSE(Fb.MachineHomingActive, 'HX1 : cycle pas encore actif');
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.OFFSET_UNKNOWN, 'HX1 en N1 : consigne passer N2');
END_TEST

TEST 'TC-P09-H010 : validation 3 appuis HX1 -> HX2 en MAINT_N2 (pas sur capteur)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'auto -> HX1');
    // 3 appuis courts (joystick centre, treuils arretes)
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB, '3 appuis -> HX2');
    ASSERT_TRUE(Fb.M3Locked, 'AC11 : M3 verrouillee des HX2 (cycle engage)');
END_TEST

TEST 'TC-P09-H012 : entree cycle sur front commande IHM StartRequest, en MAINT_N2'
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       StartRequest := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'SEMI_AUTO : StartRequest ignore');
    // front StartRequest en MAINT_N2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       StartRequest := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'front StartRequest -> HX1');
END_TEST

TEST 'TC-P09-H011 : hors maintenance, ni auto ni motif ni StartRequest n arment'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(500000000);
    Fb(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, StartRequest := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Mode := E_Mode.SEMI_AUTO, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, StartRequest := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'hors maintenance : reste HX0');
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
TEST 'TC-P09-H090 : guide BOTH_NOT_HOMED, entree cycle, AC4, HomingError -> FAILED'
    // Hors maintenance : le guide reste sur l echelle de priorite.
    Fb(Enable := TRUE, Reset := TRUE,  Mode := E_Mode.SEMI_AUTO, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingStep, E_MachineHomingStep.BOTH_NOT_HOMED, 'BOTH_NOT_HOMED hors cycle');
    // MAINT_N2 non-homed : auto-armement HX1 (debounce)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'auto -> HX1');
    // 3 appuis courts (pas sur capteur) -> HX2
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB, '3 appuis -> HX2');
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

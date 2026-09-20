(* =======================================================================
   FB_CycleMachineHoming -- GRAFCET de homing machine (HX0..HX6 + HX7 + HXF)
   Spec : DOC/WFLOW/CONTRACTS/GEL_GRAFCET_HOMING_CYCLE_20260903.md (partie 1)
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T233_IMPL_GRAFCET_HOMING_MACHINE.yaml
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T340_HOMING_LOCKED_ASCENT.yaml
             (serie TC-P09-H2xx : etape verrouillee HX7 = AC1 a AC6)
   Couverture : AC1, AC2, AC4, AC6, AC10, AC11, AC12 (AC13 = linkage/gates).
   Note : le parser de test n'accepte pas ADVANCE_TIME dans un FOR -> motif
          3 appuis deroule a plat (helper VAR-less).
   Note : les entrees omises CONSERVENT leur valeur d'un appel a l'autre ->
          Reset est toujours ramene a FALSE apres la purge initiale.
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


(* =======================================================================
   T340 -- ETAPE VERROUILLEE HX7 : montee au capteur haut puis referencement
   A L'ARRET. Sequence d'entree commune :
     1. auto-armement HX0 -> HX1 (400 ms de debounce)
     2. confirmation benne fermee (front) memorisee
     3. validation explicite 3 appuis (BootReady + MAINT_N2) -> HX7
   ======================================================================= *)

(* ================= AC2/T340 : entree par la confirmation benne ===== *)
TEST 'TC-P09-H200 : confirmation benne fermee -> etape VERROUILLEE HX7 (pas HX2)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_CHOICE, 'auto-armement -> HX1');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'T340 : confirmation benne -> etape verrouillee HX7');
    ASSERT_NEQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB,
               'T340 : le chemin HX2 non verrouille n est pas emprunte');
    ASSERT_TRUE(Fb.M3Locked, 'T340 : cycle engage -> translation M3 verrouillee');
END_TEST

TEST 'TC-P09-H201 : HX7 montee -- AUCUNE HomeReq et Homed reste FALSE (AC1)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Montee commandee, capteur haut NON atteint
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, BucketOffsetValid := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC1 : aucune HomeReq M1 pendant la montee');
    ASSERT_FALSE(Fb.M2Demand.HomeReq, 'AC1 : aucune HomeReq M2 pendant la montee');
    ASSERT_FALSE(Fb.MachineHomed, 'AC1 : Homed reste FALSE tant que le capteur n est pas atteint');
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'HX7 : montee M1 commandee sous permis');
    ASSERT_TRUE(Fb.CmdWinchM2.RunRequest, 'HX7 : montee M2 commandee sous permis');
END_TEST

TEST 'TC-P09-H202 : HX7 montee -- ordre IDENTIQUE M1/M2 au palier 1 (AC4)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.CmdWinchM1.StepTgt, 1, 'AC4 : palier 1 M1');
    ASSERT_EQ(Fb.CmdWinchM2.StepTgt, 1, 'AC4 : palier 1 M2');
    ASSERT_TRUE(Fb.CmdWinchM1.ReqAscent, 'AC4 : sens montee M1');
    ASSERT_TRUE(Fb.CmdWinchM2.ReqAscent, 'AC4 : sens montee M2');
    ASSERT_FALSE(Fb.CmdWinchM1.ReqDescend, 'T340 : jamais de descente en HX7');
    ASSERT_FALSE(Fb.CmdWinchM2.ReqDescend, 'T340 : jamais de descente en HX7');
    // Relachement du permis : coupure, etape CONSERVEE (verrou)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'AC4 : coupure au relachement du permis');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'AC4 : coupure au relachement du permis');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'AC2 : etape verrouillee conservee');
END_TEST

TEST 'TC-P09-H203 : HX7 -- capture UNIQUEMENT a l arret confirme, capteur actif (AC6)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Capteur atteint mais treuils ENCORE en mouvement : aucune capture
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC6 : pas de capture tant que les treuils ne sont pas arretes');
    ASSERT_FALSE(Fb.M2Demand.HomeReq, 'AC6 : pas de capture tant que les treuils ne sont pas arretes');
    // Arret confirme mais commande NON relachee (joystick toujours pousse) : aucune capture
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC6 : pas de capture sans retour au neutre');
    // Arret confirme + neutre : capture demandee sur les DEUX axes
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'AC6 : capture M1 a l arret, capteur haut atteint');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'AC6 : capture M2 a l arret, capteur haut atteint');
    ASSERT_FALSE(Fb.MachineHomed, 'AC1 : Homed pose par la facade codeur, pas par le cycle');
END_TEST

TEST 'TC-P09-H204 : HX7 -- reference atteinte -> HX6 puis HX0 (AC6)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, BucketOffsetValid := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, BucketOffsetValid := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Capteur atteint, arret confirme, neutre : capture
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'capture demandee');
    // Les deux codeurs repondent : reference atteinte -> HX6
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, BootReady := TRUE, BucketOffsetValid := TRUE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX6_HOMED, 'AC6 : reference -> HX6');
    // Scan suivant : retour a l'etape initiale, machine qualifiee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, BootReady := TRUE, BucketOffsetValid := TRUE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'AC6 : retour HX0');
    ASSERT_TRUE(Fb.MachineHomed, 'AC6 : machine referencee (axes + datum benne)');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC6 : impulsion unique, pas de HomeReq permanent');
END_TEST

TEST 'TC-P09-H205 : HX7 -- descente demandee -> abandon, AUCUNE reference (AC2)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Effleurement du manche sans homme-mort : aucune descente n'est commandee -> pas de sanction
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPush := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'AC2 : poussee sans homme-mort = aucune descente commandee, cycle non sanctionne');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'AC2 : pas d abandon sur poussee inoperante');
    // L'operateur commande REELLEMENT une descente (homme-mort + manche pousse)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPush := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HXF_FAILED, 'AC2 : descente -> abandon');
    ASSERT_TRUE(Fb.MachineHomingFailed, 'AC2 : sequence abandonnee');
    ASSERT_FALSE(Fb.CmdWinchM1.ReqDescend, 'AC2 : aucune descente commandee par le cycle');
    ASSERT_FALSE(Fb.CmdWinchM2.ReqDescend, 'AC2 : aucune descente commandee par le cycle');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC2 : aucune reference sur abandon');
    ASSERT_FALSE(Fb.MachineHomed, 'AC2 : machine toujours NON referencee (aucune triche)');
END_TEST

TEST 'TC-P09-H206 : HX7 -- sortie de MAINT_N2 -> etape CONSERVEE, aucun mouvement (AC2)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // L'operateur quitte MAINT_N2 alors que la montee est commandee
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'AC2 : le changement de mode ne fait PAS sortir de l etape verrouillee');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'AC2 : etape tenue, aucun abandon');
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'AC2 : aucun mouvement hors MAINT_N2');
    ASSERT_FALSE(Fb.CmdWinchM2.RunRequest, 'AC2 : aucun mouvement hors MAINT_N2');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC2 : aucune reference hors MAINT_N2');
    // Sejour PROLONGE hors MAINT_N2 avec permis maintenus : aucun ordre de montee n'est emis
    // pendant ce sejour, donc la garde ne doit PAS se consommer (sinon le retour en N2
    // sanctionnerait une montee qui n'a jamais eu lieu).
    ADVANCE_TIME(700000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingFailed, 'AC5 : aucun abandon apres 700 s hors MAINT_N2 (aucun ordre emis)');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'AC2 : etape toujours tenue');
    // Retour en MAINT_N2 : la montee reprend
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'AC2 : reprise de la montee au retour en MAINT_N2');
END_TEST

TEST 'TC-P09-H207 : HX7 -- perte des permis et arret -> etape CONSERVEE (AC3)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Montee commandee puis arret (perte des permis : equivalent testable d'une coupure AU,
    // la chaine AU n'etant pas une entree du cycle)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'montee en cours');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.CmdWinchM1.RunRequest, 'arret : plus aucun ordre');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'AC3 : etape conservee apres l arret (pas de perte d information)');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'AC3 : aucun abandon silencieux');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC3 : aucune reference posee par l arret');
    ASSERT_FALSE(Fb.MachineHomed, 'AC3 : machine toujours NON referencee');
    // Reprise : la montee repart sous permis
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'AC3 : reprise propre de la montee');
END_TEST

TEST 'TC-P09-H208 : garde de montee NON consommee sans commande de montee (A1/AC5)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Cfg.CfgTimeoutClimb := T#120s;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // HX7 en phase de montee, mais AUCUNE commande de montee (homme-mort relache) :
    // l'attente consomme 3 fois la garde configuree.
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(360000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingFailed, 'A1 : une attente sans commande ne sanctionne PAS le cycle');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
              'A1 : etape toujours active apres 3 fois la garde sans commande');
    ASSERT_FALSE(Fb.Fault.Latched, 'A1 : aucun defaut latche');
END_TEST

TEST 'TC-P09-H209 : garde de montee consommee quand la montee EST commandee (A1/AC5)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Cfg.CfgTimeoutClimb := T#120s;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BucketCloseConfirmed := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE, 'HX7 engage');
    // Montee commandee en continu : le capteur n'arrive jamais -> la garde doit sanctionner
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.CmdWinchM1.RunRequest, 'montee commandee');
    ADVANCE_TIME(121000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := FALSE,
       WinchesMechanicallyStopped := FALSE, DeadmanArmed := TRUE, JoystickPull := TRUE,
       JoystickDeflected := TRUE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HXF_FAILED,
              'AC5 : montee commandee sans capteur -> garde ecoulee -> abandon');
    ASSERT_TRUE(Fb.MachineHomingFailed, 'AC5 : sequence abandonnee sur garde de montee');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC5 : aucune reference sur echec de montee');
END_TEST

TEST 'TC-P09-H212 : capteur haut DEJA actif a l entree -> aucune capture sans franchissement (AC1)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BucketCloseConfirmed := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(400000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BucketCloseConfirmed := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_NEQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_LOCKED_REFERENCE,
               'AC1 : capteur deja actif -> PAS d etape verrouillee (franchissement non prouve)');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2N_NEUTRAL, 'AC1 : chemin herite');
    // Arret confirme + neutre + capteur actif : aucune capture immediate (pas de franchissement prouve)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, TopPositionSensor := TRUE,
       WinchesMechanicallyStopped := TRUE, DeadmanArmed := FALSE, JoystickPull := FALSE,
       JoystickDeflected := FALSE, BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'AC1 : aucune capture sans preuve de franchissement');
    ASSERT_FALSE(Fb.M2Demand.HomeReq, 'AC1 : aucune capture sans preuve de franchissement');
    ASSERT_FALSE(Fb.MachineHomed, 'AC1 : aucun datum pose');
END_TEST

(* ===== Garde de descente HX3 (meme regle que la garde de montee) ===== *)
TEST 'TC-P09-H210 : garde de descente NON consommee sans commande de descente (A1/AC5)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Cfg.CfgTimeoutHomeAxes := T#60s;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BucketCloseConfirmed := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB, 'chemin herite -> HX2');
    // Capteur atteint, arret confirme, neutre : HX2 -> HX2N
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, JoystickDeflected := FALSE, BootReady := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2N_NEUTRAL, 'capteur atteint -> HX2N');
    // Poussee + homme-mort : entree en HX3 (descente au vol)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_HOME_AXES, 'HX3 engage');
    // Pause de 4 fois la garde, SANS commande de descente : aucune sanction
    ADVANCE_TIME(240000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomingFailed, 'A1/AC5 : garde de descente non consommee sans commande');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_HOME_AXES, 'HX3 toujours engage');
END_TEST

TEST 'TC-P09-H211 : garde de descente consommee quand la descente EST commandee (A1/AC5)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, Cfg := Cfg);
    Cfg.CfgTimeoutHomeAxes := T#60s;
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BucketCloseConfirmed := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := FALSE, BootReady := TRUE, BtnValidation := FALSE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, JoystickDeflected := FALSE, BootReady := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_HOME_AXES, 'HX3 engage');
    // Descente commandee en continu, capteur toujours actif (aucun front) : la garde sanctionne
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(61000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, WinchesMechanicallyStopped := TRUE,
       TopPositionSensor := TRUE, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       BootReady := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HXF_FAILED,
              'AC5 : descente commandee sans front capteur -> garde ecoulee -> abandon');
    ASSERT_TRUE(Fb.MachineHomingFailed, 'AC5 : sequence abandonnee sur garde de descente');
END_TEST

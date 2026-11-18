(* =======================================================================
   FB_CycleMachineHoming -- Tests GRAFCET homing 5 etapes (D1..D7, T417-C)
   Sequence : HX0_REPOS -> HX1_BUCKET_PREPARE -> HX2_CLIMB_TO_TOP
             -> (si TOP: HX3_TOP_CLEARANCE -> HX1_BUCKET_PREPARE)
             -> HX4_FINAL_CONFIRM -> HX0_REPOS (MachineHomed := TRUE)
             (+ HX7_FAILED)
   ======================================================================= *)

SETUP
VAR
    Fb       : FB_CycleMachineHoming;
    Cfg      : ST_fbMachineHomingCycle_Cfg;
    StNone   : ST_fbMachineHomingCycle_AxisHomingStatus;
    StBusy   : ST_fbMachineHomingCycle_AxisHomingStatus;
    StHomed  : ST_fbMachineHomingCycle_AxisHomingStatus;
    StErr    : ST_fbMachineHomingCycle_AxisHomingStatus;
END_VAR
    Cfg.CfgTopHomingTarget_M    := 8.5;
    Cfg.CfgOffsetOpen_M         := 0.0;
    Cfg.CfgOffsetClose_M        := 15.0;
    Cfg.CfgTimeoutClimb         := T#300s;
    Cfg.CfgEntryHoldTime        := T#5s;
    Cfg.CfgBucketPrepareTimeout := T#20s;
    Cfg.CfgSlackReliefMaxTime   := T#2s;
    Cfg.CfgTopClearanceTime     := T#4s;
    Cfg.CfgTimeoutHomeAxes      := T#60s;
    Cfg.Initialized             := TRUE;

    StBusy.HomedAndReliable := TRUE;
    StBusy.HomingBusy       := TRUE;
    StBusy.HomingDone       := FALSE;

    StHomed.HomedAndReliable := TRUE;
    StHomed.HomingBusy       := FALSE;
    StHomed.HomingDone       := TRUE;

    StErr.HomingError        := TRUE;
END_SETUP


(* ================= H001 : HX0 repos & verrou M3 N1/SEMI vs N2 ========= *)
TEST 'TC-P09-H001 : HX0 repos pur, M3 verrouille en N1/SEMI et libre en N2'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);

    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'HX0 au boot N1');
    ASSERT_TRUE(Fb.M3Locked, 'HX0 N1 non reference : M3 verrouille');
    ASSERT_FALSE(Fb.MachineHomingActive, 'HX0 : cycle inactif');
    ASSERT_FALSE(Fb.AllowAscent, 'HX0 : AllowAscent FALSE');
    ASSERT_FALSE(Fb.AllowDescend, 'HX0 : AllowDescend FALSE');
    ASSERT_FALSE(Fb.SoftLimitsOff, 'HX0 : SoftLimitsOff FALSE');

    (* SEMI_AUTO non reference : M3 aussi verrouille *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.SEMI_AUTO, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.M3Locked, 'HX0 SEMI_AUTO non reference : M3 verrouille');

    (* MAINT_N2 en Step 0 : echappatoire M3 libre *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.M3Locked, 'HX0 N2 : echappatoire M3 libre');
END_TEST


(* ================= H002 : HX0 -> HX1 en N1 (5s BP neutre + anti-collage) *)
TEST 'TC-P09-H002 : HX0 N1 exige relachement prealable puis 5s RawDeadmanButton au neutre'
    (* Boot avec bouton deja appuye (collage au boot) -> ne doit pas armer *)
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(6000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Bouton colle au boot refuse');

    (* Relachement observe *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);

    (* Maintien 5s mais joystick deflechi -> refuse *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(6000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Neutre strict requis en HX0');

    (* Maintien 3s au neutre -> reste en HX0, puis 5s -> passe en HX1 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(3000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Avant 5s reste HX0');

    ADVANCE_TIME(2100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, '5s neutre N1 -> HX1');
    ASSERT_TRUE(Fb.MachineHomingActive, 'HX1 : cycle actif');
    ASSERT_EQ(Fb.CmdWinchSelect, 2, 'HX1 : selecteur M2 seul');
END_TEST


(* ================= H003 : HX0 N2 BtnStart & Verrou MachineHomed ========= *)
TEST 'TC-P09-H003 : HX0 N2 StartRequest et verrou absolu si deja MachineHomed'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, JoystickDeflected := FALSE,
       M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomed, 'Machine deja referencee');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Verrou absolu : pas d entree si MachineHomed');

    (* Machine non referencee en N2 + StartRequest au neutre -> HX1 *)
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE,
       M1Status := StNone, M2Status := StNone, BucketOffsetValid := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, BucketOffsetValid := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'N2 StartRequest -> HX1');
    ASSERT_TRUE(Fb.M3Locked, 'HX1 N2 : M3 verrouillee pendant cycle');
END_TEST


(* ================= H004 : HX1 sans butees soft & timeout continu 20s ==== *)
TEST 'TC-P09-H004 : HX1 M2 ouv/ferm sans butees soft, coupure 20s continus et rearmement neutre+BP'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Entree HX1');
    ASSERT_TRUE(Fb.SoftLimitsOff, 'HX1 : SoftLimitsOff actif');
    ASSERT_TRUE(Fb.AllowAscent, 'HX1 : fermeture autorisee');
    ASSERT_TRUE(Fb.AllowDescend, 'HX1 : ouverture autorisee');

    (* Commande continue M2 pendant 19s -> toujours actif *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       StartRequest := FALSE, JoystickWinchSelectArbitrated := 2,
       DeadmanArmed := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := TRUE, JoystickPull := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ADVANCE_TIME(19000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 2,
       DeadmanArmed := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := TRUE, JoystickPull := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowAscent, 'Avant 20s : M2 encore autorise');

    (* Atteinte 20s -> coupure nette sans HX7 *)
    ADVANCE_TIME(1500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 2,
       DeadmanArmed := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := TRUE, JoystickPull := TRUE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, '20s coupe mouvement, reste HX1');
    ASSERT_FALSE(Fb.AllowAscent, 'Apres 20s : AllowAscent coupe');
    ASSERT_FALSE(Fb.AllowDescend, 'Apres 20s : AllowDescend coupe');

    (* Retour neutre SEUL avec BP encore appuye -> reste coupe *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 2,
       DeadmanArmed := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, JoystickPull := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_FALSE(Fb.AllowAscent, 'BP non relache -> reste coupe');

    (* Neutre + relachement BP -> rearmement propre *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 2,
       DeadmanArmed := FALSE, RawDeadmanButton := FALSE, JoystickDeflected := FALSE,
       M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowAscent, 'Neutre + BP relache -> HX1 rearme');
END_TEST


(* ================= H005 : HX1 -> HX2 & dwell couplage 300ms ============= *)
TEST 'TC-P09-H005 : HX1 -> HX2 sur BtnValidation neutre puis attente couplage 300ms'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Entre HX1 en N1');

    (* Validation avec manche deflechi refusee *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, JoystickDeflected := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Refus validation hors neutre');

    (* Validation au neutre -> zero provisoire 0m M1 / 15m M2 puis HX2 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, JoystickDeflected := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'HX1 -> zero provisoire M1 0.0m');
    ASSERT_EQ(Fb.M1Demand.DynamicTarget_M, 0.0, 'HX1 : M1 cible provisoire 0.0m');
    ASSERT_EQ(Fb.M2Demand.DynamicTarget_M, 15.0, 'HX1 : M2 cible provisoire 0 + OffsetCloseM');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.BucketCommit.CommitClose, 'HX1->HX2 : benne fermee referencee en interne');
    ASSERT_FALSE(Fb.MachineHomed, 'Zero provisoire : MachineHomed RESTE FALSE avant HX4');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_TO_TOP, 'BtnValidation -> HX2');
    ASSERT_EQ(Fb.CmdWinchSelect, 0, 'HX2 : couple M1+M2');

    (* Pendant dwell 300ms : mouvements encore inhibes *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       BtnValidation := FALSE, JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.AllowAscent, 'Dwell 300ms : montee bloquee');
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowAscent, 'Apres 300ms couplage : montee HX2 autorisee');
END_TEST


(* ================= H006 : HX2 detente cable max 2s ====================== *)
TEST 'TC-P09-H006 : HX2 detente cable bornee a 2s max + rearmement neutre strict'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE, BtnValidation := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       BtnValidation := FALSE, JoystickWinchSelectArbitrated := 0, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowDescend, 'HX2 : detente cable autorisee au debut');

    ADVANCE_TIME(2100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.AllowDescend, 'HX2 : detente cable coupee apres 2s');

    (* Passage par neutre strict -> rearme *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowDescend, 'HX2 : neutre strict rearme detente');
END_TEST


(* ================= H007 : HX2 contact TOP = perdu / Step 3 ============== *)
TEST 'TC-P09-H007 : HX2 contact TopPositionSensor coupe montee, ne pose aucun preset 8.5m, passe HX3'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       BtnValidation := FALSE, JoystickWinchSelectArbitrated := 0, Cfg := Cfg);
    ADVANCE_TIME(350000000);

    (* Contact capteur TOP pendant montee *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE,
       TopPositionSensor := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_TOP_CLEARANCE, 'TOP touche -> HX3 degagement');
    ASSERT_FALSE(Fb.AllowAscent, 'TOP touche -> AllowAscent coupe immediatement');
    ASSERT_FALSE(Fb.M1Demand.HomeReq, 'TOP touche -> JAMAIS de preset M1');
    ASSERT_FALSE(Fb.M2Demand.HomeReq, 'TOP touche -> JAMAIS de preset M2');
    ASSERT_FALSE(Fb.MachineHomed, 'TOP touche -> MachineHomed reste FALSE');
END_TEST


(* ================= H008 : HX3 descente 4s accumules -> retour HX1 ======= *)
TEST 'TC-P09-H008 : HX3 montee interdite, pause 2s+2s apres release TOP, re-contact remet a 0, retour HX1'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    (* Forcage mise en service en HX3 pour tester Step 3 directement *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgCommissioningEnable := TRUE, CfgForceStepTarget := 3, CfgForceStepApply := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_TOP_CLEARANCE, 'En HX3');
    ASSERT_FALSE(Fb.AllowAscent, 'HX3 : montee strictement interdite');

    (* Tant que TOP=TRUE, le timer 4s n avance pas *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgForceStepApply := FALSE, JoystickWinchSelectArbitrated := 0,
       DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE, TopPositionSensor := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       TopPositionSensor := TRUE, Cfg := Cfg);
    ASSERT_TRUE(Fb.AllowDescend, 'Tant que TOP=TRUE, degagement non fini');

    (* TOP relache -> descente 2.5s puis pause au neutre -> reste en HX3 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       TopPositionSensor := FALSE, Cfg := Cfg);
    ADVANCE_TIME(2500000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_TOP_CLEARANCE, '2.5s < 4s : reste HX3');

    (* Reprise 1.6s (cumul > 4s) -> AllowDescend coupe ; relacher neutre -> retour HX1 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       TopPositionSensor := FALSE, Cfg := Cfg);
    ADVANCE_TIME(1600000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPush := TRUE, JoystickDeflected := TRUE,
       TopPositionSensor := FALSE, Cfg := Cfg);
    ASSERT_FALSE(Fb.AllowDescend, 'Cumul 4.1s >= 4s -> coupe descente');

    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := FALSE, JoystickPush := FALSE, JoystickDeflected := FALSE,
       WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Apres 4s + neutre -> retour HX1');
END_TEST


(* ================= H009 & H010 : HX2 -> HX4 -> Homing fait ============== *)
TEST 'TC-P09-H009 : HX2 -> HX4 avertissement bloque mouvements et leve SoftLimitsOff'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       BtnValidation := FALSE, JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);

    (* Validation en HX2 avant TOP -> HX4 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, TopPositionSensor := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_FINAL_CONFIRM, 'Validation avant TOP -> HX4');
    ASSERT_FALSE(Fb.AllowAscent, 'HX4 : montee bloquee');
    ASSERT_FALSE(Fb.AllowDescend, 'HX4 : descente bloquee');
    ASSERT_FALSE(Fb.SoftLimitsOff, 'HX4 : SoftLimitsOff retombe');
END_TEST

TEST 'TC-P09-H010 : HX4 confirmation finale ecrit 8.5m M1 + 23.5m M2 puis CommitClose et MachineHomed'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       BtnValidation := FALSE, JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, Cfg := Cfg);

    (* Second BtnValidation en HX4 : ecrit 8.5m M1 + 23.5m M2 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, TopPositionSensor := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'HX4 : M1 HomeReq emis');
    ASSERT_TRUE(Fb.M1Demand.UseDynamicTarget, 'HX4 : M1 UseDynamicTarget TRUE');
    ASSERT_EQ(Fb.M1Demand.DynamicTarget_M, 8.5, 'HX4 : M1 cible 8.5m');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'HX4 : M2 HomeReq emis');
    ASSERT_TRUE(Fb.M2Demand.UseDynamicTarget, 'HX4 : M2 UseDynamicTarget TRUE');
    ASSERT_EQ(Fb.M2Demand.DynamicTarget_M, 23.5, 'HX4 : M2 cible 8.5 + 15.0 = 23.5m');

    (* Pendant HomingBusy (meme si deja Homed avant) -> ne commit pas encore *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       BtnValidation := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       M1Status := StBusy, M2Status := StBusy, Cfg := Cfg);
    ASSERT_FALSE(Fb.BucketCommit.CommitClose, 'Attend fin HomingBusy avant commit');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_FINAL_CONFIRM, 'Reste HX4 pendant preset');

    (* Fin preset confirmee -> CommitClose + MachineHomed + retour HX0 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, TopPositionSensor := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.BucketCommit.CommitClose, 'CommitClose 1 scan emis');
    ASSERT_TRUE(Fb.MachineHomed, 'MachineHomed := TRUE');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Retour HX0 apres succes');
    ASSERT_FALSE(Fb.M3Locked, 'M3 deverrouillee apres Homing fait');
END_TEST


(* ================= H011 : Garde course TOP en HX4 ======================= *)
TEST 'TC-P09-H011 : TopPositionSensor TRUE pendant attente HX4 -> repli HX3 sans commit'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgCommissioningEnable := TRUE, CfgForceStepTarget := 4, CfgForceStepApply := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgForceStepApply := FALSE, WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, TopPositionSensor := FALSE, Cfg := Cfg);
    (* Capteur TOP touche pendant transaction -> bascule HX3 immediatement *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       BtnValidation := FALSE, WinchesMechanicallyStopped := TRUE, TopPositionSensor := TRUE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_TOP_CLEARANCE, 'TOP en HX4 -> repli HX3');
    ASSERT_FALSE(Fb.BucketCommit.CommitClose, 'Aucun CommitClose sur contact TOP');
    ASSERT_FALSE(Fb.MachineHomed, 'MachineHomed reste FALSE');
END_TEST


(* ================= H012 : Changement mode (reset graphe) & Reset defaut == *)
TEST 'TC-P09-H012 : Changement de mode en cycle -> reset propre HX0 (sans faux defaut), vrai defaut -> HX7 puis Reset'
    (* 1. Demarrage N1 -> HX1, puis bascule MAINT_N2 (echappatoire secours) -> reset propre HX0 et M3 libre *)
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'N1 en HX1');

    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'N1->N2 reset propre graphe vers HX0');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'Aucun faux HX7_FAILED au changement de mode');
    ASSERT_FALSE(Fb.SoftLimitsOff, 'SoftLimitsOff coupe au reset mode');
    ASSERT_FALSE(Fb.M3Locked, 'N2 libre immediat apres sortie cycle');

    (* 2. Bascule N2 -> SEMI_AUTO/DISABLE -> reset propre HX0 aussi *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'N2 en HX1');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.DISABLE, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'N2->DISABLE reset propre vers HX0');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'DISABLE ne cree pas de faux defaut');

    (* 3. Vrai defaut codeur pendant cycle -> HX7_FAILED maintenu meme sur changement mode, efface uniquement sur Reset *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE, M1Status := StErr, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'Defaut codeur -> HX7_FAILED');
    ASSERT_TRUE(Fb.MachineHomingFailed, 'MachineHomingFailed := TRUE');
    ASSERT_FALSE(Fb.SoftLimitsOff, 'HX7 : SoftLimitsOff coupe');

    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'Changement mode ne contourne pas un vrai HX7_FAILED');

    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Reset conscient -> HX0');
    ASSERT_FALSE(Fb.MachineHomingFailed, 'Reset efface MachineHomingFailed');
END_TEST


(* ================= H013 : ClimbTimer consomme UNIQUEMENT en montee ====== *)
TEST 'TC-P09-H013 : ClimbTimer HX2 ne consomme pas au neutre, declenche apres CfgTimeoutClimb en montee'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgCommissioningEnable := TRUE, CfgForceStepTarget := 2, CfgForceStepApply := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       CfgForceStepApply := FALSE, JoystickWinchSelectArbitrated := 0, DeadmanArmed := FALSE, JoystickPull := FALSE, Cfg := Cfg);
    (* 400s au neutre -> AUCUN timeout *)
    ADVANCE_TIME(400000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := FALSE, JoystickPull := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_TO_TOP, 'Neutre prolonge ne consomme pas ClimbTimer');

    (* Montee commandee 301s -> ClimbTimedOut -> HX7_FAILED *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE, Cfg := Cfg);
    ADVANCE_TIME(301000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, DeadmanArmed := TRUE, JoystickPull := TRUE, JoystickDeflected := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX7_FAILED, 'Montee continue > 300s -> HX7_FAILED');
END_TEST


(* ================= H014 : Gate Enable = FALSE =========================== *)
TEST 'TC-P09-H014 : Enable FALSE met toutes les sorties a etat sur'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    Fb(Enable := FALSE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE, Cfg := Cfg);
    ASSERT_FALSE(Fb.Ready, 'Enable FALSE : Ready FALSE');
    ASSERT_FALSE(Fb.MachineHomingActive, 'Enable FALSE : Active FALSE');
    ASSERT_FALSE(Fb.M3Locked, 'Enable FALSE : M3Locked FALSE');
    ASSERT_FALSE(Fb.AllowAscent, 'Enable FALSE : AllowAscent FALSE');
    ASSERT_FALSE(Fb.AllowDescend, 'Enable FALSE : AllowDescend FALSE');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Enable FALSE : retour HX0');
END_TEST

(* ================= H015 : Parcours 100% joystick (sans IHM) ============= *)
TEST 'TC-P09-H015 : Cycle complet 100pct joystick BP 5s neutre HX0->HX1->HX2->HX4->Homing fait + anti-collage'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, Cfg := Cfg);
    (* HX0 -> HX1 sur BP 5s neutre *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'HX0 -> HX1 sur BP 5s');

    (* Sans relacher BP : maintien meme > 5s NE doit PAS enchaîner HX1 -> HX2 *)
    ADVANCE_TIME(6000000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE, 'Anti-collage : reste HX1 sans relachement');

    (* Relachement puis maintien 5s au neutre -> preset 0m provisoire puis HX2 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, JoystickDeflected := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, JoystickDeflected := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'HX1 BP 5s : preset 0m M1 emis');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_FALSE(Fb.MachineHomed, 'HX2 provisoire : MachineHomed FALSE');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_TO_TOP, 'HX1 -> HX2 sur BP 5s neutre');

    (* Relachement + settle 300ms + maintien 5s au neutre -> HX4 *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_FINAL_CONFIRM, 'HX2 -> HX4 sur BP 5s neutre');

    (* Relachement + maintien 5s au neutre -> Preset 8.5m + CommitClose *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, TopPositionSensor := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, TopPositionSensor := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(5100000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := TRUE, TopPositionSensor := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'HX4 BP 5s : M1 HomeReq emis');
    ASSERT_TRUE(Fb.M2Demand.HomeReq, 'HX4 BP 5s : M2 HomeReq emis');

    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, TopPositionSensor := FALSE,
       M1Status := StBusy, M2Status := StBusy, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, RawDeadmanButton := FALSE, TopPositionSensor := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.MachineHomed, 'Cycle 100pct joystick -> MachineHomed TRUE');
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Retour HX0 verrouille');
END_TEST

(* ================= H016 : Invalidation zero provisoire si abandon ======== *)
TEST 'TC-P09-H016 : Abandon avant HX4 invalide le zero provisoire 0m (codeurs + benne + MachineHomed FALSE)'
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE, BtnValidation := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX2_CLIMB_TO_TOP, 'En HX2 avec zero provisoire');
    ASSERT_FALSE(Fb.MachineHomed, 'Provisoire : MachineHomed FALSE meme si StHomed');

    (* Sortie par changement de mode (N2 -> N1) -> InvalidateProvisionalDatum + CommitInvalidate *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed, BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Abandon -> HX0');
    ASSERT_TRUE(Fb.InvalidateProvisionalDatum, 'InvalidateProvisionalDatum pulse vers codeurs');
    ASSERT_TRUE(Fb.BucketCommit.CommitInvalidate, 'CommitInvalidate pulse vers FB_Bucket');
    ASSERT_FALSE(Fb.MachineHomed, 'Apres abandon : MachineHomed reste FALSE');
END_TEST

(* ================= H017 : Garde RETAIN boot + surcourse TOP en HX4 ======= *)
TEST 'TC-P09-H017 : Reboot avec HomingProvisional RETAIN purge le zero provisoire et TopSensor HX4 annule preset'
    VAR
        StProvHomed : ST_fbMachineHomingCycle_AxisHomingStatus;
    END_VAR
    StProvHomed := StHomed;
    StProvHomed.HomingProvisional := TRUE;

    (* Simulation reboot apres coupure secteur en HX2 : HX0 recoit HomingProvisional TRUE *)
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StProvHomed, M2Status := StProvHomed,
       BucketOffsetValid := TRUE, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'Reboot -> HX0');
    ASSERT_TRUE(Fb.InvalidateProvisionalDatum, 'Reboot avec HomingProvisional -> purge codeurs');
    ASSERT_TRUE(Fb.BucketCommit.CommitInvalidate, 'Reboot avec HomingProvisional -> purge benne');
    ASSERT_FALSE(Fb.MachineHomed, 'Reboot avec HomingProvisional -> MachineHomed FALSE');

    (* Sequence HX1->HX2->HX4 puis surcourse TOP pendant Step4PresetIssued *)
    Fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, M1Status := StNone, M2Status := StNone, BucketOffsetValid := FALSE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, StartRequest := FALSE, BtnValidation := TRUE, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ADVANCE_TIME(350000000);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       JoystickWinchSelectArbitrated := 0, WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE,
       M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX4_FINAL_CONFIRM, 'En HX4');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := TRUE, M1Status := StHomed, M2Status := StHomed, Cfg := Cfg);
    ASSERT_TRUE(Fb.M1Demand.HomeReq, 'Preset HX4 lance');
    Fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
       WinchesMechanicallyStopped := TRUE, BtnValidation := FALSE, TopPositionSensor := TRUE,
       M1Status := StBusy, M2Status := StBusy, Cfg := Cfg);
    ASSERT_EQ(Fb.MachineHomingSeqStep, E_MachineHomingTxState.HX3_TOP_CLEARANCE, 'Surcourse pendant preset HX4 -> HX3');
    ASSERT_TRUE(Fb.InvalidateProvisionalDatum, 'Surcourse pendant preset HX4 -> annule transaction codeur');
    ASSERT_FALSE(Fb.MachineHomed, 'Surcourse HX4 -> MachineHomed reste FALSE');
END_TEST

(* =======================================================================
   T418 - Integration homme-mort simule -> grafcet homing (FB_SimBench + FB_CycleMachineHoming reels)
   Cablage reproduit de PRG_02_Acquisition : BtnValidation := Operator.JoyBtnRaw OR IHM.BtnValidate
   (IHM tenue a FALSE ici). Contrat : TASK_CONTRACT_T418_SIM_JOYSTICK_HOMME_MORT_SEPARE.yaml.
   Snapshots incident : Snapshot_Troubleshooting_20261013_134929 / _135017.
   ======================================================================= *)

SETUP
VAR
    Bench    : FB_SimBench;
    Hom      : FB_CycleMachineHoming;
    Cfg      : ST_fbMachineHomingCycle_Cfg;
    StHomed  : ST_fbMachineHomingCycle_AxisHomingStatus;
    RawPosM1 : UDINT := 1000000;
    RawPosM2 : UDINT := 1000000;
END_VAR
    Cfg.CfgTopHomingTarget_M := 8.5;
    Cfg.CfgOffsetClose_M     := 0.2;
    Cfg.CfgOffsetOpen_M      := 1.0;
    Cfg.CfgTimeoutClimb      := T#120s;
    Cfg.CfgTimeoutHomeAxes   := T#60s;
    Cfg.CfgStabilizationMinM := 8.50;
    Cfg.CfgStabilizationMaxM := 8.80;
    StHomed.HomedAndReliable := TRUE;
END_SETUP

TEST 'TC-T418-INT-001 N2 machine referencee : jog simule sans homme-mort -> pas de HX1, M3 libre (incident 13/10)'
VAR
    i        : INT;
    LeftHX0  : BOOL := FALSE;
    Locked   : BOOL := FALSE;
END_VAR
    Hom(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := FALSE, StartRequest := FALSE, Cfg := Cfg);
    Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := FALSE, StartRequest := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Hom.MachineHomed, 'precondition : machine referencee');
    ASSERT_EQ(Hom.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'precondition : grafcet au repos');
    FOR i := 1 TO 200 DO
        Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
              SimJoystickRawButton := FALSE,
              SimJoystickRight_Fwd_MAINT_Active := ((i MOD 50) < 40));
        Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
            WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
            BucketOffsetValid := TRUE, BtnValidation := Bench.Operator.JoyBtnRaw,
            StartRequest := FALSE, Cfg := Cfg);
        LeftHX0 := LeftHX0 OR (Hom.MachineHomingSeqStep <> E_MachineHomingTxState.HX0_REPOS);
        Locked := Locked OR Hom.M3Locked;
    END_FOR;
    ASSERT_FALSE(LeftHX0, 'jog simule seul : le grafcet homing reste en HX0 (T418 AC1)');
    ASSERT_FALSE(Locked, 'jog simule seul : M3 jamais verrouille par le homing');
END_TEST

TEST 'TC-T418-INT-002 Homme-mort tenu AVANT N2 puis jog vers Maintenance en N2 -> pas de HX1 (AC3)'
VAR
    i        : INT;
    LeftHX0  : BOOL := FALSE;
END_VAR
    Hom(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := FALSE, StartRequest := FALSE, Cfg := Cfg);
    (* Appui homme-mort en N1 : le front est consomme hors N2 *)
    FOR i := 1 TO 20 DO
        Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2, SimJoystickRawButton := TRUE);
        Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, BootReady := TRUE,
            WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
            BucketOffsetValid := TRUE, BtnValidation := Bench.Operator.JoyBtnRaw,
            StartRequest := FALSE, Cfg := Cfg);
    END_FOR;
    ASSERT_EQ(Hom.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'front homme-mort en N1 : HX0');
    (* Passage N2, homme-mort toujours tenu, jogs vers Maintenance *)
    FOR i := 1 TO 200 DO
        Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
              SimJoystickRawButton := TRUE,
              SimJoystickRight_Fwd_MAINT_Active := ((i MOD 50) < 40));
        Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
            WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
            BucketOffsetValid := TRUE, BtnValidation := Bench.Operator.JoyBtnRaw,
            StartRequest := FALSE, Cfg := Cfg);
        LeftHX0 := LeftHX0 OR (Hom.MachineHomingSeqStep <> E_MachineHomingTxState.HX0_REPOS);
    END_FOR;
    ASSERT_FALSE(LeftHX0, 'homme-mort tenu depuis N1 + jogs en N2 : aucun nouveau front, reste HX0');
    ASSERT_TRUE(Hom.MachineHomed, 'machine toujours referencee');
END_TEST

TEST 'TC-T418-INT-003 CONSTAT (a corriger par T377) : premier appui homme-mort EN N2, machine referencee -> HX1'
    (* AC4 : comportement du code machine deploye (FB_CycleMachineHoming HX0 :
       (StartEdge OR BtnValidationEdge) AND ModeIsMaint2, sans condition de reference).
       Ce test FIGE le constat ; T377 le changera (AC9 : homme-mort seul ne lance pas la sequence
       sur machine referencee). T418 ne le corrige pas : le code machine n'est pas modifie. *)
    Hom(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := FALSE, StartRequest := FALSE, Cfg := Cfg);
    Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2, SimJoystickRawButton := FALSE);
    Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := Bench.Operator.JoyBtnRaw,
        StartRequest := FALSE, Cfg := Cfg);
    ASSERT_TRUE(Hom.MachineHomed, 'precondition : machine referencee');
    ASSERT_EQ(Hom.MachineHomingSeqStep, E_MachineHomingTxState.HX0_REPOS, 'precondition : HX0');
    Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2, SimJoystickRawButton := TRUE);
    Hom(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, BootReady := TRUE,
        WinchesMechanicallyStopped := TRUE, M1Status := StHomed, M2Status := StHomed,
        BucketOffsetValid := TRUE, BtnValidation := Bench.Operator.JoyBtnRaw,
        StartRequest := FALSE, Cfg := Cfg);
    ASSERT_EQ(Hom.MachineHomingSeqStep, E_MachineHomingTxState.HX1_BUCKET_PREPARE,
              'CONSTAT v0.7.25 : premier front homme-mort en N2 lance HX1 meme machine referencee (T377 AC9)');
    ASSERT_TRUE(Hom.M3Locked, 'CONSTAT : M3 verrouille des HX1');
END_TEST

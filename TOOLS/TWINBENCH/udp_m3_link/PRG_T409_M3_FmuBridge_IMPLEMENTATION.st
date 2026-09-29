IF Stop OR NOT Enable OR NOT GVL_Simulation.SimulationModeActive OR NOT GVL_Simulation.SimM3OpenModelicaActive THEN
    IF SocketHandle <> SysTypes.RTS_INVALID_HANDLE THEN SysSockCloseUdp(SocketHandle); END_IF;
    SocketHandle := SysTypes.RTS_INVALID_HANDLE;
    LinkReady := FALSE;
    LinkInvalid := FALSE;
    Timeout := FALSE;
    SensorWordIncoherent := FALSE;
    FmuPosition_M := 0.0;
    FmuVelocity_Mps := 0.0;
    FmuFrequency_Hz := 0.0;
    FmuState := 0;
    FmuAge_ms := 0;
    LastRxAgeCycles := 0;
    RETURN;
END_IF;

IF SocketHandle = SysTypes.RTS_INVALID_HANDLE THEN
    SocketHandle := SysSockCreateUdp(29061, 29062, ADR(LastResult));
    IF SocketHandle <> SysTypes.RTS_INVALID_HANDLE THEN
        LastResult := SysSockIoctl(SocketHandle, SOCKET_FIONBIO, ADR(NonBlocking));
    END_IF;
    RETURN;
END_IF;

// M3B1 / schema 1 / commande 1 / sequence / Hz*100 / control word / frein.
Tx[0] := 16#4D; Tx[1] := 16#33; Tx[2] := 16#42; Tx[3] := 16#31;
Tx[4] := 1; Tx[5] := 1;
Tx[6] := UDINT_TO_BYTE(Sequence AND 16#FF);
Tx[7] := UDINT_TO_BYTE(SHR(Sequence, 8) AND 16#FF);
Tx[8] := UDINT_TO_BYTE(SHR(Sequence, 16) AND 16#FF);
Tx[9] := UDINT_TO_BYTE(SHR(Sequence, 24) AND 16#FF);
Tx[10] := UINT_TO_BYTE((REAL_TO_UINT(LIMIT(0.0, GVL_Troubleshooting.L_TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz, 50.0) * 100.0)) MOD 5001);
Tx[11] := UINT_TO_BYTE(SHR(REAL_TO_UINT(LIMIT(0.0, GVL_Troubleshooting.L_TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz, 50.0) * 100.0), 8));
Tx[12] := UINT_TO_BYTE(GVL_Troubleshooting.L_TranslationPontM3.Control_400.Idx403_DriveControlWord);
Tx[13] := UINT_TO_BYTE(SHR(GVL_Troubleshooting.L_TranslationPontM3.Control_400.Idx403_DriveControlWord, 8));
Tx[14] := BOOL_TO_BYTE(GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ);
Bytes := SysSockSendToUdp(SocketHandle, 29061, '127.0.0.1', ADR(Tx), SIZEOF(Tx), ADR(LastResult));
IF Bytes = SIZEOF(Tx) THEN TxCount := TxCount + 1; Sequence := Sequence + 1; ELSE RejectCount := RejectCount + 1; END_IF;

Bytes := SysSockRecvFromUdp(SocketHandle, ADR(Rx), SIZEOF(Rx), ADR(Reply), ADR(LastResult));
IF Bytes = 39 THEN
    IF (Rx[0] = 16#4D) AND (Rx[1] = 16#33) AND (Rx[2] = 16#42) AND (Rx[3] = 16#31) AND (Rx[4] = 1) AND (Rx[5] = 2) THEN
        RxSequence := BYTE_TO_UDINT(Rx[6]) OR SHL(BYTE_TO_UDINT(Rx[7]), 8) OR SHL(BYTE_TO_UDINT(Rx[8]), 16) OR SHL(BYTE_TO_UDINT(Rx[9]), 24);
        RxCommandSequence := BYTE_TO_UDINT(Rx[10]) OR SHL(BYTE_TO_UDINT(Rx[11]), 8) OR SHL(BYTE_TO_UDINT(Rx[12]), 16) OR SHL(BYTE_TO_UDINT(Rx[13]), 24);
        RxSequenceNewer := (RxCommandSequence > LastRxSequence) AND (RxSequence > LastRxSequence);
        // UDINT : FFFFFFFF -> 0 est la progression normale après wrap.
        IF (LastRxSequence = 16#FFFFFFFF) AND (RxCommandSequence = 0) AND (RxSequence = 0) THEN
            RxSequenceNewer := TRUE;
        END_IF;
        IF (RxCount > 0) AND NOT RxSequenceNewer THEN
            LinkInvalid := TRUE;
            RejectCount := RejectCount + 1;
        ELSE
            // Octets 14-15 = consigne appliquee ; 16-17 = frequence mesuree FMU.
            RxFrequency_x100 := BYTE_TO_UINT(Rx[16]) OR SHL(BYTE_TO_UINT(Rx[17]), 8);
            RxBrakeOpen := Rx[20] <> 0;
            RxStatusWord := BYTE_TO_WORD(Rx[21]);
            RxSensors[0] := Rx[22] <> 0; RxSensors[1] := Rx[23] <> 0; RxSensors[2] := Rx[24] <> 0;
            RxSensors[3] := Rx[25] <> 0; RxSensors[4] := Rx[26] <> 0;
            RxPosition_x1000 := BYTE_TO_DINT(Rx[27]) OR SHL(BYTE_TO_DINT(Rx[28]), 8) OR SHL(BYTE_TO_DINT(Rx[29]), 16) OR SHL(BYTE_TO_DINT(Rx[30]), 24);
            RxHardStop := Rx[35] <> 0;
            RxVelocity_x1000 := BYTE_TO_DINT(Rx[18]) OR SHL(BYTE_TO_DINT(Rx[19]), 8);
            IF RxVelocity_x1000 >= 32768 THEN RxVelocity_x1000 := RxVelocity_x1000 - 65536; END_IF;
            // Chaîne terrain admissible : 11111 -> 01111 -> 00111 -> 00011 -> 00001 -> 00000.
            // Une rupture false->true vers la droite est incohérente.
            SensorWordIncoherent := (NOT RxSensors[0] AND RxSensors[1]) OR (NOT RxSensors[1] AND RxSensors[2]) OR (NOT RxSensors[2] AND RxSensors[3]) OR (NOT RxSensors[3] AND RxSensors[4]);
            IF SensorWordIncoherent THEN
                LinkInvalid := TRUE;
                RejectCount := RejectCount + 1;
            ELSE
            GVL_Simulation.SimM3OpenModelica.M3_PosTremie_DI := RxSensors[0];
            GVL_Simulation.SimM3OpenModelica.M3_PosPV_DI := RxSensors[1];
            GVL_Simulation.SimM3OpenModelica.M3_PosPVP2_DI := RxSensors[2];
            GVL_Simulation.SimM3OpenModelica.M3_PosP1_DI := RxSensors[3];
            GVL_Simulation.SimM3OpenModelica.M3_PosMaintenance_DI := RxSensors[4];
            GVL_Simulation.SimM3OpenModelica.M3_BrakeIsOpen_DI := RxBrakeOpen;
            GVL_Simulation.SimM3OpenModelica.M3_ThermalOK_DI := TRUE;
            GVL_Simulation.SimM3OpenModelica.M3_StatusWord := RxStatusWord;
            GVL_Simulation.SimM3OpenModelica.M3_ActualFrequencyHz := RxFrequency_x100;
            FmuPosition_M := DINT_TO_REAL(RxPosition_x1000) / 1000.0;
            FmuVelocity_Mps := DINT_TO_REAL(RxVelocity_x1000) / 1000.0;
            FmuFrequency_Hz := UINT_TO_REAL(RxFrequency_x100) / 100.0;
            IF RxHardStop THEN FmuState := 4;
            ELSIF RxSensors[0] AND RxSensors[1] AND RxSensors[2] AND RxSensors[3] AND RxSensors[4] THEN FmuState := 1;
            ELSIF NOT RxSensors[0] AND NOT RxSensors[1] AND NOT RxSensors[2] AND NOT RxSensors[3] AND RxSensors[4] THEN FmuState := 3;
            ELSE FmuState := 2; END_IF;
            LastRxSequence := RxSequence;
            LastRxAgeCycles := 0;
            FmuAge_ms := 0;
            LinkReady := TRUE;
            LinkInvalid := FALSE;
            Timeout := FALSE;
            RxCount := RxCount + 1;
            END_IF;
        END_IF;
    ELSE
        LinkInvalid := TRUE; RejectCount := RejectCount + 1;
    END_IF;
ELSIF LastRxAgeCycles < 1000 THEN
    LastRxAgeCycles := LastRxAgeCycles + 1;
END_IF;

IF LastRxAgeCycles > 100 THEN
    Timeout := TRUE;
    LinkReady := FALSE;
    LinkInvalid := TRUE;
    GVL_Simulation.SimM3OpenModelica.M3_PosTremie_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_PosPV_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_PosPVP2_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_PosP1_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_PosMaintenance_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_BrakeIsOpen_DI := FALSE;
    GVL_Simulation.SimM3OpenModelica.M3_ActualFrequencyHz := 0;
    FmuAge_ms := LastRxAgeCycles * 10;
END_IF;

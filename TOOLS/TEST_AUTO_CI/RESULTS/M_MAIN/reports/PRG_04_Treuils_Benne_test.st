SETUP
VAR
    harness : FB_TestHarness_PRG_04;
    acqData : ST_AcquisitionInterPrg;
    modesAuth : ST_Modes_Autorisations;
END_VAR
END_SETUP

TEST 'PRG_04_Treuils_Benne : Commande Montee M1 via Bus AcqData + ModesAuth'
    // 1. Initialisation au repos pour etablir Enable et passer D18
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 1; // M1
    acqData.EncoderM1.Measurement.EncoderAvailable := TRUE;
    acqData.EncoderM1.Measurement.CablePosM := 2.0;
    
    // Scan 1 au repos (Enable montant)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        PowerContactorEngaged := TRUE,
        M1_ContactorsReleased := TRUE
    );

    // 2. Application de la commande montee (Scan 2)
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AtNeutralXY := FALSE;
    acqData.Joystick.AxisY.Direction := 1;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        BtnWinchM1Up := TRUE,
        PowerContactorEngaged := TRUE,
        M1_ContactorsReleased := TRUE
    );

    // 3. Verification des demandes produites sur le bus sortant ST_WinchInterPrg
    ASSERT_TRUE(harness.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'ST_WinchInterPrg: Ordre RelayFwd genere vers PRG_06');
    ASSERT_FALSE(harness.Data.WinchM1Safety.SafeStop, 'ST_WinchInterPrg: Aucun SafeStop actif');
    ASSERT_GT(harness.Data.M1LogicRequestSpeedCmd_Pct, 0.0, 'ST_WinchInterPrg: consigne vitesse M1 non nulle en montee');
    ASSERT_TRUE(harness.Data.WinchM1State.RelayFwd, 'ST_WinchInterPrg: WinchM1State.RelayFwd reflete la demande');
END_TEST


TEST 'PRG_04_Treuils_Benne : SafeStop Treuil M1 sur Defaut Codeur (Bus AcqData)'
    modesAuth.Mode := E_Mode.MAINT_N1;
    // Stimulus : Defaut codeur remonte par le bus PRG_02
    acqData.EncoderM1.Measurement.EncoderAvailable := FALSE;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        PowerContactorEngaged := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        PowerContactorEngaged := TRUE
    );

    ASSERT_TRUE(harness.Data.WinchM1Safety.SafeStop, 'ST_WinchInterPrg: SafeStop declenche immediatement sur defaut codeur');
    ASSERT_FALSE(harness.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'Mouvement neutralise sur defaut codeur');
END_TEST

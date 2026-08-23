SETUP
VAR
    harness : FB_TestHarness_PRG_04;
    acqData : ST_AcquisitionInterPrg;
    modesAuth : ST_Modes_Autorisations;
END_VAR
END_SETUP

TEST 'PRG_04_Treuils_Benne : Commande Montee M1 via Bus AcqData + ModesAuth'
    // 1. Contexte : Mode Manuel N1, Treuil M1 selectionne
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 1; // M1

    // 2. Stimulus issu du bus PRG_02 : Homme mort arme, manche non centre (Montee)
    acqData.JoystickDeadmanArmed := TRUE;
    acqData.JoystickYNeutral := FALSE;
    acqData.JoystickDirectionX := 0;
    acqData.CablePosM1 := 2.0;
    acqData.M1_Speed_Mps := 0.0;

    // 3. Execution PRG_04 (2 cycles pour passer le premier scan d'init FirstScanDone)
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        BtnWinchM1Up := TRUE,
        PowerContactorEngaged := TRUE,
        M1_ContactorsReleased := TRUE
    );
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        BtnWinchM1Up := TRUE,
        PowerContactorEngaged := TRUE,
        M1_ContactorsReleased := TRUE
    );

    // 4. Verification des demandes produites sur le bus sortant ST_WinchInterPrg
    ASSERT_TRUE(harness.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd, 'ST_WinchInterPrg: Ordre RelayFwd genere vers PRG_06');
    ASSERT_FALSE(harness.Data.WinchM1Safety.SafeStop, 'ST_WinchInterPrg: Aucun SafeStop actif');
    // Consigne vitesse arbitree (ST_WinchInterPrg.M1LogicRequestSpeedRef_Pct)
    ASSERT_GT(harness.Data.M1LogicRequestSpeedRef_Pct, 0.0, 'ST_WinchInterPrg: consigne vitesse M1 non nulle en montee');
    // Etat public treuil (ST_WinchInterPrg.WinchM1State)
    ASSERT_TRUE(harness.Data.WinchM1State.RelayFwd, 'ST_WinchInterPrg: WinchM1State.RelayFwd reflete la demande');
END_TEST


TEST 'PRG_04_Treuils_Benne : SafeStop Treuil M1 sur Defaut Codeur (Bus AcqData)'
    // Stimulus : Defaut codeur remonte par le bus PRG_02
    acqData.M1_EncoderFault := TRUE;

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

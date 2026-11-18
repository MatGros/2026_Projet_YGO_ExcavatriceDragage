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

TEST 'PRG_04_Treuils_Benne : T417-C A2 Feature Escalade PowerCutOff 2s si non-arret reel au TOP (Option 2)'
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 1;
    acqData.EncoderM1.Measurement.EncoderAvailable := TRUE;
    acqData.EncoderM1.Measurement.CablePosM := 8.5;
    acqData.EncoderM1.Measurement.SpeedValid := TRUE;
    acqData.EncoderM1.Measurement.SignedSpeed_Mps := 0.0;
    acqData.Joystick.AtNeutralXY := TRUE;

    // Scan 1 : repos sain pour etablir Enable
    harness(AcqData := acqData, ModesAuth := modesAuth, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := TRUE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'Repos sain -> aucune coupure');

    // Contact TOP + contacteur reste colle (M1_ContactorsReleased = FALSE) -> avant 2s pas de PowerCutOff, >= 2s PowerCutOff MecaD
    acqData.Joystick.AtNeutralXY := FALSE;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisY.Direction := 1;
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Up := TRUE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := FALSE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := FALSE);
    ADVANCE_TIME(1500000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Up := TRUE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := FALSE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := FALSE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'Sous 2s -> pas encore PowerCutOff');

    ADVANCE_TIME(600000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Up := TRUE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := FALSE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := FALSE);
    ASSERT_TRUE(harness.Data.WinchM1Safety.PowerCutOff, 'A 2.1s avec non-arret materiel TOP -> PowerCutOff');
    ASSERT_TRUE(harness.Data.WinchM1Safety.ErrorMecaD, 'Cause 11 MecaD activee sans nouvelle cause');

    // Reset + latch TOP maintient blocage montee, descente reste libre
    acqData.Joystick.AtNeutralXY := TRUE;
    acqData.Joystick.DeadmanArmed := FALSE;
    acqData.Joystick.AxisY.Direction := 0;
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Up := FALSE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := TRUE,
            TopHardStopLatched := TRUE, FaultMachineResetIHM := TRUE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'Reset hors capteur -> PowerCutOff retombe');
    ASSERT_FALSE(harness.Data.WinchM1Safety.AscentPermit, 'TopHardStopLatched -> AscentPermit reste coupe');
    ASSERT_TRUE(harness.Data.WinchM1Safety.DescendPermit, 'TopHardStopLatched -> DescendPermit reste libre');
END_TEST

TEST 'PRG_04_Treuils_Benne : T417-C A2 Non-Regression repos TOP, descente pure, MecaD 3s, BrakeForceAllowed'
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 1;
    acqData.EncoderM1.Measurement.EncoderAvailable := TRUE;
    acqData.EncoderM1.Measurement.CablePosM := 8.5;
    acqData.EncoderM1.Measurement.SpeedValid := TRUE;
    acqData.EncoderM1.Measurement.SignedSpeed_Mps := 0.0;
    acqData.Joystick.AtNeutralXY := TRUE;

    // 1. Contact TOP au repos (contacteurs retombes, frein ferme, vitesse 0) -> AUCUNE coupure meme apres 5s
    harness(AcqData := acqData, ModesAuth := modesAuth, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := FALSE);
    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := FALSE, TopPositionFreeDI := FALSE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'Repos sur capteur TOP -> aucune coupure puissance');

    // 2. Contact TOP + descente pure -> AUCUNE coupure meme avec frein ouvert et descente active
    acqData.Joystick.AtNeutralXY := FALSE;
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AxisY.Direction := -1;
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Down := TRUE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := FALSE, M1_BrakeFeedbackOpen := TRUE, TopPositionFreeDI := FALSE);
    ADVANCE_TIME(4000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Down := TRUE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := FALSE, M1_BrakeFeedbackOpen := TRUE, TopPositionFreeDI := FALSE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'Descente pure sur capteur TOP -> aucune coupure');
    ASSERT_TRUE(harness.Data.WinchM1Safety.DescendPermit, 'Descente pure toujours permise sur TOP');

    // 3. Meca D general (PostRampTimeout = 3s conserve quand contact TOP + frein ouvert + repos sans mouvement)
    acqData.Joystick.AtNeutralXY := TRUE;
    acqData.Joystick.DeadmanArmed := FALSE;
    acqData.Joystick.AxisY.Direction := 0;
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Down := FALSE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := TRUE, TopPositionFreeDI := FALSE, BrakeForceAllowedM1 := FALSE);
    ADVANCE_TIME(2200000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Down := FALSE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := TRUE, TopPositionFreeDI := FALSE, BrakeForceAllowedM1 := FALSE);
    ASSERT_FALSE(harness.Data.WinchM1Safety.PowerCutOff, 'MecaD general reste a 3s (pas declenche a 2.2s)');
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, BtnWinchM1Down := FALSE, PowerContactorEngaged := TRUE,
            M1_ContactorsReleased := TRUE, M1_BrakeFeedbackOpen := TRUE, TopPositionFreeDI := FALSE, BrakeForceAllowedM1 := FALSE);
    ASSERT_TRUE(harness.Data.WinchM1Safety.PowerCutOff, 'MecaD general coupe bien a 3.2s');
END_TEST

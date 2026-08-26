SETUP
VAR
    harness : FB_TestHarness_PRG_02;
END_VAR
END_SETUP

TEST 'PRG_02_Acquisition : Qualification joystick (neutre -> armement -> consigne X)'
    // 1. Initialisation au neutre
    harness(
        JoyRawX := 5000,
        JoyRawY := 5000,
        JoyBtnRaw := FALSE,
        COD1_PosValue := 1008192, // 2.0 m
        COD2_PosValue := 1008192
    );
    ADVANCE_TIME(60000000);
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE); // Appui homme-mort au neutre
    ADVANCE_TIME(150000000); // 150 ms (> 100 ms DeadmanArmHoldTime)
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE);
    
    // Vérification de la structure Data (ST_AcquisitionInterPrg)
    ASSERT_TRUE(harness.Data.JoystickDeadmanArmed, 'Structure Data: Homme-mort arme avec succes');
    ASSERT_EQ(harness.Data.CablePosM1, 2.0, 'Structure Data: Position cable M1 = 2.0m');
    ASSERT_TRUE(harness.Data.M1_HomedAndReliable, 'Structure Data: Codeur M1 fiabilise');

    // 2. Mouvement manche a droite (RawX = 8000)
    harness(JoyRawX := 8000, JoyRawY := 5000, JoyBtnRaw := TRUE);
    ASSERT_EQ(harness.Data.JoystickDirectionX, 1, 'Sens X positif detecte (Translation Droite)');
    ASSERT_GT(harness.Data.JoystickSpeedPctX, 0.0, 'Consigne de vitesse non nulle transmise sur le bus Data');
    
    // Vérification de la structure d'image matérielle HwIn (ST_HardwareImage)
    ASSERT_EQ(harness.HwIn.Operator.JoyXRaw_ANA1, 8000, 'Structure HwIn: JoyXRaw_ANA1 transmis');
    ASSERT_TRUE(harness.HwIn.Operator.JoyBtnRaw, 'Structure HwIn: JoyBtnRaw transmis');
END_TEST


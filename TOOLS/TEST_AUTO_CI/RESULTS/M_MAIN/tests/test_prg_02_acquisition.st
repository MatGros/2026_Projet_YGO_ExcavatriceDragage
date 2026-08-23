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

TEST 'PRG_02_Acquisition : Decodage capteurs Translation M3 et calcul mot de position'
    // Activation capteurs zone Tremie et injection des retours de freins/contacteurs
    harness(
        M3_PosTremie_DI := TRUE,
        M3_PosPV_DI := TRUE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE,
        M1_BrakeCmd := TRUE,
        M3_BrakeCmd := TRUE
    );
    // Vérification du bus Data
    ASSERT_TRUE(harness.Data.TranslationAtTremie, 'Structure Data: Position exacte Tremie atteinte');
    ASSERT_TRUE(harness.Data.M3_LimitSwitchFwd, 'Structure Data: Fin de course avant actif a la tremie');
    ASSERT_FALSE(harness.Data.M3_SensorWordIncoherent, 'Structure Data: Mot capteurs coherent');
    
    // Vérification du bus HwIn
    ASSERT_TRUE(harness.HwIn.Translation.M3_PosTremie_DI, 'Structure HwIn: Capteur Tremie transmis');
    ASSERT_TRUE(harness.HwIn.Winch.M1_BrakeIsOpen_DI, 'Structure HwIn: Retour frein M1 recopie');
    ASSERT_TRUE(harness.HwIn.Translation.M3_BrakeIsOpen_DI, 'Structure HwIn: Retour frein M3 recopie');
END_TEST


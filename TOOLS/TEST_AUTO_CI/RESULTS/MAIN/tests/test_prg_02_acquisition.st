SETUP
VAR
    harness : FB_TestHarness_PRG_02;
END_VAR
END_SETUP

TEST 'PRG_02_Acquisition : Qualification joystick (neutre -> armement -> consigne X)'
    // 1. Initialisation au neutre
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := FALSE);
    ADVANCE_TIME(60000000);
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE); // Appui homme-mort au neutre
    ADVANCE_TIME(60000000);
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE);
    ASSERT_TRUE(harness.Data.JoystickDeadmanArmed, 'Homme-mort arme avec succes');

    // 2. Mouvement manche a droite (RawX = 8000)
    harness(JoyRawX := 8000, JoyRawY := 5000, JoyBtnRaw := FALSE);
    ASSERT_EQ(harness.Data.JoystickDirectionX, 1, 'Sens X positif detecte (Translation Droite)');
    ASSERT_GT(harness.Data.JoystickSpeedPctX, 0.0, 'Consigne de vitesse non nulle transmise sur le bus Data');
END_TEST

TEST 'PRG_02_Acquisition : Decodage capteurs Translation M3 et calcul mot de position'
    // Activation capteurs zone Tremie (SensorTremie=TRUE, SensorPV=TRUE, SensorP2=TRUE, SensorP1=TRUE, SensorMaintenance=TRUE -> 2#11111)
    harness(
        M3_PosTremie_DI := TRUE,
        M3_PosPV_DI := TRUE,
        M3_PosPVP2_DI := TRUE,
        M3_PosP1_DI := TRUE,
        M3_PosMaintenance_DI := TRUE
    );
    ASSERT_TRUE(harness.Data.TranslationAtTremie, 'Position exacte Tremie atteinte');
    ASSERT_TRUE(harness.Data.M3_LimitSwitchFwd, 'Fin de course avant actif a la tremie');
    ASSERT_FALSE(harness.Data.M3_SensorWordIncoherent, 'Mot capteurs coherent');
END_TEST

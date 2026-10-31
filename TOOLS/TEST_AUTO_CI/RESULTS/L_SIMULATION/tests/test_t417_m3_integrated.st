(* T417 D2 : boucle fermee avec le vrai cycle, arbitrage M3, safety, translation,
   interlock final, decodeur, estimateur et SimBench. Le point de depart AX14 est
   force par l'entree publique StepForceTgt; M1/M2 et la benne restent des entrees de banc. *)
SETUP
VAR
    FB : FB_TestHarnessT417_M3;
    RawPosM1 : UDINT := 0;
    RawPosM2 : UDINT := 0;
END_VAR
END_SETUP

TEST 'T417-E2E-010 AX14 vers Tremie, AX15A/B/C/18 puis retour et arret P1'
VAR
    i : INT;
    JogBack : BOOL;
    PostP1Scans : INT;
END_VAR
    (* Duree de demarrage safety (3 s) + stabilisation position au boot (500 ms). *)
    FOR i := 1 TO 320 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, SimM3Slope_Mps2 := -0.2,
           BenneDone := FALSE, BenneIsOpen := FALSE);
    END_FOR;
    ASSERT_NEAR(FB.M3PositionTrue_M, 5.0, 0.02, 'Position physique initiale P1 issue de SimBench');
    ASSERT_NEAR(FB.M3PositionEstimated_M, 5.0, 0.02, 'Estimateur cale independamment sur le capteur P1');
    ASSERT_EQ(FB.M3SensorsWord, 2#00011, 'Mot capteurs initial P1');

    (* Forcage de mise en service sur AX14 : ce preconditionnement ne prouve pas AX0..AX14. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := 14, SimM3Slope_Mps2 := -0.2,
       BenneDone := FALSE, BenneIsOpen := FALSE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickLeft := TRUE,
       SimM3Slope_Mps2 := -0.2, BenneDone := FALSE, BenneIsOpen := FALSE);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX14_TRANSLATE_DUMP, 'Depart du segment en AX14');
    ASSERT_TRUE(FB.CycleReqStart, 'AX14 emet une demande de translation');
    ASSERT_EQ(FB.CyclePositionTgt, 1, 'AX14 cible la Tremie');
    ASSERT_TRUE(FB.ArbitrationReqTremie, 'Arbitrage semi-auto emet le sens Tremie');

    (* Course physique par SimBench, retour frequence et capteurs reels du modele. *)
    FOR i := 1 TO 1500 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, JoystickLeft := TRUE,
           SimM3Slope_Mps2 := -0.2, BenneDone := FALSE, BenneIsOpen := FALSE);
    END_FOR;
    ASSERT_TRUE(FB.M3AtTremie, 'Jeton Tremie issu du decodeur sur franchissement');
    ASSERT_EQ(FB.M3SensorsWord, 2#11111, 'Mot capteurs coherent a Tremie');
    ASSERT_FALSE(FB.M3ReqTremie, 'Le cycle retire la commande au capteur Tremie');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande variateur residuelle a Tremie');

    (* Relachement operateur, confirmation d arret, puis AX15A. *)
    FOR i := 1 TO 60 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, JoystickLeft := FALSE,
           SimM3Slope_Mps2 := -0.2, BenneDone := FALSE, BenneIsOpen := FALSE);
    END_FOR;
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX15A_DUMP_ARRIVE, 'AX15A apres capteur et arret confirme');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande M3 pendant AX15A');

    (* AX15A exige un neutre puis un nouveau push operateur. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       SimM3Slope_Mps2 := -0.2, BenneDone := FALSE, BenneIsOpen := FALSE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       SimM3Slope_Mps2 := -0.2, BenneDone := FALSE, BenneIsOpen := FALSE);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX15B_DUMP_OPEN, 'Nouveau push apres neutre arme AX15B');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande M3 pendant AX15B');

    (* Branche AX15B <-> AX15C : repositionnement treuil mocke, translation vraie neutralisee. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       RepositionRequest := TRUE, SimM3Slope_Mps2 := -0.2,
       BenneDone := FALSE, BenneIsOpen := FALSE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       RepositionRequest := TRUE, SimM3Slope_Mps2 := -0.2,
       BenneDone := FALSE, BenneIsOpen := FALSE);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX15C_DUMP_REPOSITION, 'Option maintenue entre en AX15C');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande M3 pendant AX15C');

    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       RepositionRequest := FALSE, SimM3Slope_Mps2 := -0.2,
       BenneDone := FALSE, BenneIsOpen := FALSE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       RepositionRequest := FALSE, SimM3Slope_Mps2 := -0.2,
       BenneDone := FALSE, BenneIsOpen := FALSE);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX15B_DUMP_OPEN, 'Relachement option retourne en AX15B');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'M3 reste neutralisee au retour AX15B');

    (* Les seuls faits benne substitues sont declares : fin ouverture et benne ouverte. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickPush := TRUE,
       BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX18_DONE_SYNC, 'Fin de passe AX18');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande M3 pendant AX18');

    (* AX18 vers AX2 puis course inverse jusqu a P1; l arret et les capteurs viennent de SimBench. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickRight := TRUE, JoystickPush := FALSE, JoystickPull := FALSE,
       BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, StepForceTgt := -1, JoystickRight := TRUE, JoystickPush := FALSE, JoystickPull := FALSE,
       BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX2_TRANSLATE_P1, 'Geste franc AX18 relance AX2');
    ASSERT_TRUE(FB.CycleReqStart, 'AX2 emet une demande pour atteindre P1');
    ASSERT_TRUE(FB.ArbitrationReqMaintenance, 'Retour vers P1 arbitre le sens Maintenance');
    PostP1Scans := 0;
    FOR i := 1 TO 1500 DO
        ADVANCE_TIME(10000000);
        IF NOT FB.M3AtP1 OR (PostP1Scans < 500) THEN
            JogBack := NOT FB.M3AtP1;
            FB(Enable := TRUE, StepForceTgt := -1, JoystickRight := JogBack, JoystickPush := FALSE, JoystickPull := FALSE,
               BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
            IF FB.M3AtP1 THEN
                PostP1Scans := PostP1Scans + 1;
            END_IF;
        END_IF;
    END_FOR;
    ASSERT_TRUE(FB.M3AtP1, 'Jeton P1 issu du decodeur au retour');
    ASSERT_TRUE(FB.P1ArrivalCaptured, 'Snapshot P1 capture en AX2');
    ASSERT_EQ(FB.P1ArrivalDriveControlWord, 0, 'Sortie finale nulle au snapshot P1');
    ASSERT_NEAR(FB.P1ArrivalPosition_M, 5.0, 0.04, 'Position physique au snapshot dans la bande P1');
    ASSERT_LE(FB.P1ArrivalFrequency_Hz, 20.5, 'Frequence au snapshot sous la limite approche P1 de 20 Hz');
    FOR i := 1 TO 500 DO
        ADVANCE_TIME(10000000);
        FB(Enable := TRUE, StepForceTgt := -1, JoystickRight := FALSE, JoystickPush := FALSE,
           JoystickPull := FALSE, BenneDone := TRUE, BenneIsOpen := TRUE, SimM3Slope_Mps2 := -0.2);
    END_FOR;
    ASSERT_EQ(FB.CycleStep, E_AutoCycleStep.AX2_TRANSLATE_P1, 'Cycle stabilise en AX2 sur P1');
    ASSERT_EQ(FB.M3DriveControlWord, 0, 'Aucune commande variateur apres arret P1');
    ASSERT_NEAR(FB.M3DriveActualFreq_Hz, 0.0, 0.5, 'Frequence réelle sous le seuil d arret apres 5 s');
    ASSERT_FALSE(FB.M3BrakeContactOpen, 'Contact frein ferme apres 5 s sans commande');
    ASSERT_FALSE(FB.M3CartFree, 'Le chariot ne reste pas en roue libre apres fermeture du frein');
    ASSERT_EQ(FB.M3OvershootSensorId, 3, 'La metrique de depassement est associee au capteur P1');
    ASSERT_NEAR(FB.M3OvershootLast_M, ABS(FB.M3PositionTrue_M - FB.P1ArrivalPosition_M), 0.02,
                'Distance mesuree apres le front P1 egale au deplacement jusqu au repos');
    ASSERT_LE(FB.M3OvershootLast_M, 0.04, 'Depassement P1 limite a la largeur totale d hysteresis 0.02 m x 2');
    ASSERT_FALSE(FB.TranslationSafetyError, 'Aucun defaut safety injecte');
    ASSERT_FALSE(FB.TranslationMotionError, 'Aucun defaut mouvement');
    ASSERT_FALSE(FB.FinalInterlockError, 'Aucun defaut interlock final');
    ASSERT_FALSE(FB.CycleError, 'Aucun defaut sequenceur');
    ASSERT_NEAR(FB.M3PositionTrue_M, 5.0, 0.04, 'Position physique stabilisee dans la bande P1');
    ASSERT_NEAR(FB.M3PositionEstimated_M, 5.0, 0.04, 'Position estimee recalee a P1');
    ASSERT_NEAR(FB.M3PositionError_M, 0.0, 0.04, 'Ecart physique-estime nul apres recalage P1');
END_TEST

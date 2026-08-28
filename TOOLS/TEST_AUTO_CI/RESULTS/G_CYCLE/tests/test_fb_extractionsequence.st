SETUP
VAR
    FB : FB_ExtractionSequence;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P04-020 Extraction : mise en service sequence extraction'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE);
    ASSERT_TRUE(FB.Ready, 'Sequence Extraction prete');
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.READY_TO_CLOSE, 'Pret a fermer la benne');

    (* Demande de mouvement de fermeture *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.CLOSING_BUCKET, 'Passe en fermeture benne');

    (* Scan dans CLOSING_BUCKET : demande fermeture active *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    ASSERT_TRUE(FB.BucketCloseRequest, 'Demande fermeture benne active');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'Sequence en cours -> Busy');

    (* Confirmation benne fermee : passe en remontee controlee *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1, BucketIsClosed := TRUE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1, BucketIsClosed := TRUE);
    ASSERT_TRUE(FB.AscentPermit, 'Permis montee actif en remontee controlee');
END_TEST

TEST 'TC-P04-021 : Sequence extraction complete et continue avec maintien constant du joystick operateur'
    // 1. Position au fond, pret a fermer
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -10.0, M2Position_M := -10.0);
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.READY_TO_CLOSE, 'Pret a fermer');

    // 2. Operateur tire le joystick (Scan 1: transition -> CLOSING_BUCKET, Scan 2: execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -10.0, M2Position_M := -10.0,
       MotionRequestActive := TRUE, MotionDirection := 1);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -10.0, M2Position_M := -10.0,
       MotionRequestActive := TRUE, MotionDirection := 1);
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.CLOSING_BUCKET, 'Fermeture benne');
    ASSERT_TRUE(FB.BucketCloseRequest, 'Ordre fermeture actif');

    // 3. Benne fermee confirmee -> Transition directe vers palier de controle (Scan 1: transition, Scan 2: execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -10.0, M2Position_M := -10.0, BucketIsClosed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -10.0, M2Position_M := -10.0, BucketIsClosed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.CONTROL_ASCENT, 'Enchaîne sur palier de controle');
    ASSERT_TRUE(FB.ForceMinSpeedStep, 'Vitesse bridee au palier de controle');
    ASSERT_TRUE(FB.AscentPermit, 'Permis montee actif');

    // 4. Franchissement distance de controle (Scan 1: transition -> NOMINAL_ASCENT, Scan 2: execution)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -7.5, M2Position_M := -7.5, BucketIsClosed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
       ControlAscentDistance_M := 2.0, BottomPositionConfirmed := TRUE,
       PositionsValid := TRUE, M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE,
       M1Position_M := -7.5, M2Position_M := -7.5, BucketIsClosed := TRUE,
       MotionRequestActive := TRUE, MotionDirection := 1);
    ASSERT_EQ(FB.ExtractionState, E_ExtractionSequenceState.NOMINAL_ASCENT, 'Transition vers remontee nominale');
    ASSERT_FALSE(FB.ForceMinSpeedStep, 'Liberation de la vitesse nominale');
    ASSERT_TRUE(FB.AscentPermit, 'Maintien continu du permis de montee');
END_TEST


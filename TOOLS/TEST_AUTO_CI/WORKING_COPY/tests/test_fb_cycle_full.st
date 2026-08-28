SETUP
VAR
    FB : FB_Cycle;
    SampleCount : INT := 0;
    // Positions simulées (HARNESS_STIMULUS) — pilotées scan-par-scan
    M1Pos : REAL := 7.0;
    M2Pos : REAL := 7.0;
END_VAR
END_SETUP

(* =====================================================================
   Harnais dédié WORKING_COPY — cycle complet + robustesse
   SOURCE_TESTÉE = WORKING_COPY/FB_Cycle.st (corrigé F1/F2/F6)
   TC-P04-100 : traversée nominale X0 → X13 (sans X12, réservé)
   NB : chaque transition d'étape nécessite 2 scans (State puis CycleStep).
   ===================================================================== *)

TEST 'TC-P04-100 : Cycle complet nominal X0->X13 sur la copie corrigee'
    (* Pattern chaîné : chaque appel observe l'étape précédente (CycleStep) ET déclenche la
       suivante (State). CycleStep reflète State avec 1 scan de retard. *)

    (* Call 1 : X0 -> X1 (front StartCycle) ; CycleStep=X0 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'X0 initial');

    (* Call 2 : X1 (observe) ; déjà homé -> X2 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'X0->X1 sur StartCycle');

    (* Call 3 : X2 (observe) ; cible P1 atteinte -> X3 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X2_WORK_POS_SELECT, 'X1->X2 (déjà homé)');

    (* Call 4 : X3 (observe) ; benne déjà ouverte -> X4 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X3_OPEN_BUCKET, 'X2->X3 (P1 atteint)');

    (* Call 5 : X4 (observe) ; plongée + contact fond -> X5 (déclenche) *)
    M1Pos := -10.0; M2Pos := -10.0;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'X3->X4 (benne ouverte)');

    (* Call 6 : X5 (observe) ; remontée vers RaiseTargetM -> X6 (déclenche) *)
    M1Pos := -9.5; M2Pos := -9.5;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X5_BOTTOM_CONFIRMED, 'X4->X5 (contact fond)');

    (* Call 7 : X6 (observe) ; fermeture benne -> X7 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X6_CLOSE_BUCKET, 'X5->X6 (remontée)');

    (* Call 8 : X7 (observe) ; remontée contrôle -> X8 (déclenche) *)
    M1Pos := -8.0; M2Pos := -8.0;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X7_CTRL_ASCENT, 'X6->X7 (benne fermée)');

    (* Call 9 : X8 (observe) ; remontée nominale -> X9 (déclenche) *)
    M1Pos := 7.0; M2Pos := 7.0;
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X8_ASCENT_LOADED, 'X7->X8 (remontée contrôle)');

    (* Call 10 : X9 (observe) ; démarre le timer d'égouttage (State reste X9) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X9_DRAIN_PAUSE, 'X8->X9 (limite haute)');

    (* Call 11 : X9 (observe) ; après 5s, DrainingTimer.Q -> X10 (déclenche) *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X9_DRAIN_PAUSE, 'X9 (égouttage)');

    (* Call 12 : X10 (observe) ; translation vers trémie -> X11 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X10_TRANSLATE_DUMP, 'X9->X10 (égouttage)');

    (* Call 13 : X11 (observe) ; manche défléchi, benne PAS encore ouverte -> Open=TRUE (F1) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X11_OPEN_DUMP, 'X10->X11 (trémie)');
    (* 🔒 F1 : en X11, manche défléchi -> BucketCmd.Open doit être TRUE.
       Sur l'original (read-before-write), Open serait FALSE → ce test distingue corrigé/non-corrigé. *)
    ASSERT_TRUE(FB.BucketCmd.Open, 'F1: ouverture benne commandée en X11 (manche défléchi)');

    (* Call 14 : X11 (observe) ; benne ouverte -> X13 (déclenche) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X11_OPEN_DUMP, 'X11 (benne ouverte)');

    (* Call 15 : X13 (observe) ; ouverture relâchée + SampleCount +1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := M1Pos, M2_CablePosM := M2Pos, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X13_DONE_SYNC, 'X11->X13 (ouverture benne, F1 corrigé)');
    ASSERT_TRUE(FB.BucketCmd.Open = FALSE, 'Ouverture benne relâchée en X13');
    ASSERT_EQ(FB.SampleCount, 1, 'SampleCount incrémenté une fois sur X13');
END_TEST

(* =====================================================================
   Tests de robustesse (défauts / reprises)
   ===================================================================== *)

TEST 'TC-P04-101 : Defaut synchro mi-cycle -> STABILIZING -> reprise complete'
    (* X0 -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'X1 atteint');

    (* Injection défaut synchro -> STABILIZING *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := TRUE, WinchSyncDeltaM := 0.6,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.STABILIZING, 'Défaut synchro -> STABILIZING');
    ASSERT_TRUE(FB.Fault.Error, 'Fault.Error actif');

    (* Cause disparue + Reset -> X0 *)
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Reset -> X0');

    (* Redémarrage -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'Reprise après défaut -> X1');
END_TEST

TEST 'TC-P04-102 : Bascule MAINT mi-cycle -> retour -> reprise consciente exigee (F6)'
    (* Pattern chaîné : atteindre X4 (étape stable, plongée) avant la bascule de mode. *)
    (* Call 1 : X0 -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : X1 (observe) ; déjà homé -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : X2 (observe) ; P1 atteint -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : X3 (observe) ; benne déjà ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : X4 (observe) — stabilisation *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'X4 atteint (plongée)');

    (* Bascule MAINT (Enable=FALSE) -> étape mémorisée *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.Ready, 'Ready retombe hors Semi-Auto');

    (* Retour SEMI_AUTO avec manche défléchi : PAS de mouvement spontané (F6) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Étape X4 conservée');
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'PAS de mouvement spontané (F6)');
    ASSERT_FALSE(FB.WinchM2Cmd.StartStop, 'PAS de mouvement M2 (F6)');

    (* Reprise consciente : StartCycle exigé -> X5 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 8 : X5 (observe) — stabilisation après reprise *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X5_BOTTOM_CONFIRMED, 'Reprise consciente -> X5');
END_TEST

TEST 'TC-P04-103 : Relachement manche en X4 stoppe les commandes sans perdre l etape'
    (* Pattern chaîné : atteindre X4 (plongée) *)
    (* Call 1 : X0 -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : X1 (observe) ; déjà homé -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : X2 (observe) ; P1 atteint -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : X3 (observe) ; benne déjà ouverte -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : X4 (observe) — stabilisation *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'X4 atteint');

    (* Relâchement manche : CycleMotionPermit=FALSE *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := FALSE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_FALSE(FB.WinchM1Cmd.StartStop, 'M1 coupé sur relâchement manche');
    ASSERT_FALSE(FB.WinchM2Cmd.StartStop, 'M2 coupé sur relâchement manche');
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X4_DESCEND_OPEN, 'Étape X4 conservée');
END_TEST

TEST 'TC-P04-104 : AbortCycle en cours -> X0 et WaitingResume remis a FALSE'
    (* X0 -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X1_HOMING, 'X1 atteint');

    (* Abort *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, AbortCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X0_PREPARATION, 'Abort -> X0');
END_TEST

TEST 'TC-P04-105 : SampleCount +1 strict sur X13 multi-scan (F2)'
    (* Atteindre X13 (pattern chaîné) puis rester 2 scans en X13.
       Sur l'original, SampleCount augmenterait à CHAQUE scan en X13 (2 au lieu de 1).
       Sur la copie corrigée (front SampleCountDone), il reste 1. *)
    (* Call 1 : X0 -> X1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := TRUE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 2 : X1 -> X2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := FALSE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 3 : X2 -> X3 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 4 : X3 -> X4 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 5 : X4 -> X5 (contact fond) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -10.0, M2_CablePosM := -10.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := TRUE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 6 : X5 -> X6 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.5, M2_CablePosM := -9.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := FALSE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* Call 7 : X6 -> X7 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -9.5, M2_CablePosM := -9.5, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 8 : X7 -> X8 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := -8.0, M2_CablePosM := -8.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 9 : X8 -> X9 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 10 : X9 (démarre timer) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 11 : X9 -> X10 (égouttage 5s) *)
    ADVANCE_TIME(5000000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := TRUE, Translation_At_Tremie := FALSE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 12 : X10 -> X11 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := FALSE, Benne_IsClosed := TRUE, Benne_IsRoughlyClosed := TRUE,
       SampleCount := SampleCount);
    (* Call 13 : X11 -> X13 (ouverture benne) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X11_OPEN_DUMP, 'X11 atteint (call 13)');
    ASSERT_EQ(FB.SampleCount, 0, 'SampleCount = 0 avant entree X13 (precondition F2)');
    (* Call 14 : X13 (observe) — SampleCount +1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    (* 🔒 Émulation copy-out VAR_IN_OUT : le codegen STruCpp génère le IN_OUT en copy-in SEUL
       (pas de copy-out), alors qu'en CODESYS réel le IN_OUT est passé par référence.
       Sans resynchronisation, le copy-in du scan suivant ré-écrase le compteur incrémenté
       avec la valeur locale périmée (artefact harnais, pas un bug FB). *)
    SampleCount := FB.SampleCount;
    ASSERT_TRUE(FB.CycleStep = E_CycleStep.X13_DONE_SYNC, 'X13 atteint');
    ASSERT_EQ(FB.SampleCount, 1, 'SampleCount = 1 après 1er scan en X13');

    (* Call 15 : X13 (2e scan) — SampleCount ne doit PAS augmenter (F2) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_EQ(FB.SampleCount, 1, 'F2: SampleCount reste 1 au 2e scan en X13 (front)');
    SampleCount := FB.SampleCount; (* copy-out émulé avant le scan suivant (cf. ci-dessus) *)

    (* Call 16 : X13 (3e scan) — SampleCount doit rester 1 (F2) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.SEMI_AUTO,
       DeadmanArmed := TRUE, CycleMotionPermit := TRUE, HeartbeatIhmOk := TRUE,
       StartCycle := FALSE, SelTarget := 3, SetDepthM := -10.0, SetOffsetM := 0.0,
       LimitLegalDepthM := -10.5, CableLimitM1AscentM := 7.0,
       SpeedMismatchThresholdMps := 0.0, SpeedMismatchTimeout := T#0ms,
       HomedM1 := TRUE, HomedM2 := TRUE, TopPositionSensor := TRUE, HomingRequest := FALSE,
       M1_CablePosM := 7.0, M2_CablePosM := 7.0, M1_MeasuredSpeedMps := 0.0, M2_MeasuredSpeedMps := 0.0,
       KoboldContactFond := FALSE, WinchSyncError := FALSE, WinchSyncDeltaM := 0.0,
       Translation_At_P1 := FALSE, Translation_At_Tremie := TRUE, Translation_At_Maintenance := FALSE,
       Translation_Busy := FALSE, Translation_Done := TRUE,
       Benne_Busy := FALSE, Benne_Done := TRUE, Benne_IsOpen := TRUE, Benne_IsClosed := FALSE, Benne_IsRoughlyClosed := FALSE,
       SampleCount := SampleCount);
    ASSERT_EQ(FB.SampleCount, 1, 'F2: SampleCount reste 1 au 3e scan en X13 (front)');
END_TEST

(* =======================================================================
   T255-D — Reproduction exploratoire, PRODUCTEUR : FB_Safety_Winch
   -----------------------------------------------------------------------
   HORS CI OFFICIEL (dossier _TROUBLESHOOTING jetable, skill troubleshooting
   section 4ter).

   But : trancher par EXECUTION la semantique de la vue publiee par le socle de
   defaut, sur la seule cause « limite basse cable atteinte » (instCauses[6],
   bit6 = 16#0040, Latching := FALSE — FB_Safety_Winch.st:318-325).

   Question tranchee : une limite basse cable SEULE allume-t-elle Fault.Error
   (vue LIVE) sans aucun defaut latche ?

     FB_FaultCore.st:49-57   Fault.ErrorId := bitfield des Causes[i].Active
                             Fault.Error := (Fault.ErrorId <> 0)   <- vue LIVE
     FB_FaultCore.st:60-81   Latched / LatchedId = vue LATCHEE (Latching=TRUE seulement)

   Attendu : Error = TRUE, ErrorId = 16#0040, Latched = FALSE.
   ======================================================================= *)

SETUP
VAR
    SafetyW : FB_Safety_Winch;
END_VAR
END_SETUP

TEST 'T255D-PROD-1 limite basse cable seule : Fault.Error (vue LIVE) est allume'
    SafetyW(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1,
            SyncEnable := FALSE, CrossCheckEnable := FALSE,
            PowerContactorEngaged := TRUE,
            JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
            EncoderAvailable := TRUE,
            ThermalFeedback := FALSE, BrakeThermalFeedback := FALSE,
            SlackCableDetected := FALSE, PhaseRotationOk := TRUE,
            TopPositionSensor := TRUE,
            FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
            JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
            OtherWinchInhibited := FALSE,
            InReferencingMode := FALSE,
            CablePosM := -50.1, CfgCableLimitDescentM := -50.0,
            LimitLegalReached := FALSE, Homed := TRUE, HomingSuspect := FALSE, TopLimitM := 7.5,
            ReqAscent := FALSE, ReqDescend := FALSE, MovementCommanded := FALSE,
            ExpectedOtherWinchPosM := -50.1,
            MeasuredSpeedValid := TRUE, MeasuredSpeedMps := 0.0, MeasuredSpeedSignedMps := 0.0,
            SpeedBandMaxMps := 3.0,
            BypassGlobal := FALSE, BypassSafety := FALSE, BypassProcess := FALSE,
            BypassCableLimitSwitch := FALSE, BypassTopLimitSwitch := FALSE,
            BypassMecaA := FALSE, BypassMecaB := FALSE, BypassMecaC := FALSE,
            BypassMecaD := FALSE, BypassMecaE := FALSE, BypassOperatorComm := FALSE,
            BypassPhaseRotation := FALSE, BypassBrakeThermal := FALSE,
            BypassMotorThermal := FALSE);

    ASSERT_TRUE(SafetyW.Fault.Error,
                '[T255D-PROD-1] une limite basse cable seule doit allumer la vue LIVE Fault.Error');
END_TEST

TEST 'T255D-PROD-2 limite basse cable seule : ErrorId = 16#0040 et AUCUN defaut latche'
    SafetyW(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1,
            SyncEnable := FALSE, CrossCheckEnable := FALSE,
            PowerContactorEngaged := TRUE,
            JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
            EncoderAvailable := TRUE,
            ThermalFeedback := FALSE, BrakeThermalFeedback := FALSE,
            SlackCableDetected := FALSE, PhaseRotationOk := TRUE,
            TopPositionSensor := TRUE,
            FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
            JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, BenneBusy := FALSE,
            OtherWinchInhibited := FALSE,
            InReferencingMode := FALSE,
            CablePosM := -50.1, CfgCableLimitDescentM := -50.0,
            LimitLegalReached := FALSE, Homed := TRUE, HomingSuspect := FALSE, TopLimitM := 7.5,
            ReqAscent := FALSE, ReqDescend := FALSE, MovementCommanded := FALSE,
            ExpectedOtherWinchPosM := -50.1,
            MeasuredSpeedValid := TRUE, MeasuredSpeedMps := 0.0, MeasuredSpeedSignedMps := 0.0,
            SpeedBandMaxMps := 3.0,
            BypassGlobal := FALSE, BypassSafety := FALSE, BypassProcess := FALSE,
            BypassCableLimitSwitch := FALSE, BypassTopLimitSwitch := FALSE,
            BypassMecaA := FALSE, BypassMecaB := FALSE, BypassMecaC := FALSE,
            BypassMecaD := FALSE, BypassMecaE := FALSE, BypassOperatorComm := FALSE,
            BypassPhaseRotation := FALSE, BypassBrakeThermal := FALSE,
            BypassMotorThermal := FALSE);

    ASSERT_EQ(SafetyW.Fault.ErrorId, 16#0040,
              '[T255D-PROD-2] ErrorId attendu = bit6 seul (limite basse cable)');
    ASSERT_FALSE(SafetyW.Fault.Latched,
                 '[T255D-PROD-2] aucun defaut latche ne doit etre present : Latched reste FALSE');
END_TEST


IF NOT Enable OR NOT EmergencyStopOk THEN
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    SpeedStep(Enable := FALSE, SpeedRefPct := 0.0, Table := SpeedStepTable, HystMargin := SpeedStepHystMargin);
    StepNumber := SpeedStep.StepNumber;
    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeCmd := Brake.BrakeCmd;
    BrakeContactorCheck := Brake.ContactorCheck;
    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    SpeedRamp(Target := 0.0, AccelRate := RampAccelRate, DecelRate := RampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);

ResetEdge(CLK := Reset);

DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

// 🆕 Mou de câble (ForbidDescent) et Fin de course haut (ForbidAscent) intégrés à une VRAIE
// décélération rapide (comme SafeStop) :
// - ForbidDescent est INHIBÉ si CommandedDirection = 1 (montée libre pour reprendre le mou)
// - ForbidAscent est INHIBÉ si CommandedDirection = -1 (descente libre pour dégager le câble)
EffectiveSafeStop := SafeStop 
                     OR (ForbidDescent AND (CommandedDirection <> 1))
                     OR (ForbidAscent AND (CommandedDirection <> -1));

RampTargetPct := 0.0;
IF NOT EffectiveSafeStop AND StartStop AND NOT DirectionChangePending THEN
    RampTargetPct := ABS(SpeedRefPct);
    
    // 🆕 RALENTISSEMENT AUTOMATIQUE SUR BORDURES (si référencé)
    // Permet d'approcher les fins de course / limites en vitesse lente de façon progressive
    IF Homed THEN
        // En montée (engagement ou mouvement actif), ralentit à l'approche de la limite haute
        IF ((CommandedDirection = 1) OR (Direction = 1)) AND (CablePosM >= (TopLimitM - SlowdownDistanceM)) THEN
            RampTargetPct := MIN(RampTargetPct, SlowSpeedPct);
        END_IF;
        
        // En descente (engagement ou mouvement actif), ralentit à l'approche de la limite basse
        IF ((CommandedDirection = -1) OR (Direction = -1)) AND (CablePosM <= (BottomLimitM + SlowdownDistanceM)) THEN
            RampTargetPct := MIN(RampTargetPct, SlowSpeedPct);
        END_IF;
    END_IF;
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := RampAccelRate,
          DecelRate := SEL(EffectiveSafeStop, RampDecelNormalRate, RampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

IF Direction <> CommandedDirection THEN
    IF CommandedDirection = 0 AND Direction <> 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ELSIF ABS(SpeedRamp.Current) < 0.1 THEN
        DirectionChangeDelay(IN := TRUE, PT := DirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
END_IF;

// 🆕 Plafond palier descente (couple, pas vitesse) : 5 = inchangé en montée/neutre,
// MaxStepDescente uniquement si CommandedDirection = -1 (Rev)
SpeedStep(Enable := (ABS(SpeedRamp.Current) > 0.1), SpeedRefPct := ABS(SpeedRamp.Current),
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin,
          MaxStepNumber := SEL(CommandedDirection = -1, 5, MaxStepDescente));
StepNumber := SpeedStep.StepNumber;
Contactor1 := SpeedStep.Contactor1;
Contactor2 := SpeedStep.Contactor2;
Contactor3 := SpeedStep.Contactor3;
Contactor4 := SpeedStep.Contactor4;

RelayFwd := (CommandedDirection = 1) AND (StepNumber > 0);
RelayRev := (CommandedDirection = -1) AND (StepNumber > 0);

IF ForbidDescent THEN
    RelayRev := FALSE;
END_IF;

IF ForbidAscent THEN
    RelayFwd := FALSE;
END_IF;

Brake(Enable := TRUE, Reset := Reset, MovementRequested := (RelayFwd OR RelayRev),
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

FwdContactorCheck.Command := RelayFwd;
FwdContactorCheck.Feedback := ContactorFeedbackFwd;
TonFwdFeedback(IN := (RelayFwd <> ContactorFeedbackFwd), PT := ContactorFeedbackTimeout);
IF TonFwdFeedback.Q THEN
    FwdContactorCheck.StuckClosed := (NOT RelayFwd AND ContactorFeedbackFwd);
    FwdContactorCheck.StuckOpen   := (RelayFwd AND NOT ContactorFeedbackFwd);
ELSIF ResetEdge.Q THEN
    FwdContactorCheck.StuckClosed := FALSE; FwdContactorCheck.StuckOpen := FALSE;
END_IF;

RevContactorCheck.Command := RelayRev;
RevContactorCheck.Feedback := ContactorFeedbackRev;
TonRevFeedback(IN := (RelayRev <> ContactorFeedbackRev), PT := ContactorFeedbackTimeout);
IF TonRevFeedback.Q THEN
    RevContactorCheck.StuckClosed := (NOT RelayRev AND ContactorFeedbackRev);
    RevContactorCheck.StuckOpen   := (RelayRev AND NOT ContactorFeedbackRev);
ELSIF ResetEdge.Q THEN
    RevContactorCheck.StuckClosed := FALSE; RevContactorCheck.StuckOpen := FALSE;
END_IF;

IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔴 BYPASS TEST BANC (2026-07-03vicies, demande utilisateur) — sans contacteurs réels câblés/
// cohérents en essai, StuckClosed/StuckOpen se déclenche à tort et bloque RelayFwd/RelayRev
// (voir Error plus bas). TOUJOURS FALSE en exploitation réelle.
IF NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN
    IF FwdContactorCheck.StuckClosed OR FwdContactorCheck.StuckOpen THEN
        ErrorId := ErrorId OR 16#0002;
    ELSIF ResetEdge.Q THEN
        ErrorId := ErrorId AND 16#FFFD;
    END_IF;

    IF RevContactorCheck.StuckClosed OR RevContactorCheck.StuckOpen THEN
        ErrorId := ErrorId OR 16#0004;
    ELSIF ResetEdge.Q THEN
        ErrorId := ErrorId AND 16#FFFB;
    END_IF;
ELSE
    ErrorId := ErrorId AND 16#FFF9;   // Bypass actif : efface/maintient à 0 les bits 1/2
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

IF (NOT StartStop OR EffectiveSafeStop OR DirectionChangePending) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;

IF Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE;
END_IF;

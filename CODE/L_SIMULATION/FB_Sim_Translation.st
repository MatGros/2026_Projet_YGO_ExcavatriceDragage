(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Modele dynamique M3 confine au SimBench. *)
FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable : BOOL;
    ReqTremie : BOOL;
    ReqMaintenance : BOOL;
    SpeedTgt_Pct : REAL;
    FullTravelTimeS : REAL := 8.0;
    BrakeReleaseCmd : BOOL := TRUE;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 20.0;
    DriveTimeConstantS : REAL := 0.15;
    BrakeOpenDelayS : REAL := 0.10;
    BrakeCloseDelayS : REAL := 0.09;
    BrakeContactDelayS : REAL := 0.01;
    (* FAUTE EXPLICITE frein M3 — defaut FALSE : reproduit le defaut terrain « frein ferme
       alors que le variateur retourne encore 10,00 Hz » (trace 2026-09-04, 26,437 s,
       State.ErrorId=64). La garde nominale 0,5 Hz du frein n'est pas modifiee. *)
    BrakeFaultCloseWhileRunning : BOOL := FALSE;
    BrakeFaultCloseDelay_S : REAL := 0.0;
    SuspendedLoadLength_M : REAL := 1.5;
    SuspendedLoadDamping : REAL := 0.35;
    LoadReactionGain_Mps2 : REAL := 0.20;
    LoadFrequencyDroopGain_Hz : REAL := 0.50;
    SensorJitterAmplitude_M : REAL := 0.01;
    SensorStabilizationS : REAL := 1.0;
    SensorElectricalDelayS : REAL := 0.01;
    SensorIntermittenceActive : BOOL := FALSE;
    SensorLoadAngleTriggerRad : REAL := 0.01;
    SensorScenarioSeed : UDINT := 3001;
    SensorHysteresis_M : REAL := 0.02;
    SensorIntermittencePeriodS : REAL := 0.12;
END_VAR
VAR_OUTPUT
    PosTremie : BOOL;
    PosPV : BOOL;
    PosP2 : BOOL;
    PosP1 : BOOL;
    PosMaintenance : BOOL;
    FrequencyCmd_Hz : REAL;
    ElectricalFrequency_Hz : REAL;
    ActualFrequency_Hz : REAL;
    BrakeCoilEnergized : BOOL;
    BrakeMechanicallyOpen : BOOL;
    BrakeContactOpen : BOOL;
    BrakeFaultCloseActive : BOOL;
    PositionTrue_M : REAL;
    VelocityTrue_Mps : REAL;
    LoadAngle_Rad : REAL;
    SensorPosition_M : REAL;
    SensorTransitionCount : UDINT;
    HardStopTremieActive : BOOL;
    HardStopMaintenanceActive : BOOL;
END_VAR
VAR
    instCycleTime : FB_CycleTime;
    Initialized : BOOL;
    DirectionSign : REAL;
    FrequencyTarget_Hz : REAL;
    CycleTimeS : REAL;
    SpeedAt40Hz_Mps : REAL;
    VelocityTarget_Mps : REAL;
    CartAcceleration_Mps2 : REAL;
    PreviousVelocity_Mps : REAL;
    PositionCandidate_M : REAL;
    SensorNoiseState : REAL := 0.371;
    SensorNoise_M : REAL;
    instSensorTremie : FB_Sim_PositionSensor;
    instSensorPV : FB_Sim_PositionSensor;
    instSensorP2 : FB_Sim_PositionSensor;
    instSensorP1 : FB_Sim_PositionSensor;
    instSensorMaintenance : FB_Sim_PositionSensor;
    instDrive : FB_Sim_TranslationDrive;
    instBrake : FB_Sim_TranslationBrake;
    instSuspendedLoad : FB_Sim_SuspendedLoad;
END_VAR
VAR CONSTANT
    CST_PositionAtTremie : REAL := 0.0;
    (* Meme principe a Tremie : le seuil DI est legerement avant la butee afin
       que l'hysteresis puisse commuter sans depassement numerique de course. *)
    CST_PositionAtTremieSensor_M : REAL := 0.05;
    CST_PositionAtPV : REAL := 5.0;
    CST_PositionAtP2 : REAL := 15.0;
    CST_PositionAtP1 : REAL := 20.0;
    CST_PositionAtMaintenance : REAL := 30.0;
    (* Le capteur cumulatif Maintenance doit commuter avant la butee mecanique,
       sinon un modele borne a 30 m ne peut jamais produire le mot 00000. Cette
       position est SYNTHETIQUE en attente de la mesure de la came reelle. *)
    CST_PositionAtMaintenanceSensor_M : REAL := 29.95;
    CST_NominalFrequency_Hz : REAL := 40.0;
    CST_MinTimeS : REAL := 0.001;
END_VAR

instCycleTime(DefaultValueS := 0.010);
(* Le modele mono-pas suit le temps de cycle reel jusqu'a 100 ms. Cette borne
   evite de ralentir artificiellement la dynamique lorsque la trace est executee
   dans VISU_TASK (environ 100 ms), tout en restant stable pour le pendule reduit.
   Au-dela, FB_CycleTime fournit deja son temps de secours et aucun saut aberrant
   n'est accepte. La qualification des delais sub-100 ms exige toutefois une tache
   de trace plus rapide que 100 ms. *)
CycleTimeS := LIMIT(0.001, instCycleTime.CycleTimeS, 0.100);

IF NOT Enable THEN
    Initialized := FALSE;
    instDrive(Enable := FALSE);
    instBrake(Enable := FALSE);
    instSuspendedLoad(Enable := FALSE);
    FrequencyCmd_Hz := 0.0;
    ElectricalFrequency_Hz := 0.0;
    ActualFrequency_Hz := 0.0;
    BrakeMechanicallyOpen := FALSE;
    BrakeContactOpen := FALSE;
    BrakeCoilEnergized := FALSE;
    BrakeFaultCloseActive := FALSE;
    PositionTrue_M := CST_PositionAtP1;
    VelocityTrue_Mps := 0.0;
    PreviousVelocity_Mps := 0.0;
    LoadAngle_Rad := 0.0;
    SensorTransitionCount := 0;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    (* Repli deterministe compatible avec le mot thermometre P1 = 00011. *)
    PosTremie := FALSE;
    PosPV := FALSE;
    PosP2 := FALSE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
    instSensorTremie(Enable := FALSE);
    instSensorPV(Enable := FALSE);
    instSensorP2(Enable := FALSE);
    instSensorP1(Enable := FALSE);
    instSensorMaintenance(Enable := FALSE);
    RETURN;
ELSIF NOT Initialized THEN
    Initialized := TRUE;
    PositionTrue_M := CST_PositionAtP1;
END_IF;

IF Enable THEN
    DirectionSign := 0.0;
    IF ReqTremie AND NOT ReqMaintenance THEN
        DirectionSign := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        DirectionSign := 1.0;
    END_IF;

    FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * 0.4, CST_NominalFrequency_Hz);
    IF DirectionSign = 0.0 THEN
        FrequencyTarget_Hz := 0.0;
    END_IF;
    instDrive(Enable := TRUE, FrequencyTgt_Hz := FrequencyTarget_Hz,
        AccelRate_HzPerS := AccelRate_HzPerS, DecelRate_HzPerS := DecelRate_HzPerS,
        TimeConstant_S := DriveTimeConstantS,
        LoadAngularVelocity_RadPerS := instSuspendedLoad.AngularVelocity_RadPerS,
        LoadFrequencyDroopGain_Hz := LoadFrequencyDroopGain_Hz, CycleTime_S := CycleTimeS);
    FrequencyCmd_Hz := instDrive.FrequencyCmd_Hz;
    ElectricalFrequency_Hz := instDrive.ElectricalFrequency_Hz;
    ActualFrequency_Hz := instDrive.ActualFrequency_Hz;
    instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
        ActualFrequency_Hz := ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
        CloseDelay_S := BrakeCloseDelayS, ContactDelay_S := BrakeContactDelayS,
        CycleTime_S := CycleTimeS,
        FaultCloseWhileRunning := BrakeFaultCloseWhileRunning,
        FaultCloseDelay_S := BrakeFaultCloseDelay_S);
    BrakeCoilEnergized := instBrake.CoilEnergized;
    BrakeMechanicallyOpen := instBrake.MechanicallyOpen;
    BrakeContactOpen := instBrake.ContactOpen;
    BrakeFaultCloseActive := instBrake.FaultCloseActive;

    PreviousVelocity_Mps := VelocityTrue_Mps;
    IF (FullTravelTimeS > CST_MinTimeS) AND BrakeMechanicallyOpen THEN
        SpeedAt40Hz_Mps := CST_PositionAtMaintenance / FullTravelTimeS;
        VelocityTarget_Mps := DirectionSign * SpeedAt40Hz_Mps * ActualFrequency_Hz / CST_NominalFrequency_Hz;
    ELSE
        VelocityTarget_Mps := 0.0;
    END_IF;
    VelocityTrue_Mps := VelocityTrue_Mps + instDrive.ResponseAlpha * (VelocityTarget_Mps - VelocityTrue_Mps);
    IF NOT BrakeMechanicallyOpen THEN
        VelocityTrue_Mps := 0.0;
    END_IF;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
    IF PositionCandidate_M < CST_PositionAtTremie THEN
        PositionTrue_M := CST_PositionAtTremie;
        VelocityTrue_Mps := 0.0;
        HardStopTremieActive := TRUE;
    ELSIF PositionCandidate_M > CST_PositionAtMaintenance THEN
        PositionTrue_M := CST_PositionAtMaintenance;
        VelocityTrue_Mps := 0.0;
        HardStopMaintenanceActive := TRUE;
    END_IF;
    CartAcceleration_Mps2 := (VelocityTrue_Mps - PreviousVelocity_Mps) / CycleTimeS;
    instSuspendedLoad(Enable := TRUE, BrakeMechanicallyOpen := BrakeMechanicallyOpen,
        CartAcceleration_Mps2 := CartAcceleration_Mps2, Length_M := SuspendedLoadLength_M,
        Damping := SuspendedLoadDamping, ReactionGain_Mps2 := LoadReactionGain_Mps2,
        CycleTime_S := CycleTimeS);
    LoadAngle_Rad := instSuspendedLoad.Angle_Rad;
    IF HardStopTremieActive OR HardStopMaintenanceActive THEN
        VelocityTrue_Mps := 0.0;
    ELSE
        VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
        PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
        IF PositionCandidate_M < CST_PositionAtTremie THEN
            PositionTrue_M := CST_PositionAtTremie;
            VelocityTrue_Mps := 0.0;
            HardStopTremieActive := TRUE;
        ELSIF PositionCandidate_M > CST_PositionAtMaintenance THEN
            PositionTrue_M := CST_PositionAtMaintenance;
            VelocityTrue_Mps := 0.0;
            HardStopMaintenanceActive := TRUE;
        ELSE
            PositionTrue_M := PositionCandidate_M;
        END_IF;
    END_IF;
END_IF;

IF Enable AND (ABS(LoadAngle_Rad) > 0.0001) THEN
    SensorNoiseState := 3.91 * SensorNoiseState * (1.0 - SensorNoiseState);
    SensorNoise_M := (2.0 * SensorNoiseState - 1.0) * SensorJitterAmplitude_M;
ELSE
    SensorNoise_M := 0.0;
END_IF;
(* Les capteurs sont fixes au rail et observent le chariot. Le balancier agit
   seulement par la reaction mecanique sur PositionTrue_M et conditionne un
   episode electrique ; aucune deflexion de godet n'est injectee directement. *)
SensorPosition_M := PositionTrue_M + SensorNoise_M;
(* Les capteurs M3 sont volontairement cumulatifs : 11111 -> 00000. Chaque
   brique garde son hysteresis et son episode propres ; aucun timer partage ne
   peut masquer un front d'un autre capteur. *)
instSensorTremie(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtTremieSensor_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 11,
    CycleTimeS := CycleTimeS);
instSensorPV(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtPV, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 23,
    CycleTimeS := CycleTimeS);
instSensorP2(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtP2, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 37,
    CycleTimeS := CycleTimeS);
instSensorP1(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtP1, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 53,
    CycleTimeS := CycleTimeS);
instSensorMaintenance(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtMaintenanceSensor_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 71,
    CycleTimeS := CycleTimeS);

PosTremie := instSensorTremie.ElectricalOutput;
PosPV := instSensorPV.ElectricalOutput;
PosP2 := instSensorP2.ElectricalOutput;
PosP1 := instSensorP1.ElectricalOutput;
PosMaintenance := instSensorMaintenance.ElectricalOutput;
SensorTransitionCount := instSensorTremie.TransitionCount + instSensorPV.TransitionCount
    + instSensorP2.TransitionCount + instSensorP1.TransitionCount
    + instSensorMaintenance.TransitionCount;

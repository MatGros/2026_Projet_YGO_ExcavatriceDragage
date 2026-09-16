(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Capteur de position cumulatif avec hysteresis et episode intermittent rejouable.
   Cette brique ne connait ni le mouvement ni la logique M3 : elle transforme uniquement
   une position mecanique vraie en DI. *)
FUNCTION_BLOCK PUBLIC FB_Sim_PositionSensor
VAR_INPUT
    Enable : BOOL;
    Position_M : REAL;
    Threshold_M : REAL;
    Hysteresis_M : REAL := 0.02;
    ActiveBelowThreshold : BOOL := TRUE;
    ElectricalDelayS : REAL := 0.0;
    IntermittenceActive : BOOL := FALSE;
    IntermittenceDurationS : REAL := 1.0;
    IntermittencePeriodS : REAL := 0.12;
    ScenarioSeed : UDINT := 1;
    CycleTimeS : REAL := 0.01;
END_VAR
VAR_OUTPUT
    RawDetected : BOOL;
    ElectricalOutput : BOOL;
    EpisodeActive : BOOL;
    TransitionCount : UDINT;
    EpisodeTogglePeriodS : REAL;
END_VAR
VAR
    Initialized : BOOL;
    PreviousRawDetected : BOOL;
    EpisodeTarget : BOOL;
    DelayTimerS : REAL;
    EpisodeTimerS : REAL;
    ToggleTimerS : REAL;
    RandomState : UDINT;
END_VAR

IF NOT Enable THEN
    Initialized := FALSE;
    RawDetected := FALSE;
    ElectricalOutput := FALSE;
    PreviousRawDetected := FALSE;
    EpisodeActive := FALSE;
    DelayTimerS := 0.0;
    EpisodeTimerS := 0.0;
    ToggleTimerS := 0.0;
    TransitionCount := 0;
    EpisodeTogglePeriodS := 0.0;
    RETURN;
END_IF;

(* Hysteresis sur une frontiere cumulative : les cinq DI restent compatibles avec
   le mot thermometre du decodeur M3, contrairement a cinq fenetres independantes. *)
IF NOT Initialized THEN
    IF ActiveBelowThreshold THEN
        RawDetected := Position_M <= Threshold_M;
    ELSE
        RawDetected := Position_M >= Threshold_M;
    END_IF;
    ElectricalOutput := RawDetected;
    PreviousRawDetected := RawDetected;
    RandomState := ScenarioSeed MOD 1000000;
    IF RandomState = 0 THEN
        RandomState := 1;
    END_IF;
    EpisodeTogglePeriodS := MAX(0.01, IntermittencePeriodS);
    Initialized := TRUE;
    RETURN;
END_IF;

IF ActiveBelowThreshold THEN
    IF RawDetected THEN
        RawDetected := Position_M <= (Threshold_M + MAX(0.0, Hysteresis_M));
    ELSE
        RawDetected := Position_M <= (Threshold_M - MAX(0.0, Hysteresis_M));
    END_IF;
ELSE
    IF RawDetected THEN
        RawDetected := Position_M >= (Threshold_M - MAX(0.0, Hysteresis_M));
    ELSE
        RawDetected := Position_M >= (Threshold_M + MAX(0.0, Hysteresis_M));
    END_IF;
END_IF;

(* Un episode est declenche par un franchissement mecanique, pas par une de ses
   propres bascules electriques. Les fronts restent donc bornes et reproductibles. *)
IF RawDetected <> PreviousRawDetected THEN
    PreviousRawDetected := RawDetected;
    EpisodeTarget := RawDetected;
    (* Une bascule mecanique pendant l'episode modifie seulement la cible finale.
       Elle ne remet jamais son chronometre a zero : l'episode reste borne. *)
    IF NOT EpisodeActive THEN
        DelayTimerS := 0.0;
        EpisodeTimerS := 0.0;
        ToggleTimerS := 0.0;
        (* Tirage unique par episode : reproductible pour une graine et sans bruit
           blanc scan-par-scan. La periode varie de 70 % a 130 % du nominal. *)
        RandomState := RandomState + 7919;
        IF RandomState >= 1000000 THEN
            RandomState := RandomState - 1000000;
        END_IF;
        EpisodeTogglePeriodS := MAX(0.01, IntermittencePeriodS
            * (0.7 + UDINT_TO_REAL(RandomState MOD 6000) / 10000.0));
        EpisodeActive := IntermittenceActive AND (IntermittenceDurationS > 0.0);
    END_IF;
END_IF;

IF EpisodeActive THEN
    EpisodeTimerS := EpisodeTimerS + CycleTimeS;
    ToggleTimerS := ToggleTimerS + CycleTimeS;
    IF ToggleTimerS >= EpisodeTogglePeriodS THEN
        ElectricalOutput := NOT ElectricalOutput;
        ToggleTimerS := 0.0;
        TransitionCount := TransitionCount + 1;
    END_IF;
    IF EpisodeTimerS >= IntermittenceDurationS THEN
        EpisodeActive := FALSE;
        IF ElectricalOutput <> EpisodeTarget THEN
            ElectricalOutput := EpisodeTarget;
            TransitionCount := TransitionCount + 1;
        END_IF;
        DelayTimerS := 0.0;
    END_IF;
ELSIF ElectricalOutput <> RawDetected THEN
    DelayTimerS := DelayTimerS + CycleTimeS;
    IF DelayTimerS >= MAX(0.0, ElectricalDelayS) THEN
        ElectricalOutput := RawDetected;
        DelayTimerS := 0.0;
        TransitionCount := TransitionCount + 1;
    END_IF;
ELSE
    DelayTimerS := 0.0;
END_IF;

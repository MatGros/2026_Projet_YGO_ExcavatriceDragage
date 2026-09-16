(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Dynamique reduite du variateur M3, sans commande metier. *)
FUNCTION_BLOCK PUBLIC FB_Sim_TranslationDrive
VAR_INPUT
    Enable : BOOL;
    FrequencyTgt_Hz : REAL;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 20.0;
    TimeConstant_S : REAL := 0.15;
    LoadAngularVelocity_RadPerS : REAL;
    LoadFrequencyDroopGain_Hz : REAL := 0.50;
    CycleTime_S : REAL := 0.01;
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    FrequencyCmd_Hz : REAL;
    ElectricalFrequency_Hz : REAL;
    ActualFrequency_Hz : REAL;
    ResponseAlpha : REAL;
END_VAR
VAR
    FrequencyDelta_Hz : REAL;
    FrequencyStep_Hz : REAL;
END_VAR
VAR CONSTANT
    CST_MinTime_S : REAL := 0.001;
    CST_MaxFrequency_Hz : REAL := 40.0;
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    FrequencyCmd_Hz := 0.0;
    ElectricalFrequency_Hz := 0.0;
    ActualFrequency_Hz := 0.0;
    ResponseAlpha := 0.0;
    RETURN;
END_IF;

FrequencyDelta_Hz := LIMIT(0.0, FrequencyTgt_Hz, CST_MaxFrequency_Hz) - FrequencyCmd_Hz;
IF FrequencyDelta_Hz >= 0.0 THEN
    FrequencyStep_Hz := MAX(0.0, AccelRate_HzPerS) * CycleTime_S;
ELSE
    FrequencyStep_Hz := MAX(0.0, DecelRate_HzPerS) * CycleTime_S;
END_IF;
FrequencyCmd_Hz := FrequencyCmd_Hz + LIMIT(-FrequencyStep_Hz, FrequencyDelta_Hz, FrequencyStep_Hz);
IF TimeConstant_S > CST_MinTime_S THEN
    ResponseAlpha := CycleTime_S / (TimeConstant_S + CycleTime_S);
ELSE
    ResponseAlpha := 1.0;
END_IF;
ElectricalFrequency_Hz := ElectricalFrequency_Hz
    + ResponseAlpha * (FrequencyCmd_Hz - ElectricalFrequency_Hz);
ActualFrequency_Hz := MAX(0.0, ElectricalFrequency_Hz
    - MAX(0.0, LoadFrequencyDroopGain_Hz) * ABS(LoadAngularVelocity_RadPerS));
IF ActualFrequency_Hz < 0.005 THEN
    ActualFrequency_Hz := 0.0;
END_IF;
Ready := TRUE;

(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Chaine bobine, effet mecanique et contact frein M3. *)
FUNCTION_BLOCK PUBLIC FB_Sim_TranslationBrake
VAR_INPUT
    Enable : BOOL;
    ReleaseCmd : BOOL;
    ActualFrequency_Hz : REAL;
    OpenDelay_S : REAL := 0.10;
    CloseDelay_S : REAL := 0.09;
    ContactDelay_S : REAL := 0.01;
    CycleTime_S : REAL := 0.01;
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    CoilEnergized : BOOL;
    MechanicallyOpen : BOOL;
    ContactOpen : BOOL;
END_VAR
VAR
    MechanicalTimer_S : REAL;
    ContactTimer_S : REAL;
END_VAR
VAR CONSTANT
    CST_StopFrequency_Hz : REAL := 0.5;
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    CoilEnergized := FALSE;
    MechanicallyOpen := FALSE;
    ContactOpen := FALSE;
    MechanicalTimer_S := 0.0;
    ContactTimer_S := 0.0;
    RETURN;
END_IF;

CoilEnergized := ReleaseCmd;
IF CoilEnergized THEN
    IF NOT MechanicallyOpen THEN
        MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
        IF MechanicalTimer_S >= MAX(0.0, OpenDelay_S) THEN
            MechanicallyOpen := TRUE;
            MechanicalTimer_S := 0.0;
        END_IF;
    ELSE
        MechanicalTimer_S := 0.0;
    END_IF;
ELSIF ActualFrequency_Hz <= CST_StopFrequency_Hz THEN
    IF MechanicallyOpen THEN
        MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
        IF MechanicalTimer_S >= MAX(0.0, CloseDelay_S) THEN
            MechanicallyOpen := FALSE;
            MechanicalTimer_S := 0.0;
        END_IF;
    ELSE
        MechanicalTimer_S := 0.0;
    END_IF;
ELSE
    MechanicalTimer_S := 0.0;
END_IF;
IF MechanicallyOpen <> ContactOpen THEN
    ContactTimer_S := ContactTimer_S + CycleTime_S;
    IF ContactTimer_S >= MAX(0.0, ContactDelay_S) THEN
        ContactOpen := MechanicallyOpen;
        ContactTimer_S := 0.0;
    END_IF;
ELSE
    ContactTimer_S := 0.0;
END_IF;
Ready := TRUE;

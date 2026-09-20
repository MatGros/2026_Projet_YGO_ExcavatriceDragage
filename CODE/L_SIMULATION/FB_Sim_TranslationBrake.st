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
    (* Branche de FAUTE EXPLICITE — defaut FALSE : chemin nominal strictement inchange.
       Rejoue le defaut terrain « cause 6 instantanee » : contact frein ferme alors que le
       variateur retourne encore de la vitesse (trace 2026-09-04, 26,437 s, 10,00 Hz,
       State.ErrorId=64). La garde nominale CST_StopFrequency_Hz est CONSERVEE telle quelle :
       elle est validee par la meme trace (frein ouvert a 0,60 Hz, ferme a 0,00 Hz). *)
    FaultCloseWhileRunning : BOOL := FALSE;
    FaultCloseDelay_S : REAL := 0.0;
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    CoilEnergized : BOOL;
    MechanicallyOpen : BOOL;
    ContactOpen : BOOL;
    FaultCloseActive : BOOL;   (* <-- [DIAG] Branche de faute effectivement appliquee ce scan *)
END_VAR
VAR
    MechanicalTimer_S : REAL;
    ContactTimer_S : REAL;
    FaultTimer_S : REAL;
END_VAR
VAR CONSTANT
    CST_StopFrequency_Hz : REAL := 0.5;
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    CoilEnergized := FALSE;
    MechanicallyOpen := FALSE;
    ContactOpen := FALSE;
    FaultCloseActive := FALSE;
    MechanicalTimer_S := 0.0;
    ContactTimer_S := 0.0;
    FaultTimer_S := 0.0;
    RETURN;
END_IF;

(* Faute explicite : chronometre propre, remis a zero des que le stimulus retombe. *)
IF FaultCloseWhileRunning THEN
    FaultTimer_S := FaultTimer_S + CycleTime_S;
ELSE
    FaultTimer_S := 0.0;
END_IF;
FaultCloseActive := FaultCloseWhileRunning AND (FaultTimer_S >= MAX(0.0, FaultCloseDelay_S));

(* La faute fait retomber la bobine : l'etat electrique publie reste coherent avec la
   fermeture mecanique observee (jamais « bobine energisee ET frein serre »). *)
CoilEnergized := ReleaseCmd AND NOT FaultCloseActive;
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
ELSIF FaultCloseActive OR (ActualFrequency_Hz <= CST_StopFrequency_Hz) THEN
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

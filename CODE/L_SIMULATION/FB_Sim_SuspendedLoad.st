(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Pendule reduit : reaction sur chariot sans injection DI directe. *)
FUNCTION_BLOCK PUBLIC FB_Sim_SuspendedLoad
VAR_INPUT
    Enable : BOOL;
    BrakeMechanicallyOpen : BOOL;
    CartAcceleration_Mps2 : REAL;
    Length_M : REAL := 1.5;
    Damping : REAL := 0.35;
    ReactionGain_Mps2 : REAL := 0.20;
    CycleTime_S : REAL := 0.01;
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    Angle_Rad : REAL;
    AngularVelocity_RadPerS : REAL;
    VelocityReaction_Mps : REAL;
END_VAR
VAR
    AngularAccel_RadPerS2 : REAL;
END_VAR
VAR CONSTANT
    CST_Gravity_Mps2 : REAL := 9.81;
    CST_MinLength_M : REAL := 0.1;
    CST_MaxAngle_Rad : REAL := 0.6;
    CST_MaxAngularVelocity_RadPerS : REAL := 4.0;
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    Angle_Rad := 0.0;
    AngularVelocity_RadPerS := 0.0;
    VelocityReaction_Mps := 0.0;
    RETURN;
END_IF;

VelocityReaction_Mps := 0.0;
IF Length_M > CST_MinLength_M THEN
    AngularAccel_RadPerS2 := -(CST_Gravity_Mps2 / Length_M) * Angle_Rad
        - MAX(0.0, Damping) * AngularVelocity_RadPerS
        - CartAcceleration_Mps2 / Length_M;
    AngularVelocity_RadPerS := LIMIT(-CST_MaxAngularVelocity_RadPerS,
        AngularVelocity_RadPerS + AngularAccel_RadPerS2 * CycleTime_S, CST_MaxAngularVelocity_RadPerS);
    Angle_Rad := LIMIT(-CST_MaxAngle_Rad, Angle_Rad + AngularVelocity_RadPerS * CycleTime_S,
        CST_MaxAngle_Rad);
    IF BrakeMechanicallyOpen THEN
        VelocityReaction_Mps := ReactionGain_Mps2 * Angle_Rad * CycleTime_S;
    END_IF;
END_IF;
Ready := TRUE;

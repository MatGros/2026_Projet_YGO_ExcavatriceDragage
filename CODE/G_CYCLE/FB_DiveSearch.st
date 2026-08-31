(* =======================================================================
   FB_DiveSearch - Assistance plongee et recherche du fond Kobold
   Role : qualifier l'immersion et autoriser la descente assistee.
   Interface : contrat standard + bus Inputs/Outputs.
   Documentation : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)
FUNCTION_BLOCK FB_DiveSearch
VAR_INPUT
    // === CONTRAT STANDARD ===
    Enable                  : BOOL;                   // --> [CMD] Autorisation generale du FB
    Reset                   : BOOL;                   // --> [CMD] Acquittement defaut sur front

    // === BUS FONCTIONNEL ===
    Inputs                  : ST_fbDiveSearch_Inputs; // --> [BUS] Commande, capteurs et reglages
END_VAR
VAR_OUTPUT
    // === STATUT IEC ===
    Ready                   : BOOL;                   // <-- [STAT] FB pret a fonctionner
    Fault                   : ST_Fault;               // <-- [DIAG] Defaut live et latche
    Lifecycle               : ST_Lifecycle;           // <-- [STAT] Cycle en cours / termine

    // === BUS FONCTIONNEL ===
    Outputs                 : ST_fbDiveSearch_Outputs;// <-- [BUS] Etat, permis et diagnostic
END_VAR
VAR
    // === SOUS-INSTANCES & FRONTS ===
    ResetEdge               : R_TRIG;                 // . [LOC] Front Reset
    ErrorEdge               : R_TRIG;                 // . [LOC] Apparition d'un defaut
    KoboldRiseEdge          : R_TRIG;                 // . [LOC] Entree dans l'eau
    KoboldFallEdge          : F_TRIG;                 // . [LOC] Sortie de l'eau / fond
    instFault               : FB_FaultCore;           // * [INST] Socle defaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Causes nommees

    // === CALCULS DE GARDE ===
    ImmersionCourse_M          : REAL;                // . [LOC] Course maximale vers immersion (m)
    BottomCourse_M             : REAL;                // . [LOC] Course maximale vers fond (m)
    CalculatedImmersionTimeout : TIME;                // . [LOC] Timeout immersion calcule
    CalculatedBottomTimeout    : TIME;                // . [LOC] Timeout fond calcule
    EffectiveDiveSpeedMin_Mps  : REAL;                // . [LOC] Vitesse minimale appliquee (m/s)
    EffectiveTimeoutMargin     : REAL;                // . [LOC] Marge appliquee au calcul
    EffectiveTimeoutMinCourse_M: REAL;                // . [LOC] Plancher de course applique (m)
    EffectiveTimeoutMaxCourse_M: REAL;                // . [LOC] Plafond de course applique (m)
    EffectiveSecToMs            : REAL;               // . [LOC] Conversion secondes/millisecondes

    // === MEMORISATIONS & TEMPORISATIONS ===
    ImmersionTimerAcc       : TIME := T#0ms;          // . [LOC] Temps effectif de recherche immersion
    BottomTimerAcc          : TIME := T#0ms;          // . [LOC] Temps effectif de recherche fond
    PrevState               : E_DiveSearchState;      // . [LOC] Etat du scan precedent
    ImmersionConfirmed      : BOOL;                   // . [LOC] Immersion validee
    StepAtFaultCaptured     : BOOL;                   // . [LOC] Etape de defaut deja figee

    // === CAUSES INTERNES ===
    ErrorCausePresent       : BOOL;                   // . [LOC] Parametrage invalide
    SeqErrorFault           : BOOL;                   // . [LOC] Incoherence de sequence
    Palier5ForbiddenFault   : BOOL;                   // . [LOC] Palier 5 interdit sous Kobold
    TimeoutImmersionFault   : BOOL;                   // . [LOC] Timeout recherche immersion
    TimeoutBottomFault      : BOOL;                   // . [LOC] Timeout recherche fond
    DescentActive           : BOOL;                   // . [LOC] Descending demandee et autorisee
END_VAR

{region "§1 Fronts, calculs et causes"}
ResetEdge(CLK := Reset);
KoboldRiseEdge(CLK := Inputs.KoboldImmersed);
KoboldFallEdge(CLK := Inputs.KoboldImmersed);

// Les valeurs par defaut du DUT couvrent l'appel sans configuration explicite.
// Le repli runtime protege aussi un appel avec une structure entierement nulle.
EffectiveDiveSpeedMin_Mps := Inputs.Config.DiveSpeedMin_Mps;
IF EffectiveDiveSpeedMin_Mps <= 0.0 THEN EffectiveDiveSpeedMin_Mps := 0.15; END_IF;
EffectiveTimeoutMargin := Inputs.Config.TimeoutMarginFactor;
IF EffectiveTimeoutMargin <= 0.0 THEN EffectiveTimeoutMargin := 1.5; END_IF;
EffectiveTimeoutMinCourse_M := Inputs.Config.TimeoutMinCourse_M;
IF EffectiveTimeoutMinCourse_M <= 0.0 THEN EffectiveTimeoutMinCourse_M := 1.0; END_IF;
EffectiveTimeoutMaxCourse_M := Inputs.Config.TimeoutMaxCourse_M;
IF EffectiveTimeoutMaxCourse_M < EffectiveTimeoutMinCourse_M THEN EffectiveTimeoutMaxCourse_M := 200.0; END_IF;
EffectiveSecToMs := Inputs.Config.SecToMs;
IF EffectiveSecToMs <= 0.0 THEN EffectiveSecToMs := 1000.0; END_IF;

ErrorCausePresent := (Inputs.CycleTime <= T#0ms)
                 OR (NOT Inputs.BypassPreconditions AND (
                       (Inputs.DiveStartMin_M < Inputs.ImmersionUpper_M)
                    OR (Inputs.ImmersionUpper_M <= Inputs.ImmersionLower_M)
                    OR (Inputs.ImmersionLower_M <= Inputs.LimitLegalDepthMin_M)
                    OR (Inputs.CableLimitAscent_M <= Inputs.ImmersionLower_M)));

ImmersionCourse_M := LIMIT(EffectiveTimeoutMinCourse_M,
                           Inputs.CableLimitAscent_M - Inputs.ImmersionLower_M,
                           EffectiveTimeoutMaxCourse_M);
BottomCourse_M := LIMIT(EffectiveTimeoutMinCourse_M,
                        Inputs.ImmersionLower_M - Inputs.LimitLegalDepthMin_M,
                        EffectiveTimeoutMaxCourse_M);
CalculatedImmersionTimeout := UDINT_TO_TIME(REAL_TO_UDINT(
    ImmersionCourse_M / EffectiveDiveSpeedMin_Mps * EffectiveTimeoutMargin * EffectiveSecToMs));
CalculatedBottomTimeout := UDINT_TO_TIME(REAL_TO_UDINT(
    BottomCourse_M / EffectiveDiveSpeedMin_Mps * EffectiveTimeoutMargin * EffectiveSecToMs));

IF (Outputs.StepState = E_DiveSearchState.SEARCHING_IMMERSION)
   AND Inputs.MotionRequestActive AND (Inputs.MotionDirection = -1) THEN
    ImmersionTimerAcc := ImmersionTimerAcc + Inputs.CycleTime;
    IF ImmersionTimerAcc >= CalculatedImmersionTimeout THEN TimeoutImmersionFault := TRUE; END_IF;
END_IF;

IF (Outputs.StepState = E_DiveSearchState.SEARCHING_BOTTOM)
   AND Inputs.MotionRequestActive AND (Inputs.MotionDirection = -1) THEN
    BottomTimerAcc := BottomTimerAcc + Inputs.CycleTime;
    IF BottomTimerAcc >= CalculatedBottomTimeout THEN TimeoutBottomFault := TRUE; END_IF;
END_IF;

IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT Inputs.KoboldImmersed
   AND NOT Inputs.MotionRequestActive AND NOT (Inputs.CurrentSpeedStep > 4) THEN
    SeqErrorFault := FALSE;
    Palier5ForbiddenFault := FALSE;
    TimeoutImmersionFault := FALSE;
    TimeoutBottomFault := FALSE;
    ImmersionTimerAcc := T#0ms;
    BottomTimerAcc := T#0ms;
    ImmersionConfirmed := FALSE;
    Outputs.BottomTouchConfirmed := FALSE;
    Outputs.StepAtFault := E_DiveSearchState.WAIT_PRECONDITIONS;
    StepAtFaultCaptured := FALSE;
    Outputs.StepState := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;

instCauses[0].Active := SeqErrorFault;
instCauses[0].Latching := TRUE;
instCauses[0].Texte := 'Incoherence sequence immersion Kobold';
instCauses[1].Active := ErrorCausePresent;
instCauses[1].Latching := TRUE;
instCauses[1].Texte := 'Parametrage invalide des seuils de plongee';
instCauses[2].Active := Palier5ForbiddenFault;
instCauses[2].Latching := TRUE;
instCauses[2].Texte := 'Palier 5 interdit pendant la mesure Kobold';
instCauses[3].Active := TimeoutImmersionFault;
instCauses[3].Latching := TRUE;
instCauses[3].Texte := 'Timeout recherche immersion Kobold';
instCauses[4].Active := TimeoutBottomFault;
instCauses[4].Latching := TRUE;
instCauses[4].Texte := 'Timeout recherche fond Kobold';

instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

ErrorEdge(CLK := Fault.Error);
IF ErrorEdge.Q AND NOT StepAtFaultCaptured THEN
    Outputs.StepAtFault := PrevState;
    StepAtFaultCaptured := TRUE;
ELSIF ResetEdge.Q AND NOT ErrorCausePresent AND NOT Inputs.KoboldImmersed
      AND NOT Inputs.MotionRequestActive AND NOT (Inputs.CurrentSpeedStep > 4) THEN
    Outputs.StepAtFault := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;
{endregion}

{region "§2 Neutralisation et machine d'etat"}
IF NOT Enable OR NOT Inputs.PowerContactorEngaged THEN
    Ready := FALSE;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    Outputs.DescendPermit := FALSE;
    Outputs.KoboldContactorCmd := FALSE;
    Outputs.BottomTouchConfirmed := FALSE;
    Outputs.StepState := E_DiveSearchState.WAIT_PRECONDITIONS;
    Outputs.OperatorActionId := 0;
    Outputs.OperatorAction := '';
    ImmersionConfirmed := FALSE;
    ImmersionTimerAcc := T#0ms;
    BottomTimerAcc := T#0ms;
    Outputs.MinStepDown := 0;
    PrevState := E_DiveSearchState.WAIT_PRECONDITIONS;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
Outputs.DescendPermit := FALSE;
Outputs.KoboldContactorCmd := FALSE;
Lifecycle.Busy := FALSE;
Lifecycle.Done := FALSE;
Outputs.OperatorActionId := 0;
Outputs.OperatorAction := '';

DescentActive := Inputs.MotionRequestActive AND (Inputs.MotionDirection = -1)
              AND ((Inputs.Mode = E_Mode.MAINT_N1) OR (Inputs.Mode = E_Mode.MAINT_N2))
              AND NOT (Inputs.CurrentSpeedStep > 4)
              AND NOT SeqErrorFault;

IF Fault.Error OR Fault.Latched THEN
    Outputs.StepState := E_DiveSearchState.ERROR_HOLD;
    Outputs.KoboldContactorCmd := FALSE;
    Outputs.OperatorActionId := 16#0180;
    Outputs.OperatorAction := 'Verifier les conditions puis rearmer avant une nouvelle plongee.';
ELSE
    CASE Outputs.StepState OF
        E_DiveSearchState.WAIT_PRECONDITIONS:
            IF NOT Inputs.BypassPreconditions
               AND (NOT Inputs.BucketIsOpen OR NOT Inputs.PositionsValid OR Inputs.KoboldImmersed
                    OR (Inputs.M1Position_M < Inputs.DiveStartMin_M)
                    OR (Inputs.M2Position_M < Inputs.DiveStartMin_M)) THEN
                Outputs.OperatorActionId := 16#0100;
                Outputs.OperatorAction := 'Verifier benne ouverte, positions et Kobold au repos.';
            ELSE
                Outputs.StepState := E_DiveSearchState.READY_TO_DESCEND;
            END_IF;

        E_DiveSearchState.READY_TO_DESCEND:
            Ready := TRUE;
            Outputs.OperatorActionId := 16#0101;
            Outputs.OperatorAction := 'Demander une descente pour rechercher le fond.';
            IF Inputs.MotionRequestActive AND (Inputs.MotionDirection = -1) THEN
                ImmersionTimerAcc := T#0ms;
                Outputs.StepState := E_DiveSearchState.SEARCHING_IMMERSION;
            END_IF;

        E_DiveSearchState.SEARCHING_IMMERSION:
            Lifecycle.Busy := TRUE;
            Outputs.DescendPermit := DescentActive;
            Outputs.KoboldContactorCmd := DescentActive;
            Outputs.OperatorActionId := 16#0102;
            Outputs.OperatorAction := 'Maintenir la descente : recherche immersion Kobold.';
            IF Inputs.CurrentSpeedStep > 4 THEN
                IF NOT StepAtFaultCaptured THEN
                    Outputs.StepAtFault := Outputs.StepState;
                    StepAtFaultCaptured := TRUE;
                END_IF;
                Palier5ForbiddenFault := TRUE;
            END_IF;
            IF KoboldRiseEdge.Q THEN
                IF (Inputs.M1Position_M <= Inputs.ImmersionUpper_M)
                   AND (Inputs.M1Position_M >= Inputs.ImmersionLower_M)
                   AND (Inputs.M2Position_M <= Inputs.ImmersionUpper_M)
                   AND (Inputs.M2Position_M >= Inputs.ImmersionLower_M) THEN
                    ImmersionConfirmed := TRUE;
                    BottomTimerAcc := T#0ms;
                    Outputs.StepState := E_DiveSearchState.SEARCHING_BOTTOM;
                ELSE
                    IF NOT StepAtFaultCaptured THEN
                        Outputs.StepAtFault := Outputs.StepState;
                        StepAtFaultCaptured := TRUE;
                    END_IF;
                    SeqErrorFault := TRUE;
                END_IF;
            ELSIF (Inputs.M1Position_M < Inputs.ImmersionLower_M)
               OR (Inputs.M2Position_M < Inputs.ImmersionLower_M) THEN
                IF NOT StepAtFaultCaptured THEN
                    Outputs.StepAtFault := Outputs.StepState;
                    StepAtFaultCaptured := TRUE;
                END_IF;
                SeqErrorFault := TRUE;
            END_IF;

        E_DiveSearchState.SEARCHING_BOTTOM:
            Lifecycle.Busy := TRUE;
            Outputs.DescendPermit := DescentActive;
            Outputs.KoboldContactorCmd := DescentActive;
            Outputs.OperatorActionId := 16#0103;
            Outputs.OperatorAction := 'Maintenir la descente : immersion validee, recherche du fond.';
            IF Inputs.CurrentSpeedStep > 4 THEN
                IF NOT StepAtFaultCaptured THEN
                    Outputs.StepAtFault := Outputs.StepState;
                    StepAtFaultCaptured := TRUE;
                END_IF;
                Palier5ForbiddenFault := TRUE;
            END_IF;
            IF KoboldFallEdge.Q AND ImmersionConfirmed THEN
                Outputs.BottomTouchConfirmed := TRUE;
                ImmersionConfirmed := FALSE;
                Outputs.KoboldContactorCmd := FALSE;
                Outputs.StepState := E_DiveSearchState.BOTTOM_CONFIRMED;
            END_IF;

        E_DiveSearchState.BOTTOM_CONFIRMED:
            Lifecycle.Done := TRUE;
            Outputs.KoboldContactorCmd := FALSE;
            Outputs.OperatorActionId := 16#0104;
            Outputs.OperatorAction := 'Fond detecte : demander la fermeture ou extraction.';

        E_DiveSearchState.ERROR_HOLD:
            Outputs.KoboldContactorCmd := FALSE;
    END_CASE;
END_IF;

IF DescentActive AND ((Outputs.StepState = E_DiveSearchState.SEARCHING_IMMERSION)
                   OR (Outputs.StepState = E_DiveSearchState.SEARCHING_BOTTOM)) THEN
    Outputs.MinStepDown := LIMIT(0, Inputs.CfgDiveFloorStep, 5);
ELSE
    Outputs.MinStepDown := 0;
END_IF;

PrevState := Outputs.StepState;
{endregion}

END_FUNCTION_BLOCK

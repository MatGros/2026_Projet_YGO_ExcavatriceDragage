(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_WinchMotor — Couple electromagnetique moteur treuil (rotor bobine)
   ───────────────────────────────────────────────────────────────
   🎯 Role : Couple (formule de Kloss), glissement bidirectionnel, decrochage
   predictif et mode generatrice pour un treuil M1/M2.
   📄 Doc metier : DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md
   (pas encore integre a AF_Partie-13 -- entree F13.06 a creer lot dedie)
   🧩 Dependances : aucune (brique de calcul pure)
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Sim_WinchMotor
VAR_INPUT
    // === CONTRAT LIGHT ===
    Enable                    : BOOL; // --> [CMD] Autorisation generale FB (TRUE=Autorise)

    // === COMMANDES ===
    StepCmd                   : INT;  // --> [CMD] Palier resistance rotorique actif (1..5)
    DirectionCmd              : INT := 1; // --> [CMD] Sens (1=Montee, -1=Descente)

    // === MESURES / CHARGE ===
    NetworkVoltageAct_V       : REAL := 400.0; // --> [HW] Tension reseau mesuree/simulee
    ResistiveTorque_Nm        : REAL; // --> [CMD] Couple de charge, repere de commande

    // === REGLAGES & CONFIGURATION ===
    NetworkVoltageNom_V          : REAL := 400.0; // --> [CFG] Tension nominale reseau
    MaxTorque_Nm                 : REAL := 3800.0; // --> [CFG] Cmax decrochage -- SYNTHETIQUE
    SlipAtMaxTorqueStep1_Ratio   : REAL := 0.08;   // --> [CFG] gmax palier 1 -- SYNTHETIQUE
    RotorResistanceOwn_Ohm       : REAL := 0.08;   // --> [CFG] R2 propre rotor
    Inertia_KgM2                 : REAL := 45.0;   // --> [CFG] Inertie ramenee -- SYNTHETIQUE
    SynchronousSpeed_Rpm         : REAL := 1500.0; // --> [CFG] Vitesse synchronisme
    CycleTime_S                  : REAL := 0.01;   // --> [CFG] Pas d'integration
END_VAR
VAR_OUTPUT
    // === CONTRAT LIGHT ===
    Ready                     : BOOL; // <-- [STAT] FB pret

    // === RESULTATS PHYSIQUES ===
    MotorTorque_Nm            : REAL; // <-- [DIAG] Couple electromagnetique, repere de commande
    Slip_Ratio                : REAL; // <-- [DIAG] Glissement, repere de commande
    SpeedAct_Rpm               : REAL; // <-- [DIAG] Vitesse physique reelle signee (+montee/-descente)
    IsStalled                 : BOOL; // <-- [DIAG] Decrochage constate (jamais reinitialise)
    IsGeneratorMode            : BOOL; // <-- [DIAG] Couple oppose au sens de commande (freinage)
END_VAR
VAR
    // === ETAT INTERNE ===
    SpeedRel_RadPerS           : REAL; // . [LOC] Vitesse en repere de commande (N_rel)
    SynchronousSpeed_RadPerS   : REAL; // . [LOC] Vitesse synchronisme, rad/s
    SlipAtMaxTorqueStep_Ratio  : REAL; // . [LOC] gmax au palier courant
    SlipEff_Ratio               : REAL; // . [LOC] Glissement protege division par zero
    Stalled                    : BOOL; // . [LOC] Etat instantane, peut se relever
END_VAR
VAR CONSTANT
    CST_StepCount              : INT := 5;
    CST_RotorExtResistanceStep_Ohm : ARRAY[1..5] OF REAL := [3.6, 1.9, 0.9, 0.35, 0.0];
        // palier 1 = resistance max (demarrage), palier 5 = rotor court-circuite -- SYNTHETIQUE
    CST_MinSlip_Ratio          : REAL := 0.0001;
    CST_StallSpeedThreshold_Rpm : REAL := 28.0; // ~3 rad/s, "quasi arrete"
END_VAR

// === §1 GATE NEUTRALISATION ===
IF NOT Enable THEN
    Ready := FALSE;
    MotorTorque_Nm := 0.0;
    Slip_Ratio := 0.0;
    SpeedAct_Rpm := 0.0;
    IsStalled := FALSE;
    IsGeneratorMode := FALSE;
    SpeedRel_RadPerS := 0.0;
    RETURN;
END_IF;

IF (StepCmd < 1) OR (StepCmd > CST_StepCount) THEN
    Ready := FALSE;
    RETURN;
END_IF;
IF (DirectionCmd <> 1) AND (DirectionCmd <> -1) THEN
    Ready := FALSE;
    RETURN;
END_IF;

// === §2 GLISSEMENT ET COUPLE (FORMULE DE KLOSS) ===
SynchronousSpeed_RadPerS := SynchronousSpeed_Rpm * 2.0 * 3.14159265 / 60.0;

// gmax(palier) proportionnel a la resistance rotorique totale : plus de resistance ajoutee
// deplace le glissement au couple max vers 1 (couple demarrage) sans changer Cmax.
SlipAtMaxTorqueStep_Ratio := SlipAtMaxTorqueStep1_Ratio
    * (RotorResistanceOwn_Ohm + CST_RotorExtResistanceStep_Ohm[StepCmd])
    / (RotorResistanceOwn_Ohm + CST_RotorExtResistanceStep_Ohm[1]);

// Glissement en repere de commande (N_rel) : peut etre negatif (survitesse -> freinage
// generateur). SpeedRel_RadPerS reste dans ce repere ; SpeedAct_Rpm restitue le signe physique.
Slip_Ratio := 1.0 - SpeedRel_RadPerS / SynchronousSpeed_RadPerS;

IF ABS(Slip_Ratio) < CST_MinSlip_Ratio THEN
    IF Slip_Ratio >= 0.0 THEN
        SlipEff_Ratio := CST_MinSlip_Ratio;
    ELSE
        SlipEff_Ratio := -CST_MinSlip_Ratio;
    END_IF;
ELSE
    SlipEff_Ratio := Slip_Ratio;
END_IF;

MotorTorque_Nm := 2.0 * MaxTorque_Nm
    / (SlipEff_Ratio / SlipAtMaxTorqueStep_Ratio + SlipAtMaxTorqueStep_Ratio / SlipEff_Ratio)
    * (NetworkVoltageAct_V / NetworkVoltageNom_V) ** 2;

// === §3 DYNAMIQUE MECANIQUE ===
// Pas de saturation basse : SpeedRel_RadPerS peut devenir negatif (glissement arriere sous
// surcharge) ou depasser le synchronisme (regime generateur).
SpeedRel_RadPerS := SpeedRel_RadPerS
    + (MotorTorque_Nm - ResistiveTorque_Nm) / Inertia_KgM2 * CycleTime_S;

SpeedAct_Rpm := SpeedRel_RadPerS * DirectionCmd * 60.0 / (2.0 * 3.14159265);

// === §4 DECROCHAGE PREDICTIF ===
// Au palier courant, couple disponible a glissement bloque (g=1) < couple resistant, ET
// vitesse quasi nulle -- prediction "ce palier peut-il tenir la charge depuis l'arret ?",
// pas une mesure d'arret reel.
IF ABS(SpeedAct_Rpm) < CST_StallSpeedThreshold_Rpm THEN
    Stalled := (2.0 * MaxTorque_Nm
        / (1.0 / SlipAtMaxTorqueStep_Ratio + SlipAtMaxTorqueStep_Ratio)
        * (NetworkVoltageAct_V / NetworkVoltageNom_V) ** 2) < ResistiveTorque_Nm;
    IF Stalled THEN
        IsStalled := TRUE;
    END_IF;
ELSE
    Stalled := FALSE;
END_IF;

IsGeneratorMode := MotorTorque_Nm < 0.0;

Ready := TRUE;

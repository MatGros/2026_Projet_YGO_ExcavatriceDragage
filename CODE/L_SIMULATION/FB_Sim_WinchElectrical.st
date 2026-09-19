(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_WinchElectrical — Composite electrique treuil (charge + couplage)
   ───────────────────────────────────────────────────────────────
   🎯 Role : Calcule le couple resistant reel (charge, benne au sol, couplage
   M1/M2) et pilote FB_Sim_WinchMotor. Transition de charge lissee (evite les
   a-coups de couple/vitesse a la bascule seul<->couple ou charge<->benne au sol).
   📄 Doc metier : DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md
   (registre sequence/interface 2026-09-18 -- pas encore integre a AF_Partie-13)
   🧩 Dependances : FB_Sim_WinchMotor
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Sim_WinchElectrical
VAR_INPUT
    // === CONTRAT LIGHT ===
    Enable                    : BOOL; // --> [CMD] Autorisation generale FB

    // === COMMANDES ===
    StepCmd                   : INT;  // --> [CMD] Palier resistance rotorique actif (1..5)
    DirectionCmd              : INT := 1; // --> [CMD] Sens (1=Montee, -1=Descente)
    NetworkVoltageAct_V       : REAL := 400.0; // --> [HW] Tension reseau mesuree/simulee

    // === CHARGE ===
    LoadFrac_Ratio            : REAL; // --> [CMD] Taux de charge commande/estime (0..1)
    IsBucketGrounded          : BOOL; // --> [HW] TRUE = benne posee/cable detendu -> charge forcee a 0
        // A cabler sur l'image simulee de M2_TensionedCable_DI (NOT IsBucketGrounded) une fois le
        // stimulus expose en amont (GVL_Simulation) -- interface prete, cablage source en attente.
    LoadTransitionFilter_S    : REAL := 0.5; // --> [CFG] Constante de temps lissage charge (evite a-coup)

    // === COUPLAGE M1/M2 ===
    IsCoupledToPeer           : BOOL; // --> [CMD] TRUE = les deux treuils sont couples (benne commune)
        // A cabler sur l'equivalent simule de CoupledBoth/SyncActive (PRG_04_Treuils_Benne) une fois
        // expose en amont -- interface prete, cablage source en attente (lag 1 cycle accepte).
    PeerTorque_Nm             : REAL; // --> [BUS] Couple moteur de l'autre treuil (cycle precedent)
    PeerSpeed_Rpm             : REAL; // --> [BUS] Vitesse physique de l'autre treuil (cycle precedent)

    // === REGLAGES & CONFIGURATION (relayes a FB_Sim_WinchMotor) ===
    NetworkVoltageNom_V          : REAL := 400.0; // --> [CFG] Tension nominale reseau
    MaxTorque_Nm                 : REAL := 3800.0; // --> [CFG] Cmax decrochage -- SYNTHETIQUE
    SlipAtMaxTorqueBase_Ratio    : REAL := 0.08;   // --> [CFG] gmax palier rotor court-circuite
    RotorResistanceOwn_Ohm       : REAL := 0.08;   // --> [CFG] R2 propre rotor
    Inertia_KgM2                 : REAL := 45.0;   // --> [CFG] Inertie ramenee -- SYNTHETIQUE
    SynchronousSpeed_Rpm         : REAL := 1500.0; // --> [CFG] Vitesse synchronisme
    LoadNominalTorque_Nm         : REAL := 2500.0; // --> [CFG] Couple resistant a pleine charge -- SYNTHETIQUE
    LoadFrictionTorque_Nm        : REAL := 80.0;   // --> [CFG] Frottements residuels a vide -- SYNTHETIQUE
    CoupledPeerGain_Ratio         : REAL := 0.5;   // --> [CFG] Poids de l'effort differentiel du pair en mode couple
    CycleTime_S                  : REAL := 0.01;   // --> [CFG] Pas d'integration
END_VAR
VAR_OUTPUT
    // === CONTRAT LIGHT ===
    Ready                     : BOOL; // <-- [STAT] FB pret

    // === RESULTATS PHYSIQUES (relayes de FB_Sim_WinchMotor) ===
    MotorTorque_Nm            : REAL; // <-- [DIAG] Couple electromagnetique, repere de commande
    ResistiveTorqueAct_Nm     : REAL; // <-- [DIAG] Couple resistant reellement applique (charge+couplage, lisse)
    Slip_Ratio                : REAL; // <-- [DIAG] Glissement, repere de commande
    SpeedAct_Rpm               : REAL; // <-- [DIAG] Vitesse physique reelle signee (+montee/-descente)
    IsStalled                 : BOOL; // <-- [DIAG] Decrochage constate
    IsGeneratorMode            : BOOL; // <-- [DIAG] Mode freinage electrique
END_VAR
VAR
    // === SOUS-INSTANCE FB ===
    Motor                     : FB_Sim_WinchMotor; // * [INST] Couple electromagnetique elementaire

    // === ETAT INTERNE ===
    LoadFracFiltered_Ratio     : REAL; // . [LOC] Taux de charge lisse (PT1)
    LoadFracTarget_Ratio       : REAL; // . [LOC] Cible : 0 si benne au sol, sinon LoadFrac_Ratio
    PeerDifferentialTorque_Nm  : REAL; // . [LOC] Effort differentiel du pair en mode couple
    FilterAlpha_Ratio           : REAL; // . [LOC] Coefficient de lissage du pas courant
END_VAR
VAR CONSTANT
    CST_MinFilterTime_S        : REAL := 0.001;
END_VAR

// === §1 GATE NEUTRALISATION ===
IF NOT Enable THEN
    Ready := FALSE;
    MotorTorque_Nm := 0.0;
    ResistiveTorqueAct_Nm := 0.0;
    Slip_Ratio := 0.0;
    SpeedAct_Rpm := 0.0;
    IsStalled := FALSE;
    IsGeneratorMode := FALSE;
    LoadFracFiltered_Ratio := 0.0;
    RETURN;
END_IF;

// === §2 CHARGE LISSEE (benne au sol force la cible a 0, transition sans a-coup) ===
IF IsBucketGrounded THEN
    LoadFracTarget_Ratio := 0.0;
ELSE
    LoadFracTarget_Ratio := LIMIT(0.0, LoadFrac_Ratio, 1.0);
END_IF;

IF LoadTransitionFilter_S > CST_MinFilterTime_S THEN
    FilterAlpha_Ratio := CycleTime_S / (LoadTransitionFilter_S + CycleTime_S);
ELSE
    FilterAlpha_Ratio := 1.0;
END_IF;
LoadFracFiltered_Ratio := LoadFracFiltered_Ratio
    + FilterAlpha_Ratio * (LoadFracTarget_Ratio - LoadFracFiltered_Ratio);

// === §3 COUPLAGE M1/M2 ===
// En mode couple, la benne lie mecaniquement les deux treuils : un ecart de couple entre pairs
// se traduit en effort differentiel de rattrapage (proportionnel a l'ecart de vitesse), pas en
// deux dynamiques d'inertie totalement independantes qui divergent librement.
IF IsCoupledToPeer THEN
    PeerDifferentialTorque_Nm := CoupledPeerGain_Ratio * (SpeedAct_Rpm - PeerSpeed_Rpm)
        * LoadNominalTorque_Nm / MAX(SynchronousSpeed_Rpm, 1.0);
ELSE
    PeerDifferentialTorque_Nm := 0.0;
END_IF;

// === §4 COUPLE RESISTANT APPLIQUE ===
ResistiveTorqueAct_Nm := LoadFrictionTorque_Nm
    + DirectionCmd * LoadFracFiltered_Ratio * LoadNominalTorque_Nm
    + PeerDifferentialTorque_Nm;

// === §5 MOTEUR ELEMENTAIRE ===
Motor(
    Enable := TRUE,
    StepCmd := StepCmd,
    DirectionCmd := DirectionCmd,
    NetworkVoltageAct_V := NetworkVoltageAct_V,
    ResistiveTorque_Nm := ResistiveTorqueAct_Nm,
    NetworkVoltageNom_V := NetworkVoltageNom_V,
    MaxTorque_Nm := MaxTorque_Nm,
    SlipAtMaxTorqueBase_Ratio := SlipAtMaxTorqueBase_Ratio,
    RotorResistanceOwn_Ohm := RotorResistanceOwn_Ohm,
    Inertia_KgM2 := Inertia_KgM2,
    SynchronousSpeed_Rpm := SynchronousSpeed_Rpm,
    CycleTime_S := CycleTime_S
);

MotorTorque_Nm := Motor.MotorTorque_Nm;
Slip_Ratio := Motor.Slip_Ratio;
SpeedAct_Rpm := Motor.SpeedAct_Rpm;
IsStalled := Motor.IsStalled;
IsGeneratorMode := Motor.IsGeneratorMode;

Ready := TRUE;

(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_WinchMotor — Couple electromagnetique moteur treuil (rotor bobine)
   ───────────────────────────────────────────────────────────────
   🎯 Role : Couple (formule de Kloss), glissement bidirectionnel, decrochage
   predictif et mode generatrice pour un treuil M1/M2.
   📄 Doc metier : DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md
   (pas encore integre a AF_Partie-13 -- entree F13.06 a creer lot dedie)
   🧩 Dependances : FB_Sim_KlossTorque
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
    ResistiveTorque_Nm        : REAL; // --> [CMD] Couple de charge DEJA projete en repere de
        // commande (N_rel) par l'appelant : positif = s'oppose au mouvement commande, negatif =
        // aide le mouvement (ex. gravite en descente -> peut declencher le mode generatrice).
        // Ce FB ne connait pas le taux de charge/la gravite -- calcul delegue a FB_Sim_WinchElectrical.

    // === REGLAGES & CONFIGURATION ===
    NetworkVoltageNom_V          : REAL := 400.0; // --> [CFG] Tension nominale reseau
    MaxTorque_Nm                 : REAL := 3800.0; // --> [CFG] Cmax decrochage -- SYNTHETIQUE
    SlipAtMaxTorqueBase_Ratio    : REAL := 0.08;   // --> [CFG] gmax au palier rotor court-circuite
        // (resistance externe nulle) -- SYNTHETIQUE. Sert de base a la mise a l'echelle par palier.
    RotorResistanceOwn_Ohm       : REAL := 0.08;   // --> [CFG] R2 propre rotor (palier court-circuite)
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
    // === SOUS-INSTANCES FB ===
    KlossRunning               : FB_Sim_KlossTorque; // * [INST] Couple regime etabli
    KlossLockedRotor           : FB_Sim_KlossTorque; // * [INST] Couple test decrochage (g=1)

    // === ETAT INTERNE ===
    SpeedRel_RadPerS           : REAL; // . [LOC] Vitesse en repere de commande (N_rel)
    SynchronousSpeed_RadPerS   : REAL; // . [LOC] Vitesse synchronisme, rad/s
    SlipAtMaxTorqueStep_Ratio  : REAL; // . [LOC] gmax au palier courant
    SlipEff_Ratio               : REAL; // . [LOC] Glissement protege division par zero
    VoltageRatio2               : REAL; // . [LOC] (U_act/U_nom)^2
    Stalled                    : BOOL; // . [LOC] Etat instantane, peut se relever

    // === ENTREES BORNEES (SECURISE DIVISIONS) ===
    InertiaSafe_KgM2            : REAL; // . [LOC] Inertia_KgM2 bornee > 0
    RotorResistanceOwnSafe_Ohm  : REAL; // . [LOC] RotorResistanceOwn_Ohm bornee > 0
    SlipAtMaxTorqueBaseSafe_Ratio : REAL; // . [LOC] SlipAtMaxTorqueBase_Ratio bornee > 0
    NetworkVoltageNomSafe_V     : REAL; // . [LOC] NetworkVoltageNom_V bornee > 0
    StepCmdSafe                : INT;  // . [LOC] StepCmd borne [1..5]
END_VAR
VAR CONSTANT
    CST_StepCount              : INT := 5;
    CST_RotorExtResistanceStep_Ohm : ARRAY[1..5] OF REAL := [3.6, 1.9, 0.9, 0.35, 0.0];
        // palier 1 = resistance max (demarrage), palier 5 = rotor court-circuite -- SYNTHETIQUE
        // (indexation/valeurs propres au ST, pas un portage 1:1 du prototype Python 4 gradins)
    CST_MinSlip_Ratio          : REAL := 0.0001;
    CST_MinDenominator         : REAL := 0.001; // plancher generique config sensible (division)
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

StepCmdSafe := LIMIT(1, StepCmd, CST_StepCount);
IF StepCmdSafe <> StepCmd THEN
    Ready := FALSE;
    RETURN;
END_IF;
IF (DirectionCmd <> 1) AND (DirectionCmd <> -1) THEN
    Ready := FALSE;
    RETURN;
END_IF;

// Bornage systematique des entrees de config sensibles (denominateurs) -- CODE_QUALITY_STANDARDS §6
InertiaSafe_KgM2 := MAX(CST_MinDenominator, Inertia_KgM2);
RotorResistanceOwnSafe_Ohm := MAX(CST_MinDenominator, RotorResistanceOwn_Ohm);
SlipAtMaxTorqueBaseSafe_Ratio := MAX(CST_MinDenominator, SlipAtMaxTorqueBase_Ratio);
NetworkVoltageNomSafe_V := MAX(1.0, NetworkVoltageNom_V);

// === §2 GLISSEMENT ET COUPLE (FORMULE DE KLOSS) ===
SynchronousSpeed_RadPerS := SynchronousSpeed_Rpm * 2.0 * 3.14159265 / 60.0;

// gmax(palier) = gmax_base * R2_total(palier) / R2_rotor_propre -- ajouter de la resistance
// externe deplace le glissement au couple max vers 1 (couple demarrage), sans changer Cmax.
// gmax_base = gmax au palier rotor court-circuite (resistance externe nulle).
SlipAtMaxTorqueStep_Ratio := SlipAtMaxTorqueBaseSafe_Ratio
    * (RotorResistanceOwnSafe_Ohm + CST_RotorExtResistanceStep_Ohm[StepCmdSafe])
    / RotorResistanceOwnSafe_Ohm;

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

VoltageRatio2 := (NetworkVoltageAct_V / NetworkVoltageNomSafe_V) * (NetworkVoltageAct_V / NetworkVoltageNomSafe_V);

KlossRunning(
    Enable := TRUE,
    MaxTorque_Nm := MaxTorque_Nm,
    Slip_Ratio := SlipEff_Ratio,
    SlipAtMaxTorque_Ratio := SlipAtMaxTorqueStep_Ratio,
    VoltageRatio2 := VoltageRatio2);
MotorTorque_Nm := KlossRunning.Torque_Nm;

// === §3 DYNAMIQUE MECANIQUE ===
// Pas de saturation basse : SpeedRel_RadPerS peut devenir negatif (glissement arriere sous
// surcharge) ou depasser le synchronisme (regime generateur).
SpeedRel_RadPerS := SpeedRel_RadPerS
    + (MotorTorque_Nm - ResistiveTorque_Nm) / InertiaSafe_KgM2 * CycleTime_S;

SpeedAct_Rpm := SpeedRel_RadPerS * DirectionCmd * 60.0 / (2.0 * 3.14159265);

// === §4 DECROCHAGE PREDICTIF ===
// Au palier courant, couple disponible a glissement bloque (g=1) < couple resistant, ET
// vitesse quasi nulle -- prediction "ce palier peut-il tenir la charge depuis l'arret ?",
// pas une mesure d'arret reel.
IF ABS(SpeedAct_Rpm) < CST_StallSpeedThreshold_Rpm THEN
    KlossLockedRotor(
        Enable := TRUE,
        MaxTorque_Nm := MaxTorque_Nm,
        Slip_Ratio := 1.0,
        SlipAtMaxTorque_Ratio := SlipAtMaxTorqueStep_Ratio,
        VoltageRatio2 := VoltageRatio2);
    Stalled := KlossLockedRotor.Torque_Nm < ResistiveTorque_Nm;
    IF Stalled THEN
        IsStalled := TRUE;
    END_IF;
ELSE
    Stalled := FALSE;
END_IF;

IsGeneratorMode := MotorTorque_Nm < 0.0;

Ready := TRUE;

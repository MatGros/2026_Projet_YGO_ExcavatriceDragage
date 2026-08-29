(* =======================================================================
   🪝 FB_Winch — Directeur d'un treuil individuel (M1 / M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Pilotage d'un treuil individuel (contacteurs de sens et de vitesse)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : FB de mouvement (Enable, SafeStop, StartStop)
   🔒 Sécurité : Interlock inversion de sens et gestion des autorisations
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut (front)
    StartStop                       : BOOL;                           // --> [CMD] Ordre de marche/arret mouvement
    Direction                       : INT;                            // --> [CMD] Sens demande (-1: Descente, 0: Stop, 1: Montee)
    SpeedTgt_Pct                    : REAL;                           // --> [CMD] Vitesse cible % (0.0 a 100.0)

    // === SECOURS ET PERMIS DE SÉCURITÉ ===
    SafeStop                        : BOOL;                           // --> [SAFE] Arret rapide de securite
    DescendPermit                   : BOOL := TRUE;                  // --> [SAFE] Permis de descente (mou de cable)
    AscentPermit                    : BOOL := TRUE;                  // --> [SAFE] Permis de montee (fin de course haut)
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Statut contacteur de ligne / puissance

    // === REGLAGES ET CONFIGURATION ===
    SpeedStepTable                  : ST_SpeedStepTable;              // --> [CFG] Table de seuils des paliers de vitesse
    CfgMaxStepDescente              : INT := 3;                       // --> [CFG] Plafond palier en descente (1..5)
    MaxStepAscent                   : INT := 5;                       // --> [CFG] Plafond palier en montee (1..5)
    HomingApproachActive            : BOOL;                           // --> [CFG] Vitesse limitee au palier 1 (approche homing)
    SpeedStepHystMargin             : REAL := 2.0;                    // --> [CFG] Marge d'hysteresis palier (%)
    DirectionInterlockDelayDescent  : TIME := T#400ms;                // --> [CFG] Delai interlock changement de sens descente
    DirectionInterlockDelayAscent   : TIME := T#900ms;                // --> [CFG] Delai interlock changement de sens montee
    StepRampDelayAscent             : TIME := T#1000ms;               // --> [CFG] Cadence palier montee (D10, dedie)
    StepRampDelayDescente            : TIME := T#500ms;                // --> [CFG] Cadence palier descente (D10, dedie)
    ContactorFeedbackTimeout        : TIME := T#500ms;                // --> [CFG] Delai d'attente retombee des contacteurs
    TopLimitM                       : REAL := 8.5;                    // --> [CFG] Position limite haute active (m)
    BottomLimitM                    : REAL := -20.0;                  // --> [CFG] Position limite basse active (m)
    CfgSlowdownDistanceM            : REAL := 1.0;                    // --> [CFG] Distance d'approche avant limite pour ralentir (m)
    CfgSlowdownMaxStep              : INT := 1;                       // --> [CFG] Plafond palier dans zone de ralentissement (1..5)

    // === MESURES ET FEEDBACKS SENSORS ===
    FwdRevSpeedFeedbackOff          : BOOL;                           // --> [HW] Retour unique contacteurs sens+vitesse retombes
    Homed                           : BOOL;                           // --> [HW] Statut treuil reference
    HomingSuspect                   : BOOL;                           // --> [HW] Incertitude / doute sur le referencement
    CablePosM                       : REAL;                           // --> [HW] Position actuelle du cable (m)
    MeasuredSpeedBand               : INT := 0;                       // --> [HW] Bande vitesse reelle validee
    SpeedGuardEnable                : BOOL := FALSE;                  // --> [HW] Activation garde-fou changement de palier
    SpeedGuardReady                 : BOOL := FALSE;                  // --> [HW] Conditions de stabilite validees

    // === BYPASSES ET SIMULATION ===
    BypassContactorCheck            : BOOL;                           // --> [TST] Bypass diagnostic contacteurs (simu)
    BypassGlobal                    : BOOL;                           // --> [TST] Force ErrorId=0, ignore erreurs
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                           : ST_Fault;

    // === ORDRES ACTIONNEURS (CONTACTEURS) ===
    RelayFwd                        : BOOL;                           // <-- [ACT] Ordre contacteur sens montee
    RelayRev                        : BOOL;                           // <-- [ACT] Ordre contacteur sens descente
    Contactor1                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 1
    Contactor2                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 2
    Contactor3                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 3
    Contactor4                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 4

    // === DIAGNOSTICS ET MESURES ===
    RequestedStep                   : INT;                            // <-- [DIAG] Palier brut calcule par SpeedStep
    StepNumber                      : INT;                            // <-- [DIAG] Palier metier temporise actif
    BusinessStepDelayElapsed        : TIME;                           // <-- [DIAG] Ecoule tempo metier palier
    SpeedGuardLimited               : BOOL;                           // <-- [DIAG] Statut limitation par garde-fou
    ContactorsCheck                 : ST_ContactorCheck;              // <-- [DIAG] Diagnostic concorde contacteurs
    InTopSlowdownZone               : BOOL;                           // <-- [DIAG] Zone de ralentissement haut active
    InBottomSlowdownZone            : BOOL;                           // <-- [DIAG] Zone de ralentissement bas active
    CommandedDirection              : INT;                            // <-- [DIAG] Sens interne memorise
    DirectionChangeDelayElapsed     : TIME;                           // <-- [DIAG] Ecoule delai changement de sens
    DirectionChangePending          : BOOL;                           // <-- [DIAG] Changement de sens en attente
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    SpeedStep                       : FB_SpeedStep;                   // * [INST] Decodage paliers vitesse
    DirectionInterlock              : FB_WinchDirectionInterlock;     // * [INST] Interlock changement de sens (D18)
    StepShaper                      : FB_WinchStepShaper;             // * [INST] Cadencement de palier (D10)
    SpeedStepHyst1                  : HYSTERESIS;                     // * [INST] Décodage consigne -> palier, seuil 1
    SpeedStepHyst2                  : HYSTERESIS;                     // * [INST] Décodage consigne -> palier, seuil 2
    SpeedStepHyst3                  : HYSTERESIS;                     // * [INST] Décodage consigne -> palier, seuil 3
    SpeedStepHyst4                  : HYSTERESIS;                     // * [INST] Décodage consigne -> palier, seuil 4

    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    EnableRisingEdge                : R_TRIG;                         // . [LOC] Detecteur front montant Enable (D18)
    TonContactorsDropped            : TON;                            // . [LOC] Temporisation retombee contacteurs

    // === VARIABLES LOCALES CALCULÉES ===
    AllContactorsCommandedOff       : BOOL;                           // . [LOC] Tous contacteurs commandes a FALSE
    RampTargetPct                   : REAL;                           // . [LOC] Consigne cible envoyee au SpeedStep
    RampTargetStep                  : INT;                            // . [LOC] Palier demandé par le décodeur amont
    EffectiveSafeStop               : BOOL;                           // . [LOC] SafeStop effectif incluant permis
    ActiveMaxStep                   : INT;                            // . [LOC] Plafond palier actif dynamique
    EffectiveStepRampDelay          : TIME;                           // . [LOC] Cadence palier selon sens, distincte interlock

    // Latches défauts
    SpeedStepConfigFaultLatched     : BOOL;

    // Socle défaut
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS & REARMEMENT
ResetEdge(CLK := Reset);
EnableRisingEdge(CLK := Enable);

IF ResetEdge.Q OR BypassGlobal THEN
    SpeedStepConfigFaultLatched := FALSE;
    ContactorsCheck.StuckClosed := FALSE;
END_IF;

IF Enable AND SpeedStep.ConfigError THEN
    SpeedStepConfigFaultLatched := TRUE;
END_IF;

// FB_Safety_Winch est l'unique proprietaire de la detection contacteur colle.
// FB_Winch conserve le champ public pour compatibilite IHM/Troubleshooting,
// mais ne produit plus ce defaut.
instCauses[1].Active   := FALSE;
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Contacteur colle gere par FB_Safety_Winch (T181-08)';

instCauses[2].Active   := SpeedStepConfigFaultLatched;
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Configuration table des paliers vitesse invalide';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable THEN
    SpeedStep(Enable := FALSE, SpeedStepReq := 0, Table := SpeedStepTable);
    DirectionInterlock(Enable := FALSE, EnableRising := FALSE, ReqDirection := 0,
                       ChangeDelayUp := DirectionInterlockDelayAscent,
                       ChangeDelayDown := DirectionInterlockDelayDescent);
    StepShaper(Enable := FALSE, TargetStep := 0, StepRampDelay := StepRampDelayAscent);
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    RequestedStep := 0;
    StepNumber := StepShaper.ShapedStep;
    CommandedDirection := DirectionInterlock.CommandedDirection;
    DirectionChangePending := DirectionInterlock.DirectionChangePending;
    TonContactorsDropped(IN := FALSE);
    ContactorsCheck.Command := FALSE;
    ContactorsCheck.Feedback := NOT FwdRevSpeedFeedbackOff;
    InTopSlowdownZone := FALSE;
    InBottomSlowdownZone := FALSE;
    Ready := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Permis et zones de ralentissement"}
EffectiveSafeStop := SafeStop OR (Direction > 0 AND NOT AscentPermit) OR (Direction < 0 AND NOT DescendPermit);

InTopSlowdownZone := Homed AND NOT HomingSuspect AND (CablePosM >= (TopLimitM - CfgSlowdownDistanceM));
InBottomSlowdownZone := Homed AND NOT HomingSuspect AND (CablePosM <= (BottomLimitM + CfgSlowdownDistanceM));

IF Direction > 0 THEN
    ActiveMaxStep := MaxStepAscent;
    IF InTopSlowdownZone THEN
        ActiveMaxStep := MIN(ActiveMaxStep, CfgSlowdownMaxStep);
    END_IF;
ELSIF Direction < 0 THEN
    ActiveMaxStep := CfgMaxStepDescente;
    IF InBottomSlowdownZone THEN
        ActiveMaxStep := MIN(ActiveMaxStep, CfgSlowdownMaxStep);
    END_IF;
ELSE
    ActiveMaxStep := MaxStepAscent;
END_IF;

IF HomingApproachActive THEN
    ActiveMaxStep := 1;
END_IF;
{endregion}

{region "§4 Interlock direction"}
// 🔀 4. INTERLOCK DIRECTION (extrait dans FB_WinchDirectionInterlock, D18)
DirectionInterlock(
    Enable := (StepNumber = 0) AND FwdRevSpeedFeedbackOff,
    EnableRising := EnableRisingEdge.Q,
    ReqDirection := Direction,
    ChangeDelayUp := DirectionInterlockDelayAscent,
    ChangeDelayDown := DirectionInterlockDelayDescent
);
CommandedDirection := DirectionInterlock.CommandedDirection;
DirectionChangePending := DirectionInterlock.DirectionChangePending;
DirectionChangeDelayElapsed := DirectionInterlock.DelayElapsed;
{endregion}

{region "§5 Paliers vitesse et contacteurs"}
IF DirectionChangePending OR (Direction = 0) OR EffectiveSafeStop OR NOT StartStop THEN
    RampTargetPct := 0.0;
ELSE
    RampTargetPct := LIMIT(0.0, SpeedTgt_Pct, 100.0);
END_IF;

// Décodage consigne % -> palier conservé ici, immédiatement en amont du
// décodeur contacteurs. FB_SpeedStep ne reçoit plus que le palier discret.
SpeedStepHyst1(IN := REAL_TO_INT(RampTargetPct), HIGH := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[1] + SpeedStepHystMargin), LOW := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[1] - SpeedStepHystMargin));
SpeedStepHyst2(IN := REAL_TO_INT(RampTargetPct), HIGH := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[2] + SpeedStepHystMargin), LOW := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[2] - SpeedStepHystMargin));
SpeedStepHyst3(IN := REAL_TO_INT(RampTargetPct), HIGH := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[3] + SpeedStepHystMargin), LOW := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[3] - SpeedStepHystMargin));
SpeedStepHyst4(IN := REAL_TO_INT(RampTargetPct), HIGH := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[4] + SpeedStepHystMargin), LOW := REAL_TO_INT(SpeedStepTable.StepThreshold_Pct[4] - SpeedStepHystMargin));

IF RampTargetPct <= 0.1 THEN
    RampTargetStep := 0;
ELSE
    RampTargetStep := 1;
    IF NOT SpeedStepHyst1.OUT THEN RampTargetStep := 2; END_IF;
    IF NOT SpeedStepHyst2.OUT THEN RampTargetStep := 3; END_IF;
    IF NOT SpeedStepHyst3.OUT THEN RampTargetStep := 4; END_IF;
    IF NOT SpeedStepHyst4.OUT THEN RampTargetStep := 5; END_IF;
END_IF;

SpeedStep(
    Enable := (RampTargetPct > 0.1),
    SpeedStepReq := RampTargetStep,
    Table := SpeedStepTable,
    MaxStepNumber := ActiveMaxStep
);
RequestedStep := SpeedStep.StepNumber;

// ⚙️ Cadencement de palier (extrait dans FB_WinchStepShaper, D10).
// Les deux cadences historiques sont preservees sans reutiliser les delais
// d'interlock direction : 1 s en montee, 500 ms en descente.
IF CommandedDirection = -1 THEN
    EffectiveStepRampDelay := StepRampDelayDescente;
ELSE
    EffectiveStepRampDelay := StepRampDelayAscent;
END_IF;
StepShaper(
    Enable := Enable,
    TargetStep := RequestedStep,
    StepRampDelay := EffectiveStepRampDelay
);
StepNumber := StepShaper.ShapedStep;
BusinessStepDelayElapsed := StepShaper.StepDelayElapsed;
SpeedGuardLimited := FALSE; // Garde-fou vitesse gere hors de ce FB

IF StepNumber > 0 AND CommandedDirection = 1 THEN
    RelayFwd := TRUE;
    RelayRev := FALSE;
ELSIF StepNumber > 0 AND CommandedDirection = -1 THEN
    RelayFwd := FALSE;
    RelayRev := TRUE;
ELSE
    RelayFwd := FALSE;
    RelayRev := FALSE;
END_IF;

Contactor1 := (StepNumber = 1);
Contactor2 := (StepNumber = 2);
Contactor3 := (StepNumber = 3);
Contactor4 := (StepNumber = 4);

AllContactorsCommandedOff := (NOT RelayFwd) AND (NOT RelayRev)
                             AND (NOT Contactor1) AND (NOT Contactor2) AND (NOT Contactor3) AND (NOT Contactor4);

ContactorsCheck.Command  := NOT AllContactorsCommandedOff;
ContactorsCheck.Feedback := NOT FwdRevSpeedFeedbackOff;
TonContactorsDropped(IN := FALSE, PT := ContactorFeedbackTimeout);
ContactorsCheck.StuckClosed := FALSE; // proprietaire unique : FB_Safety_Winch
ContactorsCheck.StuckOpen := FALSE;

IF Fault.Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_IF;
{endregion}

END_FUNCTION_BLOCK

(* =======================================================================
   🪝 FB_Winch — Directeur d'un treuil individuel (M1 / M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Pilotage d'un treuil individuel (contacteurs de sens et de vitesse)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : FB de mouvement (Enable, SafeStop, RunRequest via WinchRequest)
   🔒 Sécurité : Interlock inversion de sens et gestion des autorisations
   🔧 Interface plate → structs (WinchRequest / Sensors / Config),
      logique interne conservée (comportement bit-identique).
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut (front)
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Statut contacteur de ligne / puissance

    // === REQUÊTE D'AXE (struct) ===
    WinchRequest                    : ST_fbWinch_Req;                  // --> [REQ] RunRequest + 2 bits de sens, palier et limites

    // === MESURES ET FEEDBACKS (struct) ===
    Sensors                         : ST_fbWinch_Sensors;             // --> [HW] Position, referencement, contacteurs, vitesse

    // === CONFIGURATION STATIQUE (struct) ===
    Config                          : ST_fbWinch_Cfg;                 // --> [CFG] Table paliers, delais, ralentissement

    // === SECOURS ET PERMIS DE SÉCURITÉ ===
    SafeStop                        : BOOL;                           // --> [SAFE] Arret rapide de securite
    DescendPermit                   : BOOL := FALSE;                 // --> [SAFE] Permis de descente (mou de cable)
    AscentPermit                    : BOOL := FALSE;                 // --> [SAFE] Permis de montee (fin de course haut)

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
    CommandedAscent                 : BOOL;                           // <-- [DIAG] Sens interne mémorisé : montée
    CommandedDescend                : BOOL;                           // <-- [DIAG] Sens interne mémorisé : descente
    RequestConflict                 : BOOL;                           // <-- [DIAG] Double demande de sens détectée
    DirectionChangeDelayElapsed     : TIME;                           // <-- [DIAG] Ecoule delai changement de sens
    DirectionChangePending          : BOOL;                           // <-- [DIAG] Changement de sens en attente

    // === INTENTION DE MAINTIEN DU CONTACTEUR DE SENS (§3bis) ===
    SenseHoldRequest                : BOOL;                           // <-- [ACT] Demande a la barriere finale de TENIR le contacteur de sens apres chute de palier a 0 (inertie moteur), bornee par T_hold_internal
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    SpeedStep                       : FB_SpeedStep;                   // * [INST] Decodage paliers vitesse
    DirectionInterlock              : FB_WinchDirectionInterlock;     // * [INST] Interlock changement de sens (D18)
    StepShaper                      : FB_WinchStepShaper;             // * [INST] Cadencement de palier (D10)

    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    EnableRisingEdge                : R_TRIG;                         // . [LOC] Detecteur front montant Enable (D18)
    TonContactorsDropped            : TON;                            // . [LOC] Temporisation retombee contacteurs

    // === VARIABLES LOCALES CALCULÉES ===
    AllContactorsCommandedOff       : BOOL;                           // . [LOC] Tous contacteurs commandes a FALSE
    RampTargetStep                  : INT;                            // . [LOC] Palier demandé par l'arbitrage amont
    EffectiveSafeStop               : BOOL;                           // . [LOC] SafeStop effectif incluant permis
    DirectionConflict               : BOOL;                           // . [LOC] Les deux demandes de sens sont actives
    ActiveMaxStep                   : INT;                            // . [LOC] Plafond palier actif dynamique
    EffectiveStepRampDelay          : TIME;                           // . [LOC] Cadence palier selon sens, distincte interlock

    // === MAINTIEN DU CONTACTEUR DE SENS (§3bis) ===
    SenseHoldTimer                  : TON;                            // . [LOC] Garde interne T_hold_internal (< MaxSenseHoldTime barriere)
    SenseHoldActiveInt              : BOOL;                           // . [LOC] Maintien de sens interne en cours
    PrevStepNumber                  : INT;                            // . [LOC] Palier temporise du scan precedent (detection chute a 0)
    SenseHoldHardCut                : BOOL;                           // . [LOC] Coupure dure active (interdit tout maintien)

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
instCauses[1].Texte    := 'Contacteur colle gere par FB_Safety_Winch ';

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
    SpeedStep(Enable := FALSE, SpeedStepReq := 0, Table := Config.SpeedStepTable);
    DirectionInterlock(Enable := FALSE, EnableRising := FALSE, Reset := Reset, ReqAscent := FALSE, ReqDescend := FALSE,
                       ChangeDelayAscent := Config.DirectionInterlockDelayAscent,
                       ChangeDelayDescent := Config.DirectionInterlockDelayDescent);
    StepShaper(Enable := FALSE, TargetStep := 0, StepRampDelay := Config.StepRampDelayAscent);
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    RequestedStep := 0;
    StepNumber := StepShaper.ShapedStep;
    CommandedAscent := DirectionInterlock.CommandedAscent;
    CommandedDescend := DirectionInterlock.CommandedDescend;
    RequestConflict := DirectionInterlock.RequestConflict;
    DirectionChangePending := DirectionInterlock.DirectionChangePending;
    TonContactorsDropped(IN := FALSE);
    ContactorsCheck.Command := FALSE;
    ContactorsCheck.Feedback := NOT Sensors.ContactorsAllOff;
    InTopSlowdownZone := FALSE;
    InBottomSlowdownZone := FALSE;
    // §3bis : coupure dure -> aucun maintien de sens possible, etat interne purge.
    SenseHoldRequest := FALSE;
    SenseHoldActiveInt := FALSE;
    SenseHoldTimer(IN := FALSE, PT := T#900ms);
    PrevStepNumber := 0;
    Ready := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Permis et zones de ralentissement"}
DirectionConflict := WinchRequest.ReqAscent AND WinchRequest.ReqDescend;
EffectiveSafeStop := SafeStop OR DirectionConflict
                     OR (WinchRequest.ReqAscent AND NOT AscentPermit)
                     OR (WinchRequest.ReqDescend AND NOT DescendPermit);

InTopSlowdownZone := Sensors.Homed AND NOT Sensors.HomingSuspect AND (Sensors.CablePosM >= (WinchRequest.TopLimitM - Config.SlowdownDistance_M));
InBottomSlowdownZone := Sensors.Homed AND NOT Sensors.HomingSuspect AND (Sensors.CablePosM <= (WinchRequest.BottomLimitM + Config.SlowdownDistance_M));

IF WinchRequest.ReqAscent AND NOT WinchRequest.ReqDescend THEN
    ActiveMaxStep := WinchRequest.MaxStepUp;
    IF InTopSlowdownZone THEN
        ActiveMaxStep := MIN(ActiveMaxStep, Config.SlowdownMaxStep);
    END_IF;
ELSIF WinchRequest.ReqDescend AND NOT WinchRequest.ReqAscent THEN
    ActiveMaxStep := WinchRequest.MaxStepDown;
    IF InBottomSlowdownZone THEN
        ActiveMaxStep := MIN(ActiveMaxStep, Config.SlowdownMaxStep);
    END_IF;
ELSE
    ActiveMaxStep := WinchRequest.MaxStepUp;
END_IF;

IF WinchRequest.HomingApproachActive THEN
    ActiveMaxStep := 1;
END_IF;
{endregion}

{region "§4 Interlock direction"}
// 🔀 4. INTERLOCK DIRECTION (extrait dans FB_WinchDirectionInterlock, D18)
DirectionInterlock(
    Enable := (StepNumber = 0) AND Sensors.ContactorsAllOff,
    EnableRising := EnableRisingEdge.Q,
    Reset := Reset,
    ReqAscent := WinchRequest.ReqAscent,
    ReqDescend := WinchRequest.ReqDescend,
    ChangeDelayAscent := Config.DirectionInterlockDelayAscent,
    ChangeDelayDescent := Config.DirectionInterlockDelayDescent
);
CommandedAscent := DirectionInterlock.CommandedAscent;
CommandedDescend := DirectionInterlock.CommandedDescend;
RequestConflict := DirectionInterlock.RequestConflict;
DirectionChangePending := DirectionInterlock.DirectionChangePending;
DirectionChangeDelayElapsed := DirectionInterlock.DelayElapsed;
{endregion}

{region "§5 Paliers vitesse et contacteurs"}
// -B : la consigne est désormais un PALIER discret (WinchRequest.SpeedStepReq,
// 1..5, 0 = arrêt) produit par l'arbitrage. Plus de décodage %→palier ici.
IF DirectionChangePending OR NOT (WinchRequest.ReqAscent OR WinchRequest.ReqDescend) OR EffectiveSafeStop OR NOT WinchRequest.RunRequest THEN
    RampTargetStep := 0;
ELSE
    RampTargetStep := WinchRequest.SpeedStepReq;
END_IF;

SpeedStep(
    Enable := (RampTargetStep > 0),
    SpeedStepReq := RampTargetStep,
    Table := Config.SpeedStepTable,
    MaxStepNumber := ActiveMaxStep
);
RequestedStep := SpeedStep.StepNumber;

// 🛡️ Garde-fou vitesse : bride le palier demande si la vitesse n'est pas stable
// (SpeedGuardReady=FALSE -> palier 1) ou si la bande mesuree est inferieure au
// palier demande (pas de passage aux paliers superieurs sans vitesse confirmee).
SpeedGuardLimited := FALSE;
IF Sensors.SpeedGuardEnable THEN
    IF NOT Sensors.SpeedGuardReady THEN
        IF RequestedStep > 1 THEN
            RequestedStep := 1;
            SpeedGuardLimited := TRUE;
        END_IF;
    ELSIF (Sensors.MeasuredSpeedBand >= 1) AND (Sensors.MeasuredSpeedBand <= 5) AND (RequestedStep > Sensors.MeasuredSpeedBand) THEN
        RequestedStep := Sensors.MeasuredSpeedBand;
        SpeedGuardLimited := TRUE;
    END_IF;
END_IF;

// 🤿 Plancher palier descente -- plongee Kobold.
// Injecte MinStepDown sur la CIBLE (RequestedStep, consommee par le shaper ci-dessous),
// JAMAIS sur StepNumber directement. Actif uniquement en descente commandee
// ET NON bloquee par un arret/permis (NOT EffectiveSafeStop) : un permis descente FALSE
// doit interdire physiquement le mouvement, sans re-atterrissage du plancher.
// (RunRequest AND ReqDescend) : relache joystick (RunRequest=FALSE) -> aucun plancher,
// l'arret franc RequestedStep=0 / RampTargetStep=0 est preserve.
// Regle d'agregation : le PLAFOND GAGNE -- si le plancher depasse le plafond courant
// ActiveMaxStep (ex. SlowdownMaxStep -> palier 1 en bordure basse), on borne au plafond.
IF WinchRequest.RunRequest AND WinchRequest.ReqDescend AND NOT WinchRequest.ReqAscent
   AND (WinchRequest.MinStepDown > 0) AND NOT EffectiveSafeStop THEN
    IF RequestedStep < WinchRequest.MinStepDown THEN
        RequestedStep := WinchRequest.MinStepDown;
    END_IF;
    IF RequestedStep > ActiveMaxStep THEN
        RequestedStep := ActiveMaxStep;
    END_IF;
END_IF;

// ⚙️ Cadencement de palier (extrait dans FB_WinchStepShaper, D10).
// Les deux cadences historiques sont preservees sans reutiliser les delais
// d'interlock direction : 1 s en montee, 500 ms en descente.
IF CommandedDescend THEN
    EffectiveStepRampDelay := Config.StepRampDelayDescent;
ELSE
    EffectiveStepRampDelay := Config.StepRampDelayAscent;
END_IF;
StepShaper(
    Enable := Enable,
    TargetStep := RequestedStep,
    StepRampDelay := EffectiveStepRampDelay
);
StepNumber := StepShaper.ShapedStep;
BusinessStepDelayElapsed := StepShaper.StepDelayElapsed;

IF StepNumber > 0 AND CommandedAscent THEN
    RelayFwd := TRUE;
    RelayRev := FALSE;
ELSIF StepNumber > 0 AND CommandedDescend THEN
    RelayFwd := FALSE;
    RelayRev := TRUE;
ELSE
    RelayFwd := FALSE;
    RelayRev := FALSE;
END_IF;

// 🛡️ FIX contacteurs (audit CONTACTEURS_2026-08-31) + SOLUTION : ré-émettre les
// contacteurs depuis FB_SpeedStep (décodage TABLE ST_SpeedStepTable cumulatif :
// P1=0, P2={K1}, P3={K1,K2}, P4={K1,K2,K3}, P5={K1,K2,K3,K4}) sur le palier SHAPÉ,
// au lieu de l'ancien décodage one-hot exclusif (ContactorN := StepNumber=N) qui
// éteignait les paliers inférieurs et ne couvrait pas le palier 5.
SpeedStep(
    Enable          := (StepNumber > 0),
    SpeedStepReq    := StepNumber,
    Table           := Config.SpeedStepTable,
    MaxStepNumber   := ActiveMaxStep
);
Contactor1 := SpeedStep.Contactor1;
Contactor2 := SpeedStep.Contactor2;
Contactor3 := SpeedStep.Contactor3;
Contactor4 := SpeedStep.Contactor4;

AllContactorsCommandedOff := (NOT RelayFwd) AND (NOT RelayRev)
                             AND (NOT Contactor1) AND (NOT Contactor2) AND (NOT Contactor3) AND (NOT Contactor4);

ContactorsCheck.Command  := NOT AllContactorsCommandedOff;
ContactorsCheck.Feedback := NOT Sensors.ContactorsAllOff;
TonContactorsDropped(IN := FALSE, PT := Config.ContactorFeedbackTimeout);
ContactorsCheck.StuckClosed := FALSE; // force a FALSE (Phase 0) : detection contacteur colle produite par FB_Safety_Winch, re-alimentee a la phase suivante
ContactorsCheck.StuckOpen := FALSE;

IF Fault.Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_IF;
{endregion}

{region "§5bis Intention de maintien du contacteur de sens (§3bis)"}
// Quand le palier temporise StepNumber vient de retomber a 0 alors qu'un sens etait
// commande, FB_Winch DEMANDE a la barriere finale (FB_WinchOutputInterlock) de TENIR
// le contacteur de sens le temps que le moteur ralentisse (inertie). Borne par
// T_hold_internal (garde interne, < MaxSenseHoldTime de la barriere = T#1s).
// Coupures dures -> retombee immediate, jamais de maintien (SafeStop / defaut / perte
// puissance / NOT Enable geree a la gate §2).
SenseHoldHardCut := (NOT PowerContactorEngaged) OR EffectiveSafeStop OR Fault.Error;

IF SenseHoldHardCut THEN
    SenseHoldActiveInt := FALSE;
ELSIF (PrevStepNumber > 0) AND (StepNumber = 0) AND (CommandedAscent OR CommandedDescend) THEN
    SenseHoldActiveInt := TRUE;   // front de chute de palier a 0 avec sens encore actif
END_IF;

// T_hold_internal PROVISOIRE essai site (base physique : inertie moteur + chute de couple) ;
// tenu < MaxSenseHoldTime de FB_WinchOutputInterlock pour que la barriere garde le dernier mot.
SenseHoldTimer(IN := SenseHoldActiveInt, PT := T#900ms);
IF SenseHoldTimer.Q OR (StepNumber > 0) THEN
    SenseHoldActiveInt := FALSE;  // borne de temps atteinte, ou nouveau mouvement demande
END_IF;

SenseHoldRequest := SenseHoldActiveInt AND NOT SenseHoldHardCut;
PrevStepNumber := StepNumber;
{endregion}

END_FUNCTION_BLOCK

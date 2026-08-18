(* =======================================================================
   🪝 FB_Winch — Directeur d'un treuil individuel (M1 / M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Pilotage d'un treuil individuel (contacteurs de sens et de vitesse)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 Interface : FB de mouvement (Enable, SafeStop, StartStop)
   🔒 Sécurité : Interlock inversion de sens et gestion des autorisations
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    StartStop                       : BOOL;                           // --> [CMD] Ordre de marche/arret mouvement
    Direction                       : INT;                            // --> [CMD] Sens demande (-1: Descente, 0: Stop, 1: Montee)
    SpeedRefPct                     : REAL;                           // --> [CMD] Consigne vitesse % (0.0 a 100.0)
    Mode                            : E_Mode;                         // --> [CMD] Mode d'exploitation actif

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
    Busy                            : BOOL;                           // <-- [STAT] Mouvement en cours
    Done                            : BOOL;                           // <-- [STAT] Action terminee
    Error                           : BOOL;                           // <-- [STAT] Synthese defaut
    ErrorId                         : WORD;                           // <-- [DIAG] Code erreur bitmask
    State                           : E_State;                        // <-- [STAT] Etat courant machine d'etat FB
    StateAtError                    : E_State;                        // <-- [DIAG] Etat memorise lors du dernier defaut

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
    CycleTimeCalc                   : FB_CycleTime;                   // * [INST] Calcul temps de cycle

    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur
    DirectionChangeDelay            : TON;                            // . [LOC] Temporisation changement de sens
    TonContactorsDropped            : TON;                            // . [LOC] Temporisation retombee contacteurs
    BusinessStepDelay               : TON;                            // . [LOC] Temporisation hausse de palier

    // === VARIABLES LOCALES CALCULÉES ===
    EffectiveDirectionInterlockDelay: TIME;                           // . [LOC] Delai interlock effectif selon sens
    EffectiveStepDelay              : TIME;                           // . [LOC] Delai palier effectif selon sens
    AllContactorsCommandedOff       : BOOL;                           // . [LOC] Tous contacteurs commandes a FALSE
    RampTargetPct                   : REAL;                           // . [LOC] Consigne cible envoyee au SpeedStep
    EffectiveSafeStop               : BOOL;                           // . [LOC] SafeStop effectif incluant permis
    ActiveMaxStep                   : INT;                            // . [LOC] Plafond palier actif dynamique
    FirstScanDone                   : BOOL;                           // . [LOC] Indicateur premier cycle passe
END_VAR

{region "§1 Gate et initialisation"}
IF NOT Enable OR NOT PowerContactorEngaged THEN
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    SpeedStep(Enable := FALSE, SpeedRefPct := 0.0, Table := SpeedStepTable, HystMargin := SpeedStepHystMargin);
    RequestedStep := SpeedStep.StepNumber;
    StepNumber := 0;
    BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    BusinessStepDelayElapsed := T#0ms;
    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelayAscent);
    DirectionChangeDelayElapsed := T#0ms;
    InTopSlowdownZone := FALSE;
    InBottomSlowdownZone := FALSE;
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    ErrorId := 16#0000;
    StepNumber := 0;
    RequestedStep := 0;
    BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    BusinessStepDelayElapsed := T#0ms;
    RETURN;
END_IF;

{endregion}

{region "§2 Preparation commande et limites vitesse"}
Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);

ResetEdge(CLK := Reset);

DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

// Mou de câble / limite basse (DescendPermit=FALSE) et Fin de course haut (AscentPermit=FALSE)
// intégrés à une VRAIE décélération rapide (comme SafeStop) :
// - NOT DescendPermit est INHIBÉ si CommandedDirection = 1 (montée libre pour reprendre le mou)
// - NOT AscentPermit est INHIBÉ si CommandedDirection = -1 (descente libre pour dégager le câble)
EffectiveSafeStop := SafeStop 
                     OR (NOT DescendPermit AND (CommandedDirection <> 1))
                     OR (NOT AscentPermit AND (CommandedDirection <> -1));

RampTargetPct := 0.0;
IF NOT EffectiveSafeStop AND StartStop AND NOT DirectionChangePending THEN
    RampTargetPct := ABS(SpeedRefPct);
END_IF;

// RALENTISSEMENT AUTOMATIQUE SUR BORDURES (si référencé et non suspect) — permet d'approcher
// les fins de course / limites en vitesse lente de façon progressive.
// Plafond palier direct (ActiveMaxStep := 1, ci-dessous, même mécanisme que
// CfgMaxStepDescente/MaxStepAscent) — un treuil ne connaît que 5 paliers de contacteurs, pas une
// vitesse continue ; palier 1 = tous contacteurs de vitesse relâchés = vitesse minimale, sans
// dépendre d'un % qui doit rester sous le 1er seuil de la table pour produire le même effet.
InTopSlowdownZone := Homed AND NOT HomingSuspect
                      AND ((CommandedDirection = 1) OR (Direction = 1))
                      AND (CablePosM >= (TopLimitM - CfgSlowdownDistanceM));
InBottomSlowdownZone := Homed AND NOT HomingSuspect
                         AND ((CommandedDirection = -1) OR (Direction = -1))
                         AND (CablePosM <= (BottomLimitM + CfgSlowdownDistanceM));

// Délai asymétrique selon le sens ENTRANT (Direction) — descente sans effort
// (câble mou/gravité favorable) réengage plus vite que montée (charge en traction). La tempo
// palier se DÉDUIT de cet interlock (+100ms) : jamais besoin de resynchroniser deux réglages.
IF Direction = -1 THEN
    EffectiveDirectionInterlockDelay := DirectionInterlockDelayDescent;
ELSE
    EffectiveDirectionInterlockDelay := DirectionInterlockDelayAscent;
END_IF;
EffectiveStepDelay := EffectiveDirectionInterlockDelay + T#100ms;

IF Direction <> CommandedDirection THEN
    // Démarrage depuis le neutre/arrêt (CommandedDirection = 0) pris en compte IMMÉDIATE (0ms),
    // pas de tempo interlock. L'interlock DirectionChangeDelay (400ms descente / 900ms montée) ne
    // s'applique QU'EN CAS d'inversion active de sens en mouvement (ex: de -1 vers +1 direct).
    IF CommandedDirection = 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
    ELSIF StepNumber = 0 THEN
        DirectionChangeDelay(IN := TRUE, PT := EffectiveDirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
END_IF;
DirectionChangeDelayElapsed := DirectionChangeDelay.ET; // Diagnostic, miroir pur

// Plafond dynamique de palier (CfgMaxStepDescente en descente, Palier 1 si non référencé ou douteux,
// Palier 1 en approche homing, MaxStepAscent en montée normale)
IF NOT Homed OR HomingSuspect THEN
    // Bypass.Global = TRUE → pas de limitation, on applique la règle normale
    IF BypassGlobal THEN
        ActiveMaxStep := SEL(CommandedDirection = -1, MaxStepAscent, CfgMaxStepDescente);
    ELSE
        ActiveMaxStep := 1;
    END_IF;
ELSIF CommandedDirection = -1 THEN
    ActiveMaxStep := CfgMaxStepDescente;
ELSIF (CommandedDirection = 1) AND HomingApproachActive THEN
    ActiveMaxStep := 1;
ELSIF CommandedDirection = 1 THEN
    ActiveMaxStep := MaxStepAscent;
ELSE
    ActiveMaxStep := 5;
END_IF;

// Ralentissement sur bordure (voir plus haut) — plafond palier direct (CfgSlowdownMaxStep,
// défaut 1 = vitesse mini, réglable IHM), appliqué APRÈS le calcul normal ci-dessus via MIN
// (ne peut qu'abaisser, jamais relever le plafond déjà décidé par ailleurs — ex.
// CfgMaxStepDescente déjà plus restrictif).
IF InTopSlowdownZone OR InBottomSlowdownZone THEN
    ActiveMaxStep := MIN(ActiveMaxStep, CfgSlowdownMaxStep);
END_IF;

{endregion}

{region "§3 Selection et temporisation paliers"}
SpeedStep(Enable := (RampTargetPct > 0.1), SpeedRefPct := RampTargetPct,
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin,
          MaxStepNumber := ActiveMaxStep,
          MeasuredSpeedBand := MeasuredSpeedBand,
          SpeedGuardEnable := SpeedGuardEnable,
          SpeedGuardReady := SpeedGuardReady);
// 🪜 Tempo métier nominale : le décollage initial de StepNumber=0 vers 1 est IMMÉDIAT (0ms).
// Toute hausse ultérieure (1->2->3) exige EffectiveStepDelay (interlock + 100ms) et progresse par pas adjacents.
// Toute baisse reste immédiate pour ne jamais retarder un arrêt/safety.
RequestedStep := SpeedStep.StepNumber;
IF RequestedStep > StepNumber THEN
    IF StepNumber = 0 THEN
        StepNumber := 1;
        BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
        BusinessStepDelayElapsed := T#0ms;
    ELSE
        BusinessStepDelay(IN := TRUE, PT := EffectiveStepDelay);
        BusinessStepDelayElapsed := BusinessStepDelay.ET;
        IF BusinessStepDelay.Q THEN
            StepNumber := StepNumber + 1;
            BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
        END_IF;
    END_IF;
ELSE
    BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
    BusinessStepDelayElapsed := BusinessStepDelay.ET;
    StepNumber := RequestedStep;
END_IF;
SpeedGuardLimited := SpeedStep.SpeedGuardLimited;

{endregion}

{region "§4 Commandes contacteurs et sens"}
// Les sorties métier suivent le palier temporisé. FB_Winch/SpeedStepTable reste
// propriétaire unique des combinaisons, y compris les mappings M2 Benne dynamiques.
// FB_WinchOutputInterlock_LD ne fait qu'autoriser ou masquer ces quatre demandes.
CASE StepNumber OF
    1:
        Contactor1 := SpeedStepTable.P1R1; Contactor2 := SpeedStepTable.P1R2;
        Contactor3 := SpeedStepTable.P1R3; Contactor4 := SpeedStepTable.P1R4;
    2:
        Contactor1 := SpeedStepTable.P2R1; Contactor2 := SpeedStepTable.P2R2;
        Contactor3 := SpeedStepTable.P2R3; Contactor4 := SpeedStepTable.P2R4;
    3:
        Contactor1 := SpeedStepTable.P3R1; Contactor2 := SpeedStepTable.P3R2;
        Contactor3 := SpeedStepTable.P3R3; Contactor4 := SpeedStepTable.P3R4;
    4:
        Contactor1 := SpeedStepTable.P4R1; Contactor2 := SpeedStepTable.P4R2;
        Contactor3 := SpeedStepTable.P4R3; Contactor4 := SpeedStepTable.P4R4;
    5:
        Contactor1 := SpeedStepTable.P5R1; Contactor2 := SpeedStepTable.P5R2;
        Contactor3 := SpeedStepTable.P5R3; Contactor4 := SpeedStepTable.P5R4;
ELSE
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_CASE;

// Coupure INSTANTANÉE de tous les contacteurs de vitesse dès que l'opérateur relâche le
// joystick (Direction=0) — ne pas attendre la fin de la rampe de décélération. Sinon,
// StepNumber suivrait la rampe (décélération progressive), gardant les contacteurs de vitesse
// engagés plusieurs secondes après l'ordre d'arrêt.
IF Direction = 0 THEN
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_IF;

// Le sens et la pré-magnétisation suivent la demande brute ; le palier métier
// temporisé reste seul transmis à l'interlock final pour autoriser la puissance.
// ET Direction=1/-1 (demande OPÉRATEUR brute, pas CommandedDirection qui reste au dernier sens
// jusqu'à la retombée de la rampe) — coupure instantanée du contacteur de sens dès le
// relâchement du joystick, même sécurité que ci-dessus.
// Plus de terme BrakeSafetyOk — le frein n'est plus une condition d'engagement des relais de
// sens, c'est l'inverse (voir FB_WinchOutputInterlock_LD §6 : BrakeCmd := RelayFwd OR RelayRev,
// calculé APRÈS ces relais).
RelayFwd := (Direction = 1) AND (CommandedDirection = 1) AND (RequestedStep > 0);
RelayRev := (Direction = -1) AND (CommandedDirection = -1) AND (RequestedStep > 0);

IF NOT DescendPermit THEN
    RelayRev := FALSE;
END_IF;

IF NOT AscentPermit THEN
    RelayFwd := FALSE;
END_IF;

// Vérification UNIQUEMENT à l'arrêt commandé (plus de détail par sens — voir bandeau en-tête).
// AllContactorsCommandedOff = tout ce que FB_Winch commande est à FALSE.
AllContactorsCommandedOff := (NOT RelayFwd) AND (NOT RelayRev)
                             AND (NOT Contactor1) AND (NOT Contactor2) AND (NOT Contactor3) AND (NOT Contactor4);

ContactorsCheck.Command  := NOT AllContactorsCommandedOff;   // TRUE = au moins un contacteur commandé
ContactorsCheck.Feedback := NOT FwdRevSpeedFeedbackOff;      // TRUE = au moins un contacteur pas retombé
TonContactorsDropped(IN := AllContactorsCommandedOff AND NOT FwdRevSpeedFeedbackOff, PT := ContactorFeedbackTimeout);
IF TonContactorsDropped.Q THEN
    ContactorsCheck.StuckClosed := TRUE;
ELSIF ResetEdge.Q THEN
    ContactorsCheck.StuckClosed := FALSE;
END_IF;
ContactorsCheck.StuckOpen := FALSE; // Non applicable avec ce retour (pas de confirmation par sens, voir bandeau)

{endregion}

{region "§5 Diagnostic contacteurs et configuration"}
// 🌐 BYPASS GLOBAL : force ErrorId = 0 et saute toute la logique d'erreur
IF BypassGlobal THEN
    ErrorId := 16#0000;
END_IF;

IF NOT BypassGlobal THEN
// bit0 ErrorId libre — le frein n'est plus surveillé ici, sa cohérence commande/retour vit
// désormais dans FB_WinchOutputInterlock_LD (BrakeFeedback).

// 🧪 Simulation (GVL_Simulation.SensorMxContactorFeedbackIsReal, passé par l'appelant via
// BypassContactorCheck) — sans contacteurs réels câblés/cohérents en essai, StuckClosed
// se déclenche à tort et bloque RelayFwd/RelayRev (voir Error plus bas).
// bit2 (ex-RevContactorCheck) libre/inutilisé, fusionné dans bit1.
IF NOT BypassContactorCheck THEN
    IF ContactorsCheck.StuckClosed THEN
        ErrorId := ErrorId OR 16#0002;
    ELSIF ResetEdge.Q THEN
        ErrorId := ErrorId AND 16#FFFD;
    END_IF;
ELSE
    ErrorId := ErrorId AND 16#FFFD;   // Bypass actif : efface/maintient à 0 le bit1
END_IF;

// 🪜 WINCH-CORE-01 : remonte le défaut de configuration interne de FB_SpeedStep.
// Le bit reste mémorisé après correction de la table ; cause disparue + nouveau front Reset
// sont obligatoires avant de rendre le treuil disponible, conformément à Partie 3 §5.
IF SpeedStep.ConfigError THEN
    ErrorId := ErrorId OR 16#0004;    // bit2 = table/plafond/hystérésis invalide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

END_IF; // fin IF NOT BypassGlobal

{endregion}

{region "§6 Etats et repli defaut"}
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

IF (NOT StartStop OR EffectiveSafeStop OR DirectionChangePending) AND StepNumber > 0 THEN
    State := E_State.STOPPING;
ELSIF StepNumber > 0 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;

IF Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_IF;

{endregion}

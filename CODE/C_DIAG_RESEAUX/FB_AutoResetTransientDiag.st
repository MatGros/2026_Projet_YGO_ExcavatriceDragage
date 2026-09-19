(* =======================================================================
   FB_AutoResetTransientDiag - Acquittement borne des diagnostics transitoires
   =======================================================================
   Responsabilite unique : produire une impulsion de reset pour les FB de
   diagnostic reseau autorises (EtherCAT/CANopen) apres stabilisation.

   ⛔ Ce FB ne reset jamais la chaine AU, les securites mouvement, les codeurs
      de securite, les contacteurs, les freins ou les defauts mecaniques.
   ⛔ Ce FB ne genere aucune commande de mouvement et aucun redemarrage cycle.
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_AutoResetTransientDiag
VAR_INPUT
    Enable                  : BOOL;          // --> [CMD] Activation du service
    StartupEnable           : BOOL;          // --> [CFG] Autorise la sequence au demarrage CPU
    PowerRearmEnable        : BOOL;          // --> [CFG] Autorise la sequence apres front contacteur
    EmergencyChainClosed    : BOOL;          // --> [SAFE] Chaine AU fermee
    PowerContactorEngaged   : BOOL;          // --> [SAFE] Retour contacteur puissance
    PowerCutOffActive       : BOOL;          // --> [SAFE] Coupure puissance active
    MotionActive             : BOOL;         // --> [SAFE] Mouvement ou demande mouvement active
    DiagnosticsStable        : BOOL;         // --> [STAT] Diagnostics reseau operationnels
    Cfg_MaxAttempts          : USINT := 1;   // --> [CFG] Borne 1..3
    Cfg_StabilizationTime     : TIME := T#1s; // --> [CFG] Stabilisation avant impulsion
    Cfg_InterAttemptTime      : TIME := T#1s; // --> [CFG] Intervalle entre impulsions
END_VAR
VAR_OUTPUT
    ResetPulse               : BOOL;         // <-- [CMD] Impulsion vers diagnostics autorises
    SequenceActive           : BOOL;         // <-- [STAT] Sequence en cours
    Lockout                  : BOOL;         // <-- [STAT] Salve terminee ou annulee, attente nouvel evenement
    Cancelled                : BOOL;         // <-- [DIAG] Sequence annulee par une condition de securite
    Phase                    : USINT;        // <-- [DIAG] 0 idle, 1 startup, 2 post-rearmement, 3 lockout
    AttemptCount             : USINT;        // <-- [DIAG] Nombre d impulsions emises
END_VAR
VAR
    PowerRearmEdge           : R_TRIG;       // * [INST] Front contacteur engage
    StabilizationTimer       : TON;          // * [INST] Tempo avant premiere impulsion
    InterAttemptTimer        : TON;          // * [INST] Tempo entre impulsions
    State                    : USINT;        // . [LOC] 0 idle, 1 wait startup, 2 wait rearm, 3 intervalle, 4 lockout
    StartupStarted           : BOOL;        // . [LOC] Sequence startup deja declenchee au boot
    RearmStarted             : BOOL;        // . [LOC] Sequence du front courant deja declenchee
    RearmPending             : BOOL;        // . [LOC] Front rearmement memorise pendant startup
    PendingPhase             : USINT;        // . [LOC] Phase a executer apres stabilisation
    MaxAttemptsEffective     : USINT;        // . [LOC] Borne appliquee 1..3
    SafeCommon               : BOOL;        // . [LOC] Conditions communes d autorisation
END_VAR

// Sorties impulsionnelles : FALSE par defaut, TRUE pendant un seul scan.
ResetPulse := FALSE;
Cancelled := FALSE;

IF NOT Enable THEN
    SequenceActive := FALSE;
    Lockout := FALSE;
    Phase := 0;
    AttemptCount := 0;
    State := 0;
    StartupStarted := FALSE;
    RearmStarted := FALSE;
    RearmPending := FALSE;
    PendingPhase := 0;
    StabilizationTimer(IN := FALSE);
    InterAttemptTimer(IN := FALSE);
    PowerRearmEdge(CLK := FALSE);
    RETURN;
END_IF;

MaxAttemptsEffective := Cfg_MaxAttempts;
IF MaxAttemptsEffective < 1 THEN MaxAttemptsEffective := 1; END_IF;
IF MaxAttemptsEffective > 3 THEN MaxAttemptsEffective := 3; END_IF;

SafeCommon := EmergencyChainClosed AND NOT PowerCutOffActive AND NOT MotionActive;
PowerRearmEdge(CLK := PowerContactorEngaged);

// Le front contacteur ne peut armer qu une seule salve. Une retombee rearme
// uniquement la detection du prochain cycle de puissance.
IF NOT PowerContactorEngaged THEN
    RearmStarted := FALSE;
    RearmPending := FALSE;
END_IF;

// Si le contacteur revient pendant la sequence startup, memoriser le front :
// le rearmement sera traite apres la fin de la sequence startup, jamais perdu.
IF PowerRearmEnable AND PowerRearmEdge.Q AND (State <> 0) AND (State <> 4) THEN
    RearmPending := TRUE;
END_IF;

// Priorite au demarrage CPU. Le contacteur doit etre au repos pour cette phase.
IF (State = 0) AND StartupEnable AND NOT StartupStarted AND SafeCommon AND NOT PowerContactorEngaged THEN
    StartupStarted := TRUE;
    PendingPhase := 1;
    AttemptCount := 0;
    Lockout := FALSE;
    State := 1;
END_IF;

// La phase post-rearmement est declenchee exclusivement sur le front du retour
// contacteur et ne peut pas etre confondue avec le demarrage CPU.
IF (State = 0 OR State = 4) AND PowerRearmEnable AND PowerRearmEdge.Q AND NOT RearmStarted THEN
    RearmStarted := TRUE;
    IF SafeCommon AND PowerContactorEngaged THEN
        PendingPhase := 2;
        AttemptCount := 0;
        Lockout := FALSE;
        State := 2;
    ELSE
        Lockout := TRUE;
        Cancelled := TRUE;
        Phase := 3;
    END_IF;
END_IF;

IF (State = 4) AND PowerRearmEnable AND RearmPending AND NOT RearmStarted
   AND SafeCommon AND PowerContactorEngaged THEN
    RearmPending := FALSE;
    RearmStarted := TRUE;
    PendingPhase := 2;
    AttemptCount := 0;
    Lockout := FALSE;
    State := 2;
END_IF;

// Les deux sequences sont annulees a la moindre condition safety invalide.
IF (State = 1 OR State = 2 OR State = 3) AND NOT SafeCommon THEN
    State := 4;
    Lockout := TRUE;
    Cancelled := TRUE;
END_IF;

// Stabilisation : le timer ne progresse que si les diagnostics sont revenus
// operationnels et si les conditions safety restent valides.
StabilizationTimer(
    IN := (State = 1 OR State = 2) AND SafeCommon AND DiagnosticsStable,
    PT := Cfg_StabilizationTime
);

IF (State = 1 OR State = 2) AND StabilizationTimer.Q THEN
    ResetPulse := TRUE;
    AttemptCount := AttemptCount + 1;
    IF AttemptCount >= MaxAttemptsEffective THEN
        State := 4;
        Lockout := TRUE;
    ELSE
        State := 3;
    END_IF;
END_IF;

// Intervalle inter-impulsions. La condition safety reste re-evaluee au scan.
InterAttemptTimer(IN := (State = 3) AND SafeCommon, PT := Cfg_InterAttemptTime);
IF (State = 3) AND InterAttemptTimer.Q THEN
    State := PendingPhase;
END_IF;

SequenceActive := (State = 1 OR State = 2 OR State = 3);
IF State = 4 THEN
    Phase := 3;
ELSIF SequenceActive THEN
    Phase := PendingPhase;
ELSE
    Phase := 0;
END_IF;

END_FUNCTION_BLOCK

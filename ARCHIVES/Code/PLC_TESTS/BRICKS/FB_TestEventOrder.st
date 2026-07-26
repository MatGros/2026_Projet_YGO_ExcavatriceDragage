FUNCTION_BLOCK FB_TestEventOrder
VAR_INPUT
    Arm       : BOOL;
    EventA    : BOOL;
    EventB    : BOOL;
    TimeoutPT : TIME;
END_VAR
VAR_OUTPUT
    OrderOk   : BOOL;
    Failed    : BOOL;
END_VAR
VAR
    TrigA     : R_TRIG;
    TrigB     : R_TRIG;
    Timer     : TON;
    HasA      : BOOL;
END_VAR
// === IMPLEMENTATION ===
TrigA(CLK := EventA);
TrigB(CLK := EventB);

IF NOT Arm THEN
    OrderOk := FALSE;
    Failed  := FALSE;
    HasA    := FALSE;
    Timer(IN := FALSE);
    RETURN;
END_IF;

// Échec immédiat si B se produit avant A
IF TrigB.Q AND NOT HasA THEN
    Failed  := TRUE;
    OrderOk := FALSE;
END_IF;

// Mémorisation de la survenue de A
IF TrigA.Q AND NOT Failed AND NOT OrderOk THEN
    HasA := TRUE;
END_IF;

// Armement du timeout une fois que A s'est produit
Timer(IN := HasA AND NOT OrderOk AND NOT Failed, PT := TimeoutPT);

IF Timer.Q THEN
    Failed  := TRUE;
    OrderOk := FALSE;
END_IF;

// Validation du succès si B arrive après A et dans les temps
IF HasA AND TrigB.Q AND NOT Failed THEN
    OrderOk := TRUE;
END_IF;

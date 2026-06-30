FUNCTION_BLOCK FB_DiagEthercat
VAR_INPUT
    Enable          : BOOL;       // Activate monitoring
    Reset           : BOOL;       // Fault acknowledgement (rising edge)
    WcState         : BOOL;       // Working Counter (FALSE = valid frame / online)
    SlaveState      : WORD;       // Internal slave state (8 = OP / Operational)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;       // Block operational
    Online          : BOOL;       // Slave present and responding
    Operational     : BOOL;       // Slave in OP mode (valid data)
    Error           : BOOL;       // Fault active
    ErrorId         : WORD;       // Error code (bit0=offline, bit1=not operational)
    StateAtError    : WORD;       // Snapshot of SlaveState at fault instant (frozen until ack)
END_VAR
VAR
    ResetEdge       : R_TRIG;
    LastSlaveState  : WORD;       // Capture state on fault for StateAtError
END_VAR

// 🛑 1. GATE DE SÉCURITÉ
IF NOT Enable THEN
    Ready := FALSE;
    Online := FALSE;
    Operational := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET DÉFAUT (front obligatoire)
ResetEdge(CLK := Reset);

IF ResetEdge.Q THEN
    // Only clear error if cause has disappeared
    IF Online AND Operational THEN
        Error := FALSE;
        ErrorId := 16#0000;
        StateAtError := 0;  // Clear snapshot on successful ack
    END_IF;
END_IF;

// 🔍 3. DIAGNOSTIC ETHERCAT
// WcState à FALSE signifie que le maître communique physiquement avec le nœud
Online := NOT WcState;

// L'état 8 en EtherCAT correspond à l'état "Operational" (échanges cycliques actifs)
Operational := Online AND (SlaveState = 8);

// ⚠️ 4. GESTION DES ERREURS avec snapshot StateAtError
IF NOT Online THEN
    IF NOT Error THEN
        // Transition to error: capture state
        LastSlaveState := SlaveState;
        StateAtError := SlaveState;
    END_IF;
    Error := TRUE;
    ErrorId.0 := TRUE;   // bit0: offline
    ErrorId.1 := FALSE;
ELSIF NOT Operational THEN
    IF NOT Error THEN
        // Transition to error: capture state
        LastSlaveState := SlaveState;
        StateAtError := SlaveState;
    END_IF;
    Error := TRUE;
    ErrorId.0 := FALSE;
    ErrorId.1 := TRUE;   // bit1: not operational
ELSE
    // No error condition
    ErrorId := 16#0000;
END_IF;

END_FUNCTION_BLOCK

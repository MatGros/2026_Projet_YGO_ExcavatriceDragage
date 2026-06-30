FUNCTION_BLOCK FB_DiagCanOpen
VAR_INPUT
    Enable              : BOOL;       // Activate monitoring
    Reset               : BOOL;       // Fault acknowledgement (rising edge)
    BusState            : BUS_STATE;  // CAN bus state enum
    BusDiagAvailable    : BOOL;       // Diagnosis info available
    DeviceState         : DEVICE_STATE; // Joystick CANopen node state
    DevDiagAvailable    : BOOL;       // Device diagnosis available
END_VAR
VAR_OUTPUT
    Ready               : BOOL;       // Block operational
    Error               : BOOL;       // Mirror of (ErrorId <> 0)
    ErrorId             : WORD;       // Bitfield: bit0=bus down, bit1=device not found, bit2=device not operational
    BusOnline           : BOOL;       // Bus physically responds
    BusOperational      : BOOL;       // Bus in RUN state
    JoystickOnline      : BOOL;       // Device present on bus
    JoystickOperational : BOOL;       // Device in NMT Operational state
    CanHealthy          : BOOL;       // BusOperational AND JoystickOperational
END_VAR
VAR
    ResetEdge           : R_TRIG;
END_VAR

// 🛑 1. GATE DE SÉCURITÉ
IF NOT Enable THEN
    Ready := FALSE;
    BusOnline := FALSE;
    BusOperational := FALSE;
    JoystickOnline := FALSE;
    JoystickOperational := FALSE;
    CanHealthy := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET DÉFAUT (front obligatoire)
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (BusOperational AND JoystickOperational) THEN
        ErrorId := 16#0000;
    END_IF;
END_IF;

// 🔍 3. DIAGNOSTIC BUS CAN
// BusState available → check bus health
BusOnline := (BusState <> BUS_STATE.IDLE); // Bus has activity
BusOperational := (BusState = BUS_STATE.RUNNING); // Bus in RUN mode

IF NOT BusOperational THEN
    ErrorId.0 := TRUE; // bit0: bus down
ELSE
    ErrorId.0 := FALSE;
END_IF;

// 🔍 4. DIAGNOSTIC JOYSTICK NODE
// DeviceState check
JoystickOnline := (DeviceState <> DEVICE_STATE.NOT_FOUND);

IF NOT JoystickOnline THEN
    ErrorId.1 := TRUE; // bit1: device not found
ELSE
    ErrorId.1 := FALSE;
END_IF;

// Device operational state (NMT Operational in CANopen)
JoystickOperational := (DeviceState = DEVICE_STATE.RUNNING);

IF NOT JoystickOperational AND JoystickOnline THEN
    ErrorId.2 := TRUE; // bit2: device not operational
ELSE
    IF JoystickOnline THEN
        ErrorId.2 := FALSE;
    END_IF;
END_IF;

// 🧾 5. CONSOLIDATED OUTPUT
CanHealthy := BusOperational AND JoystickOperational;
Error := (ErrorId <> 16#0000);

END_FUNCTION_BLOCK

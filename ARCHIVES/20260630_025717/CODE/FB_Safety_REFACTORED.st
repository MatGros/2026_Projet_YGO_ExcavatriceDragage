// FB_Safety — Refactored version
// Granular equipment availability inputs instead of single EthercatOk BOOL
// ErrorId with per-equipment bits

FUNCTION_BLOCK FB_Safety
VAR_INPUT
    Enable              : BOOL;       // Activate monitoring
    Reset               : BOOL;       // Fault acknowledgement
    EStopArmed          : BOOL;       // Emergency stop TOR (TRUE = OK)
    CanOnline           : BOOL;       // CAN bus operational
    CanOperational      : BOOL;       // CAN bus running
    JoystickAvailable   : BOOL;       // Joystick online and operational
    EncoderM1Available  : BOOL;       // Encoder M1 online and operational
    EncoderM2Available  : BOOL;       // Encoder M2 online and operational
    VariateurAvailable  : BOOL;       // Variateur online and operational
END_VAR
VAR_OUTPUT
    Ready               : BOOL;       // Logique de sécurité opérationnelle
    SafeStop            : BOOL;       // Ordre d'arrêt absolu (TRUE = STOP IMMÉDIAT)
    SafetyOk            : BOOL;       // Feu vert global (TRUE = Autorisation de bouger)
    Error               : BOOL;       // Présence anomalie sécurité
    ErrorId             : WORD;       // Bitfield code de cause
END_VAR
VAR
    ResetEdge           : R_TRIG;
END_VAR

// 1. GATE AUTOMATE
IF NOT Enable THEN
    Ready := FALSE;
    SafeStop := TRUE;             // Sécurité par défaut : arrêt forcé
    SafetyOk := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 2. RESET DÉFAUTS (front obligatoire)
ResetEdge(CLK := Reset);

IF ResetEdge.Q THEN
    // Clear only if all conditions are met
    IF EStopArmed AND CanOperational AND JoystickAvailable AND
       EncoderM1Available AND EncoderM2Available AND VariateurAvailable THEN
        Error := FALSE;
        ErrorId := 16#0000;
    END_IF;
END_IF;

// 3. LOGIQUE FAIL-SAFE (Perte de signal = Danger)
// bit0 = Emergency stop activated
IF NOT EStopArmed THEN
    ErrorId.0 := TRUE;
ELSE
    ErrorId.0 := FALSE;
END_IF;

// bit1 = CAN bus down
IF NOT CanOperational THEN
    ErrorId.1 := TRUE;
ELSE
    ErrorId.1 := FALSE;
END_IF;

// bit2 = Joystick not available
IF NOT JoystickAvailable THEN
    ErrorId.2 := TRUE;
ELSE
    ErrorId.2 := FALSE;
END_IF;

// bit3 = Encoder M1 down
IF NOT EncoderM1Available THEN
    ErrorId.3 := TRUE;
ELSE
    ErrorId.3 := FALSE;
END_IF;

// bit4 = Encoder M2 down
IF NOT EncoderM2Available THEN
    ErrorId.4 := TRUE;
ELSE
    ErrorId.4 := FALSE;
END_IF;

// bit5 = Variateur down
IF NOT VariateurAvailable THEN
    ErrorId.5 := TRUE;
ELSE
    ErrorId.5 := FALSE;
END_IF;

// 4. ARBITRAGE DES SORTIES TRANSVERSES
Error := (ErrorId &lt;&gt; 16#0000);

// SafeStop est l'actionneur logiciel (TRUE = On coupe tout)
SafeStop := Error;

// SafetyOk est le feu vert (TRUE = Tout est sain)
SafetyOk := NOT Error;

END_FUNCTION_BLOCK

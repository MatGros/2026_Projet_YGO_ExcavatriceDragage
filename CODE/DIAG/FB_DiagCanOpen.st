(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagCanOpen — Diagnostic de communication bus CANopen / Joystick
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_DiagCanOpen
VAR_INPUT
    Enable          : BOOL;        (* Active la surveillance CAN *)
    Reset           : BOOL;        (* Front d'acquittement des défauts *)
    CanOnline       : BOOL;        (* Trame joystick reçue (TRUE = OK) *)
    CanOperational  : BOOL;        (* Joystick en mode opérationnel (TRUE = OK) *)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;        (* Logique de surveillance active *)
    Busy            : BOOL;        (* Non utilisé (conformité interface) *)
    Done            : BOOL;        (* Non utilisé *)
    Error           : BOOL;        (* Présence anomalie de communication *)
    ErrorId         : WORD;        (* Code défaut global résumé *)
    State           : E_DiagState; (* Phase courante du cycle de diag *)
    StateAtError    : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    busCanOpen      : ST_DeviceDiag;  (* Diagnostics bus CANopen *)
    Joystick        : ST_DeviceDiag;  (* Diagnostics esclave Joystick *)
END_VAR
VAR
    ResetEdge       : R_TRIG;      (* Détecteur front de reset *)
END_VAR

// 🛑 1. GATE : Désactivation logique si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_DiagState.DISABLED;
    Joystick.State := E_DiagState.DISABLED;
    Joystick.Online := FALSE;
    Joystick.Operational := FALSE;
    Joystick.Error := FALSE;
    Joystick.ErrorId := 16#0000;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CanOnline AND CanOperational) THEN
        Joystick.ErrorId := 16#0000;
        StateAtError := E_DiagState.DISABLED;
    END_IF;
END_IF;

// 🔍 3. DIAGNOSTIC JOYSTICK
// Bit 0 : Perte de communication CAN
IF NOT CanOnline THEN
    Joystick.ErrorId := 16#0001;  (* Perte liaison CAN joystick *)
    Joystick.Online := FALSE;
ELSE
    Joystick.Online := TRUE;
    IF ResetEdge.Q THEN
        Joystick.ErrorId := Joystick.ErrorId AND 16#FFFE;
    END_IF;
END_IF;

// Bit 1 : Mode non-opérationnel (esclave CANopen en pré-op ou défaut)
IF NOT CanOperational THEN
    Joystick.ErrorId := Joystick.ErrorId OR 16#0002;  (* Joystick pas opérationnel *)
    Joystick.Operational := FALSE;
ELSE
    Joystick.Operational := TRUE;
    IF ResetEdge.Q THEN
        Joystick.ErrorId := Joystick.ErrorId AND 16#FFFD;
    END_IF;
END_IF;

// 🚦 4. MACHINE D'ÉTAT JOYSTICK
IF Joystick.ErrorId <> 0 THEN
    Joystick.State := E_DiagState.ERROR;
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
ELSIF NOT (Joystick.Online AND Joystick.Operational) THEN
    Joystick.State := E_DiagState.INIT;
else
    Joystick.State := E_DiagState.READY;
END_IF;

State := Joystick.State;

// 📤 5. SORTIES GLOBALES
Joystick.Error := (Joystick.ErrorId <> 0);
Error := Joystick.Error;
ErrorId := Joystick.ErrorId;

busCanOpen.Operational := CanOnline;
busCanOpen.Online := CanOnline;

// Briques génériques pour conformité standard
Busy := FALSE;
Done := FALSE;

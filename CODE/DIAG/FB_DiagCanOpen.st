(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagCanOpen — Diagnostic de communication bus CANopen / Joystick
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_DiagCanOpen
VAR_INPUT
    Enable          : BOOL;        (* Active la surveillance CAN *)
    Reset           : BOOL;        (* Front d'acquittement des défauts *)
    CANbusOnline    : BOOL;        (* État du bus CANopen (TRUE = OK) *)
    DeviceJoystickOnline: BOOL;    (* Joystick en ligne / opérationnel (TRUE = OK) *)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;        (* Logique de surveillance active *)
    Busy            : BOOL;        (* Non utilisé (conformité interface) *)
    Done            : BOOL;        (* Non utilisé *)
    Error           : BOOL;        (* Présence anomalie de communication *)
    ErrorId         : WORD;        (* Code défaut global résumé *)
    State           : E_DiagState; (* Phase courante du cycle de diag *)
    StateAtError    : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    DeviceCanOpenMaster : ST_DiagDevice;  (* Diagnostics bus CANopen *)
    DeviceJoystick  : ST_DiagDevice;  (* Diagnostics esclave Joystick *)
END_VAR
VAR
    ResetEdge       : R_TRIG;      (* Détecteur front de reset *)
END_VAR

// 🛑 1. GATE : Désactivation logique si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_DiagState.DISABLED;
    DeviceJoystick.State := E_DiagState.DISABLED;
    DeviceJoystick.Online := FALSE;
    DeviceJoystick.Operational := FALSE;
    DeviceJoystick.Error := FALSE;
    DeviceJoystick.ErrorId := 16#0000;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CANbusOnline AND DeviceJoystickOnline) THEN
        DeviceJoystick.ErrorId := 16#0000;
        StateAtError := E_DiagState.DISABLED;
    END_IF;
END_IF;

// 🔍 3. DIAGNOSTIC JOYSTICK
// Bit 0 : Perte de communication CAN
IF NOT CANbusOnline THEN
    DeviceJoystick.ErrorId := 16#0001;  (* Perte liaison CAN joystick *)
    DeviceJoystick.Online := FALSE;
ELSE
    DeviceJoystick.Online := TRUE;
    IF ResetEdge.Q THEN
        DeviceJoystick.ErrorId := DeviceJoystick.ErrorId AND 16#FFFE;
    END_IF;
END_IF;

// Bit 1 : Mode non-opérationnel (esclave CANopen en pré-op ou défaut)
IF NOT DeviceJoystickOnline THEN
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId OR 16#0002;  (* Joystick pas opérationnel *)
    DeviceJoystick.Operational := FALSE;
ELSE
    DeviceJoystick.Operational := TRUE;
    IF ResetEdge.Q THEN
        DeviceJoystick.ErrorId := DeviceJoystick.ErrorId AND 16#FFFD;
    END_IF;
END_IF;

// 🚦 4. MACHINE D'ÉTAT JOYSTICK
// REX 2026-07-08 : correction de la précédence d'affichage IHM des états d'erreur.
IF DeviceJoystick.ErrorId <> 0 THEN
    DeviceJoystick.State := E_DiagState.ERROR;
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
ELSIF NOT (DeviceJoystick.Online AND DeviceJoystick.Operational) THEN
    DeviceJoystick.State := E_DiagState.INIT;
ELSE
    DeviceJoystick.State := E_DiagState.READY;
END_IF;

State := DeviceJoystick.State;

// 📤 5. SORTIES GLOBALES
DeviceJoystick.Error := (DeviceJoystick.ErrorId <> 0);
Error := DeviceJoystick.Error;
ErrorId := DeviceJoystick.ErrorId;

DeviceCanOpenMaster.Operational := CANbusOnline;
DeviceCanOpenMaster.Online := CANbusOnline;

// Briques génériques pour conformité standard
Busy := FALSE;
Done := FALSE;

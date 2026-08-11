(* ═══════════════════════════════════════════════════════════════
   📡 FB_Diag_CanOpen — Diagnostic bus CANopen / Joystick
   ───────────────────────────────────────────────────────────────
   📄 Docs : DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md
              DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §3
   🎯 Rôle : Décide Online/Operational et publie ST_Diag_Device.
      Distinction explicite dans State :
      - INIT       : pas encore online (ni réel, ni bypass)
      - SIMULATED  : bypass actif (simulation ou bypass réseau IHM)
      - READY      : bus réellement online
      - ERROR      : défaut détecté
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Diag_CanOpen
VAR_INPUT
    Enable          : BOOL;        (* Active la surveillance CAN *)
    Reset           : BOOL;        (* Front d'acquittement des défauts *)
    CANbusStateRaw          : INT;          (* Valeur brute CANbus.GetBusState() (2 = ACTIVE) *)
    DeviceJoystickStateRaw  : DEVICE_STATE; (* Valeur brute JOY1.GetDeviceState() *)
    SimBypassActive         : BOOL;         (* TRUE = simulation active pour ce device *)
    NetworkBypassActive     : BOOL;         (* TRUE = bypass réseau global IHM *)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;        (* Logique de surveillance active *)
    Busy            : BOOL;        (* Non utilisé (conformité interface) *)
    Done            : BOOL;        (* Non utilisé *)
    Error           : BOOL;        (* Présence anomalie de communication *)
    ErrorId         : WORD;        (* Code défaut global résumé *)
    State           : E_Diag_State; (* Phase courante (INIT/SIMULATED/READY/ERROR) *)
    StateAtError    : E_Diag_State; (* Phase figée à l'apparition de l'erreur *)
    DeviceCanOpenMaster : ST_Diag_Device;  (* Diagnostics bus CANopen *)
    DeviceJoystick  : ST_Diag_Device;  (* Diagnostics esclave Joystick *)
    (* Miroirs bruts lisibles directement sur l'instance *)
    CANbusStateRawOut         : INT;
    DeviceJoystickStateRawOut : DEVICE_STATE;
END_VAR
VAR
    ResetEdge       : R_TRIG;      (* Détecteur front de reset *)
    CANbusOnlineReal         : BOOL; (* Bus réellement actif, hors tout bypass *)
    DeviceJoystickOnlineReal : BOOL; (* Joystick réellement RUNNING, hors tout bypass *)
    BypassActive             : BOOL; (* Simulation OU bypass réseau IHM *)
    CANbusOnlineEff          : BOOL; (* Online effectif (réel OU bypass) *)
    DeviceJoystickOnlineEff  : BOOL; (* Operational effectif (réel OU bypass) *)
END_VAR

// 🛑 1. GATE : Désactivation logique si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_Diag_State.DISABLED;
    DeviceJoystick.State := E_Diag_State.DISABLED;
    DeviceJoystick.Online := FALSE;
    DeviceJoystick.Operational := FALSE;
    DeviceJoystick.Error := FALSE;
    DeviceJoystick.ErrorId := 16#0000;
    DeviceCanOpenMaster.State := E_Diag_State.DISABLED;
    DeviceCanOpenMaster.Online := FALSE;
    DeviceCanOpenMaster.Operational := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    CANbusStateRawOut := CANbusStateRaw;
    DeviceJoystickStateRawOut := DeviceJoystickStateRaw;
    RETURN;
END_IF;

Ready := TRUE;

// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES
CANbusOnlineReal         := (CANbusStateRaw = 2);
DeviceJoystickOnlineReal := (DeviceJoystickStateRaw = DEVICE_STATE.RUNNING);
BypassActive             := SimBypassActive OR NetworkBypassActive;
CANbusOnlineEff          := CANbusOnlineReal OR BypassActive;
DeviceJoystickOnlineEff  := DeviceJoystickOnlineReal OR BypassActive;

// 🔑 3. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CANbusOnlineEff AND DeviceJoystickOnlineEff) THEN
        DeviceJoystick.ErrorId := 16#0000;
        StateAtError := E_Diag_State.DISABLED;
    END_IF;
END_IF;

// 🔍 4. DIAGNOSTIC JOYSTICK
// Bit 0 : Perte de communication CAN
IF NOT CANbusOnlineEff THEN
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId OR 16#0001;  (* Perte liaison CAN joystick *)
    DeviceJoystick.Online := FALSE;
ELSE
    DeviceJoystick.Online := TRUE;
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId AND 16#FFFE; (* Effacement auto si la liaison revient *)
END_IF;

// Bit 1 : Mode non-opérationnel (esclave CANopen en pré-op ou défaut)
IF NOT DeviceJoystickOnlineEff THEN
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId OR 16#0002;  (* Joystick pas opérationnel *)
    DeviceJoystick.Operational := FALSE;
ELSE
    DeviceJoystick.Operational := TRUE;
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId AND 16#FFFD; (* Effacement auto dès que RUNNING *)
END_IF;

// 🚦 5. MACHINE D'ÉTAT JOYSTICK
IF DeviceJoystick.ErrorId <> 0 THEN
    DeviceJoystick.State := E_Diag_State.ERROR;
    IF StateAtError = E_Diag_State.DISABLED THEN
        StateAtError := State;
    END_IF;
ELSIF NOT (DeviceJoystick.Online AND DeviceJoystick.Operational) THEN
    DeviceJoystick.State := E_Diag_State.INIT;
ELSIF BypassActive AND NOT (CANbusOnlineReal AND DeviceJoystickOnlineReal) THEN
    DeviceJoystick.State := E_Diag_State.SIMULATED;
ELSE
    DeviceJoystick.State := E_Diag_State.READY;
END_IF;

State := DeviceJoystick.State;

// 📤 6. SORTIES GLOBALES
DeviceJoystick.Error := (DeviceJoystick.ErrorId <> 0);
Error := DeviceJoystick.Error;
ErrorId := DeviceJoystick.ErrorId;

DeviceCanOpenMaster.Operational := CANbusOnlineEff;
DeviceCanOpenMaster.Online := CANbusOnlineEff;

IF NOT CANbusOnlineEff THEN
    DeviceCanOpenMaster.State := E_Diag_State.INIT;
ELSIF BypassActive AND NOT CANbusOnlineReal THEN
    DeviceCanOpenMaster.State := E_Diag_State.SIMULATED;
ELSE
    DeviceCanOpenMaster.State := E_Diag_State.READY;
END_IF;

// Miroirs bruts, toujours à jour
CANbusStateRawOut := CANbusStateRaw;
DeviceJoystickStateRawOut := DeviceJoystickStateRaw;

// Briques génériques pour conformité standard
Busy := FALSE;
Done := FALSE;

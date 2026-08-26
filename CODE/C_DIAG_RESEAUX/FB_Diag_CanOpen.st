(* =======================================================================
   📊 FB_Diag_CanOpen — Diagnostic bus CANopen & Esclave Joystick
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance bus CANopen master et esclave Joystick (Online/Op)
   🔌 Architecture : Publication ST_Diag_Device & E_Diag_State
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.4.md
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Diag_CanOpen
VAR_INPUT
    // === COMMANDES & CONTROLE ===
    Enable                      : BOOL;         // --> [CMD] Active la surveillance CAN
    Reset                       : BOOL;         // --> [CMD] Front d'acquittement des defauts

    // === ETATS BRUTS MATERIEL ===
    CANbusStateRaw              : INT;          // --> [HW]  Valeur brute CANbus.GetBusState() (2 = ACTIVE)
    DeviceJoystickStateRaw      : DEVICE_STATE; // --> [HW]  Valeur brute JOY1.GetDeviceState()

    // === BYPASS & SIMULATION ===
    SimBypassActive             : BOOL;         // --> [TST] TRUE = simulation active pour ce device
    NetworkBypassActive         : BOOL;         // --> [TST] TRUE = bypass reseau global IHM
    CanBusBypassActive          : BOOL;         // --> [TST] TRUE = bypass specifique bus CANopen maître
    JoystickBypassActive        : BOOL;         // --> [TST] TRUE = bypass specifique esclave Joystick
END_VAR
VAR_OUTPUT
    // === ETAT DU BLOC ===
    Ready                       : BOOL;         // <-- [STAT] Logique de surveillance active

    // === DIAGNOSTICS STRUCTURES PAR EQUIPEMENT ===
    DeviceCanOpenMaster         : ST_Diag_Device; // <-- [DIAG] Diagnostics bus CANopen maître (Online, Op, Error, ErrorId, State)
    DeviceJoystick              : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave Joystick (Online, Op, Error, ErrorId, State)
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    ResetEdge                   : R_TRIG;       // * [INST] Detecteur front de reset

    // === CALCULS ET ETATS INTERNES ===
    CANbusOnlineReal            : BOOL;         // . [LOC]  Bus reellement actif, hors tout bypass
    DeviceJoystickOnlineReal    : BOOL;         // . [LOC]  Joystick reellement RUNNING, hors tout bypass
    CANbusOnlineEff             : BOOL;         // . [LOC]  Online effectif bus CAN (reel OU bypass)
    DeviceJoystickOnlineEff     : BOOL;         // . [LOC]  Operational effectif joystick (reel OU bypass)
END_VAR

{region "§1 Gate"}
// 🛑 1. GATE : Désactivation logique si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    DeviceJoystick.State := E_Diag_State.DISABLED;
    DeviceJoystick.Online := FALSE;
    DeviceJoystick.Operational := FALSE;
    DeviceJoystick.Error := FALSE;
    DeviceJoystick.ErrorId := 16#0000;
    DeviceCanOpenMaster.State := E_Diag_State.DISABLED;
    DeviceCanOpenMaster.Online := FALSE;
    DeviceCanOpenMaster.Operational := FALSE;
    DeviceCanOpenMaster.Error := FALSE;
    DeviceCanOpenMaster.ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;
{endregion}

{region "§2 Interprétation valeurs brutes"}
// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES
CANbusOnlineReal         := (CANbusStateRaw = 2);
DeviceJoystickOnlineReal := (DeviceJoystickStateRaw = DEVICE_STATE.RUNNING);

CANbusOnlineEff          := CANbusOnlineReal OR SimBypassActive OR NetworkBypassActive OR CanBusBypassActive;
DeviceJoystickOnlineEff  := DeviceJoystickOnlineReal OR SimBypassActive OR NetworkBypassActive OR JoystickBypassActive;
{endregion}

{region "§3 Reset front"}
// 🔑 3. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CANbusOnlineEff AND DeviceJoystickOnlineEff) THEN
        DeviceJoystick.ErrorId := 16#0000;
        DeviceJoystick.StateAtError := E_Diag_State.DISABLED;
    END_IF;
END_IF;
{endregion}

{region "§4 Diagnostic joystick"}
// 🔍 4. DIAGNOSTIC JOYSTICK
// Bit 0 : Perte de communication CAN
IF NOT CANbusOnlineEff THEN
    DeviceJoystick.ErrorId := DeviceJoystick.ErrorId OR 16#0001;  (* Perte liaison CAN joystick *)
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
{endregion}

{region "§5 Machine etat joystick"}
// 🚦 5. MACHINE D'ÉTAT JOYSTICK
IF DeviceJoystick.ErrorId <> 0 THEN
    DeviceJoystick.State := E_Diag_State.ERROR;
ELSIF NOT (DeviceJoystick.Online AND DeviceJoystick.Operational) THEN
    DeviceJoystick.State := E_Diag_State.INIT;
ELSIF (SimBypassActive OR NetworkBypassActive OR JoystickBypassActive) AND NOT (CANbusOnlineReal AND DeviceJoystickOnlineReal) THEN
    DeviceJoystick.State := E_Diag_State.SIMULATED;
ELSE
    DeviceJoystick.State := E_Diag_State.READY;
END_IF;
{endregion}

{region "§6 Sorties globales"}
// 📤 6. SORTIES GLOBALES
DeviceJoystick.Error := (DeviceJoystick.ErrorId <> 0);

DeviceCanOpenMaster.Operational := CANbusOnlineEff;
DeviceCanOpenMaster.Online := CANbusOnlineEff;
DeviceCanOpenMaster.Error := NOT CANbusOnlineEff;

IF NOT CANbusOnlineEff THEN
    DeviceCanOpenMaster.ErrorId := 16#0001;
    DeviceCanOpenMaster.State := E_Diag_State.ERROR;
    IF DeviceCanOpenMaster.StateAtError = E_Diag_State.DISABLED THEN
        DeviceCanOpenMaster.StateAtError := E_Diag_State.INIT;
    END_IF;
ELSIF (SimBypassActive OR NetworkBypassActive OR CanBusBypassActive) AND NOT CANbusOnlineReal THEN
    DeviceCanOpenMaster.ErrorId := 16#0000;
    DeviceCanOpenMaster.State := E_Diag_State.SIMULATED;
ELSE
    DeviceCanOpenMaster.ErrorId := 16#0000;
    DeviceCanOpenMaster.State := E_Diag_State.READY;
END_IF;
{endregion}

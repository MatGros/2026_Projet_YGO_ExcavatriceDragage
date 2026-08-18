(* =======================================================================
   📊 FB_Diag_CanOpen — Diagnostic bus CANopen & Esclave Joystick
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance bus CANopen master et esclave Joystick (Online/Op)
   🔌 Architecture : Publication ST_Diag_Device & E_Diag_State
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.0.md
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
END_VAR
VAR_OUTPUT
    // === ETATS IEC & CONFORMITE ===
    Ready                       : BOOL;         // <-- [STAT] Logique de surveillance active
    Busy                        : BOOL;         // <-- [STAT] Non utilise (conformite interface)
    Done                        : BOOL;         // <-- [STAT] Non utilise
    State                       : E_Diag_State; // <-- [STAT] Phase courante (INIT/SIMULATED/READY/ERROR)

    // === DIAGNOSTICS & ALARMES ===
    Error                       : BOOL;         // <-- [DIAG] Presence anomalie de communication
    ErrorId                     : WORD;         // <-- [DIAG] Code defaut global resume
    StateAtError                : E_Diag_State; // <-- [DIAG] Phase figee a l'apparition de l'erreur
    DeviceCanOpenMaster         : ST_Diag_Device; // <-- [DIAG] Diagnostics bus CANopen
    DeviceJoystick              : ST_Diag_Device; // <-- [DIAG] Diagnostics esclave Joystick

    // === MIROIRS BRUTS MATERIEL ===
    CANbusStateRawOut           : INT;          // <-- [DIAG] Miroir brut status CANbus
    DeviceJoystickStateRawOut   : DEVICE_STATE; // <-- [DIAG] Miroir brut status Joystick
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    ResetEdge                   : R_TRIG;       // * [INST] Detecteur front de reset

    // === CALCULS ET ETATS INTERNES ===
    CANbusOnlineReal            : BOOL;         // . [LOC]  Bus reellement actif, hors tout bypass
    DeviceJoystickOnlineReal    : BOOL;         // . [LOC]  Joystick reellement RUNNING, hors tout bypass
    BypassActive                : BOOL;         // . [LOC]  Simulation OU bypass reseau IHM
    CANbusOnlineEff             : BOOL;         // . [LOC]  Online effectif (reel OU bypass)
    DeviceJoystickOnlineEff     : BOOL;         // . [LOC]  Operational effectif (reel OU bypass)
END_VAR

{region "§1 Gate"}
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
{endregion}

{region "§2 Interprétation valeurs brutes"}
// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES
CANbusOnlineReal         := (CANbusStateRaw = 2);
DeviceJoystickOnlineReal := (DeviceJoystickStateRaw = DEVICE_STATE.RUNNING);
BypassActive             := SimBypassActive OR NetworkBypassActive;
CANbusOnlineEff          := CANbusOnlineReal OR BypassActive;
DeviceJoystickOnlineEff  := DeviceJoystickOnlineReal OR BypassActive;
{endregion}

{region "§3 Reset front"}
// 🔑 3. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CANbusOnlineEff AND DeviceJoystickOnlineEff) THEN
        DeviceJoystick.ErrorId := 16#0000;
        StateAtError := E_Diag_State.DISABLED;
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
{endregion}

{region "§6 Sorties globales"}
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
{endregion}

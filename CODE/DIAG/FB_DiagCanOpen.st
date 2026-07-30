(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagCanOpen — Diagnostic de communication bus CANopen / Joystick
   ───────────────────────────────────────────────────────────────
   🔧 REX 2026-07-24 (demande utilisateur, mise en service) : REFONTE responsabilités —
   PRG_01_Diagnostics ne transmet plus que les valeurs BRUTES (GetBusState()/GetDeviceState())
   et les 2 bypass bruts (simulation par device, bypass réseau IHM global) ; c'est CE FB qui
   décide désormais Online/Operational ET distingue explicitement dans `State` :
     - INIT       : pas encore online (ni réel, ni bypass) — initialisation normale
     - SIMULATED  : bypass actif (simulation ou bypass réseau IHM) mais bus réel PAS confirmé online
     - READY      : bus réellement online (le bypass, actif ou non, ne change rien ici)
     - ERROR      : défaut détecté
   But : ne plus jamais confondre en mise en service un bypass masquant (SIMULATED) avec un vrai
   bus opérationnel (READY) — ambiguïté qui a causé un faux diagnostic "online" alors que le bus
   réel ne l'était pas.
    📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v3.0.md

   🐛 REX 2026-07-24 (bis) — BUG CORRIGÉ (mesure terrain mise en service) : l'ancien code comparait
   CANbusStateRaw = 1 pour "actif", valeur JAMAIS vérifiée sur le vrai bus (devinée à l'écriture du
   code initial). Mesure réelle : device physique "Bus Active=TRUE, Fault=FALSE" ⇒ CANbusStateRaw
   = 2. Comparaison corrigée à = 2. ⚠️ Cette valeur reste une CONSTATATION EMPIRIQUE (pas de doc
   vendeur consultée) — à reconfirmer si possible en simulant une vraie coupure bus (la valeur doit
   changer et NE PLUS valoir 2).
*)
FUNCTION_BLOCK PUBLIC FB_DiagCanOpen
VAR_INPUT
    Enable          : BOOL;        (* Active la surveillance CAN *)
    Reset           : BOOL;        (* Front d'acquittement des défauts *)
    // 🆕 REX 2026-07-24 : valeurs BRUTES non interprétées — l'appelant (PRG_01) ne fait plus
    // qu'acquérir, cette FB décide seule de l'interprétation (voir en-tête).
    CANbusStateRaw          : INT;          (* Valeur brute CANbus.GetBusState() (2 = ACTIVE, confirmé terrain 2026-07-24 — PAS 1) *)
    DeviceJoystickStateRaw  : DEVICE_STATE; (* Valeur brute JOY1.GetDeviceState() *)
    SimBypassActive         : BOOL;         (* TRUE = simulation active pour ce device (SimulationModeActive AND NOT BusJoystickIsReal), calculé par l'appelant *)
    NetworkBypassActive     : BOOL;         (* TRUE = bypass réseau global IHM (GVL_IHM.Network.Bypass.Global) *)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;        (* Logique de surveillance active *)
    Busy            : BOOL;        (* Non utilisé (conformité interface) *)
    Done            : BOOL;        (* Non utilisé *)
    Error           : BOOL;        (* Présence anomalie de communication *)
    ErrorId         : WORD;        (* Code défaut global résumé *)
    State           : E_DiagState; (* Phase courante du cycle de diag — voir en-tête (INIT/SIMULATED/READY/ERROR) *)
    StateAtError    : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    DeviceCanOpenMaster : ST_DiagDevice;  (* Diagnostics bus CANopen *)
    DeviceJoystick  : ST_DiagDevice;  (* Diagnostics esclave Joystick *)
    // 🆕 REX 2026-07-24 — miroirs bruts (voir VAR_INPUT ci-dessus), lisibles directement sur
    // l'instance (Device.Application.PRG_01_Diagnostics.instDiagCanOpen.<Nom>) sans dépendre
    // du reste de la logique de bypass/simulation.
    CANbusStateRawOut         : INT;
    DeviceJoystickStateRawOut : DEVICE_STATE;
END_VAR
VAR
    ResetEdge       : R_TRIG;      (* Détecteur front de reset *)
    // 🆕 REX 2026-07-24 — interprétation interne (voir en-tête)
    CANbusOnlineReal         : BOOL; (* Bus réellement actif, hors tout bypass *)
    DeviceJoystickOnlineReal : BOOL; (* Joystick réellement RUNNING, hors tout bypass *)
    BypassActive             : BOOL; (* Simulation OU bypass réseau IHM *)
    CANbusOnlineEff          : BOOL; (* Online effectif utilisé pour la logique (réel OU bypass) *)
    DeviceJoystickOnlineEff  : BOOL; (* Operational effectif utilisé pour la logique (réel OU bypass) *)
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
    // 🐛 REX 2026-07-24 (ter) — BUG CORRIGÉ : DeviceCanOpenMaster.State n'était JAMAIS assigné
    // (ni ici, ni dans le corps normal ci-dessous) → restait figé sur sa valeur d'init DISABLED
    // (E_DiagState := 0 par défaut) quel que soit l'état réel du bus. Constaté en mise en service :
    // bus réellement ACTIVE mais GVL_IHM.Network.BusCanOpen.State affichait DISABLED en continu.
    DeviceCanOpenMaster.State := E_DiagState.DISABLED;
    DeviceCanOpenMaster.Online := FALSE;
    DeviceCanOpenMaster.Operational := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    CANbusStateRawOut := CANbusStateRaw;         // 🆕 miroir toujours à jour, même désactivé
    DeviceJoystickStateRawOut := DeviceJoystickStateRaw;
    RETURN;
END_IF;

Ready := TRUE;

// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES (REX 2026-07-24, rapatrié depuis PRG_01_Diagnostics)
CANbusOnlineReal         := (CANbusStateRaw = 2); // 🐛 REX 2026-07-24 (bis) : corrigé de 1 → 2 (mesure terrain, voir en-tête)
DeviceJoystickOnlineReal := (DeviceJoystickStateRaw = DEVICE_STATE.RUNNING);
BypassActive             := SimBypassActive OR NetworkBypassActive;
CANbusOnlineEff          := CANbusOnlineReal OR BypassActive;
DeviceJoystickOnlineEff  := DeviceJoystickOnlineReal OR BypassActive;

// 🔑 3. RESET FRONT — Efface les défauts si la cause a disparu
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    IF (CANbusOnlineEff AND DeviceJoystickOnlineEff) THEN
        DeviceJoystick.ErrorId := 16#0000;
        StateAtError := E_DiagState.DISABLED;
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
// REX 2026-07-08 : correction de la précédence d'affichage IHM des états d'erreur.
// 🆕 REX 2026-07-24 : distingue SIMULATED (bypass actif, bus réel pas confirmé) de READY (réel).
IF DeviceJoystick.ErrorId <> 0 THEN
    DeviceJoystick.State := E_DiagState.ERROR;
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
ELSIF NOT (DeviceJoystick.Online AND DeviceJoystick.Operational) THEN
    DeviceJoystick.State := E_DiagState.INIT;
ELSIF BypassActive AND NOT (CANbusOnlineReal AND DeviceJoystickOnlineReal) THEN
    DeviceJoystick.State := E_DiagState.SIMULATED;
ELSE
    DeviceJoystick.State := E_DiagState.READY;
END_IF;

State := DeviceJoystick.State;

// 📤 6. SORTIES GLOBALES
DeviceJoystick.Error := (DeviceJoystick.ErrorId <> 0);
Error := DeviceJoystick.Error;
ErrorId := DeviceJoystick.ErrorId;

DeviceCanOpenMaster.Operational := CANbusOnlineEff;
DeviceCanOpenMaster.Online := CANbusOnlineEff;

// 🐛 REX 2026-07-24 (ter) : State du bus maître, jamais assigné avant (voir bug ci-dessus au GATE).
// Pas d'ErrorId propre au master (les défauts bus sont remontés via DeviceJoystick.ErrorId bit 0).
IF NOT CANbusOnlineEff THEN
    DeviceCanOpenMaster.State := E_DiagState.INIT;
ELSIF BypassActive AND NOT CANbusOnlineReal THEN
    DeviceCanOpenMaster.State := E_DiagState.SIMULATED;
ELSE
    DeviceCanOpenMaster.State := E_DiagState.READY;
END_IF;

// 🆕 REX 2026-07-24 — miroirs bruts (voir en-tête), toujours à jour
CANbusStateRawOut := CANbusStateRaw;
DeviceJoystickStateRawOut := DeviceJoystickStateRaw;

// Briques génériques pour conformité standard
Busy := FALSE;
Done := FALSE;

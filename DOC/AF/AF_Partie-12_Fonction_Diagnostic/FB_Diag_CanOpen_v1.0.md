# Fiche FB_Diag_CanOpen v1.0

> Diagnostic bus CANopen + esclave Joystick.
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_CanOpen.st` · instance : `PRG_01_Diagnostics.instDiagCanOpen` (ST actuel) ; cible `PRG_02_Acquisition_CFC.instDiagCanOpen`.

## 🎯 Rôle

Publie l'état de communication du bus CANopen et de l'esclave Joystick.
Distingue explicitement un bus réellement online (`READY`) d'un bypass masquant (`SIMULATED`).

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Enable` | BOOL | `PRG_01` (TRUE fixe) |
| `Reset` | BOOL | IHM (front acquittement) |
| `CANbusStateRaw` | INT | `CANbus.GetBusState()` (2 = ACTIVE) |
| `DeviceJoystickStateRaw` | DEVICE_STATE | `JOY1.GetDeviceState()` |
| `SimBypassActive` | BOOL | `PRG_01` (simulation device) |
| `NetworkBypassActive` | BOOL | `GVL_IHM.Network.Bypass.Global` |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `Ready` / `Busy` / `Done` | BOOL | Conformité standard |
| `Error` / `ErrorId` | BOOL / WORD | IHM Network |
| `State` / `StateAtError` | E_Diag_State | IHM, Modes |
| `DeviceCanOpenMaster` | ST_Diag_Device | IHM Network, FB_Joystick (via PRG_01) |
| `DeviceJoystick` | ST_Diag_Device | FB_Safety_Winch, FB_Safety_Translation (via PRG_03), IHM |
| `CANbusStateRawOut` / `DeviceJoystickStateRawOut` | miroirs bruts | Troubleshooting |

## 🔒 Impact machine

- **Ne coupe pas directement**.
- `FB_Safety_Winch` et `FB_Safety_Translation` consomment `DeviceJoystick.Online/Operational` :
  - `NOT Online` ou `NOT Operational` → **SafeStop** (désarmement + rampe décélération).

## 🚦 Machine d'état (E_Diag_State)

| Condition | State |
|---|---|
| `ErrorId <> 0` | `ERROR` |
| `NOT (Online AND Operational)` | `INIT` |
| `BypassActive AND NOT OnlineReal` | `SIMULATED` |
| Sinon | `READY` |

## ❌ ErrorId (DeviceJoystick)

| Bit | Cause |
|---|---|
| 0 | Perte liaison CAN joystick |
| 1 | Joystick non opérationnel |

## 📄 Docs liées

- `AF_Partie-11` §4 (flux) · `AF_Partie-06` §3 (diagnostics bus) · `AF_Partie-03` (profil non-mouvement)
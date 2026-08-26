# Fiche FB_Diag_CanOpen v1.0

> Diagnostic bus CANopen + esclave Joystick.
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_CanOpen.st` · instance : `PRG_02_Acquisition.instDiagCanOpen`.

## 🎯 Rôle

Publie l'état de communication du bus CANopen et de l'esclave Joystick.
Distingue explicitement un bus réellement online (`READY`) d'un bypass masquant (`SIMULATED`).

## 📥 Entrées

| Port | Type | Producteur | Rôle |
|---|---|---|---|
| `Enable` | BOOL | `PRG_02` (TRUE fixe) | Activation logique |
| `Reset` | BOOL | IHM (front acquittement) | Réarmement sur front montant |
| `CANbusStateRaw` | INT | `CANbus.GetBusState()` (2 = ACTIVE) | État driver CAN CODESYS |
| `DeviceJoystickStateRaw` | DEVICE_STATE | `JOY1.GetDeviceState()` | État esclave joystick |
| `SimBypassActive` | BOOL | `GVL_Simulation` | Simulation active banc |
| `NetworkBypassActive` | BOOL | `GVL_IHM.Network.Bypass.Global` | Bypass réseau global |
| `CanBusBypassActive` | BOOL | `GVL_IHM.Network.Bypass.BusCanOpen` | Bypass maître CAN seul |
| `JoystickBypassActive` | BOOL | `GVL_IHM.Network.Bypass.Joystick` | Bypass joystick esclave seul |

## 📤 Sorties

| Port | Type | Consommateur | Rôle |
|---|---|---|---|
| `Ready` | BOOL | Standard | Logique active |
| `DeviceCanOpenMaster` | ST_Diag_Device | `GVL_IHM.Network.BusCanOpen`, IHM | Diagnostics bus maître |
| `DeviceJoystick` | ST_Diag_Device | `GVL_IHM.Network.Joystick`, Safety Treuils/Translation | Diagnostics esclave Joystick |

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

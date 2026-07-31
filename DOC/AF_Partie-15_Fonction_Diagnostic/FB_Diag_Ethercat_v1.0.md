# Fiche FB_Diag_Ethercat v1.0

> Diagnostic bus EtherCAT (3 esclaves : variateur M3 + codeurs M1/M2).
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/DIAG/FB_Diag_Ethercat.st` · instance : `PRG_01_Diagnostics.instDiagEthercat`.

## 🎯 Rôle

Publie l'état de communication de chaque esclave EtherCAT.
Distingue `READY` (bus réel online) de `SIMULATED` (bypass actif).

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Enable` / `Reset` | BOOL / BOOL | `PRG_01` / IHM |
| `DeviceVariateurStateRaw` | DEVICE_STATE | `AC600_ECAT_Drive.GetDeviceState()` |
| `DeviceVariateurSimBypass` | BOOL | `PRG_01` |
| `DeviceEncoderM1StateRaw` | DEVICE_STATE | `COD1_CODEUR.GetDeviceState()` |
| `DeviceEncoderM1SimBypass` | BOOL | `PRG_01` |
| `DeviceEncoderM2StateRaw` | DEVICE_STATE | `COD2_CODEUR.GetDeviceState()` |
| `DeviceEncoderM2SimBypass` | BOOL | `PRG_01` |
| `NetworkBypassActive` | BOOL | `GVL_IHM.Network.Bypass.Global` |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `Error` / `ErrorId` | BOOL / WORD | IHM Network |
| `State` / `StateAtError` | E_Diag_State | IHM |
| `DeviceEthercatMaster` | ST_Diag_Device | IHM Network |
| `DeviceVariateur` | ST_Diag_Device | FB_Safety_Translation (via PRG_03), IHM |
| `DeviceEncoderM1` / `DeviceEncoderM2` | ST_Diag_Device | FB_Diag_Preflight, IHM |
| `*StateRawOut` | miroirs bruts | Troubleshooting |

## 🔒 Impact machine

- `FB_Safety_Translation` consomme `DeviceVariateur.Online/Operational` :
  - `NOT Online` ou `NOT Operational` → **SafeStop** Translation M3.
- `FB_Diag_Preflight` consomme `DeviceEncoderM1/M2.Operational` pour son verdict passif.

## ❌ ErrorId

| Device | Bit | Cause |
|---|---|---|
| DeviceVariateur | 4 | Perte liaison variateur M3 |
| DeviceEncoderM1 | 5 | Perte liaison codeur M1 |
| DeviceEncoderM2 | 6 | Perte liaison codeur M2 |

> ErrorId global synthétise par nibble : `0x00F0` = variateur, `0x0F00` = M1, `0xF000` = M2.

## 📄 Docs liées

- `AF_Partie-15` §4 (flux) · `AF_Partie-06` §3 (diagnostics bus) · `AF_Partie-12` (Translation)
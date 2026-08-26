# Fiche FB_Diag_Ethercat v1.1

> Diagnostic bus EtherCAT (3 esclaves : variateur M3 + codeurs M1/M2).
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st` · instance : `PRG_02_Acquisition.instDiagEthercat`.
> Chapô : [`AF_Partie-12_Fonction_Diagnostic_v1.3.md`](../AF_Partie-12_Fonction_Diagnostic_v1.3.md) §2/§7.

## 🎯 Rôle

Publie l'état de communication de chaque esclave EtherCAT.
Distingue `READY` (bus réel online) de `SIMULATED` (bypass actif).

## 🧪 Points de validation

> Propriétaire unique de <nobr><code>TC-P12-030</code></nobr> (synthèse `ErrorId` globale par
> nibble — spécifique à ce FB) — pas dupliqué au chapô. `TC-P12-010`/`020`/`040` restent au chapô
> (partagés avec `FB_Diag_CanOpen`, voir `AF_Partie-12_Fonction_Diagnostic_v1.3.md` §2).

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Etat |
|---|---|---|---|
| <nobr><code>TC-P12-030</code></nobr> | `Error` global et synthèse `ErrorId` par nibble (`0x00F0` variateur / `0x0F00` M1 / `0xF000` M2) reflètent l'état `Error` booléen de chaque device, indépendamment du détail bit-level | <nobr><code>💻 AUTO</code></nobr> | `NV` |

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
| `DeviceEncoderM1` / `DeviceEncoderM2` | ST_Diag_Device | FB_Acquisition_Preflight, IHM |
| `*StateRawOut` | miroirs bruts | Troubleshooting |

## 🔒 Impact machine

- `FB_Safety_Translation` consomme `DeviceVariateur.Online/Operational` :
  - `NOT Online` ou `NOT Operational` → **SafeStop** Translation M3.
- `FB_Acquisition_Preflight` consomme `DeviceEncoderM1/M2.Operational` pour son verdict passif.

## ❌ ErrorId

| Device | Bit (intention) | Bit (code réel) | Cause |
|---|---|---|---|
| DeviceVariateur | 4 | 4 (`16#0010`) | Perte liaison variateur M3 |
| DeviceEncoderM1 | 5 | 5 (`16#0020`) | Perte liaison codeur M1 |
| DeviceEncoderM2 | 6 | ⛔ **4+5 combinés** (`16#0030`, pas `16#0040`) | Perte liaison codeur M2 |

> ⛔ **Bug de code connu** (`TASKS.yaml` T159, non corrigé) : `DeviceEncoderM2.ErrorId` positionné
> sur `16#0030` au lieu de `16#0040` — sans impact safety (`Error`/`Online`/`Operational` restent
> corrects), trompeur en lecture directe IHM/troubleshooting. Guard = cas M2 de `TC-P12-030`/`020`.
>
> ErrorId global synthétise par nibble sur le booléen `Error` (pas la valeur brute du bit) :
> `0x00F0` = variateur, `0x0F00` = M1, `0xF000` = M2 — synthèse correcte, non affectée par le bug.

## 📄 Docs liées

- [`AF_Partie-12` (chapô)](../AF_Partie-12_Fonction_Diagnostic_v1.3.md) §2/§7 · `AF_Partie-11` §4 (flux) · `AF_Partie-06` §3 (diagnostics bus)

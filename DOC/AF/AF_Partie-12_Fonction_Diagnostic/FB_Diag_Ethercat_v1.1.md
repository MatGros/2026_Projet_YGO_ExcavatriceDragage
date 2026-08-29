# Fiche FB_Diag_Ethercat v1.1

> Diagnostic bus EtherCAT (3 esclaves : variateur M3 + codeurs M1/M2).
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st` · instance : `PRG_02_Acquisition.instDiagEthercat`.
> Chapô : [`AF_Partie-12_Fonction_Diagnostic_v1.4.md`](../AF_Partie-12_Fonction_Diagnostic_v1.4.md) §2/§7.

## 🎯 Rôle

Publie l'état de communication de chaque esclave EtherCAT.
Distingue `READY` (bus réel online) de `SIMULATED` (bypass actif).

## 🧪 Points de validation

> Propriétaire unique de <nobr><code>TC-P12-030</code></nobr> (synthèse `ErrorId` globale par
> nibble — spécifique à ce FB) — pas dupliqué au chapô. `TC-P12-010`/`020`/`040` restent au chapô
> (partagés avec `FB_Diag_CanOpen`, voir `AF_Partie-12_Fonction_Diagnostic_v1.4.md` §2).

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

| ID | Comportement attendu | Type | Etat |
|---|---|---|---|
| <nobr><code>TC-P12-030</code></nobr> | `Error` global et synthèse `ErrorId` par nibble (`0x00F0` variateur / `0x0F00` M1 / `0xF000` M2) reflètent l'état `Error` booléen de chaque device, indépendamment du détail bit-level | <nobr><code>💻 AUTO</code></nobr> | `NV` |

## 📥 Entrées

| Port | Type | Producteur | Rôle |
|---|---|---|---|
| `Enable` | BOOL | `PRG_02` (TRUE fixe) | Activation logique |
| `Reset` | BOOL | IHM (front acquittement) | Réarmement sur front montant |
| `DeviceVariateurStateRaw` | DEVICE_STATE | `AC600_ECAT_Drive.GetDeviceState()` | État esclave variateur M3 |
| `DeviceVariateurSimBypass` | BOOL | `GVL_Simulation` | Simulation active banc M3 |
| `DeviceEncoderM1StateRaw` | DEVICE_STATE | `COD1_CODEUR.GetDeviceState()` | État esclave codeur M1 |
| `DeviceEncoderM1SimBypass` | BOOL | `GVL_Simulation` | Simulation active banc M1 |
| `DeviceEncoderM2StateRaw` | DEVICE_STATE | `COD2_CODEUR.GetDeviceState()` | État esclave codeur M2 |
| `DeviceEncoderM2SimBypass` | BOOL | `GVL_Simulation` | Simulation active banc M2 |
| `NetworkBypassActive` | BOOL | `GVL_IHM.Network.Bypass.Global` | Bypass réseau global |
| `EcatBusBypassActive` | BOOL | `GVL_IHM.Network.Bypass.BusEthercat` | Bypass bus EtherCAT maître |
| `VariateurBypassActive` | BOOL | `GVL_IHM.Network.Bypass.VariateurM3` | Bypass variateur seul |
| `EncoderM1BypassActive` | BOOL | `GVL_IHM.Network.Bypass.EncoderM1` | Bypass codeur M1 seul |
| `EncoderM2BypassActive` | BOOL | `GVL_IHM.Network.Bypass.EncoderM2` | Bypass codeur M2 seul |

## 📤 Sorties

| Port | Type | Consommateur | Rôle |
|---|---|---|---|
| `Ready` | BOOL | Standard | Logique active |
| `DeviceEthercatMaster` | ST_Diag_Device | `GVL_IHM.Network.BusEthercat`, IHM | Diagnostics bus maître |
| `DeviceVariateur` | ST_Diag_Device | FB_Safety_Translation, IHM | Diagnostics esclave AC600 |
| `DeviceEncoderM1` | ST_Diag_Device | Treuils M1, IHM | Diagnostics esclave COD1 |
| `DeviceEncoderM2` | ST_Diag_Device | Treuils M2, IHM | Diagnostics esclave COD2 |

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

- [`AF_Partie-12` (chapô)](../AF_Partie-12_Fonction_Diagnostic_v1.4.md) §2/§7 · `AF_Partie-11` §4 (flux) · `AF_Partie-06` §3 (diagnostics bus)

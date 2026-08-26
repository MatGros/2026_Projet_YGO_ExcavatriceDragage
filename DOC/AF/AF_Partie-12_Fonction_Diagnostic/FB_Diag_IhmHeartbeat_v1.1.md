# Fiche FB_Diag_IhmHeartbeat v1.1

> Surveillance bidirectionnelle IHM↔PLC (toggle heartbeat).
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_IhmHeartbeat.st` · instance : `PRG_07_Supervision.instDiagIhmHeartbeat`.
> Chapô : [`AF_Partie-12_Fonction_Diagnostic_v1.3.md`](../AF_Partie-12_Fonction_Diagnostic_v1.3.md) §2.

## 🎯 Rôle

Surveille le toggle IHM (inversion attendue toutes les 500 ms), génère un toggle PLC
et expose un diagnostic de communication opérateur. Ne produit ni SafeStop ni PowerCutOff.

## 🧪 Points de validation

> Propriétaire unique de <nobr><code>TC-P12-050</code></nobr> — pas dupliqué au chapô.

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Etat |
|---|---|---|---|
| <nobr><code>TC-P12-050</code></nobr> | Absence de front `TglHeartbeatIhm` pendant `IhmTimeout` ➔ `HeartbeatIhmTimeout=TRUE`/`HeartbeatIhmOk=FALSE` ; `TglHeartbeatPlc` bascule toutes les `PlcTogglePeriod` indépendamment de l'IHM ; nouveau front après timeout ➔ `HeartbeatIhmOk` restauré immédiatement | <nobr><code>💻 AUTO</code></nobr> | `NV` |

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Enable` | BOOL | `PRG_01` |
| `TglHeartbeatIhm` | BOOL | `GVL_IHM.Commun.TglHeartbeatIhm` (ou bypass réseau) |
| `IhmTimeout` | TIME | `T#2s` (défaut) |
| `PlcTogglePeriod` | TIME | `T#500ms` (défaut) |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `HeartbeatIhmOk` | BOOL | FB_Safety_Winch, FB_Safety_Translation (via PRG_03) |
| `HeartbeatIhmTimeout` | BOOL | Troubleshooting, IHM |
| `TglHeartbeatPlc` | BOOL | IHM (supervision vie PLC) |
| `TimeSinceIhmEdge` | TIME | Diagnostic IHM |

## 🔒 Impact machine

- `FB_Safety_Winch` et `FB_Safety_Translation` consomment `HeartbeatIhmOk` :
  - `NOT HeartbeatIhmOk` → **SafeStop** (perte communication opérateur = danger).

## 📄 Docs liées

- [`AF_Partie-12` (chapô)](../AF_Partie-12_Fonction_Diagnostic_v1.3.md) §2 · `AF_Partie-11` §4 (flux) · `AF_Partie-07` (Interface IHM) · `AF_Partie-10/AF_Partie-11` (Safety consommateurs)

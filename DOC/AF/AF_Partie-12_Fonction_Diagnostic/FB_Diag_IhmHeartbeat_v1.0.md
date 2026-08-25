# Fiche FB_Diag_IhmHeartbeat v1.0

> Surveillance bidirectionnelle IHM↔PLC (toggle heartbeat).
> Profil AF03 : brique métier non-mouvement.
> Source : `CODE/C_DIAG_RESEAUX/FB_Diag_IhmHeartbeat.st` · instance : `PRG_07_Supervision.instDiagIhmHeartbeat`.

## 🎯 Rôle

Surveille le toggle IHM (inversion attendue toutes les 500 ms), génère un toggle PLC
et expose un diagnostic de communication opérateur. Ne produit ni SafeStop ni PowerCutOff.

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

- `AF_Partie-11` §4 (flux) · `AF_Partie-07` (Interface IHM) · `AF_Partie-10/AF_Partie-11` (Safety consommateurs)
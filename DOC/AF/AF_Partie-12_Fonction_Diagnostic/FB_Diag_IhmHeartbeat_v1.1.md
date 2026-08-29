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

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 170px);">
    <col style="width: 90px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Etat</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P12-050</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Absence de front <code>TglHeartbeatIhm</code> pendant <code>IhmTimeout</code> ➔ <code>HeartbeatIhmTimeout=TRUE</code>/<code>HeartbeatIhmOk=FALSE</code> ; <code>TglHeartbeatPlc</code> bascule toutes les <code>PlcTogglePeriod</code> indépendamment de l'IHM ; nouveau front après timeout ➔ <code>HeartbeatIhmOk</code> restauré immédiatement</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

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

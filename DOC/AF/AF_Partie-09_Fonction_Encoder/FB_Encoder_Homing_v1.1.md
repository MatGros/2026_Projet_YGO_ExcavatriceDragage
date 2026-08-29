# FB_Encoder_Homing — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §5 — couvre `F09.02`, `F09.03`.
> Rôle de **ce** document : détail des 3 modes de référencement, cohérence redémarrage, RETAIN.
> Source code : `CODE/E_CODEURS/FB_Encoder_Homing.st` · sous-instance `instHoming` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. 📍 Séquence homing (3 modes)
5. 🔍 Cohérence au redémarrage
6. 📊 `ErrorId`
7. ⚠️ Alertes et écarts
8. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03). Responsabilité unique : décider **quand** et **où** référencer, gérer
la RETAIN `ST_Encoder_Calib` (via `IN_OUT`). Ne lit pas le bus lui-même (reçoit `RawPos`/
`EncoderAvailable` déjà acquis par `FB_Encoder_Abs`) et ne met pas à l'échelle (`FB_Encoder_Scale`
consomme `HomingRefRaw` produit ici).

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-020` (chapô) :

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 310px);">
    <col style="width: 90px;">
    <col style="width: 140px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Etat</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Nominal : front <code>Home</code> + front <code>TopPositionSensor</code> (dans les 2 ordres) → <code>HomingRefRaw</code> calculé pour <code>CablePosM = CfgTopSensorPosM</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.2</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Unitaire : front <code>Home</code> seul → cible <code>CfgHomingTargetM</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.3</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Dynamique : front <code>UseDynamicTarget</code> (ou combiné <code>Home</code>) → cible <code>DynamicHomingTargetM</code> (ex. auto-référencement benne M2)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.4</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Toute cible hors <code>[-99;+99]m</code> → homing refusé, <code>ErrorId</code> bit4, pas d'écriture RETAIN</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.5</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Écart <code>RawPos</code>/<code>Calib.LastKnownRawPos</code> au boot &gt; tolérance → <code>HomingSuspect=TRUE</code>, <code>Homed=FALSE</code> ; levé uniquement par front <code>BtnConfirmCoherence</code> <b>ET</b> <code>HomingPermit=TRUE</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§5</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` / `Reset` | `BOOL` | Standard |
| `Home` | `BOOL` | Demande référencement (front) |
| `HomingPermit` | `BOOL` | Autorisation de homer (calculée par l'appelant) |
| `BtnConfirmCoherence` | `BOOL` | Lève le doute incohérence boot (front) |
| `CfgHomingTargetM` | `REAL` | Cible homing unitaire (m) |
| `UseDynamicTarget` | `BOOL` | Active cible dynamique |
| `DynamicHomingTargetM` | `REAL` | Cible dynamique (calculée par l'appelant) |
| `CfgTopSensorPosM` | `REAL` | Cible homing nominal (déf. 8.5m) |
| `TopPositionSensor` | `BOOL` | Capteur physique position haute |
| `RawPos` | `UDINT` | Position brute (`FB_Encoder_Abs`) |
| `EncoderAvailable` | `BOOL` | Codeur disponible (`FB_Encoder_Abs`) |
| `PresetAck` / `PresetNak` | `BOOL` | Retour séquence preset (`FB_Encoder_Abs`) |
| `PointsPerRev` / `MultiTurnRevsMax` / `CableM_PerRev` | `UDINT`/`UDINT`/`REAL` | Constantes mécaniques |
| `BypassGlobal` | `BOOL` | Neutralise défauts bornage/cohérence (ne bloque pas le homing lui-même) |
| `FwdRevSpeedFeedbackOff` | `BOOL` | ⚠️ Déclaré, **jamais lu** dans la logique ni câblé par la façade `FB_Encoder` — port mort |
| `BrakeFeedback` | `BOOL` | ⚠️ Déclaré, **jamais lu** dans la logique ni câblé par la façade `FB_Encoder` — port mort |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_Status` | Statut (State machine INIT/READY/BUSY, ErrorId bitfield) — type legacy, cible `Fault : ST_Fault` via `FB_FaultCore` (AF03 §3), migration T164-5 |
| `PresetRequest` / `PresetValue` | `BOOL`/`UDINT` | Commande vers `FB_Encoder_Abs` |
| `Homed` | `BOOL` | `Calib.Homed AND NOT Calib.HomingSuspect` |
| `HomingSuspect` | `BOOL` | Incohérence boot à confirmer |
| `HomingRefRaw` | `UDINT` | Offset de référence brut (`Calib.HomingRefRaw`) |

### `IN_OUT`

| Port | Type | Rôle |
|---|---|---|
| `Calib` | `ST_Encoder_Calib` | RETAIN : `HomingRefRaw`, `LastKnownRawPos`, `Homed`, `HomingSuspect`, `RestartCoherenceTolerancePts` |

## 4 · 📍 Séquence homing (3 modes)

| Mode | Déclenchement | Cible |
|---|---|---|
| Nominal | `HomingModeOk AND NOT UseDynamicTarget AND ((Home AND front TopPositionSensor) OR (front Home AND TopPositionSensor))` | `CfgTopSensorPosM` |
| Unitaire | `HomingModeOk AND NOT UseDynamicTarget AND front Home` | `CfgHomingTargetM` |
| Dynamique | `HomingModeOk AND (front UseDynamicTarget OR (UseDynamicTarget AND front Home))` | `DynamicHomingTargetM` |

`HomingModeOk := HomingPermit`. Cible bornée `[-99;+99]m` avant écriture — hors plage, `ErrorId`
bit4, aucune écriture RETAIN. Sur succès : `Calib.HomingRefRaw`/`Homed` mis à jour, `PresetValue`
calculé (`HomingRefRaw + TargetPoints`), `PresetRequest` pulsé vers `FB_Encoder_Abs`.

### Chronogramme — mode nominal (bouton maintenu, capteur déclenche après)

| Instant | `Home` | `TopPositionSensor` | `Homed` |
|---|---|---|---|
| t0 — repos | FALSE | FALSE | FALSE |
| t1 — opérateur maintient `Home` | TRUE ↑ | FALSE | FALSE |
| t2 — capteur haut atteint | TRUE | TRUE ↑ | **TRUE** *(front capteur pendant `Home` maintenu)* |
| t3 — relâche `Home` | FALSE ↓ | TRUE | TRUE |

L'ordre inverse (front `Home` pendant que `TopPositionSensor` est déjà actif) donne le même
résultat — capture au **premier** front rencontré, jamais après un arrêt confirmé (répétabilité
vitesse d'accostage).

## 5 · 🔍 Cohérence au redémarrage

Une fois par session `Enable` (dès que `EncoderAvailable`) : `RawDiffRestart := RawPos -
Calib.LastKnownRawPos`. Si `Calib.Homed AND ABS(RawDiffRestart) > Calib.RestartCoherenceTolerancePts`
(déf. 1000 pts, ~12% d'un tour) → `Calib.HomingSuspect := TRUE`, `ErrorId` bit9. Levé **uniquement**
par front `BtnConfirmCoherence` **ET** `HomingPermit` — indépendant du `Reset` générique (pas
d'auto-effacement).

## 6 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Homing demandé sans `HomingModeOk` | Auto-effaçable (recalculé chaque scan) |
| 4 | Cible hors plage `[-99;+99]m` | Auto-effaçable |
| 5 | Preset refusé/timeout (`PresetNak`) | Effacé par `Reset` (front) |
| 9 | Incohérence redémarrage | Levé uniquement par `BtnConfirmCoherence` |

Bits 1-3, 6-8 : libres, non utilisés (mineur, voir chapô §11 TBD).

## 7 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | `DynamicHomingTargetM`/`UseDynamicTarget` réellement câblés pour M2 (auto-référencement benne sur confirmation ouverture/fermeture, `PRG_02_Acquisition`) — M1 reste fixe `FALSE`/`0.0` | Vérifié code, voir chapô §4 |
| 2 | mineur | `FwdRevSpeedFeedbackOff`/`BrakeFeedback` déclarés en entrée, jamais lus ni câblés par la façade | Ports morts, à retirer lors d'un lot dédié (pas fait ici, hors périmètre doc) |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder`, architecture (homing dans `PRG_02_Acquisition`) |
| AF03 | Contrat `standard` |
| AF10 | Consommateur `Homed`/`HomingSuspect`, auto-référencement benne M2 |
| Code | `CODE/E_CODEURS/FB_Encoder_Homing.st` |

# FB_Encoder_Homing — Spec composant (v1.2)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.4.md`](../AF_Partie-09_Fonction_Encoder_v2.4.md)
> §5 — couvre `F09.02`, `F09.03`, `F09.08`.
> Rôle de **ce** document : détail des 3 modes de référencement, **référentiel centre-plage**,
> cohérence redémarrage, RETAIN.
> Source code : `CODE/E_CODEURS/FB_Encoder_Homing.st` · sous-instance `instHoming` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. 📍 Séquence homing (3 modes + centre-plage)
5. 🔍 Cohérence au redémarrage
6. 📊 `ErrorId`
7. ⚠️ Alertes et écarts
8. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03). Responsabilité unique : décider **quand** et **où** référencer, gérer
la RETAIN `ST_Encoder_Calib` (via `IN_OUT`). Ne lit pas le bus lui-même (reçoit `RawPos`/
`EncoderAvailable` déjà acquis par `FB_Encoder_Abs`) et ne met pas à l'échelle (`FB_Encoder_Scale`
consomme `HomingRefRaw` produit ici).

**Référentiel (v1.2, F09.08)** : tout homing écrit au codeur le **centre de sa plage de
résolution totale** (`CentrePts = (PointsPerRev × MultiTurnRevsMax)/2`, déf. 16 777 216 pts) et
grave `HomingRefRaw` dans ce référentiel — la position physique du moment ne définit **jamais** la
valeur brute du compteur. Voir §4.

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-020` (chapô) et `TC-P09-070` (centre-plage, v1.2) :

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 28px;">
    <col style="width: 50px;">
    <col style="width: calc(100% - 165px);">
    <col style="width: 45px;">
    <col style="width: 26px;">
    <col style="width: 36px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Intention</small></th>
      <th style="padding: 4px 8px;">Séquence &amp; Déroulé des étapes (Comportement attendu)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Homing</b><br>nominal</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>Homed=FALSE</code>, <code>HomingPermit=TRUE</code><br>
        🚀 <b>Étape 1</b> : Front <code>Home</code> + front <code>TopPositionSensor</code> (dans les 2 ordres)<br>
        ⚡ <b>Étape 2</b> : Calcul <code>PendingHomingRefRaw</code> pour <code>CablePosM = CfgTopSensorPosM</code> (référentiel centre-plage, §4)<br>
        ✅ <b>Étape 3</b> : <code>Homed=TRUE</code> après readback, <code>PresetRequest</code> pulsé vers <code>FB_Encoder_Abs</code> avec <code>PresetValue = CentrePts</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Homing</b><br>unitaire</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>Homed=FALSE</code>, <code>HomingPermit=TRUE</code>, <code>UseDynamicTarget=FALSE</code><br>
        🚀 <b>Étape 1</b> : Front <code>Home</code> seul (sans capteur haut)<br>
        ⚡ <b>Étape 2</b> : Cible = <code>CfgHomingTargetM</code> (libre, MAINT_N2 typiquement)<br>
        ✅ <b>Étape 3</b> : <code>Homed=TRUE</code>, <code>PendingHomingRefRaw = CentrePts − TargetPoints</code> pour cible unitaire
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.3</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Homing</b><br>dynamique</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>Homed=FALSE</code>, <code>HomingPermit=TRUE</code>, M1 <code>HomedAndReliable=TRUE</code><br>
        🚀 <b>Étape 1</b> : Front <code>UseDynamicTarget</code> (ou combiné <code>Home</code>)<br>
        ⚡ <b>Étape 2</b> : Cible = <code>DynamicHomingTargetM</code> (calculée par l'appelant, ex. auto-référencement benne M2)<br>
        ✅ <b>Étape 3</b> : <code>Homed=TRUE</code>, référence gravée au centre-plage pour cible dynamique
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.4</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Cible hors</b><br>bornes</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>Homed=FALSE</code>, <code>HomingPermit=TRUE</code><br>
        🚀 <b>Étape 1</b> : Front <code>Home</code> avec cible hors <code>[-99;+99]m</code><br>
        ⚡ <b>Étape 2</b> : Homing refusé, <code>ErrorId</code> bit4 levé<br>
        ✅ <b>Étape 3</b> : Pas d'écriture RETAIN ; borne exacte : cible=<code>±99.0m</code> acceptée, <code>±99.1m</code> refusée
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.5</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Cohérence</b><br>boot</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Boot PLC, <code>Calib.LastKnownRawPos</code> RETAIN restauré (près du centre)<br>
        🚀 <b>Étape 1</b> : Premier scan <code>EncoderAvailable=TRUE</code>, écart <code>RawPos</code> vs <code>Calib.LastKnownRawPos</code> &gt; tolérance (1000 pts)<br>
        ⚡ <b>Étape 2</b> : <code>HomingSuspect=TRUE</code>, <code>Homed=FALSE</code> (référence non fiable)<br>
        ✅ <b>Étape 3</b> : Levé uniquement par front <code>BtnConfirmCoherence</code> <b>ET</b> <code>HomingPermit=TRUE</code> (pas d'auto-effacement)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.6</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Capteur haut</b><br>absent</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>TopPositionSensor=FALSE</code> (absent), <code>HomingPermit=TRUE</code><br>
        🚀 <b>Étape 1</b> : Front <code>Home</code> en mode nominal<br>
        ⚡ <b>Étape 2</b> : Mode nominal ne déclenche pas (capteur haut requis)<br>
        ✅ <b>Étape 3</b> : Seuls unitaire/dynamique fonctionnent
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.7</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Homing</b><br>sans permit</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>HomingPermit=FALSE</code>, <code>Homed=FALSE</code><br>
        🚀 <b>Étape 1</b> : Front <code>Home</code> sans <code>HomingPermit</code><br>
        ⚡ <b>Étape 2</b> : <code>HomingModeError</code> (bit0) levé<br>
        ✅ <b>Étape 3</b> : Pas d'écriture RETAIN
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-020.8</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Suspect</b><br>RETAIN</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>HomingSuspect=TRUE</code> stocké dans <code>Calib</code> RETAIN<br>
        🚀 <b>Étape 1</b> : Redémarrage PLC (cycle froid)<br>
        ⚡ <b>Étape 2</b> : <code>Calib.HomingSuspect</code> restauré depuis RETAIN<br>
        ✅ <b>Étape 3</b> : <code>HomingSuspect</code> persiste après redémarrage
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-070.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Preset</b><br>centre-plage</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Codeur disponible, <code>RawPos = 40 000 pts</code> (proche borne basse, position physique quelconque)<br>
        🚀 <b>Étape 1</b> : Homing (tout mode) → <code>PresetValue = CentrePts = 16 777 216</code>, <code>PendingHomingRefRaw = CentrePts − TargetPoints</code><br>
        ⚡ <b>Étape 2</b> : Compteur charge le centre (<code>RawPos → 16 777 216</code>), readback <code>CablePosM = cible ± 0.010 m</code><br>
        ✅ <b>Étape 3</b> : <code>Homed=TRUE</code> ; <code>PresetValue</code> ≠ position physique : preuve que le preset a bien chargé le centre
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-070.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Wrap</b><br>impossible</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Référencé centre-plage, compteur à <code>CentrePts</code><br>
        🚀 <b>Étape 1</b> : Descente course physique complète (~20 m ≈ 327 680 pts) puis remontée<br>
        ⚡ <b>Étape 2</b> : Compteur reste dans <code>[CentrePts − 0.5M ; CentrePts + 0.5M]</code> (marge ~±2048 m consommée &lt; 2%)<br>
        ✅ <b>Étape 3</b> : Aucun wrap 0↔2^25 : <code>CablePosM</code> continue, pas de <code>EncoderIncoherent</code>, pas de faux <code>HomingSuspect</code> au boot — <b>pré-requis : simulation avec wrap réel</b> (clamp actuel à corriger, §7)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-070.3</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Cible dyn.</b><br>M1 non fiable</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : M1 non référencé ou <code>EncoderFault M1</code> actif<br>
        🚀 <b>Étape 1</b> : Demande référencement dynamique M2 (front <code>BtnConfirmOpenPos</code>/<code>ClosePos</code>)<br>
        ⚡ <b>Étape 2</b> : Cible dynamique refusée (<code>ErrorId</code> dédié, bit libre à allouer)<br>
        ✅ <b>Étape 3</b> : Aucune écriture RETAIN, aucun preset — une référence ne peut pas être bâtie sur une mesure non fiable
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
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
| `UseDynamicTarget` | `BOOL` | Active cible dynamique — refusée si M1 non `HomedAndReliable` (gate producteur, v1.2) |
| `DynamicHomingTargetM` | `REAL` | Cible dynamique (calculée par l'appelant) |
| `CfgTopSensorPosM` | `REAL` | Cible homing nominal (déf. 8.5m) |
| `TopPositionSensor` | `BOOL` | Capteur physique position haute |
| `RawPos` | `UDINT` | Position brute (`FB_Encoder_Abs`) |
| `EncoderAvailable` | `BOOL` | Codeur disponible (`FB_Encoder_Abs`) |
| `PresetStatusBit` | `BOOL` | Bit d'état preset optionnel, FALSE si non câblé |
| `Cfg` | `ST_fbEncoder_Cfg` | Mode de confirmation preset (`PresetConfirmMode`) |
| `PointsPerRev` / `MultiTurnRevsMax` / `CableM_PerRev` | `UDINT`/`UDINT`/`REAL` | Constantes mécaniques — **`MultiTurnRevsMax` dimensionne le centre de plage** (`CentrePts = PointsPerRev × MultiTurnRevsMax / 2`, §4), câblé par la façade (déf. 4096) |
| `BypassGlobal` | `BOOL` | Neutralise défauts bornage/cohérence (ne bloque pas le homing lui-même) |
| `FwdRevSpeedFeedbackOff` / `BrakeFeedback` | `BOOL` | ⚠️ Déclarés, **jamais lus** dans la logique ni câblés par la façade `FB_Encoder` — ports morts |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Fault` | `ST_Fault` | Statut — type legacy, cible `Fault : ST_Fault` via `FB_FaultCore` (AF03 §3), migration T164-5 |
| `PresetRequest` / `PresetValue` | `BOOL`/`UDINT` | Commande vers `FB_Encoder_Abs` — **`PresetValue = CentrePts`** (16 777 216, référentiel centre-plage §4) |
| `Homed` | `BOOL` | `Calib.Homed AND NOT Calib.HomingSuspect` |
| `HomingSuspect` | `BOOL` | Incohérence boot à confirmer |
| `HomingRefRaw` | `UDINT` | Offset de référence brut (`Calib.HomingRefRaw`, référentiel centre-plage) |

### `IN_OUT`

| Port | Type | Rôle |
|---|---|---|
| `Calib` | `ST_Encoder_Calib` | RETAIN : `HomingRefRaw`, `LastKnownRawPos`, `Homed`, `HomingSuspect`, `RestartCoherenceTolerancePts` |

## 4 · 📍 Séquence homing (3 modes + centre-plage)

| Mode | Déclenchement | Cible |
|---|---|---|
| Nominal | `HomingModeOk AND NOT UseDynamicTarget AND ((Home AND front TopPositionSensor) OR (front Home AND TopPositionSensor))` | `CfgTopSensorPosM` |
| Unitaire | `HomingModeOk AND NOT UseDynamicTarget AND front Home` | `CfgHomingTargetM` |
| Dynamique | `HomingModeOk AND (front UseDynamicTarget OR (UseDynamicTarget AND front Home))` — gate M1 `HomedAndReliable` requise | `DynamicHomingTargetM` |

`HomingModeOk := HomingPermit`. Cible bornée `[-99;+99]m` avant écriture — hors plage, `ErrorId`
bit4, aucune écriture RETAIN.

### 🎯 Référentiel centre-plage (F09.08) — le cœur de la séquence

Sur déclenchement validé :

```text
TargetPoints        := DINT(TargetPositionM × PointsPerRev / CableM_PerRev)   // cible → pts
CentrePts           := (PointsPerRev × MultiTurnRevsMax) / 2                  // 8192 × 4096 / 2 = 16 777 216
PresetValue         := CentrePts                                             // écrit au codeur (PDO Rx)
PendingHomingRefRaw := CentrePts − TargetPoints                              // référence candidate (commit post-readback)
PresetRequest       := TRUE                                                  // pulse vers FB_Encoder_Abs
```

- Le compteur du codeur est **toujours** placé au centre de sa plage, quel que soit le mode et
  la position physique du treuil au moment du homing — marge ±16,7 M pts (±4096 m) chaque sens,
  wrap-around physiquement impossible (course réelle ~1% de la plage).
- La référence applicative `PendingHomingRefRaw` vit dans le **référentiel post-preset** :
  une fois le codeur recentré, `CablePosM = (CentrePts − (CentrePts − TargetPoints)) × k =
  TargetPositionM` — la sémantique mètres est portée par la référence, jamais par le compteur.
- Un homing à 0 m ⇒ `TargetPoints = 0` ⇒ référence = centre : la position physique du moment lit
  0.0 m. Un homing à 8.5 m ⇒ référence = centre − 34 816 pts.
- **Aucun commit RETAIN avant confirmation readback** (chapô §13) : `PendingHomingRefRaw` n'est
  publié dans `Calib` qu'après `PresetConfirmed` ; un échec conserve la référence précédente et
  lève `PresetConfirmationFailed`.
- ⚠️ **Invariant anti-régression** : ne jamais réintroduire `PresetValue := RawPos` (preset
  neutre, commit `73fa758d`) — référencement près d'une borne = wrap possible en manœuvre
  (diagnostic `TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md`).

### Chronogramme — mode nominal (bouton maintenu, capteur déclenche après)

| Instant | `Home` | `TopPositionSensor` | `PresetValue` | `Homed` |
|---|---|---|---|---|
| t0 — repos | FALSE | FALSE | 0 | FALSE |
| t1 — opérateur maintient `Home` | TRUE ↑ | FALSE | 0 | FALSE |
| t2 — capteur haut atteint | TRUE | TRUE ↑ | `CentrePts` | FALSE *(transaction preset en cours)* |
| t3 — readback ±0.010 m confirmé | TRUE | TRUE | 0 | **TRUE** |
| t4 — relâche `Home` | FALSE ↓ | TRUE | 0 | TRUE |

L'ordre inverse (front `Home` pendant que `TopPositionSensor` est déjà actif) donne le même
résultat — capture au **premier** front rencontré, jamais après un arrêt confirmé (répétabilité
vitesse d'accostage).

## 5 · 🔍 Cohérence au redémarrage

Une fois par session `Enable` (dès que `EncoderAvailable`) : `RawDiffRestart := RawPos -
Calib.LastKnownRawPos`. Si `Calib.Homed AND ABS(RawDiffRestart) > Calib.RestartCoherenceTolerancePts`
(déf. 1000 pts, ~12% d'un tour) → `Calib.HomingSuspect := TRUE`, `ErrorId` bit9. Levé **uniquement**
par front `BtnConfirmCoherence` **ET** `HomingPermit` — indépendant du `Reset` générique (pas
d'auto-effacement). Avec le centre-plage, `LastKnownRawPos` vit près du centre : un wrap ne peut
plus produire de faux écart.

## 6 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Homing demandé sans `HomingModeOk` | Auto-effaçable (recalculé chaque scan) |
| 4 | Cible hors plage `[-99;+99]m` | Auto-effaçable |
| 5 | Preset refusé/timeout (`PresetNak`) | Effacé par `Reset` (front) |
| 9 | Incohérence redémarrage | Levé uniquement par `BtnConfirmCoherence` |
| *(libre)* | Cible dynamique refusée — M1 non `HomedAndReliable` (v1.2) | Auto-effaçable — bit à allouer à l'implémentation (1-3, 6-8 disponibles) |

## 7 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | 🔴 | **Divergence spec/code ouverte (v1.2)** : le code actuel écrit `PresetValue := RawPos` (neutre, commit `73fa758d`) — l'exigence centre-plage n'est **pas** implémentée | Correction à charger en tâche dédiée + garde-fou <nobr><code>TC-P09-070</code></nobr> (diagnostic `TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md`) |
| 2 | 🔴 | **Validation matérielle requise** : le codeur réel doit accepter le preset centre (PDO Rx `PresetTriggerCmd=2`) — sinon `PresetNak` systématique, plus aucun homing possible | À qualifier sur le matériel avant tout mouvement réel (chapô §11 TBD) |
| 3 | 🟠 | `FB_Sim_Encoder` (AF13) clampe le compteur à 0 en descente au lieu d'enrouler — <nobr><code>TC-P09-070.2</code></nobr> (wrap impossible) intestable sur banc tant que non corrigé | À corriger côté AF13 avant la campagne TC |
| 4 | mineur | `FwdRevSpeedFeedbackOff`/`BrakeFeedback` déclarés en entrée, jamais lus ni câblés par la façade | Ports morts, à retirer lors d'un lot dédié (pas fait ici, hors périmètre doc) |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô v2.4) | Rôle machine, façade `FB_Encoder`, centre-plage §5/§13, intégration programme |
| AF03 | Contrat `standard` |
| AF10 | Consommateur `Homed`/`HomingSuspect`, auto-référencement benne M2 |
| AF13 | Simulation codeur (`FB_Sim_Encoder`) — correction wrap requise (§7) |
| Diagnostic | `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md` |
| Code | `CODE/E_CODEURS/FB_Encoder_Homing.st` |

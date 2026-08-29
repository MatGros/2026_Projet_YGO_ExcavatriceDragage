# FB_Encoder_Abs — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §5 — couvre `F09.01`.
> Rôle de **ce** document : détail acquisition bus EtherCAT + séquence preset SDO.
> Source code : `CODE/E_CODEURS/FB_Encoder_Abs.st` · sous-instance `instAbs` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. ⚙️ Séquence preset SDO
5. 🔒 Gel sur doute
6. 📊 `ErrorId`
7. ⚠️ Alertes et écarts
8. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03) — remonte défaut bus/preset. Sous-instance privée de `FB_Encoder`, pas
appelée directement par un PRG. Ne décide rien : lit le bus EtherCAT, gèle la position sur perte
de disponibilité, exécute une séquence de preset sur demande (venant de `FB_Encoder_Homing`).

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-010` (chapô) :

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-010.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Bus KO</b><br>→ gel pos.</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Bus EtherCAT opérationnel, <code>RawPos</code> actif<br>
        🚀 <b>Étape 1</b> : <code>AlarmsIn≠0</code> OU <code>NOT SlaveOperational</code><br>
        ⚡ <b>Étape 2</b> : <code>EncoderAvailable=FALSE</code>, <code>RawPos</code>/<code>AngleRaw</code>/<code>TurnCount</code> gelés (dernière valeur)<br>
        ✅ <b>Étape 3</b> : Gel persiste sur plusieurs scans tant que la cause reste active
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-010.3</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Acquisition</b><br>nominale</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Bus OK, <code>Enable=TRUE</code><br>
        🚀 <b>Étape 1</b> : Lecture <code>RawPosIn</code> du PDO EtherCAT<br>
        ⚡ <b>Étape 2</b> : <code>RawPos=RawPosIn</code>, <code>AngleRaw=MOD</code>, <code>TurnCount=division</code><br>
        ✅ <b>Étape 3</b> : <code>EncoderAvailable=TRUE</code> confirmé (<code>FB_Encoder_Abs.st:116-120</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-010.4</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Preset</b><br>déclench.</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>PresetSeqStep=0</code> (IDLE), <code>PresetTriggerCmd=0</code><br>
        🚀 <b>Étape 1</b> : Front <code>PresetRequest</code> + <code>EncoderAvailable=TRUE</code><br>
        ⚡ <b>Étape 2</b> : <code>PresetSeqStep=1</code>, <code>PresetTriggerCmd=2</code><br>
        ✅ <b>Étape 3</b> : Timer <code>PresetTimeout</code> armé (<code>FB_Encoder_Abs.st:128,134</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-010.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Preset</b><br>succès/échec</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>PresetSeqStep=1</code>, <code>PresetTriggerCmd=2</code>, timer armé<br>
        🚀 <b>Étape 1</b> : Écart <code>abs(RawPos-PresetValueOut) ≤ PresetTolerancePts</code><br>
        ⚡ <b>Étape 2</b> : Maintien 500ms visuel puis <code>PresetAck</code> (pulse 1 cycle)<br>
        ✅ <b>Étape 3</b> : Sinon timeout <code>PresetTimeout</code> → <code>PresetNak</code> + <code>ErrorId</code> bit1
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | Autorisation générale |
| `Reset` | `BOOL` | Acquittement défaut (front) |
| `PresetRequest` | `BOOL` | Demande de preset (front) |
| `RawPosIn` | `UDINT` | Position brute EtherCAT |
| `AlarmsIn` | `UINT` | Code alarme brut EtherCAT (seul lu — voir §7) |
| `WarningsIn` | `UINT` | ⚠️ Déclaré, **jamais lu** dans la logique — port mort |
| `SlaveOperational` | `BOOL` | Statut esclave EtherCAT |
| `PointsPerRev` | `UDINT` | Résolution codeur (déf. 8192) |
| `PresetValue` | `UDINT` | Valeur cible de preset |
| `PresetTimeout` | `TIME` | Timeout séquence (déf. 2s) |
| `PresetTolerancePts` | `UDINT` | Tolérance relecture (déf. 10 pts) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_Status` | Statut (Busy/Done/Error/ErrorId — rempli à plat) — type legacy, cible `Fault : ST_Fault` via `FB_FaultCore` (AF03 §3), migration T164-5 |
| `RawPos` | `UDINT` | Position brute (gelée si non disponible) |
| `EncoderAvailable` | `BOOL` | Bus/esclave opérationnels |
| `AngleRaw` | `UINT` | Angle sur un tour (`RawPos MOD PointsPerRev`) |
| `TurnCount` | `UDINT` | Nombre de tours (`RawPos / PointsPerRev`) |
| `PresetAck` / `PresetNak` | `BOOL` | Pulse 1 cycle succès/échec preset |
| `PresetTriggerCmd` / `CodeSeqTriggerCmd` | `WORD` | Ordres PDO Rx (`CodeSeqTriggerCmd` jamais piloté, voir §6) |
| `PresetValueOut` | `UDINT` | Valeur de preset transmise au PDO Rx |

## 4 · ⚙️ Séquence preset SDO

| Étape | `PresetSeqStep` | Action | Sortie |
|---|---|---|---|
| IDLE | 0 | Attend front `PresetRequest` (si `EncoderAvailable`) | `PresetTriggerCmd=0` |
| Déclenchement | 1 | `PresetTriggerCmd:=2` (référence à `PresetValueOut`) | Timer `PresetTimeout` armé |
| Succès | 1→0 | `\|RawPos-PresetValueOut\| ≤ PresetTolerancePts` → maintien 500ms visuel puis `PresetAck` | `PresetTriggerCmd=0` |
| Échec | 1→0 | Timeout sans convergence → `PresetNak`, `ErrorId` bit1 | `PresetTriggerCmd=0` |

`CodeSeqTriggerCmd` toujours à `16#0000` — rôle non identifié sur le bus (voir §7).

### Chronogramme — preset réussi

| Instant | `PresetRequest` | `PresetSeqStep` | `PresetTriggerCmd` | `PresetAck` |
|---|---|---|---|---|
| t0 — repos | FALSE | 0 (IDLE) | 0 | FALSE |
| t1 — front demande | TRUE ↑ | 1 | 2 | FALSE |
| t2 — écart ≤ tolérance | TRUE | 1 | 2 | FALSE *(maintien visuel 500ms en cours)* |
| t3 — +500ms | TRUE | 0 | 0 | **TRUE** ↑ *(pulse 1 cycle)* |

Si l'écart ne converge pas avant `PresetTimeout` (déf. 2s) : `PresetNak` à la place de `PresetAck`
à t3, `ErrorId` bit1 levé, retour direct à `PresetSeqStep=0`.

## 5 · 🔒 Gel sur doute

Tant que `NOT EncoderAvailable` (bus/esclave KO), `RawPos`/`AngleRaw`/`TurnCount` **conservent leur
dernière valeur** — aucune écriture, pas de retour à 0. La lecture est gelée, mais **pas** tout le
FB : la séquence preset et l'état continuent d'être évalués (pas de `RETURN` global), pour ne pas
bloquer un preset déjà en cours si le bus revient pendant la séquence.

## 6 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Bus/esclave KO (`AlarmsIn≠0` ou `NOT SlaveOperational`) | Auto-effaçable |
| 1 | Preset refusé/timeout | Effacé par `Reset` (front, si séquence IDLE) |

## 7 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P2 | `CodeSeqTriggerCmd` — rôle non identifié sur le bus | Laissé à 0 par construction, ne jamais le piloter tant que non confirmé (commentaire code explicite) |
| 2 | mineur | `WarningsIn` déclaré, jamais lu dans la logique | Port mort, à retirer lors d'un lot dédié (hors périmètre doc) |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder`, intégration programme |
| AF03 | Contrat `standard`, tolérance T137 |
| Code | `CODE/E_CODEURS/FB_Encoder_Abs.st` |

# FB_Encoder_Safety — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.05`.
> Rôle de **ce** document : bornage physique et relais de cohérence redémarrage.
> Source code : `CODE/E_CODEURS/FB_Encoder_Safety.st` · sous-instance `instSafety` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. 🛡️ Bornage & relais cohérence
5. 📊 `ErrorId`
6. ⚠️ Alertes et écarts
7. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03) — remonte défaut bornage/cohérence. Ne calcule pas la position
(reçue de `FB_Encoder_Scale`), ne décide pas de fiabilité globale (`FB_EncoderReliability` en
aval) : ce FB **verrouille** la mesure sûre et relaie l'alerte cohérence.

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-030` (chapô) :

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
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.4</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>CablePosM</code> hors <code>[PositionMinM;PositionMaxM]</code> (déf. ±99m) → <code>EncoderIncoherent=TRUE</code>, bit0, auto-effacé au retour en plage</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.5</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>HomingSuspect=TRUE</code> → <code>EncoderIncoherent=TRUE</code>, bit1, tant que non confirmé</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.6</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>BypassGlobal=TRUE</code> → neutralise les 2 causes (mise en service)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.7</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>CablePosMSafe</code> = <code>CablePosM</code> toujours (jamais gelée — distinct du gel <code>RawPos</code> côté Abs)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` / `Reset` | `BOOL` | Standard |
| `CablePosM` | `REAL` | Position calculée (`FB_Encoder_Scale`) |
| `HomingSuspect` | `BOOL` | Alerte incohérence redémarrage (`FB_Encoder_Homing`) |
| `PositionMinM` / `PositionMaxM` | `REAL` | Bornage physique (déf. ±99.0m) |
| `BypassGlobal` | `BOOL` | Neutralise les 2 défauts (mise en service) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_Status` | Statut (ErrorId bitfield, rempli à plat) — type legacy, cible `Fault : ST_Fault` via `FB_FaultCore` (AF03 §3), migration T164-5 |
| `CablePosMSafe` | `REAL` | Position transmise (toujours réelle, non figée) |
| `EncoderIncoherent` | `BOOL` | Incohérence ou hors bornes (`= Status.Error`) |

## 4 · 🛡️ Bornage & relais cohérence

| Mécanisme | Détection | Effet |
|---|---|---|
| Bornage physique (bit0) | Hors `[PositionMinM;PositionMaxM]` | `EncoderIncoherent=TRUE`, auto-effacé au retour |
| Relais cohérence (bit1) | `HomingSuspect=TRUE` | `EncoderIncoherent=TRUE`, tant que non confirmé côté Homing |
| `BypassGlobal` | — | Neutralise les 2 causes ci-dessus |

`CablePosMSafe` **n'est jamais gelée** ici — c'est la transmission continue de la mesure. Le gel
sur perte de disponibilité a déjà eu lieu en amont, côté `FB_Encoder_Abs` (`RawPos`).

## 5 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Hors bornage `[PositionMinM;PositionMaxM]` | Auto-effaçable |
| 1 | `HomingSuspect=TRUE` | Auto-effaçable (suit l'état Homing, pas latché ici) |

## 6 · ⚠️ Alertes et écarts

Aucun écart identifié — FB simple, conforme au code vérifié.

## 7 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder` |
| AF03 | Contrat `standard` |
| Code | `CODE/E_CODEURS/FB_Encoder_Safety.st` |

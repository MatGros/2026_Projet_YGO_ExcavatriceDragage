# FB_Encoder_Scale — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.04`.
> Rôle de **ce** document : formule de conversion points → mètres.
> Source code : `CODE/E_CODEURS/FB_Encoder_Scale.st` · sous-instance `instScale` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. ⚙️ Formule de conversion
5. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `light` (AF03) — pas de cycle de vie, pas de `Reset`, pas de remontée de défaut : pur
calcul arithmétique sans état. Convertisseur unitaire, aucune décision.

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-030` (chapô) :

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Échelle</b><br>½ tour</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>HomingRefRaw</code> mémorisé, <code>PointsPerRev=8192</code>, <code>CableM_PerRev=2.0</code><br>
        🚀 <b>Étape 1</b> : Injection <code>RawPos=HomingRefRaw+4096</code> (soit ½ tour)<br>
        ⚡ <b>Étape 2</b> : Conversion <code>DINT</code> avant soustraction → <code>RawDiff=4096</code><br>
        ✅ <b>Étape 3</b> : <code>CablePosM = 4096 × (2.0/8192) = 1.0</code> m
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Échelle</b><br>négative</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>HomingRefRaw</code> mémorisé (position haute)<br>
        🚀 <b>Étape 1</b> : Injection <code>RawPos &lt; HomingRefRaw</code> (descente sous l'eau)<br>
        ⚡ <b>Étape 2</b> : <code>RawDiff</code> négatif → <code>CablePosM</code> signée négative<br>
        ✅ <b>Étape 3</b> : <code>CablePosM &lt; 0</code> (sous l'eau, convention signée +enroulé/−sous)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.3</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Division</b><br>par zéro</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>PointsPerRev=8192</code> (normal)<br>
        🚀 <b>Étape 1</b> : Injection <code>PointsPerRev=0</code> (config aberrante)<br>
        ⚡ <b>Étape 2</b> : Garde division par zéro → <code>CablePosM=0.0</code><br>
        ✅ <b>Étape 3</b> : Pas de plantage, sortie sûre (0.0)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.8</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Garde</b><br>DINT</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>RawPos</code> et <code>HomingRefRaw</code> proches des bornes <code>UDINT</code><br>
        🚀 <b>Étape 1</b> : Soustraction <code>RawPos - HomingRefRaw</code> sans conversion <code>DINT</code><br>
        ⚡ <b>Étape 2</b> : Risque de dépassement si soustraction directe <code>UDINT</code><br>
        ✅ <b>Étape 3</b> : Conversion <code>DINT</code> AVANT soustraction → pas de dépassement (<code>FB_Encoder_Scale.st:34</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-030.9</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Position</b><br>zéro</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>HomingRefRaw</code> mémorisé<br>
        🚀 <b>Étape 1</b> : Injection <code>RawPos = HomingRefRaw</code> (position de référence exacte)<br>
        ⚡ <b>Étape 2</b> : <code>RawDiff = 0</code><br>
        ✅ <b>Étape 3</b> : <code>CablePosM = 0.0</code> (<code>FB_Encoder_Scale.st:34,38</code>)
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
| `RawPos` | `UDINT` | Position brute (gelée sur doute, `FB_Encoder_Abs`) |
| `HomingRefRaw` | `UDINT` | Référence brute figée au dernier homing (`ST_Encoder_Calib`) |
| `CableM_PerRev` | `REAL` | Développement câble par tour (déf. 2.0 m/tour) |
| `PointsPerRev` | `UDINT` | Résolution codeur (déf. 8192 pts/tour) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `CablePosM` | `REAL` | Position câble signée (m, + enroulé, − sous l'eau) |

## 4 · ⚙️ Formule de conversion

```text
RawDiff := DINT(RawPos) - DINT(HomingRefRaw)     // conversion DINT AVANT soustraction (jamais l'inverse)
CablePosM := RawDiff × (CableM_PerRev / PointsPerRev)   // PointsPerRev=0 → CablePosM=0.0 (garde)
```

Aucun bornage ici — le bornage physique `[-99;+99]m` est produit en aval par `FB_Encoder_Safety`.

## 5 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder` |
| AF03 | Contrat `light` |
| Code | `CODE/E_CODEURS/FB_Encoder_Scale.st` |

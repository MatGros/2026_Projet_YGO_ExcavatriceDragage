# FB_Sim_Encoder — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.5.md`](../AF_Partie-13_Fonction_Simulation_v2.5.md) §4.
> Rôle de **ce** document : modèle simulé d'un codeur absolu de treuil — et **catalogue unique**
> des `TC-P13-030...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Encoder.st` · instances `FB_SimBench.instSimEncoderM1/M2`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Persistance `RawPos`
4. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P13-030...`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <th style="padding: 4px 8px;">Intention / Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-030</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>RelayFwd</code>/<code>RelayRev</code> font compter <code>RawPos</code> de <code>SpeedTgt_Pct * 0.1 * SpeedScaleFactor</code> par scan</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-031</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>PresetCmd=TRUE</code> charge <code>PresetValue</code> directement (priorité sur Fwd/Rev)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-032</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>RawPos</code> ne descend jamais sous 0 (borne explicite en soustraction)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-033</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>RawPos</code> survit à un reset froid (via <code>VAR_IN_OUT</code> référençant <code>GVL_PERSISTENT</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>👁️ MANUEL</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

🧩 Brique réduite (`AF_Partie-03 §2`) : pas de contrat `Enable/Reset/Error` complet — outil de banc.
Fait « compter » un codeur absolu comme si le treuil tournait réellement, à partir des relais de
sens commandés et de la vitesse rampée courante. Extraction pure d'une logique déjà en place dans
l'ancien `PRG_02_Encoders.st` (bloc « SIMULATION SUR BANC DE TEST ») — aucun changement de
comportement lors de l'extraction, juste dissociation en FB dédié.

Deux instances : une par treuil (M1/M2), câblées depuis `FB_SimBench`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Simulation active (`SimulationModeActive AND NOT BusEncoderMxIsReal`) |
| `RelayFwd`/`RelayRev` | BOOL | Sens commandé (contacteurs de sens du treuil) |
| `SpeedTgt_Pct` | REAL | Vitesse rampée courante (magnitude, %) |
| `PresetCmd` | BOOL | TRUE le cycle où un preset (homing) doit être appliqué |
| `PresetValue` | UDINT | Valeur brute à charger lors du preset |
| `SpeedScaleFactor` | REAL | Multiplicateur confort de test banc (défaut 1.0), `GVL_Simulation.SimEncoderSpeedFactor` |
| `TestOffsetCmd`/`TestOffsetPts` | BOOL / DINT | Front = injecte un vrai saut de position (test Méca E / rattrapage synchro) |

| Sortie/IN_OUT | Type | Sens |
|---|---|---|
| `RawPosOut` | UDINT | Position brute simulée, à aiguiller à la place de la valeur EtherCAT réelle |
| `RawPos` (`VAR_IN_OUT`) | UDINT | Référence `_SimEncoderRawPosM1/M2` dans `GVL_PERSISTENT` |

---

## 3. Persistance `RawPos`

`RawPos` est passé en `VAR_IN_OUT`, référencé depuis `GVL_PERSISTENT` — pas de champ interne au
FB. `PERSISTENT` n'est valide que sur du `VAR_GLOBAL` en CODESYS, pas sur une variable locale de
FB (`VAR RETAIN`/`VAR PERSISTENT RETAIN` locaux testés, aucun ne convient). Un vrai codeur absolu
physique conserve son comptage brut à travers un reset froid, indépendamment de l'automate — le
modèle simulé doit reproduire ce comportement pour rester représentatif d'un test de reprise après
coupure.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation §2 (aiguillage `WinchInputSourceSimulated`) |
| AF09/AF10 | `FB_Encoder_Abs`, `FB_Encoder_Homing` (consommateurs réels de `RawPosOut`) |
| Code | `CODE/L_SIMULATION/FB_Sim_Encoder.st`, `CODE/GVL_PERSISTENT.st` |

# FB_Winch — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §2.
> Rôle de **ce** document : directeur mouvement treuil (rampe, palier, sens, frein) — et
> **catalogue unique** des `TC-P10-011`, `017`, `018`, `019`.
> Compose `FB_SpeedStep` (§5), `FB_Brake` (§6), `FB_Ramp` (résumés ici, pas de fiche séparée).
> Source code : `CODE/H_TREUILS_BENNE/FB_Winch.st` · instances `instWinchM1/M2` dans `PRG_04_Treuils_Benne`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Interlock de sens
4. Plafonds dynamiques palier
5. FB_SpeedStep (composé) — paliers
6. FB_Brake (composé) — séquence frein
7. Alertes et écarts
8. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P10-011/017/018/019`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-011</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Inversion Fwd↔Rev en descente exige <code>DirectionInterlockDelayDescent</code>=400ms (+100ms palier=500ms) ; en montée <code>DirectionInterlockDelayAscent</code>=900ms (+100ms=1000ms). Neutre↔sens = immédiat. <code>DirectionChangePending</code> force la rampe à 0.0 pendant l'attente. Redémarrage même sens / inversion : temps mort 1s.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-017</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Config palier invalide (<code>FB_SpeedStep</code>) ➔ palier 0, sorties sûres</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-018</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>StuckClosed</code> : contacteurs off non confirmés 500ms ➔ bit1</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-019</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Ordre MainTask : Safety ➔ WinchControl ➔ PRG_06_Outputs</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ SITE+AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-042.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Plafonds dynamiques palier par contexte : descente max 3, montée max 5, approche capteur haut=1, zones ralentissement haut/bas capent le palier.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-052.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Garde-fou vitesse (<code>SpeedGuardEnable</code>, désactivé par défaut) : vitesse non-stable → palier 1 ; <code>MeasuredSpeedBand</code> &lt; <code>StepNumber</code> → bride. Testable après activation.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

FB de **mouvement** (Partie3 §1bis) : porte `StartStop`+`SafeStop` en plus du standard.
Précédence `Enable > SafeStop > StartStop`. 2 instances (`instWinchM1`, `instWinchM2`).

```text
FB_Winch
 ├─ FB_SpeedStep    (palier → 4 contacteurs, §5)
 ├─ FB_Brake        (séquence frein, §6 — partagé Translation)
 └─ FB_Ramp         (accel/décel générique, %/s)
```

---

## 2. Interface

| Port entrée | Type | Sens |
|---|---|---|
| `Enable/Reset/PowerContactorEngaged/Mode` | — | Standard |
| `StartStop/SafeStop` | BOOL | Standard mouvement |
| `DescendPermit`/`AscentPermit` | BOOL | Autorisations dédiées fail-safe (≠ SafeStop, sortie `FB_Safety_Winch`) |
| `Direction`/`SpeedTgt_Pct` | INT/REAL | Consigne |
| `SpeedStepTable` | ST_SpeedStepTable | Table 5 paliers propre au treuil |
| `CfgMaxStepDescente` :=3 / `MaxStepAscent` :=5 | INT | Plafonds palier |
| `HomingApproachActive` | BOOL | Limite palier 1 en approche capteur haut |
| `FwdRevSpeedFeedbackOff`/`BrakeFeedback` | BOOL | Confirmation arrêt |
| `Homed`/`HomingSuspect`/`CablePosM` | — | Sortie Encodeurs (AF09) |
| `TopLimitM` :=8.5 / `BottomLimitM` :=-20.0 | REAL | Limites actives |
| `CfgSlowdownDistanceM` :=1.0 / `CfgSlowSpeedPct` :=15.0 | REAL | Ralentissement approche |
| `SpeedGuardEnable`/`Ready` :=FALSE | BOOL | Garde-fou palier (désactivé — voir AF10 §9bis) |

**Sorties** : `Ready/Busy/Done/Error/State`, `ErrorId` (bit0 frein, bit1 contacteurs collés,
bit2 config invalide), `RelayFwd/Rev`, `Contactor1..4`, `StepNumber`, `BrakeCmd`, `ContactorsCheck`.

---

## 3. Interlock de sens (vérifié code)

Neutre↔un sens = immédiat. Inversion directe Fwd↔Rev exige vitesse<0.1 **et** délai
`DirectionInterlockDelay`=200ms. `DirectionChangePending` force la cible de rampe à 0.0 de façon
déterministe pendant l'attente (corrige un bug historique : inversion plus rapide que la
décélération réelle pouvait bloquer indéfiniment `CommandedDirection`).

**Nouveau : temps mort de redémarrage après arrêt** — distinct de l'inversion de sens :
- **Redémarrage même sens** : temps mort paramétrable `DeadTimeSameDir` (défaut **1s**) après `MotorRequest=FALSE` → nouvelle demande même sens.
- **Redémarrage inversion sens** : temps mort paramétrable `DeadTimeOppositeDir` (défaut **1s**, > temps mort même sens) — **en sus** du délai d'inversion 200ms FB_Winch.

Ces temps morts s'appliquent **dans la barrière finale** (FB_WinchOutputInterlock), supérieurs aux délais internes FB_Winch (inversion 200ms + palier 1s250ms).

---

## 4. Plafonds dynamiques palier

| Condition | Plafond |
|---|---|
| Non référencé / HomingSuspect | 1 |
| Descente | `CfgMaxStepDescente` (3) |
| Montée + approche capteur haut | 1 |
| Montée normale | `MaxStepAscent` (5) |
| Neutre | 5 |

⚠️ Hausse palier : délai **1s500ms** hard-codé dans `FB_Winch` (pas paramétrable) — voir écart §7.

**StuckClosed** (bit1 `ErrorId`) : `AllContactorsCommandedOff AND NOT FwdRevSpeedFeedbackOff`
pendant `ContactorFeedbackTimeout`=500ms ⇒ défaut. Vérifié **uniquement à l'arrêt commandé**
(pas de détail par sens, retour unique terrain).

---

## 5. FB_SpeedStep (composé — résumé, pas de fiche séparée)

Brique réduite (Partie3 §1bis, pas d'Enable/Reset/State propre) : décodeur palier → 4
contacteurs. 5 paliers, table propre par treuil (`ST_SpeedStepTable` : `P1R1..P5R4` +
`StepThreshold_Pct[1..5]`). Sélection par 4× `HYSTERESIS` (lib Util, `HystMargin`=2.0%).

**Validation config** (P0.2) : seuils strictement croissants [0..100], hystérésis>0, cohérence
contacteurs (≥1 TRUE par palier 2..plafond ; palier 1 tout-FALSE licite = résistances rotoriques
max). Config invalide ⇒ `ConfigError`, palier forcé à 0, sorties sûres.

**Garde-fou vitesse réelle** (`SpeedGuardEnable`, désactivé par défaut) : bride palier 1 si
non stable, ou `MeasuredSpeedBand` si dépassement. Voir AF10 §9bis (T94/T95/T96).

---

## 6. FB_Brake (composé — résumé, partagé avec Translation)

Séquence frein à manque de courant (colle au repos). `MovementRequested` (sens+palier>0)
déclenche : attente fermeture contacteur + magnétisation moteur (`DelayContactClose`+
`DelayMagnetise`) **avant** de relâcher le frein (sinon charge retombe, à-coup).

⚠️ **Code mort confirmé** : `DelayMotorDecel`/`TonDecel` (délai avant collage à l'arrêt) est
propagé dans l'interface mais **jamais armé** (`TonDecel(IN:=FALSE,...)`) — le frein colle
**immédiatement** dès que les contacteurs de sens s'ouvrent, aucune temporisation réelle.
Voir AF10 §9bis (T87/T91) — décision différée, étude terrain requise avant de trancher.

**Double vérification retour** (`ST_ContactorCheck`) : `BrakeCmd` (TRUE=relâché) et
`ContactorFeedback` normalisé (TRUE=serré) sont **toujours opposés** en marche saine — c'est
leur **égalité** qui signale un contacteur/bobine collé (pas leur différence).

---

## 7. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P1 | Délai hausse palier `FB_Winch` (1s500ms) ≠ délai barrière finale (1s250ms) — cumul possible | Voir AF10 §9bis, `FB_WinchOutputInterlock` §4 |
| 2 | P1 | `DelayMotorDecel` code mort dans `FB_Brake` | Voir AF10 §9bis (T87/T91), étude terrain requise |
| 3 | P2 | Rampe %/s (`CfgRampAccelRate` etc.) peu pertinente pour paliers discrets | Voir AF10 §9bis (T93) |

---

## 8. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme, TBD Lot 4 |
| AF10 / FB_Safety_Winch | `SafeStop`/`DescendPermit`/`AscentPermit` consommés |
| AF10 / FB_WinchOutputInterlock | Consommateur de la demande produite ici |
| AF09 | Encodeurs — `Homed`, `CablePosM`, vitesse |
| AF10 / [FB_Bucket](FB_Bucket_v1.0.md) | Benne — sous-fonction M2 de ce FB |
| Code | `CODE/H_TREUILS_BENNE/FB_Winch.st`, `FB_SpeedStep.st`, `CODE/A_COMMUN/FB_Brake.st` |

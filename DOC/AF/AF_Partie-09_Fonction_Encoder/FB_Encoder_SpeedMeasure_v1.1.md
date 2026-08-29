# FB_Encoder_SpeedMeasure — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §7 — couvre `F09.07`.
> Rôle de **ce** document : mesure de vitesse câble sur fenêtre glissante horodatée.
> Source code : `CODE/E_CODEURS/FB_Encoder_SpeedMeasure.st` · sous-instance `instSpeed` de
> `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. ⚙️ Fenêtre glissante horodatée
5. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `light` (AF03) — pas de remontée de défaut propre (`Valid=FALSE` suffit à signaler
l'indisponibilité, pas un `ErrorId`). Calcul pur sur position sûre déjà produite par
`FB_Encoder_Safety`.

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-050` (chapô) :

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Valid=TRUE</code> seulement après 6 échantillons couvrant <code>WindowElapsed ≥ T#50ms</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.2</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>PositionValid=FALSE</code> (amont) → purge complète immédiate (<code>CollectedSamples:=0</code>, <code>Valid:=FALSE</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.3</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Rebouclage <code>TIME()</code> détecté (<code>CurrentTimestamp &lt; LastTimestamp</code>) → purge sans réutiliser le delta aberrant</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.4</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SignedSpeed_Mps</code> signée (+ montée) ; <code>Speed_Mps = ABS(SignedSpeed_Mps)</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.5</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Fenêtre &lt;50ms → <code>Valid=FALSE</code> sans purge (buffer conservé) (FB_Encoder_SpeedMeasure.st:128-132)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-050.6</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Vitesse exacte : <code>SignedSpeed_Mps=(P[5]−P[0])/WindowElapsed</code> ; <code>Speed_Mps=ABS</code> (FB_Encoder_SpeedMeasure.st:124-126)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | Autorisation générale |
| `Reset` | `BOOL` | Purge immédiate de l'historique (front) |
| `Position_M` | `REAL` | Position câble sûre (`FB_Encoder_Safety.CablePosMSafe`) |
| `PositionValid` | `BOOL` | Validité chaîne codeur (`NOT FB_EncoderReliability.EncoderFault`) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Speed_Mps` | `REAL` | Vitesse absolue sur fenêtre glissante |
| `SignedSpeed_Mps` | `REAL` | Vitesse signée (+ montée, − descente) |
| `Valid` | `BOOL` | 6 échantillons valides sur ≥50ms |

## 4 · ⚙️ Fenêtre glissante horodatée

Constantes : `WindowTime=T#50MS`, `SamplePeriod=T#10MS`, `SampleCount=6`.

- Horodatage natif (`TIME()`), jamais un cycle scan supposé.
- Échantillon collecté seulement si `ElapsedSinceSample ≥ SamplePeriod` (évite le suréchantillonnage).
- Buffer plein (6) : décalage FIFO (`FOR Index := 0 TO 4`), pas de réinitialisation.
- Vitesse calculée seulement si `Timestamps[5] ≥ Timestamps[0]` (ordre temporel) **et**
  `WindowElapsed ≥ WindowTime` :
  - Fenêtre trop courte (`WindowElapsed < WindowTime`) → `Valid=FALSE` **sans purge** (attend le
    prochain échantillon, buffer conservé).
  - Ordre temporel rompu (`Timestamps[5] < Timestamps[0]`) → `Valid=FALSE` **avec purge complète**
    (buffer remis à zéro) — cas distinct, pas le même traitement.
- Purge complète (historique remis à zéro) sur : `NOT Enable`, `Reset`, `NOT PositionValid`,
  rebouclage `TIME` détecté, ordre temporel rompu (ci-dessus).

```text
SignedSpeed_Mps := (Positions_M[5] - Positions_M[0]) / (WindowElapsed_s)
Speed_Mps       := ABS(SignedSpeed_Mps)
```

## 5 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder` |
| AF10 | Consommateur `Speed_Mps`/`SignedSpeed_Mps` (`FB_Safety_Winch`, détection mouvement non commandé) |
| Code | `CODE/E_CODEURS/FB_Encoder_SpeedMeasure.st` |

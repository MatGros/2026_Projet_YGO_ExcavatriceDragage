# FB_Encoder_SpeedMeasure — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §7 — couvre `F09.07`.
> Rôle de **ce** document : mesure de vitesse câble sur fenêtre glissante horodatée.
> Source code : `CODE/E_CODEURS/FB_Encoder_SpeedMeasure.st` · sous-instance `instSpeed` de
> `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. ⚙️ Fenêtre glissante horodatée
5. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `light` (AF03) — pas de remontée de défaut propre (`Valid=FALSE` suffit à signaler
l'indisponibilité, pas un `ErrorId`). Calcul pur sur position sûre déjà produite par
`FB_Encoder_Safety`.

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-050` (chapô) :

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Réf | Etat |
|---|---|---|---|---|
| <nobr><code>TC-P09-050.1</code></nobr> | `Valid=TRUE` seulement après 6 échantillons couvrant `WindowElapsed ≥ T#50ms` | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-050.2</code></nobr> | `PositionValid=FALSE` (amont) → purge complète immédiate (`CollectedSamples:=0`, `Valid:=FALSE`) | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-050.3</code></nobr> | Rebouclage `TIME()` détecté (`CurrentTimestamp < LastTimestamp`) → purge sans réutiliser le delta aberrant | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-050.4</code></nobr> | `SignedSpeed_Mps` signée (+ montée) ; `Speed_Mps = ABS(SignedSpeed_Mps)` | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |

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

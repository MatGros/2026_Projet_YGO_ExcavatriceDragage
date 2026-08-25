# FB_Encoder_Scale — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.04`.
> Rôle de **ce** document : formule de conversion points → mètres.
> Source code : `CODE/E_CODEURS/FB_Encoder_Scale.st` · sous-instance `instScale` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. ⚙️ Formule de conversion
5. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `light` (AF03) — pas de cycle de vie, pas de `Reset`, pas de remontée de défaut : pur
calcul arithmétique sans état. Convertisseur unitaire, aucune décision.

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-030` (chapô) :

| ID | Comportement attendu | Type | Réf |
|---|---|---|---|
| <nobr><code>TC-P09-030.1</code></nobr> | `RawPos=HomingRefRaw+4096` (soit ½ tour), `CableM_PerRev=2.0`, `PointsPerRev=8192` → `CablePosM=1.0` | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-030.2</code></nobr> | `RawPos<HomingRefRaw` → `CablePosM` négative (sous l'eau) | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-030.3</code></nobr> | `PointsPerRev=0` → `CablePosM=0.0` (garde division par zéro), pas de plantage | <nobr><code>💻 AUTO</code></nobr> | §4 |

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

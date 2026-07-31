# FB_Encoder_Scale — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §5.  
> Rôle de **ce** document : conversion cinématique des points bruts codeur en mètres de câble déroulé/enroulé.  
> Source code : `CODE/CODEURS/FB_Encoder_Scale.st` · instances `instEncoderScaleM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Calcul cinématique
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-013 | Conversion linéaire exacte `PointsPerRev` ➔ mètres câble selon ratio tambour | `💻 AUTO` |

---

## 1. Rôle et profil

Brique technique de **conversion d'échelle** : transforme la différence entre la position brute courante (`RawPos`) et la référence de homing (`HomingRefRaw`) en une distance physique exprimée en mètres (`CablePosM`).

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `RawPos` | UDINT | Position brute qualifiée issue de `FB_Encoder_Abs` |
| `HomingRefRaw` | UDINT | Référence brute issue de `FB_Encoder_Homing` |
| `PointsPerRev` | UDINT | Nbre de points par tour (défaut 8192) |
| `MetersPerRev` | REAL | Nbre de mètres de câble par tour de tambour |
| `InvertSense` | BOOL | Inversion du sens de comptage (montée/descente) |

**Sorties** :
- `CablePosM : REAL` : Position calculée du câble en mètres.

---

## 3. Calcul cinématique

$$\text{DeltaPts} = \text{RawPos} - \text{HomingRefRaw}$$
$$\text{CablePosM} = \left( \frac{\text{DeltaPts}}{\text{PointsPerRev}} \right) \times \text{MetersPerRev} \times (\text{si InvertSense THEN } -1.0 \text{ ELSE } 1.0)$$

---

## 4. Alertes et écarts

- N'effectue aucun filtrage temporel (le filtrage et la surveillance de vitesse sont délégués à `FB_Encoder_SpeedMeasure`).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)

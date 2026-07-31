# FB_Encoder_Scale — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §5.  
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

## 2. Interface (vérifiée `CODE/CODEURS/FB_Encoder_Scale.st`)

| Port entrée | Type | Rôle |
|---|---|---|
| `RawPos` | UDINT | Position brute — sortie `FB_Encoder_Abs`, déjà gelée sur doute |
| `HomingRefRaw` | UDINT | Référence brute figée au dernier homing (`ST_EncoderCalib`) |
| `CableM_PerRev` | REAL := 2.0 | Câble déroulé par tour de tambour (périmètre confirmé terrain, RETAIN site) |
| `PointsPerRev` | UDINT := 8192 | Résolution codeur |

**Sortie** :
- `CablePosM : REAL` : Position câble en mètres, signée (+ enroulé, − sous l'eau).

⚠️ **Pas de port `InvertSense`.** L'inversion de sens de comptage est gérée **côté codeur**
(objet CoE `6000h`, Startup Parameter CODESYS), pas dans ce FB. Un ancien calcul logiciel
équivalent (`InvertDirection`, `16#FFFFFFFF - RawPosIn`) a été **retiré le 2026-07-03** : il
inversait sur toute la plage `UDINT` (32 bits) au lieu de la plage réelle du codeur (25 bits),
produisant des positions incohérentes après homing. Ne pas réintroduire côté PLC.

---

## 3. Calcul cinématique

```
RawDiff (DINT)  = UDINT_TO_DINT(RawPos) − UDINT_TO_DINT(HomingRefRaw)   ⚠️ conversion DINT
                                                                            AVANT soustraction
CablePosM       = RawDiff × (CableM_PerRev / PointsPerRev)   si PointsPerRev > 0
                = 0.0                                          sinon (garde division par zéro)
```

⚠️ **Garde arithmétique obligatoire** : soustraire deux `UDINT` directement reboucle
silencieusement vers ~2³² en cas de résultat négatif (`RawPos < HomingRefRaw`, cas normal en
descente sous la référence). La conversion `DINT` **avant** la soustraction est donc une
exigence de sécurité de calcul, pas un détail d'implémentation.

---

## 4. Alertes et écarts

- N'effectue aucun filtrage temporel (le filtrage et la surveillance de vitesse sont délégués à `FB_Encoder_SpeedMeasure`).
- Brique de calcul pure : pas de gel ni de bornage ici (`RawPos` déjà gelé par `FB_Encoder_Abs` ;
  le bornage physique `[-99;+99] m` est la responsabilité de `FB_Encoder_Safety`).
- 🟠 **Nommage** : `CablePosM` (sortie) sans underscore avant le suffixe d'unité `M` — non
  conforme `NAMING_CONVENTION.md` §Suffixes d'unité. Ne pas renommer au fil de l'eau (voir chapô
  AF-09 §6 point 9).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)

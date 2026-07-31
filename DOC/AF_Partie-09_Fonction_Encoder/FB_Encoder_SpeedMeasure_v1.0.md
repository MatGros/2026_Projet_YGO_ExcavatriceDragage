# FB_Encoder_SpeedMeasure — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §5.  
> Rôle de **ce** document : calcul de la vitesse linéaire réelle du câble (m/s) par glissement d'échantillons horodatés.  
> Source code : `CODE/CODEURS/FB_Encoder_SpeedMeasure.st` · instances `instEncoderSpeedMeasureM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Algorithme de calcul
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-014 | Calcul vitesse m/s sur fenêtre fixe 50 ms sans filtre passe-bas PT1 parasite | `💻 AUTO` |

---

## 1. Rôle et profil

Brique technique de **mesure de vitesse linéaire** : calcule la vitesse du câble en m/s (absolue et signée) à partir de la dérivée temporelle réelle de la position.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `CablePosM` | REAL | Position courante sécurisée (m) |
| `EncoderAvailable` | BOOL | Disponibilité du signal codeur |

**Sorties** :
- `MeasuredSpeed_Mps : REAL` : Vitesse linéaire absolue en m/s ($\ge 0.0$).
- `MeasuredSpeedSigned_Mps : REAL` : Vitesse signée (positive en montée, négative en descente).
- `SpeedValid : BOOL` : `TRUE` si la fenêtre d'échantillonnage est remplie et que l'encodeur est disponible.

---

## 3. Algorithme de calcul

- **Fenêtre d'échantillonnage** : 6 positions horodatées conservées dans un buffer circulaire (5 intervalles temporels de 10 ms = fenêtre totale fixe de 50 ms).
- Calcul de la vitesse par ratio $\frac{\Delta \text{Position}}{\Delta \text{Temps\_réel\_écolé}}$, évitant les retards de phase introduits par les filtres du premier ordre (`PT1`).

---

## 4. Alertes et écarts

- Utilisé par `FB_Safety_Winch` pour la surveillance des survitesses et dérives sous frein (Méca A).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)

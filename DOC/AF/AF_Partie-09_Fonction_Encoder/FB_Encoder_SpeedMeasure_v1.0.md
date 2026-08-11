# FB_Encoder_SpeedMeasure — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §5.  
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
| <nobr><code>TC-P09-014</code></nobr> | Calcul vitesse m/s sur fenêtre fixe 50 ms sans filtre passe-bas PT1 parasite | `💻 AUTO` |

---

## 1. Rôle et profil

Brique technique de **mesure de vitesse linéaire** : calcule la vitesse du câble en m/s (absolue et signée) à partir de la dérivée temporelle réelle de la position.

---

## 2. Interface (vérifiée `CODE/CODEURS/FB_Encoder_SpeedMeasure.st`)

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable` | BOOL | Autorise l'acquisition |
| `Reset` | BOOL | Purge immédiate de l'historique (6 positions) |
| `Position_M` | REAL | Position câble **sûre** — sortie `FB_Encoder_Safety.CablePosMSafe`, pas `FB_Encoder_Scale` directement |
| `PositionValid` | BOOL | `TRUE` si la chaîne codeur garantit la position |

**Sorties** :
- `Speed_Mps : REAL` : Vitesse absolue sur la fenêtre horodatée.
- `SignedSpeed_Mps : REAL` : Vitesse signée (positive montée, négative descente).
- `Valid : BOOL` : `TRUE` après 6 positions couvrant au moins 50 ms.

---

## 3. Algorithme de calcul

- **Fenêtre d'échantillonnage** : 6 positions horodatées conservées dans un buffer circulaire (5 intervalles temporels de 10 ms = fenêtre totale fixe de 50 ms).
- Calcul de la vitesse par ratio $\frac{\Delta \text{Position}}{\Delta \text{Temps\_réel\_écolé}}$, évitant les retards de phase introduits par les filtres du premier ordre (`PT1`).

---

## 4. Alertes et écarts

- Utilisé par `FB_Safety_Winch` pour la surveillance des survitesses et dérives sous frein (Méca A).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)

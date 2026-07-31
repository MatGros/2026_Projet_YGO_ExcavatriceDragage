# FB_Encoder_SpeedMonitor — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §5.  
> Rôle de **ce** document : diagnostic et détection de variations brusques/incohérentes de vitesse.  
> Source code : `CODE/CODEURS/FB_Encoder_SpeedMonitor.st` · instances `instSpeedMonitorM1/M2` dans `Safety (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Surveillance et alarme
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-015 | Détection de variation de vitesse brusque > seuil paramétrable avec tempo de confirmation | `💻 AUTO` |

---

## 1. Rôle et profil

Brique de **diagnostic passif et de surveillance cinématique** : surveille l'accélération et les sauts brusques de vitesse mesurée pour lever une alerte IHM en cas d'anomalie mécanique ou d'échantillonnage.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `MeasuredSpeedMps` | REAL | Vitesse courante mesurée en m/s |
| `SpeedValid` | BOOL | Signal de validité de la mesure |
| `MaxAllowedSpeedStepMps` | REAL | Seuil maximal de saut de vitesse autorisé entre deux cycles |
| `ConfirmationDelayMs` | UDINT | Durée de temporisation avant levée du défaut |

**Sorties** :
- `SpeedAbnormal : BOOL` : `TRUE` si une variation anormale est confirmée.
- `SpeedStepDetected : BOOL` : Signal transitoire de détection de saut de vitesse.

---

## 3. Surveillance et alarme

- N'engendre pas d'arrêt automatique (`SafeStop`) direct : produit une alarme d'alerte pour le diagnostic et l'IHM.

---

## 4. Alertes et écarts

- **Seuils inertes (0 par défaut)** : Les seuils restent désactivés jusqu'au calibrage complet des plages de vitesse terrain (T45).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)

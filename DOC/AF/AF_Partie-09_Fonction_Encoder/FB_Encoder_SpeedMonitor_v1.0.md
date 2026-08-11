# FB_Encoder_SpeedMonitor — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §5.  
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

## 2. Interface (vérifiée `CODE/CODEURS/FB_Encoder_SpeedMonitor.st`)

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable` | BOOL | Autorise la surveillance |
| `Reset` | BOOL | Acquittement défaut (front) |
| `PowerContactorEngaged` | BOOL | Standard |
| `Mode` | E_Mode | Contexte de fonctionnement |
| `SpeedMps` | REAL | Vitesse linéaire absolue mesurée (m/s) |
| `SpeedVariationThresholdMps` | REAL | Variation minimale à surveiller entre 2 cycles (m/s) |
| `SpeedVariationTimeout` | TIME | Durée minimale de confirmation avant défaut |
| `SpeedStabilityTimeout` | TIME | Durée sans variation avant `SpeedStable = TRUE` |

**Sorties** :
- `ErrorId` : bit0 = variation de vitesse confirmée.
- `SpeedDeltaMps : REAL` : écart absolu entre deux mesures.
- `SpeedVariationDetected : BOOL` : seuil dépassé sur le cycle courant.
- `SpeedVariationConfirmed : BOOL` : seuil dépassé pendant `SpeedVariationTimeout`.
- `SpeedStable : BOOL` : vitesse stable pendant `SpeedStabilityTimeout` — **sortie à effet aval**, voir §4.

---

## 3. Surveillance et alarme

- N'engendre pas d'arrêt automatique (`SafeStop`) direct : `ErrorId` bit0 reste mémorisé jusqu'à
  disparition de la cause et acquittement par front `Reset` (pattern Cause/Ack, `CODE_QUALITY_STANDARDS §9`).
- Le seuil et la durée de confirmation sont fournis par l'appelant : aucun réglage métier n'est figé dans cette brique.

---

## 4. Alertes et écarts

- **Seuils inertes** : `SpeedVariationThresholdMps`/`SpeedVariationTimeout` câblés à `0`/`T#0ms`
  dans `PRG_SAFETY_CFC.st` — `ErrorId` bit0 **ne peut jamais se déclencher** actuellement (volontaire,
  en attente calibrage terrain T45).
- 🔴 **`SpeedStable` n'est pas qu'un diagnostic** : elle conditionne `SpeedGuardReady` dans
  `FB_SpeedStep`, qui bride le palier de vitesse Winch à 1 tant qu'elle n'est pas confirmée
  (`PRG_TREUILS_CFC.st`, `FB_SpeedStep.st`). Avec `SpeedStabilityTimeout = T#0ms`,
  `SpeedStable` reste `FALSE` en permanence — **sans effet aujourd'hui** car
  `SpeedGuardEnableM1/M2 := FALSE` (garde-fou palier non activé). ⚠️ Piège identifié : le jour où
  `SpeedGuardEnable` passe à `TRUE` **sans** régler `SpeedStabilityTimeout` en même temps, la
  machine reste bridée au palier 1 en permanence. Les deux réglages doivent être activés ensemble.
- 🟠 **Nommage** : `SpeedMps`/`SpeedDeltaMps`/`SpeedVariationThresholdMps` sans underscore avant
  `Mps` — non conforme `NAMING_CONVENTION.md` §Suffixes d'unité, et **incohérent avec le FB voisin
  du même domaine** `FB_Encoder_SpeedMeasure` qui utilise déjà `Speed_Mps`/`SignedSpeed_Mps` avec
  underscore. Ne pas renommer au fil de l'eau (voir chapô AF-09 §6 point 9).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)

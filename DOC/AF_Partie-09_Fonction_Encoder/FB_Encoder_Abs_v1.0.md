# FB_Encoder_Abs — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §2.  
> Rôle de **ce** document : acquisition brute bus EtherCAT, gestion de la disponibilité et des requêtes de preset.  
> Source code : `CODE/CODEURS/FB_Encoder_Abs.st` · instances `instEncoderAbsM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Séquence Preset
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-001/002` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-001 | Preset `PresetTriggerCmd=2` sous tolérance 10 pts et timeout 2s | `⚡ AUTO_PLC` |
| TC-P09-002 | `RawPos` gelé si `EncoderAvailable=FALSE` (perte bus EtherCAT) | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

Brique de **qualification d'entrée** (Partie3 §2) : lit la position brute EtherCAT (`RawPosIn`) et exécute les ordres de calibration/preset envoyés par `FB_Encoder_Homing`.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `RawPosIn` | UDINT | Position brute issue du variateur/bus EtherCAT |
| `AlarmsIn` | UINT | Alarmes matérielles brutes |
| `SlaveOperational` | BOOL | État opérationnel de l'esclave EtherCAT (`FB_DiagEthercat`) |
| `PresetRequest` | BOOL | Demande d'écriture de preset (issue de `FB_Encoder_Homing`) |
| `PresetValue` | UDINT | Valeur brute de preset à appliquer |

**Sorties** :
- `RawPos : UDINT` : Position brute qualifiée (gelée sur sa dernière valeur si `EncoderAvailable = FALSE`).
- `EncoderAvailable : BOOL` : `TRUE` si l'esclave est opérationnel et qu'aucun défaut n'est actif (`(ErrorId AND 1) = 0`).
- `PresetAck / PresetNak : BOOL` : Impulsions de confirmation (Ack) ou de rejet/timeout (Nak).

---

## 3. Séquence Preset

- **Constantes** : `PointsPerRev = 8192`, `PresetTimeout = T#2s`, `PresetTolerancePts = 10`.
- **Mécanisme** : Lors d'un front montant de `PresetRequest`, le bloc envoie la commande `PresetTriggerCmd := 2` (valeur confirmée terrain) et attend que `|RawPos - PresetValueOut| <= 10 pts` dans la fenêtre de 2 secondes.
- Si le délai expire sans convergence, `PresetNak` est émis et le bit1 d'ErrorId est positionné.

---

## 4. Alertes et écarts

- `RawPos` doit impérativement être gelé en cas de perte de bus pour éviter des sauts de position virtuels dans les blocs aval.

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)

# FB_Encoder_Abs — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §2.  
> Rôle de **ce** document : acquisition brute bus EtherCAT, gestion de la disponibilité et des requêtes de preset.  
> Source code : `CODE/E_CODEURS/FB_Encoder_Abs.st` · instances `instEncoderAbsM1/M2` dans `PRG_02_Acquisition`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Séquence Preset
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-001/002` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P09-001</code></nobr> | Preset `PresetTriggerCmd=2` sous tolérance 10 pts et timeout 2s | `⚡ AUTO_PLC` |
| <nobr><code>TC-P09-002</code></nobr> | `RawPos` gelé si `EncoderAvailable=FALSE` (perte bus EtherCAT) | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

Brique de **qualification d'entrée** (Partie3 §2) : lit la position brute EtherCAT (`RawPosIn`) et exécute les ordres de calibration/preset envoyés par `FB_Encoder_Homing`.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `PowerContactorEngaged` | BOOL | Standard |
| `Mode` | E_Mode | Standard (contexte, pas encore exploité ce lot) |
| `RawPosIn` | UDINT | Position brute issue du variateur/bus EtherCAT |
| `AlarmsIn` | UINT | Alarmes matérielles brutes |
| `WarningsIn` | UINT | Avertissements matériels bruts — informatif seulement |
| `SlaveOperational` | BOOL | État opérationnel de l'esclave EtherCAT (`FB_Diag_Ethercat`) |
| `PointsPerRev` | UDINT := 8192 | Résolution codeur |
| `PresetRequest` | BOOL (front) | Demande d'écriture de preset (issue de `FB_Encoder_Homing`) |
| `PresetValue` | UDINT | Valeur brute de preset à appliquer |
| `PresetTimeout` | TIME := T#2s | Délai max de convergence post-preset |
| `PresetTolerancePts` | UDINT := 10 | Tolérance relecture post-preset |

**Sorties** :
- `RawPos : UDINT` : Position brute qualifiée (gelée sur sa dernière valeur si `EncoderAvailable = FALSE`).
- `EncoderAvailable : BOOL` : `TRUE` si l'esclave est opérationnel et qu'aucun défaut n'est actif (`(ErrorId AND 1) = 0`).
- `AngleRaw`/`TurnCount` : informatif maintenance (`RawPos MOD/DIV PointsPerRev`).
- `PresetAck / PresetNak : BOOL` : Impulsions de confirmation (Ack) ou de rejet/timeout (Nak).
- `PresetTriggerCmd`/`CodeSeqTriggerCmd`/`PresetValueOut` : à câbler sur les RxPDO codeur.

**`ErrorId`** : bit0 = "Défaut communication codeur" (alarme/bus) ; bit1 = "Erreur référencement (timeout)" (preset refusé/timeout).

---

## 3. Séquence Preset EtherCAT

- **Constantes** : `PointsPerRev = 8192`, `MultiTurnRevsMax = 4096`, `PresetTimeout = T#2s`, `PresetTolerancePts = 10`.
- **Cible nominale** : `HomingRefTarget = (PointsPerRev × MultiTurnRevsMax) / 2`
  `= (8192 × 4096) / 2 = 16 777 216 points UL`. Cette valeur est le centre de la plage
  multitour totale de `33 554 432 points UL`, pas la moitié d'un seul tour (`4096 points`).
- **Mécanisme** : Lors d'un front montant de `PresetRequest`, le bloc envoie la commande `PresetTriggerCmd := 2` (valeur confirmée terrain) et attend que `|RawPos - PresetValueOut| <= 10 pts` dans la fenêtre de 2 secondes.
- Si le délai expire sans convergence, `PresetNak` est émis et le bit1 d'ErrorId est positionné.

---

## 4. Alertes et écarts

- `RawPos` doit impérativement être gelé en cas de perte de bus pour éviter des sauts de position virtuels dans les blocs aval.

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)

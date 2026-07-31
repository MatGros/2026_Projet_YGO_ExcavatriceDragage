# FB_Encoder_Homing — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §3.  
> Rôle de **ce** document : gestion du référencement (homing nominal et unitaire), mémorisation RETAIN et qualification du doute.  
> Source code : `CODE/CODEURS/FB_Encoder_Homing.st` · instances `instHomingM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Conditions d'exécution et vérifications
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-003 à 009` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-003 | Homing nominal refusé sans capteur haut (hors bypass) ➔ Bit4 | `⚡ AUTO_PLC` |
| TC-P09-004 | Homing refusé si arrêt non confirmé (contacteurs+frein) ➔ Bit2 | `⚡ AUTO_PLC` |
| TC-P09-005 | Homing unitaire refusé hors MAINT_N2 ou treuil erroné ➔ Bit0/Bit1 | `💻 AUTO` |
| TC-P09-006 | Cible hors [-99;+99] m rejetée sans écriture preset | `💻 AUTO` |
| TC-P09-007 | `HomingRefRaw` conforme ; `CablePosM` = cible post-Done | `⚡ AUTO_PLC` |
| TC-P09-008 | Écart au reboot ➔ `HomingSuspect`, `Homed` masqué | `⚡ AUTO_PLC` |
| TC-P09-009 | `BtnConfirmCoherence` lève le doute sans réécrire ref | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

Brique de **référencement et calibration** : calcule la position de référence brute (`HomingRefRaw`) à appliquer au codeur pour qu'une hauteur cible donnée (`CfgHomingTargetM`) corresponde exactement à la cote physique.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `BtnHome` | BOOL | Front montant déclenchant le homing |
| `BtnHomingAtZero` | BOOL | Front montant déclenchant le homing forcé à 0.0 m (mise en service) |
| `BtnConfirmCoherence` | BOOL | Acquitte l'état `HomingSuspect` au boot |
| `TopSensorSwitch` | BOOL | État du capteur physique fin de course haut |
| `TopSensorBypass` | BOOL | Bypass de sécurité pour essais |
| `FwdRevSpeedFeedbackOff/BrakeFeedback` | BOOL | Confirmation d'arrêt mécanique |
| `RawPos` | UDINT | Position brute du codeur |
| `CfgTopSensorPos_M` | REAL | Cote physique assignée au capteur haut (ex. 8.0 m) |
| `CfgHomingTargetM` | REAL | Cote cible configurée pour le homing unitaire |

**InOut** : `Calib : ST_EncoderCalib` (Structure RETAIN contenant `HomingRefRaw`, `Homed`, `HomingSuspect`).  
**Sorties** : `Ready/Busy/Done/Error/ErrorId`, `PresetRequest/PresetValue`, `Homed`, `HomingSuspect`.

---

## 3. Conditions d'exécution et vérifications

Pour qu'un ordre de homing soit accepté :
1. **Arrêt mécanique impératif** (`FwdRevSpeedFeedbackOff = TRUE` et `BrakeFeedback = TRUE`).
2. **Capteur haut actif** en homing nominal (`TopSensorSwitch = TRUE` ou `TopSensorBypass = TRUE`).
3. **Cible bornée** dans l'intervalle valide `[-99.0 ; +99.0]` mètres.
4. **Autorisation de mode** : Homing unitaire réservé au mode `MAINT_N2`.

En cas de décalage de la position brute au démarrage de l'automate (mouvement hors tension), le bloc positionne `HomingSuspect := TRUE` et masque `Homed := FALSE` jusqu'à confirmation par l'opérateur (`BtnConfirmCoherence`).

---

## 4. Alertes et écarts

- La cote `CfgTopSensorPos_M` enregistrée en persistant (8.0 m) prime sur les valeurs d'usine déclarées dans le code.

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)

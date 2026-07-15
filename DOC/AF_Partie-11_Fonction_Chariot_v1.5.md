# 📋 Analyse Fonctionnelle — Partie 11 : Fonction Chariot (v1.5)

> 🆕 **v1.5 (2026-07-15) — Intégration nominale EtherCAT & Sécurités** :
> * **Abandon du mode dégradé par relais (`DEGRADED_IO`)** : La vraie machine n'étant équipée d'aucun I/O digital physique pour la commande de sens/vitesse du variateur, le pilotage s'effectue exclusivement par le bus de terrain EtherCAT. Si une défaillance de com ou du variateur est détectée, la sécurité PLC déclenche l'arrêt et coupe le circuit d'urgence (AU/PowerCutOff) pour coller le frein par manque de courant.
> * **Spécifications AC600 EtherCAT intégrées** :
>   * Mot de commande (`DriveControlWord`, donné par Given Command 1 à l'adresse 0x3101/0x3001) : `0` = Aucun/Arrêt, `1` = Marche avant, `2` = Marche arrière, `7` = Reset défaut.
>   * Mot d'état (`DriveStatusWord`, donné par Drive Status 1 à l'adresse 0x3102/0x3002) : `Bit0` = Opération, `Bit4` = Défaut variateur (Faulty), `Bit7` = Prêt/Opérationnel (Operation Enable).
>   * Consignes et mesures de fréquence (`DriveFreqRefHz` et `DriveActualFreqHz`) : Mappées en centi-Hz ($\text{Hz} \times 100$) sur le bus EtherCAT.
> * **Surveillances de sécurité avancées (`FB_Safety_Chariot`)** :
>   * **Méca A (Mouvement non commandé à l'arrêt)** : Si la commande est à l'arrêt (`Direction = 0` et frein serré), mais qu'une fréquence réelle est détectée (`ABS(DriveActualFreqHz) > 0.5 Hz`) pendant plus de 1.0s, défaut (SafeStop + PowerCutOff).
>   * **Méca B (Incohérence à l'arrêt)** : Si commandé à l'arrêt mais que le retour frein indique qu'il reste desserré (`BrakeFeedback = TRUE`) ou que le variateur reste en opération (`DriveStatusWord.0 = TRUE`) pendant plus de 3.0s (PostRampTimeout), défaut (SafeStop + PowerCutOff).
>   * **Fins de course extrêmes (`LimitSwitchFwd`/`Rev`)** : Protection immédiate contre le dépassement physique. Coupure instantanée de la consigne et du mot de commande dans `FB_Chariot` dès l'atteinte de la butée extrême dans le sens de marche.
>   * **Diagnostic de la communication bus** : Surveillance de l'état du nœud EtherCAT (`DriveOnline` et `DriveOperational`).
> * ⚠️ **Avertissement majeur de sécurité (STO)** : L'entrée matérielle de coupure de couple (Safe Torque Off) du variateur AC600 n'est pas câblée sur la boucle d'AU. La coupure de puissance se fait par contacteurs amont, ce qui peut provoquer un glissement en roue libre temporaire pendant le temps de fermeture mécanique du frein.

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (axe X, chariot) en commande numérique du variateur AC600 (M3) via le réseau EtherCAT, dans le respect strict de la précédence `Enable` > `SafeStop` > `StartStop` (Partie3 §1bis).

Toutes les sécurités (Homme-mort, arrêt sur capteur cible, fins de course extrêmes et surveillances de cohérence à l'arrêt) sont actives pour protéger la mécanique contre les chocs et dérives de charge.

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdX ──► FB_Chariot(M3) ──► DriveControlWord + DriveFreqRefHz ──► AC600 (EtherCAT)
                                       ──► FB_Brake ──► BrakeCmd (bobine frein M3)

FB_Safety_Chariot ──► SafeStop     ──► (entrée) FB_Chariot(M3)
                  ──► PowerCutOff  ──► Coupure de puissance amont (Boucle d'AU générale)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_Chariot` | Gère la rampe interne (`FB_Ramp`), l'arbitrage `Enable > SafeStop > StartStop`, l'interlock de sens, l'arrêt sur capteur cible, les coupures immédiates sur fins de course extrêmes, et l'écriture des PDO EtherCAT. |
| `FB_Brake` | Séquence de freinage temporisée standard (Partie9 §FB_Brake), réutilisée avec les réglages propres au frein à manque de courant du chariot M3. |
| `FB_Safety_Chariot` | Centralise les sécurités du domaine : perte joystick, perte com EtherCAT, rotation de phase, thermique frein commun, et surveillances physiques Méca A (dérive vitesse) et Méca B (cohérence arrêt). |

---

## 🔌 3. Interface `FB_Chariot` (FB de mouvement, Partie3 §1bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) |
| `StartStop` / `SafeStop` | BOOL | Standard FB de mouvement (Partie3 §1bis) |
| `Direction` | INT | Consigne de sens -1 (arrière), 0 (neutre), +1 (avant) |
| `SpeedRefPct` | REAL | Magnitude de la consigne de vitesse (0..100 %) |
| `PositionSensorTarget` | BOOL | Capteur de position cible courante atteint (débounced) |
| `LimitSwitchFwd` | BOOL | Fin de course extrême avant (bloque la marche avant) |
| `LimitSwitchRev` | BOOL | Fin de course extrême arrière (bloque la marche arrière) |
| `DriveStatusWord` | WORD | Mot d'état variateur AC600 lu par EtherCAT |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée par le variateur (Hz) |
| `BrakeFeedback` | BOOL | Retour d'état câblé bobine frein (NC conditionné) |
| `BypassContactorCheck` | BOOL | Désactivation des diagnostics frein (simulation) |

**Réglages (RETAIN)**
| Paramètre | Type | Rôle |
|-----------|------|------|
| `RampAccelRate` | REAL | Taux d'accélération (%/s) |
| `RampDecelNormalRate` | REAL | Taux de décélération normale (%/s) |
| `RampDecelFastRate` | REAL | Taux de décélération rapide/d'urgence (%/s) |
| `DirectionInterlockDelay` | TIME | Délai d'interdiction d'inversion directe de sens |
| `ApproachTime` | TIME | Durée de translation normale avant le ralentissement auto |
| `ApproachSpeedPct` | REAL | Vitesse maximale d'approche lente de la cible (%) |
| `DriveFreqScaleMaxHz` | REAL | Échelle maximale du variateur (défaut 50.0 Hz) |
| `CaptorDebounce` | TIME | Tempo anti-rebond pour le capteur de position cible |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | Statuts standards du contrat FB (Partie3 §1) |
| `TargetReached` | BOOL | Capteur cible confirmé |
| `DriveControlWord` | WORD | Mot de commande donné au variateur AC600 (0x3101) |
| `DriveFreqRefHz` | REAL | Consigne de fréquence de sortie (Hz) |
| `BrakeCmd` | BOOL | Commande de la bobine de frein M3 (TRUE = desserré) |
| `BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic d'incohérence du contacteur de frein |

`ErrorId` (`FB_Chariot`) :
* `bit0` : Défaut frein (incohérence commande/retour)
* `bit3` : Défaut variateur (remonté par le bit4 du Status Word variateur)
* `bit6` : Fin de course extrême atteint

---

## 🔌 3bis. Interface `FB_Safety_Chariot`

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) |
| `JoystickOnline` / `JoystickOperational` | BOOL | Diagnostics du joystick CANopen |
| `PhaseRotationOk` | BOOL | Diagnostic de présence et ordre des phases électriques |
| `BrakeThermalFeedback` | BOOL | Retour thermique commun aux freins M1/M2/M3 |
| `DriveOnline` / `DriveOperational` | BOOL | Diagnostic de connexion et état du nœud EtherCAT variateur |
| `DriveStatusWord` | WORD | Mot d'état variateur AC600 (PDO EtherCAT) |
| `DriveActualFreqHz` | REAL | Vitesse mesurée du variateur (Hz) |
| `BrakeFeedback` | BOOL | Retour d'état bobine frein chariot |
| `BrakeCmd` | BOOL | Commande frein chariot |
| `Direction` | INT | Sens commandé |
| `LimitSwitchFwd` | BOOL | Fin de course extrême avant |
| `LimitSwitchRev` | BOOL | Fin de course extrême arrière |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/State/StateAtError` | — | Contrat standard |
| `ErrorId` | WORD | Bitfield détaillé :
* `bit0` : Perte com/défaut joystick CANopen
* `bit1` : Perte com EtherCAT variateur
* `bit2` : Mauvaise rotation de phases électriques
* `bit3` : Surchauffe thermique frein commun
* `bit4` : Méca B (Incohérence à l'arrêt : frein non serré ou variateur en marche)
* `bit5` : Méca A (Mouvement non commandé détecté à l'arrêt)
* `bit6` : Fin de course extrême physique franchi
| `SafeStop` | BOOL | Demande d'arrêt rapide par décélération PLC |
| `PowerCutOff` | BOOL | Coupure immédiate de la puissance amont (AU) |

---

## 🛡️ 4. Sécurités & Surveillances Détaillées

### 1. Précédence standard
L'arborescence des priorités `Enable > SafeStop > StartStop` s'applique de manière inconditionnelle. Tout défaut coupe immédiatement la consigne de vitesse et le mot de commande et applique le frein.

### 2. Interlock changement de sens
Toute inversion directe du sens de translation exige l'arrêt complet confirmé par le PLC (`ABS(SpeedRamp.Current) < 0.1 %`) et l'écoulement d'une temporisation de 200 ms (`DirectionInterlockDelay`).

### 3. Arrêt exact sur capteur cible
Dès que la cible est atteinte (`TargetReached = TRUE`), le mouvement dans la direction d'approche est verrouillé (`ArrivalLock := TRUE`). L'opérateur ne peut relancer le chariot que dans le sens opposé pour se dégager de la position.

### 4. Coupure sur fins de course extrêmes (`LimitSwitchFwd`/`Rev`)
Si le capteur de fin de course extrême est déclenché dans le sens de marche, le bloc `FB_Chariot` force instantanément le mot de commande à 0 et la consigne de fréquence à 0 Hz, sans suivre de rampe de décélération normale. En parallèle, `FB_Safety_Chariot` lève une anomalie (bit 6) provoquant l'activation de `PowerCutOff` pour couper l'alimentation générale et coller mécaniquement le frein.

### 5. Surveillance Méca A (Mouvement non commandé)
* **Condition** : Le chariot est commandé à l'arrêt (`Direction = 0` et `BrakeCmd = FALSE`).
* **Mesure** : La fréquence réelle lue sur le variateur dépasse le seuil : `ABS(DriveActualFreqHz) > 0.5 Hz`.
* **Action** : Si l'incohérence persiste pendant plus de 1.0 seconde (`TonMecaA`), le défaut de dérive est levé (`ErrorId` bit 5), déclenchant `SafeStop` et la coupure d'urgence `PowerCutOff`.

### 6. Surveillance Méca B (Incohérence à l'arrêt)
* **Condition** : Le chariot est commandé à l'arrêt.
* **Mesure** : Le variateur signale être toujours opérationnel (`DriveStatusWord.0 = TRUE`) ou le contacteur de frein est resté ouvert (`BrakeFeedback = TRUE`).
* **Action** : Si l'incohérence persiste pendant plus de 3.0 secondes (`PostRampTimeout`), le défaut d'incohérence est levé (`ErrorId` bit 4), déclenchant `SafeStop` et la coupure d'urgence `PowerCutOff`.

---

## 🗺️ 5. Mapping E/S (Image Process EtherCAT)

Les variables physiques suivantes doivent être configurées dans l'I/O Mapping CODESYS sous le maître EtherCAT :

| Variable (PLC) | Direction | Adresse PDO / Registre | Rôle |
|-----------------|-----------|------------------------|------|
| `M3_CommandWord` | Sortie | Given Command 1 (0x3101) | Commande numérique AC600 |
| `M3_SetpointFrequencyHz` | Sortie | frequency setpoint (0x3100) | Consigne vitesse ($\text{Hz} \times 100$) |
| `M3_StatusWord` | Entrée | Drive Status 1 (0x3102) | Mot d'état variateur AC600 |
| `M3_ActualFrequencyHz` | Entrée | Actual Frequency C00.01 (0x3103) | Vitesse réelle mesurée ($\text{Hz} \times 100$) |

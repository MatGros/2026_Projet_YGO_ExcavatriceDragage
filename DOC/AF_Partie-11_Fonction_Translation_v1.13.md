# 📋 Analyse Fonctionnelle — Partie 11 : Fonction Translation (v1.13)

> 🆕 **v1.13 (Lot 3A, implémenté — qualification CODESYS différée)** : gate final M3 après `FB_Brake` : les mots AC600 1/2 et toute fréquence sont nuls sans **les deux conditions** `BrakeReleaseRequest=TRUE` et `M3BrakeCommandOpenConfirmed=TRUE`. Watchdog fixe 500 ms ; après timeout, `RestartInhibit` impose disparition cause + front Reset + mot 0 neutre + nouvelle demande. Le code 7 reste exclusivement le reset variateur à fréquence nulle. La confirmation concerne le contacteur/bobine, jamais le frein mécanique. `SafeStop` reste la rampe rapide de `FB_Translation` avec `Enable` maintenu ; l'interlock final n'en fait pas une coupure sèche et attend la retombée effective de la demande.
>
> 🆕 **v1.12 (2026-07-23) — Restauration intégrale post-audit & consolidation** :
> Restauration complète des spécifications techniques de la v1.9 (mapping EtherCAT AC600, 
> registres de commande/statut, décodage des 5 capteurs, garde-fous Méca A/B, pipeline) 
> combinée aux éclaircissements de la v1.11 sur l'animation joystick HMI.
> 
> 🆕 **v1.9 (2026-07-19) — Suppression définitive d'IHM_MANU** : le dispositif dérogatoire
> IHM_MANU (mise en service urgence, v0.4.4) est retiré du code actif. Le pilotage manuel de
> M3 passe désormais exclusivement par MAINT_N1/MAINT_N2 + joystick homme-mort, sous
> `PRG_07_TranslationControl` §1bis (gatée par `Mode`, plus de flag `ManuActive` séparé).

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (axe X, translation) en commande numérique du variateur AC600 (M3) via le réseau EtherCAT, dans le respect strict de la précédence `Enable` > `SafeStop` > `StartStop` (Partie3 §1bis).

Toutes les sécurités (Homme-mort, arrêt sur capteur cible, fins de course extrêmes et surveillances de cohérence à l'arrêt) sont actives pour protéger la mécanique contre les chocs et dérives de charge — **y compris en MAINT_N1/MAINT_N2** (plus de bypass conditionnel, IHM_MANU supprimé v1.9).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdX ──► FB_Translation(M3) ──► RequestedDriveControlWord + RequestedDriveFreqHz
                                       ──► BrakeReleaseRequest (FB_Brake)
                                       ──► FB_TranslationOutputInterlock_LD
                                           ──► DriveControlWord + DriveFreqRefHz + BrakeCmd ──► AC600 / frein

FB_Safety_Translation ──► SafeStop     ──► FB_Translation + FB_TranslationOutputInterlock_LD
                  ──► PowerCutOff  ──► Coupure de puissance amont (Boucle d'AU générale)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_Translation` | Gère la rampe interne (`FB_Ramp`), l'arbitrage `Enable > SafeStop > StartStop`, l'interlock de sens, l'arrêt sur capteur cible et produit exclusivement les demandes métier `RequestedDriveControlWord`, `RequestedDriveFreqHz`, `BrakeReleaseRequest`. |
| `FB_TranslationOutputInterlock_LD` | Frontière finale M3 : applique le watchdog frein, interdit 1/2+fréquence tant que `BrakeReleaseRequest` **et** la confirmation contacteur/bobine ne sont pas vrais, mémorise le timeout et impose neutre + nouvelle demande après Reset. Produit seul les PDO/frein appliqués. |
| `FB_Brake` | Séquence de freinage temporisée standard (Partie9 §FB_Brake), réutilisée avec les réglages propres au frein à manque de courant du translation M3. |
| `FB_Safety_Translation` | Centralise les sécurités du domaine : perte joystick, perte com EtherCAT, rotation de phase, thermique frein commun, et surveillances physiques Méca A (dérive vitesse) et Méca B (cohérence arrêt). |

---

## 🔌 3. Interface `FB_Translation` (FB de mouvement, Partie3 §1bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) |
| `StartStop` / `SafeStop` | BOOL | Standard FB de mouvement (Partie3 §1bis) |
| `Direction` | INT | Consigne de sens -1 (arrière), 0 (neutre), +1 (avant) |
| `SpeedRefPct` | REAL | Magnitude de la consigne de vitesse (0..100 %) |
| `PositionSensorTarget` | BOOL | Capteur de position cible courante atteint (débounced) |
| `SlowdownSensor` | BOOL | Capteur PV : réduction à `ApproachSpeedPct` uniquement vers la Trémie |
| `LimitSwitchFwd` | BOOL | Fin de course extrême avant (bloque la marche avant) |
| `LimitSwitchRev` | BOOL | Fin de course extrême arrière (bloque la marche arrière) |
| `DriveStatusWord` | WORD | Mot d'état variateur AC600 lu par EtherCAT |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée par le variateur (Hz) |
| `BrakeFeedback` | BOOL | Retour d'état câblé bobine frein (NC conditionné) |
| `BypassContactorCheck` | BOOL | Désactivation des diagnostics frein (simulation) |

**Réglages (RETAIN)** — paramètres câblés depuis `GVL_PERSISTENT` par `PRG_07_TranslationControl`
| Paramètre | Type | Rôle |
|-----------|------|------|
| `RampAccelRate` | REAL | Taux d'accélération (%/s) — source `_TranslationRampAccelRate_Pct` |
| `RampDecelNormalRate` | REAL | Taux de décélération normale (%/s) — source `_TranslationRampDecelNormal_Pct` |
| `RampDecelFastRate` | REAL | Taux de décélération rapide/d'urgence (%/s) — source `_TranslationRampDecelFast_Pct` |
| `DirectionInterlockDelay` | TIME | Délai d'interdiction d'inversion directe de sens |
| `ApproachSpeedPct` | REAL | Vitesse maximale d'approche lente de la cible (%) |
| `DriveFreqScaleMaxHz` | REAL | Échelle maximale du variateur (val. usine **60.0 Hz**, source `GVL_PERSISTENT._TranslationMaxFreq_Hz`) |
| `CaptorDebounce` | TIME | Tempo anti-rebond pour le capteur de position cible |

**PERSISTENT `GVL_PERSISTENT` (Translation M3)**
| Variable | Type | Défaut | Rôle |
|----------|------|--------|------|
| `_TranslationMaxFreq_Hz` | `REAL` | 60.0 | Fréquence max absolue M3 (Hz) — source unique pour `DriveFreqScaleMaxHz` |
| `_TranslationRampAccelRate_Pct` | `REAL` | 20.0 | Accélération translation (%/s) |
| `_TranslationRampDecelNormal_Pct` | `REAL` | 40.0 | Décélération normale (%/s) |
| `_TranslationRampDecelFast_Pct` | `REAL` | 100.0 | Décélération rapide SafeStop (%/s) |
| `_TranslationAutoSpeedCap_Pct` | `REAL` | 40.0 | Plafond vitesse en mode SEMI_AUTO (% de la consigne) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | Statuts standards du contrat FB (Partie3 §1) |
| `TargetReached` | BOOL | Capteur cible confirmé |
| `RequestedDriveControlWord` | WORD | Demande métier AC600 (0=None, 1=Fwd, 2=Rev, 7=Reset), avant interlock final |
| `RequestedDriveFreqHz` | REAL | Demande métier fréquence (Hz), avant interlock final |
| `BrakeReleaseRequest` | BOOL | Demande métier de desserrage issue de `FB_Brake` |
| `BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic d'incohérence du contacteur de frein |
| `BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic d'incohérence du contacteur de frein |

`ErrorId` (`FB_Translation`) :
* `bit0` : Défaut frein (incohérence commande/retour)
* `bit3` : Défaut variateur (remonté par le bit4 du Status Word variateur)
* `bit6` : Fin de course extrême atteint
* `bit7` : Mot des cinq capteurs de position incohérent

### 🧩 3bis. Décodage des capteurs de position M3

`FB_Translation_PositionDecoder` reçoit les cinq entrées dans l'ordre
`Trémie | PV | P2 | P1 | Maintenance` et accepte uniquement les mots monotones suivants :

| Mot | Zone | Effet |
|---|---|---|
| `11111` | Extrême gauche / Trémie | Limite `Fwd` |
| `01111` | Entre Trémie et PV | Approche rapide |
| `00111` | P2 | Position de travail |
| `00011` | P1 | Position de travail |
| `00001` | Entre P1 et Maintenance | Approche Maintenance |
| `00000` | Extrême droite / Maintenance | Limite `Rev`, accès `MAINT_N2` uniquement |

Toute autre combinaison déclenche `Incoherent`, transmis à `FB_Safety_Translation` via `SensorWordIncoherent`. Ce défaut provoque `SafeStop` et `PowerCutOff`.

---

## 🔌 3ter. Interface `FB_Safety_Translation`

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) — `Enable` inconditionnel (`PRG_03_Safety.st`) |
| `JoystickOnline` / `JoystickOperational` | BOOL | Diagnostics du joystick CANopen |
| `PhaseRotationOk` | BOOL | Diagnostic de présence et ordre des phases électriques |
| `BrakeThermalFeedback` | BOOL | Retour thermique commun aux freins M1/M2/M3 |
| `DriveOnline` / `DriveOperational` | BOOL | Diagnostic esclave EtherCAT variateur |
| `DriveStatusWord` | WORD | Mot d'état variateur AC600 (PDO EtherCAT) |
| `DriveActualFreqHz` | REAL | Vitesse mesurée du variateur (Hz) |
| `BrakeFeedback` | BOOL | Retour d'état bobine frein translation |
| `BrakeCmd` | BOOL | Commande frein translation |
| `Direction` | INT | Sens commandé |
| `LimitSwitchFwd` / `LimitSwitchRev` | BOOL | Fins de course extrêmes |
| `SensorWordIncoherent` | BOOL | Incohérence du mot cinq capteurs |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `ErrorId` | WORD | Bitfield détaillé :
* `bit0` : Perte com/défaut joystick CANopen
* `bit1` : Perte com EtherCAT variateur
* `bit2` : Mauvaise rotation de phases électriques
* `bit3` : Surchauffe thermique frein commun
* `bit4` : Méca B (Incohérence à l'arrêt : frein non serré ou variateur en marche)
* `bit5` : Méca A (Mouvement non commandé détecté à l'arrêt)
* `bit6` : Fin de course extrême physique franchi
* `bit7` : Mot capteurs incohérent — `SafeStop` + `PowerCutOff`
| `SafeStop` | BOOL | Demande d'arrêt rapide par décélération PLC |
| `PowerCutOff` | BOOL | Coupure immédiate de la puissance amont (AU) |

---

## 🛡️ 4. Sécurités & Surveillances Détaillées

### 1. Surveillance Méca A (Mouvement non commandé)
* **Condition** : Translation commandée à l'arrêt (`Direction = 0` et `BrakeCmd = FALSE`).
* **Mesure** : Fréquence réelle variateur : `ABS(DriveActualFreqHz) > 0.5 Hz`.
* **Action** : Si l'incohérence persiste `$t > 1.0\,\text{s}$`, défaut levé (bit 5) $\Rightarrow$ `SafeStop` + `PowerCutOff`.

### 2. Surveillance Méca B (Incohérence à l'arrêt)
* **Condition** : Translation commandée à l'arrêt.
* **Mesure** : Variateur toujours opérationnel (`DriveStatusWord.0 = TRUE`) ou retour frein ouvert (`BrakeFeedback = TRUE`).
* **Action** : Si l'incohérence persiste `$t > 3.0\,\text{s}$` (PostRampTimeout), défaut levé (bit 4) $\Rightarrow$ `SafeStop` + `PowerCutOff`.

---

## 🗺️ 5. Mapping E/S (Image Process EtherCAT)

| Variable (PLC) | Direction | Adresse PDO / Registre | Rôle |
|-----------------|-----------|------------------------|------|
| `M3_CommandWord` | Sortie | Given Command 1 (0x3101) | Commande numérique AC600 |
| `M3_SetpointFrequencyHz` | Sortie | frequency setpoint (0x3100) | Consigne vitesse ($\text{Hz} \times 100$) |
| `M3_StatusWord` | Entrée | Drive Status 1 (0x3102) | Mot d'état variateur AC600 |
| `M3_ActualFrequencyHz` | Entrée | Actual Frequency C00.01 (0x3103) | Vitesse réelle mesurée ($\text{Hz} \times 100$) |

---

## 🖥️ 6. Interface IHM (`ST_TranslationHMI`, `GVL_IHM.TranslationM3`)

| Champ | Type | Sens | Rôle |
|-------|------|------|------|
| `SelTarget` | INT | IHM→PLC | Cible : `1=Trémie`, `2=P2`, `3=P1`, `4=Maintenance` |
| `BtnFwd` / `BtnRev` | BOOL | IHM→PLC | Commande manuelle marche avant/arrière |
| `SetFreq_Hz` | REAL | IHM→PLC | Consigne fréquence manuelle (Hz), limitée à `_TranslationMaxFreq_Hz` |
| `DriveActualFreqHz` | REAL | PLC→IHM | Fréquence réelle mesurée (Hz) |
| `DriveCommReady` | BOOL | PLC→IHM | StatusWord bit7 (communication prête) |
| `DrivePowerReady` | BOOL | PLC→IHM | StatusWord bit0 (puissance prête) |
| `JoystickDeflectionPct` | REAL | PLC→IHM | Déflexion fonctionnelle signée axe X (`-100..+100 %`) pour animation IHM |
| `BypassContactorFeedback` | BOOL | PLC→IHM | Diag banc de test (`GVL_Simulation.ContactorFeedbackM3_IsReal`) |

---

## 🛡️ Lot 3A — Gate final AC600

`FB_Translation` reste propriétaire des rampes, de la demande métier AC600 et de `FB_Brake`. `FB_TranslationOutputInterlock_LD` est la frontière finale distincte : `FB_Translation → FB_TranslationOutputInterlock_LD → PRG_10_Outputs_LD → AC600/frein`.

`M3BrakeCommandOpenConfirmed`, produit et filtré dans `PRG_00_Inputs`, ne confirme que le contacteur/bobine de desserrage. Tant qu'il est faux, `DriveControlWord` 1/2 et `DriveFreqRefHz` sont forcés à zéro ; le mot 7 (reset AC600) est préservé avec fréquence explicitement nulle.

Le watchdog interne non configurable de `T#500ms` démarre sur `BrakeReleaseRequest` effectif ; timeout = frein serré, arrêt mouvement, défaut mémorisé et `RestartInhibit`. Après disparition de cause + front Reset, le mot 0 doit être observé, puis une nouvelle demande 1/2 est exigée : aucun redémarrage automatique. `Enable=FALSE`, `EmergencyStopOk=FALSE` et `SafeStop=TRUE` forcent aussi mot 0, fréquence 0 et frein serré. Le code 7 AC600 reste autorisé durant l'inhibition, toujours avec fréquence nulle. `BrakeFeedbackTimeout` nominal est `T#300ms`, strictement sous ce dernier recours.

Le suffixe `_LD` rend cette frontière finale lisible pour la maintenance. Le générateur PLCopenXML convertit uniquement les `PRG_*_LD` en Ladder ; les `FB_*_LD` restent exportés en ST.

📄 Sources uniques : `CODE/TRANSLATION/FB_Translation.st` et `CODE/TRANSLATION/FB_TranslationOutputInterlock_LD.st`.

### Lot 3A — implantation frontière finale

`PRG_07_TranslationControl` publie uniquement `TranslationFinalInterlockRequest` après
`FB_Translation`. L'unique instance `FB_TranslationOutputInterlock_LD` réside dans
`PRG_10_Outputs_LD`, juste avant le frein M3 et les PDO AC600. `PRG_07` doit précéder `PRG_10`
dans MainTask. Le `R_TRIG` de reset de l'interlock est échantillonné avant ses gates Enable/AU : un
reset maintenu pendant une inhibition ne peut pas devenir un acquittement au retour.

# 📋 Analyse Fonctionnelle — Partie 11 : Fonction Translation (v1.9)

> 🆕 **v1.9 (2026-07-19) — Suppression définitive d'IHM_MANU** : le dispositif dérogatoire
> IHM_MANU (mise en service urgence, v0.4.4) est retiré du code actif. Le pilotage manuel de
> M3 passe désormais exclusivement par MAINT_N1/MAINT_N2 + joystick homme-mort, sous
> `PRG_07_TranslationControl` §1bis (gatée par `Mode`, plus de flag `ManuActive` séparé). Les
> mentions "mode IHM_MANU" et "`ManuActive`" ci-dessous (bandeau v1.7) sont historiques —
> voir `DOC/IHM_MANU_Journal_Modifications.md` pour la trace complète de la migration.

> 🆕 **v1.8 (2026-07-18) — Mise en conformité M3 avec le codage cinq capteurs** : ajout du
> décodage `Trémie|PV|P2|P1|Maintenance`, remplacement du ralentissement temporisé par le
> capteur PV, ajout du diagnostic d’incohérence bit7 et alignement de la simulation sur les
> six mots valides.

> 🆕 **v1.7 (2026-07-16) — IHM_MANU aligné sur le modèle M1/M2 (fin du bypass `M3_CommandWord`)** :
> * `PRG_07_TranslationControl.st` : nouvelle branche `ELSIF PRG_10_Outputs.ManuActive THEN` (§1bis),
>   mirroir de `PRG_06_WinchControl` — M3 est désormais piloté par la **même instance**
>   `instTranslationM3` (`FB_Translation`) qu'en Auto/SEMI_AUTO, qu'on soit en Manu ou pas.
>   `Direction`/`StartStop` dérivés de `PRG_10_Outputs.M3Fwd_Demand`/`M3Rev_Demand` (boutons HMI ou
>   joystick, déjà arbitrés en amont).
> * `instSafetyTranslationM3.Enable` (`PRG_03_Safety.st`) passe à `TRUE` **inconditionnel** —
>   l'ex-"Conditional Bypass Doctrine" (`NOT ManuActive OR ...`) est retirée. `FB_Safety_Translation`
>   est désormais **toujours active**, y compris en Manu (Méca A/B, thermique, rotation phase,
>   perte com EtherCAT/joystick). Ceci débloque `FB_TranslationValidation` (TC-T1/T2/T3, voir
>   `AF_Partie-14`), dont l'exécution était impossible tant que `Enable=FALSE` masquait tout défaut.
> * **Vitesse en Manu — diffère volontairement du Winch** : `GVL_IHM.M3Translation.FreqSetpointHz`
>   (consigne Hz réglable opérateur, limitée par `PRG_10_Outputs` à `_TranslationMaxFreq_Hz`) reste
>   la référence pleine échelle pour boutons HMI **et** joystick — reproduit le comportement exact
>   de l'ex-bypass. Le Winch utilise `100.0` fixe en boutons HMI (paliers discrets de contacteurs,
>   pas de notion de fréquence réglable) ; Translation pilote une fréquence continue, donc conserve
>   ce réglage fin plutôt que de le perdre en mirorant le Winch à l'identique.
> * `PRG_10_Outputs.st` : écriture directe `M3_CommandWord`/`M3_SetpointFrequencyHz` supprimée
>   (`M3Fwd_Eff`/`M3Rev_Eff`/`M3_ActiveFreqCmd`/`M3_DriveIsReal` orphelins, retirés) — ces sorties
>   viennent désormais uniquement de `instTranslationM3.DriveControlWord`/`DriveFreqRefHz`, pour
>   Auto ET Manu (même modèle que M1/M2). `TranslationBrakeCmd` n'est plus écrasé en Manu, déjà
>   écrit par `PRG_07_TranslationControl` (position 7 < 10 dans l'ordre de tâche).
> * Détail complet : `DOC/IHM_MANU_Journal_Modifications.md` §12.
>
> 🆕 **v1.6 (2026-07-15) — Finalisation IHM (`ST_TranslationHMI`)** :
> * `ST_TranslationHMI` (`GVL_IHM.M3Translation`) reprend les commandes manuelles ex-`ST_IHM_MANU`
>   (`ReqFwd`/`ReqRev`/`FreqSetpointHz`, sans préfixe `M3_` — redondant une fois scopé sous
>   `GVL_IHM.M3Translation.xxx`).
> * Diagnostic variateur **décodé** : `DriveCommReady`/`DrivePowerReady` (booléens, StatusWord
>   bit7/bit0) remplacent le `WORD` brut `DriveStatusWord` — binding visu direct (LED/checkbox),
>   pas de bit-masking côté développeur IHM. Le défaut variateur (bit4) reste couvert par
>   `Translation.Error`/`ErrorId` (bit3 `FB_Translation`), pas de 3ᵉ booléen dédié.
> * `BypassBrakeFeedback` **supprimé** (n'était jamais écrit, redondant avec
>   `BypassContactorFeedback` qui couvre déjà "sens + frein" — voir `GVL_Simulation.ContactorFeedbackM3_IsReal`).
>   `PRG_07_TranslationControl` utilise désormais `BypassContactorFeedback` pour le `SEL` de
>   `BrakeFeedback` transmis à `FB_Translation`.
> * `DriveActualFreqHz` : source unique `PRG_00_Inputs.M3_ActualFrequencyHz_Filtered`, écrite
>   une seule fois (`PRG_09_Supervision`), valable Auto ET Manu.
> * `GVL_IHM.Translation` renommé `GVL_IHM.M3Translation` (cohérence avec `WinchM1`/`WinchM2` — le nom
>   du membre porte son identifiant matériel). Idem `Joystick`→`JOY1Joystick`. `Benne` reste
>   sans suffixe (contrairement à Translation/Joystick, pas de paire M1/M2 à distinguer — un suffixe
>   `M2` répéterait `M2` déjà présent dans ses propres champs, ex. `M2PositionCorrected`).
> * **Bug corrigé** (hors périmètre IHM strict, découvert au passage) : la simulation de trajet
>   M3 (`FB_Sim_Translation`) lisait `RelayFwd`/`RelayRev` depuis `GVL_Translation_M3_Stub.M3_RelayFwd/Rev`
>   — variables jamais écrites depuis l'abandon du mode relais `DEGRADED_IO` (v0.4.11) : la
>   progression de trajet restait bloquée en permanence. Rebranché sur `M3_CommandWord = 1/2`.
>
> **v1.5 (2026-07-15) — Intégration nominale EtherCAT & Sécurités** :
> * **Abandon du mode dégradé par relais (`DEGRADED_IO`)** : La vraie machine n'étant équipée d'aucun I/O digital physique pour la commande de sens/vitesse du variateur, le pilotage s'effectue exclusivement par le bus de terrain EtherCAT. Si une défaillance de com ou du variateur est détectée, la sécurité PLC déclenche l'arrêt et coupe le circuit d'urgence (AU/PowerCutOff) pour coller le frein par manque de courant.
> * **Spécifications AC600 EtherCAT intégrées** :
>   * Mot de commande (`DriveControlWord`, donné par Given Command 1 à l'adresse 0x3101/0x3001) : `0` = Aucun/Arrêt, `1` = Marche avant, `2` = Marche arrière, `7` = Reset défaut.
>   * Mot d'état (`DriveStatusWord`, donné par Drive Status 1 à l'adresse 0x3102/0x3002) : `Bit0` = Opération, `Bit4` = Défaut variateur (Faulty), `Bit7` = Prêt/Opérationnel (Operation Enable).
>   * Consignes et mesures de fréquence (`DriveFreqRefHz` et `DriveActualFreqHz`) : Mappées en centi-Hz ($\text{Hz} \times 100$) sur le bus EtherCAT.
> * **Surveillances de sécurité avancées (`FB_Safety_Translation`)** :
>   * **Méca A (Mouvement non commandé à l'arrêt)** : Si la commande est à l'arrêt (`Direction = 0` et frein serré), mais qu'une fréquence réelle est détectée (`ABS(DriveActualFreqHz) > 0.5 Hz`) pendant plus de 1.0s, défaut (SafeStop + PowerCutOff).
>   * **Méca B (Incohérence à l'arrêt)** : Si commandé à l'arrêt mais que le retour frein indique qu'il reste desserré (`BrakeFeedback = TRUE`) ou que le variateur reste en opération (`DriveStatusWord.0 = TRUE`) pendant plus de 3.0s (PostRampTimeout), défaut (SafeStop + PowerCutOff).
>   * **Fins de course extrêmes (`LimitSwitchFwd`/`Rev`)** : Protection immédiate contre le dépassement physique. Coupure instantanée de la consigne et du mot de commande dans `FB_Translation` dès l'atteinte de la butée extrême dans le sens de marche.
>   * **Diagnostic de la communication bus** : Surveillance de l'état du nœud EtherCAT (`DriveOnline` et `DriveOperational`).
> * ⚠️ **Avertissement majeur de sécurité (STO)** : L'entrée matérielle de coupure de couple (Safe Torque Off) du variateur AC600 n'est pas câblée sur la boucle d'AU. La coupure de puissance se fait par contacteurs amont, ce qui peut provoquer un glissement en roue libre temporaire pendant le temps de fermeture mécanique du frein.

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (axe X, translation) en commande numérique du variateur AC600 (M3) via le réseau EtherCAT, dans le respect strict de la précédence `Enable` > `SafeStop` > `StartStop` (Partie3 §1bis).

Toutes les sécurités (Homme-mort, arrêt sur capteur cible, fins de course extrêmes et surveillances de cohérence à l'arrêt) sont actives pour protéger la mécanique contre les chocs et dérives de charge — **y compris en MAINT_N1/MAINT_N2** (plus de bypass conditionnel, IHM_MANU supprimé v1.9).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdX ──► FB_Translation(M3) ──► DriveControlWord + DriveFreqRefHz ──► AC600 (EtherCAT)
                                       ──► FB_Brake ──► BrakeCmd (bobine frein M3)

FB_Safety_Translation ──► SafeStop     ──► (entrée) FB_Translation(M3)
                  ──► PowerCutOff  ──► Coupure de puissance amont (Boucle d'AU générale)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_Translation` | Gère la rampe interne (`FB_Ramp`), l'arbitrage `Enable > SafeStop > StartStop`, l'interlock de sens, l'arrêt sur capteur cible, les coupures immédiates sur fins de course extrêmes, et l'écriture des PDO EtherCAT. |
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

**Réglages (RETAIN)** — paramètres câblés depuis `GVL_PERSISTENT` par `PRG_07_TranslationControl` (🔧 v1.9 REX 2026-07-22 : auparavant hardcodés dans FB_Translation, désormais paramétrables par personnel qualifié sans recompilation)
| Paramètre | Type | Rôle |
|-----------|------|------|
| `RampAccelRate` | REAL | Taux d'accélération (%/s) — source `_TranslationRampAccelRate_Pct` |
| `RampDecelNormalRate` | REAL | Taux de décélération normale (%/s) — source `_TranslationRampDecelNormal_Pct` |
| `RampDecelFastRate` | REAL | Taux de décélération rapide/d'urgence (%/s) — source `_TranslationRampDecelFast_Pct` |
| `DirectionInterlockDelay` | TIME | Délai d'interdiction d'inversion directe de sens |
| `ApproachSpeedPct` | REAL | Vitesse maximale d'approche lente de la cible (%) |
| `DriveFreqScaleMaxHz` | REAL | Échelle maximale du variateur (val. usine **60.0 Hz** 🔧 REX 2026-07-21 — évolué de 50.0 Hz suite demande terrain. **Source unique** = `GVL_PERSISTENT._TranslationMaxFreq_Hz`. Plus de valeur par défaut interne) |
| `CaptorDebounce` | TIME | Tempo anti-rebond pour le capteur de position cible |

**PERSISTENT `GVL_PERSISTENT` (Translation M3)** — 🔧 REX 2026-07-22 : nouveau bloc, unifie la source des paramètres machine (rampes, plafond auto, fréquence max)
| Variable | Type | Défaut | Rôle |
|----------|------|--------|------|
| `_TranslationMaxFreq_Hz` | `REAL` | 60.0 | Fréquence max absolue M3 (Hz) — source unique pour `DriveFreqScaleMaxHz` de `FB_Translation` |
| `_TranslationRampAccelRate_Pct` | `REAL` | 20.0 | Accélération translation (%/s) |
| `_TranslationRampDecelNormal_Pct` | `REAL` | 40.0 | Décélération normale (%/s) |
| `_TranslationRampDecelFast_Pct` | `REAL` | 100.0 | Décélération rapide SafeStop (%/s) |
| `_TranslationAutoSpeedCap_Pct` | `REAL` | 40.0 | Plafond vitesse en mode SEMI_AUTO (% de la consigne, auparavant hardcodé 40.0 dans `PRG_07`) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | Statuts standards du contrat FB (Partie3 §1) |
| `TargetReached` | BOOL | Capteur cible confirmé |
| `DriveControlWord` | WORD | Mot de commande donné au variateur AC600 (0x3101) |
| `DriveFreqRefHz` | REAL | Consigne de fréquence de sortie (Hz) |
| `BrakeCmd` | BOOL | Commande de la bobine de frein M3 (TRUE = desserré) |
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

Toute autre combinaison déclenche `Incoherent`, transmis à `FB_Safety_Translation` via
`SensorWordIncoherent`. Ce défaut provoque `SafeStop` et `PowerCutOff`.

Le capteur `PV` est uniquement un point de ralentissement avant la Trémie. Il ne constitue
jamais une cible d'arrêt.

---

## 🔌 3bis. Interface `FB_Safety_Translation`

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) — `Enable` inconditionnel depuis v1.7 (`PRG_03_Safety.st`), Auto ET Manu |
| `JoystickOnline` / `JoystickOperational` | BOOL | Diagnostics du joystick CANopen |
| `PhaseRotationOk` | BOOL | Diagnostic de présence et ordre des phases électriques |
| `BrakeThermalFeedback` | BOOL | Retour thermique commun aux freins M1/M2/M3 |
| `DriveOnline` / `DriveOperational` | BOOL | Diagnostic de connexion et état du nœud EtherCAT variateur |
| `DriveStatusWord` | WORD | Mot d'état variateur AC600 (PDO EtherCAT) |
| `DriveActualFreqHz` | REAL | Vitesse mesurée du variateur (Hz) |
| `BrakeFeedback` | BOOL | Retour d'état bobine frein translation |
| `BrakeCmd` | BOOL | Commande frein translation |
| `Direction` | INT | Sens commandé |
| `LimitSwitchFwd` | BOOL | Fin de course extrême avant |
| `LimitSwitchRev` | BOOL | Fin de course extrême arrière |
| `SensorWordIncoherent` | BOOL | Incohérence du mot cinq capteurs |

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
* `bit7` : Mot capteurs incohérent — `SafeStop` + `PowerCutOff`
| `SafeStop` | BOOL | Demande d'arrêt rapide par décélération PLC |
| `PowerCutOff` | BOOL | Coupure immédiate de la puissance amont (AU) |

---

## 🛡️ 4. Sécurités & Surveillances Détaillées

### 1. Précédence standard
L'arborescence des priorités `Enable > SafeStop > StartStop` s'applique de manière inconditionnelle. Tout défaut coupe immédiatement la consigne de vitesse et le mot de commande et applique le frein.

### 2. Interlock changement de sens
Toute inversion directe du sens de translation exige l'arrêt complet confirmé par le PLC (`ABS(SpeedRamp.Current) < 0.1 %`) et l'écoulement d'une temporisation de 200 ms (`DirectionInterlockDelay`).

### 3. Arrêt exact sur capteur cible
Dès que la cible est atteinte (`TargetReached = TRUE`), le mouvement dans la direction d'approche est verrouillé (`ArrivalLock := TRUE`). L'opérateur ne peut relancer le translation que dans le sens opposé pour se dégager de la position.

### 4. Coupure sur fins de course extrêmes (`LimitSwitchFwd`/`Rev`)
Si le capteur de fin de course extrême est déclenché dans le sens de marche, le bloc `FB_Translation` force instantanément le mot de commande à 0 et la consigne de fréquence à 0 Hz, sans suivre de rampe de décélération normale. En parallèle, `FB_Safety_Translation` lève une anomalie (bit 6) provoquant l'activation de `PowerCutOff` pour couper l'alimentation générale et coller mécaniquement le frein.

### 5. Surveillance Méca A (Mouvement non commandé)
* **Condition** : Le translation est commandé à l'arrêt (`Direction = 0` et `BrakeCmd = FALSE`).
* **Mesure** : La fréquence réelle lue sur le variateur dépasse le seuil : `ABS(DriveActualFreqHz) > 0.5 Hz`.
* **Action** : Si l'incohérence persiste pendant plus de 1.0 seconde (`TonMecaA`), le défaut de dérive est levé (`ErrorId` bit 5), déclenchant `SafeStop` et la coupure d'urgence `PowerCutOff`.

### 6. Surveillance Méca B (Incohérence à l'arrêt)
* **Condition** : Le translation est commandé à l'arrêt.
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

---

## 🖥️ 6. Interface IHM (`ST_TranslationHMI`, `GVL_IHM.TranslationM3`)

Structure d'échange IHM (migration depuis l'ex-`ST_IHM_MANU`, **terminée et définitive**, v1.9 —
IHM_MANU supprimé). En MAINT_N1/MAINT_N2, `BtnFwd`/`BtnRev`/`SetFreq_Hz` alimentent
l'arbitrage `PRG_07_TranslationControl` §1bis (gatée par `Mode`), qui pilote la même instance
`FB_Translation` qu'en Auto (historique de la migration : `DOC/IHM_MANU_Journal_Modifications.md` §12).

| Champ | Type | Sens | Rôle |
|-------|------|------|------|
| `SelTarget` | INT | IHM→PLC | Cible : `1=Trémie`, `2=P2`, `3=P1`, `4=Maintenance` ; PV n'est pas une cible |
| `BtnFwd` / `BtnRev` | BOOL | IHM→PLC | Commande manuelle marche avant/arrière (EtherCAT, pas un relais physique) — n'entraîne un mouvement que si `DeadmanArmed` (homme-mort joystick) est actif, voir §6bis |
| `SetFreq_Hz` | REAL | IHM→PLC | Consigne fréquence manuelle (Hz), limitée à `_TranslationMaxFreq_Hz` — référence de vitesse pleine échelle en Manu (boutons ET joystick, voir bandeau v1.7) |
| `FBState` | E_State | PLC→IHM | État interne `FB_Translation` (diagnostic) |
| `Ready/Busy/Done/Error/ErrorId` | — | PLC→IHM | Statuts standards `FB_Translation` |
| `BrakeCmd` | BOOL | PLC→IHM | Miroir lecture seule (TRUE = desserré) — pas de forçage inconditionnel : le déblocage en MAINT passe par `BtnFwd`/`BtnRev` (mouvement), qui desserre le frein nativement via `FB_Brake` (même doctrine que `ST_WinchHMI`) |
| `BrakeFeedback` | BOOL | PLC→IHM | Retour physique bobine frein |
| `PositionSensorTarget` | BOOL | PLC→IHM | Capteur position cible atteint |
| `DriveActualFreqHz` | REAL | PLC→IHM | Fréquence réelle mesurée (Hz), source unique `PRG_00_Inputs`, Auto ET Manu |
| `DriveCommReady` | BOOL | PLC→IHM | StatusWord bit7 (communication prête) — décodé, pas de bit-masking IHM |
| `DrivePowerReady` | BOOL | PLC→IHM | StatusWord bit0 (puissance prête) — décodé |
| `BypassContactorFeedback` | BOOL | PLC→IHM | Diag banc de test, auto-calculé (`GVL_Simulation.ContactorFeedbackM3_IsReal`) — couvre sens + frein |
| `SafetyError` / `SafetyErrorId` | — | PLC→IHM | Statuts `FB_Safety_Translation` |
| `SafetyErrorSensorIncoherent` | BOOL | PLC→IHM | Incohérence du mot capteurs M3 (bit7) |

### Interface complète de supervision et de test

`GVL_IHM.TranslationM3` constitue l'interface unique de supervision de l'objet métier
Translation M3. Elle expose également le mot de progression des cinq capteurs :
`bit4=Trémie`, `bit3=PV`, `bit2=P2`, `bit1=P1`, `bit0=Maintenance`.

Les champs `PositionTremie`, `PositionPV`, `PositionP2`, `PositionP1`,
`PositionMaintenance`, `SensorsWord`, `SensorWordIncoherent`, `LimitSwitchFwd` et
`LimitSwitchRev` permettent de diagnostiquer directement le câblage et la position estimée.
`SafetySafeStop` et `SafetyPowerCutOff` indiquent la réaction de sécurité effective.

En maintenance N1/N2, les commandes `BtnFwd`/`BtnRev` et `SetFreq_Hz` sont traitées
par `PRG_07_TranslationControl` sans dépendre de `IHM_MANU`. En mode `SEMI_AUTO`, la
commande vient du cycle et reste conditionnée par l'homme-mort et le joystick X.

### 6bis. Homme-mort obligatoire, y compris en pilotage boutons IHM

🆕 **v1.9 (2026-07-19, revue sécurité post-suppression IHM_MANU)** : `M3_StartStop_Active`
exige désormais `PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed` **quel que soit** le mode de
pilotage sélectionné (`TglJoystickMaster` TRUE ou FALSE). Auparavant, piloter M3 via les boutons
`BtnFwd`/`BtnRev` (`TglJoystickMaster=FALSE`) ne testait aucune condition homme-mort — écart
relevé lors de la revue de sécurité de la mission de suppression d'IHM_MANU (le bug préexistait
à IHM_MANU, hérité de l'ex-bypass direct). Sens/vitesse restent pilotables via les boutons IHM ;
seule la validation du mouvement (`StartStop`) exige en plus que l'opérateur maintienne le
homme-mort du joystick, conformément au principe transverse « tout mouvement validé au joystick
homme-mort » (voir `CLAUDE.md`).

Les champs `Test*` de `GVL_IHM.TranslationM3` ne sont utilisables que sur le banc de
simulation. Ils recopient les overrides Translation prévus dans `GVL_PLC_Tests` et ne
créent aucune commande physique supplémentaire.

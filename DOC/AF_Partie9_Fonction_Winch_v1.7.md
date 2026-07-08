# 📋 Analyse Fonctionnelle — Partie 9 : Fonction Winch (v1.7)

> 📌 **État d'implémentation (2026-07-08, AUDIT)** : `FB_WinchSync` **codé et audité**
> — `CODE/FB_WinchSync.st`, 1 instance. Calcule `DeltaPosM`/`SyncWarn` (IHM uniquement, PAS de
> `SafeStop` pour l'écart de position), `SyncActive` selon Mode (imposé N1, activable/désactivable N2 via `OverrideSync`
> de `FB_Modes`).
> **Contrôle de cohérence de commande intégré** : `ErrorId` bit 1 (16#0002) entraîne un `SafeStop` des deux treuils.
> **Pas de correction/régulation active** de l'écart — `FB_Winch` n'a aucune entrée de
> correction de vitesse aujourd'hui, hors périmètre de ce lot (§9 "reste à faire"). Sélecteur
> treuil IHM (M1/M2/Les deux) et bit « Prise de main IHM » : toujours **non codés**.
>
> **Fonction métier** : chaîne de commande Joystick (axe Y, Plongée/Extraction) → `FB_Winch` →
> relais de sens et de vitesse, avec séquence frein. Premier lot testable en **Maintenance N1**,
> treuil **M1 seul**, **sans dépendance codeur**.
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔗 Dépend de : [P2 Architecture v2.10](AF_Partie2_Architecture_Programme_v2.10.md), [P3 Contrat FB v1.3](AF_Partie3_Template_FB_Commun_v1.3.md), [P4 Cycle v1.2](AF_Partie4_Cycle_Sequenceur_v1.2.md) §3bis/§4, [P5 Modes v1.2](AF_Partie5_Modes_Maintenance_v1.2.md), [P8 Joystick v1.2](AF_Partie8_Fonction_Joystick_v1.2.md).
>
> 🆕 **v1.7 (2026-07-08)** — Lot #9-17 : Inhibition treuils, HomingApproachEnable, Méca B étendu, Méca D et refactoring Méca A/C :
> - **Inhibition treuils** (`InhibitM1`/`InhibitM2` en mode `MAINT_N2`) : Coupe l'`Enable` de `FB_Winch` et `FB_Safety_Winch`, et désactive automatiquement la synchronisation (`FB_WinchSync`).
> - **HomingApproachEnable** (ex-`OverrideTopStop`) : Bit d'autorisation explicite de dépassement de l'arrêt normal haut (à `HomingTargetMx_M - WinchTopStopMarginM`).
> - **Méca D (bit 11)** : Modèle à 3 couches en fonctionnement normal (hors référencement) pour l'arrêt haut : (1) arrêt normal à 12.0m (consigne coupée) -> (2) coupure immédiate `ForbidAscent` si le capteur physique `TopPositionSensor` est atteint (bit 5, 12.5m) -> (3) surveillance temporelle sur capteur haut (PostRampTimeout, bit 11) si atteint hors homing (si les contacteurs et le frein ne confirment pas l'arrêt, SafeStop + PowerCutOff).
> - **FB_DriftGuard** : Nouvelle brique logicielle factorisant la dérive pour Méca A (bit 7) et Méca C (bit 9).
> - **Méca B étendu (bit 8)** : Vérifie désormais `BrakeFeedback` en plus de `FwdRevSpeedFeedbackOff` sous le délai `PostRampTimeout`.
> - **Diagnostics IHM** : Remontée en sortie de `FB_Safety_Winch` de `MecaADriftM`, `MecaCDriftM` et `MecaBElapsedTime` pour affichage et réglage sur l'IHM.
> - **Simulation cohérence** : Asservissement du capteur haut `TopPositionSensor` simulé à la position simulée (`SimTopSensorTriggered` si `CablePosM >= HomingTargetM1_M` en simulation).
> - **Simulation Joystick** : Division du flag de simulation de présence joystick en 2 : `Joystick_IsReal` (bus CANopen) et `JoystickSignal_IsReal` (signaux bruts).
>
> 🔧 **v1.6 (2026-07-08)** — Retour terrain frein (demande utilisateur) : nouveau retour thermique
> **frein**, COMMUN aux 3 axes M1/M2/M3 (1 seul fil, `BrakeThermalFeedback_DI`, câblé identiquement
> sur les 2 instances `FB_Safety_Winch` **et** sur `FB_Safety_Chariot` — voir Partie11 v1.3) → bit10
> `ErrorId`. **Escalade `PowerCutOff`** : un frein est à manque de courant (colle au repos, voir
> `FB_Brake`) — la perte de ce retour peut signifier qu'un frein colle **instantanément** alors que
> le moteur est encore en mouvement ; une simple rampe `SafeStop` ne protège pas la mécanique dans
> ce cas, il faut couper la puissance immédiatement. **Même raisonnement appliqué à bit2 (surchauffe
> moteur, déjà existant depuis v1.1)** : ajouté au masque `PowerCutOff` par cohérence/défense en
> profondeur (demande explicite utilisateur). Nouveaux masques : `SafeStop = (ErrorId AND 16#0F9F)` /
> `16#0F97` (OverrideSync), `PowerCutOff = (ErrorId AND 16#0F84)` (bits 2/7/8/9/10/11). Détail §3/§4sexies/§4nonies.
> 🔧 **v1.5 (2026-07-07)** — Implémentation du Cas B (« Mouvement non commandé / roue libre »,
> §4quinquies-TBD ci-avant) et de 2 garde-fous supplémentaires en défense en profondeur, tous
> câblés dans `FB_Safety_Winch` (nouveaux bits 7/8/9) : **Méca A** — mouvement/dérive détecté(e)
> alors que tout est confirmé physiquement coupé (contacteurs + frein) ; **Méca B** — pilotage
> actif constaté malgré absence de commande opérateur (perte CAN ou joystick au neutre) ;
> **Méca C (couche 2, escalade)** — glissement M1 pendant un mouvement Grappin, au-delà de ce que
> la couche 1 (`FB_Grappin`, voir Partie12 v1.2) a pu contenir. `PowerCutOff` devient **réel**
> (`FALSE` codé en dur jusqu'ici) pour ces 3 cas — les contacteurs étant déjà confirmés coupés,
> `SafeStop` seul ne suffit pas. Détail complet en §4quinquies ci-dessous ; interface
> `FB_Safety_Winch` et tableau `ErrorId` mis à jour en §3.
> 🔧 **v1.4 (2026-07-07)** — REX terrain : le retour contacteur individuel par sens
> (`ContactorFeedbackFwd`/`ContactorFeedbackRev`) est **supprimé côté câblage réel** — remplacé
> par **un seul retour par treuil**, `FwdRevSpeedFeedbackOff` (« tous les contacteurs sens+vitesse
> de ce treuil sont retombés »), câblé sur les nouvelles entrées physiques
> `M1/M2_FwdRevSpeedFeedbackOff_DI` (remplacent les 4 anciens canaux `M1/M2_FeedbackFwd/Rev_DI`).
> Conséquences : `FwdContactorCheck`/`RevContactorCheck` fusionnés en un seul `ContactorsCheck`
> (`ST_ContactorCheck`) ; vérification **StuckClosed uniquement, à l'arrêt commandé** (bit1
> `ErrorId`) ; `StuckOpen` n'a plus de sens avec ce signal (toujours `FALSE`, champ conservé pour
> compatibilité de type) ; bit2 `ErrorId` (ex-`RevContactorCheck`) **libéré/inutilisé**. Détail
> complet dans `CODE/WINCH/FB_Winch.st` (règle anti-doublon — pas de recopie ici) — voir §3/§5/§6
> ci-dessous pour l'interface et le mapping mis à jour. Hors périmètre : le Chariot M3
> (`FB_Chariot.st`) garde ses retours individuels `ContactorFeedbackFwd`/`Rev` — ce changement
> matériel ne concerne **que** les treuils M1/M2.
> 🗂️ **Réalignement nom de fichier/version** : ce fichier restait suffixé `_v1.1` alors que son
> contenu interne était déjà en v1.3. Corrigé à partir de v1.4.
> 🔧 **v1.3 (2026-07-04)** — Révision §4ter : comportement mou de câble revu.
> 🔧 **v1.2 (2026-07-03)** — Audit de sécurité et intégration du contrôle de cohérence des commandes.
> 🔧 **v1.1 (2026-07-02)** — Nouvel export `Device.export` avec I/O réel.

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (`ST_AxisCmd`, axe Y = Plongée/Extraction) en commande
physique d'un treuil : sens de rotation (2 contacteurs), palier de vitesse (4 contacteurs,
masque 4 bits), et séquence de frein à manque de courant — dans le respect strict de la
précédence `Enable` > `SafeStop` > `StartStop` (Partie3 §1bis).

Objectif de ce lot : **valider la chaîne complète en Maintenance N1** sur le treuil **M1**,
piloté **unitairement** (droit N1, Partie5 §2), **sans codeur** (acquisition non finalisée —
voir §5 Sécurité pour ce que cela implique concrètement).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdY ──► FB_Winch(M1) ──┬─► FB_SpeedStep ──► Contactor1..4 (table P<palier>R<relais>)
                                        ├─► RelayFwd / RelayRev (interlock changement de sens + ForbidDescent + ForbidAscent)
                                        └─► FB_Brake ──► BrakeCmd (séquence temporisée)

FB_Safety_Winch ──► SafeStop        ──► (entrée) FB_Winch(M1) — arrêt total (joystick/codeur/thermique moteur/thermique frein/mou câble normal/Méca A/B/C/D 🆕)
                ──► ForbidDescent   ──► (entrée) FB_Winch — masque UNIQUEMENT RelayRev (mou câble, MAINT+OverrideSync)
                ──► ForbidAscent    ──► (entrée) FB_Winch — masque UNIQUEMENT RelayFwd (mou câble, MAINT+OverrideSync ; ou arrêt normal haut hors HomingApproachEnable 🆕)
                ──► PowerCutOff 🆕  ──► (hors FB_Winch) coupure puissance amont — Méca A/B/C/D 🆕 + thermique moteur + thermique frein (SafeStop ne suffit pas, contacteurs déjà confirmés coupés OU frein risque de coller instantanément)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_SpeedStep` | Décode `SpeedRefPct` (0..100 %) en 4 sorties `Contactor1..4`, via table `ST_SpeedStepTable` propre à M1 (paramétrage individuel `P<palier>R<relais>`), sélection par `HYSTERESIS` (lib Util, anti-battement) |
| `FB_Brake` | Séquence frein temporisée (relâche après magnétisation, collage après décélération), double vérif retour contacteur |
| `FB_Safety_Winch` | Bloc safety **métier** du domaine treuil : lève `SafeStop` sur perte joystick/CAN, perte codeur, surchauffe moteur, surchauffe/perte thermique frein, mou de câble (mode normal), Méca A/B/C/D (roue libre, pilotage sans commande, glissement grappin escaladé, capteur haut non confirmé arrêté) ; lève `ForbidDescent`/`ForbidAscent` en MAINT+OverrideSync — voir §4ter, §4octies et §4nonies ; lève `PowerCutOff` sur thermique moteur/frein et Méca A/B/C/D — voir §4sexies et §4nonies |
| `FB_Winch` | Assemble les deux + arbitrage rampe `Enable > SafeStop > StartStop` + interlock sens + masquage `RelayRev`/`RelayFwd` sur `ForbidDescent`/`ForbidAscent`. Inhibé (`Enable` forcé à `FALSE`) si `InhibitMx` est actif. |

---

## 🔌 3. Interface

### `FB_Winch` (FB de mouvement, Partie3 §1bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | `FALSE` = neutralisation totale (sorties coupées). Forcé `FALSE` si `InhibitMx` est actif. |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Chaîne AU réarmée + conditions globales OK |
| `Mode` | `E_Mode` | Contexte (droits arbitrés en amont) |
| `StartStop` | BOOL | `TRUE` = rampe accélération, `FALSE` = rampe décélération normale |
| `SafeStop` | BOOL | Sortie `FB_Safety_Winch` : `TRUE` = rampe décélération **rapide** (arrêt total) |
| `ForbidDescent` | BOOL | Sortie dédiée `FB_Safety_Winch` (mou de câble) : masque **uniquement** `RelayRev` |
| `ForbidAscent` 🆕 v1.7 | BOOL | Sortie dédiée `FB_Safety_Winch` / Position : masque **uniquement** `RelayFwd` |
| `Direction` | INT | -1/0/+1 |
| `SpeedRefPct` | REAL | Consigne 0..100 % |
| `SpeedStepTable` | `ST_SpeedStepTable` | Table des 5 paliers **propre à M1** (20 `BOOL` `P<palier>R<relais>` + seuils) |
| `FwdRevSpeedFeedbackOff` | BOOL | Retour **unique** par treuil (I/O réel) : « tous les contacteurs sens+vitesse de ce treuil sont retombés » |
| `BrakeFeedback` | BOOL | Retour contacteur bobine frein |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `RelayFwd` / `RelayRev` | BOOL | Contacteurs de sens (jamais simultanés — interlock ; `RelayRev` forcé `FALSE` si `ForbidDescent`, `RelayFwd` forcé `FALSE` si `ForbidAscent`) |
| `Contactor1..4` | BOOL | Contacteurs de vitesse du palier courant (lus dans `Table.P<palier>R<relais>`) |
| `BrakeCmd` | BOOL | Commande bobine frein (`TRUE` = relâché) |
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | État standard (Partie3 §1) |
| `ContactorsCheck/BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic détaillé (IHM) |

### `FB_Safety_Winch` (1 instance par treuil, Partie3 §1/§7bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable`/`Reset`/`EmergencyStopOk`/`Mode` | — | Contrat standard (Inhibé/`FALSE` si `InhibitMx` actif) |
| `OverrideSync` | BOOL | OverrideSync actif (MAINT N1/N2) → exclut le bit3 (mou de câble) du SafeStop |
| `JoystickOnline`/`JoystickOperational` | BOOL | `instDiagCanOpen.Joystick` |
| `EncoderAvailable` | BOOL | Sortie `FB_Encoder_Abs` **de ce treuil** |
| `ThermalFeedback` | BOOL | Retour TOR thermique **de ce moteur** (`M1/M2_ThermalFeedback`, I/O réel) |
| `BrakeThermalFeedback` | BOOL | Retour TOR thermique **frein**, COMMUN aux 3 axes M1/M2/M3 |
| `SlackCableDetected` | BOOL | Détecteur mou de câble **commun** aux 2 treuils |
| `TopPositionSensor` 🆕 v1.7 | BOOL | Capteur de position haute unique (commun, NF : `TRUE` = sain, `FALSE` = butée) |
| `InReferencingMode` 🆕 v1.7 | BOOL | `TRUE` si le treuil est en cours de référencement (homing) |
| `CablePosM` | REAL | Position câble **de ce treuil** en mètres (scalée) |
| `CableLimitDescentM` | REAL | Limite basse physique descente (m, valeur négative) |
| `FwdRevSpeedFeedbackOff` | BOOL | Retour unique « tous contacteurs sens+vitesse retombés » |
| `BrakeFeedback` | BOOL | Retour frein **de ce treuil** (I/O réel) : `TRUE` = serré |
| `JoystickYNeutral` | BOOL | `TRUE` = joystick axe Y au neutre (magnitude `< 0.1`) |
| `GrappinHoldStillActive` | BOOL | `TRUE` pour l'instance M1 (glissement pendant `Grappin.Busy`) |
| `UncommandedSpeedThresholdMps` | REAL := 0.02 | Seuil vitesse unitaire Méca A |
| `UncommandedDriftToleranceM` | REAL := 2.0 | Tolérance dérive position Méca A |
| `PostRampTimeout` | TIME := T#3S | Délai de confirmation pour Méca B / Méca D |
| `GrappinSlipToleranceM` | REAL := 2.0 | Tolérance dérive M1 Méca C (escalade) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/State/StateAtError` | — | Contrat standard |
| `ErrorId` | WORD | bit0 : perte joystick/CAN ; bit1 : perte codeur ; bit2 : surchauffe moteur ; bit3 : mou de câble ; bit4 : rotation de phase ; bit5 : fin de course haut ; bit6 : longueur max câble ; bit7 : Méca A (mouvement non commandé) ; bit8 : Méca B (pilotage sans commande opérateur, vérifie contacteurs + frein) ; bit9 : Méca C (glissement M1 grappin) ; bit10 : surchauffe/perte thermique frein commun ; bit11 🆕 v1.7 : Méca D (capteur haut non confirmé arrêté hors homing, SafeStop+PowerCutOff) |
| `SafeStop` | BOOL | `(ErrorId AND 16#0F9F) <> 0` hors OverrideSync (bits 0/1/2/3/4/7/8/9/10/11), `(ErrorId AND 16#0F97) <> 0` sous OverrideSync (bit3 exclu). |
| `ForbidDescent` | BOOL | bit6 uniquement (limite basse câble) |
| `ForbidAscent` | BOOL | bit5 (fin de course haut) OU bit3+OverrideSync (récupération mou câble) |
| `PowerCutOff` | BOOL | `(ErrorId AND 16#0F84) <> 0` — bits 2 (surchauffe moteur), 7/8/9 (Méca A/B/C), 10 (thermique frein), 11 (Méca D). |
| `MecaADriftM` 🆕 v1.7 | REAL | Dérive mesurée Méca A (m) via `FB_DriftGuard` |
| `MecaCDriftM` 🆕 v1.7 | REAL | Dérive mesurée Méca C (m) via `FB_DriftGuard` |
| `MecaBElapsedTime` 🆕 v1.7 | TIME | Temps écoulé confirmation Méca B/D |

### `FB_WinchSync` (1 instance unique, Partie3 §1bis)

**📥 Entrées additionnelles 🆕 v1.7**
- `InhibitM1` / `InhibitM2` : Si l'un des treuils est inhibé en Maintenance N2, le bloc est désactivé (`Enable := FALSE` dans `PRG_MAIN`), remettant ses erreurs à zéro.

---

## 🛡️ 4. Sécurité

*(Paragraphes 4, 4ter, 4quater, 4quinquies, 4sexies inchangés, se référer aux versions précédentes)*

### 🆕 4septies. Inhibition des treuils (Lot #9-17)

En mode `MAINT_N2`, l'opérateur a la possibilité d'inhiber individuellement un treuil via l'IHM (`PRG_04_Modes.instModes.InhibitM1` ou `InhibitM2`).
- **Comportement sur le treuil inhibé** : L'inhibition force à `FALSE` l'`Enable` de son bloc de commande `FB_Winch` ainsi que celui de son bloc de surveillance `FB_Safety_Winch`. Le treuil concerné est ainsi totalement neutralisé (sorties physiques coupées, frein serré, sécurité logicielle inactive).
- **Comportement sur la synchronisation** : L'inhibition de l'un ou l'autre treuil désactive automatiquement `FB_WinchSync` (`Enable := FALSE`), ce qui efface ses défauts et empêche le déclenchement de l'alarme d'incohérence de commande (bit 1, 16#0002). Cela permet de faire fonctionner le treuil restant seul en toute sécurité pour des tests de mise en service.

### 🆕 4octies. Autorisation dépassement arrêt normal (HomingApproachEnable)

- **Arrêt normal haut** : En fonctionnement normal, dès qu'un treuil est référencé (`Homed = TRUE`), une limite virtuelle haute est activée à `HomingTargetMx_M - WinchTopStopMarginM` (ex : 12.0m). Dès que cette position est atteinte, la montée est interdite (`ForbidAscent := TRUE`), ce qui applique une rampe de décélération normale vers 0.
- **HomingApproachEnable** (ex-`OverrideTopStop`) : L'opérateur peut autoriser le dépassement de cet arrêt normal haut via un bouton IHM (`HomingApproachEnableRequest` actif en mode `MAINT_N2` uniquement). Si `HomingApproachEnable = TRUE`, la limite virtuelle est ignorée, et le treuil peut continuer sa montée jusqu'à l'atteinte physique du capteur haut.

### 🆕 4nonies. Surveillance Méca D et modèle à 3 couches d'arrêt haut

Pour protéger la structure mécanique lors de la montée, un modèle de sécurité à 3 couches successives est mis en place :
1. **Couche 1 : Arrêt normal** : Limitation virtuelle logicielle à `HomingTargetMx_M - WinchTopStopMarginM` (12.0m). Consigne coupée avec rampe de décélération normale. Bypassable via `HomingApproachEnable`.
2. **Couche 2 : Arrêt immédiat (bit 5)** : Si la butée physique `TopPositionSensor` est atteinte (NC ouvert, `FALSE`), l'automate coupe immédiatement la commande de montée (`ForbidAscent := TRUE`, ce qui coupe `RelayFwd` sans rampe).
3. **Couche 3 : Méca D (bit 11 - 🆕 v1.7)** : Si le capteur physique `TopPositionSensor` est atteint en fonctionnement normal (hors référencement) et que les contacteurs physiques (`FwdRevSpeedFeedbackOff`) ou le frein (`BrakeFeedback`) ne confirment pas l'arrêt réel (c'est-à-dire contacteurs ouverts et frein serré) dans un délai `PostRampTimeout` (3 s), le défaut **Méca D** (bit 11) se déclenche. Ce défaut entraîne un `SafeStop` et un `PowerCutOff` immédiats pour couper l'alimentation de puissance en amont.

### 🆕 4decies. Refactoring Méca A/C par FB_DriftGuard et extension Méca B/D

- **FB_DriftGuard** : Pour éviter les redondances de code, la logique de dérive (stockage de position de référence lors de l'armement, puis comparaison de la dérive absolue à un seuil toléré) est factorisée dans la brique réutilisable `FB_DriftGuard`. Deux instances distinctes (`DriftGuardA` et `DriftGuardC`) sont intégrées dans `FB_Safety_Winch`.
- **Méca B étendu** : La surveillance Méca B (pilotage actif sans commande opérateur) a été étendue au retour frein : le défaut se déclenche si les contacteurs ne retombent pas **OU** si le frein ne confirme pas son serrage (`BrakeFeedback = FALSE`) à la fin de la temporisation.
- **Diagnostics IHM** : Afin de faciliter la mise en service et le réglage des seuils sur site, les valeurs de dérive mesurées (`MecaADriftM`, `MecaCDriftM`) ainsi que le temps d'attente d'arrêt réel (`MecaBElapsedTime`) sont exposés en sorties de `FB_Safety_Winch` et mappés vers l'IHM.

---

## 🗺️ 5. Mapping E/S et Simulation

| Variable (code) | Sens | Statut | Rôle |
|------------------|------|--------|------|
| `M1/M2_RelayFwd` | Sortie | 📡 I/O réel | Contacteur sens avant (montée) |
| `M1/M2_RelayRev` | Sortie | 📡 I/O réel | Contacteur sens arrière (descente) |
| `M1/M2_SpeedContactor_1..4` | Sortie | 📡 I/O réel | Contacteurs de vitesse |
| `M1/M2_BrakeCmd` | Sortie | 📡 I/O réel | Bobine frein (`TRUE` = relâché) |
| `M1/M2_FwdRevSpeedFeedbackOff` | Entrée | 📡 I/O réel | Retour unique contacteurs sens+vitesse retombés |
| `M1/M2_BrakeFeedback` | Entrée | 📡 I/O réel | Retour contacteur frein |
| `M1_M2_TopPositionSensor` | Entrée | 📡 I/O réel | Capteur position haute commun |
| `M1/M2_ThermalFeedback` | Entrée | 📡 I/O réel | Thermique moteur |
| `M1_M2_SlackCableSwitch` | Entrée | 📡 I/O réel | Détecteur mou de câble commun |
| `BrakeThermalFeedback_DI` | Entrée | 📡 I/O réel | Retour thermique frein commun M1/M2/M3 |

### 🧪 Simulation & Cohérence

- **Simulation de cohérence Capteur Haut** : En mode simulation (si `TopPositionSensor_IsReal = FALSE`), le capteur physique simulé est asservi à la position du câble de M1 :
  `SimTopSensorTriggered := HomedM1 AND (CablePosM1 >= HomingTargetM1_M)`
  Si cette condition est `TRUE`, le capteur physique est simulé à `FALSE` (butée atteinte en logique NC), déclenchant l'arrêt de la Couche 2.
- **Scission de Simulation Joystick** :
  - `Joystick_IsReal` : Gère le bus/nœud CANopen (CanOnline/CanOperational). Si `FALSE`, simule le nœud sain.
  - `JoystickSignal_IsReal` : Gère les signaux bruts (RawX/RawY/RawButton). Si `FALSE`, les signaux sont simulés par `instSimJoystick`, permettant de tester des profils de consignes sans joystick physique.

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier** — dossier `CODE/` :
- [`CODE/WINCH/FB_DriftGuard.st`](../CODE/WINCH/FB_DriftGuard.st) 🆕 v1.7 — Brique de détection de dérive (Méca A/C)
- [`CODE/WINCH/FB_Safety_Winch.st`](../CODE/WINCH/FB_Safety_Winch.st) — **Mise à jour v1.7** (Méca D, diagnostics IHM, Méca B étendu, refactoring DriftGuard, SafeStop/PowerCutOff)
- [`CODE/WINCH/FB_WinchSync.st`](../CODE/WINCH/FB_WinchSync.st) — **Mise à jour v1.7** (Ajout entrées d'inhibition M1/M2)
- [`CODE/MAIN/PRG_00_Inputs.st`](../CODE/MAIN/PRG_00_Inputs.st) — **Mise à jour v1.7** (SimTopSensorTriggered asservi, BrakeThermalFeedback commun, JoystickSignal_IsReal split)
- [`CODE/MAIN/PRG_03_Safety.st`](../CODE/MAIN/PRG_03_Safety.st) — **Mise à jour v1.7** (Inhibition M1/M2 câblée vers Enable Safety)
- [`CODE/MAIN/PRG_06_WinchControl.st`](../CODE/MAIN/PRG_06_WinchControl.st) — **Mise à jour v1.7** (InhibitM1/M2, HomingApproachEnable, désactivation de la synchro sur inhibition)
- [`CODE/SIMULATION/GVL_Simulation.st`](../CODE/SIMULATION/GVL_Simulation.st) — **Mise à jour v1.7** (Séparation `Joystick_IsReal` / `JoystickSignal_IsReal`)

---

## 📝 7. Note d'application CODESYS 3.5

### Étape 0 — Importer la brique `FB_DriftGuard`
1. Créer un nouveau bloc fonctionnel `FB_DriftGuard` dans le dossier `WINCH`.
2. Y coller le code de [`CODE/WINCH/FB_DriftGuard.st`](../CODE/WINCH/FB_DriftGuard.st).

### Étape 6bis — Mettre à jour `FB_Safety_Winch`
1. Mettre à jour la déclaration et l'implémentation de `FB_Safety_Winch` à partir de [`CODE/WINCH/FB_Safety_Winch.st`](../CODE/WINCH/FB_Safety_Winch.st).
2. Vérifier que les variables de diagnostics IHM (`MecaADriftM`, `MecaCDriftM`, `MecaBElapsedTime`) sont bien créées.

### Étape 7bis — Mettre à jour les programmes de commande
1. Mettre à jour `PRG_00_Inputs` pour intégrer la simulation de butée haute cohérente et le split joystick.
2. Mettre à jour `PRG_03_Safety` et `PRG_06_WinchControl` pour raccorder les signaux `InhibitM1`/`InhibitM2` et `HomingApproachEnable`.

### Étape 10 — Compiler et vérifier
1. Faire un **Rebuild all** (F11) et valider qu'il y a 0 erreur.

---

## 🔁 8. Retour d'expérience (Checklist Validation v1.7)

- [ ] **Inhibition treuils** : Activer `InhibitM1` (IHM) en MAINT_N2 → vérifier `Enable` de `FB_Winch(M1)` et `FB_Safety_Winch(M1)` coupés, et `FB_WinchSync` désactivé (pas d'erreur de mismatch). Répéter pour M2.
- [ ] **HomingApproachEnable** : Sans activer, monter le câble référencé → vérifier l'interdiction de montée à 12.0m. Activer la case IHM → vérifier que la montée est autorisée au-delà de 12.0m.
- [ ] **Modèle 3 couches (Méca D)** : Monter le treuil hors référencement jusqu'au capteur haut physique (NC ouvert) → forcer un contacteur ou le frein à rester collé (par simulation) → vérifier que le défaut **Méca D** (bit 11) se déclenche après 3s, coupant le `SafeStop` et le `PowerCutOff`.
- [ ] **Méca B étendu** : Mettre le joystick au neutre → forcer le retour contacteur ou frein à `FALSE` → vérifier que le défaut Méca B se déclenche après 3s.
- [ ] **Diagnostics IHM** : Vérifier que les variables `MecaADriftM`, `MecaCDriftM` et `MecaBElapsedTime` sont correctement rafraîchies à l'écran de supervision.
- [ ] **Simulation cohérence capteur haut** : En simulation, monter au-dessus du point de butée virtuelle → vérifier que le capteur physique simulé `TopPositionSensor` passe bien à `FALSE` de manière synchrone.
- [ ] **Scission Joystick** : Configurer `Joystick_IsReal := TRUE` et `JoystickSignal_IsReal := FALSE` → vérifier que le nœud CAN est diagnostiqué sain sur le bus, tout en pouvant injecter une consigne simulée via `instSimJoystick`.

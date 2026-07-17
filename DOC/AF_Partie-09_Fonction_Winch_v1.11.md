# 📋 Analyse Fonctionnelle — Partie 9 : Fonction Winch (v1.11)

> **v1.11 (2026-07-15)** — TASK-0001 : Mise à jour de la référence T20 (arbitrage du sélecteur JoystickWinchSelect déplacé dans FB_Modes, voir AF_Partie-05 v1.6).
>
> **v1.10** — Nettoyage documentaire (audit doc) : remarques organisationnelles (sélecteur treuil
> IHM non codé, §4undecies montée en charge, checklist validation v1.7) remplacées par des renvois
> courts vers `DOC/PLAN_TASK_v1.0.md` §3 (T9/T20/T21). Aucun changement fonctionnel.
> 🆕 **v1.9 (2026-07-09)** — Documentation exhaustive des 5 mécanismes de sécurité (Méca A–E, bits 7/8/9/11/12/13), extraits du code réel `FB_Safety_Winch.st` : comportement d'armement, seuils, conséquences, escalades PowerCutOff, et subtilités critiques (§4novies ci-dessous).
> 📌 **État d'implémentation (2026-07-08, AUDIT)** : `FB_WinchSync` **codé et audité**
> — `CODE/FB_WinchSync.st`, 1 instance. Calcule `DeltaPosM`/`SyncWarn` (IHM uniquement, PAS de
> `SafeStop` pour l'écart de position), `SyncActive` selon Mode (imposé N1, configurable en N2 via `SyncEnable`
> de `FB_Modes`).
> **Contrôle de cohérence de commande intégré** : `ErrorId` bit 1 (16#0002) entraîne un `SafeStop` des deux treuils.
> **Pas de correction/régulation active** de l'écart — `FB_Winch` n'a aucune entrée de
> correction de vitesse aujourd'hui. 📌 Suivi (sélecteur treuil IHM M1/M2/Les deux + bit « Prise de
> main IHM », toujours non codés) : voir `DOC/PLAN_TASK_v1.0.md` §3 (T20).
>
> **Fonction métier** : chaîne de commande Joystick (axe Y, Plongée/Extraction) → `FB_Winch` →
> relais de sens et de vitesse, avec séquence frein. Premier lot testable en **Maintenance N1**,
> treuil **M1 seul**, **sans dépendance codeur**.
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔗 Dépend de : [P2 Architecture v2.12](AF_Partie-02_Architecture_Programme_v2.12.md), [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md), [P4 Cycle v1.4](AF_Partie-04_Cycle_Sequenceur_v1.4.md) §3bis/§4, [P5 Modes v1.6](AF_Partie-05_Modes_Maintenance_v1.6.md), [P8 Joystick v1.3](AF_Partie-08_Fonction_Joystick_v1.3.md).
>
> 🆕 **v1.8 (2026-07-08)** — Lot #9-18 : Alignment and clarifications on independent cable limit descent (M1 and M2 cable limits are fully independent, using dedicated GVL_PERSISTENT and HMI variables).
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
> sur les 2 instances `FB_Safety_Winch` **et** sur `FB_Safety_Translation` — voir Partie11 v1.3) → bit10
> `ErrorId`. **Escalade `PowerCutOff`** : un frein est à manque de courant (colle au repos, voir
> `FB_Brake`) — la perte de ce retour peut signifier qu'un frein colle **instantanément** alors que
> le moteur est encore en mouvement ; une simple rampe `SafeStop` ne protège pas la mécanique dans
> ce cas, il faut couper la puissance immédiatement. **Même raisonnement appliqué à bit2 (surchauffe
> moteur, déjà existant depuis v1.1)** : ajouté au masque `PowerCutOff` par cohérence/défense en
> profondeur (demande explicite utilisateur). Nouveaux masques : `SafeStop = (ErrorId AND 16#0F9F)` /
> `16#0F97` (si SyncEnable=FALSE), `PowerCutOff = (ErrorId AND 16#0F84)` (bits 2/7/8/9/10/11). Détail §3/§4sexies/§4nonies.
> 🔧 **v1.5 (2026-07-07)** — Implémentation du Cas B (« Mouvement non commandé / roue libre »,
> §4quinquies-TBD ci-avant) et de 2 garde-fous supplémentaires en défense en profondeur, tous
> câblés dans `FB_Safety_Winch` (nouveaux bits 7/8/9) : **Méca A** — mouvement/dérive détecté(e)
> alors que tout est confirmé physiquement coupé (contacteurs + frein) ; **Méca B** — pilotage
> actif constaté malgré absence de commande opérateur (perte CAN ou joystick au neutre) ;
> **Méca C (couche 2, escalade)** — glissement M1 pendant un mouvement Benne, au-delà de ce que
> la couche 1 (`FB_Bucket`, voir Partie12 v1.2) a pu contenir. `PowerCutOff` devient **réel**
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
> ci-dessous pour l'interface et le mapping mis à jour. Hors périmètre : le Translation M3
> (`FB_Translation.st`) garde ses retours individuels `ContactorFeedbackFwd`/`Rev` — ce changement
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
                ──► ForbidDescent   ──► (entrée) FB_Winch — masque UNIQUEMENT RelayRev (mou câble, MAINT+SyncEnable=FALSE)
                ──► ForbidAscent    ──► (entrée) FB_Winch — masque UNIQUEMENT RelayFwd (mou câble, MAINT+SyncEnable=FALSE ; ou arrêt normal haut hors HomingApproachEnable 🆕)
                ──► PowerCutOff 🆕  ──► (hors FB_Winch) coupure puissance amont — Méca A/B/C/D 🆕 + thermique moteur + thermique frein (SafeStop ne suffit pas, contacteurs déjà confirmés coupés OU frein risque de coller instantanément)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_SpeedStep` | Décode `SpeedRefPct` (0..100 %) en 4 sorties `Contactor1..4`, via table `ST_SpeedStepTable` propre à M1 (paramétrage individuel `P<palier>R<relais>`), sélection par `HYSTERESIS` (lib Util, anti-battement) |
| `FB_Brake` | Séquence frein temporisée (relâche après magnétisation, collage après décélération), double vérif retour contacteur |
| `FB_Safety_Winch` | Bloc safety **métier** du domaine treuil : lève `SafeStop` sur perte joystick/CAN, perte codeur, surchauffe moteur, surchauffe/perte thermique frein, mou de câble (mode normal), Méca A/B/C/D (roue libre, pilotage sans commande, glissement benne escaladé, capteur haut non confirmé arrêté) ; lève `ForbidDescent`/`ForbidAscent` en MAINT+SyncEnable=FALSE — voir §4ter, §4octies et §4nonies ; lève `PowerCutOff` sur thermique moteur/frein et Méca A/B/C/D — voir §4sexies et §4nonies |
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
| `SyncEnable` | BOOL | SyncEnable (MAINT N1/N2) — `FALSE` exclut le bit3 (mou de câble) du SafeStop |
| `JoystickOnline`/`JoystickOperational` | BOOL | `instDiagCanOpen.DeviceJoystick` |
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
| `BenneHoldStillActive` | BOOL | `TRUE` pour l'instance M1 (glissement pendant `Benne.Busy`) |
| `UncommandedSpeedThresholdMps` | REAL := 0.02 | Seuil vitesse unitaire Méca A |
| `UncommandedDriftToleranceM` | REAL := 2.0 | Tolérance dérive position Méca A |
| `PostRampTimeout` | TIME := T#3S | Délai de confirmation pour Méca B / Méca D |
| `BenneSlipToleranceM` | REAL := 2.0 | Tolérance dérive M1 Méca C (escalade) |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/State/StateAtError` | — | Contrat standard |
| `ErrorId` | WORD | bit0 : perte joystick/CAN ; bit1 : perte codeur ; bit2 : surchauffe moteur ; bit3 : mou de câble ; bit4 : rotation de phase ; bit5 : fin de course haut ; bit6 : longueur max câble ; bit7 : Méca A (mouvement non commandé) ; bit8 : Méca B (pilotage sans commande opérateur, vérifie contacteurs + frein) ; bit9 : Méca C (glissement M1 benne) ; bit10 : surchauffe/perte thermique frein commun ; bit11 🆕 v1.7 : Méca D (capteur haut non confirmé arrêté hors homing, SafeStop+PowerCutOff) |
| `SafeStop` | BOOL | `(ErrorId AND 16#0F9F) <> 0` si SyncEnable=TRUE (bits 0/1/2/3/4/7/8/9/10/11), `(ErrorId AND 16#0F97) <> 0` si SyncEnable=FALSE (bit3 exclu). |
| `ForbidDescent` | BOOL | bit6 uniquement (limite basse câble) |
| `ForbidAscent` | BOOL | bit5 (fin de course haut) OU bit3+SyncEnable=FALSE (récupération mou câble) |
| `PowerCutOff` | BOOL | `(ErrorId AND 16#0F84) <> 0` — bits 2 (surchauffe moteur), 7/8/9 (Méca A/B/C), 10 (thermique frein), 11 (Méca D). |
| `MecaADriftM` 🆕 v1.7 | REAL | Dérive mesurée Méca A (m) via `FB_DriftGuard` |
| `MecaCDriftM` 🆕 v1.7 | REAL | Dérive mesurée Méca C (m) via `FB_DriftGuard` |
| `MecaBElapsedTime` 🆕 v1.7 | TIME | Temps écoulé confirmation Méca B/D |

### `FB_WinchSync` (1 instance unique, Partie3 §1bis)

**📥 Entrées additionnelles 🆕 v1.7**
- `InhibitM1` / `InhibitM2` : Si l'un des treuils est inhibé en Maintenance N2, le bloc est désactivé (`Enable := FALSE` dans `PRG_MAIN`), remettant ses erreurs à zéro.
- **Déclenchement du SafeStop** : Toute erreur active du bloc (`Error = TRUE`, incluant l'écart de position hors tolérance bit 0 (16#0001) et l'incohérence des commandes bit 1 (16#0002)) déclenche immédiatement un `SafeStop` sur les deux treuils, entraînant une rampe de décélération rapide vers 0.

---

## 🛡️ 4. Sécurité

*(Paragraphes 4, 4ter, 4quater, 4quinquies, 4sexies inchangés, se référer aux versions précédentes)*

### 🆕 4septies. Inhibition des treuils (Lot #9-17)

En mode `MAINT_N2`, l'opérateur a la possibilité d'inhiber individuellement un treuil via l'IHM (`PRG_04_Modes.instModes.InhibitM1` ou `InhibitM2`).
- **Comportement sur le treuil inhibé** : L'inhibition force à `FALSE` l'`Enable` de son bloc de commande `FB_Winch` ainsi que celui de son bloc de surveillance `FB_Safety_Winch`. Le treuil concerné est ainsi totalement neutralisé (sorties physiques coupées, frein serré, sécurité logicielle inactive).
- **Isolation complète de la sécurité et des défauts** :
  - **Remise à zéro des erreurs** : Lorsque l'entrée `Enable` de `FB_Winch` et `FB_Safety_Winch` passe à `FALSE`, leurs sorties `Error` et `ErrorId` (16#0000) sont explicitement réinitialisées. Les surveillances associées au treuil inhibé (dérive DriftGuard Méca A/C, surveillance thermique moteur/frein, glissement, retour d'état des contacteurs) sont totalement désactivées et ne peuvent plus générer d'alarme active.
  - **Filtrage supervision/IHM** : Dans la logique de supervision globale (`PRG_09_Supervision.st`), l'acquisition du signal d'alarme global `GVL_IHM.Modes.AnyFaultActive` filtre dynamiquement et ignore les défauts spécifiques du treuil inhibé (ce qui inclut l'encodeur absolu, le homing, la sécurité codeur, la sécurité générale du treuil et le bloc de contrôle de mouvement).
- **Comportement sur la synchronisation et le benne** : L'inhibition de l'un ou l'autre treuil désactive automatiquement `FB_WinchSync` (`Enable := FALSE`), ce qui efface ses défauts et empêche le déclenchement de l'alarme d'incohérence de commande (bit 1, 16#0002). De plus, l'inhibition du treuil M2 (fermeture) désactive également le bloc benne `FB_Bucket` (`Enable := FALSE`), empêchant toute ouverture ou fermeture. En revanche, si seul M1 (retenue) est inhibé, le benne peut toujours être manœuvré (M2 tourne seul pour ouvrir/fermer, M1 restant verrouillé au frein) à condition que les deux codeurs M1 et M2 soient disponibles, valides (sains) et référencés (homed). Si le codeur de M1 ou M2 est en défaut ou non référencé, le benne est automatiquement bloqué. Cela permet de faire fonctionner le treuil restant seul en toute sécurité pour des tests de mise en service.

### 🆕 4octies. Autorisation dépassement arrêt normal (HomingApproachEnable), limites logicielles et dissociation des limites de descente

- **Dissociation des limites de descente câble (M1/M2)** : Les limites de descente de câble pour les treuils M1 et M2 sont entièrement indépendantes. Elles sont définies par deux variables persistantes distinctes dans `GVL_PERSISTENT` : `CableLimitDescentM1_M` (pour M1) et `CableLimitDescentM2_M` (pour M2). Elles sont configurées individuellement depuis l'IHM via `WinchM1.CableLimitDescentM` et `WinchM2.CableLimitDescentM` et propagées par `PRG_09_Supervision`.
- **Arrêt virtuel normal haut** : En fonctionnement normal, dès qu'un treuil est référencé (`Homed = TRUE` et `HomingSuspect = FALSE`), une limite virtuelle haute normale est activée. Pour le treuil M1 (holding), elle est à `HomingTargetM1_M - WinchTopStopMarginM` (par défaut 12.00m). Pour le treuil M2 (closing), afin de permettre la fermeture complète du benne y compris à hauteur maximale sans déclencher de butée prématurée, cette limite est décalée dynamiquement de l'offset de fermeture et se situe à `HomingTargetM2_M + M2_LimitShift - WinchTopStopMarginM` (soit 14.00m si `OffsetCloseM = 2.0m`). Ce décalage `M2_LimitShift` est égal à `OffsetCloseM` uniquement si le benne est fermé ou en cours de fermeture (`IsClosed OR CloseReq`), et vaut `0.0` si le benne est ouvert (ramenant la butée de M2 à 12.00m comme M1 pour un arrêt synchrone en remontée normale). Dès que cette position est atteinte et si `HomingApproachEnable = FALSE`, la montée est interdite (`ForbidAscent := TRUE`), ce qui applique une rampe de décélération normale vers 0.
- **Limite logicielle absolue** : Dès que le treuil est référencé (`Homed = TRUE` et `HomingSuspect = FALSE`), une limite logicielle absolue est active. Pour le treuil M1, elle est à `HomingTargetM1_M` (12.50m). Pour le treuil M2, elle est décalée dynamiquement de l'offset de fermeture et se situe à `HomingTargetM2_M + M2_LimitShift` (soit 14.50m si `OffsetCloseM = 2.0m` et benne fermé/fermeture). Dès que cette limite absolue est dépassée, la montée est inconditionnellement interdite (`ForbidAscent := TRUE`).
- **HomingApproachEnable** (ex-`OverrideTopStop`) : L'opérateur peut autoriser le dépassement de l'arrêt normal haut (12.00m) via un bouton HMI (`HomingApproachEnableRequest` actif en mode `MAINT_N2` uniquement). Si `HomingApproachEnable = TRUE`, la limite virtuelle normale (12.00m) est ignorée, permettant au treuil d'approcher lentement le capteur physique haut jusqu'à la limite logicielle absolue (12.50m) ou l'atteinte physique du capteur.
- **Verrouillage de vitesse au Palier 1** : Afin de sécuriser les mouvements en phase critique ou en l'absence de repères fiables, la vitesse du treuil est bridée dynamiquement au **palier 1** (contacteur `Contactor1` actif uniquement, `MaxStepNumber := 1` dans `FB_Winch`) dans les cas suivants :
  1. Le treuil n'est pas référencé (`Homed = FALSE`) ou présente un doute de dérive au démarrage (`HomingSuspect = TRUE`).
  2. Le mode approche est actif en montée (`HomingApproachActive = TRUE`, correspondant à `HomingApproachEnable = TRUE` en montée).

### 🆕 4nonies. Surveillance Méca D et modèle à 3 couches d'arrêt haut

Pour protéger la structure mécanique lors de la montée, un modèle de sécurité à 3 couches successives est mis en place :
1. **Couche 1 : Arrêt normal et limite absolue** : Limitation virtuelle logicielle à `HomingTargetMx_M - WinchTopStopMarginM` (12.00m), bypassable par `HomingApproachEnable` (qui bride alors la vitesse au palier 1), puis arrêt inconditionnel sur la limite logicielle absolue à `HomingTargetMx_M` (12.50m).
2. **Couche 2 : Arrêt immédiat et alarme capteur physique (bit 5)** :
   - **Comportement de l'alarme (bit 5 `ErrorId`)** : L'alarme de fin de course haut n'est levée que si le capteur physique `TopPositionSensor` est activé (contact NF ouvert, `FALSE`), hors mode référencement (`InReferencingMode = FALSE`), ET que le treuil est commandé dans le sens de la montée (`Direction > 0`). Cela évite de lever un défaut permanent bloquant. L'alarme peut être acquittée via `Reset` dès que la commande de montée est relâchée (`Direction <= 0`), permettant ainsi d'engager la descente pour dégager le câble.
   - **Maintien de la sécurité positive** : Bien que l'alarme IHM (bit 5) puisse être acquittée pour autoriser la descente, l'interdiction de montée `ForbidAscent` reste verrouillée physiquement à `TRUE` tant que le capteur physique haut est actionné (`TopPositionSensor = FALSE`) et que le treuil n'est pas en phase de référencement.
3. **Couche 3 : Méca D (bit 11 - 🆕 v1.7)** : Si le capteur physique `TopPositionSensor` est atteint en fonctionnement normal (hors référencement) **OU** si la limite logicielle redondante est dépassée (`Homed = TRUE`, `HomingSuspect = FALSE`, et `CablePosM >= TopLimitM + 0.10`), et que les contacteurs physiques (`FwdRevSpeedFeedbackOff`) ou le frein (`BrakeFeedback`) ne confirment pas l'arrêt réel (c'est-à-dire contacteurs ouverts et frein serré) dans un délai `PostRampTimeout` (3 s), le défaut **Méca D** (bit 11) se déclenche. Ce défaut entraîne un `SafeStop` et un `PowerCutOff` immédiats pour couper l'alimentation de puissance en amont.

### 🆕 4decies. Refactoring Méca A/C par FB_DriftGuard et extension Méca B/D

- **FB_DriftGuard** : Pour éviter les redondances de code, la logique de dérive (stockage de position de référence lors de l'armement, puis comparaison de la dérive absolue à un seuil toléré) est factorisée dans la brique réutilisable `FB_DriftGuard`. Deux instances distinctes (`DriftGuardA` et `DriftGuardC`) sont intégrées dans `FB_Safety_Winch`.
- **Méca B étendu** : La surveillance Méca B (pilotage actif sans commande opérateur) a été étendue au retour frein : le défaut se déclenche si les contacteurs ne retombent pas **OU** si le frein ne confirme pas son serrage (`BrakeFeedback = FALSE`) à la fin de la temporisation.
- **Diagnostics IHM** : Afin de faciliter la mise en service et le réglage des seuils sur site, les valeurs de dérive mesurées (`MecaADriftM`, `MecaCDriftM`) ainsi que le temps d'attente d'arrêt réel (`MecaBElapsedTime`) sont exposés en sorties de `FB_Safety_Winch` et mappés vers l'IHM.

### 🆕 4undecies. Investigations futures — Montée en charge et temporisation frein

**Contexte** : Phase opérationnelle de descente (récupération de charge), puis remontée chargée
(montée en charge). Le poids de la charge crée un effet entraînant mécanique sur le système,
susceptible de contredire l'hypothèse des temporisations de frein actuelles (voir `FB_Brake.st` §3),
en particulier sur le délai de relâche (magnétisation) et de collage (décélération) du frein.

📌 Suivi (validation terrain + réglages de temporisations différés après essais de charge) : voir
`DOC/PLAN_TASK_v1.0.md` §3 (T9).

### 🆕 4novies. Défense en profondeur : Les 5 mécanismes de sécurité (Méca A–E, v1.9)

`FB_Safety_Winch` implémente **5 mécanismes de sécurité indépendants** en défense en profondeur contre les défauts de mouvement (roue libre), les défaillances de capteurs, et les écarts de synchronisation. Chaque mécanisme dispose d'un **bit `ErrorId` dédié**, d'une **condition d'armement**, d'une **condition de déclenchement**, et d'une **conséquence** (arrêt `SafeStop` classique, ou escalade `PowerCutOff` amont quand les contacteurs confirment déjà être coupés ou quand la protection du couple est en jeu).

#### Tableau récapitulatif

| **Méca** | **Rôle** | **Bit** | **Armement** | **Déclenchement** | **Conséquence** | **Seuil / Délai** |
|---|---|---|---|---|---|---|
| **A** | Mouvement non commandé (roue libre) | bit7 (16#0080) | Contacteurs + frein confirmés coupés, hors homing | Dérive > 2.0m OU vitesse > 0.02 m/s | SafeStop + **PowerCutOff** | `UncommandedDriftToleranceM` (2.0m), `UncommandedSpeedThresholdMps` (0.02 m/s) |
| **B** | Pilotage sans commande opérateur | bit8 (16#0100) | Perte CAN ou joystick au neutre | Contacteurs/frein ne confirment pas arrêt après délai | SafeStop + **PowerCutOff** | `PostRampTimeout` (3s) |
| **C** | Glissement M1 pendant benne | bit9 (16#0200) | Benne en mouvement (M1 seul) | Dérive M1 > 2.0m (escalade au-delà de `FB_Bucket`) | SafeStop + **PowerCutOff** | `BenneSlipToleranceM` (2.0m) |
| **D** | Capteur haut non confirmé arrêté | bit11 (16#0800) | Capteur physique atteint OU limite logicielle dépassée, hors homing | Contacteurs/frein ne confirment pas arrêt après délai | SafeStop + **PowerCutOff** | `PostRampTimeout` (3s) |
| **E** | Écart synchro M1/M2 critique | bit12 (16#1000) + bit13 (16#2000) | Synchro activée, hors benne/homing | Écart > 2.0m → **bit12 immédiat** ; pas confirmé arrêté → **bit13 escalade** | Bit12 : SafeStop seul ; Bit13 : SafeStop + **PowerCutOff** | `CriticalSyncToleranceM` (2.0m), `PostRampTimeout` (3s) |

---

#### Méca A — Mouvement non commandé général (Bit7)

**Rôle** : Détecter la **roue libre ou le glissement du frein** au repos — tout mouvement lors que l'automate a commandé l'arrêt complet (tous les contacteurs et le frein confirmés fermés).

**Armement** : 
- Condition : `FwdRevSpeedFeedbackOff AND BrakeFeedback AND NOT InReferencingMode`
  - `FwdRevSpeedFeedbackOff` = tous les contacteurs sens+vitesse retombés ✓
  - `BrakeFeedback` = frein serré (contact fermé) ✓
  - Hors phase de référencement (position instable)

**Déclenchement** :
- Condition : Toujours vraie dans ce cycle, **OU** (vitesse mesurée dans le cycle > 0.02 m/s)
- Brique `FB_DriftGuard` : capture la position de référence à l'armement ; chaque scan, calcule `ABS(CablePosM - RefPos)` → si > 2.0 m → `Violation := TRUE`
- Littéralement : `DriftGuardA.Violation OR (Vitesse > 0.02 m/s)`

**Conséquence** : 
- `ErrorId` bit7 levé → inclus dans le **masque `SafeStop`** (bits 0/1/2/3/4/7/8/9/10/11/12/13)
- **Escalade immédiate** : bit7 aussi dans le **masque `PowerCutOff`** (bits 2/7/8/9/10/11/13) → coupure puissance amont sans délai
- Raison : les contacteurs et le frein confirment déjà être arrêtés ; `SafeStop` seul ne suffit pas (frein peut avoir flanché)

**Paramètres réglables** :
- `UncommandedDriftToleranceM` (défaut 2.0 m) — Tolérance spatiale avant défaut
- `UncommandedSpeedThresholdMps` (défaut 0.02 m/s) — Seuil vitesse (mesurée par différence position entre 2 scans, à 10 ms)

**Subtilités** :
- Deux conditions en **OR** : dérive OU vitesse. L'une ou l'autre suffit à déclencher le défaut.
- Frein doit être confirmé **serré** (pas juste les contacteurs) — protection contre un frein qui aurait relâché prématurément.
- Sortie diagnostic : `MecaADriftM` (dérive mesurée en mètres) — affichée à l'IHM pour mise en service.

---

#### Méca B — Pilotage actif sans commande opérateur (Bit8)

**Rôle** : Détecter un **mouvement non autorisé suite à une perte de commande** (perte du lien CAN ou joystick au neutre), en tant que **garde-fou indépendant** même si `FB_Winch` défaillerait.

**Armement** :
- Condition : `(NOT JoystickOnline) OR (NOT JoystickOperational) OR JoystickYNeutral`
  - Perte du nœud CAN, OU
  - Nœud en défaut d'exploitation, OU
  - Manche au neutre (magnitude < 0.1)
  - → `MecaB_NoOperatorCmd := TRUE`

**Déclenchement** :
- Condition : Si `MecaB_NoOperatorCmd = TRUE` **ET** que `NOT (FwdRevSpeedFeedbackOff AND BrakeFeedback)` (contacteurs OU frein ne confirmant pas arrêt) pendant **3 secondes**
- Timer `TonMecaB` : si la condition reste vraie tout ce temps, `TonMecaB.Q` bascule → bit8 levé
- Littéralement : perte de commande + pas de confirmation physique d'arrêt après 3s = mouvement indésirable

**Conséquence** :
- `ErrorId` bit8 levé → inclus dans masque **`SafeStop`**
- **Escalade immédiate** : aussi dans le masque **`PowerCutOff`** → coupure puissance amont

**Paramètres réglables** :
- `PostRampTimeout` (défaut T#3S) — Délai de confirmation contacteurs/frein (partagé avec Méca D)

**Subtilités** :
- **Vérification combinée des deux retours** : Les contacteurs **ET** le frein doivent tous deux confirmer l'arrêt — c'est une **évolution v1.7** (auparavant seuls les contacteurs étaient vérifiés).
- La perte de frein (pas de serrage) seule suffit à déclencher Méca B, même si les contacteurs retombent correctement.
- Sortie diagnostic : `MecaBElapsedTime` (temps écoulé depuis le début de la temporisation) — monitoré à l'IHM.

---

#### Méca C — Glissement M1 pendant benne (Bit9 — Escalade)

**Rôle** : Détecter l'**escalade d'un glissement partiel du treuil M1** qui avait déjà été en partie contenu par la couche 1 (`FB_Bucket`, tolérance 1.0 m). Si même avec le `SafeStop` du benne M1 ne suffit pas à l'arrêter, cela signifie un problème mécanique grave (roue libre augmentée, surcharge).

**Armement** :
- Condition : `BenneHoldStillActive`
  - Variable câblée sur `instBucket.Busy` pour l'instance M1 **seulement**
  - Toujours `FALSE` côté M2 (qui doit continuer son mouvement normalement pendant que le benne s'ouvre/ferme)
  - → Surveillance active uniquement pendant le cycle du benne, sur M1

**Déclenchement** :
- Brique `FB_DriftGuard` : capture position de référence à l'armement ; chaque scan, calcule dérive absolue
- Si dérive M1 > 2.0 m (seuil > 1.0 m de `FB_Bucket`) → `DriftGuardC.Violation := TRUE` → bit9 levé
- Littéralement : M1 a dévié de plus de 2 mètres **malgré** l'arrêt de sécurité du benne

**Conséquence** :
- `ErrorId` bit9 levé → inclus dans masque **`SafeStop`**
- **Escalade immédiate** : aussi dans le masque **`PowerCutOff`** → coupure puissance amont

**Paramètres réglables** :
- `BenneSlipToleranceM` (défaut 2.0 m) — Tolérance d'escalade (> au seuil de `FB_Bucket` 1.0 m)

**Subtilités** :
- **Armé UNIQUEMENT côté M1** — M2 n'est jamais surveillé pour cela, car il doit tourner pendant le benne.
- Le benne (`FB_Bucket`) implémente déjà un niveau 1 de surveillance (arrêt M1 si glissement > 1.0 m) — Méca C est une couche 2 (si même ce premier niveau échoue).
- Sortie diagnostic : `MecaCDriftM` (dérive mesurée) — affichée à l'IHM pour mise en service et réglage du seuil.

---

#### Méca D — Capteur haut non confirmé arrêté (Bit11)

**Rôle** : Compléter la protection **à 3 couches** lors de l'approche du capteur haut physique (fin de course) :
1. **Couche 1** : Arrêt normal logiciel à ~12.0 m (ou dépassement autorisé en homing avec `HomingApproachEnable`).
2. **Couche 2** : `ForbidAscent` immédiat si capteur atteint (bit5, visible IHM, acquittable).
3. **Couche 3** : **Méca D** (bit11) — si malgré `ForbidAscent`, les contacteurs/frein ne confirment pas l'arrêt → défaut + `PowerCutOff`.

**Armement** :
- Condition : `(((NOT TopPositionSensor AND NOT InReferencingMode) OR (Homed AND NOT HomingSuspect AND CablePosM >= (TopLimitM + 0.10))) AND (Direction >= 0)) AND NOT (FwdRevSpeedFeedbackOff AND BrakeFeedback)`
  - **Cas 1** : Capteur physique haut atteint (`TopPositionSensor = FALSE`, contact NF ouvert), hors homing, ET montée commandée (`Direction >= 0`)
  - **OU Cas 2** : Position logicielle dépassée (`CablePosM >= TopLimitM + 0.10`) tout en étant référencé
  - **ET** : Les contacteurs/frein **ne confirment PAS** l'arrêt (`FwdRevSpeedFeedbackOff = FALSE` OU `BrakeFeedback = FALSE`)
  - Neutralisée si `Direction < 0` (descente)

**Déclenchement** :
- Timer `TonMecaD` : si la condition d'armement reste vraie pendant **3 secondes** → `TonMecaD.Q` bascule → bit11 levé

**Conséquence** :
- `ErrorId` bit11 levé → inclus dans masque **`SafeStop`**
- **Escalade immédiate** : aussi dans le masque **`PowerCutOff`** → coupure puissance amont

**Paramètres réglables** :
- `PostRampTimeout` (défaut T#3S) — Délai de confirmation (partagé avec Méca B)
- `TopLimitM` (fourni en entrée) — Limite logicielle haute (12.5 m par défaut)

**Subtilités** :
- **Deux conditions d'armement** : capteur physique OU limite logicielle redondante — défense en profondeur.
- Neutralisée en **descente** (`Direction = -1`) — pas de risque de collision vers le bas, donc pas de surveillance.
- L'alarme IHM de fin de course (bit5, `ForbidAscent`) peut être acquittée une fois la commande de montée relâchée — mais Méca D surveille le physique indépendamment.
- Timer partagé avec Méca B (`PostRampTimeout`) — le même délai s'applique.

---

#### Méca E — Écart synchro M1/M2 critique (Bits12 + Bit13 — Escalade)

**Rôle** : Détection d'une **dégradation importante de la synchronisation** entre M1 et M2 → défense en profondeur au-delà du premier niveau (`FB_WinchSync`, écart mineur).

**Armement** :
- Condition : `SyncEnable AND NOT BenneBusy AND NOT InReferencingMode`
  - Synchro activée (peut être désactivée en maintenance N2)
  - Hors cycle benne (où un écart M1/M2 est normal/volontaire)
  - Hors phase de référencement (position instable)

**Déclenchement** :

**Bit12 (Détection écart critique)** :
- Condition : `ABS(CablePosM - ExpectedOtherWinchPosM) > CriticalSyncToleranceM` (2.0 m par défaut)
  - Entrée `ExpectedOtherWinchPosM` déjà corrigée de l'offset benne actif par l'appelant — comparaison directe valable
  - Si écart > 2.0 m → bit12 immédiatement levé

**Bit13 (Escalade — pas de confirmation d'arrêt)** :
- Condition : Si bit12 est actif **ET** `NOT (FwdRevSpeedFeedbackOff AND BrakeFeedback)` pendant `PostRampTimeout` (3s)
  - Timer `TonMecaE` : si le frein/contacteurs ne confirment pas l'arrêt malgré le `SafeStop` du bit12 → bit13 levé

**Conséquence** :
- **Bit12** : `ErrorId` bit12 (16#1000) → inclus dans masque **`SafeStop`** uniquement (pas de `PowerCutOff` immédiat)
  - L'écart critique est grave, mais `SafeStop` doit suffire à arrêter les deux treuils ensemble
- **Bit13** : `ErrorId` bit13 (16#2000) → escalade : aussi dans masque **`PowerCutOff`**
  - Si même après 3s le `SafeStop` du bit12 ne suffit pas à confirmer l'arrêt, l'un des deux treuils n'a probablement pas décéléré → `PowerCutOff` amont

**Paramètres réglables** :
- `CriticalSyncToleranceM` (défaut 2.0 m) — Seuil d'écart critique
- `PostRampTimeout` (défaut T#3S) — Délai d'escalade (partagé avec Méca B/D)

**Subtilités** :
- **Deux bits coordonnés** : bit12 = alerte (SafeStop), bit13 = aggravation (PowerCutOff). Permet une IHM différenciée (warning vs alerte).
- `ExpectedOtherWinchPosM` est **déjà offset-corrigé** par l'appelant — le FB ne refait pas le calcul (règle anti-duplication).
- Suppression pendant `BenneBusy` — le benne peut créer des écarts transitoires inévitables, ce n'est pas un défaut tant qu'il bouge.
- Premier niveau (`FB_WinchSync`, écart mineur) met une alerte IHM ; cet écart critique → `SafeStop` automatique.

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
  `SimTopSensorTriggered := (CablePosM1 >= HomingTargetM1_M)`
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

## 🔁 8. Retour d'expérience

📌 Suivi (checklist de validation v1.7 non réalisée — inhibition treuils, `HomingApproachEnable`,
modèle 3 couches Méca D, Méca B étendu, diagnostics IHM, simulation capteur haut, scission
Joystick) : voir `DOC/PLAN_TASK_v1.0.md` §3 (T21).

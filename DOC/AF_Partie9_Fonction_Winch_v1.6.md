# 📋 Analyse Fonctionnelle — Partie 9 : Fonction Winch (v1.6)

> 📌 **État d'implémentation (2026-07-03, AUDIT)** : `FB_WinchSync` **codé et audité**
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
> 🆕 **v1.6 (2026-07-08)** — Retour terrain frein (demande utilisateur) : nouveau retour thermique
> **frein**, COMMUN aux 3 axes M1/M2/M3 (1 seul fil, `BrakeThermalFeedback_DI`, câblé identiquement
> sur les 2 instances `FB_Safety_Winch` **et** sur `FB_Safety_Chariot` — voir Partie11 v1.3) → bit10
> `ErrorId`. **Escalade `PowerCutOff`** : un frein est à manque de courant (colle au repos, voir
> `FB_Brake`) — la perte de ce retour peut signifier qu'un frein colle **instantanément** alors que
> le moteur est encore en mouvement ; une simple rampe `SafeStop` ne protège pas la mécanique dans
> ce cas, il faut couper la puissance immédiatement. **Même raisonnement appliqué à bit2 (surchauffe
> moteur, déjà existant depuis v1.1)** : ajouté au masque `PowerCutOff` par cohérence/défense en
> profondeur (demande explicite utilisateur). Nouveaux masques : `SafeStop = (ErrorId AND 16#079F)` /
> `16#0797` (OverrideSync), `PowerCutOff = (ErrorId AND 16#0784)` (bits 2/7/8/9/10). Détail §3/§4sexies.
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
> contenu interne était déjà en v1.3 (changelog D_SLACK_1/2/3, D_OVERRIDESYNC ci-dessous, jamais
> répercuté dans le nom de fichier — écart déjà repéré dans `DOC/PLAN_Finalisation_v1.0.md` §4.2).
> Corrigé à partir de cette version : le suffixe de fichier suit désormais fidèlement le numéro de
> version indiqué dans ce changelog.
> 🔧 **v1.3 (2026-07-04)** — Révision §4ter : comportement mou de câble revu (D_SLACK_1 : SafeStop M1+M2 en mode normal, ForbidAscent en MAINT+OverrideSync), procédure de récupération grappin bloqué (D_SLACK_2), acquittement manuel alarme IHM (D_SLACK_3), clarification capteur physiquement sur M2 uniquement, OverrideSync applicable MAINT_N1 et MAINT_N2 (D_OVERRIDESYNC).
> 🔧 **v1.2 (2026-07-03)** — Audit de sécurité et intégration du contrôle de cohérence des commandes (SafeStop sur bit 1 de `ErrorId`, bypass automatique sur Grappin actif et override MAINT_N2, avec effacement automatique des erreurs).
> 🔧 **v1.1 (2026-07-02)** — Nouvel export `Device.export` avec I/O réel : `M1/M2_RelayFwd/Rev`,
> `M1/M2_SpeedContactor_1..4` (renommé, ex `Contactor1..4`), `M1/M2_BrakeCmd`,
> `M1/M2_ContactorFeedbackFwd/Rev`, `M1_M2_TopPositionSensor` sont désormais câblés en I/O
> Mapping réel (seul `M1/M2_BrakeFeedback` reste stub). AJOUT §4ter : `ThermalFeedback` (par
> treuil) et `SlackCableDetected`/`M1_M2_SlackCableSwitch` (commun, mou de câble) dans
> `FB_Safety_Winch`, avec la nouvelle sortie dédiée `ForbidDescent` (distincte de `SafeStop`).

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

FB_Safety_Winch ──► SafeStop        ──► (entrée) FB_Winch(M1) — arrêt total (joystick/codeur/thermique moteur/thermique frein/mou câble normal/Méca A/B/C)
                ──► ForbidDescent   ──► (entrée) FB_Winch — masque UNIQUEMENT RelayRev (mou câble, MAINT+OverrideSync)
                ──► ForbidAscent    ──► (entrée) FB_Winch — masque UNIQUEMENT RelayFwd  (mou câble, MAINT+OverrideSync)
                ──► PowerCutOff 🆕  ──► (hors FB_Winch) coupure puissance amont — Méca A/B/C + thermique moteur + thermique frein (SafeStop ne suffit pas, contacteurs déjà confirmés coupés OU frein risque de coller instantanément)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_SpeedStep` | Décode `SpeedRefPct` (0..100 %) en 4 sorties `Contactor1..4`, via table `ST_SpeedStepTable` propre à M1 (paramétrage individuel `P<palier>R<relais>`), sélection par `HYSTERESIS` (lib Util, anti-battement) |
| `FB_Brake` | Séquence frein temporisée (relâche après magnétisation, collage après décélération), double vérif retour contacteur |
| `FB_Safety_Winch` | Bloc safety **métier** du domaine treuil : lève `SafeStop` sur perte joystick/CAN, perte codeur, surchauffe moteur, surchauffe/perte thermique frein 🆕, mou de câble (mode normal), ou Méca A/B/C (roue libre, pilotage sans commande, glissement grappin escaladé) ; lève `ForbidDescent`/`ForbidAscent` en MAINT+OverrideSync — voir §4ter ; lève `PowerCutOff` sur thermique moteur/frein 🆕 et Méca A/B/C — voir §4sexies |
| `FB_Winch` | Assemble les deux + arbitrage rampe `Enable > SafeStop > StartStop` + interlock sens + masquage `RelayRev`/`RelayFwd` sur `ForbidDescent`/`ForbidAscent` |

> ♻️ **Réutilisation** (Partie3 §0) : `HYSTERESIS` (lib Util) pour les paliers, `FB_Ramp` +
> `FB_CycleTime` (déjà utilisés par `FB_Joystick`) pour la rampe interne — aucune brique
> réinventée.

---

## 🔌 3. Interface

### `FB_Winch` (FB de mouvement, Partie3 §1bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | `FALSE` = neutralisation totale (sorties coupées) |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Chaîne AU réarmée + conditions globales OK |
| `Mode` | `E_Mode` | Contexte (droits arbitrés en amont, `FB_Modes` à venir) |
| `StartStop` | BOOL | `TRUE` = rampe accélération, `FALSE` = rampe décélération normale |
| `SafeStop` | BOOL | Sortie `FB_Safety_Winch` : `TRUE` = rampe décélération **rapide** (arrêt total) |
| `ForbidDescent` 🆕 | BOOL | Sortie dédiée `FB_Safety_Winch` (mou de câble) : masque **uniquement** `RelayRev` |
| `Direction` | INT | -1/0/+1 |
| `SpeedRefPct` | REAL | Consigne 0..100 % |
| `SpeedStepTable` | `ST_SpeedStepTable` | Table des 5 paliers **propre à M1** (20 `BOOL` `P<palier>R<relais>` + seuils) |
| `FwdRevSpeedFeedbackOff` 🔧 v1.4 | BOOL | Retour **unique** par treuil (I/O réel) : « tous les contacteurs sens+vitesse de ce treuil sont retombés » — remplace `ContactorFeedbackFwd/Rev` (retour individuel par sens, supprimé côté câblage réel) |
| `BrakeFeedback` | BOOL | Retour contacteur bobine frein (stub, non câblé) |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `RelayFwd` / `RelayRev` | BOOL | Contacteurs de sens (jamais simultanés — interlock ; `RelayRev` forcé `FALSE` si `ForbidDescent`) |
| `Contactor1..4` | BOOL | Contacteurs de vitesse du palier courant (lus dans `Table.P<palier>R<relais>`) |
| `BrakeCmd` | BOOL | Commande bobine frein (`TRUE` = relâché) |
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | État standard (Partie3 §1) |
| `ContactorsCheck/BrakeContactorCheck` 🔧 v1.4 | `ST_ContactorCheck` | Diagnostic détaillé (IHM) — `ContactorsCheck` fusionne l'ancien `FwdContactorCheck`+`RevContactorCheck` (un seul retour matériel désormais, plus de diagnostic par sens) ; `BrakeContactorCheck` inchangé |

`ErrorId` : bit0 = défaut frein, bit1 = contacteur(s) sens/vitesse collé(s) (🔧 v1.4 : `ContactorsCheck.StuckClosed`, vérifié **uniquement à l'arrêt commandé** — plus de détection par sens), bit2 **libre/inutilisé** (🔧 v1.4, ex-contacteur sens Rev, fusionné dans bit1). `ContactorsCheck.StuckOpen` reste toujours `FALSE` (non détectable avec ce retour unique, champ conservé pour compatibilité de type `ST_ContactorCheck`).

### `FB_Safety_Winch` (1 instance par treuil, Partie3 §1/§7bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable`/`Reset`/`EmergencyStopOk`/`Mode` | — | Contrat standard (Partie3 §1) |
| `JoystickOnline`/`JoystickOperational` | BOOL | `instDiagCanOpen.Joystick` |
| `EncoderAvailable` | BOOL | Sortie `FB_Encoder_Abs` **de ce treuil** |
| `ThermalFeedback` | BOOL | Retour TOR thermique **de ce moteur** (`M1/M2_ThermalFeedback`, I/O réel) |
| `BrakeThermalFeedback` 🆕 v1.6 | BOOL | Retour TOR thermique **frein**, COMMUN aux 3 axes M1/M2/M3 (`BrakeThermalFeedback_DI`, 1 seul fil, câblé IDENTIQUEMENT sur les 2 instances Winch **et** l'instance Chariot — voir Partie11 v1.3) : `TRUE` = surchauffe/perte |
| `SlackCableDetected` | BOOL | Détecteur mou de câble **commun** aux 2 treuils (`M1_M2_SlackCableSwitch`, I/O réel — même valeur sur les 2 instances) |
| `CablePosM` | REAL | Position câble **de ce treuil** en mètres (scalée) — réutilisée pour Méca A/C (dérive/vitesse) |
| `CableLimitDescentM` | REAL | Limite basse physique descente (m, valeur négative) |
| `FwdRevSpeedFeedbackOff` 🆕 v1.5 | BOOL | Retour unique « tous contacteurs sens+vitesse retombés » **de ce treuil** (déjà consommé par `FB_Winch`, désormais aussi par `FB_Safety_Winch` pour armer Méca A/B) |
| `BrakeFeedback` 🆕 v1.5 | BOOL | Retour frein **de ce treuil** (I/O réel, `M1/M2_BrakeFeedback`) : `TRUE` = serré/collé — arme Méca A conjointement avec `FwdRevSpeedFeedbackOff` |
| `JoystickYNeutral` 🆕 v1.5 | BOOL | `TRUE` = joystick axe Y au neutre (magnitude `ABS(SpeedRef) < 0.1`), précalculé en amont (`PRG_03_Safety`) — Méca B |
| `GrappinHoldStillActive` 🆕 v1.5 | BOOL | `TRUE` **uniquement pour l'instance M1**, câblé sur `instGrappin.Busy` (toujours `FALSE` côté M2, qui doit bouger pendant le grappin) — arme Méca C (couche 2) |
| `UncommandedSpeedThresholdMps` 🆕 v1.5 | REAL := 0.02 | Seuil vitesse mesurée (m/s) au-delà duquel Méca A se déclenche pendant qu'il est armé — théorique, à ajuster sur site |
| `UncommandedDriftToleranceM` 🆕 v1.5 | REAL := 2.0 | Tolérance de dérive de position (m) par rapport à la référence prise à l'armement de Méca A |
| `PostRampTimeout` 🆕 v1.5 | TIME := T#3S | Délai laissé après perte de commande opérateur pour que `FwdRevSpeedFeedbackOff` reconfirme l'arrêt réel (Méca B) — marge au-dessus du temps de décélération réel, théorique |
| `GrappinSlipToleranceM` 🆕 v1.5 | REAL := 2.0 | Tolérance de dérive M1 (m) pour l'escalade Méca C — volontairement **supérieure** aux 1.0 m déjà surveillés côté `FB_Grappin` (couche 1, voir Partie12 v1.2) : n'intervient que si cette couche 1 n'a pas suffi |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/State/StateAtError` | — | Contrat standard |
| `ErrorId` | WORD | bit0 : perte joystick/CAN ; bit1 : perte codeur ; bit2 : surchauffe moteur (**SafeStop+PowerCutOff 🆕 v1.6**) ; bit3 : mou de câble ; bit4 : rotation de phase ; bit5 : fin de course haut ; bit6 : longueur max câble ; bit7 : Méca A (mouvement non commandé) ; bit8 : Méca B (pilotage sans commande opérateur) ; bit9 : Méca C couche 2 (glissement M1/grappin, escalade) ; bit10 🆕 v1.6 : surchauffe/perte thermique frein commun M1/M2/M3 (SafeStop+PowerCutOff) |
| `SafeStop` | BOOL | 🔧 v1.6 : `(ErrorId AND 16#079F) <> 0` hors OverrideSync (bits 0/1/2/3/4/7/8/9/10), `(ErrorId AND 16#0797) <> 0` sous OverrideSync (bit3 exclu, comme avant — voir §4ter). Les bits 7/8/9/10 **ne sont jamais exclus** par `OverrideSync`, sans rapport avec la procédure de récupération mou de câble |
| `ForbidDescent` | BOOL | bit6 uniquement (limite basse câble) — inchangé |
| `ForbidAscent` | BOOL | bit5 (fin de course haut) OU bit3+OverrideSync (récupération mou câble) — inchangé |
| `PowerCutOff` 🔧 v1.6 | BOOL | `(ErrorId AND 16#0784) <> 0` — bits 2 (surchauffe moteur 🆕), 7/8/9 (Méca A/B/C), 10 (surchauffe/perte thermique frein 🆕). Coupure puissance amont : dans ces cas, les contacteurs locaux sont déjà confirmés coupés/insuffisants OU le frein risque de coller instantanément — `SafeStop` seul ne suffit pas |

---

## 🛡️ 4. Sécurité

- **Précédence stricte** `Enable > SafeStop > StartStop` (arbitrage rampe interne à `FB_Winch`,
  indépendant de la rampe déjà appliquée par `FB_Joystick` sur la consigne).
- **Interlock changement de sens** : `RelayFwd`/`RelayRev` ne sont jamais actifs simultanément ;
  **seul l'engagement initial** neutre→un sens est immédiat — un arrêt (un sens→neutre) **et**
  une inversion directe Fwd↔Rev exigent tous les deux la vitesse rampée confirmée nulle
  (`DirectionInterlockDelay`), pour que le contacteur de sens reste actif tout le temps de la
  décélération réelle (cohérent avec le palier et le frein).
- **Arrêt forcé et déterministe pendant un changement de sens en attente** : dès que
  `Direction ≠ CommandedDirection` (hors 1er engagement), la cible de rampe est **forcée à 0**
  — indépendamment de ce que redemande le joystick entre-temps — pour garantir un arrêt réel,
  même en cas d'inversion plus rapide que le temps de décélération.
- **Frein** : séquence temporisée stricte (Partie4 §4) — jamais de relâche avant fermeture
  contacteur + magnétisation, jamais de collage avant décélération.
- **Double vérification contacteurs** (sens + frein) via `ST_ContactorCheck` : incohérence
  commande/retour au-delà d'un timeout → `ErrorId`.
- **Sortie sûre sur défaut** (`FB_Winch`/`FB_Brake`) : `Error` force `RelayFwd`/`RelayRev`/
  `Contactor1..4`/`BrakeCmd` à leur état sûr (coupure directe, frein collé), conforme Partie3
  §9 étape 7 — un contacteur incohérent ne doit plus jamais rester commandé normalement.

### 🆕 4ter. Surchauffe moteur + mou de câble — **RÉVISÉ v1.3** (D_SLACK_1/D_SLACK_2/D_SLACK_3)

Le nouvel export `Device.export` câble deux nouveaux retours safety-critiques :

**Surchauffe moteur (`M1/M2_ThermalFeedback`, par treuil)** — traitement classique : nouveau
bit `ErrorId` (bit2) dans `FB_Safety_Winch`, participe au calcul de `SafeStop` **au même titre**
que la perte joystick/codeur → arrêt total des 2 sens, `Enable` maintenu (rampe rapide).
🔧 **v1.6** : participe désormais **aussi** au calcul de `PowerCutOff` — voir §4sexies.
* **Câblage physique** : Contacts Normally Closed (NC), donc sains à `1` (TRUE) et en défaut/ouvert à `0` (FALSE).
* **Reset** : Front standard (Partie3 §5) dès que le retour physique repasse à `TRUE` (sain). L'automate utilise l'inversion `NOT GVL_IN.M1ThermalFeedback` (pour M1) ou `NOT GVL_IN.M2ThermalFeedback` (pour M2) pour la logique de défaut.

#### 🔴 Mou de câble — comportement revu (D_SLACK_1, 2026-07-04)

**Emplacement physique du capteur** : `M1_M2_SlackCableSwitch` est câblé **uniquement sur le
tambour du treuil M2** (grappin). Le même signal est distribué aux deux instances
`FB_Safety_Winch` par convention de nommage, mais la cause physique est exclusivement côté M2.

**Scénario terrain (revu)** : lors d'une remontée, si le grappin se ferme mal (pince un câblot,
objet), il peut se bloquer partiellement — le tambour M2 continue d'enrouler alors que le câble
ne monte pas vraiment → du mou se forme sur le tambour M2. Ce scénario survient **en montée**
(contrairement au scénario descente documenté v1.1).

**Comportement selon le mode** :

| Mode | OverrideSync | Comportement mou de câble (`SlackCableDetected = TRUE`) |
|------|-------------|----------------------------------------------------------|
| NORMAL / SEMI_AUTO / MAINT_N1 | N/A | **SafeStop M1 + M2** — rampe rapide, arrêt total des 2 sens + **alarme IHM acquittable** (pattern Partie3 §5) |
| MAINT_N1 ou MAINT_N2 | ✅ OverrideSync activé | SafeStop câble **levé** — `ForbidAscent` (montée interdite M1 ET M2) + descente autorisée (pour rattraper le câble) |

```
// Mode NORMAL/SEMI_AUTO/MAINT sans OverrideSync :
ErrorId.bit3  := SlackCableDetected
SafeStop      := (ErrorId AND 16#079F) <> 0    // 🔧 v1.6 : bits 0/1/2/3/4/7/8/9/10 → arrêt total
ForbidDescent := FALSE                          // inutile, SafeStop bloque tout
ForbidAscent  := FALSE                          // inutile, SafeStop bloque tout

// Mode MAINT avec OverrideSync activé :
ErrorId.bit3  := SlackCableDetected
SafeStop      := (ErrorId AND 16#0797) <> 0    // 🔧 v1.6 : bits 0/1/2/4/7/8/9/10 — bit3 SEUL exclu
ForbidDescent := FALSE                          // descente autorisée pour rattraper le câble
ForbidAscent  := (ErrorId AND 16#0008) <> 0    // bit3 → montée interdite M1 ET M2

// Dans FB_Winch (appliqué sur les 2 instances M1 et M2) :
RelayFwd forcé FALSE si ForbidAscent   // bloque la montée
RelayRev forcé FALSE si ForbidDescent  // bloque la descente (+ EffectiveSafeStop si SafeStop)
```

> 🔧 **v1.6** : bit10 (thermique frein commun) suit exactement le même traitement que les bits
> 7/8/9 (Méca A/B/C) — jamais exclu par `OverrideSync`, sans rapport avec la procédure de
> récupération mou de câble.

`Error` reste le miroir de **tout** `ErrorId` (Partie3 §4, y compris bit3) : le défaut est
visible à l'IHM comme **alarme acquittable** — voir §4ter-D_SLACK_3 ci-dessous.

> 🧭 La logique direction-dépendante (`ForbidAscent`/`ForbidDescent`) est appliquée côté
> `FB_Winch` (seul FB qui connaît `CommandedDirection`), pas côté `FB_Safety_Winch`
> (qui ne doit pas connaître le sens de mouvement) — cohérent avec le pattern établi en D72b.

#### 🔧 Procédure de récupération — grappin bloqué (D_SLACK_2, 2026-07-04)

Quand un mou de câble survient en SEMI_AUTO :
- Le `SafeStop` se déclenche sur M1 et M2 → le cycle SEMI_AUTO se **suspend** (reste en mémoire,
  non réinitialisé) ;
- L'opérateur **doit** quitter vers MAINT_N1 ou MAINT_N2 pour intervenir ;
- La réouverture du grappin est **MANUELLE depuis l'IHM** (bouton `CmdOpen` sur `FB_Grappin`) ;
- L'opérateur a deux options :
  1. Utiliser d'autres axes (chariot…) → quitte le mode de récupération → **perd la mémoire du cycle** ;
  2. Acquitter l'alarme seule (`Reset` IHM) → le cycle peut reprendre là où il s'est arrêté.

**Séquence typique de récupération** :

```
a. Passer en MAINT_N2 + activer OverrideSync (IHM)
b. Redescendre M2 (tambour) pour rattraper le câble sur le tambour
c. Si grappin vraiment bloqué mécaniquement : redescendre M1 aussi (dégagement)
d. Ouvrir manuellement le grappin (bouton CmdOpen IHM → FB_Grappin)
e. Remonter en position connue (M1 + M2 indépendants sous OverrideSync)
f. Désactiver OverrideSync → revenir en MAINT_N1
g. Acquitter l'alarme mou de câble via IHM (Reset front + cause disparue)
h. Valider la reprise du cycle SEMI_AUTO si souhaité
```

> ⚠️ En mode MAINT_N2 + OverrideSync : l'opérateur pilote M1 et M2 **indépendamment**, sans
> contrôle d'écart de position ni synchronisation. `ForbidAscent` empêche toute montée tant que
> `SlackCableDetected = TRUE` (le mou n'est pas rattrapé). La descente reste libre pour
> enrouler le câble correctement sur le tambour.

#### 🔔 Acquittement des alarmes mou de câble (D_SLACK_3, 2026-07-04)

- Les défauts mou de câble (bit3 `ErrorId`) sont exposés comme **alarmes sur l'IHM** via la
  sortie `Error` du FB (Partie3 §4) ;
- Acquittement **Manuel obligatoire** : l'opérateur doit explicitement appuyer sur le bouton
  Reset de l'IHM ;
- **Condition d'acquittement** : cause réelle disparue (`GVL_IN.SlackCableSwitch = TRUE` à
  nouveau) **ET** appui Reset (front montant) ;
- Pattern standard **Partie3 §5** (front Reset + cause disparue) — identique à tous les autres
  défauts du domaine treuil.

> ⚠️ **Pas de reset automatique** : même si le câble se rattrape physiquement (capteur revenu
> à TRUE), l'opérateur doit valider explicitement que la situation est correcte avant que le
> mouvement ne reprenne. Un `SafeStop` résiduel ne s'efface jamais seul.

> 🔧 **Correctifs retour terrain + revue de code 2026-07-01** (2 itérations) :
> 1. La 1ère version de l'interlock exigeait la vitesse confirmée nulle (200 ms) **avant même
>    le tout premier engagement** (neutre → un sens) — or la rampe interne quitte le seuil de
>    repos en ~2 ms dès qu'une consigne existe (`AccelRate` 50 %/s), donc `CommandedDirection`
>    restait bloqué à 0 en permanence : les paliers de vitesse évoluaient (`Contactor1..4`),
>    mais aucun `RelayFwd`/`RelayRev` ne s'activait jamais (symptôme observé : "les relais
>    vitesse évoluent mais pas de commande de sens").
> 2. Le correctif 1 traitait ensuite "un sens → neutre" comme immédiat lui aussi — or
>    `Contactor1..4` suit une rampe indépendante (`SpeedRamp.Current`) : un arrêt demandé
>    coupait le contacteur de sens **avant** la fin de la décélération réelle, frein encore
>    ouvert (non conforme Partie3 §9). Corrigé dans `CODE/FB_Winch.st` §3bis (revue de code
>    indépendante) : seul l'engagement initial est immédiat, arrêt et inversion directe
>    exigent tous les deux la vitesse confirmée nulle.
> 3. Ajout de la sortie sûre sur `Error` (ci-dessus), absente des deux versions précédentes.
> 4. **(2026-07-02)** Les correctifs 1/2 supposaient que `ABS(SpeedRamp.Current)` finirait par
>    croiser le seuil 0,1 % naturellement en suivant la magnitude joystick — faux en cas
>    d'inversion **plus rapide que le temps de décélération réel** : la magnitude peut sauter
>    par-dessus la fenêtre de détection (deux rampes en cascade, pas discrets) sans jamais y
>    entrer, laissant le treuil tourner indéfiniment dans l'ancien sens tant que l'opérateur ne
>    laisse pas le joystick se stabiliser. Corrigé dans `CODE/FB_Winch.st` §3 : la cible de
>    rampe est désormais **forcée à 0.0** dès qu'un changement de sens est en attente
>    (`DirectionChangePending`), garantissant un arrêt réel et déterministe, indépendant du
>    signal joystick.

> 🔧 **Correctif `FB_Ramp` (retour terrain 2026-07-02)** : lors d'une inversion **rapide** du
> joystick, `FB_Ramp` (utilisé par `RampX`/`RampY` dans `FB_Joystick`) sélectionnait à tort le
> taux d'**accélération** (lent) au lieu de **décélération** (rapide) pour la portion du trajet
> qui revient vers zéro — la comparaison se faisait sur le signe brut de `Target`/`Current`, pas
> sur le côté de zéro où se trouve `Current`. Conséquence en cascade : `AxisCmdY.Direction`
> restait "collé" sur l'ancien sens ~3× plus longtemps que nécessaire lors d'un flick rapide, ce
> qui retardait d'autant l'interlock de sens de `FB_Winch` (symptôme : "les contacteurs Fwd/Rev
> restent bloqués sur l'ancien sens" après une inversion rapide). Corrigé dans `CODE/FB_Ramp.st`
> (nouveau fichier — `FB_Ramp` existait déjà dans le projet mais n'était pas encore extrait dans
> `CODE/`). **Analyse d'impact avant correctif** : `FB_Ramp` n'est instancié que 3 fois au total
> (`RampX`/`RampY` dans `FB_Joystick`, cible signée → concernées ; `SpeedRamp` dans `FB_Winch`,
> cible toujours `>= 0` → **jamais** concernée, comportement inchangé pour `FB_Winch`).
### 🆕 4quater. Contrôle de cohérence des commandes (2026-07-03)

Afin d'éviter tout dommage mécanique majeur (déchirement du câble, torsion de l'arbre) ou une chute de charge en cas de comportement divergent des deux treuils M1 et M2, un contrôle de cohérence des commandes est intégré dans `FB_WinchSync` :

- **Principe de détection** :
  Le bloc compare en temps réel les consignes de mouvement envoyées aux contacteurs physiques des deux moteurs :
  - Sens de marche : `RelayFwdM1` vs `RelayFwdM2` et `RelayRevM1` vs `RelayRevM2`.
  - Paliers de vitesse engagés : `Contactor1..4_M1` vs `Contactor1..4_M2`.
  Si une discordance est détectée alors que la surveillance de synchronisation est active (`SyncActive = TRUE`), un filtre temporel anti-rebond de **500 ms** (`MismatchTimer`) est lancé pour éviter les déclenchements intempestifs durant les phases transitoires (rampes de vitesse ou commutations).
  
- **Traitement du défaut** :
  - **Bit de défaut** : `ErrorId` bit 1 (16#0002) dans `FB_WinchSync`.
  - **Action de sécurité** : Ce défaut étant critique, il entraîne un **`SafeStop`** immédiat (décélération rapide et serrage des freins) sur les deux treuils M1 et M2 par le câblage suivant dans `PRG_MAIN` :
    `SafeStop := instSafetyWinchM1/M2.SafeStop OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)`.
  - *Remarque sur l'écart de position (bit 0)* : L'écart hors tolérance de position (`ErrorId` bit 0, 16#0001) reste quant à lui un simple avertissement IHM (`SyncWarn = Error` pour affichage) et ne doit pas couper le mouvement (`SafeStop` non activé par ce bit).

- **Conditions d'activation et de Bypass** :
  - **MAINT_N1 / MANUEL / SEMI_AUTO** : La surveillance est active par défaut (`SyncActive = TRUE`).
  - **MAINT_N2 (Override Sync)** : L'opérateur peut désactiver temporairement la surveillance en cochant `OverrideSync` à l'IHM, ce qui désactive le bloc `FB_WinchSync` (`Enable := FALSE`) et efface immédiatement son défaut.
  - **Mouvement Grappin** : Lorsque le grappin est en mouvement (`Grappin.Busy = TRUE`), le treuil M2 fonctionne de manière indépendante pour ouvrir/fermer le grappin. Le contrôle de cohérence des commandes est alors automatiquement désactivé en forçant `FB_WinchSync.Enable := FALSE` dans `PRG_MAIN`.
  - **Effacement automatique sur désactivation** : Lorsque `Enable` passe à `FALSE`, le bloc `FB_WinchSync` remet à zéro ses sorties `Error` (à `FALSE`) et `ErrorId` (à `16#0000`) afin de ne pas verrouiller le système en `SafeStop` pendant un bypass ou l'utilisation du grappin.

### 🆕 4quinquies. Méca A/B/C — Garde-fous mouvement non commandé (2026-07-07, IMPLÉMENTÉS)

> ✅ Statut : **implémentés et câblés** dans `FB_Safety_Winch` (bits 7/8/9) + `FB_Grappin` (bit4),
> suite à la consolidation du retour contacteur unique par treuil (`FwdRevSpeedFeedbackOff`,
> v1.4). Couvrent le **Cas B** identifié ci-dessous (« mouvement non commandé / roue libre ») et
> son cas particulier propre au Grappin. Les Cas A et C (originaux, ci-dessous) restent **TBD**.

**Méca A — mouvement non commandé général (`FB_Safety_Winch` bit7)**
Armé dès que `FwdRevSpeedFeedbackOff AND BrakeFeedback` (tout est confirmé physiquement coupé :
contacteurs de sens/vitesse **et** frein serré). Une fois armé, si la vitesse mesurée (voir TBD
mesure vitesse ci-dessous) dépasse `UncommandedSpeedThresholdMps` (0.02 m/s, théorique) **ou** si
la position dérive de plus de `UncommandedDriftToleranceM` (2.0 m) par rapport à la référence
prise au moment de l'armement → défaut → `SafeStop` **et** `PowerCutOff`. `PowerCutOff` est
nécessaire ici car les contacteurs sont déjà confirmés coupés : `SafeStop` seul (qui ne fait que
commander une décélération rapide) ne changerait rien à une charge en roue libre.

**Méca B — pilotage actif malgré absence de commande opérateur (`FB_Safety_Winch` bit8)**
Indépendant de la logique interne de `FB_Winch` — défense en profondeur : reste valable même si
l'arbitrage `FB_Winch` est lui-même en défaut. Si (perte communication CAN joystick, déjà bit0
existant) **ou** (joystick axe Y au neutre, `JoystickYNeutral`, seuil `ABS(SpeedRef) < 0.1`) **et**
que `FwdRevSpeedFeedbackOff` ne repasse **pas** à `TRUE` dans `PostRampTimeout` (3 s, théorique —
marge au-dessus du temps de décélération réel) → défaut → `SafeStop` **et** `PowerCutOff`.

**Méca C — glissement M1 pendant mouvement Grappin, à 2 couches**
Pendant l'ouverture/fermeture du grappin (M2 bouge seul, M1 doit rester immobile) :
- **Couche 1** (`FB_Grappin` bit4, tolérance `M1SlipToleranceM` = 1.0 m) : si M1 dérive de plus
  d'1 m par rapport à sa position mémorisée à l'entrée en `Busy` → `SevereError` (coupe M2 via le
  mécanisme existant) + nouvelle sortie `M1SlipDetected`, consommée dans `PRG_06_WinchControl.st`
  (OR'ée dans `SafeStopM1_Raw` pour forcer `SafeStop` sur M1 spécifiquement — `FB_Grappin` ne
  pilote pas M1 directement). Détail interface : Partie12 v1.2 §4.
- **Couche 2** (`FB_Safety_Winch` bit9, tolérance `GrappinSlipToleranceM` = 2.0 m > tolérance
  couche 1) : armée **uniquement** via `GrappinHoldStillActive`, câblée sur `instGrappin.Busy`
  pour l'instance **M1 seule** (toujours `FALSE` côté M2, qui doit bouger pendant le grappin). Si
  la dérive continue au-delà de 2.0 m malgré la couche 1 → escalade `PowerCutOff` (dernier
  recours, la couche 1 n'a pas suffi).

> 📄 Code de référence (règle anti-doublon, pas de recopie ici) : `CODE/WINCH/FB_Safety_Winch.st`
> (Méca A/B/C, bits 7/8/9), `CODE/GRAPPIN/FB_Grappin.st` (Méca C couche 1, bit4),
> `CODE/MAIN/PRG_03_Safety.st` (câblage des nouvelles entrées), `CODE/MAIN/PRG_06_WinchControl.st`
> (consommation de `M1SlipDetected`).

#### 🔴 TBD — Mesure de vitesse par différentiation logicielle (amélioration future)

La mesure de vitesse utilisée par Méca A est aujourd'hui une **différentiation logicielle** de
`CablePosM` (delta position / temps de cycle réel via `FB_CycleTime`), **pas** un mot vitesse
natif du codeur. Or les PDO EtherCAT fournissent bien un mot vitesse natif (`COD1_SpdValue` /
`COD2_SpdValue`, mappé `%IW10` côté COD1, « Speed value channel 1 »), jamais consommé dans
`CODE/` à ce jour, qui serait probablement plus fiable/moins bruité que la différentiation sur un
seul cycle (10 ms). **Mais l'échelle/unité de ce mot n'est pas connue** (points/seconde ? tr/min ?
autre ?) — à déterminer via la fiche technique du codeur Kübler F58x8 ou empiriquement sur site.
Amélioration prévue pour une phase projet plus avancée : utiliser `COD1_SpdValue`/`COD2_SpdValue`
quand `EncoderM1/M2_IsReal = TRUE`, garder la différentiation logicielle comme repli en
simulation (même principe que l'aiguillage `M1_RawPosToUse` déjà en place pour la position,
Partie10 v1.7).

### 🔴 TBD — Surveillance de cohérence mouvement, Cas A et C originaux (2026-07-02, PAS implémentés)

> ⚠️ Statut : **idée capturée, non conçue en détail, non implémentée.** Le Cas B ci-dessous est
> désormais couvert par Méca A/B/C ci-dessus (§4quinquies) — restent non traités : Cas A (sens
> opposé) et Cas C (absence de mouvement malgré commande). Ne pas commencer l'implémentation sans
> repasser par le workflow complet (spec → plan → validation) le moment venu.

Piste de sécurité identifiée pendant les tests : au-delà du contrôle **commande vs retour d'un
même contacteur** déjà fait par `ST_ContactorCheck` (Partie3 §7bis, existant dans `FB_Winch`),
il manque un contrôle de cohérence de plus haut niveau entre **l'intention opérateur**,
**ce que la machine commande**, et **ce qu'elle fait réellement**. Ce sont 3 signaux distincts
qui devraient normalement toujours converger (à un délai de rampe/interlock près), et 4 cas de
divergence à couvrir séparément — ce ne sont pas des variantes d'un même défaut, chacun a une
cause probable et une gravité différentes :

| Cas | Divergence observée | Cause probable | Gravité | Statut |
|-----|----------------------|-----------------|---------|--------|
| **A — Sens opposé** | Sens joystick **brut** (avant deadband/filtre/rampe, donc l'intention quasi instantanée) ≠ sens réellement constaté (contacteur engagé et/ou signe vitesse codeur), de façon **persistante** | Câblage de sens inversé, contacteur collé dans le mauvais sens, codeur mal orienté (signe inversé à la config) | Élevée — la machine bouge à l'opposé de la demande opérateur | 🔴 TBD |
| **B — Mouvement non commandé (roue libre)** | Le codeur indique un déplacement significatif alors qu'**aucun** contacteur de sens n'est engagé (`RelayFwd`/`RelayRev` = FALSE tous les deux) | Charge qui tombe (frein qui ne tient pas malgré `BrakeCmd=FALSE`), roue libre mécanique | **Très élevée** — mouvement incontrôlé | ✅ **Implémenté** — voir Méca A/B §4quinquies |
| **C — Absence de mouvement malgré commande** | Sens + palier commandés, frein relâché **confirmé** (`BrakeCmd=TRUE` et `BrakeContactorCheck` cohérent), mais le codeur ne montre **aucune** évolution de position après un délai raisonnable | Blocage mécanique, accouplement/câble rompu, contacteur de puissance qui ne répond pas malgré un retour TOR correct (défaut invisible à `ST_ContactorCheck`, qui ne voit que la bobine de commande, pas l'arbre moteur) | Élevée — aucune action physique alors que tout semble commandé correctement | 🔴 TBD |
| **D — Fenêtre de tolérance** | *(pas un cas de défaut, une règle transverse aux cas ci-dessus)* Ne jamais déclencher pendant le temps normal de rampe + interlock (~0,5 à 1 s selon les taux réglés, voir §4) | — | — évite les faux positifs à chaque changement de sens/palier normal | — |

> ⚠️ Le « Méca C » du §4quinquies (glissement M1/grappin) est un cas **distinct** de ce tableau
> (spécifique au grappin, pas une variante générique du Cas A/B/C ci-dessus) — ne pas confondre.

**Sources de données nécessaires pour les Cas A et C restants** (aucune encore remontée jusqu'à
`FB_Safety_Winch`) :
- Sens joystick **brut** (avant traitement) — actuellement `FB_Safety_Winch` ne voit que
  `Joystick.Online`/`Operational`, pas `RawX`/`RawY` ni un signe brut dérivé.
- Signe + magnitude de la vitesse codeur (Cas A, C) — la différentiation logicielle existe
  désormais (Méca A), mais reste TBD un mot vitesse natif fiable (voir TBD ci-dessus).
- `RelayFwd`/`RelayRev`/`BrakeCmd` de `FB_Winch` (Cas C) — déjà disponibles en sortie de
  `FB_Winch`, juste pas encore câblés vers `FB_Safety_Winch`.

Chaque cas incohérent → un bit `ErrorId` **distinct** dans `FB_Safety_Winch` (1 bit = 1 cause,
Partie3 §3), pas un bit générique "incohérence". Note miroir (condensée) laissée dans
`CODE/WINCH/FB_Safety_Winch.st` (en-tête).

### 🆕 4sexies. Thermique frein commun + escalade PowerCutOff moteur/frein (2026-07-08)

> ✅ Statut : **implémenté et câblé** dans `FB_Safety_Winch` (bit10) et `FB_Safety_Chariot`
> (bit3, voir Partie11 v1.3) — demande utilisateur directe, retour terrain frein.

**Contexte** : le frein de chaque axe (M1/M2/M3) est **à manque de courant** — il colle au
repos par construction (sécurité positive, voir `FB_Brake`). Un nouveau retour thermique
**commun aux 3 freins** (`BrakeThermalFeedback_DI`, 1 seul fil — impossible de distinguer lequel
des 3 axes est en cause) est câblé sur `PRG_00_Inputs.BrakeThermalFeedback`, puis distribué
identiquement aux 3 instances Safety (`instSafetyWinchM1`/`M2`, `instSafetyChariotM3`).

**Raisonnement sécurité (demande utilisateur)** : la perte de ce retour (surchauffe réelle OU
fil coupé — indiscernable par construction NC, comme tous les capteurs de la famille "sécurité")
peut signifier qu'un frein colle **instantanément** alors que l'axe concerné est encore en
mouvement/sous couple. Une simple rampe de décélération (`SafeStop`) ne protège pas la mécanique
dans ce cas précis : il faut couper la puissance **immédiatement** (`PowerCutOff`), comme pour
Méca A/B/C ci-dessus (§4quinquies) — les 3 axes sont coupés simultanément puisque le signal ne
permet pas d'isoler lequel est réellement en cause.

**Extension à la surchauffe moteur (bit2, déjà existante depuis v1.1)** : par cohérence et
défense en profondeur (demande explicite utilisateur), la perte du retour thermique **moteur**
M1/M2 (bit2) est désormais **également** ajoutée au masque `PowerCutOff`, alors qu'elle ne
déclenchait auparavant que `SafeStop`.

```
// Nouveaux masques FB_Safety_Winch (remplacent ceux de v1.5) :
SafeStop    := (ErrorId AND 16#079F) <> 0   // hors OverrideSync : bits 0/1/2/3/4/7/8/9/10
SafeStop    := (ErrorId AND 16#0797) <> 0   // sous OverrideSync : bit3 seul exclu
PowerCutOff := (ErrorId AND 16#0784) <> 0   // bits 2/7/8/9/10
```

> 📄 Code de référence (règle anti-doublon) : `CODE/WINCH/FB_Safety_Winch.st` (bit10, masques),
> `CODE/CHARIOT/FB_Safety_Chariot.st` (bit3, voir Partie11 v1.3), `CODE/MAIN/PRG_00_Inputs.st`
> (acquisition commune), `CODE/MAIN/PRG_03_Safety.st` (distribution aux 3 instances),
> `CODE/SUPERVISION/ST_WinchHMI.st`/`ST_ChariotHMI.st` + `CODE/MAIN/PRG_09_Supervision.st`
> (remontée IHM `BrakeThermalFault`, demande utilisateur explicite).

### ⚠️ Ce que « pas de codeur » signifie concrètement pour ce lot

`FB_Winch` **ne consomme pas** le codeur directement (il n'en a jamais eu besoin — c'est
`FB_WinchSync`/`FB_Encoder_Safety`, absents de ce lot, qui l'utilisent). `FB_Safety_Winch`
couvre **uniquement** la perte joystick/CAN pour ce lot ; la perte codeur/EtherCAT M1 est
**explicitement non câblée** (pas de stub simulé) — voir `CODE/FB_Safety_Winch.st`.

Conséquence assumée (validée avec l'utilisateur) : **aucune limite de fin de course logicielle**
tant que le codeur n'est pas fiabilisé. En Maintenance N1, le pilotage reste **unitaire** et
**revalidé en continu par le joystick (homme-mort)** : relâcher le joystick arrête le mouvement
via la rampe. Ne pas utiliser cette chaîne au-delà de la vigilance opérateur directe (pas de
descente sans surveillance visuelle des fins de câble physiques).

---

## 🗺️ 5. Mapping E/S

| Variable (code) | Sens | Statut | Rôle |
|------------------|------|--------|------|
| `M1/M2_RelayFwd` | Sortie | 📡 I/O réel | Contacteur sens avant (montée) |
| `M1/M2_RelayRev` | Sortie | 📡 I/O réel | Contacteur sens arrière (descente) |
| `M1/M2_SpeedContactor_1..4` | Sortie | 📡 I/O réel | Contacteurs de vitesse (palier courant, table `P<palier>R<relais>`) — 🔧 renommé (ex `Contactor1..4`) |
| `M1/M2_BrakeCmd` | Sortie | 📡 I/O réel | Bobine frein (`TRUE` = relâché) |
| `M1/M2_FwdRevSpeedFeedbackOff` 🔧 v1.4 | Entrée | 📡 I/O réel | Retour **unique** « tous contacteurs sens+vitesse retombés » — câblé sur `M1/M2_FwdRevSpeedFeedbackOff_DI` (remplace `M1/M2_ContactorFeedbackFwd/Rev`, 4 canaux `M1/M2_FeedbackFwd/Rev_DI` retirés). 🆕 v1.5 : consommé aussi par `FB_Safety_Winch` (arme Méca A/B) |
| `M1/M2_BrakeFeedback` 🔧 v1.5 | Entrée | 📡 I/O réel | Retour contacteur bobine frein — câblé sur `M1/M2_BrakeFeedback_DI` (n'est plus un stub, contrairement à la mention v1.1). 🆕 v1.5 : consommé aussi par `FB_Safety_Winch` (arme Méca A conjointement avec `FwdRevSpeedFeedbackOff`) |
| `M1_M2_TopPositionSensor` 🆕 | Entrée | 📡 I/O réel | Capteur position haute, **commun** M1+M2 (remplace `GVL_Homing_Stub`, supprimé) |
| `M1/M2_ThermalFeedback` 🆕 | Entrée | 📡 I/O réel | Retour thermique **de ce moteur** → `FB_Safety_Winch.ThermalFeedback` |
| `M1_M2_SlackCableSwitch` 🆕 | Entrée | 📡 I/O réel | Détecteur mou de câble, **commun** M1+M2 → `FB_Safety_Winch.SlackCableDetected` (même valeur sur les 2 instances) |
| `BrakeThermalFeedback_DI` 🆕 v1.6 | Entrée | 🧪 À câbler (mapping physique restant) | Retour thermique **frein**, **commun aux 3 axes** M1/M2/M3 (1 seul fil) → `PRG_00_Inputs.BrakeThermalFeedback` → `FB_Safety_Winch.BrakeThermalFeedback` (les 2 instances) + `FB_Safety_Chariot.BrakeThermalFeedback` — voir Partie11 v1.3 |

> 🔧 **v1.5** : `JoystickYNeutral` (Méca B) et `GrappinHoldStillActive` (Méca C couche 2) ne sont
> **pas** des canaux I/O physiques — ce sont des signaux **précalculés** dans `PRG_03_Safety`
> (`ABS(FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1`, respectivement `instGrappin.Busy` câblé sur
> l'instance M1 seule) avant d'être passés en entrée de `FB_Safety_Winch`.

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier (unique)** — dossier `CODE/` :
- [`CODE/E_Mode.st`](../CODE/E_Mode.st), [`CODE/E_State.st`](../CODE/E_State.st) — fondations manquantes
- [`CODE/ST_SpeedStepTable.st`](../CODE/ST_SpeedStepTable.st), [`CODE/ST_ContactorCheck.st`](../CODE/ST_ContactorCheck.st)
- [`CODE/ST_AxisCmd.st`](../CODE/ST_AxisCmd.st) — **mise à jour** (renommage `Start`→`StartStop`, retrait `SafetyOk`)
- [`CODE/FB_Joystick.st`](../CODE/FB_Joystick.st) — **mise à jour** (suit `ST_AxisCmd`, renomme `SafetyOk`→`EmergencyStopOk`, l'ajoute au GATE)
- [`CODE/FB_Ramp.st`](../CODE/FB_Ramp.st) — **mise à jour** (POU déjà existant, correctif bug accel/décel lors d'une inversion rapide — voir §4)
- [`CODE/FB_SpeedStep.st`](../CODE/FB_SpeedStep.st), [`CODE/FB_Brake.st`](../CODE/FB_Brake.st) — nouvelles briques composées
- [`CODE/FB_Safety_Winch.st`](../CODE/FB_Safety_Winch.st) — **mise à jour v1.1** (`ThermalFeedback`, `SlackCableDetected`, `ForbidDescent` — voir §4ter)
- [`CODE/PRG_MAIN.st`](../CODE/PRG_MAIN.st) — **mise à jour** (câblage I/O réel + nouvelles entrées safety)

📂 **🔧 v1.4 (2026-07-07)** — REX retour contacteur unique par treuil, fichiers réellement présents dans l'arborescence actuelle (`CODE/WINCH/`, `CODE/MAIN/`) :
- [`CODE/WINCH/FB_Winch.st`](../CODE/WINCH/FB_Winch.st) — **mise à jour** (`FwdRevSpeedFeedbackOff` remplace `ContactorFeedbackFwd/Rev`, `ContactorsCheck` fusionne `FwdContactorCheck`/`RevContactorCheck`)
- [`CODE/MAIN/PRG_00_Inputs.st`](../CODE/MAIN/PRG_00_Inputs.st) — **mise à jour** (`M1/M2FwdRevSpeedFeedbackOff` remplace `M1/M2ContactorFeedbackFwd/Rev`)
- [`CODE/MAIN/PRG_02_Encoders.st`](../CODE/MAIN/PRG_02_Encoders.st), [`CODE/MAIN/PRG_06_WinchControl.st`](../CODE/MAIN/PRG_06_WinchControl.st) — **mise à jour** (câblages `instHomingM1/M2`/`instWinchM1/M2` vers `FwdRevSpeedFeedbackOff`)
- [`CODE/ENCODERS/FB_Encoder_Homing.st`](../CODE/ENCODERS/FB_Encoder_Homing.st) — **mise à jour** (`ArretConfirme` utilise `FwdRevSpeedFeedbackOff`, voir Partie10 §7)
- [`CODE/SUPERVISION/ST_WinchHMI.st`](../CODE/SUPERVISION/ST_WinchHMI.st), [`CODE/MAIN/PRG_09_Supervision.st`](../CODE/MAIN/PRG_09_Supervision.st) — **mise à jour** (IHM, `ContactorsCheck` unique)

📂 **🔧 v1.5 (2026-07-07)** — Méca A/B/C (voir §4quinquies) :
- [`CODE/WINCH/FB_Safety_Winch.st`](../CODE/WINCH/FB_Safety_Winch.st) — **mise à jour** (bits 7/8/9,
  nouvelles entrées `FwdRevSpeedFeedbackOff`/`BrakeFeedback`/`JoystickYNeutral`/
  `GrappinHoldStillActive`/seuils, `SafeStop`/`PowerCutOff` recalculés)
- [`CODE/GRAPPIN/FB_Grappin.st`](../CODE/GRAPPIN/FB_Grappin.st) — **mise à jour** (bit4 glissement
  M1, sortie `M1SlipDetected` — voir aussi Partie12 v1.2)
- [`CODE/MAIN/PRG_03_Safety.st`](../CODE/MAIN/PRG_03_Safety.st) — **mise à jour** (câblage des
  nouvelles entrées `FB_Safety_Winch`, `GrappinHoldStillActive` câblé sur `instGrappin.Busy`
  UNIQUEMENT pour l'instance M1)
- [`CODE/MAIN/PRG_06_WinchControl.st`](../CODE/MAIN/PRG_06_WinchControl.st) — **mise à jour**
  (`SafeStopM1_Raw` OR'e désormais `instGrappin.M1SlipDetected`)

📂 **🆕 v1.6 (2026-07-08)** — Thermique frein commun + escalade PowerCutOff (voir §4sexies) :
- [`CODE/SIMULATION/GVL_Simulation.st`](../CODE/SIMULATION/GVL_Simulation.st) — **mise à jour**
  (flag `BrakeThermal_IsReal`)
- [`CODE/MAIN/PRG_00_Inputs.st`](../CODE/MAIN/PRG_00_Inputs.st) — **mise à jour** (nouvelle
  entrée conditionnée `BrakeThermalFeedback`, commune M1/M2/M3)
- [`CODE/WINCH/FB_Safety_Winch.st`](../CODE/WINCH/FB_Safety_Winch.st) — **mise à jour** (bit10,
  masques `SafeStop`/`PowerCutOff` recalculés)
- [`CODE/CHARIOT/FB_Safety_Chariot.st`](../CODE/CHARIOT/FB_Safety_Chariot.st) — **mise à jour**
  (bit3, `PowerCutOff` réel pour ce bit — voir Partie11 v1.3)
- [`CODE/MAIN/PRG_03_Safety.st`](../CODE/MAIN/PRG_03_Safety.st) — **mise à jour** (distribution du
  signal commun aux 3 instances Safety)
- [`CODE/SUPERVISION/ST_WinchHMI.st`](../CODE/SUPERVISION/ST_WinchHMI.st),
  [`CODE/SUPERVISION/ST_ChariotHMI.st`](../CODE/SUPERVISION/ST_ChariotHMI.st),
  [`CODE/MAIN/PRG_09_Supervision.st`](../CODE/MAIN/PRG_09_Supervision.st) — **mise à jour**
  (nouveau champ IHM `BrakeThermalFault`, demande utilisateur explicite)

*(Pas de recopie du corps ici — voir les fichiers `CODE/` pour le ST complet, règle anti-doublon.)*

---

## 📝 7. Note d'application CODESYS 3.5 (manuel, pas à pas)

> ⚠️ **Ordre impératif** (dépendances entre objets) : suivre les étapes dans l'ordre ci-dessous.
> Chaque étape indique précisément quoi cocher/sélectionner dans les fenêtres CODESYS.
> 🆕 **v1.1** : les étapes 0 à 8 sont **inchangées** si déjà appliquées (v1.0). Seules les
> étapes **6bis** (mise à jour `FB_Safety_Winch`), **7bis** (mise à jour `FB_Winch`) et **9**
> (I/O Mapping, désormais en grande partie déjà fait côté device) sont nouvelles/à revoir.

### Étape 0 — Vérifier la bibliothèque Util (pour `HYSTERESIS`)
1. Menu **Outils → Library Repository** (ou **Bibliothèques** dans l'arbre projet, nœud
   `Library Manager`).
2. Ouvrir **Library Manager** (double-clic dans l'arbre projet).
3. Vérifier que **`Util`** apparaît dans la liste. Si absent : bouton **Add library...** →
   rechercher `Util` → sélectionner → **OK**.

### Étape 1 à 8 — Voir Partie9 v1.0 (archivée, `DOC/Archives/`) — inchangées

### Étape 6bis 🆕 — Mettre à jour `FB_Safety_Winch`
1. Double-clic sur `FB_Safety_Winch` (dossier `SAFETY`, déjà créé si Étape 6 v1.0 faite).
2. Volet déclaration : effacer tout, coller la section **DECLARATION** de
   `CODE/FB_Safety_Winch.st` (v1.1 — ajoute `ThermalFeedback`/`SlackCableDetected` en entrée,
   `ForbidDescent` en sortie).
3. Volet implémentation : effacer tout, coller la section **IMPLEMENTATION**.
4. **Enregistrer**. Répéter pour **les 2 instances** (`instSafetyWinchM1`/`instSafetyWinchM2`
   partagent le même TYPE — rien à dupliquer côté POU, juste le câblage dans `PRG_MAIN`).

### Étape 7bis 🆕 — Mettre à jour `FB_Winch`
1. Double-clic sur `FB_Winch` (dossier `WINCH`).
2. Volet déclaration : coller la section **DECLARATION** de `CODE/FB_Winch.st` (v1.1 — ajoute
   `ForbidDescent` en entrée).
3. Volet implémentation : coller la section **IMPLEMENTATION** (§5bis nouveau : masque
   `RelayRev` si `ForbidDescent`).
4. **Enregistrer**.

### Étape 8bis 🆕 — Mettre à jour `PRG_MAIN`
1. Double-clic sur `PRG_MAIN`.
2. Recoller **DECLARATION** puis **IMPLEMENTATION** de `CODE/PRG_MAIN.st` (câblage complet :
   I/O réel M1/M2, `ThermalFeedback`/`SlackCableDetected`/`ForbidDescent`, renommage Chariot).
3. **Enregistrer**.

### Étape 9 — I/O Mapping — **déjà fait pour la majorité des canaux (nouvel export)**
D'après le dernier export `Device.export`, les canaux suivants sont **déjà mappés** (rien à
refaire, juste vérifier la présence dans l'arbre projet, onglet I/O Mapping) :

| Canal physique | Variable (déjà mappée) |
|-----------------|-------------------------|
| Sortie contacteur sens avant/arrière M1/M2 | `M1_RelayFwd`/`M1_RelayRev`, `M2_RelayFwd`/`M2_RelayRev` |
| Sortie contacteur vitesse 1..4 M1/M2 | `M1_SpeedContactor_1..4`, `M2_SpeedContactor_1..4` |
| Sortie bobine frein M1/M2 | `M1_BrakeCmd`, `M2_BrakeCmd` |
| Entrée retour unique contacteurs sens+vitesse M1/M2 🔧 v1.4 (remplace les 4 canaux `M1/M2_FeedbackFwd/Rev_DI`) | `M1_FwdRevSpeedFeedbackOff_DI`, `M2_FwdRevSpeedFeedbackOff_DI` |
| Entrée capteur position haute (commun) | `M1_M2_TopPositionSensor` |
| Entrée thermique moteur M1/M2 | `M1_ThermalFeedback`, `M2_ThermalFeedback` |
| Entrée mou de câble (commun) | `M1_M2_SlackCableSwitch` |

Seul reste **non câblé** (stub logiciel, `GVL_Winch_M1/M2_Stub`) :

| Canal physique | Colonne **Variable** à saisir (quand le matériel sera prêt) |
|-----------------|-------------------------------|
| Entrée retour contacteur frein M1/M2 | `M1_BrakeFeedback`, `M2_BrakeFeedback` |

### Étape 9bis — GVL stub logiciel — **réduit v1.1**
`GVL_Winch_M1_Stub`/`GVL_Winch_M2_Stub` ne contiennent plus qu'une seule variable chacun
(`M1/M2_BrakeFeedback`) — tout le reste est désormais réel. Si le GVL existe encore avec
l'ancien contenu (v1.0, 10 `BOOL`), **recoller entièrement** le fichier `CODE/GVL_Winch_M1(M2)_Stub.st`
(v1.1) : les variables déjà réelles seraient sinon en conflit de nom avec l'I/O Mapping.

🔴 **`GVL_Homing_Stub` (capteur position haute)** : à **supprimer entièrement** (clic droit →
Delete dans l'arbre projet) — `M1_M2_TopPositionSensor` est désormais réel.

### Étape 10 — Compiler et vérifier
1. Menu **Build → Rebuild all** (ou **F11**).
2. Corriger les éventuelles erreurs de référence résiduelles (noms de variables I/O Mapping
   pas encore saisis, typiquement — l'erreur indique la ligne exacte dans `PRG_MAIN`).
3. **Ne pas télécharger sur l'automate avant d'avoir un Rebuild propre (0 erreur).**

### 🔧 v1.5 — Méca A/B/C (2026-07-07)
`CODE/WINCH/FB_Safety_Winch.st`, `CODE/GRAPPIN/FB_Grappin.st`, `CODE/MAIN/PRG_03_Safety.st` et
`CODE/MAIN/PRG_06_WinchControl.st` sont **déjà à jour et validés** avec Méca A/B/C (voir
§4quinquies) — aucune nouvelle recopie manuelle requise au-delà de ce qui a déjà été appliqué en
session, sauf réimportation complète depuis `CODE/` suite à un nouvel export CODESYS.

### 🆕 v1.6 — Thermique frein commun (2026-07-08)
Tous les fichiers listés en §6 sont **déjà à jour dans `CODE/`** — réimport via bundle
PLCopenXML (`PLCOPENXML_TOOLING/generated/CODE_Bundle.xml`) ou recopie manuelle ST habituelle.
**Reste à faire côté utilisateur** (hors périmètre `CODE/`, action manuelle CODESYS) :
1. **I/O Mapping** : mapper le nouveau canal physique `BrakeThermalFeedback_DI` (retour thermique
   frein, contact NC, commun aux 3 axes) sur l'entrée TOR physique réelle (bornier/carte I/O du
   variateur ou armoire — à identifier selon le câblage réel du site).
2. **Rebuild** — 0 erreur avant tout téléchargement automate.
3. Vérifier en simulation (`GVL_Simulation.BrakeThermal_IsReal = FALSE`, comportement par défaut
   sain — `TRUE` simulé) que `PowerCutOff` ne se déclenche PAS en fonctionnement normal, puis
   forcer `BrakeThermalFeedback_DI := FALSE` (ou couper `GVL_Simulation.BrakeThermal_IsReal`
   sans câblage réel) pour valider le déclenchement — voir checklist REX §8.

### 🔒 À sécuriser après remise en service (stubs debug de ce lot)
| Entrée debug | Remplacer par |
|--------------|---------------|
| `StubWinchEnableN1 := TRUE` (PRG_MAIN) | Sortie réelle `FB_Modes` (Enable arbitré par mode) |
| `EmergencyStopOk := GVL_DEBUG.DBG_True` (Joystick/Safety/Winch) | Chaîne AU réarmée réelle |
| `Reset := FALSE` (Joystick/Safety/Winch) | Front acquittement IHM |
| `Mode := E_Mode.MAINT_N1` (Safety/Winch) | Sortie réelle `FB_Modes` |
| Table `M1_SpeedStepTable` (valeurs par défaut cumulatives) | `P<palier>R<relais>` + seuils réels validés à la mise en service |

---

## 🔁 8. Retour d'expérience (à compléter après test)

- [x] Sens (Fwd/Rev) — bug interlock corrigé 2026-07-01 (neutre→un sens bloqué à tort) : à revalider en marche réelle
- [x] Revue de code indépendante 2026-07-01 : 2 critiques + 1 majeur corrigés (interlock arrêt
      prématuré, `Reset` non-front sur `FB_Joystick`, sortie sûre sur `Error` manquante) — à
      revalider en marche réelle malgré tout (défauts précédemment "dormants" en banc de test).
- [ ] Sens (Fwd/Rev) cohérent avec le joystick axe Y (haut = plongée ou extraction ? à vérifier au 1er essai)
- [ ] Paliers de vitesse progressifs et stables (pas de battement au changement de palier)
- [ ] Chaque `P<palier>R<relais>` de `M1_SpeedStepTable` réglé un par un selon le câblage réel des 4 contacteurs M1
- [ ] Frein : relâche bien après le délai (pas d'à-coup), collage bien après arrêt (pas de grincement)
- [ ] Interlock changement de sens : impossible de commuter Fwd/Rev en mouvement ; arrêt ET inversion directe bien bloqués hors vitesse confirmée nulle
- [ ] Inversion **rapide** du joystick (flick) : `Direction`/`RelayFwd`/`RelayRev` basculent en ~0,5 s (temps de décel normal), plus ~3 s comme avant le correctif `FB_Ramp`
- [ ] Inversion **plus rapide que la rampe de décélération** (répétée/sans jamais tenir le stick immobile) : le treuil doit quand même ralentir puis s'arrêter avant de rebasculer — vérifier `instWinchM1.StepNumber` qui redescend bien vers 0 pendant ce temps (correctif `DirectionChangePending` 2026-07-02)
- [ ] Relâcher le joystick → rampe de décélération normale → contacteur de sens reste actif jusqu'à l'arrêt réel → frein collé
- [ ] Défaut simulé (débrancher un retour contacteur) → sorties coupées immédiatement (sortie sûre sur `Error`)
- [ ] Seuils `StepThreshold_Pct` définitifs à figer une fois validés
- [ ] 🆕 **2026-07-03quinquies** — `MaxStepDescente` (défaut 2, `FB_Winch`/`FB_SpeedStep`) : en
      descente, vérifier qu'à 100% joystick le palier ne dépasse JAMAIS `MaxStepDescente` (charge
      entraînante, limitation couple pas vitesse) ; en montée, vérifier que les 5 paliers normaux
      sont inchangés. Valeur `2` indicative, à ajuster selon comportement réel du câble/charge.
- [ ] **Avant de câbler le CAN réel ou le bouton Reset IHM** : re-tester spécifiquement la
      perte joystick/CAN (`SafeStop`) et un Reset maintenu, actuellement inatteignables en
      banc d'essai (`CanOnline`/`CanOperational` figés `TRUE`, `Reset` figé `FALSE`)
- [ ] Si validé → dupliquer pour M2 (nouvelle instance `FB_Winch`, nouvelle table), puis
      réintégrer `FB_WinchSync`/`FB_Encoder_Safety` une fois le codeur fiabilisé
- [ ] **Revue indépendante 2026-07-02** : lors d'une inversion **directe** de sens (Fwd↔Rev sans
      repasser par neutre), `RelayFwd`/`RelayRev` basculent dans le **même cycle** (10 ms) — pas
      de temps mort logiciel explicite entre l'ouverture d'un contacteur de sens et la fermeture
      de l'autre. Non corrigé (incertain si un verrouillage électromécanique matériel existe déjà
      sur l'armoire M1) : **vérifier le schéma électrique réel de l'armoire M1** avant tout essai
      avec charge/vitesse réelle. Si absent, ajouter un état intermédiaire (2 relais à `FALSE`
      pendant quelques dizaines de ms) dans `FB_Winch` §3bis/§5 avant d'engager le nouveau sens.
- [ ] 🆕 **v1.1** — Forcer `M1_ThermalFeedback`/`M2_ThermalFeedback` → vérifier `SafeStop` (arrêt
      total des 2 sens), puis relâcher + Reset front → mouvement réautorisé.
- [ ] 🆕 **v1.1** — Forcer `M1_M2_SlackCableSwitch` pendant une descente → vérifier `RelayRev`
      coupé **immédiatement**, `RelayFwd` (montée) **toujours disponible**, `Error`/`ErrorId`
      bit3 visible IHM. Relâcher + Reset front → descente réautorisée.
- [ ] 🆕 **v1.1** — Vérifier qu'un défaut thermique **et** un mou de câble simultanés cumulent
      bien `SafeStop=TRUE` **et** `ForbidDescent=TRUE` (les deux bits actifs, pas d'écrasement).
- [ ] 🆕 **v1.4 (2026-07-07)** — Débrancher/simuler la perte du retour `M1_FwdRevSpeedFeedbackOff_DI`
      pendant un arrêt commandé (tous relais/contacteurs à `FALSE`) → vérifier `ErrorId` bit1
      (`ContactorsCheck.StuckClosed`) après `ContactorFeedbackTimeout` (500ms), puis Reset front
      + retour réel confirmé → défaut effacé.
- [ ] 🆕 **v1.4** — Confirmer qu'aucun scénario ne déclenche plus jamais bit2 `ErrorId` (libéré) ;
      confirmer que `ContactorsCheck.StuckOpen` reste bien figé à `FALSE` en toutes circonstances
      (plus de détection par sens possible avec ce nouveau câblage).
- [ ] 🆕 **v1.5 (2026-07-07, Méca A)** — En banc, forcer `FwdRevSpeedFeedbackOff := TRUE` et
      `BrakeFeedback := TRUE` (tout confirmé coupé), puis simuler une dérive de `CablePosM`
      au-delà de `UncommandedDriftToleranceM` (2.0 m) → vérifier bit7 `ErrorId`, `SafeStop`
      **et** `PowerCutOff` tous les deux à `TRUE`. Répéter en dépassant `UncommandedSpeedThresholdMps`
      (0.02 m/s) plutôt que la dérive.
- [ ] 🆕 **v1.5 (Méca B)** — Couper le CAN joystick (ou mettre l'axe Y au neutre) pendant un
      mouvement, puis ne **pas** relâcher `FwdRevSpeedFeedbackOff` dans `PostRampTimeout` (3 s)
      → vérifier bit8 `ErrorId`, `SafeStop` **et** `PowerCutOff`. Vérifier qu'un arrêt normal
      (relais qui retombent bien dans les 3 s) ne déclenche **pas** le défaut (pas de faux positif).
- [ ] 🆕 **v1.5 (Méca C couche 2)** — Pendant un mouvement grappin (`instGrappin.Busy = TRUE`),
      simuler une dérive M1 au-delà de `GrappinSlipToleranceM` (2.0 m) alors que la couche 1
      (`FB_Grappin` bit4, 1.0 m) a déjà réagi → vérifier l'escalade bit9 `ErrorId` et `PowerCutOff`
      sur `instSafetyWinchM1` uniquement (jamais sur M2, `GrappinHoldStillActive` toujours `FALSE`
      côté M2).
- [ ] 🆕 **v1.5** — Vérifier qu'`OverrideSync` (MAINT_N2, procédure récupération mou de câble)
      **n'exclut jamais** les bits 7/8/9 du calcul de `SafeStop` (contrairement au bit3 mou de
      câble) — les deux masques (`16#039F`/`16#0397`) doivent différer **uniquement** sur le bit3.
- [ ] 🆕 **v1.5 (TBD futur)** — Une fois l'échelle de `COD1_SpdValue`/`COD2_SpdValue` déterminée
      (fiche technique Kübler F58x8 ou essai terrain), comparer la vitesse mesurée par ce mot
      natif à la différentiation logicielle actuelle (`MeasuredSpeedMps`) sur un même mouvement,
      pour évaluer le gain de fiabilité avant de basculer Méca A dessus en réel.
- [ ] 🆕 **v1.6 (2026-07-08)** — Une fois `BrakeThermalFeedback_DI` mappé en I/O réel : forcer une
      perte du retour (fil coupé simulé) → vérifier bit10 `ErrorId`, `SafeStop` **et**
      `PowerCutOff` sur **les 3 axes simultanément** (M1, M2 ET M3 — signal commun), `GVL_IHM.*.BrakeThermalFault`
      visible sur les 3 structs IHM concernées (`WinchM1`/`WinchM2`/`Chariot`). Puis relâcher +
      Reset front → mouvement réautorisé sur les 3 axes.
- [ ] 🆕 **v1.6** — Forcer `M1_ThermalFeedback`/`M2_ThermalFeedback` (surchauffe moteur, bit2) →
      vérifier que `PowerCutOff` se déclenche désormais **aussi** (pas seulement `SafeStop` comme
      avant v1.6) — non-régression : `GVL_IHM.Modes.PowerCutOffActive` doit refléter cette
      escalade sans modification supplémentaire (agrégat déjà en place, `PRG_09_Supervision`).
- [ ] 🆕 **v1.6** — Vérifier qu'`OverrideSync` **n'exclut jamais** le bit10 du calcul de `SafeStop`
      (même règle que bits 7/8/9) — les masques `16#079F`/`16#0797` doivent différer
      **uniquement** sur le bit3.

---

## 🧭 9. Extension — Treuil M2 + sélection opérateur (partiellement implémenté)

> 🟡 **Statut mis à jour 2026-07-02** : `instWinchM2`/`instSafetyWinchM2` sont créés et **actifs**
> dans `PRG_MAIN` (voir `CODE/PRG_MAIN.st`), consigne **dupliquée** sur l'axe Y du joystick (même
> source que M1) — **sans** `E_WinchSelect`/sélecteur IHM, **sans** bit « Prise de main IHM »,
> **sans** `FB_WinchSync` réel. Les décisions ci-dessous (sélecteur, arbitrage IHM, synchro
> conditionnelle par mode) restent **non codées** — seule l'intégration brute de M2 (dupliqué) a
> été avancée, à la demande explicite de l'utilisateur, en parallèle du lot Codeur.

### Besoin
Pouvoir piloter le treuil **M2** en plus de M1, avec un choix opérateur explicite :
- **Quel(s) treuil(s)** : M1 seul, M2 seul, ou les deux.
- **Quelle source de commande** : Joystick **ou** IHM — **jamais les deux en même temps**.

### Décisions actées (session 2026-07-02)
1. **Sélection treuil** : sélecteur **IHM dédié** (M1 / M2 / Les deux), indépendant du mode de
   marche — l'opérateur choisit à tout moment.
2. **Arbitrage Joystick ↔ IHM** : bit **« Prise de main IHM »**. Tant qu'il est actif, l'IHM est
   la source légitime et le joystick est ignoré (même logique d'arbitrage de source que
   `FB_Modes` Manuel/SemiAuto, Partie5 §1, mais appliquée ici à Joystick vs IHM).
3. **Synchro M1/M2 selon mode** (si « Les deux » sélectionné) :
   - **Semi-auto** : synchro **active par défaut** (hors périmètre immédiat — `FB_Cycle` n'existe
     pas encore).
   - **Maintenance N1** : synchro **imposée**, non désactivable (cohérent avec Partie5 §2 —
     sécurité maintenue en N1).
   - **Maintenance N2** : synchro **activable/désactivable par sélecteur** (override assumé,
     cohérent avec Partie5 §2 — droits étendus N2).
   - Sinon (un seul treuil sélectionné) : pas de notion de synchro, consigne simple sur le
     treuil choisi (comme M1 aujourd'hui).
4. **Périmètre** : **Maintenance N1 et N2 uniquement** pour ce lot (pas Manuel, pas Semi-auto —
   `FB_Cycle` gérera les deux treuils à sa manière plus tard).

### Dépendance bloquante (toujours valable pour la synchro)
`FB_WinchSync` (Partie2 §4, Partie4 §3) régule l'écart `ΔPos = |PosM1 − PosM2|` à partir des
positions codeur validées. L'acquisition + mise à l'échelle (`FB_Encoder_Abs`→`FB_Encoder_Scale`)
sont codées depuis le 2026-07-02 (voir `DOC/AF_Partie10_Fonction_Encoder_Homing_v1.7.md` §9), mais
`HomingRefRaw` reste une valeur RETAIN modifiable **manuellement** (pas de vrai homing tant que
`FB_Encoder_Homing` n'est pas codé) — construire une synchro sur cette base serait prématuré.
**M1 et M2 bougent donc ensemble sans aucune régulation d'écart pour l'instant** : à surveiller
visuellement pendant tout essai avec les deux treuils actifs.

### Ce qui reste à faire
- Sélecteur treuil IHM (M1 / M2 / Les deux), bit « Prise de main IHM », `E_WinchSelect`
- `FB_WinchSync` réel (dépend d'un homing fiable, donc de `FB_Encoder_Homing`)
- Synchro conditionnelle par mode (imposée N1, activable N2, active SemiAuto) — décisions déjà
  actées ci-dessus, juste pas codées

---

## 📚 Documents liés
- **Partie 2 v2.10** — Architecture (`PRG_00_Inputs`→`PRG_10_Outputs`, mapping M1/M2/M3).
- **Partie 3 v1.3** — Contrat FB (`StartStop`/`SafeStop`, ErrorId, reset).
- **Partie 4 v1.2** — Cycle (§3 Synchro, §4 Frein — règles reprises ici pour `FB_Brake`).
- **Partie 5 v1.2** — Modes & maintenance (droits Maintenance N1).
- **Partie 8 v1.2** — Fonction Joystick (source de `AxisCmdY`, corrections `ST_AxisCmd` liées).
- **Partie 10 v1.7** — Encoder Homing (dépendance bloquante §9 ci-dessus, pas encore codée).
- **Partie 11 v1.3** 🆕 v1.6 — Fonction Chariot (`FB_Safety_Chariot` bit3, même signal commun
  `BrakeThermalFeedback` — voir §4sexies).
- **Partie 12 v1.2** 🆕 v1.5 — Fonction Grappin (Méca C couche 1, `M1SlipDetected` consommé par
  Méca C couche 2 ci-dessus §4quinquies).

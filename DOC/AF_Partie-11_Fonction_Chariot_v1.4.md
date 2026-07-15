# 📋 Analyse Fonctionnelle — Partie 11 : Fonction Chariot (v1.4)

> **v1.4** — Nettoyage documentaire (audit doc) : remarques organisationnelles (ST_ContactorCheck
> chariot manquant, protocole AC600, checklist de mise en service) remplacées par des renvois
> courts vers `DOC/PLAN_TASK_v1.0.md` §3 (T4/T12/T26). Aucun changement fonctionnel.
> 🆕 **v1.3 (2026-07-08)** — Retour terrain frein (demande utilisateur) : nouveau retour thermique
> **frein**, COMMUN aux 3 axes M1/M2/M3 (1 seul fil, `BrakeThermalFeedback_DI`, câblé
> identiquement sur `FB_Safety_Chariot` **et** les 2 instances `FB_Safety_Winch` — voir
> [Partie9 v1.7](AF_Partie-09_Fonction_Winch_v1.10.md) §4sexies) → nouveau bit3 `ErrorId`
> (`FB_Safety_Chariot`, bit1 reste réservé EtherCAT variateur, non câblé). **`PowerCutOff` devient
> réel pour ce bit précis** (`(ErrorId AND 16#0008) <> 0`) — jusqu'ici toujours `FALSE` en dur
> pour ce FB (les autres bits du domaine Chariot restent `FALSE` — 📌 voir
> `DOC/PLAN_TASK_v1.0.md` §3 T12). Justification : le frein M3 est à manque de courant (colle au repos, comme
> `FB_Brake` — voir Partie9) — la perte de ce retour peut signifier un collage instantané pendant
> que le chariot est encore en mouvement, une rampe `SafeStop` seule ne suffit pas. Nouveau champ
> IHM `ST_ChariotHMI.BrakeThermalFault` (demande utilisateur explicite : info accessible via
> IHM). Détail interface en §3, mapping E/S en §5bis.
> **v1.2** — Renommage métier Translation→Chariot (demande utilisateur — l'axe transversal est
> un objet métier, "le chariot qui se déplace"), préfixe I/O physique M3 inchangé. AJOUT §5bis :
> capteurs position réels du chariot (`PosFosse1`/`PosFosse2`/`PosMaintenance`/`PosTremie`,
> I/O Mapping réel) + sélecteur STUB maintenance (`StubChariotPositionSelect_IHM`,
> `GVL_Chariot_M3_Stub`) en attendant `FB_Cycle` pour la sélection de cible normale.

> **Fonction métier** : chaîne de commande Joystick (axe X) → `FB_Chariot` → variateur AC600
> (axe M3), avec **deux modes de communication** sélectionnables manuellement : `ETHERCAT`
> (nominal, mot commande/état + consigne fréquence proportionnelle) et `DEGRADED_IO` (relais de
> sens + présélection vitesse PV/GV en TOR, vitesse et rampes réglées localement sur le
> variateur) — motivé par une panne de communication EtherCAT constatée sur le variateur AC600.
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔴 **Document de réflexion / squelette** : la partie `ETHERCAT` porte des inconnues protocolaires
> (layout exact des mots commande/état AC600) volontairement **non comblées par approximation**
> (règle projet : ne jamais deviner). La partie `DEGRADED_IO` est fonctionnellement complète
> (corrigée v1.1) mais reste conditionnée à la confirmation du bornier réel et du paramétrage
> AC600 (§4bis) avant tout essai machine en charge.
> 🔗 Dépend de : [P2 Architecture v2.11](AF_Partie-02_Architecture_Programme_v2.11.md), [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md) §1bis, [P4 Cycle v1.2](AF_Partie-04_Cycle_Sequenceur_v1.3.md) §5, [P9 Winch v1.7](AF_Partie-09_Fonction_Winch_v1.10.md) (patterns réutilisés : interlock sens, `FB_Brake`, `FB_Safety_<Metier>`, thermique frein commun §4sexies).
>
> ℹ️ **Numérotation** : la branche `claude/encoder-homing-winch-control-h6ef89` (non fusionnée
> dans `main` à la rédaction) occupe déjà `AF_Partie-10_Fonction_Encoder_Homing_v1.1.md` — ce
> document prend donc le numéro **11** pour éviter toute collision au moment du merge.
>
> **v1.1** — Correctifs suite revue automatisme/mise en service 2026-07-02 (périmètre strictement
> limité à `FB_Chariot`/`FB_Safety_Chariot`/`E_ChariotCommMode`, aucun autre bloc du
> projet touché) :
> - 🔴 **[F1, bloquant, corrigé]** En `DEGRADED_IO`, la coupure des relais de sens sur arrivée
>   capteur (§9bis) dépendait de la rampe **logicielle** `SpeedRamp.Current`, sans lien avec la
>   vitesse physique réelle en tout-ou-rien (PV/GV) → jusqu'à ~2,5 s de roulage à pleine vitesse
>   après passage sur le capteur. Corrigé : coupure **immédiate**, découplée de la rampe
>   (`DegradedMoveAuthorized`, voir `CODE/FB_Chariot.st`).
> - 🟠 **[F5, corrigé]** `CommMode` est désormais **verrouillé** (`CommModeLocked`) tant qu'un
>   mouvement est en cours — un changement de mode pendant `Busy=TRUE` n'est plus pris en compte.
> - 🟠 **[F7, clarifié]** Les paramètres de rampe ne pilotent une vitesse physique réelle qu'en
>   `ETHERCAT`. Nouveau paramètre `DegradedStopSettleTime` (délai physique réel) remplace la rampe
>   comme confirmation d'arrêt pour l'interlock de sens en `DEGRADED_IO`.
> - 🟠 **[F2, F3, F4, F6]** Ajout §4bis (paramétrage AC600 à vérifier avant essai), avertissement
>   double commande EtherCAT/relais (§4bis), note de portée sur Partie2 §5 (§4), checklist
>   "avant premier essai" (§7).

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (axe X, chariot) en commande physique du variateur
AC600 (M3), dans le respect strict de la précédence `Enable` > `SafeStop` > `StartStop`
(Partie3 §1bis) — **quel que soit le mode de communication actif**.

**Origine du besoin** : le pilotage nominal du variateur via EtherCAT (mot de commande, consigne
fréquence) est actuellement **indisponible** (panne bus). Plutôt que d'immobiliser l'axe de
chariot, on prévoit une chaîne de secours par **relais TOR**, câblée en parallèle du bus
EtherCAT, activable manuellement le temps de fiabiliser la communication.

**Sélection du mode** : entrée `CommMode : E_ChariotCommMode` (`ETHERCAT` / `DEGRADED_IO`),
positionnée **manuellement** (maintenance/IHM) — **jamais de bascule automatique** en cours de
mouvement, cohérent avec le principe projet « jamais de redémarrage/bascule automatique sans
action consciente » (CLAUDE.md, guardrails).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdX ──► FB_Chariot(M3) ──┬─► [CommMode=ETHERCAT]    DriveControlWord + DriveFreqRefHz ──► AC600 (EtherCAT)
                                               ├─► [CommMode=DEGRADED_IO] RelayFwd/RelayRev + RelaySpeedGv (PV/GV) ──► AC600 (bornier TOR)
                                               └─► FB_Brake ──► BrakeCmd (séquence temporisée, indépendante du mode)

FB_Safety_Chariot ──► SafeStop     ──► (entrée) FB_Chariot(M3)
                  ──► PowerCutOff 🆕 ──► (hors FB_Chariot) coupure puissance amont — thermique frein commun uniquement (bit3, voir §4ter)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_Chariot` | Assemble rampe interne, arbitrage `Enable > SafeStop > StartStop`, interlock sens, arrêt sur capteur, et sortie physique selon `CommMode` |
| `FB_Brake` | **Réutilisé tel quel** depuis `_COMMON` (même brique que le treuil) — nouvelle instance, nouveaux réglages RETAIN propres à M3. Partie4 §5 mentionne déjà un « frein à manque de courant » pour le chariot → pas de FB dédié nécessaire (Partie3 §0, anti-réinvention) |
| `FB_Safety_Chariot` | Bloc safety **métier** du domaine chariot : lève `SafeStop_Chariot` — périmètre minimal ce lot : perte joystick/CAN, rotation de phase, et 🆕 thermique frein commun (voir §4ter) ; lève `PowerCutOff` 🆕 sur ce dernier point uniquement |

> ♻️ **Réutilisation** (Partie3 §0) : `HYSTERESIS` (lib Util) pour la sélection PV/GV en
> `DEGRADED_IO` — **pas** `FB_SpeedStep` (table 5 paliers/4 relais disproportionnée pour un choix
> à 2 états). `FB_Ramp` + `FB_CycleTime` (déjà utilisés par `FB_Joystick`/`FB_Winch`) pour la
> rampe interne. `LIMIT` (IEC standard) pour le plafonnement vitesse d'approche.

---

## 🔌 3. Interface `FB_Chariot` (FB de mouvement, Partie3 §1bis)

**📥 Entrées communes**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` / `Reset` / `EmergencyStopOk` / `Mode` | — | Standard (Partie3 §1) |
| `StartStop` / `SafeStop` | BOOL | Standard FB de mouvement (Partie3 §1bis) |
| `CommMode` | `E_ChariotCommMode` | Sélection manuelle `ETHERCAT`/`DEGRADED_IO` |
| `Direction` | INT | -1/0/+1 (axe X joystick) |
| `SpeedRefPct` | REAL | 0..100 % — proportionnel en `ETHERCAT`, sélecteur PV/GV (via `HYSTERESIS`) en `DEGRADED_IO` |
| `PositionSensorTarget` | BOOL | Capteur position cible courante (sélection de la cible = **hors périmètre** de ce FB, en amont IHM/`FB_Cycle`) |
| `BrakeFeedback` | BOOL | Retour contacteur bobine frein (circuit propre, indépendant du mode) |

**📥 Entrées spécifiques `ETHERCAT`**
| Entrée | Type | Rôle |
|--------|------|------|
| `DriveStatusWord` | WORD | 🔴 Mot d'état AC600 — **layout de bits TBD**, lu depuis l'image d'entrée EtherCAT |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée (pas de mesure de courant, Partie4 §5) |

**📥 Entrées spécifiques `DEGRADED_IO`**
| Entrée | Type | Rôle |
|--------|------|------|
| `ContactorFeedbackFwd` / `Rev` | BOOL | Retours d'état câblés contacteurs de sens |
| `DriveFaultOk` | BOOL | Retour TOR état sain variateur, câblage NF (`TRUE` = sain/normal, `FALSE` = défaut/ouvert ou fil coupé) |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `DriveControlWord` / `DriveFreqRefHz` | WORD / REAL | 🔴 `ETHERCAT` — mot de commande (**TBD**) + consigne fréquence (calculée, échelle explicite en attendant vérif `LIN_TRAFO`) |
| `RelayFwd` / `RelayRev` / `RelaySpeedGv` | BOOL | `DEGRADED_IO` — contacteurs de sens + sélection GV (`FALSE`=PV, `TRUE`=GV) |
| `BrakeCmd` | BOOL | Commande bobine frein (`TRUE` = relâché) — indépendant du mode |
| `TargetReached` | BOOL | Capteur cible confirmé (debounce) |
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | État standard (Partie3 §1) |
| `FwdContactorCheck` / `RevContactorCheck` / `BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic détaillé (IHM) |

`ErrorId` (`FB_Chariot`) : bit0 = défaut frein, bit1 = contacteur sens Fwd incohérent (`DEGRADED_IO`), bit2 =
contacteur sens Rev incohérent (`DEGRADED_IO`), bit3 = défaut variateur (`DriveFaultOk` ou 
variateur non disponible, actif sur `FALSE`/`0`).

### `FB_Safety_Chariot` (Partie3 §1/§7bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable`/`Reset`/`EmergencyStopOk`/`Mode` | — | Contrat standard (Partie3 §1) |
| `JoystickOnline`/`JoystickOperational` | BOOL | `instDiagCanOpen.Joystick` |
| `PhaseRotationOk` | BOOL | `PRG_00_Inputs.PhaseRotationOk` (commun M1/M2/M3, I/O réel) |
| `BrakeThermalFeedback` 🆕 v1.3 | BOOL | Retour TOR thermique **frein**, COMMUN aux 3 axes M1/M2/M3 (`BrakeThermalFeedback_DI`, 1 seul fil, câblé IDENTIQUEMENT sur cette instance et les 2 instances `FB_Safety_Winch` — voir [Partie9 v1.6](AF_Partie-09_Fonction_Winch_v1.10.md) §4sexies) : `TRUE` = surchauffe/perte |

**📤 Sorties**
| Sortie | Type | Rôle |
|--------|------|------|
| `Ready/Busy/Done/Error/State/StateAtError` | — | Contrat standard |
| `ErrorId` | WORD | bit0 : perte joystick/CAN ; bit1 **réservé** (EtherCAT variateur AC600, non câblé, TBD) ; bit2 : mauvaise rotation de phase (commun M1/M2/M3) ; bit3 🆕 v1.3 : surchauffe/perte thermique frein commun M1/M2/M3 (`SafeStop` via `Error` + `PowerCutOff`) |
| `SafeStop` | BOOL | `Error OR NOT EmergencyStopOk` (miroir de tout `ErrorId`, y compris bit3 — inchangé structurellement) |
| `PowerCutOff` 🔧 v1.3 | BOOL | **Réel pour bit3 uniquement** : `(ErrorId AND 16#0008) <> 0`. Coupure puissance amont : un frein à manque de courant qui perd son retour thermique peut coller instantanément pendant le mouvement — `SafeStop` seul ne suffit pas. Les autres bits du domaine Chariot restent `FALSE` (📌 voir `DOC/PLAN_TASK_v1.0.md` §3 T12) |

---

## 🛡️ 4. Sécurité

- **Précédence stricte** `Enable > SafeStop > StartStop`, identique aux autres FB de mouvement.
- **Interlock changement de sens** : même principe que `FB_Winch` — engagement initial
  neutre→un sens immédiat, arrêt et inversion directe exigent une confirmation d'arrêt
  (`IsStoppedConfirmed`, 🆕 v1.1) dont la source diffère par mode : rampe logicielle confirmée
  nulle en `ETHERCAT` (consigne réellement proportionnelle), **délai physique réel
  `DegradedStopSettleTime`** en `DEGRADED_IO` (la rampe logicielle n'y a aucun lien avec la
  vitesse réelle, cf. correctif F1/F7).
- **Arrêt exact sur capteur** (§9bis du code, 🆕 **comportement proposé, à valider avec
  l'utilisateur** — absent de toute doc existante) : le mouvement est verrouillé (`ArrivalLock`)
  tant que `PositionSensorTarget` (débounced) reste actif **et** que le sens commandé est le même
  que celui qui a mené à l'arrivée — permet de repartir immédiatement en sens inverse sans
  bloquer totalement l'axe sur la position atteinte. **Coupure immédiate des relais en
  `DEGRADED_IO`** depuis le correctif v1.1 (F1) — avant correction, la coupure réelle pouvait être
  retardée de plusieurs secondes.
- **Ralentissement auto à l'approche** (`ETHERCAT` uniquement, Partie4 §5) : après `ApproachTime`
  écoulé depuis le début du mouvement, la consigne est plafonnée à `ApproachSpeedPct`. **Non
  reproductible en `DEGRADED_IO`** (pas de consigne variable programmable) — le choix PV/GV y
  reste manuel, au joystick.
- **Frein** : séquence temporisée stricte (`FB_Brake`, réutilisé tel quel), pilotée par
  `MovementRequested`, commun aux deux modes.
- **Sortie sûre sur défaut** : `Error` force `DriveControlWord`/`DriveFreqRefHz`/`RelayFwd`/
  `RelayRev`/`RelaySpeedGv`/`BrakeCmd` à leur état sûr, conforme Partie3 §9 étape 7.

### 🆕 4ter. Thermique frein commun M1/M2/M3 + PowerCutOff (2026-07-08)

> ✅ Statut : **implémenté et câblé** dans `FB_Safety_Chariot` (bit3) — même signal, même
> raisonnement que [Partie9 v1.6](AF_Partie-09_Fonction_Winch_v1.10.md) §4sexies (`FB_Safety_Winch`
> bit10). Demande utilisateur directe, retour terrain frein.

**Contexte** : le frein M3 (comme M1/M2) est **à manque de courant** — il colle au repos par
construction (sécurité positive, voir `FB_Brake`, Partie9). Le nouveau retour thermique
**commun aux 3 freins** (`BrakeThermalFeedback_DI`, 1 seul fil — impossible de distinguer lequel
des 3 axes est en cause) est câblé sur `PRG_00_Inputs.BrakeThermalFeedback`, puis distribué
identiquement aux 3 instances Safety (`instSafetyWinchM1`/`M2`, `instSafetyChariotM3`).

**Raisonnement sécurité (demande utilisateur)** : la perte de ce retour (surchauffe réelle OU
fil coupé — indiscernable par construction NC) peut signifier qu'un frein colle
**instantanément** alors que l'axe concerné est encore en mouvement/sous couple. Une simple
rampe de décélération (`SafeStop`) ne protège pas la mécanique dans ce cas précis : il faut
couper la puissance **immédiatement** (`PowerCutOff`) — les 3 axes sont coupés simultanément
puisque le signal ne permet pas d'isoler lequel est réellement en cause.

**Différence avec `FB_Safety_Winch`** : côté Chariot, `PowerCutOff` était **toujours `FALSE`**
avant ce lot (aucun `ST_ContactorCheck` de puissance câblé pour ce domaine — 📌 voir
`DOC/PLAN_TASK_v1.0.md` §3 T12). Ce lot ne rend
`PowerCutOff` réel **que pour le bit3** (thermique frein) — les autres bits (perte joystick/CAN,
rotation de phase) restent `FALSE` pour `PowerCutOff`, inchangés.

```
// Nouveau calcul FB_Safety_Chariot (remplace le FALSE en dur de v1.2) :
PowerCutOff := (ErrorId AND 16#0008) <> 0   // bit3 (thermique frein commun) uniquement
```

> 📄 Code de référence (règle anti-doublon) : `CODE/CHARIOT/FB_Safety_Chariot.st` (bit3, calcul
> `PowerCutOff`), `CODE/MAIN/PRG_00_Inputs.st` (acquisition commune), `CODE/MAIN/PRG_03_Safety.st`
> (distribution aux 3 instances), `CODE/SUPERVISION/ST_ChariotHMI.st` + `CODE/MAIN/PRG_09_Supervision.st`
> (remontée IHM `BrakeThermalFault`, demande utilisateur explicite).

### ⚠️ Ce qui reste TBD (ne pas approximer)

Layout `DriveControlWord`/`DriveStatusWord` (protocole AC600), interface `LIN_TRAFO` non
vérifiée, bornier TOR réel `DEGRADED_IO` et `VariateurAvailable`/diag EtherCAT AC600 non finalisé
— tous liés au même point bloquant : le protocole/constructeur du variateur AC600 n'a pas encore
été confirmé. 📌 Suivi : voir `DOC/PLAN_TASK_v1.0.md` §3 (T4, T12). La table "Dégradation par
domaine" de [Partie2 §5](AF_Partie-02_Architecture_Programme_v2.11.md) reste également à mettre à
jour pour référencer `CommMode := DEGRADED_IO` (hors périmètre de ce document, ne touche que les
fichiers Chariot).

---

## ⚡ 4bis. Paramétrage AC600 & câblage — à vérifier AVANT tout essai réel

🔴 **Cette section liste QUOI vérifier, pas les valeurs exactes** (numéros de paramètres/menu
propres au modèle AC600 exact installé — non disponibles à la rédaction, à relever sur la doc
constructeur ou l'étiquette du variateur).

| Vérification | Pourquoi | Type |
|---------------|----------|------|
| Fréquence PV (petite vitesse) réglée sur le variateur | Vitesse physique réelle en `DEGRADED_IO` quand `RelaySpeedGv = FALSE` — le PLC ne fait que sélectionner, pas moduler | Paramètre variateur |
| Fréquence GV (grande vitesse) réglée sur le variateur | Idem quand `RelaySpeedGv = TRUE` | Paramètre variateur |
| Rampes accel/decel **internes** au variateur | Déterminent la décélération physique réelle après coupure du relais de sens — c'est cette valeur, pas `RampDecelNormalRate`/`RampDecelFastRate` (paramètres PLC, sans effet physique en `DEGRADED_IO`), qui doit inspirer le réglage de `DegradedStopSettleTime` | Paramètre variateur |
| **Source de commande** (Terminal/bornier vs Communication/fieldbus) | 🔴 **Critique** : le câblage relais est prévu **en parallèle** du bus EtherCAT (§1). Tant que ce paramètre n'est pas verrouillé sur *Terminal* pendant `CommMode = DEGRADED_IO`, une reprise intermittente du bus EtherCAT peut produire un comportement imprévisible (le PLC écrit `DriveControlWord := 0`/`DriveFreqRefHz := 0.0` sur l'image EtherCAT en `DEGRADED_IO`, mais l'interprétation de ce "0" par le variateur dépend entièrement de ce paramètre) | Paramètre variateur — **à figer avant tout essai** |
| Sectionnement/isolement physique du bus EtherCAT (si possible) | Alternative plus sûre que le seul verrouillage logiciel du paramètre source de commande, tant que ce dernier n'est pas confirmé | Câblage |

**Procédure de réglage progressif recommandée pour le premier essai** (valeurs par défaut
`FB_Chariot.st` volontairement prudentes mais non validées terrain) :
1. Régler PV à une fréquence **très basse** sur le variateur (mouvement à peine perceptible).
2. Tester `RelayFwd` seul (axe **non chargé**, machine à l'arrêt) → valider le sens physique
   correspond bien à l'attendu joystick (sinon inverser le câblage moteur, pas la logique PLC).
3. Remonter PV progressivement jusqu'à une valeur d'exploitation confortable.
4. Régler GV en dernier, seulement une fois PV validée et le comportement d'arrêt sur capteur
   (§9bis) vérifié à vitesse PV.

---

## 🗺️ 5. Mapping E/S (à créer en I/O Mapping CODESYS, voir §7)

**`ETHERCAT`** (image process EtherCAT, rafraîchie par `EtherCatTask` 4ms)
| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M3_DriveControlWord` | Sortie | Mot de commande AC600 — 🔴 TBD layout |
| `M3_DriveFreqRefHz` | Sortie | Consigne fréquence |
| `M3_DriveStatusWord` | Entrée | Mot d'état AC600 — 🔴 TBD layout |
| `M3_DriveActualFreqHz` | Entrée | Fréquence réelle mesurée |

**`DEGRADED_IO`** (relais/TOR, I/O Mapping standard)
| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M3_RelayFwd` | Sortie | Contacteur sens avant M3 |
| `M3_RelayRev` | Sortie | Contacteur sens arrière M3 |
| `M3_RelaySpeedGv` | Sortie | Sélection vitesse (câblé sur entrée présélection AC600) |
| `M3_ContactorFeedbackFwd` / `Rev` | Entrée | Retours contacteurs de sens M3 |
| `M3_DriveFaultOk` | Entrée | Retour TOR état sain variateur, câblage NF (`TRUE` = OK/sain, `FALSE` = défaut/ouvert ou fil coupé) |

**Communs**
| Variable (code) | Sens | Statut | Rôle |
|------------------|------|--------|------|
| `M3_BrakeCmd` | Sortie | 📡 I/O réel (2026-07-02) | Bobine frein chariot |
| `M3_BrakeFeedback` | Entrée | 🧪 STUB | Retour contacteur bobine frein — non câblé |
| `M3_PositionSensorTarget` | Entrée | 🧪 STUB, arbitré | Capteur position cible **arbitré** — voir §5bis |
| `BrakeThermalFeedback_DI` 🆕 v1.3 | Entrée | 🧪 À câbler (mapping physique restant) | Retour thermique **frein**, **commun aux 3 axes** M1/M2/M3 (1 seul fil) → `PRG_00_Inputs.BrakeThermalFeedback` → `FB_Safety_Chariot.BrakeThermalFeedback` (+ les 2 instances `FB_Safety_Winch`, voir Partie9 v1.6) |

---

## 🎯 5bis. Capteurs position réels du chariot (2026-07-02, demande utilisateur)

Le nouvel export `Device.export` câble **4 capteurs position réels distincts** liés au chariot,
permettant un arrêt précis sur chacun sans attendre `FB_Cycle` (pas encore codé) :

| Variable (I/O réel) | Rôle |
|----------------------|------|
| `PosFosse1` | Position fosse 1 |
| `PosFosse2` | Position fosse 2 |
| `PosMaintenance` | Position maintenance |
| `PosTremie` | Position trémie |

`FB_Chariot` n'a qu'**une seule** entrée `PositionSensorTarget` (§3 — la sélection de la cible
est **hors périmètre** de ce FB, portée en amont). En exploitation normale, ce sera `FB_Cycle`
qui arbitrera laquelle de ces 4 variables alimente `PositionSensorTarget` selon l'étape en
cours. **`FB_Cycle` n'existe pas encore** — pour permettre de tester dès ce lot chaque capteur
individuellement, un **sélecteur STUB maintenance** a été ajouté dans `GVL_Chariot_M3_Stub` :

```
StubChariotPositionSelect_IHM : INT := 0;   // 0=Aucun, 1=Fosse1, 2=Fosse2, 3=Maintenance, 4=Trémie
```

`PRG_MAIN.st` arbitre `M3_PositionSensorTarget` par un `CASE` sur ce sélecteur (voir §6). Ce
sélecteur est **explicitement temporaire** : à supprimer dès que `FB_Cycle` prend en charge la
sélection de cible réelle (même principe que les autres stubs — pas de coexistence prévue avec
la logique définitive).

> 🧭 **Portée limitée à ce lot** (Règle d'or projet) : uniquement le mapping + sélecteur de test.
> Aucune logique de cycle/séquencement n'est ajoutée ici — les capteurs des autres équipements
> nouvellement câblés (convoyeur, grille, casque, hydraulique) restent hors périmètre, non
> traités (décision explicite utilisateur, "pour l'instant tout ou rien, il n'y a rien à faire").

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier (unique)** — dossier `CODE/` :
- [`CODE/E_ChariotCommMode.st`](../CODE/E_ChariotCommMode.st) — nouveau type
- [`CODE/FB_Chariot.st`](../CODE/FB_Chariot.st) — 🔴 **squelette** : interface complète +
  corps ST fonctionnel pour tout ce qui est spécifié, sections TBD clairement isolées et
  commentées (ne pas les compléter par approximation)
- [`CODE/FB_Safety_Chariot.st`](../CODE/FB_Safety_Chariot.st) — nouveau bloc safety
  métier, périmètre minimal (perte joystick/CAN)
- [`CODE/GVL_Chariot_M3_Stub.st`](../CODE/GVL_Chariot_M3_Stub.st) — **mis à jour v1.2** :
  `M3_BrakeCmd` retiré (réel), sélecteur STUB position (§5bis) ajouté

📂 **🆕 v1.3 (2026-07-08)** — Thermique frein commun + PowerCutOff (voir §4ter) :
- [`CODE/CHARIOT/FB_Safety_Chariot.st`](../CODE/CHARIOT/FB_Safety_Chariot.st) — **mise à jour**
  (entrée `BrakeThermalFeedback`, bit3 `ErrorId`, `PowerCutOff` réel pour ce bit)
- [`CODE/MAIN/PRG_03_Safety.st`](../CODE/MAIN/PRG_03_Safety.st) — **mise à jour** (câblage de
  l'entrée commune sur `instSafetyChariotM3`)
- [`CODE/SUPERVISION/ST_ChariotHMI.st`](../CODE/SUPERVISION/ST_ChariotHMI.st),
  [`CODE/MAIN/PRG_09_Supervision.st`](../CODE/MAIN/PRG_09_Supervision.st) — **mise à jour**
  (nouveau champ IHM `BrakeThermalFault`, demande utilisateur explicite)
- Voir aussi [`CODE/MAIN/PRG_00_Inputs.st`](../CODE/MAIN/PRG_00_Inputs.st) et
  [`CODE/SIMULATION/GVL_Simulation.st`](../CODE/SIMULATION/GVL_Simulation.st) — modifiés dans le
  même lot mais documentés côté Partie9 v1.6 §6 (signal commun, source unique)

*(Pas de recopie du corps ici — voir les fichiers `CODE/` pour le ST complet, règle anti-doublon.)*

---

## 📝 7. Note d'application CODESYS 3.5 (manuel)

🔴 **Ce lot n'est pas prêt à être collé intégralement** : la branche `ETHERCAT` porte des TBD
protocolaires (§4). Deux options :

1. **Appliquer uniquement la branche `DEGRADED_IO`** dès maintenant (relais + PV/GV), en laissant
   `CommMode` figé à `DEGRADED_IO` et les entrées `ETHERCAT` (`DriveStatusWord`,
   `DriveActualFreqHz`) câblées à des stubs neutres (0) le temps de fiabiliser le bus — même
   logique que le stub `GVL_Winch_M1_Stub` de la Partie9 §7 Étape 9bis.
2. **Attendre la confirmation du protocole AC600** (doc constructeur) avant de coller
   `FB_Chariot` en entier, pour ne pas introduire un mot de commande erroné qui pourrait
   déclencher un comportement inattendu du variateur.

👉 **Recommandation** : option 1 — le besoin exprimé est justement de disposer d'un axe M3
opérationnel pendant que l'EtherCAT est en panne. Étapes (une fois validées) :
1. Créer `E_ChariotCommMode` (DUT Enumeration).
2. Créer dossier `CHARIOT` (si absent) → `FB_Chariot` (POU Function Block, ST).
3. Créer `FB_Safety_Chariot` dans `SAFETY` (dossier existant).
4. Câbler dans `PRG_MAIN` : `CommMode := E_ChariotCommMode.DEGRADED_IO` (figé, en attendant
   IHM/sélecteur maintenance), `DriveStatusWord := 0`, `DriveActualFreqHz := 0.0` (stubs neutres).
5. I/O Mapping : relais sens + PV/GV + retours (Mapping §5) sur les canaux physiques réels.
6. **Rebuild** — 0 erreur avant tout téléchargement automate.
7. **Paramétrage AC600 + verrouillage source de commande** (§4bis) — avant toute mise sous tension
   avec le PLC actif.

### ✅ Avant le premier essai réel (mouvement machine)

À faire **dans cet ordre**, avant tout essai en charge :
1. Vérifier §4bis entièrement réglé (PV très basse, source de commande verrouillée Terminal).
2. **Essai à vide** (axe débrayé si possible, ou machine non chargée) : valider `RelayFwd`/`RelayRev`
   séparément, sens physique conforme au joystick.
3. Valider l'interlock de sens : tenter une inversion directe Fwd→Rev en mouvement → doit être
   bloquée jusqu'à `DegradedStopSettleTime` écoulé après coupure relais.
4. Valider la double vérification contacteurs (`FwdContactorCheck`/`RevContactorCheck`) :
   débrancher volontairement un retour contacteur → `ErrorId` doit se lever, sorties coupées.
5. Valider l'arrêt sur capteur (§9bis) à vitesse **PV uniquement**, machine non chargée, avant
   tout essai à vitesse GV ou en charge.
6. Seulement après ces 5 points validés : essai en charge, montée progressive PV→GV.

### 🆕 v1.3 — Thermique frein commun (2026-07-08)
Tous les fichiers listés en §6 sont **déjà à jour dans `CODE/`** — réimport via bundle
PLCopenXML (`CODE/CODE_Bundle.xml`) ou recopie manuelle ST habituelle.
**Reste à faire côté utilisateur** (même canal physique que Partie9 v1.6, un seul fil pour les
3 axes — pas de mapping supplémentaire spécifique Chariot) :
1. **I/O Mapping** : mapper `BrakeThermalFeedback_DI` (retour thermique frein, contact NC,
   commun aux 3 axes) sur l'entrée TOR physique réelle — **une seule fois**, pas par axe.
2. **Rebuild** — 0 erreur avant tout téléchargement automate.
3. Voir checklist REX §8 pour la procédure de test (perte du retour → `PowerCutOff` sur les
   3 axes simultanément).

---

## 🔁 8. Retour d'expérience

- [x] **Intégré dans `PRG_MAIN` (2026-07-02, revue par une 2ᵉ IA/session)** : `instSafetyChariotM3`
      + `instChariotM3`, `CommMode` figé `DEGRADED_IO`, câblé sur `FB_Joystick_0.AxisCmdX`.
      Stubs `GVL_Chariot_M3_Stub` (relais/retours/capteur cible), même principe que
      `GVL_Winch_M1_Stub`/`M2_Stub`.

📌 Suivi (checklist de mise en service restante — finding `IsStoppedConfirmed`/`ETHERCAT`, essai à
vide, réglages `DegradedStopSettleTime`/PV-GV/frein, verrou `CommMode`, protocole AC600,
`BrakeThermalFeedback_DI`) : voir `DOC/PLAN_TASK_v1.0.md` §3 (T26).

---

## 📚 Documents liés
- **Partie 2 v2.11** — Architecture (`FB_Chariot`, mapping M3/AC600).
- **Partie 3 v1.3** — Contrat FB (`StartStop`/`SafeStop`, ErrorId, reset, §1bis FB de mouvement).
- **Partie 4 v1.2** — Cycle (§5 Chariot — approche temporisée, arrêt sur capteur, source des paramètres `ApproachTime`/`ApproachSpeed`).
- **Partie 9 v1.6** — Fonction Winch (patterns réutilisés : interlock sens, `FB_Brake`,
  `FB_Safety_<Metier>`, `HYSTERESIS` ; 🆕 signal commun thermique frein + escalade `PowerCutOff`,
  voir §4sexies — même signal consommé ici en §4ter).

# 📋 Analyse Fonctionnelle — Partie 5 : Modes & Maintenance (v1.6)

> **Version 1.6 (2026-07-15)** — TASK-0001 : Arbitrage de la sélection JoystickWinchSelect (M1 seul/M2 seul/Couplé) réservé au mode MAINT_N2, forcé à Couplé (3) dans tous les autres modes.
>
> **Version 1.5** — Nettoyage documentaire (audit doc) : la remarque "GVL d'échange IHM à créer
> (à définir)" (§6) était organisationnelle — remplacée par un renvoi court vers
> `DOC/PLAN_TASK_v1.0.md` §3 (T18). Aucun changement fonctionnel. Corrige au passage le nom de
> fichier, resté suffixé `_v1.3` alors que le contenu interne était déjà en v1.4 (voir bandeau
> ci-dessous).
> 📌 **État d'implémentation (2026-07-08, AUDIT)** : `FB_Modes` **codé et enrichi** —
> `CODE/MODES/FB_Modes.st` + `GVL_Modes_Stub.st`. Diffuse `Mode` (remplace les 10 `E_Mode.MAINT_N1`
> codés dans les programmes métier dédiés), refuse `SEMI_AUTO` si défaut codeur (`FB_Encoder_Safety`),
> refuse `MAINT_N2` sans mot de passe (stub), sort `SyncEnable` (→ `FB_WinchSync`).
> **v1.4 (2026-07-08)** — Lot #9-17 : Intégration de l'inhibition unitaire des treuils (M1 ou M2) en `MAINT_N2` avec isolation complète de la sécurité (blocs de commande et de sécurité désactivés, erreurs effacées), exclusion mutuelle, filtrage supervision de `AnyFaultActive` et désactivation forcée de `SyncEnable`.
> **Version 1.3 (2026-07-08)** — D_SYNCEN : Polarité inversée de `OverrideSync` → `SyncEnable` ; `TRUE` = synchro active (logique positive), défaut démande IHM devenu `TRUE`; pseudo-codes et descriptions mises à jour en conséquence.
> **Version 1.2 (2026-07-04)** — Renommage terminologique (demande utilisateur) : Bucket→Benne
> (`OverrideBucket`, `FB_Bucket`), Translation→Translation — préfixe I/O physique M3 inchangé.
> **Version 1.1** — Suite audit documentaire : correction du pseudo-code d'override (§2) qui
> plaçait à tort la limite légale dans `FB_Safety` (elle est **exclusivement** gérée par
> `FB_Modes`, §3) ; `CoupeEnable` retiré (jamais une variable) au profit de `SafeStop`/`StartStop` ;
> `FB_Watchdog` retiré (fonction système CODESYS, pas un FB applicatif) ; `SafetyOk` renommé
> `EmergencyStopOk`.
> **Version 1.0** — Modes de marche, niveaux de maintenance et droits associés,
> articulation AU / `SafeStop`, limite légale de dragage, stratégie de pertes/défauts.
>
> 🔗 Dépend de : Partie 2 v2.5 (architecture, `FB_Modes`, `SafeStop`), Partie 4 (cycle).

---

## 🎚️ 1. Modes de marche (`E_Mode`)

```codesys
TYPE E_Mode :
ENUM
  MANUEL      := 0;   (* Pilotage joystick direct, sécurités actives *)
  MAINT_N1    := 1;   (* Manuel "encadré" : ~cycle avec interdictions, sécurité correcte *)
  MAINT_N2    := 2;   (* Droits étendus, mot de passe, override de sécurités *)
  SEMI_AUTO   := 3;   (* Séquenceur FB_Cycle (semi-automatique) *)
END_ENUM
END_TYPE
```

`FB_Modes` (appelé dans `PRG_04_Modes`) :
- sélectionne la **source de commande légitime** (joystick en Manuel/Maint, `FB_Cycle` en SemiAuto) ;
- calcule les **autorisations / interlocks** par bloc métier ;
- porte les **overrides** de Maintenance N2 ;
- **applique la limite légale de dragage** (interdiction normale, hors sécurité — voir §3) ;
- **remplace l'ancien `E_DegradationLevel`** : la dégradation se traduit par des `Enable`
  conditionnels et des `Ready` qui varient selon le mode et les interlocks.

> 🧭 Les blocs métier ont tous `Enable` et une info `Ready`. Selon le mode et les interlocks,
> `Ready` varie ; l'opérateur en est informé (message/couleur IHM). Un **vrai** problème passe
> par `Error`/`ErrorId` (et `SafeStop` du bloc safety métier concerné), pas par un niveau de
> dégradation global.

---

## 🛠️ 2. Niveaux de maintenance

### 🟢 Maintenance Niveau 1 (`MAINT_N1`)
Mode **manuel encadré** : permet de réaliser **à peu près le cycle** avec des **interdictions
ponctuelles**, mais en conservant **un niveau de sécurité correct**.

| Caractéristique | État |
|-----------------|------|
| Commande | Joystick, treuils **pilotables unitairement** (M1, M2 séparés) |
| Contrôle synchro (`FB_WinchSync`) | ✅ Actif (sauf phase benne — suspension automatique, Partie 4 §3bis) |
| **Demande de synchronisation (`SyncEnable`)** | ✅ **Disponible en MAINT_N1** (voir §6bis — `SyncEnable=FALSE` désactive la synchro et lève aussi le SafeStop mou de câble) |
| Contrôle benne (`FB_Bucket`) | ✅ Actif |
| Codeurs / freins / capteurs | ✅ Actifs (sécurités maintenues) |
| Limite légale profondeur | ⚠️ Non bloquante, **signalisation** IHM |
| Authentification | Aucune (un sélecteur de choix pourra élargir vers N2 à la marche) |

Usages : positionnement init après démarrage, tests moteurs/freins en conditions sûres,
remise en ordre légère (ex. benne à recaler en vitesse réduite).

### 🔴 Maintenance Niveau 2 (`MAINT_N2`)
Mode à **mot de passe** plus dur, **droits augmentés**, avec la possibilité de **désactiver
des sécurités** pouvant mettre en péril la machine **et les utilisateurs**. Choix **délibéré**
de l'opérateur (mot de passe + droits).

| Caractéristique | État |
|-----------------|------|
| Authentification | 🔑 Mot de passe + droits |
| Commande | Joystick, treuils **indépendants** |
| Demande de synchro | ✅ Configurable (ex. codeur mort) |
| Override contrôle benne | ⛔→ désactivable |
| Override limite légale | ⛔→ désactivable (signalisation maintenue) |
| Pilotage sans codeur | ✅ possible |
| Pilotage sans/forçant frein | ✅ possible selon droits |
| Inhibition unitaire treuil | ✅ possible (soit M1, soit M2, jamais les deux simultanément) |
| Message IHM permanent | « ⚠️ MAINT N2 — Dégradation sécurité acceptée » |

Usages **lourds** : changement de treuil / câble, changement de codeurs, remplacement de
freins, déplacements **malgré** défauts ou incohérences, récupération après panne grave.

> 🧭 N2 a pour but de **pouvoir tout faire** (maintenance lourde) en assumant explicitement la
> levée de protections, sous responsabilité de l'opérateur authentifié.

### Logique d'override (`FB_Modes`)
```
// SyncEnable est disponible en MAINT_N1 ET MAINT_N2 (D_SYNCEN, D83)
IF (Mode = MAINT_N1 OR (Mode = MAINT_N2 AND PasswordOk)) THEN
    SyncEnable   := SyncEnableRequest;   // case à cocher opérateur (MAINT_N1 ou N2), TRUE = synchro active
END_IF
IF Mode = MAINT_N2 AND PasswordOk THEN
    OverrideBucket := UserSelectIHM;
    OverrideLimit  := UserSelectIHM;
    MsgIHM := "MAINT N2 active";
END_IF

// Exclusion mutuelle des demandes d'inhibition treuils (MAINT_N2)
IF InhibitM1Request AND InhibitM2Request THEN
    // Si M1 était déjà inhibé, rejette M2. Si M2 déjà inhibé, rejette M1.
    IF PrevInhibitM1 THEN
        InhibitM2Request := FALSE;
    ELSIF PrevInhibitM2 THEN
        InhibitM1Request := FALSE;
    ELSE
        InhibitM1Request := FALSE; InhibitM2Request := FALSE;
    END_IF;
END_IF;
PrevInhibitM1 := InhibitM1Request;
PrevInhibitM2 := InhibitM2Request;

// Si l'un des treuils est inhibé, SyncEnable est désactivé et forcé à FALSE
IF InhibitM1Request OR InhibitM2Request THEN
    SyncEnable := FALSE;
END_IF;

// Arbitrage sélecteur Joystick (TASK-0001, v1.6)
// M1 seul (=1) ou M2 seul (=2) au joystick est restreint au mode MAINT_N2
// pour éviter de désynchroniser accidentellement les treuils (câble en travers).
// Forcé à Couplé (=3) dans tous les autres modes (MAINT_N1, SEMI_AUTO, DISABLE).
IF Mode = E_Mode.MAINT_N2 THEN
    JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSE
    JoystickWinchSelectArbitrated := 3; // Couplé forcé
END_IF;

// Application aux blocs concernés :
FB_WinchSync.Enable       := SyncEnable AND NOT InhibitM1Request AND NOT InhibitM2Request;  // synchro active si SyncEnable=TRUE
FB_Bucket.ControlEnable   := NOT OverrideBucket;
LimitLegal.Enabled        := NOT OverrideLimit;  // interne à FB_Modes (PAS FB_Safety, voir §3)

// Activation unitaire des treuils et de leur sécurité
FB_WinchM1.Enable          := NOT InhibitM1Request;
FB_Safety_WinchM1.Enable   := NOT InhibitM1Request;
FB_WinchM2.Enable          := NOT InhibitM2Request;
FB_Safety_WinchM2.Enable   := NOT InhibitM2Request;

IF NOT (Mode = MAINT_N1 OR Mode = MAINT_N2) THEN
    SyncEnable := TRUE; OverrideBucket := FALSE; OverrideLimit := FALSE;  // synchro active par défaut, autres overrides désactivés
END_IF
```

> ⚠️ **Inhibition et isolation des défauts** : Lorsqu'un treuil est inhibé (ex: `InhibitM1Request = TRUE`), l'entrée `Enable` de `FB_WinchM1` et `FB_Safety_WinchM1` passe à `FALSE`, forçant leurs sorties d'erreur respectives `Error := FALSE` et `ErrorId := 16#0000`. De plus, dans le programme de supervision `PRG_09_Supervision`, les défauts de l'axe inhibé sont dynamiquement ignorés dans le calcul de `GVL_IHM.Modes.AnyFaultActive`.

> ⚠️ **Correction v1.1** : la limite légale n'est **jamais** portée par un bloc safety
> (`FB_Safety_<Metier>`) — c'est une interdiction **normale**, gérée en interne à `FB_Modes`
> (voir §3). L'ancienne formulation `FB_Safety.CheckLimitLegal` était une erreur de conception.

> 🔧 **Correction v1.3 (D_SYNCEN, D83)** : Polarité inversée de `SyncEnable` ; `TRUE` = synchro
> active (avant : `OverrideSync`, `TRUE` = synchro désactivée). Pseudo-codes et descriptions
> mises à jour. `SyncEnable` accessible **dès MAINT_N1** (pas seulement N2).

---

## 📏 3. Limite légale de dragage (`ST_LimitLegal`)

Ce n'est **pas** une fonction de sécurité (machine), mais une **interdiction normale**
réglementaire : interdiction de draguer sous une cote imposée.

```codesys
TYPE ST_LimitLegal :
STRUCT
  DepthMinAllowed : REAL;   (* m ; cote min autorisée (ex. négatif sous le plan d'eau) *)
  Enabled         : BOOL;   (* Active en SEMI_AUTO *)
END_STRUCT
END_TYPE
```

- **Paramètre IHM** saisi par l'opérateur, **mémorisé** (RETAIN).
- **Actif en mode semi-automatique, en descente uniquement.**
- En **Maintenance N1/N2** : **pas de blocage**, mais **signalisation IHM** à l'opérateur
  (qui peut donc dépasser la cote sous sa responsabilité).
- C'est **`FB_Modes`**, et **uniquement** `FB_Modes`, qui **ordonne** l'application
  (autorise/interdit la descente) — **jamais** un bloc safety (ce n'est pas un défaut machine).

```
IF Mode = SEMI_AUTO AND LimitLegal.Enabled
   AND Step IN (DESCENDING_OPEN, DESCENDING_OPEN_DUMP) THEN
    IF Depth_m < LimitLegal.DepthMinAllowed THEN
        Enable_Descente := FALSE;       // interdiction normale (FB_Modes, pas SafeStop)
        MsgIHM := "Limite profondeur atteinte";
    END_IF
ELSIF Mode IN (MAINT_N1, MAINT_N2) THEN
    MsgIHM := "Limite dépassée (maintenance)";   // signalisation seule
END_IF
```

---

## 🟥 4. Arrêt d'urgence (AU) vs `SafeStop` (rappel/synthèse)

> Détail complet en Partie 2 v2.5 §6. Synthèse ici car central pour les modes.

| Couche | Mécanisme | Effet |
|--------|-----------|-------|
| Matérielle | Bouton coup-de-poing (opérateur) | Coupe le **contacteur de puissance** → moteurs OFF **brutalement** + freins collés. Automate/CC restent alimentés, continuent de surveiller. |
| Logiciel → Matériel | Sortie automate **`PowerCutOff`** | Déclenche la coupure AU si un **contacteur de puissance reste collé** (treuil incontrôlable). |
| Logicielle | **`SafeStop`** (sortie d'un bloc safety **métier**, une par domaine) | Met le(s) FB de mouvement du domaine en **rampe de décélération rapide** sur défaut (`Enable` maintenu), pour que l'opérateur traite le problème. Ce **n'est pas** l'AU : **seul l'AU coupe brutalement**. |

🧭 L'AU est **indépendant** et **prioritaire**. `SafeStop` gère les défauts process de façon
**propre** (rampe d'arrêt rapide mais non destructive, freins, message) — **par métier**, pas un
signal global. `EmergencyStopOk` (entrée FB, anciennement `SafetyOk`) reflète « AU réarmé +
conditions globales OK ».

---

## ⚠️ 5. Stratégie de pertes & défauts (codeur / bus / joystick)

### En cycle : perte d'un codeur (ou bus, ou joystick)
```
1. Détection (FB_Encoder_Abs / FB_DiagEthercat / FB_DiagCanOpen) → FB_Safety_<Metier> concerné
2. FB_Safety_<Metier>.SafeStop := TRUE
3. Les FB de mouvement du domaine : rampe de décélération RAPIDE mais NON destructive
     (Enable maintenu le temps du ralentissement maîtrisé, pas de coupure brutale)
4. Freins se collent (FB_Brake) en fin de rampe
5. Message IHM : "Erreur codeur — cycle impossible"
6. Obligation de passer en MAINTENANCE.
```

### Récupération (exemple : codeur M1 mort)
```
- L'axe treuil M1 est SIGNALÉ en défaut ; ses commandes seront compliquées/inopérantes.
- Le treuil M2 reste fonctionnel (ex. ouvrir/fermer benne possible via M2).
- Meilleure pratique : passer en MAINT_N2 :
    → choisir de remonter SYNCHRONE mais SANS contrôle de synchronisme
      (codeurs morts → désactiver SyncEnable) ;
    → piloter les contacteurs, les deux moteurs (sains) montent ensemble ;
    → revenir en position, puis aller RÉPARER le codeur.
```

> 🧭 La philosophie : **sur défaut, on s'arrête proprement** (rampe rapide non abîmante,
> freins collés, message), **on n'enchaîne jamais** en aveugle, et la reprise se fait en
> maintenance avec, si nécessaire, des overrides **assumés** en N2.

### Surveillance périodicité des tâches
Assurée par la **fonction système CODESYS** (watchdog de tâche configuré en propriétés de
tâche, seuil **200 ms**) — **pas de `FB_Watchdog` applicatif** (voir Partie 2 v2.5 §2). Un
dépassement remonte comme défaut système, répercuté en `SafeStop` par le bloc safety concerné.

---

## 🖥️ 6. Échange IHM (principe, pas de spec IHM ici)

> Pas de spécification IHM détaillée à ce stade (mapping manuel par l'intégrateur).

Règle de conception : **prévoir, en sortie de chaque FB, de l'information pensée « IHM utilisateur »**.
- `FB_Cycle` : numéro d'étape (`E_CycleStep`), conditions, demandes d'action.
- FB métier : `State`, `Ready`, `Error`, `ErrorId` (bitfield), `SafeStop` (par domaine),
  warnings (`SyncWarn`, `ForceImbalance`…), positions, vitesses estimées.
- Les **textes** des messages sont écrits **dans l'IHM** ; les FB exposent des **mots / bits / valeurs**
  que l'intégrateur **mappe** manuellement (DFD entrée pour les paramètres, sortie pour l'affichage).
- Une **GVL d'échange IHM** est le seul usage de GVL envisagé, l'état interne machine restant
  porté par les E/S des FB. 📌 Suivi (création ou non) : voir `DOC/PLAN_TASK_v1.0.md` §3 (T18).

---

## 🔒 6bis. Rôle complet de `SyncEnable` (D_SYNCEN, D83, 2026-07-08)

`SyncEnable` est une **demande de synchronisation** (case à cocher IHM, conditionné par
l'activation d'un niveau de Maintenance) qui réunit **trois effets simultanés** :

| Effet | Détail |
|-------|--------|
| **Active la synchronisation** | `FB_WinchSync.Enable := TRUE` — calcul `DeltaPosM`/`SyncWarn`, surveillance d'écart active (par défaut) |
| **Active le contrôle de cohérence des commandes** | `FB_WinchSync` étant `Enable=TRUE`, le SafeStop de cohérence de commande est armé ; si `SyncEnable=FALSE`, le bit1 `ErrorId WinchSync` est inhibé et effacé |
| **Lève ou maintient le SafeStop mou de câble selon l'état** | `FB_Safety_Winch` : si `SyncEnable=FALSE`, le bit3 n'alimente plus `SafeStop` mais active `ForbidAscent` (montée interdite M1+M2) et laisse la descente libre (pour rattraper le câble) — voir Partie9 §4ter et D_SLACK_1 |

**Disponibilité** : `SyncEnable` est accessible **dès MAINT_N1** (sans mot de passe) et bien
sûr en MAINT_N2. Les autres overrides (`OverrideBucket`, `OverrideLimit`) restent
**exclusifs à MAINT_N2** (droits étendus, mot de passe requis).

> ⚠️ **Rappel sécurité** : avec `SyncEnable=FALSE` (demande de synchro désactivée), l'opérateur
> pilote M1 et M2 **sans aucun contrôle d'écart de position**. Il est responsable de la cohérence
> du mouvement. `ForbidAscent` reste actif tant que `SlackCableDetected = TRUE` : on ne peut pas
> aggraver le mou en remontant, mais la cause doit être réglée avant de reprendre un
> mouvement synchrone normal.

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (`FB_Modes`, `SafeStop`/`StartStop`, AU).
- **Partie 3 v1.2** — Contrat FB (`Mode`, `EmergencyStopOk`, `SafeStop`, reset).
- **Partie 4** — Cycle (étapes, synchro, benne, rampes).
- **Partie 6** — Conditionnement E/S.

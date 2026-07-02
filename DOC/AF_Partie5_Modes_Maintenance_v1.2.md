# 📋 Analyse Fonctionnelle — Partie 5 : Modes & Maintenance (v1.2)

> **Version 1.2** — Renommage terminologique (demande utilisateur, 2026-07-02) : Bucket→Grappin
> (`OverrideGrappin`, `FB_Grappin`), Translation→Chariot — préfixe I/O physique M3 inchangé.
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

`FB_Modes` (appelé dans `PLC_PRG_MAIN`) :
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
| Contrôle synchro (`FB_WinchSync`) | ✅ Actif (sauf phase grappin — suspension automatique, Partie 4 §3bis) |
| Contrôle grappin (`FB_Grappin`) | ✅ Actif |
| Codeurs / freins / capteurs | ✅ Actifs (sécurités maintenues) |
| Limite légale profondeur | ⚠️ Non bloquante, **signalisation** IHM |
| Authentification | Aucune (un sélecteur de choix pourra élargir vers N2 à la marche) |

Usages : positionnement init après démarrage, tests moteurs/freins en conditions sûres,
remise en ordre légère (ex. grappin à recaler en vitesse réduite).

### 🔴 Maintenance Niveau 2 (`MAINT_N2`)
Mode à **mot de passe** plus dur, **droits augmentés**, avec la possibilité de **désactiver
des sécurités** pouvant mettre en péril la machine **et les utilisateurs**. Choix **délibéré**
de l'opérateur (mot de passe + droits).

| Caractéristique | État |
|-----------------|------|
| Authentification | 🔑 Mot de passe + droits |
| Commande | Joystick, treuils **indépendants** |
| Override synchro | ⛔→ désactivable (ex. codeur mort) |
| Override contrôle grappin | ⛔→ désactivable |
| Override limite légale | ⛔→ désactivable (signalisation maintenue) |
| Pilotage sans codeur | ✅ possible |
| Pilotage sans/forçant frein | ✅ possible selon droits |
| Message IHM permanent | « ⚠️ MAINT N2 — Dégradation sécurité acceptée » |

Usages **lourds** : changement de treuil / câble, changement de codeurs, remplacement de
freins, déplacements **malgré** défauts ou incohérences, récupération après panne grave.

> 🧭 N2 a pour but de **pouvoir tout faire** (maintenance lourde) en assumant explicitement la
> levée de protections, sous responsabilité de l'opérateur authentifié.

### Logique d'override (`FB_Modes`)
```
IF Mode = MAINT_N2 AND PasswordOk THEN
    OverrideSync   := UserSelectIHM;   // case à cocher opérateur
    OverrideGrappin := UserSelectIHM;
    OverrideLimit  := UserSelectIHM;
    // application aux blocs concernés :
    FB_WinchSync.Enable       := NOT OverrideSync;
    FB_Grappin.ControlEnable   := NOT OverrideGrappin;
    LimitLegal.Enabled        := NOT OverrideLimit;   // interne à FB_Modes (PAS FB_Safety, voir §3)
    MsgIHM := "MAINT N2 active";
ELSE
    OverrideSync := FALSE; OverrideGrappin := FALSE; OverrideLimit := FALSE;  // tout actif
END_IF
```

> ⚠️ **Correction v1.1** : la limite légale n'est **jamais** portée par un bloc safety
> (`FB_Safety_<Metier>`) — c'est une interdiction **normale**, gérée en interne à `FB_Modes`
> (voir §3). L'ancienne formulation `FB_Safety.CheckLimitLegal` était une erreur de conception.

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
| Matérielle | Bouton coup-de-poing **ou** câble mécanique « montée excessive » | Coupe le **contacteur de puissance** → moteurs OFF **brutalement** + freins collés. Automate/CC restent alimentés, continuent de surveiller. |
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
- Le treuil M2 reste fonctionnel (ex. ouvrir/fermer grappin possible via M2).
- Meilleure pratique : passer en MAINT_N2 :
    → choisir de remonter SYNCHRONE mais SANS contrôle de synchronisme
      (codeurs morts → override OverrideSync) ;
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
- Une **GVL d'échange IHM** *pourra* être créée à cette fin (à définir) — c'est le seul usage
  de GVL envisagé, l'état interne machine restant porté par les E/S des FB.

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (`FB_Modes`, `SafeStop`/`StartStop`, AU).
- **Partie 3 v1.2** — Contrat FB (`Mode`, `EmergencyStopOk`, `SafeStop`, reset).
- **Partie 4** — Cycle (étapes, synchro, grappin, rampes).
- **Partie 6** — Conditionnement E/S.

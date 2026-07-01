# 📋 Analyse Fonctionnelle — Partie 5 : Modes & Maintenance

> **Version 1.0** — Modes de marche, niveaux de maintenance et droits associés,
> articulation AU / `CoupeEnable`, limite légale de dragage, stratégie de pertes/défauts.
>
> 🔗 Dépend de : Partie 2 v2.4 (architecture, `FB_Modes`, `CoupeEnable`), Partie 4 (cycle).

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

`FB_Modes` (dans `PRG_MODES`) :
- sélectionne la **source de commande légitime** (joystick en Manuel/Maint, `FB_Cycle` en SemiAuto) ;
- calcule les **autorisations / interlocks** par bloc métier ;
- porte les **overrides** de Maintenance N2 ;
- **remplace l'ancien `E_DegradationLevel`** : la dégradation se traduit par des `Enable`
  conditionnels et des `Ready` qui varient selon le mode et les interlocks.

> 🧭 Les blocs métier ont tous `Enable` et une info `Ready`. Selon le mode et les interlocks,
> `Ready` varie ; l'opérateur en est informé (message/couleur IHM). Un **vrai** problème passe
> par `Error`/`ErrorId`, pas par un niveau de dégradation global.

---

## 🛠️ 2. Niveaux de maintenance

### 🟢 Maintenance Niveau 1 (`MAINT_N1`)
Mode **manuel encadré** : permet de réaliser **à peu près le cycle** avec des **interdictions
ponctuelles**, mais en conservant **un niveau de sécurité correct**.

| Caractéristique | État |
|-----------------|------|
| Commande | Joystick, treuils **pilotables unitairement** (M1, M2 séparés) |
| Contrôle synchro (`FB_WinchSync`) | ✅ Actif |
| Contrôle godet (`FB_Bucket`) | ✅ Actif |
| Codeurs / freins / capteurs | ✅ Actifs (sécurités maintenues) |
| Limite légale profondeur | ⚠️ Non bloquante, **signalisation** IHM |
| Authentification | Aucune (un sélecteur de choix pourra élargir vers N2 à la marche) |

Usages : positionnement init après démarrage, tests moteurs/freins en conditions sûres,
remise en ordre légère (ex. godet à recaler en vitesse réduite).

### 🔴 Maintenance Niveau 2 (`MAINT_N2`)
Mode à **mot de passe** plus dur, **droits augmentés**, avec la possibilité de **désactiver
des sécurités** pouvant mettre en péril la machine **et les utilisateurs**. Choix **délibéré**
de l'opérateur (mot de passe + droits).

| Caractéristique | État |
|-----------------|------|
| Authentification | 🔑 Mot de passe + droits |
| Commande | Joystick, treuils **indépendants** |
| Override synchro | ⛔→ désactivable (ex. codeur mort) |
| Override contrôle godet | ⛔→ désactivable |
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
    OverrideBucket := UserSelectIHM;
    OverrideLimit  := UserSelectIHM;
    // application aux blocs concernés :
    FB_WinchSync.Enable        := NOT OverrideSync;
    FB_Bucket.ControlEnable    := NOT OverrideBucket;
    FB_Safety.CheckLimitLegal  := NOT OverrideLimit;
    MsgIHM := "MAINT N2 active";
ELSE
    OverrideSync := FALSE; OverrideBucket := FALSE; OverrideLimit := FALSE;  // tout actif
END_IF
```

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
- C'est **`FB_Modes`** qui **ordonne** l'application (autorise/interdit la descente),
  pas `FB_Safety` (ce n'est pas un défaut machine).

```
IF Mode = SEMI_AUTO AND LimitLegal.Enabled
   AND Step IN (DESCENDING_OPEN, DESCENDING_OPEN_DUMP) THEN
    IF Depth_m < LimitLegal.DepthMinAllowed THEN
        Enable_Descente := FALSE;       // interdiction normale
        MsgIHM := "Limite profondeur atteinte";
    END_IF
ELSIF Mode IN (MAINT_N1, MAINT_N2) THEN
    MsgIHM := "Limite dépassée (maintenance)";   // signalisation seule
END_IF
```

---

## 🟥 4. Arrêt d'urgence (AU) vs `CoupeEnable` (rappel/synthèse)

> Détail complet en Partie 2 v2.4 §6. Synthèse ici car central pour les modes.

| Couche | Mécanisme | Effet |
|--------|-----------|-------|
| Matérielle | Bouton coup-de-poing **ou** câble mécanique « montée excessive » | Coupe le **contacteur de puissance** → moteurs OFF + freins collés. Automate/CC restent alimentés. |
| Logiciel → Matériel | Sortie automate **`PowerCutOff`** | Déclenche la coupure AU si un **contacteur de puissance reste collé** (treuil incontrôlable). |
| Logicielle | **`FB_Safety.CoupeEnable`** | Met la machine en **état sûr** sur défaut (coupe les `Enable`), pour que l'opérateur traite le problème. Ce **n'est pas** l'AU. |

🧭 L'AU est **indépendant** et **prioritaire**. `CoupeEnable` gère les défauts process de façon
**propre** (rampe d'arrêt non destructive, freins, message). `SafetyOk` (entrée FB) reflète
« AU réarmé + conditions globales OK ».

---

## ⚠️ 5. Stratégie de pertes & défauts (codeur / bus / joystick)

### En cycle : perte d'un codeur (ou bus, ou joystick)
```
1. Détection (FB_Encoder_Abs / FB_DiagEthercat / FB_DiagCanOpen) → FB_Safety
2. FB_Safety.CoupeEnable := TRUE
3. PRG_MAIN retire les Enable → ARRÊT sur RAMPE plus RAIDE mais NON destructive
     (relais activés le temps d'un ralentissement maîtrisé, pas de coupure brutale)
4. Freins se collent (FB_Brake)
5. Message IHM : "Erreur codeur — cycle impossible"
6. Obligation de passer en MAINTENANCE.
```

### Récupération (exemple : codeur M1 mort)
```
- L'axe treuil M1 est SIGNALÉ en défaut ; ses commandes seront compliquées/inopérantes.
- Le treuil M2 reste fonctionnel (ex. ouvrir/fermer godet possible via M2).
- Meilleure pratique : passer en MAINT_N2 :
    → choisir de remonter SYNCHRONE mais SANS contrôle de synchronisme
      (codeurs morts → override OverrideSync) ;
    → piloter les contacteurs, les deux moteurs (sains) montent ensemble ;
    → revenir en position, puis aller RÉPARER le codeur.
```

> 🧭 La philosophie : **sur défaut, on s'arrête proprement** (rampe rapide non abîmante,
> freins collés, message), **on n'enchaîne jamais** en aveugle, et la reprise se fait en
> maintenance avec, si nécessaire, des overrides **assumés** en N2.

### Watchdog
`FB_Watchdog` : seuil **200 ms** sur toutes les tâches. Dépassement → `ErrorId` → `FB_Safety`
→ `CoupeEnable` → arrêt sûr.

---

## 🖥️ 6. Échange IHM (principe, pas de spec IHM ici)

> Pas de spécification IHM détaillée à ce stade (mapping manuel par l'intégrateur).

Règle de conception : **prévoir, en sortie de chaque FB, de l'information pensée « IHM utilisateur »**.
- `FB_Cycle` : numéro d'étape (`E_CycleStep`), conditions, demandes d'action.
- FB métier : `State`, `Ready`, `Error`, `ErrorId` (bitfield), warnings (`SyncWarn`, `ForceImbalance`…),
  positions, vitesses estimées.
- Les **textes** des messages sont écrits **dans l'IHM** ; les FB exposent des **mots / bits / valeurs**
  que l'intégrateur **mappe** manuellement (DFD entrée pour les paramètres, sortie pour l'affichage).
- Une **GVL d'échange IHM** *pourra* être créée à cette fin (à définir) — c'est le seul usage
  de GVL envisagé, l'état interne machine restant porté par les E/S des FB.

---

## 📚 Documents liés
- **Partie 2 v2.4** — Architecture (`FB_Modes`, `CoupeEnable`, AU).
- **Partie 3 (v1.1)** — Contrat FB (`Mode`, `SafetyOk`, reset).
- **Partie 4** — Cycle (étapes, synchro, godet, rampes).
- **Partie 6** — Conditionnement E/S.
</content>

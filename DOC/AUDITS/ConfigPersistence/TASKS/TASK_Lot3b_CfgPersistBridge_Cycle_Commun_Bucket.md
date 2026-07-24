# 📋 Document de Tâche — Lot 3b : Généralisation `FB_CfgPersistBridge` à Cycle / Commun / Bucket

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 3a (pilote `FB_CfgPersistBridge_SyncCfg` sur `M1M2Sync`, fait et vérifié, commit
> `8e1aac6`) — ce lot applique le MÊME pattern, déjà validé en usage réel, à **3 autres domaines
> singleton** (une seule instance chacun, comme Sync). Indépendant du Lot 3a, ne touche aucun de
> ses fichiers.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande. Ce lot touche `GVL_PERSISTENT` (variables
  `PERSISTENT RETAIN`) sur 3 domaines à la fois — sois particulièrement attentif à ne pas mélanger
  les 3 (chaque domaine a son propre FB, sa propre variable persistante, ses propres fichiers).
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §6** — toute modification hors périmètre doit être
  signalée séparément, jamais appliquée silencieusement en plus de ce qui est demandé.
  **Ce lot NE TOUCHE PAS `Winch` (`M1TreuilRetenue`/`M2TreuilBenne`, hors `.Bucket`)** — ce domaine
  a une complexité propre (4 champs partagés entre M1/M2 avec réconciliation) reportée à un lot
  séparé, décision déjà prise avec l'utilisateur. Ne pas l'anticiper ni le "corriger au passage".
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté.** Pointeurs utiles :
  - `CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st` — le FB pilote déjà en place et vérifié, **le
    style et la logique exacts à reproduire** pour les 3 nouveaux FB de ce lot (seul le type
    `ST_XxxCfg` change).
  - `DOC/AUDITS/ConfigPersistence/TASKS/TASK_Lot3a_CfgPersistBridge_Pilote_Sync.md` — le document
    du pilote, pour voir comment le premier a été spécifié et vérifié.
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier** — les 3 blocs à remplacer sont proches les uns
    des autres (restauration en section 2, sauvegarde en section 3) mais bien distincts.
  - Si aucun de ces pointeurs ne suffit à lever le doute : arrête-toi et signale.

## 1. Contexte

Le Lot 3a a validé en usage réel le pattern `FB_CfgPersistBridge_<Type>` sur `M1M2Sync.Cfg` (1
champ, 1 instance). Ce lot (3b) généralise le MÊME pattern à **3 domaines qui partagent la même
caractéristique "singleton"** (une seule instance dans `GVL_IHM`, pas de duplication M1/M2 comme
Winch) :

| Domaine | Type `Cfg` | Instance IHM | Nb champs métier |
|---|---|---|---|
| Cycle | `ST_CycleCfg` | `GVL_IHM.Cycle.Cfg` | 2 (`SetDepth_M`, `SetOffset_M`) |
| Commun | `ST_CommunCfg` | `GVL_IHM.Commun.Cfg` | 3 (`LimitLegalDepthMinAllowed_M`, `LimitLegalEnabled`, `SelHomingApproachEnable`) |
| Bucket | `ST_BucketCfg` | `GVL_IHM.M2TreuilBenne.Bucket.Cfg` | 2 (`Config` — sous-struct `ST_BucketConfig`, `CfgTimeoutDuration`) |

⚠️ **`Winch` (`ST_WinchCfg`, instances `M1TreuilRetenue`/`M2TreuilBenne`) est explicitement HORS
PÉRIMÈTRE de ce lot** — 4 de ses 11 champs sont partagés entre M1 et M2 avec une logique de
réconciliation ("dernier qui écrit gagne, puis remiroir sur les deux"), incompatible avec le
pattern simple 1-instance-1-persist du pont générique. Traité dans un lot séparé une fois cette
particularité résolue.

### 🔍 Découvertes en préparant ce lot — consommateurs directs hors `PRG_09_Supervision.st`

Comme pour `_WinchSyncTolerance_M` au Lot 3a, certaines variables `GVL_PERSISTENT` à remplacer
sont lues **directement par `PRG_06_WinchControl.st`** (tâche exécutée en position 6, AVANT
`PRG_09_Supervision.st` en position 9 — lire la variable `GVL_PERSISTENT` plutôt que le champ
`GVL_IHM.Xxx.Cfg` correspondant est donc **structurellement nécessaire**, pas un choix de style :
la restauration boot n'a pas encore eu lieu au moment où `PRG_06` s'exécute dans le même scan).
Détail exact en §5.

### 🆕 Effet de bord positif — 2 champs qui gagnent une VRAIE persistance pour la première fois

- `GVL_IHM.Commun.Cfg.SelHomingApproachEnable` était restauré à une valeur **codée en dur**
  (`FALSE`) au boot, jamais sauvegardée — limitation connue et acceptée au Lot 2c. Le nouveau
  struct miroir `_CommunCfgPersist : ST_CommunCfg` inclut CE champ nativement (même type que
  `Hmi`) → il obtient une vraie persistance **gratuitement**, comme conséquence naturelle du
  passage au miroir de struct complet. C'est voulu, pas un dérapage de scope.
- `GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration` était dans la même situation (toujours
  remis à `T#30s`, jamais sauvegardé) — même effet de bord positif via `_BucketCfgPersist : ST_BucketCfg`.

**Ne pas essayer de retirer ces 2 gains de scope "pour rester minimal"** — ils sont la conséquence
directe et voulue de la bonne façon de faire (miroir de type complet), pas un ajout séparé à
justifier.

### ⚠️ Reset unique accepté (rappel du Lot 3a, même principe)

Chaque remplacement d'une variable plate `GVL_PERSISTENT` par un champ de struct fait perdre sa
valeur actuelle au premier téléchargement de ce lot (retour au défaut compilé). **Déjà confirmé
acceptable par l'utilisateur** (aucune calibration critique en jeu aujourd'hui) — ne pas tenter de
compenser, ne pas réinventer une migration transitoire.

## 2. Objectif

1. Créer 3 nouveaux FB dans `CODE/COMMUN/` : `FB_CfgPersistBridge_CycleCfg`,
   `FB_CfgPersistBridge_CommunCfg`, `FB_CfgPersistBridge_BucketCfg` — même structure exacte que
   `FB_CfgPersistBridge_SyncCfg` (voir §4), seul le type `ST_XxxCfg` change.
2. Modifier `CODE/GVL_PERSISTENT.st` : remplacer les variables plates des 3 domaines par leurs
   structs miroir respectifs (voir §5).
3. Modifier `CODE/MAIN/PRG_09_Supervision.st` : remplacer les 3 paires de blocs manuels
   (restauration + sauvegarde) par 3 appels de FB (voir §5).
4. Modifier `CODE/MAIN/PRG_06_WinchControl.st` : migrer les consommateurs directs découverts
   (`_LimitLegalDepthMinAllowed_M`/`_LimitLegalEnabled` ×8, `_BucketConfig` ×2 — voir §5).
5. Régénérer le bundle, vérifier les gates.

## 3. Types `Cfg` concernés (déjà existants, **ne pas les modifier**)

```
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M  : REAL := -12.5;
    SetOffset_M : REAL := 1.5;
    Initialized : BOOL := FALSE;
END_STRUCT
END_TYPE

TYPE ST_CommunCfg :
STRUCT
    LimitLegalDepthMinAllowed_M : REAL;
    LimitLegalEnabled           : BOOL;
    SelHomingApproachEnable     : BOOL;
    Initialized                 : BOOL := FALSE;
END_STRUCT
END_TYPE

TYPE ST_BucketCfg :
STRUCT
    Config              : ST_BucketConfig; (* OffsetOpenM, OffsetCloseM, CoherenceLimitM *)
    CfgTimeoutDuration  : TIME := T#30s;
    Initialized         : BOOL := FALSE;
END_STRUCT
END_TYPE
```
⚠️ Remarquer que `ST_CommunCfg.LimitLegalDepthMinAllowed_M`/`.LimitLegalEnabled` n'ont **pas** de
valeur par défaut dans le DUT (contrairement à Cycle/Bucket) — les vraies valeurs par défaut
viennent des anciennes variables `GVL_PERSISTENT` actuelles (`-15.0`/`TRUE`, voir §5.2), à
reproduire dans le struct miroir.

## 4. Nouveaux FB — reproduire EXACTEMENT le style/la logique de `FB_CfgPersistBridge_SyncCfg`
(déjà en place, vérifié) — seul le type change

### `CODE/COMMUN/FB_CfgPersistBridge_CycleCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_CycleCfg — Pont persistance générique pour ST_CycleCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_CycleCfg change.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_CycleCfg
VAR_IN_OUT
    Hmi     : ST_CycleCfg; (* 🖥️ ex. GVL_IHM.Cycle.Cfg *)
    Persist : ST_CycleCfg; (* 💾 ex. GVL_PERSISTENT._CycleCfgPersist *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL;
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
```

### `CODE/COMMUN/FB_CfgPersistBridge_CommunCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_CommunCfg — Pont persistance générique pour ST_CommunCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_CommunCfg change.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_CommunCfg
VAR_IN_OUT
    Hmi     : ST_CommunCfg; (* 🖥️ ex. GVL_IHM.Commun.Cfg *)
    Persist : ST_CommunCfg; (* 💾 ex. GVL_PERSISTENT._CommunCfgPersist *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL;
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
```

### `CODE/COMMUN/FB_CfgPersistBridge_BucketCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_BucketCfg — Pont persistance générique pour ST_BucketCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_BucketCfg change. La copie struct-à-struct gère aussi le sous-struct imbriqué
   Config : ST_BucketConfig automatiquement (pas de traitement spécial nécessaire).
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_BucketCfg
VAR_IN_OUT
    Hmi     : ST_BucketCfg; (* 🖥️ ex. GVL_IHM.M2TreuilBenne.Bucket.Cfg *)
    Persist : ST_BucketCfg; (* 💾 ex. GVL_PERSISTENT._BucketCfgPersist *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL;
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
```

## 5. Sweep exhaustif — par domaine, vérifié par grep, ne pas en chercher d'autres

### 5.1 — Cycle

**`CODE/GVL_PERSISTENT.st`** — état actuel (section `🔄 CYCLE`) :
```
    // 🔄 CYCLE (dragage semi-automatique)
    _CycleSetDepth_M  : REAL := -12.5; // T66 : profondeur de dragage cible (m, négative)
    _CycleSetOffset_M : REAL := 1.5;   // T66 : décalage cible de fermeture benne (m)
```
→ remplacer par :
```
    // 🔄 CYCLE (dragage semi-automatique)
    _CycleCfgPersist : ST_CycleCfg := (SetDepth_M := -12.5, SetOffset_M := 1.5); // 🌉 Pont FB_CfgPersistBridge_CycleCfg (T66, ex-variables plates)
```

**`CODE/MAIN/PRG_09_Supervision.st`** — déclarer `instCfgPersistBridgeCycle : FB_CfgPersistBridge_CycleCfg;`
dans le `VAR` (à la suite de `instCfgPersistBridgeSync`).

Bloc de restauration actuel :
```
IF NOT GVL_IHM.Cycle.Cfg.Initialized THEN
    GVL_IHM.Cycle.Cfg.SetDepth_M  := _CycleSetDepth_M;
    GVL_IHM.Cycle.Cfg.SetOffset_M := _CycleSetOffset_M;
    GVL_IHM.Cycle.Cfg.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
→ remplacer par :
```
instCfgPersistBridgeCycle(Hmi := GVL_IHM.Cycle.Cfg, Persist := _CycleCfgPersist);
IF instCfgPersistBridgeCycle.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```

Bloc de sauvegarde actuel (à supprimer entièrement) :
```
IF GVL_IHM.Cycle.Cfg.Initialized THEN
    _CycleSetDepth_M  := GVL_IHM.Cycle.Cfg.SetDepth_M;
    _CycleSetOffset_M := GVL_IHM.Cycle.Cfg.SetOffset_M;
END_IF;
```

Aucun autre fichier ne consomme `_CycleSetDepth_M`/`_CycleSetOffset_M` (vérifié exhaustivement par
grep — `PRG_05_Cycle.st` lit déjà `GVL_IHM.Cycle.Cfg.SetDepth_M` directement, pas la variable
persistante — **ne pas toucher `PRG_05_Cycle.st`**, hors périmètre, rien à y migrer).

### 5.2 — Commun

**`CODE/GVL_PERSISTENT.st`** — état actuel (section `📏 RÉGLEMENTATION / LÉGAL`) :
```
    // 📏 RÉGLEMENTATION / LÉGAL
    _LimitLegalDepthMinAllowed_M   : REAL := -15.0; // Cote min dragage autorisée (m)
    _LimitLegalEnabled           : BOOL := TRUE;  // Activation limite légale
```
→ remplacer par :
```
    // 📏 RÉGLEMENTATION / LÉGAL
    _CommunCfgPersist : ST_CommunCfg := (LimitLegalDepthMinAllowed_M := -15.0, LimitLegalEnabled := TRUE, SelHomingApproachEnable := FALSE); // 🌉 Pont FB_CfgPersistBridge_CommunCfg (ex-variables plates + SelHomingApproachEnable gagne une vraie persistance, voir §1)
```

**`CODE/MAIN/PRG_09_Supervision.st`** — déclarer `instCfgPersistBridgeCommun : FB_CfgPersistBridge_CommunCfg;`.

Bloc de restauration actuel :
```
IF NOT GVL_IHM.Commun.Cfg.Initialized THEN
    GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M := _LimitLegalDepthMinAllowed_M;
    GVL_IHM.Commun.Cfg.LimitLegalEnabled           := _LimitLegalEnabled;
    GVL_IHM.Commun.Cfg.SelHomingApproachEnable     := FALSE; (* défaut inactif *)
    GVL_IHM.Commun.Cfg.Initialized                 := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent    := TRUE;
END_IF;
```
→ remplacer par :
```
instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);
IF instCfgPersistBridgeCommun.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
(`SelHomingApproachEnable` n'est plus codé en dur à `FALSE` — il est restauré depuis
`_CommunCfgPersist.SelHomingApproachEnable`, comme les 2 autres champs. Voir §1 pour pourquoi
c'est voulu.)

Bloc de sauvegarde actuel (à supprimer entièrement) :
```
IF GVL_IHM.Commun.Cfg.Initialized THEN
    _LimitLegalDepthMinAllowed_M := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
    _LimitLegalEnabled           := GVL_IHM.Commun.Cfg.LimitLegalEnabled;
END_IF;
```

**`CODE/MAIN/PRG_09_Supervision.st`** — computation `LimitLegalReached` (section plus bas dans le
même fichier), consommateur DIRECT des variables plates (celui-ci s'exécute APRÈS le bloc de
sauvegarde ci-dessus dans le même fichier, mais migré par cohérence — les variables plates
disparaissent entièrement) :
```
GVL_IHM.Commun.LimitLegalReached         := _LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M)));
```
→ remplacer les 3 occurrences de `_LimitLegalEnabled`/`_LimitLegalDepthMinAllowed_M` par
`_CommunCfgPersist.LimitLegalEnabled`/`_CommunCfgPersist.LimitLegalDepthMinAllowed_M` :
```
GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)));
```

**`CODE/MAIN/PRG_06_WinchControl.st`** — consommateur direct découvert (tâche position 6, avant
la restauration de `PRG_09` en position 9 — voir §1), 8 occurrences (4 lignes ×2 variables) :
```
L356-359 (bloc M1) :
    BottomLimitM1_Active := _CableLimitM1Descent_M;
    IF _LimitLegalEnabled THEN
        BottomLimitM1_Active := MAX(BottomLimitM1_Active, _LimitLegalDepthMinAllowed_M);
    END_IF;
  →
    BottomLimitM1_Active := _CableLimitM1Descent_M;
    IF _CommunCfgPersist.LimitLegalEnabled THEN
        BottomLimitM1_Active := MAX(BottomLimitM1_Active, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
    END_IF;

L361-364 (bloc M2, même pattern) :
    BottomLimitM2_Active := _CableLimitM2Descent_M;
    IF _LimitLegalEnabled THEN
        BottomLimitM2_Active := MAX(BottomLimitM2_Active, _LimitLegalDepthMinAllowed_M);
    END_IF;
  →
    BottomLimitM2_Active := _CableLimitM2Descent_M;
    IF _CommunCfgPersist.LimitLegalEnabled THEN
        BottomLimitM2_Active := MAX(BottomLimitM2_Active, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
    END_IF;

L387-389 (ForbidDescentM1_Raw) :
    ForbidDescentM1_Raw := (NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND PRG_03_Safety.instSafetyWinchM1.ForbidDescent)
                           OR (_LimitLegalEnabled
                               AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M));
  →
    ForbidDescentM1_Raw := (NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND PRG_03_Safety.instSafetyWinchM1.ForbidDescent)
                           OR (_CommunCfgPersist.LimitLegalEnabled
                               AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));

L390-392 (ForbidDescentM2_Raw, même pattern) :
    ForbidDescentM2_Raw := (NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND PRG_03_Safety.instSafetyWinchM2.ForbidDescent)
                           OR (_LimitLegalEnabled
                               AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M));
  →
    ForbidDescentM2_Raw := (NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND PRG_03_Safety.instSafetyWinchM2.ForbidDescent)
                           OR (_CommunCfgPersist.LimitLegalEnabled
                               AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
```
⚠️ Ces 4 lignes touchent la logique de blocage de descente (sécurité) — remplacement MÉCANIQUE de
nom de variable uniquement, **ne changer AUCUNE autre partie de la logique/condition**.

### 5.3 — Bucket

**`CODE/GVL_PERSISTENT.st`** — état actuel (section `🪣 BENNE`) :
```
    // 🪣 BENNE
    _BucketConfig : ST_BucketConfig := (
        OffsetOpenM      := 0.0,   // Position ouverture relative (m)
        OffsetCloseM     := 10.0,  // Position fermeture relative (m) - Valeur terrain
        CoherenceLimitM  := 0.05   // Tolérance cohérence (m)
    );
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)
```
→ remplacer **uniquement** `_BucketConfig` (garder `_BucketState` inchangé, hors périmètre —
c'est un autre type, pas un `Cfg`) :
```
    // 🪣 BENNE
    _BucketCfgPersist : ST_BucketCfg := (
        Config := (
            OffsetOpenM      := 0.0,
            OffsetCloseM     := 10.0,
            CoherenceLimitM  := 0.05
        ),
        CfgTimeoutDuration := T#30s
    ); // 🌉 Pont FB_CfgPersistBridge_BucketCfg (ex-_BucketConfig + CfgTimeoutDuration gagne une vraie persistance, voir §1)
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)
```

**`CODE/MAIN/PRG_09_Supervision.st`** — déclarer `instCfgPersistBridgeBucket : FB_CfgPersistBridge_BucketCfg;`.

Bloc de restauration actuel :
```
IF NOT GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized THEN
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config := _BucketConfig;
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration := T#30s;
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized := TRUE;
END_IF;
```
→ remplacer par :
```
instCfgPersistBridgeBucket(Hmi := GVL_IHM.M2TreuilBenne.Bucket.Cfg, Persist := _BucketCfgPersist);
IF instCfgPersistBridgeBucket.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
⚠️ Ce bloc actuel n'avait PAS d'alarme `ConfigRestoredFromPersistent` (contrairement à
Sync/Commun/Cycle) — **l'ajouter maintenant est voulu**, cohérence avec tous les autres domaines
`Cfg` (effet de bord positif supplémentaire, même principe que §1).

Bloc de sauvegarde actuel :
```
_BucketConfig              := GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config;
```
→ **supprimer cette ligne entièrement** (gérée par le FB pont désormais).

**`CODE/MAIN/PRG_06_WinchControl.st`** — consommateur direct découvert (tâche position 6),
2 occurrences :
```
L109: Config              := _BucketConfig,
  →   Config              := _BucketCfgPersist.Config,
L428: M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketConfig.OffsetCloseM);
  →   M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketCfgPersist.Config.OffsetCloseM);
```
⚠️ **Ne PAS toucher `L110`** (`CfgTimeoutDuration := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,`)
— ce champ lit déjà `GVL_IHM` directement (pas une variable plate `GVL_PERSISTENT`), c'est un
pattern différent et préexistant, **hors périmètre de ce lot**, ne pas le "corriger" au passage
même si ça semble une amélioration cohérente — signale-le si tu penses que ça devrait changer,
mais n'y touche pas toi-même.

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : les 3 sweeps ci-dessus (5.1/5.2/5.3)
couvrent TOUTES les occurrences des variables plates retirées. Si le grep de vérification en
trouve d'autres au moment de l'exécution, les traiter avec le même principe, ne pas improviser.

## 6. Fichiers à modifier

1. `CODE/COMMUN/FB_CfgPersistBridge_CycleCfg.st` (nouveau)
2. `CODE/COMMUN/FB_CfgPersistBridge_CommunCfg.st` (nouveau)
3. `CODE/COMMUN/FB_CfgPersistBridge_BucketCfg.st` (nouveau)
4. `CODE/GVL_PERSISTENT.st`
5. `CODE/MAIN/PRG_09_Supervision.st`
6. `CODE/MAIN/PRG_06_WinchControl.st`
7. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas toucher à `Winch`** (`M1TreuilRetenue.Cfg`/`M2TreuilBenne.Cfg`, hors `.Bucket`) — hors
  périmètre explicite (voir §1).
- **Ne pas toucher** `CODE/MAIN/PRG_05_Cycle.st` — aucun changement nécessaire (voir §5.1).
- **Ne pas toucher `PRG_06_WinchControl.st:110`** (`CfgTimeoutDuration`) — pattern différent,
  préexistant, hors périmètre (voir §5.3).
- **Ne pas toucher** `_BucketState`, `ST_CycleCfg.st`, `ST_CommunCfg.st`, `ST_BucketCfg.st`,
  `ST_BucketConfig.st` — les types ne changent pas, seul leur usage (via les FB ponts) change.
- **Ne pas toucher** aux fichiers du Lot 3a (`FB_CfgPersistBridge_SyncCfg.st` et le câblage Sync
  dans `PRG_09_Supervision.st`/`PRG_06_WinchControl.st`, déjà committés/vérifiés).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage.
- **PascalCase strict**, pas de hongrois.
- Les 2 effets de bord positifs (§1 : `SelHomingApproachEnable` et `CfgTimeoutDuration` gagnent une
  vraie persistance) sont **voulus**, ne pas les retirer par excès de prudence.

## 8. Obligatoire avant restitution

1. `grep -rn "_WinchSyncTolerance_M\b" CODE/` (doit rester zéro, contrôle de non-régression Lot 3a).
2. `grep -rn "\b_CycleSetDepth_M\b\|\b_CycleSetOffset_M\b\|\b_LimitLegalDepthMinAllowed_M\b\|\b_LimitLegalEnabled\b\|\b_BucketConfig\b" CODE/`
   doit retourner **zéro résultat** (toutes les anciennes variables plates doivent avoir disparu).
3. `grep -n "_CycleCfgPersist\|_CommunCfgPersist\|_BucketCfgPersist" CODE/GVL_PERSISTENT.st CODE/MAIN/PRG_09_Supervision.st CODE/MAIN/PRG_06_WinchControl.st`
   doit montrer les 3 nouvelles variables déclarées ET utilisées aux endroits attendus.
4. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
5. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
6. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 3 nouveaux FB créés dans `CODE/COMMUN/`, structure identique à `FB_CfgPersistBridge_SyncCfg`
      (seul le type change), `VAR_IN_OUT Hmi`/`Persist`, `VAR_OUTPUT JustRestored`.
- [ ] `GVL_PERSISTENT.st` : 3 variables plates/struct remplacées par leurs 3 structs miroir
      (`_CycleCfgPersist`, `_CommunCfgPersist`, `_BucketCfgPersist`), mêmes valeurs par défaut.
- [ ] `PRG_09_Supervision.st` : 3 instances déclarées, 3 appels remplaçant les 3 paires de blocs
      manuels, `JustRestored` pilote `ConfigRestoredFromPersistent` pour chacun (y compris Bucket,
      qui n'avait pas cette alarme avant — voir §5.3).
- [ ] `LimitLegalReached` (PRG_09_Supervision.st) migré vers `_CommunCfgPersist.*`.
- [ ] `PRG_06_WinchControl.st` : 8 occurrences LimitLegal migrées, 2 occurrences `_BucketConfig`
      migrées vers `_BucketCfgPersist.Config`, ligne 110 (`CfgTimeoutDuration`) **non touchée**.
- [ ] `PRG_05_Cycle.st` non modifié.
- [ ] `grep` de vérification §8.1/§8.2 = zéro résultat.
- [ ] `ST_CycleCfg.st`, `ST_CommunCfg.st`, `ST_BucketCfg.st`, `ST_BucketConfig.st`,
      `_BucketState`/son usage non modifiés.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

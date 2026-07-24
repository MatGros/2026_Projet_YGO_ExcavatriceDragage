# 📋 Document de Tâche — Lot 3d-2 : Créer `FB_CfgPersistBridge_WinchCfg` (M1 + M2)
## ⚠️ PRIORITÉ SÉCURITÉ MAXIMALE — ce lot touche des paramètres consommés par `FB_Safety_Winch`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 3d-1 (déplacement des 4 champs communs M1/M2 vers `Commun.Cfg`, fait et vérifié,
> commit `3af3b07`). `ST_WinchCfg` est maintenant réduit à **7 champs vraiment indépendants par
> instance** — plus de réconciliation à gérer, le pont générique s'applique enfin proprement.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **⚠️ Ce lot est le plus sensible de tout le chantier persistance** : 2 des 7 champs migrés
  (`CfgTopSensorPos_M`, `CfgCableLimitDescent_M`) alimentent directement des `VAR_INPUT` de
  `FB_Safety_Winch` (`TopLimitM`, `CfgCableLimitDescentM`) via `PRG_03_Safety.st` — ce sont des
  paramètres de SÉCURITÉ (fin de course haute, limite basse câble). Une erreur de câblage ici
  (mauvaise instance M1/M2 croisée, valeur non migrée) peut désactiver ou fausser une protection
  réelle. **Relis deux fois chaque ligne touchant `PRG_03_Safety.st` avant de la modifier.**
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer. Pour CE lot en
  particulier, un doute non résolu doit bloquer l'exécution plutôt que d'être deviné.
- **Ne touche QUE les fichiers listés en §6.**
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté.** Pointeurs utiles :
  - `CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st`, `FB_CfgPersistBridge_CycleCfg.st` — le pattern
    exact à reproduire (VAR_IN_OUT `Hmi`/`Persist` du même type, sortie `JustRestored`).
  - `CODE/TREUILS/FB_Safety_Winch.st` — pour confirmer toi-même comment `TopLimitM`/
    `CfgCableLimitDescentM` sont utilisés en interne (contexte de sécurité), si le §1 ne suffit pas.
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier** — les blocs à remplacer sont répartis entre
    "── 2. INITIALISATION..." et "── 3. PROPAGATION...".
  - Si aucun de ces pointeurs ne suffit à lever le doute : arrête-toi et signale.

## 1. Contexte

`ST_WinchCfg` a maintenant 7 champs (après le Lot 3d-1) : `CfgTopSensorPos_M`, `CfgHomingTarget_M`,
`CfgRampAccelRate`, `CfgRampDecelNormalRate`, `CfgRampDecelFastRate`, `CfgCableLimitDescent_M`,
`CfgCableLimitAscent_M` — **tous vraiment indépendants entre M1 et M2** (chacun a déjà sa propre
variable `GVL_PERSISTENT`, ex. `_HomingTargetM1_M` vs `_HomingTargetM2_M`, aucune réconciliation).
Le pont générique `FB_CfgPersistBridge_<Type>` (déjà utilisé pour Sync/Cycle/Commun/Bucket)
s'applique donc directement, en 2 instances (M1, M2).

### 🔍 Ce lot est plus gros que les précédents — pourquoi

Contrairement à Sync/Cycle (consommateur externe unique) ou Commun/Bucket (peu de consommateurs),
ces 7 champs sont lus **directement depuis la variable `GVL_PERSISTENT`** (pas depuis
`GVL_IHM.Xxx.Cfg`) dans **5 fichiers différents**, tous exécutés par la tâche PLC **avant**
`PRG_09_Supervision.st` (position 9) — même raison structurelle que pour tous les lots précédents
(la restauration boot n'a pas encore eu lieu au moment où ces programmes lisent la valeur dans le
même scan) :
- `PRG_00_Inputs.st` (position 0)
- `PRG_02_Encoders.st` (position 2)
- `PRG_03_Safety.st` (position 3) — **paramètres de sécurité, voir §0**
- `PRG_05_Cycle.st` (position 5)
- `PRG_06_WinchControl.st` (position 6)

Chaque consommateur direct doit être migré vers le nouveau champ miroir (ex. `_HomingTargetM1_M`
→ `_WinchM1CfgPersist.CfgTopSensorPos_M`), exactement comme `_WinchSyncTolerance_M` a été migré
au Lot 3a et `_BucketConfig`/`_LimitLegalDepthMinAllowed_M`/etc. au Lot 3b.

## 2. Objectif

1. Créer `CODE/COMMUN/FB_CfgPersistBridge_WinchCfg.st` — même pattern générique que les FB
   existants, type `ST_WinchCfg` (voir §4).
2. `CODE/GVL_PERSISTENT.st` : remplacer les 14 variables plates (7 champs × 2 instances) par 2
   structs miroir `_WinchM1CfgPersist`/`_WinchM2CfgPersist : ST_WinchCfg`.
3. `PRG_09_Supervision.st` : remplacer les 2 blocs de restauration + toute la section de
   sauvegarde concernée par 2 appels du nouveau pont.
4. Migrer les **25 lectures directes** réparties dans `PRG_00_Inputs.st`, `PRG_02_Encoders.st`,
   `PRG_03_Safety.st`, `PRG_05_Cycle.st`, `PRG_06_WinchControl.st` (liste exhaustive §5.4).
5. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_WinchCfg.st` (déjà à jour depuis le Lot 3d-1, **ne pas y toucher**)

```
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;
    CfgHomingTarget_M       : REAL := 0.0;
    CfgRampAccelRate        : REAL := 50.0;
    CfgRampDecelNormalRate  : REAL := 150.0;
    CfgRampDecelFastRate    : REAL := 400.0;
    CfgCableLimitDescent_M  : REAL := -20.0;
    CfgCableLimitAscent_M   : REAL := 8.0;
    Initialized              : BOOL := FALSE;
END_STRUCT
END_TYPE
```

## 4. Nouveau FB — `CODE/COMMUN/FB_CfgPersistBridge_WinchCfg.st` (nouveau fichier)

```
(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_WinchCfg — Pont persistance générique pour ST_WinchCfg
   ───────────────────────────────────────────────────────────────
   🎯 Voir FB_CfgPersistBridge_SyncCfg.st (Lot 3a) pour la logique de référence — identique,
   seul le type ST_WinchCfg change. 2 instances (M1, M2) — plus de champs partagés depuis le
   Lot 3d-1 (déplacés vers Commun.Cfg), chaque instance est totalement indépendante.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_WinchCfg
VAR_IN_OUT
    Hmi     : ST_WinchCfg; (* 🖥️ ex. GVL_IHM.M1TreuilRetenue.Cfg ou M2TreuilBenne.Cfg *)
    Persist : ST_WinchCfg; (* 💾 ex. GVL_PERSISTENT._WinchM1CfgPersist ou _WinchM2CfgPersist *)
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

## 5. Sweep exhaustif — vérifié par grep, ne pas en chercher d'autres

### 5.1 — `CODE/GVL_PERSISTENT.st`

État actuel (section `🏗️ TREUILS`) :
```
    _HomingTargetM1_M : REAL := 8.5;
    _HomingTargetM2_M : REAL := 8.5;
    _HomingUnitaryTargetM1_M : REAL := 0.0;
    _HomingUnitaryTargetM2_M : REAL := 0.0;
    ...
    _WinchM1RampAccelRate_Pct    : REAL := 50.0;
    _WinchM1RampDecelNormal_Pct  : REAL := 150.0;
    _WinchM1RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)
    _WinchM2RampAccelRate_Pct    : REAL := 50.0;
    _WinchM2RampDecelNormal_Pct  : REAL := 150.0;
    _WinchM2RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)

    _CableLimitM1Descent_M       : REAL := -20.0;
    _CableLimitM2Descent_M       : REAL := -20.0;
    _CableLimitM1Ascent_M        : REAL := 8.0;
    _CableLimitM2Ascent_M        : REAL := 8.0;
```
→ **retirer ces 14 lignes entièrement**, remplacer par (mêmes valeurs par défaut, mêmes pour M1 et
M2 — vérifié, aucune divergence de défaut entre les deux aujourd'hui) :
```
    _WinchM1CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5,
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 50.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 8.0
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M1)
    _WinchM2CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5,
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 50.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 8.0
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M2)
```
(place-les au même endroit, section `🏗️ TREUILS` — l'ordre exact dans le fichier n'a pas
d'importance fonctionnelle)

### 5.2 — `CODE/MAIN/PRG_09_Supervision.st` — déclaration + remplacement des blocs de restauration

Ajouter dans le `VAR` (à la suite de `instCfgPersistBridgeBucket`) :
```
    instCfgPersistBridgeWinchM1 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M1TreuilRetenue.Cfg (Lot 3d-2)
    instCfgPersistBridgeWinchM2 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M2TreuilBenne.Cfg (Lot 3d-2)
```

Bloc M1 actuel (section "── 2. INITIALISATION...") :
```
IF NOT GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M  := _HomingTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M       := _HomingUnitaryTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate       := _WinchM1RampAccelRate_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelNormalRate := _WinchM1RampDecelNormal_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelFastRate   := _WinchM1RampDecelFast_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M  := _CableLimitM1Descent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M   := _CableLimitM1Ascent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
→ remplacer par :
```
instCfgPersistBridgeWinchM1(Hmi := GVL_IHM.M1TreuilRetenue.Cfg, Persist := _WinchM1CfgPersist);
IF instCfgPersistBridgeWinchM1.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```

Bloc M2 actuel, juste en dessous — **même remplacement**, `M1TreuilRetenue`→`M2TreuilBenne`,
`_WinchM1CfgPersist`→`_WinchM2CfgPersist`, `instCfgPersistBridgeWinchM1`→`instCfgPersistBridgeWinchM2`.

### 5.3 — `CODE/MAIN/PRG_09_Supervision.st` — supprimer toute la section de sauvegarde concernée

Dans la section "── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE", **supprimer entièrement** (les
lignes exactes peuvent avoir légèrement bougé, repère-toi au contenu, pas seulement au numéro) :
```
_HomingTargetM1_M            := GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M;
_HomingTargetM2_M            := GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M;
_HomingUnitaryTargetM1_M     := GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M;
_HomingUnitaryTargetM2_M     := GVL_IHM.M2TreuilBenne.Cfg.CfgHomingTarget_M;
IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    _WinchM1RampAccelRate_Pct   := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate;
    _WinchM1RampDecelNormal_Pct := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelNormalRate;
    _WinchM1RampDecelFast_Pct   := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelFastRate;
END_IF;
IF GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
    _WinchM2RampAccelRate_Pct   := GVL_IHM.M2TreuilBenne.Cfg.CfgRampAccelRate;
    _WinchM2RampDecelNormal_Pct := GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelNormalRate;
    _WinchM2RampDecelFast_Pct   := GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelFastRate;
END_IF;

IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M <> _CableLimitM1Descent_M THEN
        _CableLimitM1Descent_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M := _CableLimitM1Descent_M;
END_IF;

IF GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
    IF GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M <> _CableLimitM2Descent_M THEN
        _CableLimitM2Descent_M := GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M;
    END_IF;
    GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M := _CableLimitM2Descent_M;
END_IF;

// 🆕 REX 2026-07-15 (6) — même pattern miroir bidirectionnel que CableLimitDescent_M ci-dessus.
IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M <> _CableLimitM1Ascent_M THEN
        _CableLimitM1Ascent_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M := _CableLimitM1Ascent_M;
END_IF;

IF GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
    IF GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M <> _CableLimitM2Ascent_M THEN
        _CableLimitM2Ascent_M := GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M;
    END_IF;
    GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M := _CableLimitM2Ascent_M;
END_IF;
```
→ **supprimer tout ce bloc** (le pont créé en §5.2 gère restauration ET sauvegarde en un seul
appel par instance, plus besoin de ce code manuel).

⚠️ Le commentaire d'introduction juste avant ("🐛 FIX 2026-07-23 : chaque bloc ci-dessous est
désormais gardé par le flag...") reste valable pour les autres blocs restants dans cette section
(bypass, LimitLegalReached, etc.) — **ne pas le retirer**, seul le CODE ci-dessus disparaît.

### 5.4 — Les 25 lectures directes à migrer (5 fichiers)

**`CODE/MAIN/PRG_00_Inputs.st`** (2 lignes) :
```
L195: SimTopSensorTriggered := (NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _HomingTargetM1_M))
  →                                                                                                                    _WinchM1CfgPersist.CfgTopSensorPos_M
L196:                       OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= _HomingTargetM2_M));
  →                                                                                                                    _WinchM2CfgPersist.CfgTopSensorPos_M
```

**`CODE/MAIN/PRG_02_Encoders.st`** (4 lignes — 2 par instance, dans les appels `instHomingM1`/`instHomingM2`) :
```
L135: CfgHomingTargetM        := _HomingUnitaryTargetM1_M,
  →   CfgHomingTargetM        := _WinchM1CfgPersist.CfgHomingTarget_M,
L138: CfgTopSensorPosM   := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _HomingTargetM1_M, 0.0),
  →   CfgTopSensorPosM   := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
L185: CfgHomingTargetM        := _HomingUnitaryTargetM2_M,
  →   CfgHomingTargetM        := _WinchM2CfgPersist.CfgHomingTarget_M,
L188: CfgTopSensorPosM   := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _HomingTargetM2_M, 0.0),
  →   CfgTopSensorPosM   := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _WinchM2CfgPersist.CfgTopSensorPos_M, 0.0),
```

**`CODE/MAIN/PRG_03_Safety.st`** (4 lignes — ⚠️ paramètres `FB_Safety_Winch`, voir §0) :
```
L49  (dans instSafetyWinchM1) : CfgCableLimitDescentM  := _CableLimitM1Descent_M,
  →                             CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
L54  (dans instSafetyWinchM1) : TopLimitM           := _HomingTargetM1_M,
  →                             TopLimitM           := _WinchM1CfgPersist.CfgTopSensorPos_M,
L107 (dans instSafetyWinchM2) : CfgCableLimitDescentM  := _CableLimitM2Descent_M,
  →                             CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
L112 (dans instSafetyWinchM2) : TopLimitM           := _HomingTargetM2_M,
  →                             TopLimitM           := _WinchM2CfgPersist.CfgTopSensorPos_M,
```
⚠️ **Vérifie bien que L49/L54 sont dans le bloc `instSafetyWinchM1` et L107/L112 dans
`instSafetyWinchM2`** — une inversion M1/M2 ici serait une régression de sécurité silencieuse.

**`CODE/MAIN/PRG_05_Cycle.st`** (1 ligne, M1 seulement — pas de M2 équivalent, c'est déjà le cas
aujourd'hui, ne pas en ajouter un) :
```
L73: CableLimitM1AscentM       := _CableLimitM1Ascent_M,
  →  CableLimitM1AscentM       := _WinchM1CfgPersist.CfgCableLimitAscent_M,
```

**`CODE/MAIN/PRG_06_WinchControl.st`** (14 lignes) :
```
L356: BottomLimitM1_Active := _CableLimitM1Descent_M;
  →   BottomLimitM1_Active := _WinchM1CfgPersist.CfgCableLimitDescent_M;
L361: BottomLimitM2_Active := _CableLimitM2Descent_M;
  →   BottomLimitM2_Active := _WinchM2CfgPersist.CfgCableLimitDescent_M;

L414: AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _CableLimitM1Ascent_M)
  →   AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _WinchM1CfgPersist.CfgCableLimitAscent_M)
L421: AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _HomingTargetM1_M))
  →   AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _WinchM1CfgPersist.CfgTopSensorPos_M))
L433: AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_CableLimitM2Ascent_M + M2_LimitShift))
  →   AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift))
L440: AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_HomingTargetM2_M + M2_LimitShift)))
  →   AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_WinchM2CfgPersist.CfgTopSensorPos_M + M2_LimitShift)))

L479 (dans instWinchM1) : CfgRampAccelRate           := _WinchM1RampAccelRate_Pct,
  →                       CfgRampAccelRate           := _WinchM1CfgPersist.CfgRampAccelRate,
L480 (dans instWinchM1) : CfgRampDecelNormalRate     := _WinchM1RampDecelNormal_Pct,
  →                       CfgRampDecelNormalRate     := _WinchM1CfgPersist.CfgRampDecelNormalRate,
L481 (dans instWinchM1) : CfgRampDecelFastRate       := _WinchM1RampDecelFast_Pct,
  →                       CfgRampDecelFastRate       := _WinchM1CfgPersist.CfgRampDecelFastRate,
L488 (dans instWinchM1) : TopLimitM               := _CableLimitM1Ascent_M,
  →                       TopLimitM               := _WinchM1CfgPersist.CfgCableLimitAscent_M,

L523 (dans instWinchM2) : CfgRampAccelRate           := _WinchM2RampAccelRate_Pct,
  →                       CfgRampAccelRate           := _WinchM2CfgPersist.CfgRampAccelRate,
L524 (dans instWinchM2) : CfgRampDecelNormalRate     := _WinchM2RampDecelNormal_Pct,
  →                       CfgRampDecelNormalRate     := _WinchM2CfgPersist.CfgRampDecelNormalRate,
L525 (dans instWinchM2) : CfgRampDecelFastRate       := _WinchM2RampDecelFast_Pct,
  →                       CfgRampDecelFastRate       := _WinchM2CfgPersist.CfgRampDecelFastRate,
L530 (dans instWinchM2) : TopLimitM               := _CableLimitM2Ascent_M + M2_LimitShift,
  →                       TopLimitM               := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
```

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : ces 25 lignes + les blocs
`PRG_09_Supervision.st` couvrent TOUTES les occurrences des 14 variables plates retirées. Si le
grep de vérification en trouve d'autres au moment de l'exécution, les traiter avec le même
principe de mapping, ne pas improviser un nouveau pattern — et signaler si le compte final diffère
de 25.

## 6. Fichiers à modifier

1. `CODE/COMMUN/FB_CfgPersistBridge_WinchCfg.st` (nouveau)
2. `CODE/GVL_PERSISTENT.st`
3. `CODE/MAIN/PRG_09_Supervision.st`
4. `CODE/MAIN/PRG_00_Inputs.st`
5. `CODE/MAIN/PRG_02_Encoders.st`
6. `CODE/MAIN/PRG_03_Safety.st`
7. `CODE/MAIN/PRG_05_Cycle.st`
8. `CODE/MAIN/PRG_06_WinchControl.st`
9. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas toucher** `CODE/SUPERVISION/_TYPES/ST_WinchCfg.st` — déjà à jour depuis le Lot 3d-1.
- **Ne pas toucher** `CODE/TREUILS/FB_Winch.st`, `CODE/TREUILS/FB_Safety_Winch.st` — leurs
  `VAR_INPUT` ne changent pas de nom/signature, seule la SOURCE change côté appelant.
- **Ne pas toucher** aux fichiers des lots précédents déjà committés (Sync/Cycle/Commun/Bucket,
  correctif générateur, Lot 3d-1).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage.
- **PascalCase strict**, pas de hongrois.
- Le reset unique de ces 7×2 valeurs au premier téléchargement (retour aux défauts `8.5`/`0.0`/
  `50.0`/`150.0`/`400.0`/`-20.0`/`8.0`) est **accepté** — même principe déjà validé aux lots
  précédents.

## 8. Obligatoire avant restitution

1. `grep -rn "_HomingTargetM1_M\b\|_HomingTargetM2_M\b\|_HomingUnitaryTargetM1_M\b\|_HomingUnitaryTargetM2_M\b\|_WinchM1RampAccelRate_Pct\b\|_WinchM2RampAccelRate_Pct\b\|_WinchM1RampDecelNormal_Pct\b\|_WinchM2RampDecelNormal_Pct\b\|_WinchM1RampDecelFast_Pct\b\|_WinchM2RampDecelFast_Pct\b\|_CableLimitM1Descent_M\b\|_CableLimitM2Descent_M\b\|_CableLimitM1Ascent_M\b\|_CableLimitM2Ascent_M\b" CODE/`
   doit retourner **zéro résultat**.
2. `grep -n "_WinchM1CfgPersist\|_WinchM2CfgPersist" CODE/GVL_PERSISTENT.st CODE/MAIN/PRG_09_Supervision.st CODE/MAIN/PRG_00_Inputs.st CODE/MAIN/PRG_02_Encoders.st CODE/MAIN/PRG_03_Safety.st CODE/MAIN/PRG_05_Cycle.st CODE/MAIN/PRG_06_WinchControl.st`
   doit montrer les 2 variables déclarées ET utilisées aux ~25 endroits attendus.
3. **Relire toi-même `PRG_03_Safety.st` après modification** : confirmer que `instSafetyWinchM1`
   utilise bien `_WinchM1CfgPersist.*` et `instSafetyWinchM2` bien `_WinchM2CfgPersist.*` (aucune
   inversion M1/M2).
4. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
5. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
6. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] `FB_CfgPersistBridge_WinchCfg.st` créé, structure identique aux FB existants.
- [ ] `GVL_PERSISTENT.st` : 14 variables plates remplacées par `_WinchM1CfgPersist`/
      `_WinchM2CfgPersist : ST_WinchCfg`, mêmes valeurs par défaut.
- [ ] `PRG_09_Supervision.st` : 2 instances déclarées, 2 appels remplaçant les 2 blocs de
      restauration, toute la section de sauvegarde concernée (Homing + rampes + limites câble)
      supprimée.
- [ ] Les 25 lectures directes migrées exactement comme listé §5.4, **aucune inversion M1/M2**
      (vérification explicite sur `PRG_03_Safety.st` en particulier).
- [ ] `ST_WinchCfg.st`, `FB_Winch.st`, `FB_Safety_Winch.st` non modifiés.
- [ ] `grep` de vérification §8.1 = zéro résultat.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

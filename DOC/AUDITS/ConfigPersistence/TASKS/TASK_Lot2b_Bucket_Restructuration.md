# 📋 Document de Tâche — Lot 2b : Restructuration `GVL_IHM.M2Benne` → `GVL_IHM.M2TreuilBenne.Bucket`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 2a (`M1M2Sync`, déjà fait et vérifié) — ce lot est indépendant, ne touche pas aux
> fichiers du Lot 2a ni du Lot 1a.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande. Ne corrige pas silencieusement, ne l'ignore pas.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §6** — toute modification hors périmètre (ex. outillage
  Python, autre struct) doit être signalée séparément dans ta restitution, jamais appliquée
  silencieusement en plus de ce qui est demandé.
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.

## 1. Contexte

`M2Benne` (la benne) est **physiquement couplée à M2** (`instBucket.Busy` pilote directement M2 —
voir `PRG_06_WinchControl.st`). Décision utilisateur (2026-07-23) : la nester **dans**
`M2TreuilBenne` plutôt que de la garder en groupe racine séparé, **sans changer le namespace**
`M1TreuilRetenue`/`M2TreuilBenne` eux-mêmes (pas de wrapper `Treuils`, décision déjà tranchée).

**Confirmé non mappé sur un écran IHM physique** — aucun risque de casser un mapping existant.

⚠️ **Tradeoff assumé, à ne pas "corriger"** : `M1TreuilRetenue` et `M2TreuilBenne` partagent le
MÊME type `ST_WinchHMI`. Nester `Bucket` dedans veut dire que **M1 aura aussi un champ `.Bucket`
qu'il n'utilisera jamais** (inerte, jamais lu/écrit côté M1). C'est le prix pour ne pas dupliquer
`ST_WinchHMI` en 2 types quasi-identiques ni casser le namespace du treuil — décision utilisateur
explicite, ne pas essayer de "nettoyer" ça autrement (ex. ne pas créer un `ST_WinchHMI` séparé pour
M2 seul).

## 2. Objectif

1. Créer 4 nouveaux types dans `CODE/SUPERVISION/_TYPES/` : `ST_BucketCmd`, `ST_BucketState`
   (⚠️ collision de nom, voir §4), `ST_BucketCfg`, `ST_BypassBucket`.
2. Modifier `ST_BucketHMI` pour composer ces 4 sous-structs.
3. Ajouter un champ `Bucket : ST_BucketHMI;` à `ST_WinchHMI` (voir §4).
4. Retirer la déclaration `M2Benne : ST_BucketHMI;` de `GVL_IHM.st` (elle disparaît, remplacée par
   l'accès via `M2TreuilBenne.Bucket`).
5. Mettre à jour **toutes** les références (liste exhaustive §5, y compris `PLC_TESTS`).
6. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_BucketHMI.st`

```
TYPE ST_BucketHMI :
STRUCT
    Config              : ST_BucketConfig;
    CfgTimeoutDuration     : TIME := T#30s;

    State               : ST_BucketState;
    FBState             : E_State;
    ActiveOffset_M        : REAL;
    M2StartStop         : BOOL;
    M2Direction         : INT;
    M2ForceSlowSpeed    : BOOL;
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;
    RemainingTravel_M     : REAL;
    CloseActive            : BOOL;
    OpenActive             : BOOL;
    M2PositionCorrected : REAL;

    BtnOpen             : BOOL;
    BtnClose            : BOOL;
    BtnReset            : BOOL;
    BtnConfirmOpenPos : BOOL;
    BtnConfirmClosePos : BOOL;
    BypassGlobal     : BOOL;
END_STRUCT
END_TYPE
```
⚠️ Note bien : le type existant `ST_BucketState` (ligne `State : ST_BucketState`) est **DIFFÉRENT**
du nouveau sous-struct `State` qu'on va créer pour le regroupement IHM (§4) — collision de nom
directe, voir §4 pour la résolution exacte (ne pas confondre les deux, ne pas supprimer
`ST_BucketState` qui reste utilisé ailleurs, ex. `_BucketState : ST_BucketState` dans
`GVL_PERSISTENT.st`).

## 4. Structure cible

**Collision de nom** : le champ `State : ST_BucketState` (mémoire mécanique ouverte/fermée,
persistante) entre en collision avec le nouveau sous-struct `State` de regroupement IHM. **Le
renommer en `MechState`** à l'intérieur de `ST_BucketHMI` uniquement — le type `ST_BucketState`
lui-même (fichier `ST_BucketState.st`) **ne change pas de nom**, seul le NOM DU CHAMP qui le
contient dans `ST_BucketHMI` change (`State` → `MechState`).

### `CODE/SUPERVISION/_TYPES/ST_BucketCmd.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_BucketCmd — Commandes IHM pour la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketCmd :
STRUCT
    BtnOpen             : BOOL; (* 🪣 Bouton commande ouverture *)
    BtnClose            : BOOL; (* 🪣 Bouton commande fermeture *)
    BtnReset            : BOOL; (* 🔑 Acquittement défaut benne *)
    BtnConfirmOpenPos   : BOOL; (* 🆕 Référencement benne position ouverte (mise en service) — confirmation pure, aucun mouvement *)
    BtnConfirmClosePos  : BOOL; (* 🆕 Référencement benne position fermée (mise en service) — confirmation pure, aucun mouvement *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_BucketState.st` — ⚠️ NOM DÉJÀ PRIS, voir remarque
Le nom `ST_BucketState` est déjà utilisé par le type existant (mémoire mécanique persistante,
`GVL_PERSISTENT._BucketState`). **Nommer le nouveau sous-struct de regroupement IHM différemment** :
`ST_BucketHMIState` (nouveau fichier `CODE/SUPERVISION/_TYPES/ST_BucketHMIState.st`) :
```
(* ═══════════════════════════════════════════════════════════════
   🚦 ST_BucketHMIState — États et diagnostics IHM de la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketHMIState :
STRUCT
    MechState           : ST_BucketState; (* 🚥 État mécanique mémorisé (IsOpen, IsClosed...) — ex-champ "State", renommé pour éviter collision de nom avec ce sous-struct *)
    FBState             : E_State;          (* 🤖 État de l'automate interne (FB_Bucket) *)
    ActiveOffset_M        : REAL;             (* 📐 Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* 🛗 Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* 🛗 Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* 🐢 Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* 🟢 Bloc opérationnel *)
    Busy                : BOOL;             (* ⚙️ Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* ✅ Mouvement terminé avec succès *)
    Error               : BOOL;             (* 🔴 Benne en défaut *)
    ErrorId             : WORD;             (* ❌ Code bitfield du défaut benne *)
    RemainingTravel_M     : REAL;             (* 📏 Distance restante avant cible (m) *)
    CloseActive            : BOOL;             (* 🆕 Demande de fermeture active (image FB_Bucket) *)
    OpenActive             : BOOL;             (* 🆕 Demande d'ouverture active (image FB_Bucket) *)
    M2PositionCorrected : REAL;             (* 📊 WinchM2.PositionM - ActiveOffset_M, affichage bargraphe *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_BucketCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BucketCfg — Configuration de la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketCfg :
STRUCT
    Config              : ST_BucketConfig; (* 🔧 Offsets Open/Close/Coherence *)
    CfgTimeoutDuration  : TIME := T#30s;    (* ⏱️ Temps max pour l'ouverture/fermeture *)
    Initialized         : BOOL := FALSE;   (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_BypassBucket.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassBucket — Bypass de la surveillance benne (M2)
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassBucket :
STRUCT
    Global      : BOOL; (* 🌐 Bypass GLOBAL benne *)
    Initialized : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_BucketHMI.st` (modifié, remplace le contenu actuel)
```
(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_BucketHMI — Données d'échange IHM pour la benne (M2)
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Bypass (2026-07-23), homogène avec ST_WinchHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketHMI :
STRUCT
    Cmd    : ST_BucketCmd;
    State  : ST_BucketHMIState;
    Cfg    : ST_BucketCfg;
    Bypass : ST_BypassBucket;
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_WinchHMI.st` (modifié — ajout d'un champ)
Ajouter, à la fin du struct (après `Bypass : ST_BypassWinch;`) :
```
    (* 🪣 Benne — pertinent uniquement pour M2 (M2TreuilBenne.Bucket), M1 ne l'utilise pas — voir §1 *)
    Bucket                  : ST_BucketHMI;
```

## 5. Sweep exhaustif des références — vérifié par grep, ne pas en chercher d'autres

**`CODE/SUPERVISION/GVL_IHM.st`** : retirer la ligne
`M2Benne : ST_BucketHMI; (* 🪣 Variables d'échange IHM Mécanisme Benne (M2) *)` — elle disparaît
(remplacée par l'accès via `M2TreuilBenne.Bucket`, déjà ajouté en §4 dans `ST_WinchHMI`).

**`CODE/MAIN/PRG_00_Inputs.st:132-136`** :
```
GVL_IHM.M2Benne.BtnOpen := FALSE;              → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen := FALSE;
GVL_IHM.M2Benne.BtnClose := FALSE;             → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose := FALSE;
GVL_IHM.M2Benne.BtnReset := FALSE;              → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset := FALSE;
GVL_IHM.M2Benne.BtnConfirmOpenPos := FALSE;    → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos := FALSE;
GVL_IHM.M2Benne.BtnConfirmClosePos := FALSE;   → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos := FALSE;
```

**`CODE/MAIN/PRG_06_WinchControl.st`** (6 lignes) :
```
L97:  CmdOpen_IHM  := GVL_IHM.M2Benne.BtnOpen OR ...
  →   CmdOpen_IHM  := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen OR ...
L98:  CmdClose_IHM := GVL_IHM.M2Benne.BtnClose OR ...
  →   CmdClose_IHM := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose OR ...
L107: ConfirmOpenPosition := GVL_IHM.M2Benne.BtnConfirmOpenPos,
  →   ConfirmOpenPosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
L108: ConfirmClosePosition:= GVL_IHM.M2Benne.BtnConfirmClosePos,
  →   ConfirmClosePosition:= GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
L110: CfgTimeoutDuration := GVL_IHM.M2Benne.CfgTimeoutDuration,
  →   CfgTimeoutDuration := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
L114: BypassGlobal := GVL_IHM.M2Benne.BypassGlobal
  →   BypassGlobal := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global
```

**`CODE/MAIN/PRG_09_Supervision.st`** (22 lignes) :
```
L74:  OR GVL_IHM.M2Benne.BtnReset;
  →   OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;

L193: IF GVL_IHM.M2Benne.Config.OffsetOpenM = 0.0 AND GVL_IHM.M2Benne.Config.OffsetCloseM = 0.0 THEN
  →   IF GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config.OffsetOpenM = 0.0 AND GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config.OffsetCloseM = 0.0 THEN
L194:     GVL_IHM.M2Benne.Config := _BucketConfig;
  →       GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config := _BucketConfig;
L195:     GVL_IHM.M2Benne.CfgTimeoutDuration := T#30s;
  →       GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration := T#30s;

L254: IF BypassBucketGlobal AND GVL_IHM.M2Benne.BypassGlobal = FALSE THEN
  →   IF BypassBucketGlobal AND GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global = FALSE THEN
L255:     GVL_IHM.M2Benne.BypassGlobal := TRUE;
  →       GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global := TRUE;

L288: _BucketConfig := GVL_IHM.M2Benne.Config;
  →   _BucketConfig := GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config;

L366: BypassBucketGlobal := GVL_IHM.M2Benne.BypassGlobal;
  →   BypassBucketGlobal := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global;

L518-534 (mapping état → IHM, 15 lignes) — remplacer `GVL_IHM.M2Benne.<Champ>` par
`GVL_IHM.M2TreuilBenne.Bucket.State.<Champ>` pour TOUS ces champs, SAUF le dernier :
FBState, ActiveOffset_M, M2StartStop, M2Direction, M2ForceSlowSpeed, Ready, Busy, Done, Error,
ErrorId, RemainingTravel_M, CloseActive, OpenActive, M2PositionCorrected
    → GVL_IHM.M2TreuilBenne.Bucket.State.<MêmeChamp>
L534: GVL_IHM.M2Benne.State := _BucketState;
  →   GVL_IHM.M2TreuilBenne.Bucket.State.MechState := _BucketState;   ⚠️ champ renommé MechState (voir §4)
```

**⚠️ Ajouter aussi le bloc de restauration `Initialized` pour `ST_BucketCfg`/`ST_BypassBucket`**
(nouveaux champs `Initialized` créés en §4, sinon ils restent inutilisés — même remarque que pour
`ST_BypassSync` au Lot 2a, où le flag `Initialized` du bypass nouvellement créé doit être câblé
avec le même pattern que Winch/Translation/Network/Sync, PAS laissé sur l'ancien mécanisme
`BypassRestoreDone`) :
```
IF NOT GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized THEN
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.Config := _BucketConfig;
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration := T#30s;
    GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized := TRUE;
END_IF;
```
(remplace le bloc `IF GVL_IHM.M2Benne.Config.OffsetOpenM = 0.0 AND ... THEN` — même principe que
tous les autres correctifs `Initialized` déjà faits : sentinelle de valeur remplacée par un flag
dédié) et :
```
IF NOT GVL_IHM.M2TreuilBenne.Bucket.Bypass.Initialized THEN
    IF BypassBucketGlobal THEN
        GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bucket.Bypass.Initialized := TRUE;
END_IF;
```
(retire alors `BypassBucketGlobal`/`M2Benne` du bloc `IF NOT BypassRestoreDone THEN` — après ce
lot, `BypassRestoreDone` ne protège plus AUCUN struct, il devient orphelin. **Signaler ce constat
dans ta restitution plutôt que de le supprimer toi-même** — décision à valider par le relecteur,
potentiellement `BypassRestoreDone` et sa déclaration `VAR RETAIN` associée seront supprimés dans
un lot ultérieur une fois confirmé qu'il ne sert plus à rien).

**`CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st:532,544`** :
```
GVL_IHM.M2Benne.BtnClose := TRUE;   → GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose := TRUE;
AND NOT GVL_IHM.M2Benne.BtnClose    → AND NOT GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose
```

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_BucketCmd.st` (nouveau)
2. `CODE/SUPERVISION/_TYPES/ST_BucketHMIState.st` (nouveau — PAS `ST_BucketState.st`, nom déjà pris)
3. `CODE/SUPERVISION/_TYPES/ST_BucketCfg.st` (nouveau)
4. `CODE/SUPERVISION/_TYPES/ST_BypassBucket.st` (nouveau)
5. `CODE/SUPERVISION/_TYPES/ST_BucketHMI.st` (remplacé)
6. `CODE/SUPERVISION/_TYPES/ST_WinchHMI.st` (ajout du champ `Bucket`)
7. `CODE/SUPERVISION/GVL_IHM.st` (retrait de la déclaration `M2Benne`)
8. `CODE/MAIN/PRG_00_Inputs.st`
9. `CODE/MAIN/PRG_06_WinchControl.st`
10. `CODE/MAIN/PRG_09_Supervision.st`
11. `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st`
12. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas toucher** `FB_Bucket.st`, `ST_BucketConfig.st`, `ST_BucketState.st` (le type existant,
  pas le nouveau sous-struct) — inchangés, seuls leurs CONSOMMATEURS (chemins `GVL_IHM`) changent.
- **Ne pas toucher** aux fichiers des Lots 1a/2a (déjà committés/vérifiés).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage —
  hors périmètre strict de ce lot (rappel explicite suite au Lot 2a).
- **PascalCase strict**, pas de hongrois.

## 8. Obligatoire avant restitution

1. `grep -rn "GVL_IHM\.M2Benne\b" CODE/` doit retourner **zéro résultat**.
2. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
3. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
4. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 4 nouveaux fichiers struct créés exactement comme spécifié §4 (attention au nom
      `ST_BucketHMIState`, pas `ST_BucketState`).
- [ ] `ST_BucketHMI.st` compose les 4 sous-structs.
- [ ] `ST_WinchHMI.st` a le nouveau champ `Bucket : ST_BucketHMI;`.
- [ ] `GVL_IHM.st` : plus de déclaration `M2Benne` séparée.
- [ ] `grep -rn "GVL_IHM\.M2Benne\b" CODE/` = zéro résultat.
- [ ] Bloc `Initialized` ajouté pour `Cfg` ET `Bypass` du Bucket, suivant le pattern établi (pas
      l'ancien mécanisme `= 0.0`/`BypassRestoreDone`).
- [ ] `BypassRestoreDone` devenu orphelin **signalé** dans la restitution, pas supprimé sans validation.
- [ ] `FB_Bucket.st` non modifié.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

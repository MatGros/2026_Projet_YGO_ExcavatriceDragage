# 📋 Document de Tâche — Lot 2a : Restructuration `GVL_IHM.Sync` → `GVL_IHM.M1M2Sync`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> Ne pas improviser au-delà de ce qui est spécifié — en cas de doute, s'arrêter et demander
> clarification plutôt qu'approximer (règle d'or du projet).
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 1a (persistance bypass, déjà fait et vérifié, commit `303c44a`) — ce lot est
> indépendant, ne touche pas aux fichiers du Lot 1a.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

Ce document essaie d'être précis, mais **tu portes une responsabilité sur ce que tu produis**, pas
seulement sur l'exécution littérale des étapes :

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** dans ta
  restitution avant de continuer à deviner. Ne force jamais une instruction obsolète sur du code
  qui a changé.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien dans ce document ne te le demande. Ne corrige pas silencieusement,
  ne l'ignore pas non plus.
- **Si une partie du périmètre reste ambiguë** malgré la précision recherchée ici → **pose la
  question** plutôt que d'approximer une réponse plausible.
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet — le
  relecteur (moi) vérifiera de toute façon chaque affirmation contre le code réel avant validation,
  donc un doute signalé vaut mieux qu'une correction silencieuse ou une supposition.

## 1. Contexte

`ST_WinchHMI`/`ST_TranslationHMI` suivent déjà un pattern homogène :
`Cmd` (commandes opérateur) / `State` (mesures, retours) / `Cfg` (réglages) / `Bypass`.

`GVL_IHM.Sync` (struct `ST_SyncHMI`) est resté **plat** — mélange commande (`SelSyncEnable`), état
(`DeltaPos_M`, `SyncActive`...), config (`CfgSyncTolerance_M`) et bypass (`BypassGlobal`) au même
niveau. Décision utilisateur (2026-07-23) : l'harmoniser avec le même pattern, **et renommer**
`Sync` → `M1M2Sync` (nom plus explicite — c'est une relation entre M1 et M2, pas propre à l'un des
deux ; reste au niveau racine de `GVL_IHM`, PAS nesté sous `M1TreuilRetenue`/`M2TreuilBenne`).

**Confirmé non mappé sur un écran IHM physique** — aucun risque de casser un mapping existant.

## 2. Objectif

1. Créer 4 nouveaux types dans `CODE/SUPERVISION/_TYPES/` : `ST_SyncCmd`, `ST_SyncState`,
   `ST_SyncCfg`, `ST_BypassSync`.
2. Modifier `ST_SyncHMI` pour composer ces 4 sous-structs (au lieu des champs plats).
3. Renommer le champ `GVL_IHM.Sync` → `GVL_IHM.M1M2Sync` dans `CODE/SUPERVISION/GVL_IHM.st`.
4. Mettre à jour **toutes** les références dans le code (liste exhaustive §5 — vérifiée par grep,
   ne pas en chercher d'autres, ne pas en oublier).
5. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_SyncHMI.st`

```
TYPE ST_SyncHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture) *)
    CfgSyncTolerance_M       : REAL := 0.25;
    CfgInitialized           : BOOL := FALSE;

    (* 🚦 États (Lecture seule) *)
    DeltaPos_M            : REAL;
    SyncActive          : BOOL;
    SyncWarn            : BOOL;
    Ready               : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;
    State               : E_State;

    (* 🎮 Commandes / Bypasses *)
    SelSyncEnable   : BOOL := TRUE;
    BypassGlobal    : BOOL := FALSE;
END_STRUCT
END_TYPE
```

## 4. Structure cible

⚠️ **Collision de nom** : le champ `State : E_State` (ligne existante, "état de l'automate
interne") entrerait en collision avec le nouveau sous-struct `State` (regroupement IHM). **Le
renommer en `FBState`** — c'est exactement la convention déjà utilisée dans `ST_WinchHMI`/
`ST_WinchState` pour ce même concept ("état de l'automate interne FB_Xxx"), donc cohérent avec
l'existant, pas une invention.

### `CODE/SUPERVISION/_TYPES/ST_SyncCmd.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_SyncCmd — Commandes IHM pour la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCmd :
STRUCT
    SelSyncEnable : BOOL := TRUE; (* ☑️ coché = synchro voulue (MAINT_N1/N2), ex-OverrideSync inversé *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_SyncState.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🚦 ST_SyncState — États et diagnostics de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncState :
STRUCT
    DeltaPos_M : REAL;    (* 📊 Écart de position réel mesuré (m) *)
    SyncActive : BOOL;    (* ⚖️ Indicateur si surveillance active *)
    SyncWarn   : BOOL;    (* ⚠️ LED d'alarme écart hors tolérance *)
    Ready      : BOOL;    (* 🟢 Bloc de synchro prêt *)
    Error      : BOOL;    (* 🔴 Alarme synchro active *)
    ErrorId    : WORD;    (* ❌ Code défaut synchro *)
    FBState    : E_State; (* 🤖 État de l'automate interne (FB_WinchSync) — ex-"State", renommé pour éviter collision avec le sous-struct State *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_SyncCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_SyncCfg — Configuration de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 0.25;  (* 📐 Tolérance max d'écart (m) *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot, ex-CfgInitialized renommé pour cohérence avec ST_WinchCfg *)
END_STRUCT
END_TYPE
```
⚠️ `CfgInitialized` devient `Initialized` (déjà le nom utilisé dans `ST_WinchCfg`/toutes les
autres structs `Cfg` — cohérence de nommage). Adapter en conséquence toutes les références (§5).

### `CODE/SUPERVISION/_TYPES/ST_BypassSync.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassSync — Bypass de la surveillance synchronisation M1/M2
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassSync :
STRUCT
    Global      : BOOL := FALSE;   (* 🌐 Bypass GLOBAL synchro : ignore toute erreur de synchronisation *)
    Initialized : BOOL := FALSE;   (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
```
⚠️ Pas de granularité `Safety`/`Process`/bit individuel ici — analysé précédemment : les bits de
`FB_WinchSync` (écart, incohérence commande) ne remontent QUE en `SafeStop`, jamais en
`PowerCutOff` directement (l'escalade critique réelle, Méca E, est un mécanisme indépendant dans
`FB_Safety_Winch`, hors périmètre de ce struct). Ne pas ajouter de champ supplémentaire ici.

### `CODE/SUPERVISION/_TYPES/ST_SyncHMI.st` (modifié, remplace le contenu actuel)
```
(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_SyncHMI — Données d'échange IHM pour la synchronisation M1/M2
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Bypass (2026-07-23), homogène avec ST_WinchHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncHMI :
STRUCT
    Cmd    : ST_SyncCmd;
    State  : ST_SyncState;
    Cfg    : ST_SyncCfg;
    Bypass : ST_BypassSync;
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif des références — TOUS les usages actuels, vérifiés par grep

Renommer chaque occurrence exactement comme indiqué (chemin ancien → nouveau) :

**`CODE/SUPERVISION/GVL_IHM.st`** (déclaration du champ) :
```
Sync : ST_SyncHMI;   →   M1M2Sync : ST_SyncHMI;
```

**`CODE/MAIN/PRG_04_Modes.st:39`** :
```
GVL_IHM.Sync.SelSyncEnable := TRUE;
→ GVL_IHM.M1M2Sync.Cmd.SelSyncEnable := TRUE;
```

**`CODE/MAIN/PRG_06_WinchControl.st:315`** :
```
BypassGlobal    := GVL_IHM.Sync.BypassGlobal
→ BypassGlobal    := GVL_IHM.M1M2Sync.Bypass.Global
```

**`CODE/MAIN/PRG_09_Supervision.st`** (8 lignes) :
```
L52:  GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.Sync.SelSyncEnable;
  →   GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable;

L187: IF NOT GVL_IHM.Sync.CfgInitialized THEN
  →   IF NOT GVL_IHM.M1M2Sync.Cfg.Initialized THEN
L188:     GVL_IHM.Sync.CfgSyncTolerance_M          := _WinchSyncTolerance_M;
  →       GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M          := _WinchSyncTolerance_M;
L189:     GVL_IHM.Sync.CfgInitialized := TRUE;
  →       GVL_IHM.M1M2Sync.Cfg.Initialized := TRUE;

L247: IF BypassSyncGlobal AND GVL_IHM.Sync.BypassGlobal = FALSE THEN
  →   IF BypassSyncGlobal AND GVL_IHM.M1M2Sync.Bypass.Global = FALSE THEN
L248:     GVL_IHM.Sync.BypassGlobal := TRUE;
  →       GVL_IHM.M1M2Sync.Bypass.Global := TRUE;

L281: IF GVL_IHM.Sync.CfgInitialized THEN
  →   IF GVL_IHM.M1M2Sync.Cfg.Initialized THEN
L282:     _WinchSyncTolerance_M       := GVL_IHM.Sync.CfgSyncTolerance_M;
  →       _WinchSyncTolerance_M       := GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M;

L360: BypassSyncGlobal            := GVL_IHM.Sync.BypassGlobal;
  →   BypassSyncGlobal            := GVL_IHM.M1M2Sync.Bypass.Global;

L534: GVL_IHM.Sync.DeltaPos_M   := PRG_06_WinchControl.instWinchSync.DeltaPosM;
  →   GVL_IHM.M1M2Sync.State.DeltaPos_M   := PRG_06_WinchControl.instWinchSync.DeltaPosM;
L535: GVL_IHM.Sync.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
  →   GVL_IHM.M1M2Sync.State.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
L536: GVL_IHM.Sync.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
  →   GVL_IHM.M1M2Sync.State.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
L537: GVL_IHM.Sync.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
  →   GVL_IHM.M1M2Sync.State.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
L538: GVL_IHM.Sync.Error      := PRG_06_WinchControl.instWinchSync.Error;
  →   GVL_IHM.M1M2Sync.State.Error      := PRG_06_WinchControl.instWinchSync.Error;
L539: GVL_IHM.Sync.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
  →   GVL_IHM.M1M2Sync.State.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
L540: GVL_IHM.Sync.State      := PRG_06_WinchControl.instWinchSync.State;
  →   GVL_IHM.M1M2Sync.State.FBState    := PRG_06_WinchControl.instWinchSync.State;
```
(numéros de ligne indicatifs, se référer au contenu exact du fichier — un `grep -n "GVL_IHM\.Sync"`
avant de commencer donne la liste réelle et à jour, ne pas supposer que les numéros n'ont pas
bougé depuis la rédaction de ce document)

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : aucune autre référence à `GVL_IHM.Sync`
n'existe ailleurs (ni `PLC_TESTS`, ni `PRG_05_Cycle` qui lit directement
`PRG_06_WinchControl.instWinchSync`, pas `GVL_IHM.Sync`). Si le grep de vérification en trouve
d'autres au moment de l'exécution (le code a pu bouger depuis), les traiter avec le même principe
de mapping, ne pas improviser un nouveau pattern.

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_SyncCmd.st` (nouveau)
2. `CODE/SUPERVISION/_TYPES/ST_SyncState.st` (nouveau)
3. `CODE/SUPERVISION/_TYPES/ST_SyncCfg.st` (nouveau)
4. `CODE/SUPERVISION/_TYPES/ST_BypassSync.st` (nouveau)
5. `CODE/SUPERVISION/_TYPES/ST_SyncHMI.st` (remplacé)
6. `CODE/SUPERVISION/GVL_IHM.st` (renommage du champ)
7. `CODE/MAIN/PRG_04_Modes.st`
8. `CODE/MAIN/PRG_06_WinchControl.st`
9. `CODE/MAIN/PRG_09_Supervision.st`
10. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas toucher** `FB_WinchSync.st` — cette FB n'a aucune raison de changer, seuls ses
  consommateurs (chemins `GVL_IHM`) sont renommés.
- **Ne pas toucher** au Lot 1a (fichiers déjà modifiés/committés, commit `303c44a`) — domaine
  différent, aucun chevauchement de fichier.
- **PascalCase strict**, pas de hongrois.
- Le renommage `CfgInitialized` → `Initialized` (dans `ST_SyncCfg`) doit être répercuté PARTOUT où
  ce champ est lu/écrit (voir §5) — ne pas laisser les deux noms coexister.

## 8. Obligatoire avant restitution

1. `grep -rn "GVL_IHM\.Sync\b" CODE/` doit retourner **zéro résultat** avant de considérer le lot
   terminé (uniquement `GVL_IHM.M1M2Sync` doit subsister).
2. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
3. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur
   par rapport à l'état actuel (des erreurs préexistantes sans lien avec ce lot peuvent déjà être
   présentes, ne pas les corriger, hors périmètre).
4. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 4 nouveaux fichiers struct créés exactement comme spécifié §4.
- [ ] `ST_SyncHMI.st` compose les 4 sous-structs, plus aucun champ plat.
- [ ] Champ `State` (enum) renommé `FBState` dans `ST_SyncState` — pas de collision de nom.
- [ ] `CfgInitialized` renommé `Initialized` dans `ST_SyncCfg`, cohérent avec `ST_WinchCfg`.
- [ ] `GVL_IHM.st` : champ renommé `M1M2Sync`, reste au niveau racine (pas nesté).
- [ ] `grep -rn "GVL_IHM\.Sync\b" CODE/` = zéro résultat.
- [ ] `FB_WinchSync.st` non modifié.
- [ ] Bundle régénéré et frais.
- [ ] Gates : pas de nouvelle erreur introduite.

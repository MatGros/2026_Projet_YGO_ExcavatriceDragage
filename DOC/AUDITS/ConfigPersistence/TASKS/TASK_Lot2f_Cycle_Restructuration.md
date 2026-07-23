# 📋 Document de Tâche — Lot 2f : Restructuration `GVL_IHM.Cycle` en `Cmd`/`State`/`Cfg`/`Test`
## ⚠️ Priorité sécurité — corrige T66 (persistance `SetDepth_M`/`SetOffset_M`)

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md` (**T66**), `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite des Lots 2a (`M1M2Sync`), 2b (`Bucket`), 2c (`Commun`), 2d (`Modes`), 2e (`Joystick`) —
> tous faits et vérifiés. Ce lot est indépendant, ne touche à aucun fichier des lots précédents.
> Ce lot est **le plus critique** du chantier : `SetDepth_M`/`SetOffset_M` n'ont AUJOURD'HUI aucune
> protection de persistance réelle (voir §1).

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande. Ne corrige pas silencieusement, ne l'ignore pas.
  Ce lot touche à la persistance de paramètres de sécurité (profondeur de dragage cible) — sois
  particulièrement attentif à tout ce qui semblerait faire écraser une valeur opérateur par un
  défaut usine.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §6** — toute modification hors périmètre (ex. outillage
  Python, autre struct) doit être signalée séparément dans ta restitution, jamais appliquée
  silencieusement en plus de ce qui est demandé.
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté** — ne reste jamais bloqué par manque de contexte sans avoir essayé. Pointeurs utiles
  pour ce lot précis :
  - `DOC/NAMING_CONVENTION.md` — convention de nommage si un doute PascalCase/sémantique.
  - `DOC/AUDITS/ConfigPersistence/TASKS/TASK_Lot2a_M1M2Sync_Restructuration.md` — lot le plus
    proche question persistance `Cfg` (crée `ST_SyncCfg` + flag `Initialized` + câblage
    `PRG_09_Supervision.st`), même mécanique à reproduire ici pour `SetDepth_M`/`SetOffset_M`.
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier**, sections "── 2. INITIALISATION IHM DEPUIS
    GVL_PERSISTENT (Boot)" et "── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE" — c'est LE pattern
    de référence à reproduire à l'identique pour `Cycle.Cfg` (voir §5.3/§5.4 ci-dessous pour
    l'extrait exact déjà écrit, mais relis le fichier réel avant d'appliquer, il a pu bouger).
  - `CODE/GVL_PERSISTENT.st` — pour voir le style de déclaration/commentaire des variables
    persistantes existantes avant d'y ajouter les 2 nouvelles.
  - `CODE/CYCLE/FB_Cycle.st` — le FB métier lui-même, pour confirmer qu'il ne référence AUCUN
    chemin `GVL_IHM` en interne (seul son appelant `PRG_05_Cycle.st` le fait) avant de le classer
    hors périmètre.
  - Si aucun de ces pointeurs ne suffit à lever le doute : c'est le moment de t'arrêter et de
    signaler, pas de deviner.

## 1. Contexte — pourquoi ce lot est prioritaire (T66)

`GVL_IHM.Cycle` (type `ST_CycleHMI`) est un groupe plat qui mélange commandes opérateur, deux
réglages critiques (`SetDepth_M`/`SetOffset_M`), états calculés et un sous-struct de test déjà
existant (`Test : ST_TestCycle`).

**Le vrai problème (T66)** : contrairement à TOUS les autres domaines déjà traités dans ce
chantier (Winch, Translation, Sync, Bucket, Commun), **`SetDepth_M`/`SetOffset_M` n'ont AUCUNE
variable `GVL_PERSISTENT` de secours aujourd'hui** — vérifié par grep sur `CODE/GVL_PERSISTENT.st` :
aucune variable `_CycleSetDepth_M`/`_CycleSetOffset_M` n'existe. Ces 2 champs n'ont qu'un défaut
compilé dans le DUT (`SetDepth_M : REAL := -12.5;`, `SetOffset_M : REAL := 1.5;`) et vivent
uniquement dans `GVL_IHM` (`VAR_GLOBAL RETAIN`, pas `PERSISTENT`). Concrètement :
- `RETAIN` simple survit à un Warm Restart, mais est **invalidé par tout changement de layout** du
  DUT `ST_CycleHMI` (ex. justement CE lot, qui restructure ce struct) ou par un Cold
  Restart/Download avec incompatibilité.
- Quand ça arrive, la valeur retombe **silencieusement** au défaut compilé (-12.5 m / 1.5 m) —
  aucune alarme, aucun moyen de savoir que la vraie valeur réglée par l'opérateur a disparu. Pire
  que le bug initial de ce chantier (`CfgMaxStepDescente`) car il n'existe même pas de filet
  `GVL_PERSISTENT` à restaurer depuis.

**Objectif de ce lot** : ne pas se contenter de déplacer `SetDepth_M`/`SetOffset_M` dans un
sous-struct `Cfg` — il faut aussi **créer leur backing `GVL_PERSISTENT` et le câblage
restauration/sauvegarde**, exactement selon le pattern déjà en place pour tous les autres `Cfg`
(voir §5.3/§5.4). Sans ce câblage, le problème resterait entier malgré la restructuration.

**Confirmé non mappé sur un écran IHM physique** (comme les lots précédents) — aucun risque de
casser un mapping existant.

## 2. Objectif

1. Créer 3 nouveaux types dans `CODE/SUPERVISION/_TYPES/` : `ST_CycleCmd`, `ST_CycleState`,
   `ST_CycleCfg` (avec flag `Initialized`).
2. Réécrire `ST_CycleHMI` pour composer `Cmd`/`State`/`Cfg`/`Test` — **`Test : ST_TestCycle` reste
   INCHANGÉ**, c'est déjà un sous-struct correctement isolé, ne pas le toucher ni le renommer.
3. Ajouter à `CODE/GVL_PERSISTENT.st` : `_CycleSetDepth_M : REAL := -12.5;` et
   `_CycleSetOffset_M : REAL := 1.5;` (mêmes valeurs par défaut que le DUT actuel — aucun
   changement de comportement pour un premier boot après ce lot, la protection ne joue que pour
   les reprogrammations futures).
4. Ajouter dans `CODE/MAIN/PRG_09_Supervision.st` le bloc de restauration boot (§2) ET le bloc de
   sauvegarde continue (§3) pour `Cycle.Cfg`, suivant EXACTEMENT le pattern déjà en place pour
   `M1M2Sync.Cfg` (voir §5.3/§5.4 — c'est un copier-coller adapté, pas une nouvelle invention).
5. Mettre à jour **toutes** les références (liste exhaustive §5 — vérifiée par grep, ne pas en
   chercher d'autres, ne pas en oublier), y compris `PRG_05_Cycle.st` et 2 suites `PLC_TESTS`.
6. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_CycleHMI.st`

```
(* 🔄 Interface IHM du cycle semi-automatique.
   Les commandes Cmd* sont des impulsions acquittées par le PLC. *)
TYPE ST_CycleHMI :
STRUCT
    BtnStart             : BOOL;
    BtnPause             : BOOL;
    BtnAbort             : BOOL;
    BtnReset             : BOOL;
    SetDepth_M          : REAL := -12.5;
    SetOffset_M         : REAL := 1.5;
    Ready                : BOOL;
    Busy                 : BOOL;
    Done                 : BOOL;
    Error                : BOOL;
    ErrorId              : WORD;
    CycleStep            : E_CycleStep;
    CycleStateStr        : STRING(80);
    SelTarget    : INT;
    KoboldContactFond    : BOOL;
    KoboldContactorCmd   : BOOL;
    LimitLegalReached    : BOOL;
    LimitLegalDepth_M      : REAL;
    WinchSyncError       : BOOL;
    WinchSyncDelta_M       : REAL;
    SpeedMismatch_Mps      : REAL;
    SpeedMismatchActive  : BOOL;
    SpeedMismatchConfirmed : BOOL;
    M1Position_M           : REAL;
    M2Position_M           : REAL;
    DeadmanArmed         : BOOL;
    JoystickMotionActive : BOOL;
    MotionPermit         : BOOL;
    Test                 : ST_TestCycle;
END_STRUCT
END_TYPE
```
`ST_TestCycle` (déjà existant, **ne pas toucher**, contenu pour référence uniquement) :
```
TYPE ST_TestCycle :
STRUCT
    KoboldContactFond : BOOL; (* 🔌 Simulation du capteur de contact de fond Kobold *)
END_STRUCT
END_TYPE
```

## 4. Structure cible — classement Cmd/State/Cfg (vérifié par balayage exhaustif de toutes les
références du projet — voir §5, chaque champ n'a qu'un seul usage cohérent)

**Cmd** (4) : `BtnStart`, `BtnPause`, `BtnAbort`, `BtnReset`.

**Cfg** (2, + `Initialized`) : `SetDepth_M`, `SetOffset_M` — **priorité T66**, voir §1.

**State** (22) : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `CycleStep`, `CycleStateStr`,
`SelTarget`, `KoboldContactFond`, `KoboldContactorCmd`, `LimitLegalReached`, `LimitLegalDepth_M`,
`WinchSyncError`, `WinchSyncDelta_M`, `SpeedMismatch_Mps`, `SpeedMismatchActive`,
`SpeedMismatchConfirmed`, `M1Position_M`, `M2Position_M`, `DeadmanArmed`, `JoystickMotionActive`,
`MotionPermit`.
👉 `SelTarget` va dans `State` bien qu'il soit à l'origine une commande : ici c'est un **miroir en
lecture seule** de `GVL_IHM.TranslationM3.Cmd.SelTarget` (voir `PRG_09_Supervision.st` L619 —
`GVL_IHM.Cycle.SelTarget := GVL_IHM.TranslationM3.Cmd.SelTarget;`), le PLC l'écrit, l'IHM ne fait
que le lire depuis `Cycle`. `KoboldContactFond` (hors `Test`) est le retour **physique réel** du
capteur (`PRG_00_Inputs.KoboldContactFond`), différent du `Test.KoboldContactFond` qui est la
**simulation** de ce même capteur — les deux coexistent, ne pas les confondre ni les fusionner.

**Test** (1, INCHANGÉ) : `Test : ST_TestCycle` — déjà un sous-struct correctement isolé.

### `CODE/SUPERVISION/_TYPES/ST_CycleCmd.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleCmd — Commandes IHM pour le cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCmd :
STRUCT
    BtnStart : BOOL; (* ▶️ Lancement cycle automatique *)
    BtnPause : BOOL; (* ⏸️ Pause cycle automatique *)
    BtnAbort : BOOL; (* ⏹️ Abandon / arrêt cycle automatique *)
    BtnReset : BOOL; (* 🔁 Reset dédié FB_Cycle, jamais mélangé au reset défauts général (REX 2026-07-07) *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_CycleCfg.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_CycleCfg — Configuration du cycle semi-automatique
   🐛 T66 : SetDepth_M/SetOffset_M protégés par persistance GVL_PERSISTENT (voir PRG_09_Supervision.st §2/§3)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M  : REAL := -12.5; (* 📐 Profondeur de dragage cible (m, négative) *)
    SetOffset_M : REAL := 1.5;   (* 📐 Décalage cible de fermeture de la benne (m) *)
    Initialized : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_CycleState.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🚦 ST_CycleState — États et diagnostics IHM du cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleState :
STRUCT
    Ready                  : BOOL;          (* 🟢 Séquenceur prêt *)
    Busy                   : BOOL;          (* ⚙️ Cycle en cours *)
    Done                   : BOOL;          (* ✅ Cycle terminé *)
    Error                  : BOOL;          (* 🔴 Défaut cycle *)
    ErrorId                : WORD;          (* ❌ Code défaut cycle *)
    CycleStep              : E_CycleStep;   (* 🔄 Étape courante du Grafcet *)
    CycleStateStr          : STRING(80);    (* 📝 Libellé texte de l'étape courante *)
    SelTarget              : INT;           (* 🎯 Miroir lecture seule de GVL_IHM.TranslationM3.Cmd.SelTarget *)
    KoboldContactFond      : BOOL;          (* 🔌 Retour physique réel capteur contact de fond Kobold *)
    KoboldContactorCmd     : BOOL;          (* 🔌 Commande contacteur Kobold (calculée par FB_Cycle) *)
    LimitLegalReached      : BOOL;          (* 📐 Miroir de GVL_IHM.Commun.LimitLegalReached *)
    LimitLegalDepth_M      : REAL;          (* 📐 Miroir de GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M *)
    WinchSyncError         : BOOL;          (* ⚖️ Miroir de l'erreur synchro M1/M2 *)
    WinchSyncDelta_M       : REAL;          (* ⚖️ Miroir de l'écart synchro M1/M2 *)
    SpeedMismatch_Mps      : REAL;          (* 🐢 Écart de vitesse mesuré (T43/T45) *)
    SpeedMismatchActive    : BOOL;          (* 🐢 Écart de vitesse détecté *)
    SpeedMismatchConfirmed : BOOL;          (* 🐢 Écart de vitesse confirmé *)
    M1Position_M           : REAL;          (* 📊 Position câble M1 *)
    M2Position_M           : REAL;          (* 📊 Position câble M2 *)
    DeadmanArmed           : BOOL;          (* 🔫 Homme-mort joystick armé *)
    JoystickMotionActive   : BOOL;          (* 🕹️ Mouvement joystick actif *)
    MotionPermit           : BOOL;          (* 🟢 Homme-mort + axe Y actif (CycleMotionPermit) *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_CycleHMI.st` (modifié, remplace le contenu actuel)
```
(* ═══════════════════════════════════════════════════════════════
   🔄 ST_CycleHMI — Données d'échange IHM du cycle semi-automatique
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg / Test (2026-07-24), homogène avec ST_WinchHMI.
   🐛 T66 : Cfg protégé par persistance GVL_PERSISTENT (voir PRG_09_Supervision.st §2/§3) —
   avant ce lot, SetDepth_M/SetOffset_M n'avaient AUCUN backing persistant (juste un défaut
   compilé dans le DUT), contrairement à tous les autres domaines déjà traités.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleHMI :
STRUCT
    Cmd   : ST_CycleCmd;
    State : ST_CycleState;
    Cfg   : ST_CycleCfg;
    Test  : ST_TestCycle; (* ⚠️ INCHANGÉ — déjà un sous-struct correctement isolé avant ce lot *)
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif des références — vérifié par grep, ne pas en chercher d'autres

### 5.1 — `CODE/GVL_PERSISTENT.st` (ajout, pas de modification de l'existant)

⚠️ **Chemin reconfirmé le 2026-07-24** : `CODE/GVL_PERSISTENT.st` (racine de `CODE/`, PAS
`CODE/MAIN/`) — vérifié `git ls-files CODE/GVL_PERSISTENT.st` (fichier suivi) et
`git log --oneline -- CODE/GVL_PERSISTENT.st` (existe depuis le commit `7727123`, bien avant ce
chantier, donc présent sur `origin/main`). Si ce fichier reste introuvable de ton côté : fais
d'abord un `git status`/`git pull`/`git fetch` pour vérifier que ton checkout local est bien
synchronisé avec `origin/main` avant de conclure que le chemin est faux — signale-le si le
problème persiste après vérification de la synchro.

Ajouter une nouvelle section (juste avant la section `// 📏 RÉGLEMENTATION / LÉGAL`, ou à un autre
endroit cohérent si le fichier a changé — l'important est la présence des 2 variables, pas leur
position exacte) :
```
    // 🔄 CYCLE (dragage semi-automatique)
    _CycleSetDepth_M  : REAL := -12.5; // T66 : profondeur de dragage cible (m, négative)
    _CycleSetOffset_M : REAL := 1.5;   // T66 : décalage cible de fermeture benne (m)

```
⚠️ Valeurs par défaut **identiques** à celles du DUT actuel (`-12.5`/`1.5`) — aucune surprise pour
un premier boot après ce lot.

### 5.2 — `CODE/SUPERVISION/GVL_IHM.st`

Aucune modification du champ `Cycle : ST_CycleHMI;` lui-même (nom/position inchangés) — seul le
type `ST_CycleHMI` change de contenu (voir §4). Vérifier qu'aucune référence `GVL_IHM.Cycle.` en
commentaire n'existe dans ce fichier (grep négatif attendu, sweep déjà fait — aucune trouvée).

### 5.3 — `CODE/MAIN/PRG_09_Supervision.st` — bloc de restauration boot (§2 du fichier)

**Ajouter**, dans la section "── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot)" (à la suite
du bloc existant `IF NOT GVL_IHM.Commun.Cfg.Initialized THEN ... END_IF;`, même style, même
principe que `M1M2Sync.Cfg` déjà en place) :
```
IF NOT GVL_IHM.Cycle.Cfg.Initialized THEN
    GVL_IHM.Cycle.Cfg.SetDepth_M  := _CycleSetDepth_M;
    GVL_IHM.Cycle.Cfg.SetOffset_M := _CycleSetOffset_M;
    GVL_IHM.Cycle.Cfg.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE; // ⚠️ Restauration détectée — acquittement opérateur requis (§2bis)
END_IF;
```
(même style EXACT que le bloc `M1M2Sync.Cfg` : `GVL_Modes_Stub`/alarme incluse — ce champ est
maintenant assez critique pour justifier la même alarme `ConfigRestoredFromPersistent` que Winch/
Sync/Commun, contrairement à un bypass qui n'a pas cette alarme).

### 5.4 — `CODE/MAIN/PRG_09_Supervision.st` — bloc de sauvegarde continue (§3 du fichier)

**Ajouter**, dans la section "── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE" (à la suite du
bloc existant `IF GVL_IHM.Commun.Cfg.Initialized THEN ... END_IF;`, même garde `Initialized` que
tous les autres, pattern déjà établi — défense en profondeur, jamais d'écriture PERSISTENT avant
que la restauration ait eu lieu) :
```
IF GVL_IHM.Cycle.Cfg.Initialized THEN
    _CycleSetDepth_M  := GVL_IHM.Cycle.Cfg.SetDepth_M;
    _CycleSetOffset_M := GVL_IHM.Cycle.Cfg.SetOffset_M;
END_IF;
```

### 5.5 — `CODE/MAIN/PRG_09_Supervision.st` — mapping état → IHM (section "── 9./10. MAPPING
CYCLE → IHM", lignes ~612-630 actuelles)

```
L612: GVL_IHM.Cycle.Ready                := PRG_05_Cycle.instCycle.Ready;
  →   GVL_IHM.Cycle.State.Ready                := PRG_05_Cycle.instCycle.Ready;
L613: GVL_IHM.Cycle.Busy                 := PRG_05_Cycle.instCycle.Busy;
  →   GVL_IHM.Cycle.State.Busy                 := PRG_05_Cycle.instCycle.Busy;
L614: GVL_IHM.Cycle.Done                 := PRG_05_Cycle.instCycle.Done;
  →   GVL_IHM.Cycle.State.Done                 := PRG_05_Cycle.instCycle.Done;
L615: GVL_IHM.Cycle.Error                := PRG_05_Cycle.instCycle.Error;
  →   GVL_IHM.Cycle.State.Error                := PRG_05_Cycle.instCycle.Error;
L616: GVL_IHM.Cycle.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
  →   GVL_IHM.Cycle.State.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
L617: GVL_IHM.Cycle.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
  →   GVL_IHM.Cycle.State.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
L618: GVL_IHM.Cycle.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
  →   GVL_IHM.Cycle.State.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
L619: GVL_IHM.Cycle.SelTarget    := GVL_IHM.TranslationM3.Cmd.SelTarget;
  →   GVL_IHM.Cycle.State.SelTarget    := GVL_IHM.TranslationM3.Cmd.SelTarget;
L620: GVL_IHM.Cycle.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
  →   GVL_IHM.Cycle.State.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
L621: GVL_IHM.Cycle.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
  →   GVL_IHM.Cycle.State.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
L622: GVL_IHM.Cycle.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
  →   GVL_IHM.Cycle.State.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
L623: GVL_IHM.Cycle.LimitLegalDepth_M      := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
  →   GVL_IHM.Cycle.State.LimitLegalDepth_M      := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
L624: GVL_IHM.Cycle.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
  →   GVL_IHM.Cycle.State.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
L625: GVL_IHM.Cycle.WinchSyncDelta_M       := PRG_06_WinchControl.instWinchSync.DeltaPosM;
  →   GVL_IHM.Cycle.State.WinchSyncDelta_M       := PRG_06_WinchControl.instWinchSync.DeltaPosM;
L626: GVL_IHM.Cycle.M1Position_M           := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
  →   GVL_IHM.Cycle.State.M1Position_M           := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
L627: GVL_IHM.Cycle.M2Position_M           := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
  →   GVL_IHM.Cycle.State.M2Position_M           := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
L628: GVL_IHM.Cycle.DeadmanArmed         := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
  →   GVL_IHM.Cycle.State.DeadmanArmed         := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
L629: GVL_IHM.Cycle.JoystickMotionActive := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
  →   GVL_IHM.Cycle.State.JoystickMotionActive := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
L630: GVL_IHM.Cycle.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;
  →   GVL_IHM.Cycle.State.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;
```

### 5.6 — `CODE/MAIN/PRG_00_Inputs.st` (lignes 138-141, purge boot des commandes)

```
GVL_IHM.Cycle.BtnStart := FALSE;   → GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
GVL_IHM.Cycle.BtnPause := FALSE;   → GVL_IHM.Cycle.Cmd.BtnPause := FALSE;
GVL_IHM.Cycle.BtnAbort := FALSE;   → GVL_IHM.Cycle.Cmd.BtnAbort := FALSE;
GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
```

### 5.7 — `CODE/MAIN/PRG_05_Cycle.st` (lignes 33-39, lecture commandes/config ; lignes 90-98,
retours état + purge)

```
L33: CmdStartCycle_IHM := GVL_IHM.Cycle.BtnStart;
  →  CmdStartCycle_IHM := GVL_IHM.Cycle.Cmd.BtnStart;
L34: CmdPauseCycle_IHM := GVL_IHM.Cycle.BtnPause;
  →  CmdPauseCycle_IHM := GVL_IHM.Cycle.Cmd.BtnPause;
L35: CmdAbortCycle_IHM := GVL_IHM.Cycle.BtnAbort;
  →  CmdAbortCycle_IHM := GVL_IHM.Cycle.Cmd.BtnAbort;
L36: CmdResetCycle_IHM := GVL_IHM.Cycle.BtnReset;
  →  CmdResetCycle_IHM := GVL_IHM.Cycle.Cmd.BtnReset;
L37: SetDepthM      := GVL_IHM.Cycle.SetDepth_M;
  →  SetDepthM      := GVL_IHM.Cycle.Cfg.SetDepth_M;
L38: SetOffsetM     := GVL_IHM.Cycle.SetOffset_M;
  →  SetOffsetM     := GVL_IHM.Cycle.Cfg.SetOffset_M;
L39: GVL_Simulation.SimKoboldContactFondValue := GVL_IHM.Cycle.Test.KoboldContactFond;
  →  (INCHANGÉ — Test.KoboldContactFond ne bouge pas, déjà correctement isolé)

L90: GVL_IHM.Cycle.SpeedMismatch_Mps         := instCycle.SpeedMismatchMps;
  →  GVL_IHM.Cycle.State.SpeedMismatch_Mps         := instCycle.SpeedMismatchMps;
L91: GVL_IHM.Cycle.SpeedMismatchActive     := instCycle.SpeedMismatchActive;
  →  GVL_IHM.Cycle.State.SpeedMismatchActive     := instCycle.SpeedMismatchActive;
L92: GVL_IHM.Cycle.SpeedMismatchConfirmed  := instCycle.SpeedMismatchConfirmed;
  →  GVL_IHM.Cycle.State.SpeedMismatchConfirmed  := instCycle.SpeedMismatchConfirmed;

L95: GVL_IHM.Cycle.BtnStart := FALSE;   → GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
L96: GVL_IHM.Cycle.BtnPause := FALSE;   → GVL_IHM.Cycle.Cmd.BtnPause := FALSE;
L97: GVL_IHM.Cycle.BtnAbort := FALSE;   → GVL_IHM.Cycle.Cmd.BtnAbort := FALSE;
L98: GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
```
⚠️ Ne pas toucher aux paramètres `VAR_INPUT` de l'appel `instCycle(...)` (`SetDepthM := SetDepthM`,
etc. lignes 57-58) — ils utilisent déjà les variables locales `SetDepthM`/`SetOffsetM` du
`PROGRAM`, pas directement `GVL_IHM`, donc rien à changer là.

### 5.8 — `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st` (lignes 18 commentaire,
97, 359 commentaire, 363, 365, 533, 545 — tous `Cmd`)

```
L18 (commentaire) : démarrage (`GVL_IHM.Cycle.CmdStart`) hors SEMI_AUTO reste sans effet.
  →  (commentaire déjà obsolète avant ce lot — le vrai nom est BtnStart, pas CmdStart — corriger
     en `GVL_IHM.Cycle.Cmd.BtnStart` tant qu'on touche cette ligne, signaler si le texte a encore
     bougé)
L97:  GVL_IHM.Cycle.BtnStart := FALSE;
  →   GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
L359 (commentaire) : démarrage (GVL_IHM.Cycle.BtnStart, ré-assertée chaque scan pour couvrir l'ordre
  →  démarrage (GVL_IHM.Cycle.Cmd.BtnStart, ré-assertée chaque scan pour couvrir l'ordre
L363: GVL_IHM.Cycle.BtnStart := TRUE;
  →   GVL_IHM.Cycle.Cmd.BtnStart := TRUE;
L365:     GVL_IHM.Cycle.BtnStart := FALSE;
  →       GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
L533: GVL_IHM.Cycle.BtnStart := TRUE;
  →   GVL_IHM.Cycle.Cmd.BtnStart := TRUE;
L545:            AND NOT GVL_IHM.Cycle.BtnStart
  →              AND NOT GVL_IHM.Cycle.Cmd.BtnStart
```

### 5.9 — `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_HeartbeatValidation.st` (lignes 105, 127,
407, 445, 466 — tous `Cmd`, champ `BtnReset`)

```
L105: GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
L127: GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
L407: GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
L445:     GVL_IHM.Cycle.BtnReset := TRUE;   →     GVL_IHM.Cycle.Cmd.BtnReset := TRUE;
L466: GVL_IHM.Cycle.BtnReset := FALSE;   → GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
```

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : aucune autre référence à `GVL_IHM.Cycle.`
n'existe ailleurs. Si le grep de vérification en trouve d'autres au moment de l'exécution (le code
a pu bouger depuis), les traiter avec le même principe de mapping, ne pas improviser un nouveau
pattern.

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_CycleCmd.st` (nouveau)
2. `CODE/SUPERVISION/_TYPES/ST_CycleState.st` (nouveau)
3. `CODE/SUPERVISION/_TYPES/ST_CycleCfg.st` (nouveau)
4. `CODE/SUPERVISION/_TYPES/ST_CycleHMI.st` (remplacé)
5. `CODE/GVL_PERSISTENT.st` (ajout de 2 variables, §5.1)
6. `CODE/MAIN/PRG_00_Inputs.st`
7. `CODE/MAIN/PRG_05_Cycle.st`
8. `CODE/MAIN/PRG_09_Supervision.st` (mapping §5.5 + nouveaux blocs restauration/sauvegarde §5.3/§5.4)
9. `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st`
10. `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_HeartbeatValidation.st`
11. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **`Test : ST_TestCycle` reste absolument inchangé** — ne pas le renommer, ne pas le fusionner
  dans `State`, ne pas modifier `ST_TestCycle.st` lui-même.
- **Ne pas toucher** `CODE/CYCLE/FB_Cycle.st` — cette FB n'a aucune raison de changer, seul son
  appelant (`PRG_05_Cycle.st`) est modifié, et seulement pour les lignes qui lisent/écrivent
  `GVL_IHM.Cycle.*` (pas les paramètres `VAR_INPUT` de l'appel `instCycle(...)`, voir §5.7).
- **Ne pas toucher** aux fichiers des Lots 1a/2a/2b/2c/2d/2e (déjà committés/vérifiés).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage —
  hors périmètre strict de ce lot (rappel explicite, déjà signalé aux lots précédents).
- **Les 2 nouvelles variables `GVL_PERSISTENT`** doivent avoir EXACTEMENT les mêmes valeurs par
  défaut que le DUT actuel (`-12.5`/`1.5`) — ne pas les changer, même si elles semblent
  arbitraires, ce n'est pas l'objet de ce lot.
- **PascalCase strict**, pas de hongrois.

## 8. Obligatoire avant restitution

1. `grep -rn "GVL_IHM\.Cycle\.\(BtnStart\|BtnPause\|BtnAbort\|BtnReset\|SetDepth_M\|SetOffset_M\|Ready\|Busy\|Done\|Error\|ErrorId\|CycleStep\|CycleStateStr\|SelTarget\|KoboldContactFond\|KoboldContactorCmd\|LimitLegalReached\|LimitLegalDepth_M\|WinchSyncError\|WinchSyncDelta_M\|SpeedMismatch_Mps\|SpeedMismatchActive\|SpeedMismatchConfirmed\|M1Position_M\|M2Position_M\|DeadmanArmed\|JoystickMotionActive\|MotionPermit\)\b" CODE/ --include=*.st`
   doit retourner **zéro résultat** (toutes les occurrences doivent passer par `.Cmd.`, `.State.`
   ou `.Cfg.`).
2. `grep -n "_CycleSetDepth_M\|_CycleSetOffset_M" CODE/GVL_PERSISTENT.st CODE/MAIN/PRG_09_Supervision.st`
   doit montrer les 2 variables déclarées ET utilisées dans les 2 blocs (restauration §5.3 +
   sauvegarde §5.4).
3. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
4. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur
   (une erreur Gate 1 pré-existante sans lien avec ce lot peut déjà être présente, ne pas la
   corriger, hors périmètre).
5. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 3 nouveaux fichiers struct créés exactement comme spécifié §4.
- [ ] `ST_CycleHMI.st` compose `Cmd`/`State`/`Cfg`/`Test` — `Test : ST_TestCycle` inchangé.
- [ ] Tous les champs classés exactement comme en §4 (4 Cmd, 22 State, 2 Cfg + `Initialized`
      nouveau, 1 Test substruct — 4+2+22+1 = 29 champs/substructs comme l'original `ST_CycleHMI`
      [correction 2026-07-24 : le document initial disait 21/28 par erreur d'addition, la liste
      de champs elle-même était correcte], aucun oublié ni dupliqué).
- [ ] `CODE/GVL_PERSISTENT.st` : `_CycleSetDepth_M`/`_CycleSetOffset_M` ajoutées, mêmes valeurs
      par défaut que le DUT actuel.
- [ ] `PRG_09_Supervision.st` : bloc de restauration `Cycle.Cfg.Initialized` (§5.3) ET bloc de
      sauvegarde continue gardé par `IF GVL_IHM.Cycle.Cfg.Initialized THEN` (§5.4) présents,
      suivant EXACTEMENT le pattern déjà en place pour `M1M2Sync.Cfg`.
- [ ] Alarme `GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;` incluse dans le bloc de
      restauration `Cycle.Cfg` (même traitement que Winch/Sync/Commun).
- [ ] Sweep complet des 6 fichiers listés en §6 (hors nouveaux structs/GVL_PERSISTENT).
- [ ] `grep` de vérification §8.1 = zéro résultat.
- [ ] `FB_Cycle.st` non modifié.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

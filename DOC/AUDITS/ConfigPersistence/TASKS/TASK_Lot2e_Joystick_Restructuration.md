# 📋 Document de Tâche — Lot 2e : Restructuration `GVL_IHM.JOY1Joystick` en `Cmd`/`State`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite des Lots 2a (`M1M2Sync`), 2b (`Bucket`), 2c (`Commun`), 2d (`Modes`) — tous faits et
> vérifiés. Ce lot est indépendant, ne touche à aucun fichier des lots précédents.

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
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté** — ne reste jamais bloqué par manque de contexte sans avoir essayé. Pointeurs utiles
  pour ce lot précis :
  - `DOC/NAMING_CONVENTION.md` — convention de nommage si un doute PascalCase/sémantique.
  - `DOC/AUDITS/ConfigPersistence/TASKS/TASK_Lot2d_Modes_Restructuration.md` — lot précédent le
    plus proche (split `Cmd`/`State` seul, sans `Cfg`/`Bypass`), même structure de document.
  - `CODE/SUPERVISION/_TYPES/ST_ModesHMI.st`, `ST_ModesCmd.st`, `ST_ModesState.st` — exemple déjà
    en place d'un split `Cmd`/`State` pur (2 sous-structs, pas 4), pour comparer le style exact.
  - `CODE/JOYSTICK/FB_Joystick.st` — le FB métier lui-même, pour confirmer qu'il ne référence AUCUN
    chemin `GVL_IHM` en interne (seuls ses appelants `PRG_01_Diagnostics.st`/`PRG_09_Supervision.st`
    le font) avant de le classer hors périmètre.
  - `CODE/MAIN/PRG_09_Supervision.st` en entier (pas seulement l'extrait cité en §5) — si le
    contexte autour d'une ligne citée manque pour comprendre un usage.
  - Si aucun de ces pointeurs ne suffit à lever le doute : c'est le moment de t'arrêter et de
    signaler, pas de deviner.

## 1. Contexte

`GVL_IHM.JOY1Joystick` (type `ST_JoystickHMI`) est un groupe plat qui mélange **une commande
opérateur** (`BtnCalibrate` — demande de recalage au neutre) et **des états calculés par le PLC**
(valeurs brutes, consignes normalisées, diagnostics, neutres calibrés en lecture seule).
Contrairement à Sync/Bucket/Commun, **ce domaine n'a besoin QUE d'un split `Cmd`/`State`** — même
motif que le Lot 2d (Modes) :
- Pas de `Cfg` : les vrais réglages de calibration (`_JoystickNeutralX/Y`, `_JoystickInvertX/Y`,
  `_JoystickDeadband_Pct`, `_JoystickFilterTime`) vivent dans `GVL_PERSISTENT`, **pas** dans
  `ST_JoystickHMI` — ce struct ne contient que des valeurs lues, jamais les réglages eux-mêmes. Ne
  pas essayer de les y rapatrier, hors périmètre de ce lot.
- Pas de `Bypass` : `ST_JoystickHMI` ne porte aujourd'hui aucun concept de bypass.

**Confirmé non mappé sur un écran IHM physique** (comme les lots précédents) — aucun risque de
casser un mapping existant.

⚠️ **Hors périmètre explicite (connu, PAS à corriger ici)** : `BtnCalibrate` ne réécrit
aujourd'hui PAS `GVL_PERSISTENT._JoystickNeutralX/Y` (bug de câblage retour de calibration,
identifié précédemment, traité dans un lot ultérieur — persistance généralisée). Ce lot ne change
QUE la structure IHM (`Cmd`/`State`), pas la logique de calibration.

## 2. Objectif

1. Créer 2 nouveaux types dans `CODE/SUPERVISION/_TYPES/` : `ST_JoystickCmd`, `ST_JoystickState`.
2. Réécrire `ST_JoystickHMI` pour composer ces 2 sous-structs.
3. Mettre à jour **toutes** les références (liste exhaustive §5 — vérifiée par grep, ne pas en
   chercher d'autres, ne pas en oublier). Périmètre volontairement petit : seulement 3 fichiers.
4. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_JoystickHMI.st`

```
TYPE ST_JoystickHMI :
STRUCT
    RawX        : INT;        (* 🕹️ Axe X brut du joystick (0..10000) *)
    RawY        : INT;        (* 🕹️ Axe Y brut du joystick (0..10000) *)
    RawButton   : BOOL;       (* 🔘 Bouton homme-mort brut *)
    AxisCmdX    : ST_AxisCmd; (* ⚙️ Consigne d'axe X normalisée (sortie FB_Joystick) *)
    AxisCmdY    : ST_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée (sortie FB_Joystick) *)
    NeutralXAct : INT;        (* 🎯 Neutre X calibré actuel (lecture seule) *)
    NeutralYAct : INT;        (* 🎯 Neutre Y calibré actuel (lecture seule) *)
    DeadmanArmed : BOOL;      (* 🔫 Geste homme-mort armé (FB_Joystick.DeadmanArmed) *)
    Online      : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational : BOOL;       (* 🟢 Joystick opérationnel *)
    BtnCalibrate   : BOOL;       (* 🎯 Demande de recalage au neutre *)
    Error       : BOOL;       (* 🔴 Joystick en défaut *)
    ErrorId     : WORD;       (* ❌ Code défaut joystick *)
END_STRUCT
END_TYPE
```

## 4. Structure cible — classement Cmd/State (vérifié par balayage exhaustif de toutes les
références du projet — voir §5, chaque champ n'a qu'un seul usage cohérent)

**Cmd** (écrit par l'IHM, consommé par le PLC) : **uniquement `BtnCalibrate`** — c'est le seul champ
que l'opérateur écrit ; le PLC le lit (`PRG_01_Diagnostics.st`) puis le remet à `FALSE` après
consommation (`PRG_00_Inputs.st`, purge boot), même principe que les boutons Cmd des autres
domaines.

**State** (calculé par le PLC, lu par l'IHM) : `RawX`, `RawY`, `RawButton`, `AxisCmdX`, `AxisCmdY`,
`NeutralXAct`, `NeutralYAct`, `DeadmanArmed`, `Online`, `Operational`, `Error`, `ErrorId`.
👉 **`NeutralXAct`/`NeutralYAct` vont dans `State`** (pas `Cfg`) : ce sont des valeurs **lecture
seule**, calculées/reflétées par le PLC depuis `GVL_PERSISTENT._JoystickNeutralX/Y` — pas des
réglages que l'IHM écrit directement dans ce struct (voir §1, la vraie config vit ailleurs).

### `CODE/SUPERVISION/_TYPES/ST_JoystickCmd.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_JoystickCmd — Commandes IHM pour le Joystick
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickCmd :
STRUCT
    BtnCalibrate : BOOL; (* 🎯 Demande de recalage au neutre *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_JoystickState.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🚦 ST_JoystickState — États et diagnostics IHM du Joystick
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickState :
STRUCT
    RawX         : INT;        (* 🕹️ Axe X brut du joystick (0..10000) *)
    RawY         : INT;        (* 🕹️ Axe Y brut du joystick (0..10000) *)
    RawButton    : BOOL;       (* 🔘 Bouton homme-mort brut *)
    AxisCmdX     : ST_AxisCmd; (* ⚙️ Consigne d'axe X normalisée (sortie FB_Joystick) *)
    AxisCmdY     : ST_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée (sortie FB_Joystick) *)
    NeutralXAct  : INT;        (* 🎯 Neutre X calibré actuel (lecture seule) *)
    NeutralYAct  : INT;        (* 🎯 Neutre Y calibré actuel (lecture seule) *)
    DeadmanArmed : BOOL;       (* 🔫 Geste homme-mort armé (FB_Joystick.DeadmanArmed) *)
    Online       : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational  : BOOL;       (* 🟢 Joystick opérationnel *)
    Error        : BOOL;       (* 🔴 Joystick en défaut *)
    ErrorId      : WORD;       (* ❌ Code défaut joystick *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_JoystickHMI.st` (modifié, remplace le contenu actuel)
```
(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_JoystickHMI — Données d'échange IHM pour le Joystick
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State (2026-07-24), homogène avec ST_ModesHMI.
   Pas de Cfg (les vrais réglages de calibration vivent dans GVL_PERSISTENT, pas ici) ni de
   Bypass (concept absent de ce struct).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickHMI :
STRUCT
    Cmd   : ST_JoystickCmd;
    State : ST_JoystickState;
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif des références — vérifié par grep, ne pas en chercher d'autres

**`CODE/MAIN/PRG_00_Inputs.st:146`** :
```
GVL_IHM.JOY1Joystick.BtnCalibrate := FALSE;
→ GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate := FALSE;
```

**`CODE/MAIN/PRG_01_Diagnostics.st:105`** :
```
BtnCalibrate           := GVL_IHM.JOY1Joystick.BtnCalibrate,
→ BtnCalibrate           := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
```

**`CODE/MAIN/PRG_09_Supervision.st`** (1 commentaire + 12 lignes actives) :
```
L143 (commentaire) : ℹ️ BtnCalibrate joystick : lu directement depuis GVL_IHM.JOY1Joystick.BtnCalibrate dans PRG_01_Diagnostics (ligne 48)
  →  ℹ️ BtnCalibrate joystick : lu directement depuis GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate dans PRG_01_Diagnostics (ligne 48)

L634: GVL_IHM.JOY1Joystick.RawX       := PRG_01_Diagnostics.FB_Joystick_0.RawX;
  →   GVL_IHM.JOY1Joystick.State.RawX       := PRG_01_Diagnostics.FB_Joystick_0.RawX;
L635: GVL_IHM.JOY1Joystick.RawY       := PRG_01_Diagnostics.FB_Joystick_0.RawY;
  →   GVL_IHM.JOY1Joystick.State.RawY       := PRG_01_Diagnostics.FB_Joystick_0.RawY;
L636: GVL_IHM.JOY1Joystick.RawButton  := PRG_01_Diagnostics.FB_Joystick_0.RawButton;
  →   GVL_IHM.JOY1Joystick.State.RawButton  := PRG_01_Diagnostics.FB_Joystick_0.RawButton;
L637: GVL_IHM.JOY1Joystick.AxisCmdX        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
  →   GVL_IHM.JOY1Joystick.State.AxisCmdX        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
L638: GVL_IHM.JOY1Joystick.AxisCmdY        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
  →   GVL_IHM.JOY1Joystick.State.AxisCmdY        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
L639: GVL_IHM.JOY1Joystick.NeutralXAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralXAct;
  →   GVL_IHM.JOY1Joystick.State.NeutralXAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralXAct;
L640: GVL_IHM.JOY1Joystick.NeutralYAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralYAct;
  →   GVL_IHM.JOY1Joystick.State.NeutralYAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralYAct;
L641: GVL_IHM.JOY1Joystick.DeadmanArmed := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
  →   GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
L642: GVL_IHM.JOY1Joystick.Online     := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
  →   GVL_IHM.JOY1Joystick.State.Online     := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
L643: GVL_IHM.JOY1Joystick.Operational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
  →   GVL_IHM.JOY1Joystick.State.Operational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
L644: GVL_IHM.JOY1Joystick.Error       := PRG_01_Diagnostics.FB_Joystick_0.Error;
  →   GVL_IHM.JOY1Joystick.State.Error       := PRG_01_Diagnostics.FB_Joystick_0.Error;
L645: GVL_IHM.JOY1Joystick.ErrorId     := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;
  →   GVL_IHM.JOY1Joystick.State.ErrorId     := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;
```

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : aucune autre référence à
`GVL_IHM.JOY1Joystick` n'existe ailleurs (aucune suite `PLC_TESTS` ne le référence). Si le grep de
vérification en trouve d'autres au moment de l'exécution (le code a pu bouger depuis), les traiter
avec le même principe de mapping, ne pas improviser un nouveau pattern.

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_JoystickCmd.st` (nouveau)
2. `CODE/SUPERVISION/_TYPES/ST_JoystickState.st` (nouveau)
3. `CODE/SUPERVISION/_TYPES/ST_JoystickHMI.st` (remplacé)
4. `CODE/MAIN/PRG_00_Inputs.st`
5. `CODE/MAIN/PRG_01_Diagnostics.st`
6. `CODE/MAIN/PRG_09_Supervision.st`
7. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Pas de `Cfg` ni de `Bypass` dans `ST_JoystickHMI`** — voir §1, ce domaine n'en a pas besoin.
  Ne pas ajouter "par cohérence" avec les lots précédents : ce serait hors-scope et non justifié
  par le code réel.
- **Ne pas toucher au bug de calibration** (`BtnCalibrate` qui ne réécrit pas
  `GVL_PERSISTENT._JoystickNeutralX/Y`) — hors périmètre explicite de ce lot (voir §1), traité dans
  un lot ultérieur de persistance généralisée.
- **Ne pas toucher** `CODE/JOYSTICK/FB_Joystick.st` — cette FB n'a aucune raison de changer, seuls
  ses appelants (chemins `GVL_IHM`) sont modifiés.
- **Ne pas toucher** aux fichiers des Lots 1a/2a/2b/2c/2d (déjà committés/vérifiés).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage —
  hors périmètre strict de ce lot (rappel explicite, déjà signalé aux lots précédents).
- **PascalCase strict**, pas de hongrois.

## 8. Obligatoire avant restitution

1. `grep -rn "GVL_IHM\.JOY1Joystick\.\(RawX\|RawY\|RawButton\|AxisCmdX\|AxisCmdY\|NeutralXAct\|NeutralYAct\|DeadmanArmed\|Online\|Operational\|BtnCalibrate\|Error\|ErrorId\)\b" CODE/ --include=*.st`
   doit retourner **zéro résultat** (toutes les occurrences doivent passer par `.Cmd.` ou `.State.`).
2. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
3. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur
   (une erreur Gate 1 pré-existante sans lien avec ce lot peut déjà être présente, ne pas la
   corriger, hors périmètre).
4. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 2 nouveaux fichiers struct créés exactement comme spécifié §4.
- [ ] `ST_JoystickHMI.st` compose uniquement `Cmd`/`State` (pas de `Cfg`/`Bypass`).
- [ ] Tous les champs classés exactement comme en §4 (1 dans Cmd, 12 dans State — 13 au total,
      aucun champ oublié ni dupliqué).
- [ ] `NeutralXAct`/`NeutralYAct` bien dans `State`, pas dans un `Cfg` inventé.
- [ ] Sweep complet des 6 fichiers listés en §6.
- [ ] `grep` de vérification §8.1 = zéro résultat.
- [ ] `FB_Joystick.st` non modifié.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

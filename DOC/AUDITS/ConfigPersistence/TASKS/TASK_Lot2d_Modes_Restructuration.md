# 📋 Document de Tâche — Lot 2d : Restructuration `GVL_IHM.Modes` en `Cmd`/`State`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite des Lots 2a (`M1M2Sync`), 2b (`Bucket`), 2c (`Commun`) — tous faits et vérifiés. Ce lot
> est indépendant, ne touche à aucun fichier des lots précédents.

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
  - `DOC/AUDITS/ConfigPersistence/TASKS/TASK_Lot2a_M1M2Sync_Restructuration.md`,
    `TASK_Lot2b_Bucket_Restructuration.md` — lots précédents du même type de restructuration
    (Cmd/State/Cfg/Bypass), pour voir comment un cas similaire déjà validé a été traité.
  - `CODE/SUPERVISION/_TYPES/ST_WinchHMI.st`, `ST_SyncHMI.st`, `ST_BucketHMI.st` — exemples déjà
    en place de structs composées `Cmd`/`State`(/`Cfg`/`Bypass`), pour comparer le style exact.
  - `CODE/MODES/FB_Modes.st` — le FB métier lui-même, pour confirmer qu'il ne référence AUCUN
    chemin `GVL_IHM` en interne (seul son appelant `PRG_04_Modes.st` le fait) avant de le classer
    hors périmètre.
  - `CODE/MAIN/PRG_04_Modes.st`, `PRG_09_Supervision.st` en entier (pas seulement les extraits
    cités en §5) — si le contexte autour d'une ligne citée manque pour comprendre un usage.
  - Si aucun de ces pointeurs ne suffit à lever le doute : c'est le moment de t'arrêter et de
    signaler, pas de deviner.

## 1. Contexte

`GVL_IHM.Modes` (type `ST_ModesHMI`) est un groupe plat qui mélange **commandes opérateur** (ce
que l'IHM écrit vers le PLC : sélection de mode, boutons reset/armement, sélection joystick) et
**états calculés par le PLC** (mode courant, chaîne AU, défauts agrégés). Contrairement à
Sync/Bucket/Commun, **`Modes` n'a besoin QUE d'un split `Cmd`/`State`** :
- Pas de `Cfg` : aucun champ n'est un réglage numérique/paramètre — c'est confirmé par balayage
  exhaustif de tous les champs (§3-4 ci-dessous), aucun ne ressemble à une config persistante.
- Pas de `Bypass` : `Modes` ne porte aucun concept de bypass (les bypass vivent dans les domaines
  métier : Winch, Translation, Sync, Bucket, Commun, Network).

**Confirmé non mappé sur un écran IHM physique** (comme Sync/Bucket avant lui) — aucun risque de
casser un mapping existant.

## 2. Objectif

1. Créer 2 nouveaux types dans `CODE/SUPERVISION/_TYPES/` : `ST_ModesCmd`, `ST_ModesState`.
2. Réécrire `ST_ModesHMI` pour composer ces 2 sous-structs (pas de collision de nom cette fois :
   `Modes` n'avait pas de champ `State` préexistant, contrairement à `Bucket`/`Sync`).
3. Mettre à jour **toutes** les références (liste exhaustive §5, y compris `PLC_TESTS` et les
   commentaires qui citent le chemin en toutes lettres).
4. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_ModesHMI.st`

```
TYPE ST_ModesHMI :
STRUCT
    CurrentMode     : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    SelMode     : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    EmergencyStopOk    : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    BtnFaultReset  : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    BtnModeReset          : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)
    AnyFaultActive     : BOOL;   (* 🔴 REX 2026-07-07 : au moins un défaut/alarme actif dans le domaine
                                     sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                     BtnFaultReset a été pressé (OR de tous les .Error du domaine,
                                     même périmètre que BtnFaultReset) *)
    PowerCutOffActive  : BOOL;   (* 🧨 REX 2026-07-07 : au moins un Méca A/B/C (FB_Safety_Winch) ou
                                     PowerCutOff Translation actif — TRUE = coupure demandée. Attention :
                                     PowerCutOff_A_RQ/B_RQ (sortie physique réelle) sont à la polarité
                                     INVERSÉE (fail-safe, TRUE=maintenu/OK) — ce champ IHM reste en
                                     polarité "alarme" (TRUE=problème) pour cohérence avec AnyFaultActive *)

    // 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md §Sécurité électrique)
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)
    EmergencyChainOk   : BOOL;   (* 🔗 Boucle AU saine (coup-de-poing relâchés + pas de PowerCutOff PLC actif) *)
    PowerContactorOk   : BOOL;   (* 🔌 Contacteur de puissance confirmé engagé (miroir EmergencyStopOk) *)
    EmergencyArmable   : BOOL;   (* 🟢 Réarmement possible maintenant (chaîne saine, ni séquence ni verrouillage en cours,
                                     ni RedundancyTestFailed) *)
    EmergencyArmingBusy: BOOL;   (* ⏳ Auto-test A/B, pulse, confirmation OU verrouillage 5s en cours — nouvelle demande ignorée *)
    RedundancyTestFailed  : BOOL; (* 🔴 Canal A ou B non fonctionnel détecté à l'auto-test — bloque tout réarmement (front Reset requis) *)
    EmergencyArmingFailed : BOOL; (* 🔴 Impulsion envoyée mais contacteur puissance jamais confirmé sous 2s (front Reset + contacteur confirmé requis) *)

    // 🔧 REX 2026-07-19 : rapatrié depuis GVL_IHM.IHM_MANU (suppression IHM_MANU) — TASK-0001,
    // sélection treuil au joystick, arbitrée par FB_Modes (MAINT_N2 uniquement, forcé à 3=Couplé sinon)
    SelJoystickWinch : INT; (* 🕹️ 1=M1 seul, 2=M2 seul, 3=Couplé — voir FB_Modes.JoystickWinchSelectArbitrated *)

    // 🆕 REX (session WINCH-BTN-01) — reouverture documentee doctrine T40 (voir
    // DOC/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md). Bascule UNIQUEMENT
    // la SOURCE du signal StartStop/Direction/SpeedRefPct (joystick vs boutons IHM) —
    // SelJoystickWinch ci-dessus reste l'unique autorite de selection treuil (M1/M2/Couple),
    // appliquee IDENTIQUEMENT quelle que soit la source. Accessible des MAINT_N1 (pas de mot
    // de passe), homme-mort joystick reel toujours obligatoire meme en pilotage boutons
    // (lecon precedent AF_Partie-11 v1.9 §6bis, bug Translation deja corrige).
    TglJoystickMaster : BOOL := TRUE; (* 🕹️ TRUE (defaut) = joystick pilote Winch (comportement historique, preserve au boot) ; FALSE = boutons IHM BtnUp/BtnDown *)
END_STRUCT
END_TYPE
```

## 4. Structure cible — classement Cmd/State (fait, vérifié par balayage exhaustif de toutes les
références du projet — voir §5, chaque champ n'a qu'un seul usage cohérent)

**Cmd** (écrit par l'IHM, consommé par le PLC) : `SelMode`, `BtnFaultReset`, `BtnModeReset`,
`BtnEmergencyArming`, `BtnEmergencyCutOff`, `SelJoystickWinch`, `TglJoystickMaster`.
👉 Note : certains champs Cmd sont aussi remis à `FALSE` par le PLC lui-même après consommation
(ex. `PRG_00_Inputs.st` les purge au boot, `PRG_09_Supervision.st` les enchaîne en front) — c'est
normal pour des boutons/commandes à impulsion, ça reste `Cmd` (le PLC ne fait qu'acquitter/consommer,
il ne calcule pas ces valeurs).

**State** (calculé par le PLC, lu par l'IHM) : `CurrentMode`, `EmergencyStopOk`, `AnyFaultActive`,
`PowerCutOffActive`, `EmergencyChainOk`, `PowerContactorOk`, `EmergencyArmable`,
`EmergencyArmingBusy`, `RedundancyTestFailed`, `EmergencyArmingFailed`.

### `CODE/SUPERVISION/_TYPES/ST_ModesCmd.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_ModesCmd — Commandes IHM pour les modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesCmd :
STRUCT
    SelMode            : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    BtnFaultReset      : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    BtnModeReset       : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)

    // 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md §Sécurité électrique)
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)

    // 🔧 REX 2026-07-19 : rapatrié depuis GVL_IHM.IHM_MANU (suppression IHM_MANU) — TASK-0001,
    // sélection treuil au joystick, arbitrée par FB_Modes (MAINT_N2 uniquement, forcé à 3=Couplé sinon)
    SelJoystickWinch   : INT;    (* 🕹️ 1=M1 seul, 2=M2 seul, 3=Couplé — voir FB_Modes.JoystickWinchSelectArbitrated *)

    // 🆕 REX (session WINCH-BTN-01) — bascule UNIQUEMENT la SOURCE du signal StartStop/Direction/
    // SpeedRefPct (joystick vs boutons IHM) — SelJoystickWinch ci-dessus reste l'unique autorité de
    // sélection treuil (M1/M2/Couplé), appliquée IDENTIQUEMENT quelle que soit la source.
    TglJoystickMaster  : BOOL := TRUE; (* 🕹️ TRUE (défaut) = joystick pilote Winch (comportement historique, préservé au boot) ; FALSE = boutons IHM BtnUp/BtnDown *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_ModesState.st` (nouveau fichier)
```
(* ═══════════════════════════════════════════════════════════════
   🚦 ST_ModesState — États et diagnostics IHM des modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesState :
STRUCT
    CurrentMode           : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    EmergencyStopOk       : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    AnyFaultActive        : BOOL;   (* 🔴 REX 2026-07-07 : au moins un défaut/alarme actif dans le domaine
                                        sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                        BtnFaultReset a été pressé (OR de tous les .Error du domaine,
                                        même périmètre que BtnFaultReset) *)
    PowerCutOffActive     : BOOL;   (* 🧨 REX 2026-07-07 : au moins un Méca A/B/C (FB_Safety_Winch) ou
                                        PowerCutOff Translation actif — TRUE = coupure demandée. Attention :
                                        PowerCutOff_A_RQ/B_RQ (sortie physique réelle) sont à la polarité
                                        INVERSÉE (fail-safe, TRUE=maintenu/OK) — ce champ IHM reste en
                                        polarité "alarme" (TRUE=problème) pour cohérence avec AnyFaultActive *)
    EmergencyChainOk      : BOOL;   (* 🔗 Boucle AU saine (coup-de-poing relâchés + pas de PowerCutOff PLC actif) *)
    PowerContactorOk      : BOOL;   (* 🔌 Contacteur de puissance confirmé engagé (miroir EmergencyStopOk) *)
    EmergencyArmable      : BOOL;   (* 🟢 Réarmement possible maintenant (chaîne saine, ni séquence ni verrouillage en cours,
                                        ni RedundancyTestFailed) *)
    EmergencyArmingBusy   : BOOL;   (* ⏳ Auto-test A/B, pulse, confirmation OU verrouillage 5s en cours — nouvelle demande ignorée *)
    RedundancyTestFailed  : BOOL;   (* 🔴 Canal A ou B non fonctionnel détecté à l'auto-test — bloque tout réarmement (front Reset requis) *)
    EmergencyArmingFailed : BOOL;   (* 🔴 Impulsion envoyée mais contacteur puissance jamais confirmé sous 2s (front Reset + contacteur confirmé requis) *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_ModesHMI.st` (modifié, remplace le contenu actuel)
```
(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State (2026-07-24), homogène avec ST_WinchHMI/ST_SyncHMI/ST_BucketHMI.
   Pas de Cfg (aucun réglage numérique dans ce domaine) ni de Bypass (concept absent de Modes).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    Cmd   : ST_ModesCmd;
    State : ST_ModesState;
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif des références — vérifié par grep, ne pas en chercher d'autres

**`CODE/SUPERVISION/GVL_IHM.st`** (commentaires uniquement, dans le bloc de procédure de test) :
```
L37: GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1
  →  GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1
L39: reset unique — Modes/Cycle ont chacun le leur, voir GVL_IHM.Modes.BtnModeReset /
  →  (idem, remplacer par GVL_IHM.Modes.Cmd.BtnModeReset)
L41: GVL_IHM.Modes.BtnFaultReset := TRUE puis FALSE (front)
  →  GVL_IHM.Modes.Cmd.BtnFaultReset := TRUE puis FALSE (front)
```

**`CODE/CODEURS/FB_Encoder_Homing.st:197`** (commentaire uniquement) :
```
l'IHM, invisible sauf sur GVL_IHM.Modes.AnyFaultActive qui restait à 1 sans raison visible).
  → ... GVL_IHM.Modes.State.AnyFaultActive ...
```

**`CODE/MAIN/PRG_00_Inputs.st:119-121`** :
```
GVL_IHM.Modes.BtnFaultReset := FALSE;      → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
GVL_IHM.Modes.BtnModeReset := FALSE;       → GVL_IHM.Modes.Cmd.BtnModeReset := FALSE;
GVL_IHM.Modes.BtnEmergencyArming := FALSE; → GVL_IHM.Modes.Cmd.BtnEmergencyArming := FALSE;
```

**`CODE/MAIN/PRG_04_Modes.st`** :
```
L44: Reset := GVL_IHM.Modes.BtnModeReset,
  →  Reset := GVL_IHM.Modes.Cmd.BtnModeReset,
L52: JoystickWinchSelectRequest := GVL_IHM.Modes.SelJoystickWinch
  →  JoystickWinchSelectRequest := GVL_IHM.Modes.Cmd.SelJoystickWinch
```

**`CODE/MAIN/PRG_06_WinchControl.st`** (2 usages actifs + 2 commentaires) :
```
L157 (commentaire): GVL_IHM.Modes.TglJoystickMaster bascule vers les boutons IHM maintenus...
  →  GVL_IHM.Modes.Cmd.TglJoystickMaster bascule vers les boutons IHM maintenus...
L169: IF GVL_IHM.Modes.TglJoystickMaster THEN
  →   IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
L220 (commentaire): idem M1 ... GVL_IHM.Modes.TglJoystickMaster bascule la SOURCE...
  →  idem M1 ... GVL_IHM.Modes.Cmd.TglJoystickMaster bascule la SOURCE...
L232: IF GVL_IHM.Modes.TglJoystickMaster THEN
  →   IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
```

**`CODE/MAIN/PRG_09_Supervision.st`** (1 commentaire + 13 lignes actives) :
```
L10 (commentaire, bandeau de tête) : ... dédié (GVL_IHM.Modes.BtnModeReset côté PRG_04_Modes ...
  →  ... dédié (GVL_IHM.Modes.Cmd.BtnModeReset côté PRG_04_Modes ...

L51:  GVL_Modes_Stub.ModeRequest_IHM := GVL_IHM.Modes.SelMode;
  →   GVL_Modes_Stub.ModeRequest_IHM := GVL_IHM.Modes.Cmd.SelMode;

L71:  FaultMachineReset_IHM := GVL_IHM.Modes.BtnFaultReset
  →   FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset

L79:  GVL_IHM.Modes.AnyFaultActive :=
  →   GVL_IHM.Modes.State.AnyFaultActive :=
      (écriture PLC — reste le même bloc de calcul, seul le chemin cible change)

L107: GVL_IHM.Modes.PowerCutOffActive := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
  →   GVL_IHM.Modes.State.PowerCutOffActive := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
L110:                                  OR GVL_IHM.Modes.BtnEmergencyCutOff;
  →                                   OR GVL_IHM.Modes.Cmd.BtnEmergencyCutOff;

L129: GVL_IHM.Modes.EmergencyChainOk    := PRG_00_Inputs.EmergencyChain;
  →   GVL_IHM.Modes.State.EmergencyChainOk    := PRG_00_Inputs.EmergencyChain;
L130: GVL_IHM.Modes.PowerContactorOk    := PRG_00_Inputs.EmergencyStopOk;
  →   GVL_IHM.Modes.State.PowerContactorOk    := PRG_00_Inputs.EmergencyStopOk;
L131: GVL_IHM.Modes.EmergencyArmingBusy := (PRG_10_Outputs.ArmingSeqStep <> 0) OR PRG_10_Outputs.EmergencyArmingLockoutActive;
  →   GVL_IHM.Modes.State.EmergencyArmingBusy := (PRG_10_Outputs.ArmingSeqStep <> 0) OR PRG_10_Outputs.EmergencyArmingLockoutActive;
L132: GVL_IHM.Modes.EmergencyArmable    := PRG_00_Inputs.EmergencyChain
  →   GVL_IHM.Modes.State.EmergencyArmable    := PRG_00_Inputs.EmergencyChain
      (les 3 lignes de conditions AND qui suivent, L133-135, ne référencent pas Modes — inchangées)
L136: GVL_IHM.Modes.RedundancyTestFailed := PRG_10_Outputs.RedundancyTestFailed;
  →   GVL_IHM.Modes.State.RedundancyTestFailed := PRG_10_Outputs.RedundancyTestFailed;
L137: GVL_IHM.Modes.EmergencyArmingFailed := PRG_10_Outputs.EmergencyArmingFailed;
  →   GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_10_Outputs.EmergencyArmingFailed;

L649: GVL_IHM.Modes.CurrentMode     := PRG_04_Modes.instModes.Mode;
  →   GVL_IHM.Modes.State.CurrentMode     := PRG_04_Modes.instModes.Mode;
L650: GVL_IHM.Modes.EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk;
  →   GVL_IHM.Modes.State.EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk;
```

**`CODE/MAIN/PRG_10_Outputs.st`** :
```
L147: ArmRequest := GVL_IHM.Modes.BtnEmergencyArming,
  →   ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
L151: BtnEmergencyCutOff := GVL_IHM.Modes.BtnEmergencyCutOff
  →   BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
```

**`CODE/SIMULATION/PLC_TESTS/SUITE_ENCODER/FB_EncoderValidation.st:163,185`** :
```
GVL_IHM.Modes.SelMode := E_Mode.MAINT_N2;  →  GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N2;
(les deux occurrences, mêmes changements)
```

**`CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st`** (lignes 96, 232, 234, 242, 293,
313, 330, 348, 350, 362, 378) — toutes des écritures de stimuli `SelMode`/`BtnFaultReset`/
`BtnEmergencyArming`, toutes `Cmd` :
```
L96:  GVL_IHM.Modes.BtnFaultReset := FALSE;         → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L232: GVL_IHM.Modes.BtnEmergencyArming := TRUE;      → GVL_IHM.Modes.Cmd.BtnEmergencyArming := TRUE;
L234:     GVL_IHM.Modes.BtnEmergencyArming := FALSE; →     GVL_IHM.Modes.Cmd.BtnEmergencyArming := FALSE;
L242: GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;      → GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1;
L293: GVL_IHM.Modes.SelMode := E_Mode.MAINT_N2;      → GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N2;
L313: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;     → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L330: GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;      → GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1;
L348: GVL_IHM.Modes.BtnFaultReset := TRUE;           → GVL_IHM.Modes.Cmd.BtnFaultReset := TRUE;
L350:     GVL_IHM.Modes.BtnFaultReset := FALSE;      →     GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L362: GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;      → GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1;
L378: GVL_IHM.Modes.SelMode := E_Mode.DISABLE;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.DISABLE;
```

**`CODE/SIMULATION/PLC_TESTS/SUITE_TRANSLATION/FB_TranslationValidation.st:216`** :
```
GVL_IHM.Modes.BtnFaultReset := ResetFaults;  →  GVL_IHM.Modes.Cmd.BtnFaultReset := ResetFaults;
```

**`CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_HeartbeatValidation.st`** (lignes 104, 126, 128, 141,
382, 405, 406, 412, 422, 427, 436, 444, 450, 465, 467) :
```
L104: GVL_IHM.Modes.BtnFaultReset := FALSE;            → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L126: GVL_IHM.Modes.BtnFaultReset := FALSE;            → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L128: IF Busy THEN GVL_IHM.Modes.SelMode := StimModeRequest; END_IF;
  →   IF Busy THEN GVL_IHM.Modes.Cmd.SelMode := StimModeRequest; END_IF;
L141: StimModeRequest := GVL_IHM.Modes.SelMode;        → StimModeRequest := GVL_IHM.Modes.Cmd.SelMode;
L382: ProbeBool[SigPowerCutOffActive] := GVL_IHM.Modes.PowerCutOffActive;
  →   ProbeBool[SigPowerCutOffActive] := GVL_IHM.Modes.State.PowerCutOffActive;   ⚠️ seule lecture State de ce fichier, ne pas la classer par erreur en Cmd
L405: GVL_IHM.Modes.SelMode := StimModeRequest;        → GVL_IHM.Modes.Cmd.SelMode := StimModeRequest;
L406: GVL_IHM.Modes.BtnFaultReset := FALSE;            → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L412: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L422: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L427: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L436: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L444:     GVL_IHM.Modes.BtnFaultReset := TRUE;         →     GVL_IHM.Modes.Cmd.BtnFaultReset := TRUE;
L450: GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;       → GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
L465: GVL_IHM.Modes.BtnFaultReset := FALSE;            → GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
L467: GVL_IHM.Modes.SelMode := StimModeRequest;        → GVL_IHM.Modes.Cmd.SelMode := StimModeRequest;
```

**`CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_SafetyValidation.st:558,559`** :
```
GVL_IHM.Modes.BtnEmergencyArming := ArmRequest;   → GVL_IHM.Modes.Cmd.BtnEmergencyArming := ArmRequest;
GVL_IHM.Modes.BtnFaultReset  := ResetFaults;      → GVL_IHM.Modes.Cmd.BtnFaultReset  := ResetFaults;
```

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_ModesCmd.st` (nouveau)
2. `CODE/SUPERVISION/_TYPES/ST_ModesState.st` (nouveau)
3. `CODE/SUPERVISION/_TYPES/ST_ModesHMI.st` (remplacé)
4. `CODE/SUPERVISION/GVL_IHM.st` (commentaires uniquement)
5. `CODE/CODEURS/FB_Encoder_Homing.st` (commentaire uniquement)
6. `CODE/MAIN/PRG_00_Inputs.st`
7. `CODE/MAIN/PRG_04_Modes.st`
8. `CODE/MAIN/PRG_06_WinchControl.st`
9. `CODE/MAIN/PRG_09_Supervision.st`
10. `CODE/MAIN/PRG_10_Outputs.st`
11. `CODE/SIMULATION/PLC_TESTS/SUITE_ENCODER/FB_EncoderValidation.st`
12. `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st`
13. `CODE/SIMULATION/PLC_TESTS/SUITE_TRANSLATION/FB_TranslationValidation.st`
14. `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_HeartbeatValidation.st`
15. `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_SafetyValidation.st`
16. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Pas de `Cfg` ni de `Bypass` dans `ST_ModesHMI`** — ce domaine n'en a pas besoin (voir §1). Ne
  pas en ajouter "par cohérence" avec les lots précédents : ce serait hors-scope et non justifié
  par le code réel.
- **Ne pas toucher** `FB_Modes.st` (logique interne du FB, aucune référence `GVL_IHM` à l'intérieur
  — vérifié, seul son APPELANT `PRG_04_Modes.st` référence `GVL_IHM.Modes`).
- **Ne pas toucher** aux fichiers des Lots 1a/2a/2b/2c (déjà committés/vérifiés).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage —
  hors périmètre strict de ce lot (rappel explicite, déjà signalé aux lots précédents).
- **PascalCase strict**, pas de hongrois.
- Ce lot ne touche à aucun mécanisme de persistance (`GVL_PERSISTENT`, `Initialized`) — `Modes`
  n'a pas de `Cfg`/`Bypass`, donc rien à protéger ici. Ne pas inventer un flag `Initialized`.

## 8. Obligatoire avant restitution

1. `grep -rn "GVL_IHM\.Modes\.\(SelMode\|BtnFaultReset\|BtnModeReset\|BtnEmergencyArming\|BtnEmergencyCutOff\|SelJoystickWinch\|TglJoystickMaster\|CurrentMode\|EmergencyStopOk\|AnyFaultActive\|PowerCutOffActive\|EmergencyChainOk\|PowerContactorOk\|EmergencyArmable\|EmergencyArmingBusy\|RedundancyTestFailed\|EmergencyArmingFailed\)\b" CODE/ --include=*.st`
   doit retourner **zéro résultat** (toutes les occurrences doivent passer par `.Cmd.` ou `.State.`).
2. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
3. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
4. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] 2 nouveaux fichiers struct créés exactement comme spécifié §4.
- [ ] `ST_ModesHMI.st` compose uniquement `Cmd`/`State` (pas de `Cfg`/`Bypass`).
- [ ] Tous les champs classés exactement comme en §4 (7 dans Cmd, 10 dans State — 17 au total,
      aucun champ oublié ni dupliqué).
- [ ] Sweep complet des 16 fichiers listés en §6, y compris les commentaires qui citent le chemin.
- [ ] `grep` de vérification §8.1 = zéro résultat.
- [ ] `FB_Modes.st` non modifié.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

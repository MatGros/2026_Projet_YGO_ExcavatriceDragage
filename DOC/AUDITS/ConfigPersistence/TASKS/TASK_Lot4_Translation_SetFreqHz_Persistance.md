# 📋 Document de Tâche — Lot 4 : Persistance de `TranslationM3.Cmd.SetFreq_Hz`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Indépendant du Lot 3 (persistance générique, terminé — commits `8e1aac6`…`9d2d12f`). Ce lot
> traite le dernier champ de config non protégé identifié par l'audit initial.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §6** — en particulier, **ne persiste QUE `SetFreq_Hz`**,
  jamais les autres champs de `ST_TranslationCmd` (voir §1, c'est une contrainte de sécurité, pas
  une préférence de style).
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté.** Pointeurs utiles :
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier** — pour voir le style des blocs de
    restauration/sauvegarde À PLAT (avant l'introduction du pont générique), par exemple le bloc
    `Commun.Cfg` ou n'importe quel bloc antérieur au Lot 3 — c'est CE style qu'il faut reproduire
    ici, pas le pont générique `FB_CfgPersistBridge_*` (voir §1 pour pourquoi).
  - Si aucun de ces pointeurs ne suffit à lever le doute : arrête-toi et signale.

## 1. Contexte

`GVL_IHM.TranslationM3.Cmd.SetFreq_Hz` (consigne fréquence manuelle en Hz, réglée par
l'opérateur) n'a **aucun backing `GVL_PERSISTENT`** aujourd'hui — juste un défaut compilé implicite
(`REAL` nu, donc `0.0`). Comme tous les autres champs Cfg déjà traités dans ce chantier, un
changement de layout de `ST_TranslationCmd` (RETAIN invalidé) ferait perdre silencieusement le
réglage opérateur.

### ⚠️ Pourquoi PAS le pont générique `FB_CfgPersistBridge_<Type>` ici

`ST_TranslationCmd` n'est **pas** un struct `Cfg` pur — il mélange `SetFreq_Hz` (réglage à
protéger) avec des **boutons/commandes momentanées** (`BtnFwd`, `BtnRev`) et des sélecteurs de mode
(`SelPositioning`, `SelTarget`, `TglJoystickMaster`, `InvertDirection`). Le pont générique fait une
copie de struct COMPLÈTE (`Persist := Hmi`) — l'appliquer ici persisterait aussi `BtnFwd`/`BtnRev`
dans `GVL_PERSISTENT`, ce qui est dangereux : un bouton momentané qui survivrait à un redémarrage à
`TRUE` pourrait redémarrer un mouvement automatiquement au boot. **Interdit.**

La bonne approche (déjà actée avant ce chantier, voir `PLAN_TASK_v1.0.md`) : protéger **uniquement**
`SetFreq_Hz` avec le pattern manuel à plat (restauration + sauvegarde ciblées un seul champ),
exactement comme c'était fait pour tous les autres champs Cfg **avant** l'introduction du pont
générique au Lot 3 — pas de nouveau sous-struct `Cfg`, pas de pont, juste le champ protégé
directement dans `ST_TranslationCmd`.

### 🔍 Consommateur direct — pas de migration nécessaire

`CODE/MAIN/PRG_07_TranslationControl.st:98` lit `GVL_IHM.TranslationM3.Cmd.SetFreq_Hz`
**directement depuis `GVL_IHM`** (pas depuis une variable `GVL_PERSISTENT`). Bien que PRG_07
(position 7) s'exécute avant PRG_09 (position 9), ceci est **volontairement laissé tel quel** —
`GVL_IHM` est `RETAIN`, donc la valeur réelle survit déjà à un simple redémarrage à chaud ; le seul
cas où PRG_07 lirait un défaut pendant 1 scan est juste après un changement de layout RETAIN
(rarissime), exactement le même compromis déjà accepté pour `Cycle.Cfg.SetDepth_M` dans
`PRG_05_Cycle.st` et `Bucket.Cfg.CfgTimeoutDuration` dans `PRG_06_WinchControl.st` aux lots
précédents. **Ne pas migrer cette ligne**, hors périmètre de ce lot.

## 2. Objectif

1. `CODE/SUPERVISION/_TYPES/ST_TranslationCmd.st` : ajouter `Initialized : BOOL := FALSE;`.
2. `CODE/GVL_PERSISTENT.st` : ajouter `_TranslationSetFreq_Hz : REAL := 0.0;` (section
   `↔️ TRANSLATION (M3)`, même défaut que le champ actuel).
3. `CODE/MAIN/PRG_09_Supervision.st` : ajouter un bloc de restauration (section 2) + un bloc de
   sauvegarde (section 3) ciblant **uniquement** `SetFreq_Hz`, style manuel (pas de pont générique).
4. Régénérer le bundle, vérifier les gates (y compris le nouveau gate
   `check_config_persistence.py` — voir note §7).

## 3. État actuel exact de `ST_TranslationCmd.st`

```
TYPE ST_TranslationCmd :
STRUCT
    SelPositioning     : BOOL;
    SelTarget          : INT;
    BtnFwd             : BOOL;
    BtnRev             : BOOL;
    SetFreq_Hz         : REAL;
    TglJoystickMaster  : BOOL;
    InvertDirection    : BOOL;
END_STRUCT
END_TYPE
```

## 4. Structure cible

```
(* ═══════════════════════════════════════════════════════════════
   🎮 ST_TranslationCmd — Commandes IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au pilotage de la translation M3 depuis l'IHM.
   📄 2026-07-24 : Initialized ajouté pour protéger SetFreq_Hz (seul champ de ce struct qui est
   un réglage à faire survivre à un reboot, pas une commande momentanée) — voir
   PRG_09_Supervision.st §2/§3. Volontairement pas de pont FB_CfgPersistBridge_* générique ici :
   ça persisterait aussi BtnFwd/BtnRev (dangereux, voir DOC/AUDITS/ConfigPersistence/TASKS/
   TASK_Lot4_Translation_SetFreqHz_Persistance.md §1).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCmd :
STRUCT
    SelPositioning     : BOOL;    (* 🎯 TRUE = positionneur sur SelTarget ; FALSE = jog libre *)
    SelTarget          : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    BtnFwd             : BOOL;    (* ↔️ Requête marche avant (→ Trémie), pilotage IHM exclusif *)
    BtnRev             : BOOL;    (* ↔️ Requête marche arrière (→ Maintenance), pilotage IHM exclusif *)
    SetFreq_Hz         : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], limitée par PRG_10_Outputs *)
    TglJoystickMaster  : BOOL;    (* 🕹️ TRUE = joystick, FALSE = boutons BtnFwd/BtnRev *)
    InvertDirection    : BOOL;    (* 🔄 TRUE = inverse Fwd→Maintenance / Rev→Trémie (mise en service) *)
    Initialized        : BOOL := FALSE; (* 🚦 TRUE = SetFreq_Hz restauré depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif

### 5.1 — `CODE/GVL_PERSISTENT.st`

État actuel (section `↔️ TRANSLATION (M3)`) :
```
    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz        : REAL := 60.0; // Fréquence max absolue M3 (Hz) — source unique
    _TranslationRampAccelRate_Pct   : REAL := 20.0;  // Accélération translation (%/s)
    _TranslationRampDecelNormal_Pct : REAL := 40.0;  // Décélération normale (%/s)
    _TranslationRampDecelFast_Pct   : REAL := 100.0; // Décélération rapide SafeStop (%/s)
    _TranslationAutoSpeedCap_Pct    : REAL := 40.0;  // Plafond vitesse SEMI_AUTO (%)
```
→ ajouter une ligne (ne pas modifier les 5 existantes) :
```
    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz        : REAL := 60.0; // Fréquence max absolue M3 (Hz) — source unique
    _TranslationRampAccelRate_Pct   : REAL := 20.0;  // Accélération translation (%/s)
    _TranslationRampDecelNormal_Pct : REAL := 40.0;  // Décélération normale (%/s)
    _TranslationRampDecelFast_Pct   : REAL := 100.0; // Décélération rapide SafeStop (%/s)
    _TranslationAutoSpeedCap_Pct    : REAL := 40.0;  // Plafond vitesse SEMI_AUTO (%)
    _TranslationSetFreq_Hz         : REAL := 0.0;    // 🚦 Consigne fréquence manuelle opérateur (Hz) — protégée depuis Lot 4
```

### 5.2 — `CODE/MAIN/PRG_09_Supervision.st` — bloc de restauration (section "── 2. INITIALISATION...")

Ajouter, à la suite du dernier bloc de restauration existant (ex. juste après le bloc
`Commun.Cfg` ou `Cycle.Cfg`, peu importe l'ordre exact — repère-toi au contenu de la section) :
```
IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```

### 5.3 — `CODE/MAIN/PRG_09_Supervision.st` — bloc de sauvegarde (section "── 3. PROPAGATION...")

Ajouter, à la suite des autres blocs de sauvegarde de cette section :
```
IF GVL_IHM.TranslationM3.Cmd.Initialized THEN
    _TranslationSetFreq_Hz := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;
END_IF;
```

⚠️ **Ne PAS** utiliser `FB_CfgPersistBridge_<Type>` ici, **ne PAS** créer de nouveau type
`ST_TranslationCfg`, **ne PAS** toucher `BtnFwd`/`BtnRev`/`SelPositioning`/`SelTarget`/
`TglJoystickMaster`/`InvertDirection` (voir §1).

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : aucun autre fichier ne référence
`_TranslationSetFreq_Hz` (nouvelle variable) — `PRG_07_TranslationControl.st` continue de lire
`GVL_IHM.TranslationM3.Cmd.SetFreq_Hz` directement, volontairement non modifié (voir §1).

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_TranslationCmd.st`
2. `CODE/GVL_PERSISTENT.st`
3. `CODE/MAIN/PRG_09_Supervision.st`
4. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas toucher** `CODE/MAIN/PRG_07_TranslationControl.st` (voir §1, lecture directe
  volontairement conservée).
- **Ne pas créer** de FB pont ni de nouveau type `ST_TranslationCfg` — protection à plat
  uniquement (voir §1).
- **Ne pas toucher** aux fichiers du Lot 3 (`FB_CfgPersistBridge_*`, leurs instances dans
  `PRG_09_Supervision.st`).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage.
- **PascalCase strict**, pas de hongrois.
- Note sur le nouveau gate `check_config_persistence.py` (Lot 3c) : il ne scanne que les fichiers
  `ST_*Cfg.st` — `ST_TranslationCmd.st` n'est PAS dans son périmètre (nom différent, volontaire,
  voir §1), donc ce lot ne doit déclencher aucune de ses 4 règles. S'il en déclenche une, c'est
  que quelque chose a été mal nommé — signale-le.

## 8. Obligatoire avant restitution

1. `grep -rn "_TranslationSetFreq_Hz" CODE/` doit montrer la variable déclarée dans
   `GVL_PERSISTENT.st` ET utilisée aux 2 endroits attendus dans `PRG_09_Supervision.st`.
2. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
3. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
4. `python TOOLS/AGENT_WORKFLOW/scripts/check_config_persistence.py .` — doit rester `PASS` (ce
   lot ne doit déclencher aucune de ses 4 règles, voir §7).
5. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] `ST_TranslationCmd.st` : `Initialized : BOOL := FALSE;` ajouté, aucun autre champ modifié.
- [ ] `GVL_PERSISTENT.st` : `_TranslationSetFreq_Hz` ajoutée, même défaut (`0.0`) que le champ.
- [ ] `PRG_09_Supervision.st` : bloc de restauration + bloc de sauvegarde ciblant **uniquement**
      `SetFreq_Hz`, style manuel à plat (pas de pont générique).
- [ ] `PRG_07_TranslationControl.st` non modifié.
- [ ] `BtnFwd`/`BtnRev`/`SelPositioning`/`SelTarget`/`TglJoystickMaster`/`InvertDirection` jamais
      référencés dans `GVL_PERSISTENT.st`.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates + `check_config_persistence.py` sans nouvelle erreur.

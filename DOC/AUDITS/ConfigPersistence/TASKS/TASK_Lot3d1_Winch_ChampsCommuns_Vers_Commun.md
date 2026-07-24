# 📋 Document de Tâche — Lot 3d-1 : Déplacer les 4 champs Winch communs M1/M2 vers `Commun.Cfg`
## ⚠️ Ce lot touche un chemin IHM probablement câblé sur l'écran physique réel

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 3b (généralisation `FB_CfgPersistBridge` à Cycle/Commun/Bucket, fait et vérifié,
> commit `8f90d89`) et du correctif générateur (`e893c05`). Ce lot prépare le terrain pour
> `FB_CfgPersistBridge_WinchCfg` (lot suivant, 3d-2) en résolvant d'abord la particularité Winch :
> 4 champs partagés entre M1 et M2, incompatibles avec le pont générique simple.

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande. Ce lot touche des paramètres qui pilotent
  directement la vitesse et le palier des treuils (`CfgMaxStepDescente`/`CfgMaxStepAscent`) et la
  zone de ralentissement en fin de course (`CfgSlowdownDistance_M`/`CfgSlowSpeed_Pct`) — sois
  particulièrement attentif à la logique de sécurité/mouvement, même si ce lot ne fait que déplacer
  des données (pas de nouvelle logique de sécurité).
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **⚠️ CE LOT CHANGE UN CHEMIN IHM RÉELLEMENT MAPPÉ** — contrairement à presque tous les lots
  précédents de ce chantier (Sync/Bucket/Commun/Modes/Joystick/Cycle, tous confirmés "non mappés
  sur écran IHM physique"), `M1TreuilRetenue.Cfg`/`M2TreuilBenne.Cfg` sont le domaine du bug
  **originel** qui a déclenché tout ce chantier (`CfgMaxStepDescente` revenant au défaut usine,
  2026-07-23) — l'utilisateur exploite déjà cette machine avec un pupitre réel branché dessus.
  **Ne pas supposer que ce chemin n'est pas mappé.** Le document de migration
  `DOC/AUDITS/ConfigPersistence/IHM_VARIABLES_MIGRATION.md` doit être mis à jour avec ce changement
  précis (voir §6) pour que l'utilisateur puisse reparamétrer son pupitre.
- **Ne touche QUE les fichiers listés en §6** — toute modification hors périmètre doit être
  signalée séparément, jamais appliquée silencieusement en plus de ce qui est demandé.
  **Ce lot NE crée PAS de `FB_CfgPersistBridge_WinchCfg`** — ce sera un lot séparé (3d-2), une fois
  que `ST_WinchCfg` sera réduit aux 7 champs vraiment indépendants par instance.
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté.** Pointeurs utiles :
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier** — les blocs à supprimer/modifier sont répartis
    entre la section "── 2. INITIALISATION..." (restauration) et "── 3. PROPAGATION..." (sauvegarde
    + réconciliation M1/M2), pas côte à côte.
  - `CODE/SUPERVISION/_TYPES/ST_CommunCfg.st`, `CODE/COMMUN/FB_CfgPersistBridge_CommunCfg.st` — le
    pont Commun existe déjà (Lot 3b) et fonctionne sur TOUT le struct `ST_CommunCfg` — ajouter des
    champs à ce type suffit, **aucun nouveau code de pont n'est nécessaire** pour eux (voir §1).
  - Si aucun de ces pointeurs ne suffit à lever le doute : arrête-toi et signale.

## 1. Contexte

`ST_WinchCfg` (utilisé par `M1TreuilRetenue.Cfg` ET `M2TreuilBenne.Cfg`) a 11 champs, dont **4 sont
volontairement partagés entre M1 et M2** (décision explicite, REX 2026-07-08, demande utilisateur —
pas un oubli) : `CfgMaxStepDescente`, `CfgMaxStepAscent`, `CfgSlowdownDistance_M`,
`CfgSlowSpeed_Pct`. Aujourd'hui, une SEULE variable `GVL_PERSISTENT` par champ (ex.
`_WinchMaxStepDescent`) sert de source de vérité, avec une logique de réconciliation
"dernier qui écrit gagne, puis remiroir sur M1 ET M2" dans `PRG_09_Supervision.st`. Cette
particularité est **incompatible** avec le pont générique `FB_CfgPersistBridge_<Type>` (1
instance = 1 struct persistant du même type) déjà utilisé pour Sync/Cycle/Commun/Bucket.

**Décision utilisateur (2026-07-24)** : plutôt que de garder cette réconciliation ad-hoc, déplacer
ces 4 champs vers `GVL_IHM.Commun.Cfg` (type `ST_CommunCfg`) — cohérent avec la raison d'être de
`Commun` ("signaux qui ne concernent pas un axe en particulier"). Une fois là-bas, **il n'y a plus
qu'UNE SEULE instance** de ces 4 valeurs (pas 2 à réconcilier) — le problème de fond disparaît,
pas seulement son symptôme.

### 🎁 Effet de bord : le pont Commun existe déjà, ce lot n'a PAS besoin d'en créer un

`ST_CommunCfg`/`GVL_IHM.Commun.Cfg` sont déjà protégés par `FB_CfgPersistBridge_CommunCfg` et son
instance `instCfgPersistBridgeCommun` (Lot 3b, déjà en place et vérifié) — ce pont copie **tout le
struct** `ST_CommunCfg` d'un coup. Ajouter 4 nouveaux champs à `ST_CommunCfg` suffit à ce qu'ils
soient automatiquement restaurés/sauvegardés par ce pont existant, **sans toucher au pont
lui-même ni à son appel**. Ce lot se limite donc à : déplacer les champs (types), migrer leur
backing `GVL_PERSISTENT` (fusionné dans `_CommunCfgPersist`, qui existe déjà), et migrer leurs
2 blocs de code obsolètes (restauration + réconciliation) dans `PRG_09_Supervision.st`.

### 📛 Nommage des champs déplacés

Dans `ST_CommunCfg`, les autres champs n'ont pas de préfixe `Cfg` (ex. `LimitLegalEnabled`, pas
`CfgLimitLegalEnabled`) — mais comme ce sont des réglages **spécifiques aux treuils** qui vivent
maintenant dans un struct **partagé toute la machine**, ils gardent un préfixe `Winch` pour rester
identifiables (cohérent avec le nom des variables `GVL_PERSISTENT` déjà existantes,
`_WinchMaxStepDescent` etc.) :
- `CfgMaxStepDescente` (Winch) → `WinchMaxStepDescente` (Commun)
- `CfgMaxStepAscent` (Winch) → `WinchMaxStepAscent` (Commun)
- `CfgSlowdownDistance_M` (Winch) → `WinchSlowdownDistance_M` (Commun)
- `CfgSlowSpeed_Pct` (Winch) → `WinchSlowSpeed_Pct` (Commun)

## 2. Objectif

1. Retirer les 4 champs de `ST_WinchCfg` (11 champs → 7 champs + `Initialized`).
2. Ajouter les 4 champs (renommés, voir §1) à `ST_CommunCfg`.
3. `GVL_PERSISTENT.st` : retirer les 4 variables plates (`_WinchMaxStepDescent`,
   `_WinchMaxStepAscent`, `_WinchSlowdownDistance_M`, `_WinchSlowSpeed_Pct`), étendre
   l'initialiseur de `_CommunCfgPersist` (déjà `ST_CommunCfg`, Lot 3b) avec les 4 nouvelles valeurs.
4. `PRG_09_Supervision.st` : retirer les 2 lignes concernées de chaque bloc de restauration
   M1/M2 (§5.2), et supprimer ENTIÈREMENT les 2 blocs de réconciliation dédiés (§5.3) — plus
   besoin, un seul endroit désormais.
5. `PRG_06_WinchControl.st` : migrer les 4 lectures directes (tâche position 6, avant restauration
   position 9 — même raison structurelle que Sync/Commun/Bucket aux lots précédents) vers
   `_CommunCfgPersist.WinchXxx`.
6. Mettre à jour `DOC/AUDITS/ConfigPersistence/IHM_VARIABLES_MIGRATION.md` avec ce changement de
   chemin — **section prioritaire**, ce chemin est probablement câblé sur un pupitre réel (voir §0).
7. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact

### `CODE/SUPERVISION/_TYPES/ST_WinchCfg.st`
```
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;
    CfgHomingTarget_M       : REAL := 0.0;
    CfgMaxStepDescente      : INT := 3;
    CfgMaxStepAscent        : INT := 5;
    CfgRampAccelRate        : REAL := 50.0;
    CfgRampDecelNormalRate  : REAL := 150.0;
    CfgRampDecelFastRate    : REAL := 400.0;
    CfgCableLimitDescent_M  : REAL := -20.0;
    CfgCableLimitAscent_M   : REAL := 8.0;
    CfgSlowdownDistance_M   : REAL := 1.0;
    CfgSlowSpeed_Pct         : REAL := 15.0;
    Initialized              : BOOL := FALSE;
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_CommunCfg.st`
```
TYPE ST_CommunCfg :
STRUCT
    LimitLegalDepthMinAllowed_M : REAL;
    LimitLegalEnabled           : BOOL;
    SelHomingApproachEnable     : BOOL;
    Initialized                 : BOOL := FALSE;
END_STRUCT
END_TYPE
```

## 4. Structure cible

### `CODE/SUPERVISION/_TYPES/ST_WinchCfg.st` (modifié — retrait de 4 champs)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_WinchCfg — Configurations et paramètres réglables pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au paramétrage et calibration depuis l'IHM (RETAIN).
   📄 2026-07-24 : CfgMaxStepDescente/CfgMaxStepAscent/CfgSlowdownDistance_M/CfgSlowSpeed_Pct
   déplacés vers GVL_IHM.Commun.Cfg (WinchMaxStepDescente/etc.) — étaient partagés M1/M2 via
   réconciliation ad-hoc, une seule instance dans Commun élimine le besoin de réconciliation.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;      (* 📐 Position cible du capteur haut (m) *)
    CfgHomingTarget_M       : REAL := 0.0;      (* 🔧 Cible libre Homing unitaire MAINT_N2 [-99..+99 m] *)
    CfgRampAccelRate        : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    CfgRampDecelNormalRate  : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    CfgRampDecelFastRate    : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CfgCableLimitDescent_M  : REAL := -20.0;    (* 📐 Limite basse physique de descente (m, négatif) *)
    CfgCableLimitAscent_M   : REAL := 8.0;      (* 📐 Limite haute d'exploitation NORMALE (m) *)

    (* 🐛 FIX 2026-07-23 : flag restauration boot (défaut FALSE non ambigu, contrairement à un champ
       métier dont le défaut peut valoir n'importe quoi) — PRG_09_Supervision.st §2/§3 *)
    Initialized              : BOOL := FALSE;    (* 🚦 TRUE = config restaurée depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE
```

### `CODE/SUPERVISION/_TYPES/ST_CommunCfg.st` (modifié — ajout de 4 champs)
```
(* ═══════════════════════════════════════════════════════════════
   🔧 ST_CommunCfg — Configuration des paramètres communs machine
   📄 2026-07-24 : WinchMaxStepDescente/WinchMaxStepAscent/WinchSlowdownDistance_M/
   WinchSlowSpeed_Pct rapatriés depuis ST_WinchCfg (étaient partagés M1/M2 par réconciliation
   ad-hoc dans PRG_09_Supervision.st, une seule instance ici l'élimine).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunCfg :
STRUCT
    LimitLegalDepthMinAllowed_M : REAL; (* 📐 Cote min de dragage autorisée (m, négatif) *)
    LimitLegalEnabled           : BOOL; (* 🟢 Activation de la limite légale *)
    SelHomingApproachEnable     : BOOL; (* 🔌 Case IHM : autorise le dépassement butée haute pour homing (si MAINT_N2) *)
    WinchMaxStepDescente        : INT := 3;    (* 🛑 Limitation palier vitesse en descente (1..5), commun M1/M2 *)
    WinchMaxStepAscent          : INT := 5;    (* 🚀 Limitation palier vitesse en montée (1..5), commun M1/M2 *)
    WinchSlowdownDistance_M     : REAL := 1.0; (* 📏 Distance avant limite pour enclencher le ralentissement (m), commun M1/M2 *)
    WinchSlowSpeed_Pct          : REAL := 15.0; (* 📉 Vitesse de consigne lente dans la zone de ralentissement (%), commun M1/M2 *)
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
```

## 5. Sweep exhaustif — vérifié par grep, ne pas en chercher d'autres

### 5.1 — `CODE/GVL_PERSISTENT.st`

État actuel (section `🏗️ TREUILS`, lignes ~28-29) :
```
    _WinchMaxStepDescent : INT := 3; // Palier max descente commun M1/M2
    _WinchMaxStepAscent  : INT := 5; // Palier max montée commun M1/M2
```
→ **supprimer ces 2 lignes entièrement**.

État actuel (section `🏗️ TREUILS`, lignes ~49-50) :
```
    _WinchSlowdownDistance_M     : REAL := 1.0;   // Distance ralentissement commune (m)
    _WinchSlowSpeed_Pct           : REAL := 15.0;  // Vitesse lente zone ralentissement (%)
```
→ **supprimer ces 2 lignes entièrement**.

État actuel (section `📏 RÉGLEMENTATION / LÉGAL`, mise à jour au Lot 3b) :
```
    _CommunCfgPersist : ST_CommunCfg := (LimitLegalDepthMinAllowed_M := -15.0, LimitLegalEnabled := TRUE, SelHomingApproachEnable := FALSE); // 🌉 Pont FB_CfgPersistBridge_CommunCfg
```
→ remplacer par (mêmes valeurs par défaut que celles retirées ci-dessus — `3`/`5`/`1.0`/`15.0`) :
```
    _CommunCfgPersist : ST_CommunCfg := (
        LimitLegalDepthMinAllowed_M := -15.0,
        LimitLegalEnabled := TRUE,
        SelHomingApproachEnable := FALSE,
        WinchMaxStepDescente := 3,
        WinchMaxStepAscent := 5,
        WinchSlowdownDistance_M := 1.0,
        WinchSlowSpeed_Pct := 15.0
    ); // 🌉 Pont FB_CfgPersistBridge_CommunCfg (+ champs Winch communs M1/M2 rapatriés 2026-07-24)
```

### 5.2 — `CODE/MAIN/PRG_09_Supervision.st` — retirer 2 lignes de chaque bloc de restauration

Bloc M1 actuel :
```
IF NOT GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M  := _HomingTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M       := _HomingUnitaryTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente     := _WinchMaxStepDescent; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent       := _WinchMaxStepAscent;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate       := _WinchM1RampAccelRate_Pct;
    ...
```
→ **retirer uniquement les 2 lignes `CfgMaxStepDescente`/`CfgMaxStepAscent`** (garder tout le reste
tel quel, y compris `CfgTopSensorPos_M`/`CfgHomingTarget_M`/les rampes/les limites câble) :
```
IF NOT GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
    GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M  := _HomingTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M       := _HomingUnitaryTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate       := _WinchM1RampAccelRate_Pct;
    ...
```
Puis, plus bas dans le MÊME bloc, **retirer aussi les 2 lignes `CfgSlowdownDistance_M`/`CfgSlowSpeed_Pct`** :
```
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M  := _CableLimitM1Descent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M   := _CableLimitM1Ascent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M   := _WinchSlowdownDistance_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct        := _WinchSlowSpeed_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.Initialized := TRUE;
```
→ devient :
```
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M  := _CableLimitM1Descent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M   := _CableLimitM1Ascent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.Initialized := TRUE;
```
**Répéter EXACTEMENT le même retrait (4 lignes au total) dans le bloc `M2TreuilBenne.Cfg` juste en
dessous** (mêmes noms de champs, `M1TreuilRetenue`→`M2TreuilBenne`, `_WinchM1...`→ pas de variable
M1/M2 séparée ici puisque ces 4 champs étaient déjà communs — les lignes M2 utilisent les MÊMES
`_WinchMaxStepDescent`/`_WinchMaxStepAscent`/`_WinchSlowdownDistance_M`/`_WinchSlowSpeed_Pct` que M1).

⚠️ Ne toucher AUCUNE autre ligne de ces 2 blocs (`CfgTopSensorPos_M`, `CfgHomingTarget_M`, les 3
rampes, les 2 limites câble, `Initialized`, l'alarme `ConfigRestoredFromPersistent` juste après le
`END_IF` — tout ça reste inchangé).

### 5.3 — `CODE/MAIN/PRG_09_Supervision.st` — supprimer 2 blocs de réconciliation entiers

**Bloc 1 (MaxStepDescente/MaxStepAscent)** — supprimer ENTIÈREMENT, y compris les 2 commentaires
REX qui l'annoncent :
```
// 🔧 REX 2026-07-08 : CfgMaxStepDescente désormais commun M1/M2 — voir bloc miroir bidirectionnel
// ci-dessous (même pattern que CableLimitDescent_M/SlowdownDistance_M/SlowSpeed_Pct), plus de
// propagation à sens unique séparée par treuil ici.
```
(ce commentaire précède les blocs rampes — **ne retirer que la partie qui annonce le bloc
MaxStepDescente/Ascent qui suit**, garder le contexte utile pour les rampes si le commentaire est
partagé ; si en le lisant tu juges qu'il faut le réécrire plutôt que le couper à moitié, fais-le et
signale-le)

```
// 🔧 REX 2026-07-08 (demande utilisateur) : CfgMaxStepDescente commun M1/M2 — même profil de
// déplacement des 2 treuils, même pattern miroir que CableLimitDescent_M ci-dessous.
IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente <> _WinchMaxStepDescent THEN
        _WinchMaxStepDescent := GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente;
    ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente <> _WinchMaxStepDescent THEN
        _WinchMaxStepDescent := GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente := _WinchMaxStepDescent;
    GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente := _WinchMaxStepDescent;

    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent <> _WinchMaxStepAscent THEN
        _WinchMaxStepAscent := GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent;
    ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepAscent <> _WinchMaxStepAscent THEN
        _WinchMaxStepAscent := GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepAscent;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent := _WinchMaxStepAscent;
    GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepAscent := _WinchMaxStepAscent;
END_IF;
```
→ **supprimer ce bloc IF entier (18 lignes + son commentaire d'intro)**.

**Bloc 2 (SlowdownDistance_M/SlowSpeed_Pct)**, plus bas dans le même fichier, après les 2 blocs
`CableLimitAscent_M` (ne pas les toucher) :
```
IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized AND GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M <> _WinchSlowdownDistance_M THEN
        _WinchSlowdownDistance_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M;
    ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M <> _WinchSlowdownDistance_M THEN
        _WinchSlowdownDistance_M := GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M := _WinchSlowdownDistance_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M := _WinchSlowdownDistance_M;

    IF GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct <> _WinchSlowSpeed_Pct THEN
        _WinchSlowSpeed_Pct := GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct;
    ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct <> _WinchSlowSpeed_Pct THEN
        _WinchSlowSpeed_Pct := GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct := _WinchSlowSpeed_Pct;
    GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct := _WinchSlowSpeed_Pct;
END_IF;
```
→ **supprimer ce bloc IF entier (14 lignes)**.

⚠️ **Aucun nouveau code de restauration/sauvegarde à ajouter pour ces 4 champs** — ils sont
maintenant dans `ST_CommunCfg`, déjà entièrement couvert par l'appel existant
`instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);` (Lot 3b,
inchangé, ne pas y toucher).

### 5.4 — `CODE/MAIN/PRG_06_WinchControl.st` — 4 consommateurs directs à migrer

```
L136: EffectiveMaxStepAscent   := _WinchMaxStepAscent;
  →   EffectiveMaxStepAscent   := _CommunCfgPersist.WinchMaxStepAscent;
L137: EffectiveMaxStepDescente := _WinchMaxStepDescent;
  →   EffectiveMaxStepDescente := _CommunCfgPersist.WinchMaxStepDescente;

L490: CfgSlowdownDistanceM       := _WinchSlowdownDistance_M,
  →   CfgSlowdownDistanceM       := _CommunCfgPersist.WinchSlowdownDistance_M,
L491: CfgSlowSpeedPct            := _WinchSlowSpeed_Pct,
  →   CfgSlowSpeedPct            := _CommunCfgPersist.WinchSlowSpeed_Pct,

L532: CfgSlowdownDistanceM       := _WinchSlowdownDistance_M,
  →   CfgSlowdownDistanceM       := _CommunCfgPersist.WinchSlowdownDistance_M,
L533: CfgSlowSpeedPct            := _WinchSlowSpeed_Pct,
  →   CfgSlowSpeedPct            := _CommunCfgPersist.WinchSlowSpeed_Pct,
```
(L490-491 = appel `instWinchM1`, L532-533 = appel `instWinchM2` — mêmes 2 lignes dans les 2 blocs)

⚠️ **Ne PAS toucher** `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st:442` — cette
ligne appelle `FB_Winch` directement avec des valeurs de test en dur
(`CfgMaxStepDescente := 3, MaxStepAscent := 5, ...`), ce sont les noms des `VAR_INPUT` **de
`FB_Winch` lui-même** (inchangés par ce lot), pas des chemins `GVL_IHM`/`GVL_PERSISTENT` — rien à y
migrer.

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : aucune autre référence à
`_WinchMaxStepDescent`/`_WinchMaxStepAscent`/`_WinchSlowdownDistance_M`/`_WinchSlowSpeed_Pct` ni à
`GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente`/`CfgMaxStepAscent`/`CfgSlowdownDistance_M`/
`CfgSlowSpeed_Pct` (ni la variante M2) n'existe ailleurs.

### 5.5 — `DOC/AUDITS/ConfigPersistence/IHM_VARIABLES_MIGRATION.md`

Ajouter une nouvelle section (après la dernière section ✅ existante, avant "🔜 Lots à venir") :
```markdown
## ⏳ Lot 3d-1 — Winch : 4 champs communs M1/M2 déplacés vers Commun.Cfg (document de tâche
écrit, PAS encore exécuté/vérifié — ne pas reparamétrer l'IHM sur ce lot tant que cette section
n'est pas passée en ✅)

⚠️ **Chemin très probablement câblé sur le pupitre IHM réel** (contrairement à la plupart des
lots précédents) — c'est le domaine du bug originel de ce chantier. Vérifier le pupitre avant
et après ce lot.

`M1TreuilRetenue.Cfg`/`M2TreuilBenne.Cfg` avaient CHACUN leur propre chemin pour 4 valeurs en
réalité PARTAGÉES (même valeur forcée des deux côtés) — un seul chemin les remplace tous les deux :

| Ancien chemin (×2, M1 et M2, valeur toujours identique) | Nouveau chemin (prévu) |
|---|---|
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente` / `GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente` | `GVL_IHM.Commun.Cfg.WinchMaxStepDescente` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepAscent` / `GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepAscent` | `GVL_IHM.Commun.Cfg.WinchMaxStepAscent` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M` / `GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M` | `GVL_IHM.Commun.Cfg.WinchSlowdownDistance_M` |
| `GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct` / `GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct` | `GVL_IHM.Commun.Cfg.WinchSlowSpeed_Pct` |
```

## 6. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_WinchCfg.st`
2. `CODE/SUPERVISION/_TYPES/ST_CommunCfg.st`
3. `CODE/GVL_PERSISTENT.st`
4. `CODE/MAIN/PRG_09_Supervision.st`
5. `CODE/MAIN/PRG_06_WinchControl.st`
6. `DOC/AUDITS/ConfigPersistence/IHM_VARIABLES_MIGRATION.md`
7. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ne pas créer `FB_CfgPersistBridge_WinchCfg`** dans ce lot — c'est le lot suivant (3d-2), une
  fois `ST_WinchCfg` réduit à 7 champs indépendants.
- **Ne pas toucher** `instCfgPersistBridgeCommun` ni son appel — déjà correct, couvre
  automatiquement les 4 nouveaux champs de `ST_CommunCfg` sans aucune modification.
- **Ne pas toucher** `CODE/TREUILS/FB_Winch.st` — ses `VAR_INPUT` (`CfgMaxStepDescente`,
  `MaxStepAscent`, `CfgSlowdownDistanceM`, `CfgSlowSpeedPct`) ne changent pas de nom ni de
  signature, seule la SOURCE des valeurs passées par l'appelant change.
- **Ne pas toucher** `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st` (voir §5.4).
- **Ne pas toucher** aux fichiers des lots précédents déjà committés (Lot 3a `FB_CfgPersistBridge_SyncCfg`,
  Lot 3b `FB_CfgPersistBridge_CycleCfg`/`CommunCfg`/`BucketCfg`, correctif générateur `xml_builder.py`).
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage.
- **PascalCase strict**, pas de hongrois.
- Le reset unique de ces 4 valeurs au premier téléchargement de ce lot (retour aux défauts `3`/`5`/
  `1.0`/`15.0`) est **accepté** — même principe déjà validé aux lots 3a/3b.

## 8. Obligatoire avant restitution

1. `grep -rn "_WinchMaxStepDescent\b\|_WinchMaxStepAscent\b\|_WinchSlowdownDistance_M\b\|_WinchSlowSpeed_Pct\b" CODE/`
   doit retourner **zéro résultat**.
2. `grep -rn "GVL_IHM\.\(M1TreuilRetenue\|M2TreuilBenne\)\.Cfg\.\(CfgMaxStepDescente\|CfgMaxStepAscent\|CfgSlowdownDistance_M\|CfgSlowSpeed_Pct\)\b" CODE/`
   doit retourner **zéro résultat**.
3. `grep -n "WinchMaxStepDescente\|WinchMaxStepAscent\|WinchSlowdownDistance_M\|WinchSlowSpeed_Pct" CODE/SUPERVISION/_TYPES/ST_CommunCfg.st CODE/GVL_PERSISTENT.st CODE/MAIN/PRG_06_WinchControl.st`
   doit montrer les 4 champs déclarés ET utilisés aux endroits attendus.
4. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
5. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
6. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] `ST_WinchCfg.st` : 7 champs + `Initialized` (les 4 champs communs retirés).
- [ ] `ST_CommunCfg.st` : 3 champs existants + 4 nouveaux (`WinchMaxStepDescente`/`WinchMaxStepAscent`/
      `WinchSlowdownDistance_M`/`WinchSlowSpeed_Pct`) + `Initialized`.
- [ ] `GVL_PERSISTENT.st` : 4 variables plates retirées, `_CommunCfgPersist` étendu avec les mêmes
      valeurs par défaut (`3`/`5`/`1.0`/`15.0`).
- [ ] `PRG_09_Supervision.st` : 4 lignes retirées des 2 blocs de restauration M1/M2 (2 chacun), 2
      blocs de réconciliation entiers supprimés (32 lignes au total), **aucun nouveau code
      restauration/sauvegarde ajouté** (le pont Commun existant suffit).
- [ ] `PRG_06_WinchControl.st` : 4 lectures migrées vers `_CommunCfgPersist.WinchXxx`.
- [ ] `FB_Winch.st`, `FB_ModesValidation.st`, `instCfgPersistBridgeCommun`/son appel non modifiés.
- [ ] `IHM_VARIABLES_MIGRATION.md` mis à jour avec la nouvelle section (§5.5), signalée comme
      "chemin probablement câblé sur pupitre réel".
- [ ] `grep` de vérification §8.1/§8.2 = zéro résultat.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

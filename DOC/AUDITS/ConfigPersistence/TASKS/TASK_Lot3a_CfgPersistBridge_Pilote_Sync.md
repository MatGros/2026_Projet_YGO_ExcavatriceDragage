# 📋 Document de Tâche — Lot 3a : Pilote `FB_CfgPersistBridge_SyncCfg`
## Généralisation de la persistance des `Cfg` — première application sur `M1M2Sync`

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Suite du Lot 2 (restructuration IHM Cmd/State/Cfg/Bypass, 6 domaines, tous faits et
> vérifiés). Ce lot ouvre le Lot 3 (persistance générique) — **pilote sur UN SEUL domaine** avant
> généralisation aux autres, même discipline que le Lot 2 (domaine par domaine).

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande. Ce lot touche `GVL_PERSISTENT` (variables
  `PERSISTENT RETAIN`, pas juste `RETAIN` simple) — sois particulièrement attentif à tout ce qui
  ressemblerait à une perte de valeur réelle non documentée.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §6** — toute modification hors périmètre (ex. outillage
  Python, autre struct Cfg que Sync) doit être signalée séparément dans ta restitution, jamais
  appliquée silencieusement en plus de ce qui est demandé. **Ce lot ne touche QUE `M1M2Sync` — ne
  généralise PAS le pattern aux autres domaines (Winch/Bucket/Commun/Cycle) même si ça semble une
  suite logique évidente : ce sera un lot séparé une fois ce pilote vérifié.**
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté** — ne reste jamais bloqué par manque de contexte sans avoir essayé. Pointeurs utiles :
  - `DOC/NAMING_CONVENTION.md` — convention de nommage.
  - `CODE/COMMUN/FB_Brake.st`, `FB_Ramp.st` — exemples de FB génériques déjà en place dans
    `CODE/COMMUN/`, pour le style de header/commentaire à reproduire pour le nouveau FB.
  - `CODE/MAIN/PRG_09_Supervision.st` **en entier** — comprendre le contexte autour des blocs à
    remplacer (§5.2/§5.3 ci-dessous donnent l'état exact déjà lu, mais relis le fichier réel, il a
    pu bouger depuis).
  - `CODE/SUPERVISION/_TYPES/ST_SyncCfg.st` — le type exact à faire transiter par le FB pont.
  - Si aucun de ces pointeurs ne suffit à lever le doute : c'est le moment de t'arrêter et de
    signaler, pas de deviner.

## 1. Contexte

Depuis le Lot 2, chaque domaine IHM a un sous-struct `Cfg` protégé par un flag `Initialized`, avec
un bloc de restauration boot + un bloc de sauvegarde continue **écrits à la main** dans
`PRG_09_Supervision.st`, champ par champ, un bloc par domaine (`M1TreuilRetenue.Cfg`,
`M2TreuilBenne.Cfg`, `M1M2Sync.Cfg`, `M2TreuilBenne.Bucket.Cfg`, `Commun.Cfg`, `Cycle.Cfg`). Le
pattern est strictement identique à chaque fois (voir n'importe lequel de ces 6 blocs) — **pur
code répétitif**, source d'erreur à chaque nouveau domaine (ex. oubli d'un champ, faute de frappe).

**Objectif du Lot 3** : remplacer ces blocs manuels par un **Function Block générique**
`FB_CfgPersistBridge_<Type>` (un par TYPE de struct `Cfg` distinct — pas par instance — réutilisé
pour les instances qui partagent un type, ex. `ST_WinchCfg` pour M1 ET M2). Le FB fait, en une
seule instance appelée une fois par scan :
- Restauration boot (`Hmi.Initialized = FALSE` → copie `Persist` → `Hmi`, marque `Initialized`).
- Sauvegarde continue (`Hmi.Initialized = TRUE` → copie `Hmi` → `Persist`).
- Signale à l'appelant qu'une restauration vient d'avoir lieu (pour piloter l'alarme
  `ConfigRestoredFromPersistent`, gérée en dehors du FB — cross-domaine, pas son rôle).

**Ce lot (3a) est un PILOTE** : on l'applique d'abord à **`M1M2Sync.Cfg` uniquement** (le plus
simple : 1 seul champ métier, 1 seule instance, pas de sous-struct imbriqué). Une fois vérifié, un
lot suivant généralisera aux 5 autres types (`ST_WinchCfg` ×2 instances, `ST_BucketCfg`,
`ST_CommunCfg`, `ST_CycleCfg`).

### ⚠️ Point de conception validé avec l'utilisateur (2026-07-24) — reset unique accepté

`GVL_PERSISTENT` est `VAR_GLOBAL PERSISTENT RETAIN` : contrairement au `RETAIN` simple de
`GVL_IHM`, CODESYS ne fait correspondre les valeurs `PERSISTENT` d'un build à l'autre que par NOM
de variable. **Remplacer une variable plate (`_WinchSyncTolerance_M`) par un champ de struct
(`_SyncCfgPersist.CfgSyncTolerance_M`) fait perdre la valeur actuellement persistée au premier
téléchargement de ce lot** — elle repart au défaut compilé (`0.25`).
**Confirmé acceptable par l'utilisateur** : aucune valeur de calibration critique n'est en jeu
aujourd'hui sur la machine réelle (tolérance synchro jamais réglée en dehors du défaut). Ce reset
unique est **accepté explicitement pour ce lot** — ne pas essayer d'inventer un mécanisme de
migration transitoire (double lecture ancien/nouveau nom), ce serait une complexité non demandée.

## 2. Objectif

1. Créer `CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st` — FB générique de pont persistance pour le
   type `ST_SyncCfg` (voir §4 pour le code exact).
2. Modifier `CODE/GVL_PERSISTENT.st` : remplacer la variable plate `_WinchSyncTolerance_M` par
   `_SyncCfgPersist : ST_SyncCfg` (voir §5.1).
3. Modifier `CODE/MAIN/PRG_09_Supervision.st` : remplacer les 2 blocs manuels (restauration §2 +
   sauvegarde §3) par **un seul appel** au nouveau FB (voir §5.2/§5.3).
4. Modifier `CODE/MAIN/PRG_06_WinchControl.st` : le seul autre consommateur de
   `_WinchSyncTolerance_M` (voir §5.4) doit lire le nouveau chemin `_SyncCfgPersist.CfgSyncTolerance_M`.
5. Régénérer le bundle, vérifier les gates.

## 3. État actuel exact de `ST_SyncCfg.st` (déjà existant, **ne pas toucher ce fichier**)

```
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 0.25;  (* 📐 Tolérance max d'écart (m) *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot, ex-CfgInitialized renommé pour cohérence avec ST_WinchCfg *)
END_STRUCT
END_TYPE
```

## 4. Nouveau FB — `CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st` (nouveau fichier)

```
(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_SyncCfg — Pont persistance générique pour ST_SyncCfg
   ───────────────────────────────────────────────────────────────
   🎯 Remplace les blocs manuels restauration/sauvegarde dupliqués à chaque domaine
   (voir DOC/AUDITS/ConfigPersistence/). Une instance = un couple (struct IHM, struct
   GVL_PERSISTENT) du MÊME type. Logique :
   - Hmi.Initialized = FALSE (RETAIN invalidé, ex. changement de layout DUT) → restaure
     Hmi depuis Persist, marque Initialized, pulse JustRestored 1 scan.
   - Hmi.Initialized = TRUE → sauvegarde continue Hmi vers Persist (jamais l'inverse).
   🔒 Défense en profondeur : jamais d'écriture PERSISTENT avant qu'une restauration
   réussie n'ait eu lieu (même principe que tous les blocs Cfg du Lot 2).
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_SyncCfg
VAR_IN_OUT
    Hmi     : ST_SyncCfg; (* 🖥️ ex. GVL_IHM.M1M2Sync.Cfg — struct exposé à l'IHM *)
    Persist : ST_SyncCfg; (* 💾 ex. GVL_PERSISTENT._SyncCfgPersist — mémoire PERSISTENT *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL; (* 🔔 TRUE pendant 1 scan le boot où la restauration a eu lieu —
                             l'appelant s'en sert pour piloter GVL_IHM.Commun.ConfigRestoredFromPersistent *)
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

⚠️ **Pourquoi `Hmi := Persist;` puis `Hmi.Initialized := TRUE;` dans cet ordre** : la première
ligne copie AUSSI le champ `Initialized` de `Persist` (qui vaut `FALSE` par défaut ou n'importe
quelle valeur résiduelle, sans importance) — la ligne suivante l'écrase immédiatement à `TRUE`.
Ne pas inverser l'ordre, ne pas essayer d'exclure `Initialized` de la copie (complexité inutile,
ce champ est de toute façon écrasé juste après).

## 5. Sweep exhaustif des références — vérifié par grep, ne pas en chercher d'autres

### 5.1 — `CODE/GVL_PERSISTENT.st`

État actuel (section `⚖️ SYNCHRONISATION (M1 ↔ M2)`) :
```
    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _WinchSyncTolerance_M : REAL := 0.25; // Tolérance écart (REX 2026-07-08 : 0.10 -> 0.25)
    _WinchCriticalSyncTolerance_M : REAL := 2.0; // Méca E : écart critique
    _SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)
```
Remplacer **uniquement** la ligne `_WinchSyncTolerance_M` (garder `_WinchCriticalSyncTolerance_M`
et `_SyncSoftStopEnable` inchangées — hors périmètre, pas encore reliées à un `Cfg` IHM) :
```
    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _SyncCfgPersist : ST_SyncCfg := (CfgSyncTolerance_M := 0.25); // 🌉 Pont FB_CfgPersistBridge_SyncCfg (ex-_WinchSyncTolerance_M)
    _WinchCriticalSyncTolerance_M : REAL := 2.0; // Méca E : écart critique
    _SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)
```

### 5.2 — `CODE/MAIN/PRG_09_Supervision.st` — déclaration d'instance

Ajouter dans le `VAR` du programme (à la suite de `instAckConfigRestored : R_TRIG;` ou tout autre
endroit cohérent du bloc `VAR`) :
```
    instCfgPersistBridgeSync : FB_CfgPersistBridge_SyncCfg; // 🌉 Pont persistance M1M2Sync.Cfg (Lot 3a, pilote)
```

### 5.3 — `CODE/MAIN/PRG_09_Supervision.st` — remplacement des 2 blocs manuels

**Bloc de restauration actuel (section "── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT")** :
```
IF NOT GVL_IHM.M1M2Sync.Cfg.Initialized THEN
    GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M          := _WinchSyncTolerance_M;
    GVL_IHM.M1M2Sync.Cfg.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
→ **remplacer par** :
```
instCfgPersistBridgeSync(Hmi := GVL_IHM.M1M2Sync.Cfg, Persist := _SyncCfgPersist);
IF instCfgPersistBridgeSync.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
```
(placer cet appel au MÊME endroit que l'ancien bloc — la logique de restauration ET de sauvegarde
est maintenant gérée par ce seul appel, exécuté une fois par scan, quel que soit l'état
`Initialized`).

**Bloc de sauvegarde actuel (section "── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE")** :
```
// ⚠️ REX 2026-07-08 (5) — PIÈGE pont IHM→PERSISTENT découvert lors de l'audit, désormais clos
// par le flag `M1M2Sync.Cfg.Initialized` (posé en §2 uniquement après restauration réussie).
IF GVL_IHM.M1M2Sync.Cfg.Initialized THEN
    _WinchSyncTolerance_M       := GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M;
END_IF;
```
→ **supprimer ce bloc entièrement** (la sauvegarde est désormais faite par
`instCfgPersistBridgeSync` en §5.3 ci-dessus — ce bloc devient redondant, pas juste inutile : le
laisser créerait une double-écriture PERSISTENT au même scan). Le commentaire REX peut être retiré
avec le bloc (il documentait le piège que l'appel FB résout maintenant structurellement).

### 5.4 — `CODE/MAIN/PRG_06_WinchControl.st:300` (seul autre consommateur)

```
CfgSyncToleranceM  := _WinchSyncTolerance_M,
→ CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
```

⚠️ **Vérifié exhaustivement (grep sur tout `CODE/`)** : `_WinchSyncTolerance_M` n'a que ces 3
usages (déclaration + les 2 ci-dessus). Après ce lot, `grep -rn "_WinchSyncTolerance_M" CODE/`
doit retourner **zéro résultat** — plus aucune trace de l'ancien nom nulle part.

## 6. Fichiers à modifier

1. `CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st` (nouveau)
2. `CODE/GVL_PERSISTENT.st`
3. `CODE/MAIN/PRG_09_Supervision.st`
4. `CODE/MAIN/PRG_06_WinchControl.st`
5. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 7. Contraintes STRICTES

- **Ce lot ne touche QUE `M1M2Sync.Cfg`** — ne pas généraliser aux autres domaines (`Winch`,
  `Bucket`, `Commun`, `Cycle`) même si le pattern semble évident à répliquer. Ce sera un lot séparé.
- **Ne pas toucher** `CODE/SUPERVISION/_TYPES/ST_SyncCfg.st` — le type ne change pas, seul son
  usage (via le FB pont) change.
- **Ne pas toucher** `_WinchCriticalSyncTolerance_M`/`_SyncSoftStopEnable` — pas encore reliés à un
  `Cfg` IHM, hors périmètre de ce lot.
- **Ne pas toucher** `FB_WinchSync.st` — cette FB reçoit déjà `CfgSyncToleranceM` en `VAR_INPUT`
  simple, aucun changement d'interface nécessaire, seul l'appelant (`PRG_06_WinchControl.st`)
  change sa source.
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage —
  hors périmètre strict de ce lot.
- **PascalCase strict**, pas de hongrois.
- Le reset unique de `_WinchSyncTolerance_M` → `0.25` au premier téléchargement de ce lot est
  **accepté et voulu** (voir §1) — ne pas tenter de le compenser.

## 8. Obligatoire avant restitution

1. `grep -rn "_WinchSyncTolerance_M" CODE/` doit retourner **zéro résultat**.
2. `grep -n "_SyncCfgPersist" CODE/GVL_PERSISTENT.st CODE/MAIN/PRG_09_Supervision.st CODE/MAIN/PRG_06_WinchControl.st`
   doit montrer la variable déclarée ET utilisée aux 3 endroits attendus.
3. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
4. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur
   (une erreur Gate 1 pré-existante sans lien avec ce lot peut déjà être présente, ne pas la
   corriger, hors périmètre).
5. Ne PAS committer — restituer le diff pour vérification.

## 9. Critères d'acceptation

- [ ] `FB_CfgPersistBridge_SyncCfg.st` créé exactement comme spécifié §4 (VAR_IN_OUT `Hmi`/`Persist`,
      VAR_OUTPUT `JustRestored`, logique restauration/sauvegarde correcte).
- [ ] `GVL_PERSISTENT.st` : `_WinchSyncTolerance_M` remplacée par `_SyncCfgPersist : ST_SyncCfg`,
      même valeur par défaut (`0.25`).
- [ ] `PRG_09_Supervision.st` : instance `instCfgPersistBridgeSync` déclarée, appelée UNE fois,
      `JustRestored` pilote `ConfigRestoredFromPersistent`. Ancien bloc de sauvegarde (§5.3)
      entièrement supprimé, pas juste commenté.
- [ ] `PRG_06_WinchControl.st:300` : lit `_SyncCfgPersist.CfgSyncTolerance_M`.
- [ ] `grep -rn "_WinchSyncTolerance_M" CODE/` = zéro résultat.
- [ ] `ST_SyncCfg.st`, `FB_WinchSync.st` non modifiés.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates sans nouvelle erreur.

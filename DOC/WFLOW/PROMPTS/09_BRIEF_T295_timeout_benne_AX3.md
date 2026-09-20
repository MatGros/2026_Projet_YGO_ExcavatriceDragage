# 🎯 BRIEF — T295 : timeout benne injustifié en AX3 / AX15B (ErrorID:03)

> **À copier-coller en tête de la mission déléguée :** le contenu **intégral** de
> `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (préambule obligatoire du projet).
> Ce brief **ne le remplace pas**.

```
════════════════════════════════════════════════════════════
MISSION T295 — Timeout benne [BENNE] ErrorID:03 en AX3_OPEN_BUCKET / AX15B_DUMP_OPEN
Criticité C3 · Domaine CYCLE_AUTO / BENNE · Stratégie patch
Orchestrateur : CC01 · Brief : 2026-09-20 · Nouvel agent attendu : DSH08 (premier tag libre)
Parent : — · Tâche : DOC/WFLOW/TASKS.yaml:1026-1070
Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T295_AX15B_BUCKET_OPEN_TIMEOUT.yaml
════════════════════════════════════════════════════════════
```

---

## 0 · PRÉREQUIS D'ENTRÉE — ⚠️ **DEUX BLOQUANTS AVANT DE CODER**

| # | Prérequis | État vérifié 2026-09-20 | Action |
|---|---|---|---|
| 1 | 🔒 **Verrou de travail** `T295` | ✅ **POSÉ** — `acteur: DSH08` (`TASK_LOCKS.json`, 2026-09-20T18:02:24) | — |
| 2 | 📄 **Contrat C3** | ✅ **COMPLÉTÉ** — scope élargi (`TOOLS/AGENT_WORKFLOW/scripts/`), `AC8-AC11`, `design_decision_20260920` ; `check_task_contract.py` **PASS 0 erreur** | — |
| 3 | Lire `AGENTS.md`, `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md`, `AF_Partie-10` | — | — |
| 4 | ⚠️ **T331** (repli treuils AX15b) écrit dans **`FB_CycleSemiAuto.st`** | — | **sérialiser** (voir §7) |

> ⛔ Sans 🔒 **et** contrat complété, **ne pas commencer** — remonter à l'orchestrateur.

---

## 1 · POSTURE (non négociable)

- 🛡️ **Anti-Yes-Man** : la décision de conception consignée le 2026-09-20 dit
  *« TON accumule uniquement pendant commande active (**CloseReq/OpenReq**), reset sinon »*.
  **Cette formulation est fausse par construction** (§3.4). Ton premier livrable est de la
  **réfuter ou de la corriger**, pas de l'appliquer.
- 🎯 **Cause racine d'abord**. Elle est **déjà établie** (§3.2) : la re-vérifier `fichier:ligne`,
  ne pas la re-découvrir, ne pas la supposer.
- 🔬 **Distingue** FAIT PROUVÉ / HYPOTHÈSE / INCERTAIN.
- 🚨 **Devoir d'alerte** : toute incohérence hors scope (ex. §3.3 `30 s` vs `60 s`) remonte
  **immédiatement**, sans être corrigée.
- ✍️ **Signaler n'est pas élargir**.

---

## 2 · CONTEXTE

**Symptôme terrain** (utilisateur, essais en cours 2026-09-20) : en cycle, l'ouverture de benne
(`AX3_OPEN_BUCKET`, libellé IHM `AX15 1/1`) finit en **`[BENNE] ErrorID:03` = « Timeout commande
deplacement benne »** après une commande **normale** suivie d'une **longue attente sans mouvement
bloqué avéré**. Défaut **latché** ⇒ il faut un `Reset` sur front pour repartir ⇒ **les essais du
grafcet sont pollués**.

**Demande utilisateur** : que le timeout ne compte **que** le temps où l'opérateur **commande
réellement** le mouvement, jamais les **pauses opérateur légitimes** (relâchement / reprise).

> 📌 Option **(b)** « timeout sur progression mesurée » (TASKS.yaml:1063-1065) est **explicitement
> hors scope** aujourd'hui (arbitrage utilisateur). Ne pas la concevoir, ne pas la coder.

---

## 3 · ANCRES VÉRIFIÉES `fichier:ligne` (point de départ — **à revérifier**)

### 3.1 La chaîne de commande en cycle

| Maillon | Ancre | Fait |
|---|---|---|
| Étape cycle AX3 | `CODE/G_CYCLE/FB_CycleSemiAuto.st:916-944` | `BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush` (`:936`) — **`ReqOpen` n'est vrai QUE joystick poussé** ; relâchement ⇒ `BucketCmd.ReqOpen := FALSE` (`:938`) |
| Étape cycle AX15B | `CODE/G_CYCLE/FB_CycleSemiAuto.st:1419-1447` | idem : `BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush` (`:1439`) |
| Arbitrage | `CODE/H_TREUILS_BENNE/FB_BucketCmdArbitration.st:62` | `CmdOpen_IHM := IHM.BtnOpen OR WinchBothDiveBucketOpenArmed OR ReqBucket.ReqOpen` |
| Demande **mémorisée** | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:424-425` | `IF CmdOpen_IHM AND NOT Lifecycle.Busy ... THEN OpenReq := TRUE` ⇒ **`OpenReq` est un LATCH** |
| Sens M2 en SEMI_AUTO | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:342-343` | `ReqDescend := WinchBothReqDescend OR (Mode = SEMI_AUTO AND Joystick.AxisY.Direction < 0)` ⇒ **`ReqDescend` suit le joystick EN DIRECT** |
| Armement du `Busy` | `FB_Bucket.st:434-444` | `BusyEdge(CLK := (CloseReq OR OpenReq) AND MotionRequestActive)` ⇒ `Lifecycle.Busy := TRUE` |

### 3.2 🎯 CAUSE RACINE (FAIT PROUVÉ — à confirmer par trace ou test, pas à re-chercher)

`CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:199` :

```st
TonTimeout(IN := Lifecycle.Busy, PT := CfgTimeoutDuration);
IF TonTimeout.Q THEN TimeoutFaultLatched := TRUE; END_IF;   // :200-202 → instCauses[2] → ErrorID:03
```

- `Lifecycle.Busy` **reste TRUE** tant que la manœuvre n'est pas **terminée**, pas tant que
  l'opérateur **commande**. Les seules sorties de `Busy` sont :
  arrivée position (`:515`/`:540`), erreur sévère (`:393-401`), abandon hors contexte (`:407-420`).
- ⇒ **Le relâchement du joystick n'arrête pas le TON** : les pauses opérateur sont **imputées au
  budget de 60 s** depuis le front de `Busy`, sans aucun mouvement ni commande.
- ⇒ **`60 s` de temps MURAL depuis l'armement** au lieu de `60 s` de **commande réellement
  engagée**. C'est le défaut, et il est **structurel** (pas un réglage).

### 3.3 Valeur effective du timeout — ⚠️ **incohérence à signaler** (O2)

| Source | Valeur | Ancre |
|---|---|---|
| Valeur **persistée** (effective, pontée IHM) | `T#60s` | `CODE/GVL_PERSISTENT.st:64-82` (`:81`) → `PRG_04:370` |
| Défaut du **type IHM** | `T#30s` | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketCfg.st:7` |
| Défaut **FB** | `T#60s` | `FB_Bucket.st:50` |

⇒ **Signaler** l'écart `30 s` (type) ≠ `60 s` (persisté), **sans le corriger** dans ce lot.
**Interdit formellement** : augmenter ou supprimer `CfgTimeoutDuration` (contrat T295 `forbidden:`
+ `acceptance AC3`).

### 3.4 🔴 LES DEUX PIÈGES — c'est **le** travail de conception de ce lot

**PIÈGE A — la décision consignée est vide de sens si elle est prise au mot.**

La consigne `TASKS_ORCHESTRATOR.yaml:2270` dit *« TON accumule uniquement pendant commande active
(CloseReq/OpenReq), reset sinon »*.
**FAUX** : `OpenReq`/`CloseReq` **sont des latches** (`FB_Bucket.st:424-431`, remis à FALSE
uniquement à l'arrivée `:515`/`:540`, en erreur sévère `:398-399`, ou à l'abandon de contexte
`:416-417`). Ils restent **TRUE pendant toute la pause opérateur**.
⇒ Conditionner le TON sur `(CloseReq OR OpenReq)` = **zéro changement de comportement**.
⛔ Ne pas livrer cette version.

**PIÈGE B — « reset au relâchement » ≠ « temps cumulé ».**

`TASKS.yaml:1062-1063` décrit l'option (a) comme *« reset du TON a chaque relachement de commande
(**temps cumule** uniquement pendant commande active) »* : **contradictoire**. Un `TON` IEC **remet
`ET` à zéro** dès `IN=FALSE` ⇒ « reset » et « cumul » sont **exclusifs**. Deux sémantiques
réellement différentes, **à trancher explicitement** :

| Option | Sémantique | Détection d'un vrai blocage | Coût / risque |
|---|---|---|---|
| **a1 — engagement CONTINU** | `TonTimeout(IN := Lifecycle.Busy AND <engagement>, PT := ...)` ⇒ `ET` repart de 0 à chaque relâchement | Blocage **sous commande continue tenue ≥ PT** uniquement | ✅ TON standard, aucun état ajouté |
| **a2 — ⭐ ACTÉE PAR L'HUMAIN le 2026-09-20 — SUSPENSION, PAS REMISE À ZÉRO** | `ET` **gelé** pendant le relâchement, **reprise au ré-engagement**, cumul jusqu'à `PT` | Blocage **continu** détecté **et** blocage partiellement recouvert par des relâchements, dès que le **cumul** atteint `PT` | ⚠️ exige une **composition** (le `TON` IEC ne sait pas « pauser ») ⇒ à implémenter **proprement**, cf. §6.1 |

**Signal d'engagement — ⚠️ DÉCISION CC01, à challenger si tu as mieux `fichier:ligne` :**

| Candidat | Verdict | Motif |
|---|---|---|
`MotionRequestActive` (`FB_Bucket.st:391`, `= (ReqAscent OR ReqDescend) AND NOT conflict`) | 🟢 **RETENU** | en SEMI_AUTO il **suit le joystick en direct** (`PRG_04:342-343`) ; c'est **déjà** la condition d'armement du `Busy` (`:434`) ; disponible **sans** changer l'interface FB |
`CloseReq` / `OpenReq` (nommés par l'humain) | 🔴 **INOPÉRANT — ne pas utiliser** | ce sont des **latches** (`FB_Bucket.st:424-431`, remis à FALSE seulement à l'arrivée `:515`/`:540`, en erreur sévère `:398-399`, à l'abandon de contexte `:416-417`) ⇒ **TRUE pendant toute la pause** ⇒ **zéro changement de comportement**. **Signalé à l'humain le 2026-09-20** (cf. contrat T295 `design_decision_20260920.alerte_cc01_signal`). |
`CmdOpen_IHM` / `CmdClose_IHM` | 🔴 rejeter | combinent le cycle **et** des armements couplés (`FB_BucketCmdArbitration.st:49-62`) — pas une intention continue |
`M2_RunRequest` | 🟠 rejeter | tombe aussi quand un **permis** bloque alors que l'opérateur commande ⇒ masquerait un cas « commandé mais interdit » |
`M1_Busy`/`M2_Busy` | 🔴 rejeter | état **matériel**, pas une intention |
`JoystickPush` | 🔴 rejeter **ici** | **n'existe pas** dans `FB_Bucket` ⇒ nouveau `VAR_INPUT` = changement d'interface à arbitrer (hors scope T295) |

> 🎯 **Décision ACTÉE (contrat T295 §`design_decision_20260920`)** : sémantique **a2** (suspension, cumul,
> remise à zéro **uniquement** en fin de manœuvre `Lifecycle.Busy` retombé et sur `Reset` **sur front**),
> signal **`MotionRequestActive`**, `PT` **inchangé** (60 s effectif), **latch inchangé**.
> Si tu démontres `fichier:ligne` qu'un autre signal est plus juste, **signale-le avant de coder**.
> ⚠️ **Risque résiduel assumé** : un blocage **réel** haché par des relâchements peut ne jamais atteindre
> le cumul — les filets conservés sont les causes 1 (`:186-196`) et 3 (`:208-214`), la non-arrivée à la
> cible visible par le cycle, et la détection du blocage **sous commande continue**.

---

## 4 · OBJECTIFS (la restitution se juge **contre eux**)

| # | Objectif |
|---|---|
**O1** | **Cause racine re-confirmée** `fichier:ligne` (elle est en §3.2) **et reproduite** : test CI qui **échoue avant** / **passe après**, ou trace. |
**O2** | **Valeur effective du timeout** établie et **incohérence §3.3 signalée** (non corrigée). |
**O3** | **Comportement cible prouvé** : une **pause opérateur** (relâchement > `PT`, sans progression) **ne produit AUCUN `ErrorID:03`**, ni `Error` ni `Latched`. |
**O4** | **Non-neutralisation** : un mouvement **commandé en continu** sans progression **latche toujours** dans un délai borné (`≤ CfgTimeoutDuration`), et un mouvement nominal n'est **jamais** en défaut. |
**O5** | **Garde-fou `guard:`** versé dans `TOOLS/AGENT_WORKFLOW/scripts/` **et branché dans `PLANS`** de `run_all_gates.py` (cf. REX « garde-fou mort-né », §8). |
**O6** | **Aucune régression** : ouverture hors AX15B, fermeture, jog benne, homing benne, `Reset` sur front, **aucun redémarrage automatique**. |

---

## 5 · PÉRIMÈTRE

| Attendu (cible du correctif) | Interdit |
|---|---|
`CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (**cible principale**) · `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st` · le **garde-fou** `TOOLS/AGENT_WORKFLOW/scripts/G5xx_*.py` + sa ligne `PLANS` · contrat T295 + `DOC/WFLOW/TASKS.yaml` (suivi) · `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` (**si et seulement si** la sémantique du timeout change : la doc doit dire la **vérité**) | ⛔ `CfgTimeoutDuration` (valeur **et** défauts) · ⛔ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` et `PRG_07_Supervision.st` (T291-B / T330) · ⛔ `CODE/L_SIMULATION/*` (T300 P-A / T328) · ⛔ `CODE/G_CYCLE/FB_CycleSemiAuto.st` (**T331** en vol) · ⛔ `CODE/J_SUPERVISION/_TYPES/*` (champ IHM = arbitrage orchestrateur) · ⛔ `PRJ_CODESYS/**/Device.export` · ⛔ `GVL_PERSISTENT.st` · ⛔ tout autre fichier sans justification `fichier:ligne` |

> ✅ `FB_Bucket.st` **n'est actuellement modifié par personne** (vérifié : absent de `git status --short`).

---

## 6 · TRAVAIL DEMANDÉ

1. **Appliquer la sémantique ACTÉE** (`a2` — suspension, cumul, remise à zéro en fin de manœuvre et sur
   `Reset` sur front) avec le signal **`MotionRequestActive`** (§3.4). **Piste d'implémentation** (à
   challenger, tu restes garant du code) : pas de nouvel état lourd ni de `dt` requis — un `TON` relancé
   avec le **temps restant** (`PT := CfgTimeoutDuration - <temps engagé déjà consommé>`, temps consommé
   mémorisé chaque scan où l'engagement est vrai, remis à zéro quand `Lifecycle.Busy` retombe).
   ⚠️ Contrôler explicitement : (i) **aucun** re-latch immédiat après `Reset` sur front pendant une
   commande encore engagée ; (ii) `PT` **jamais** nul ni négatif (borner à `T#0ms` et documenter le cas) ;
   (iii) comportement identique en `Enable=FALSE` / `PowerContactorEngaged=FALSE` (gate `:240-264`).
   **Écrire la décision effective dans le contrat T295** (`design_decision_20260920`).
2. **Tracer la chaîne de bout en bout** `fichier:ligne`, **avant** de coder, et **nommer le
   consommateur final** (`CODE_QUALITY_STANDARDS` §3ter) : producteur du défaut → `FB_Bucket.Fault`
   → `PRG_04:1748-1750` (`BucketState.ErrorId`) → `PRG_07` → `GVL_IHM` → **opérateur (bandeau)**.
3. **Reproduire** : test CI (O1) **rouge avant**, **vert après**. Réutiliser/étendre
   `TC-P10-046.1` (`test_fb_bucket.st:754-798`, `CfgTimeoutDuration` forcé à `T#1s`) :
   - **TC-P10-046.1** conservé : commande **continue**, pas de progression ⇒ `Fault.Error` + `Fault.Latched` ;
   - **nouveau TC — pause opérateur** : `Busy` armé, puis **relâchement** (`ReqDescend := FALSE`) maintenu **> `PT`** ⇒ **aucun** défaut ;
   - **nouveau TC — reprise** : après la pause, ré-engagement ⇒ la manœuvre aboutit **sans** défaut ;
   - **nouveau TC — non-régression arrivée** : progression jusqu'à la cible sous commande ⇒ `Lifecycle.Done`, **aucun** défaut.
4. **Corriger au minimum** — dans `FB_Bucket.st` seul, sans toucher `PT`, sans nouveau `VAR_INPUT`,
   sans nouvel état persistant si `a1` est retenu.
5. **Garde-fou `fix:` + `guard:`** — **deux** livrables. Le gate doit **échouer** si le TON de
   timeout est de nouveau armé sur le **seul** `Lifecycle.Busy`, et vérifier la présence des tests
   ci-dessus. **Choisir un identifiant LIBRE** : `G504`/`G505` sont **réservés T330**, `G506` est
   **pris** (T255-D) ⇒ **`G507` ou au-delà**, après vérification du dépôt.
6. **Signaler** (§3.3) l'écart `30 s`/`60 s` — **sans** le corriger.

### ⚠️ Piège de test à vérifier AVANT d'écrire (anti-test-vacuant)

`test_fb_bucket.st` passe **partout** `MotionRequestActive := TRUE` en argument nommé
(ex. `:73`, `:775`, `:792`), alors que `MotionRequestActive` est un **`VAR` local** de `FB_Bucket`
(`FB_Bucket.st:127`, **calculé** en `:391`) et **non** un `VAR_INPUT`.
⇒ **Établir** si le harnais `STruCpp` **injecte réellement** ce paramètre ou s'il est **ignoré**.
S'il est ignoré, tes tests doivent piloter les **vraies entrées** (`ReqAscent` / `ReqDescend`) et la
**pause** doit être faite **par ces entrées**, jamais par un argument inerte. Un test qui « passe »
sur un paramètre mort ne prouve rien.

---

## 7 · CHANTIERS CONCURRENTS — **sérialisation**

| Tâche | Agent | Fichiers | État | Conflit |
|---|---|---|---|---|
🔴 **T331** (repli treuils AX15b) | à nommer | **`FB_CycleSemiAuto.st`** | brief émis, non démarré | **même étape AX15b fonctionnellement** ⇒ ne pas toucher `FB_CycleSemiAuto.st` ici ; **essai machine** des deux lots **sérialisé** |
T255-D (défaut muet FDC bas) | DSH05 | `FB_Hmi_BannerFormatter.st`, `PRG_07_Supervision.st` | ⏳ en vol | 🔴 **`PRG_07` interdit ici** |
T300 P-A / T328 | DSH03 🔒 | `L_SIMULATION/*` | ⏳ | 🔴 interdit ici |
T330 | DSH06 🔒 | docs T330, `G504`/`G505` | ⏳ plan v1.3 | gates **504/505 réservés** |
T291-B | AGY01 | `PRG_04`, gates 499→505 | en attente | 🔴 `PRG_04` interdit ici |
T333 / T334 / T336 / T332 | DSH02/DSH07/CDX02/DSH04 | hors périmètre | ⏳ | — |

---

## 8 · CRITÈRES TESTABLES

| AC | Critère | Preuve exigée |
|---|---|---|
**AC-A** | **Décision de conception écrite** dans le contrat T295 (`a1`/`a2` + signal + risque résiduel) **avant** toute écriture de code | diff du contrat |
**AC-B** | **Pause opérateur > `PT` sans progression ⇒ aucun défaut** (ni `Error`, ni `Latched`, `ErrorId` sans bit 2) | test CI rouge avant / vert après |
**AC-C** | **Blocage commandé en continu ⇒ défaut latché borné** (`TC-P10-046.1` toujours vert) | sortie brute |
**AC-D** | **Aucun changement** de `CfgTimeoutDuration` ni de ses défauts (60 s / 30 s) | `git diff` |
**AC-E** | **Garde-fou présent ET branché** (`PLANS`) — un gate non branché = **assurance fallacieuse** | ligne `PLANS` + exécution réelle |
**AC-F** | **Non-régression `FB_Bucket`** : suite `H_TREUILS_BENNE` **100 % PASS**, aucun test désactivé ni affaibli | rapport CI |
**AC-G** | **Aucun fichier hors périmètre** dans `git status --short` | sortie brute |
**AC-H** | **Incohérence `30 s`/`60 s` signalée** (non corrigée) | note |

### 🚨 REX À NE PAS REPRODUIRE — « garde-fou mort-né »

`G490_check_ihm_bindings.py` et `G499_check_t291b_top_authority.py` **existent mais ne s'exécutent
JAMAIS** : absents de `PLANS` (`run_all_gates.py:146-151`). ⇒ **AC-E exige la ligne `PLANS`.**

---

## 9 · PREUVES MÉCANIQUES À PRODUIRE (règle projet, aucune exception)

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report     # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C --pytest --full-ci
```

- ⛔ Sans `--full-ci`, `G460` (harnais `TEST_AUTO_CI`) **ne tourne pas** ; sans `--pytest`, `G420` non plus.
- Le bloc **`Auto-vérification liaison`** de `G200 --report` est **collé dans la restitution**.
- **Bandeaux** obligatoires : **1** bundle · **diff bundle + liste des objets** · **2** seulement si gates verts.

---

## 10 · RESPONSABILITÉ ET FORMAT DE RESTITUTION

- ⛔ **Aucun commit, aucun push.**
- 📊 **Checkpoint heartbeat** (session `T295`, agent **ton trigramme**, ex. `DSH08`) :
  `python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record T295 <ETAPE> <etat> --agent <TRIGRAMME> --msg "<résumé>"`
- 🔁 **Règle `fix:` + `guard:`**.

### Restitution attendue
1. **Verdict** (`PASS` / `ALERTE` / `BLOCK`)
2. **Décision de conception** (`a1`/`a2` + signal retenu + **risque résiduel** assumé)
3. **Traçabilité d'impact** : producteur → route → **consommateur final nommé**
4. **Cause racine** re-confirmée `fichier:ligne` + **reproduction** (test rouge avant / vert après)
5. **AC-A → AC-H** avec preuve
6. **Bloc `Auto-vérification liaison` (G200)** collé + **objets du diff bundle** listés
7. **Risques résiduels** et **fichiers modifiés** (chemins exacts)

---

## 11 · ⛔ CAS D'ARRÊT — demander, ne pas deviner

- 🔒 **Verrou `T295` absent ou porté par un autre acteur** → **STOP**
- 📄 **Contrat non conforme** (`check_task_contract.py` rouge) → **STOP**
- Tu ne peux pas démontrer `fichier:ligne` que le signal `MotionRequestActive` retombe bien au
  relâchement dans le scénario visé → **STOP et remonte** (un signal latché = correctif inopérant)
- Le correctif **exigerait** un nouveau `VAR_INPUT` (`JoystickPush` par ex.) ou un **champ IHM**
  → **arbitrage orchestrateur**, jamais décidé par l'agent
- Un **gate** existant échoue et la correction exige une **allowlist** → **remonter** (une exemption
  n'est **jamais** une décision d'agent, `subagent_preamble.md:44`)
- La tentation d'**augmenter / supprimer** le timeout → **refus catégorique** (AC-D, contrat AC3)

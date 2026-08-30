# 🎬 PLAN TECHNIQUE — Famille T171 (Animation pilotée par le code compilé)

> **Périmètre de modification : `TOOLS/TEST_AUTO_CI/**` uniquement.** Lecture du reste du
> projet autorisée (`CODE/`, `DOC/AF/`, `COMPILER_ST2C_STruCpp/`), écriture interdite hors de ce
> périmètre.
> **Worktree : `WT3_TEST_AUTO_CI`** · Base : `main` @ `19eb9e3a`.
> **Criticité :** T171 (C3 orchestration) → T171-A (C3) → T171-B (C2) → T171-CR (C2 review).
> **Révision :** v6 — intégration des objections du challengeur + **décision utilisateur**
> (copie de travail + animation 2 phases) + **audit humain externe (6 points bloquants)** +
> **cadrage final validé (Option 2 : avancer avec WORKING_COPY/)**.

---

## 0 · Décision utilisateur (re-scope, 2026-08-28)

> **Directive :** copier le code de séquence (semi-auto `FB_Cycle`, `FB_DiveSearch`,
> `FB_ExtractionSequence`) **dans le dossier de travail de l'outil** (`TOOLS/TEST_AUTO_CI/`) et
> travailler sur **cette copie modifiée** — jamais sur `CODE/`. L'objectif : la séquence
> automatique modifiée doit se comporter comme l'animation HTML/JS (traversée X0→X13 réaliste).

**Conséquences sur le plan :**
- **Copie de travail** : `TOOLS/TEST_AUTO_CI/WORKING_COPY/` héberge les copies modifiées de
  `FB_Cycle.st`, `FB_DiveSearch.st`, `FB_ExtractionSequence.st` (+ types/DUT nécessaires).
  Le harnais et la trace compilent **cette copie**, pas `CODE/`.
  ⚠️ **`WORKING_COPY/` n'existe pas encore** — à créer, avec **gate de faisabilité STruCpp**
  (fermeture de types complète) en tête de T171-A.
- **F1/F2 (bugs X11 / SampleCount)** : corrigés **dans la copie de travail** (dans le périmètre
  `TOOLS/`), avec un **test dédié qui échoue sur le code d'origine** (révèle le bug, ne le masque
  pas). Les correctifs sont **remontés** à l'orchestrateur pour réintégration `CODE/` ultérieure.
- **Animation en 2 phases** :
  - **Phase 1 (T171-B, maintenant)** : simple, **sans simulation mécanique/dynamique** — états
    discrets captés (pont/benne/mou), positions continues seulement là où la trace les porte.
  - **Phase 2 (future, hors T171)** : utiliser le **Simbench de l'automate** pour générer temps
    de réaction et dynamique réels.

---

## 0bis · Audit humain externe — 6 points bloquants (verdict : plan bloqué avant implémentation)

> **Verdict humain :** plan T171 bloqué tant que ces 6 points ne sont pas cadrés. Évaluation du
> challengeur (sourcée) ci-dessous.

| # | Point audit | Évaluation challengeur | Résolution |
|---|---|---|---|
| **1** | Compilation réelle de `WORKING_COPY` | ❌ Non couvert — **`WORKING_COPY/` n'existe pas** | Gate de faisabilité STruCpp (fermeture de types complète) en tête de T171-A ; nommer la source compilée |
| **2** | Correction F1 nécessite direction joystick absente de l'interface | ⚠️ F1 couvert, **cause racine nouvelle** : aucun `JoystickY`/`JoyDir` en `VAR_INPUT` (L.11-63) ; `ExpectedDirection` est une **sortie** (L.85-86) | Fix CODE prérequis (entrée `JoystickY`) ; TC-P04-100 n'exerce pas l'ouverture réelle ; test T8 qui échoue |
| **3** | **F6 (nouveau) : reprise après bascule de mode actuellement AUTOMATIQUE** | ❌ **Faille sécurité réelle non détectée** : `WaitingResume` posé à TRUE (L.215) mais `IF` vide (L.240-243), jamais lu pour couper les commandes → reprise auto du mouvement | Fix CODE prérequis (gater `WaitingResume`) ; T2 documente l'auto-reprise, ne la normalise pas |
| **4** | Séquence normative X0…X11→X13 (pas de X12) | ✅ Confirmé (AF-04 §4.2, pas de X12 dans l'enum) | Purger `X12_RESERVED` du HTML (L.611-616) |
| **5** | Trace = « binaire sous stimuli de harnais », non simulation physique réelle | ✅ R-F couvert | Reformuler la sémantique dans le plan + contrat |
| **6** | Garde-fou JS robuste, pas un simple grep | ⚠️ F5 partiel | Script taint AST + gate CI ; couvrir les sinks indirects |

**Décisions validées :** versionnage JSON + HTML (pas de `.gitignore`) ✅ · **SHA-256 croisé** de la
trace (déterminisme CI) ✅.

**2 nouveaux défauts CODE bloquants (hors T171, prérequis) :** X11 non réalisable sans entrée
joystick (point 2) · reprise automatique après bascule de mode (point 3). À escalader comme tâches
CODE avant de verrouiller T171-A.

---

## 0ter · Cadrage final validé (Option 2 — avancer avec WORKING_COPY/)

> **Décision utilisateur (2026-08-28) :** T171 produit une trace et une animation à partir d'un
> binaire STruCpp **réellement exécuté**. Il peut copier `FB_Cycle.st`, l'adapter dans
> `TOOLS/TEST_AUTO_CI/WORKING_COPY/`, puis compiler **explicitement cette copie** avec un runner
> isolé. **Aucune modification de `CODE/` ni de `registry.yaml`.**

### Exigences de traçabilité (contraignantes)

| # | Exigence | Application |
|---|---|---|
| **T1** | La trace, le HTML et le rapport indiquent explicitement **`SOURCE_TESTÉE = WORKING_COPY/FB_Cycle.st`** + son **SHA-256** | `meta.source` + `meta.sha256` dans le JSON ; bandeau dans le HTML |
| **T2** | **TC-P04-100** prouve le cycle nominal de la **copie corrigée** | Suite verte |
| **T3** | **T8 / F2 / F6** prouvent séparément que le source historique `CODE/G_CYCLE/FB_Cycle.st` **échoue** — **tests négatifs, exclus de la suite verte** | Runner isolé sur l'original ; non comptés dans le PASS |
| **T4** | Les correctifs F1/F2/F6 sont **remontés à l'orchestrateur** comme écarts à réintégrer ultérieurement dans `CODE/` | Rapport d'écarts |
| **T5** | **Aucun résultat T171 ne doit affirmer** que le programme CODESYS de production est déjà corrigé ou sécurisé | Formulation stricte dans trace/HTML/rapport |

### Cadrage v4 retenu (inchangé)

- Séquence **`[X0…X11, X13]`** (pas de X12).
- Trace qualifiée **« binaire sous stimuli de harnais »** (pas une dynamique physique réelle).
- **JSON + HTML versionnés** avec **SHA-256 croisé**.
- **Garde-fou JS mécanique** (AST + taint, pas grep).

### Architecture d'exécution (runner isolé)

```text
WORKING_COPY/FB_Cycle.st (copie corrigée F1/F2/F6)   ──┐
   + types/DUT (fermeture complète)                    │  runner isolé
   ▼                                                    │  (pas registry.yaml)
compile STruCpp → binaire → TC-P04-100 → trace JSON    │
                                                       ─┘
CODE/G_CYCLE/FB_Cycle.st (original, lecture seule)  ──┐
   ▼                                                  │  runner isolé (tests négatifs)
compile STruCpp → T8/F2/F6 → échec attendu            ─┘
```

---

## 1 · Objectif global (T171)

**Éradiquer la simulation JS fictive** (`STATE`, `simStep`, `executeAutoSequence`,
`updatePhysics`) de `FICHE_SEMI_AUTO_ANIMATION.html` et asservir la cinématique Canvas aux
**valeurs réelles du binaire ST IEC compilé** (`FB_Cycle` via STruCpp), via une **trace
scan-par-scan** `trace_semi_auto_cycle.json`.

**Critère d'acceptation de haut niveau (corrigé après challenge) :** aucune décision d'étape,
aucun calcul de mouvement décisionnel en JavaScript. **L'étape vient de `CycleStep` (trace)** ;
**les positions viennent des retours captés** dans la trace (`M1_CablePosM`, `M2_CablePosM`),
**les axes sans analogique sont rendus en états discrets captés** (`Translation_At_*`,
`Benne_IsOpen/_IsClosed`) — **jamais interpolés ni reconstruits en JS**.

> ⚠️ **Alerte devoir d'alerte (AGENTS.md §Posture)** : le challengeur a identifié **2 défauts
> réels dans `CODE/G_CYCLE/FB_Cycle.st`** (F1, F2) qui **bloquent l'AC1 de T171-A** et un
> dépassement d'interface (F3). Ce sont des bugs **hors périmètre T171** (`CODE/**` interdit).
> Ils sont remontés ici pour décision — le harnais ne doit **pas** les masquer.

---

## 1bis · 🔬 Provenance des données — code compilé vs stubs/mocks (exigence utilisateur)

> **Exigence :** la compilation et la simulation doivent être **sans ambiguïté** sur ce qui vient
> du **code ST compilé** et ce qui vient des **stubs/mocks de harnais**. L'utilisateur ne doit
> **jamais** croire ou statuer sur un manque d'information. Le périmètre de chaque donnée est
> **explicite et tracé**.

### 1bis.1 · Taxonomie de provenance (chaque champ de la trace est étiqueté)

| Provenance | Définition | Exemples dans `FB_Cycle` |
|---|---|---|
| **`COMPILED`** | Valeur **calculée par le binaire ST compilé** (logique de décision, sorties, états) | `CycleStep`, `WinchM1Cmd.*`, `WinchM2Cmd.*`, `TranslationCmd.*`, `BucketCmd.*`, `Ready`, `Fault.*`, `Lifecycle.*`, `WaitingForOperator`, `ExpectedAxis/Direction`, `OperatorActionId` |
| **`HARNESS_STIMULUS`** | Valeur **injectée par le harnais de test** (entrées de retour / capteurs / positions) — **simulée**, pas mesurée | `M1_CablePosM`, `M2_CablePosM`, `M1/M2_MeasuredSpeedMps`, `KoboldContactFond`, `Translation_At_*`, `Benne_IsOpen/_IsClosed/_RoughlyClosed`, `HomedM1/M2`, `TopPositionSensor`, `WinchSyncError`, `LimitLegalReached` |
| **`CONFIG`** | Constante de configuration fournie au harnais | `SetDepthM`, `SetOffsetM`, `SelTarget`, `CableLimitM1AscentM`, `SpeedMismatchThresholdMps` |
| **`DERIVED`** | Grandeur **dérivée à la génération** (Python, hors JS) pour le rendu — jamais calculée en JS | delta de position entre scans, états discrets déduits des capteurs |

### 1bis.2 · Règles de traçabilité (non négociables)

1. **Chaque champ du JSON porte un attribut `provenance`** : `"provenance": "COMPILED"` |
   `"HARNESS_STIMULUS"` | `"CONFIG"` | `"DERIVED"`.
2. **L'animation affiche la provenance** : chaque télémétrie / HUD indique visuellement
   « 🟢 compilé » vs « 🟡 simulé (harnais) » — l'utilisateur voit d'un coup d'œil ce qui est réel
   et ce qui est mocké.
3. **Aucune valeur `HARNESS_STIMULUS` n'est présentée comme une mesure réelle** : la trace est
   « binaire ST compilé **sous stimuli de harnais** », jamais une dynamique physique réelle.
4. **Le garde-fou AST** vérifie que le JS ne **calcule** aucune valeur : il ne fait que **lire**
   les champs de la trace (toute provenance confondue) et les afficher.
5. **Le contrat T171-A** documente la liste exacte des champs `COMPILED` vs `HARNESS_STIMULUS`
   (source : interface `FB_Cycle.st`), pour qu'aucun lecteur ne statue sur un manque d'information.

### 1bis.3 · Schéma JSON de la trace (avec provenance)

```json
{
  "meta": {
    "generated_by": "generate_trace_cycle.py",
    "source": "WORKING_COPY/FB_Cycle.st (compilé STruCpp)",
    "semantics": "logique de décision du séquenceur sous stimuli de harnais scan-par-scan — PAS une dynamique physique réelle",
    "sha256": "…"
  },
  "scans": [
    {
      "test": "TC-P04-100",
      "scan": 0,
      "t_ns": 0,
      "fields": {
        "CycleStep":            { "value": "X0_PREPARATION", "provenance": "COMPILED" },
        "WinchM1Cmd.ReqStartStop": { "value": false,           "provenance": "COMPILED" },
        "M1_CablePosM":         { "value": 7.0,             "provenance": "HARNESS_STIMULUS" },
        "Benne_IsOpen":         { "value": false,           "provenance": "HARNESS_STIMULUS" }
      }
    }
  ]
}
```

> 🎯 **Objectif :** zéro ambiguïté. L'utilisateur sait toujours **d'où vient chaque valeur** et
> **ce que la trace prouve** (logique de décision compilée) et **ce qu'elle ne prouve pas**
> (dynamique physique réelle, cadence automate).

---

## 2 · Constats d'état actuel (analyse du périmètre)

| Élément | État | Localisation |
|---|---|---|
| Harnais ST de cycle | 7 tests unitaires `TC-P03-001`, `TC-P04-001..013` (partiels) | `RESULTS/G_CYCLE/tests/test_fb_cycle.st` |
| Trace scan-par-scan | Générée en mémoire par `chronogram.py`, injectée dans les rapports `FB_Cycle.html` ; **aucun fichier `trace_semi_auto_cycle.json` dédié** | `scripts/chronogram.py` |
| Animation Canvas | **Moteur JS fictif intégral** (`STATE`/`simStep`/`executeAutoSequence`) | `RESULTS/G_CYCLE/reports/FICHE_SEMI_AUTO_ANIMATION.html` |
| Source de vérité FB | Interface réelle `FB_Cycle` (IN/OUT) | `CODE/G_CYCLE/FB_Cycle.st` |
| Grafcet de référence | `E_CycleStep` X0..X13 + STABILIZING | `DOC/AF/AF_Partie-04_..._v2.3.md` §4.2 |
| Politique git de `reports/` | **`TOOLS/TEST_AUTO_CI/RESULTS/` n'est PAS gitignoré** (le HTML est déjà commité) | `.gitignore` |

**Point de conception clé :** `FB_Cycle` **reçoit en entrée les positions/retours** (`M1_CablePosM`,
`M2_CablePosM`, `Translation_At_*`, `Benne_IsOpen`, `KoboldContactFond`, …) et **émet des commandes**
(`WinchM1Cmd`/`WinchM2Cmd`, `TranslationCmd`, `BucketCmd`) + `CycleStep`. Le harnais alimente donc
les retours réalistes **par scan**, et la trace capture ces retours : l'animation n'a **pas** à
réinventer la physique — elle lit les valeurs captées dans la trace. C'est la base de l'éradication
de la double vérité.

---

## 3 · Architecture de la chaîne cible

```text
FB_Cycle.st (CODE, en lecture seule)
   │  convert_codesys_to_iec.py  (COMPILER_ST2C_STruCpp)
   ▼
.bst IEC + test_fb_cycle.st étendu (TC-P04-100 + TC-P04-101..112 robustesse)
   │  strucpp.exe --test  +  instrument chronogram.py
   ▼
trace scan-par-scan : trace_semi_auto_cycle.json   ◄── NOUVEAU livrable T171-A (+ contrôle cohérence Python)
   │
   ▼
FICHE_SEMI_AUTO_ANIMATION.html (Canvas reader pur)  ◄── T171-B (suppression JS fictif)
   │  window.__traceScan + Play/Pause/Vitesse/Scrub + garde-fou mécanique
   ▼
Audit indépendant Ollama qwen3.8:27b                ◄── T171-CR (contrôle COMPLÉMENTAIRE, non bloquant seul)
```

---

## 4 · Plan détaillé par sous-tâche

### 4.1 T171-A — Harnais ST dynamique + génération de trace (C3)

**Livrables :**
0. **Copie de travail** : créer `TOOLS/TEST_AUTO_CI/WORKING_COPY/` avec les copies de
   `FB_Cycle.st`, `FB_DiveSearch.st`, `FB_ExtractionSequence.st` + types/DUT requis. **Corriger
   dans la copie** les bugs F1 (X11 ouverture), F2 (SampleCount front) et F6 (gater `WaitingResume`).
   **Runner isolé** (pas `registry.yaml`) : compile explicitement `WORKING_COPY/FB_Cycle.st`.
   **Gate de faisabilité** : smoke-test STruCpp de la fermeture de types complète en tête.
1. **Étendre `RESULTS/G_CYCLE/tests/test_fb_cycle.st`** avec le scénario **`TC-P04-100`**
   (parcours nominal X0 → X13) + une série de tests de robustesse **TC-P04-101..112**
   (défauts/reprises — voir §7). Stimuli scan-par-scan réalistes :
   - homme-mort armé (`DeadmanArmed`), manche défléchi (`CycleMotionPermit`), `StartCycle` front ;
   - référencement codeurs (`HomedM1/M2`, `TopPositionSensor`, `HomingRequest`) pour X1 ;
   - sélection cible + `Translation_Done`/`Translation_At_*` pour X2 et X10 ;
   - ouverture/fermeture benne (`Benne_Busy/Done/IsOpen/IsClosed/RoughlyClosed`) pour X3/X6/X11 ;
   - plongée synchrone (`M1_CablePosM`, `M2_CablePosM`, `M1/M2_MeasuredSpeedMps`) pour X4 ;
   - contact fond (`KoboldContactFond` + `CycleMotionPermit`) pour X5 — **pas de `FB_DiveSearch`**
     interne : transition X5 pilotée par l'entrée `KoboldContactFond` (`FB_Cycle.st` L391-401) ;
   - remontée contrôle (X7) → nominale (X8) → égouttage `DrainingTimer` (X9) ;
   - fin de cycle → vérification `SampleCount` sur X13 (X12 = réservé, sauté).
   **Contrainte :** conserver 100 % des tests unitaires existants (TC-P03-001, TC-P04-001..013).
2. **Générer `RESULTS/G_CYCLE/reports/trace_semi_auto_cycle.json`** :
   nouveau script **`scripts/generate_trace_cycle.py`** qui réutilise l'instrumentation de
   `chronogram.py` (import du **module du worktree**, aucune modification de
   `COMPILER_ST2C_STruCpp`), isole la trace du test `TC-P04-100`, **sous-échantillonne les
   champs** aux seuls nécessaires au Canvas (limite la taille HTML), **étiquette chaque champ
   avec sa `provenance`** (`COMPILED` / `HARNESS_STIMULUS` / `CONFIG` / `DERIVED` — cf. §1bis),
   et écrit en JSON autonome `{meta, scans:[{test, scan, t_ns, fields:{…}}]}`.
   **`meta.source = WORKING_COPY/FB_Cycle.st` + `meta.sha256`** (exigence T1).
3. **Contrôle de cohérence mécanique (garde-fou, à la génération, hors JS)** dans
   `generate_trace_cycle.py` : pour chaque commande exigeant un mouvement, vérifier que la
   position captée évolue dans le bon sens entre scans consécutifs. Toute incohérence →
   **rejet à la génération** (jamais toléré ni recréé par l'animation).
4. **Tests négatifs (exigence T3)** : runner isolé sur `CODE/G_CYCLE/FB_Cycle.st` (original) —
   **T8** (X11 ouverture), **F2** (SampleCount), **F6** (reprise auto) doivent **échouer**.
   **Exclus de la suite verte** ; documentés comme preuve que l'original n'est pas corrigé.

**Critères d'acceptation (contrat T171-A, à réviser) :** AC1 traversée X0→X13 sans saut anormal
**sur la copie de travail corrigée** ; AC2 trace JSON reflète `CycleStep` + sorties
(`WinchM1/M2Cmd`, `TranslationCmd`, `BucketCmd`) + retours captés à chaque scan, **avec
`provenance` et `SOURCE_TESTÉE`/`sha256`** ; AC3 contrôle de cohérence Python passé ;
AC4 tests négatifs T8/F2/F6 échouent sur l'original ; AC5 visa orchestrateur sur `git diff`.

### 4.2 T171-B — Raccordement Canvas sur la trace compilée (C2) — **Phase 1 simple**

**Livrables :** réécrire `RESULTS/G_CYCLE/reports/FICHE_SEMI_AUTO_ANIMATION.html` :

1. **Supprimer** `STATE`/`simStep`/`executeAutoSequence`/`updatePhysics` (machine JS fictive).
2. **Charger** la trace (`trace_semi_auto_cycle.json`) — données embarquées dans un `<script>` en
   ligne pour lecture hors serveur (fichier ouvert depuis le disque, pas de CORS).
3. **Exposer `window.__traceScan`** : index courant + accès aux champs du scan courant.
4. **Asservir le Canvas en pur lecteur** : frame N = scan N du JSON ; position = champ capté du
   scan ; **zéro interpolation d'un scan à l'autre**. `CycleStep` pour l'étape et la bannière ;
   commandes (`WinchM1/M2Cmd`, `TranslationCmd`, `BucketCmd`) **uniquement pour le HUD
   d'affichage**, jamais pour le calcul de coordonnée. Axes sans analogique (pont, ouverture %,
   mou de câble) → **états discrets captés** (`Translation_At_*`, `Benne_IsOpen/_IsClosed`).
   **Phase 1 = simple, sans simulation mécanique/dynamique.**
   **Affichage de provenance** : chaque télémétrie/HUD indique « 🟢 compilé » vs « 🟡 simulé
   (harnais) » (cf. §1bis) — l'utilisateur voit d'un coup d'œil ce qui est réel et ce qui est mocké.
5. **Contrôles** : Play, Pause, Vitesse x1/x2/x5, **scrub** au scan voulu (indexé par `scan`,
   **jamais par `t_ns`**), affichage temps-réel des E/S (télémétrie + diagnostic
   `ST_ChainCycleSemiAuto`). Robustesse : trace vide / champs manquants / scrub hors bornes →
   pas de crash ; détection d'incohérence (position qui bouge sans commande) → flag de
   non-conformité, jamais d'interpolation.

> **Phase 2 (future, hors T171)** : brancher le **Simbench de l'automate** pour générer temps de
> réaction et dynamique réels. Non traité ici.

**Critère d'acceptation AC1 (contrat, à réécrire) :** "100 % des **décisions d'état** et des
positions **disponibles/captées** sont asservies au binaire compilé ; les axes sans analogique
sont rendus en états discrets captés ; aucun calcul cinématique en JS."

### 4.3 T171-CR — Audit & Challenge externe (C2, review)

**Livrables :**
1. **Garde-fou mécanique robuste (gate principal)** : nouveau script
   `scripts/guard_animation_no_business_logic.py` — **analyse AST + taint**, pas un grep :
   - parser JS réel (`pyjsparser` Python ou `acorn` via node) ;
   - **sources de confiance** = tableau de trace embarqué + index de scan + constantes ;
   - **sinks** = écritures de position Canvas (`setAttribute('transform'/'d'…)`, `textContent`/
     `innerText` sur `gantryGroup`, `bucketGroup`, `cablePathM1/M2`, `jawLeftGroup`, `bucketGravel`) ;
   - **assertion** : variables libres de chaque sink ⊆ {trace, scanIndex, constantes, refs DOM} ;
   - **rejets bloquants** : `Math.random`, `Date.now`, `performance.now`, `setInterval`/
     `requestAnimationFrame` mutant une position, objet `STATE`, `+=`/`-=` sur position entre
     frames, mutation du tableau de trace ;
   - **couvrir les sinks indirects** (helpers qui écrivent le DOM) pour éviter le contournement
     par indirection ;
   - branché en **gate CI** (pas une étape manuelle).
2. **Audit indépendant** par sous-agent Ollama `qwen3.8:27b` en **complément** (jamais seul gate) :
   absence de décision d'étape/état en JS ; conformité de la cinématique aux sorties/retours de
   `FB_Cycle.st`.

---

## 5 · 🔴 Failles critiques identifiées par le challengeur (à trancher)

| # | Faille | Localisation | Impact T171 | Décision requise |
|---|---|---|---|---|
| **F1** | **X11_OPEN_DUMP incohérent** : `BucketCmd.ReqOpen` évalue `ReqDirection = -1` **après** qu'elle a été forcée à `1` (read-before-write, L.552-559) → ouverture **jamais commandée** → X11 ne peut pas sortir (Benne jamais ouverte). **Cause racine : aucune entrée joystick en `VAR_INPUT`** (`ExpectedDirection` est une sortie) | `FB_Cycle.st` L.552-563 | X0→X13 **infaisable** sans triche | 🔴 **Fix CODE prérequis** (entrée `JoystickY`) ; TC-P04-100 n'exerce pas l'ouverture réelle ; test T8 qui échoue |
| **F2** | **`SampleCount` incrémenté à CHAQUE scan de X13** (pas de cadrage front) → compteur falsifié | `FB_Cycle.st` L.582 | AC « SampleCount sur X13 » non déterministe si >1 scan | ✅ **Corrigé dans la copie de travail** (front, +1 strict) + test d'inflation ; remonté à l'orchestrateur |
| **F3** | **« 100 % cinématique » inatteignable** : pas de champ analogique pour pont M3 (seulement `Translation_At_*` BOOL), ouverture benne %, mou de câble | Interface `FB_Cycle` | AC1 T171-B sur-prometteur | ✅ **Phase 1 simple** : états discrets captés ; AC1 réécrit |
| **F4** | **R6 faux** : `RESULTS/` n'est **pas** gitignoré (HTML déjà tracké) | `.gitignore` | Trace JSON + HTML régénérés polluent le diff worktree | ✅ **Versionnage assumé** (décision utilisateur) : les artefacts sont trackés, le conflit de merge est visible et résolvable |
| **F5** | **Audit LLM seul = contrôle faible** | T171-CR | Certification zéro-logique-JS non fiable | 🔴 **Garde-fou AST robuste** (taint, pas grep) + gate CI ; l'audit devient complémentaire |
| **F6** | **Reprise après bascule de mode AUTOMATIQUE** : `WaitingResume` posé à TRUE (L.215) mais `IF` vide (L.240-243), jamais lu pour couper les commandes → reprise auto du mouvement au retour en semi-auto | `FB_Cycle.st` L.213-216, L.240-243 | **Faille sécurité** (violation AGENTS.md « jamais de redémarrage auto » + AF-04 §4.1 L.137) | 🔴 **Fix CODE prérequis** (gater `WaitingResume`) ; T2 documente l'auto-reprise, ne la normalise pas |

---

## 6 · Risques majeurs (à surveiller)

| # | Risque | Détail | Gravité |
|---|---|---|---|
| R-A | Déterminisme JSON non mécanisé | Trace doit être stable à l'octet pour le diff CI ; `t_ns` ne bouge que si le test appelle `ADVANCE_TIME` → plusieurs scans partagent le même `t_ns` | 🔴 |
| R-B | `t_ns`/temps fictif | L'animation indexe par `scan`, ignore `t_ns` ; sinon axe temporel mort | 🟠 |
| R-C | Défaut tempo en X11 (interaction F1) | Si le harnais traîne > 60 s simulées, `StepMaxTimer` → `cause[4]` → STABILIZING → traversée fausse | 🔴 |
| R-D | Taille HTML | `fields` inclut tous les champs publics du FB × centaines de scans → HTML lourd → **sous-échantillonner** à la génération | 🟠 |
| R-E | Double copie main/worktree | Les éditions vont aux copies du worktree ; `generate_trace_cycle.py` doit importer le `chronogram` du worktree | 🟠 |
| R-F | Portée « scan-par-scan » | Trace valide la **logique de décision**, pas la cadence réelle (timers ne défilent qu'avec `ADVANCE_TIME`) — ne jamais présenter comme « temps réel » | 🟠 |

---

## 7 · 🧪 Tests de robustesse à ajouter au harnais (TC-P04-101..112)

| # | Scénario | Étape cible | Preuve |
|---|---|---|---|
| T1 | `WinchSyncError` mi-cycle → STABILIZING → cause + Reset + Start → reprise → X13 | X4 | Repli + reprise complète |
| T2 | Bascule MAINT mi-plongée → retour → `WaitingResume` → **StartCycle exigé** | X4 | `PausedState`/`WaitingResume` |
| T3 | Relâchement manche en **chaque** étape de mouvement (X1/X4/X5/X6/X7/X8/X11) | tous | `ReqStartStop=FALSE` + étape conservée |
| T4 | Capteur Kobold jamais de front → `StepMaxTimer` → `cause[4]` | X4 | Tempo max anti-blocage |
| T5 | `LimitLegalReached` en X4 → `cause[0]` | X4 | Cause L.163-165 |
| T6 | `HeartbeatIhmOk` perdu → `cause[3]` | X5 | Cause L.175-177 |
| T7 | `AbortCycle` en cours → X0, `WaitingResume=FALSE` | X4 | Chemin L.259-263 |
| T8 | **X11 ouverture réelle (expose F1)** | X11 | **Doit échouer** sur le code actuel |
| T9 | **SampleCount +1 strict (expose F2)** | X13 | **Doit échouer** sur multi-scan |
| T10 | Écart vitesse confirmé en X7 → `cause[2]` | X7 | `SpeedMismatchConfirmed` |
| T11 | Rebouchage : `StartEdge` en X13 → X0 | X13 | L.584-587 |
| T12 | `Benne_IsRoughlyClosed` vs `Benne_IsClosed` en X6 (tolérance matière) | X6 | L.444 |

---

## 8 · Décisions à trancher (recommandation + alternative)

| # | Point | ✅ Recommandé | 🔀 Alternative |
|---|---|---|---|
| D1 | F1 X11 | Corriger `BucketCmd.ReqOpen`/`ReqStartStop` dans `CODE/` (re-scoper) puis tester la vraie ouverture | Forçage `Benne_IsOpen` MAIS avec **test dédié qui échoue** (révèle le bug, ne le masque pas) |
| D2 | F2 SampleCount | Corriger `FB_Cycle` (front, +1 strict) + test d'inflation qui échoue | TC-P04-100 force X13 **mono-scan** + contournement documenté |
| D3 | F3 axes sans analogique | Raboter l'animation : état discret pont/benne/mou ; suppression interpolation JS | Réécrire AC1 « décisions d'état + positions disponibles captées », rendu non-continu assumé |
| D4 | R-A determinisme | `generate_trace_cycle.py` re-génère et **compare à l'octet** (fail si dérive) + **SHA-256 croisé** gelé dans le contrat + `ADVANCE_TIME` obligatoire entre scans | Geler le SHA-256 de la trace dans le contrat (adopté) |
| D5 | R-B t_ns | Animation indexée par `scan` uniquement | Garder `t_display_ms` (`_apply_realistic_time`) comme seul axe de temps affiché |
| D6 | F4 gitignore | **Versionnage assumé** (décision utilisateur) : trace JSON + HTML régénérés sont trackés ; conflit de merge visible et résolvable | Règle `.gitignore` ciblée (écartée) |
| D7 | F5 certification | **Garde-fou AST robuste** (taint, pas grep) + gate CI ; T171-CR complémentaire | Audit LLM en gate humain non bloquant |

---

## 9 · Plan de validation

1. **Gate de faisabilité** : smoke-test STruCpp de la **fermeture de types complète** de
   `WORKING_COPY/` (runner isolé) **avant** d'écrire TC-P04-100.
2. Trace JSON fraîche produite par `TOOLS/TEST_AUTO_CI/anim_bench/generate_trace_cycle.py` → produit `trace_semi_auto_cycle.json`
   + contrôle de cohérence + **comparaison SHA-256** (fail si dérive) + `SOURCE_TESTÉE`/`sha256`.
3. `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_Cycle` (runner isolé sur `WORKING_COPY/`)
   → tous les tests PASS (unitaires + TC-P04-100 + robustesse).
4. **Tests négatifs** (runner isolé sur `CODE/G_CYCLE/FB_Cycle.st`) : T8/F2/F6 **échouent** —
   exclus de la suite verte.
5. Contrôle sémantique de la séquence `CycleStep` dans le JSON (X0→X13 ordonné, X11→X13 sans X12).
6. Ouverture de `FICHE_SEMI_AUTO_ANIMATION.html` : scrub/lecture conforme à la trace + affichage
   de provenance.
7. **Garde-fou AST** `guard_animation_no_business_logic.py` (gate CI).
8. Bandeau de restitution obligatoire (`BUNDLE EXPORTÉ` / `Gates` / liaison) — voir AGENTS.md.
9. Audit Ollama T171-CR (complémentaire).

---

## 10 · Hors périmètre (interdit)

- `CODE/**`, `PRJ_CODESYS/**` — **aucune modification directe**. Les défauts F1/F2 sont corrigés
  **dans la copie de travail** `TOOLS/TEST_AUTO_CI/WORKING_COPY/` (périmètre `TOOLS/`), puis
  **remontés** à l'orchestrateur pour réintégration `CODE/` ultérieure.
- `TOOLS/COMPILER_ST2C_STruCpp/**` — aucune modification (consommé en lecture seule).
- Pas de push direct ; commit uniquement après validation humaine (`wip:` puis `test:`).

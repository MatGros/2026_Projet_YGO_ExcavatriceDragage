# BRIEF v2 — T371 « Faux vert de `ST_MotionChecklist` » (transmission agent)

> ⚠️ **Version corrigée** de `DOC/WFLOW/CONTRACTS/BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST.md` (v1, 87 l.,
> **jamais transmis**). Le v1 a été **challengé avant transmission** par l'orchestrateur :
> `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T371_FAUX_VERT_20260921.md`.
> **Sa borne §3 interdisait le seul correctif nécessaire** et reposait sur une prémisse fausse
> (§2 du challenge). Le v1 **n'est ni déplacé ni supprimé** (décision humaine) — la correction vit ici.
>
> ✅ **Le préambule obligatoire est COLLÉ EN TÊTE de ce prompt (§0)** — tu n'as rien à aller chercher.
> ✅ **Mission C4** : contrat obligatoire avant toute écriture, arrêt humain, `git diff` relu par un
> orchestrateur, **aucun commit**.
> ✅ **Ancrage** : HEAD 2026-09-21 · `CODE/` **propre** à la prise (à re-vérifier, jamais supposé).

---

# §0 — PRÉAMBULE OBLIGATOIRE (collé en tête — texte intégral)

<!-- source : TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md -->

# Préambule obligatoire — tout sous-agent qui touche au code

> 📌 **À coller en tête de CHAQUE tâche déléguée** (fork Claude Code worker/reviewer, Codex,
> antigravity). Sans lui, le sous-agent démarre sans les règles du projet et redécouvre
> les mêmes bugs — c'est ce qui s'est produit sur `PRG_10_Outputs_LD` (REX 2026-07-29).
> Le préambule est court **exprès** : il pointe, il ne recopie pas.

---

## Contexte projet & Persona

Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué **manuellement** par l'utilisateur dans CODESYS. Sécurité machine réelle : une erreur de câblage logique a des conséquences physiques.

### 🎭 Persona : Expert Senior Automatisme, Sécurité Machine & CI/CD
Tu es un **Expert Senior en Automatisme Industriel (CODESYS 3.5, Safety, IHM, POO/FB, normes)**.
- 🛑 **Validation préalable** : Tu valides toujours les approches et leur pertinence avant de proposer ou d'écrire du code.
- ⚡ **Style TDAH-Friendly & Direct** : Réponses courtes, synthétiques, visuelles (emojis, tableaux courts, diffs clairs), zéro blabla inutile ni détails superflus. Réponds toujours en français.
- 🛡️ **Challengeur constructif & Esprit critique (Anti-Yes-Man)** : Sois critique, pas complaisant. Ne valide jamais les affirmations ou choix utilisateur par défaut. Vérifie faits, code et sources réelles. Challenge les mauvaises idées, signale immédiatement les risques, effets de bord, incohérences et l'effort estimé, en proposant des alternatives plus robustes.
- 🔬 **Rigueur méthodologique** : Distingue clairement faits avérés, hypothèses et incertitudes ; ne déduis rien sans preuve. Ne fonce pas dans l'implémentation : vérifie brièvement la pertinence et les conséquences de chaque action.
- 🔒 **Validation explicite stricte** :
  - **JAMAIS de commit sans validation humaine explicite.**
  - **Toute modification de fichier nécessite une validation préalable**, sauf poursuite directe d'une tâche déjà explicitement validée (auquel cas, informer avant modification).
  - Avant de coder, consulte obligatoirement les standards du projet (`NAMING_CONVENTION.md`, `AF_Partie*.md`) et demande confirmation explicite.

---

## 📝 Contrat de tâche — ta seule référence de succès

> REX 2026-07-29 : sur 53 tâches déléguées, les critères d'acceptation étaient 3 phrases
> génériques. Un agent rendait donc un rapport « conforme » à **rien**.

Le contrat de tâche fourni avec cette mission porte les **critères testables**. Ils remplacent
tout critère générique d'acceptation. Ta restitution se juge **contre eux**, pas contre
« j'ai bien travaillé ».

- Un critère sans moyen de vérification n'est pas un critère → **le signaler, ne pas deviner**.
- Si aucun contrat n'est fourni sur une tâche de criticité ≥ C2 → **demander**, ne pas commencer.
- Si le scope touche `CODE/MAIN/`, le contrat doit prouver explicitement : **nom de fichier = nom de POU** et **suffixe de langage = langage généré dans le bundle**. Sans ces deux critères, demander une correction du contrat avant d'écrire.

## 🤝 Responsabilité du principal et usage des agents secondaires

- Si tu es l'agent principal du lot, tu peux solliciter des agents à contexte frais pour challenger
  le besoin, le plan, les tests ou le diff. Tu implémentes toi-même le lot qui t'est confié et tu
  restes garant de la restitution, de la qualité et des preuves.
- Un agent secondaire ne remplace jamais ta lecture du code réel ni ta vérification du diff.
- Un seul agent écrit dans un même périmètre de fichiers ; les challengers/reviewers sont
  read-only et rendent un verdict sourcé.
- Toute anomalie hors scope est signalée à l'orchestrateur ; elle n'est pas corrigée spontanément.
- Pour une mission C3/C4, utiliser le cadrage compact de
  `TOOLS/AGENT_WORKFLOW/skills/orchestrator/references/delegation_c3_c4.md`.

## 🧱 Structure des programmes — non négociable

- Ne jamais créer ou renommer un POU dont le nom diffère du nom de son fichier source.
- Ne jamais apposer `_CFC`, `_LD` ou un autre suffixe de langage si le générateur ne produit pas le langage correspondant dans le bundle PLCopenXML.
- Une exemption de gate ou une allowlist n'est jamais une décision d'agent : remonter le fait, son usage réel et sa condition de retrait à l'orchestrateur. Seul l'orchestrateur peut la valider et la tracer.

## 📊 Checkpoint de progression — obligatoire

> Pourquoi : le suivi d'état en direct exige que chaque agent journalise ses étapes.
> Un agent LLM ne bat pas un heartbeat 5s natif (il travaille par tours de 10-60s+) :
> on journalise donc un **checkpoint à chaque étape**, cible maximale ~10s sans log.

- À **chaque étape franchie** (début, lecture specs, avant/pendant/après écriture,
  après chaque gate, attente validation, fin), append une ligne dans le fichier
  partagé de ta session :
  ```bash
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <SESSION> <ETAPE> <etat> --agent <nom> --msg "<resume>"
  ```
  - `<SESSION>` : id unique de ta mission (ex. `task-AF10`, ou horodatage).
  - `<etat>` : `en_cours | ok | fail | attente_validation | termine`.
  - `<nom>` (`--agent`) : code court normalisé obligatoire (`CC01`/`CC02`, `AGY01`/`AGY02`, `CDX01`/`CDX02`, `DSH01`/`DSH02`, `OPC01`), zéro libellé long.
- Les nouveaux fichiers vivent dans `TOOLS/AGENT_WORKFLOW/status/` (local et ignoré).
  Des fichiers historiques peuvent encore être suivis : ne pas les supprimer ni les désindexer,
  leur régularisation relève de la phase 4 T279.
- Le suivi en direct se fait via :
  ```bash
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch            # tous
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch <SESSION>  # une session
  ```
- **Cible** : ne pas dépasser ~10s sans un log d'étape, autant que les tours le
  permettent (un outil long peut déroger — le signaler dans le log suivant).
- Ne journalise jamais ailleurs que dans cette zone dédiée. Toute preuve durable va dans le
  sous-dossier métier de `DOC/WFLOW/`, pas dans un scratch.

## 🚨 Devoir d'alerte — non négociable

Tout problème constaté **en cours de route** (incohérence de spec, bug préexistant, risque hors
scope, doute de sécurité) remonte **immédiatement** à l'orchestrateur — pas à la fin, jamais
silencieusement, jamais enterré dans un paragraphe de conclusion.

**Signaler n'est pas élargir le périmètre.** On attend le signalement, pas la correction
spontanée. Continuer en silence sur un doute est la faute ; le signaler ne l'est jamais.

## 🧭 Traçabilité d'impact — avant de coder (non négociable)

Avant de modifier une fonction, **tracer l'impact complet** : qui **produit** la donnée, qui la
**route**, qui la **consomme**. Vérifier que la modification atteint bien le **consommateur
final** — ne jamais coder une fonction isolément sans vérifier le câblage de bout en bout.
Exemple vécu : le correctif `FB_Sim_Safety` (chaîne fermée par défaut) ne « passait » pas car la
valeur simulée n'atteignait pas l'entrée `EmergencyChainClosed` du FB AU (le routage simulation
exigeait `SimSafetyActive`). Règle complète : `DOC/STDS/CODE_QUALITY_STANDARDS.md §3ter`.

## À lire avant d'écrire (dans cet ordre, aucune exception)

1. `AGENTS.md` — point d'entrée, guardrails, persona et cas d'arrêt
2. `DOC/STDS/CODE_QUALITY_STANDARDS.md` — déclaration, liaison, POO, non-régression
3. `DOC/STDS/NAMING_CONVENTION.md` — nommage
4. `DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md` — contrats FB, DUT et CFC (si création/modif de FB)
5. La spec métier concernée (`DOC/AF_Partie-08` à `-14`)

`ARCHIVES/` n'est **jamais** une source active.

## Cas d'arrêt — ne pas produire de code, demander

- Spec incomplète, ambiguë, ou contredite par la doc
- Nommage impossible à décider sans hypothèse
- Interface FB incomplète (profils `AF_Partie-03 §1bis`)
- `Reset` pas sur front · redémarrage automatique après défaut
- `SafeStop`/`StartStop` sur un FB qui n'est pas un FB de mouvement
- `CoupeEnable` ou `FB_Watchdog` applicatif réintroduits

## Vérification mécanique — standard de test (ni trop, ni rien)

> 🎯 **Standard de test** : un minimum à **chaque** livraison, la suite complète à la livraison
> d'un **lot**. Ni sur-tester (suite complète à chaque micro-édition) ni sous-tester (livrer sans
> le minimum).

**① Minimum obligatoire — à CHAQUE livraison de code** (rapide, ~secondes) :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .   # bundle frais
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <tous-les-fichiers-CODE-st-touches>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report # liaison bloquante (sur le bundle frais)
```
Le diff bundle `CODE_XML/CODE_DiffBundle.xml` est **systématique** : il complète le bundle
complet, ne le remplace jamais. Le restituer avec la liste des objets inclus ; ne jamais proposer
un import POU par POU. Règle canonique : `AGENTS.md` § « Diff bundle ».
⛔ **Jamais livrer sans ce minimum** : un bundle généré ou des tests Python verts **ne prouvent
pas** qu'une fonction est reliée. Seul `G200_check_linkage.py` le prouve. Le bloc
`Auto-vérification liaison` qu'il produit doit figurer dans la restitution.

**② Suite complète — à la livraison d'un LOT** (plusieurs fonctions, fin de lot) :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py   # ou --palier C (GUIDE_GATES_ET_TESTS §2)
```

**③ Pendant l'édition (micro-éditions)** : ne **pas** lancer la suite complète. Choisir le palier
adapté (`--palier A` bloc isolé, `--palier B` dès qu'un lien apparaît) — `GUIDE_GATES_ET_TESTS §2`.

## Format de restitution attendu

```text
Auto-vérification liaison (G200_check_linkage.py) — PASS|FAIL
  OK  <instance> : <FB> — déclarée <fichier>:<ligne> · appelée :<ligne>
  ...
Gates : structure / style / liaison / persistance / bundle / pytest = PASS|FAIL
Diff bundle : `CODE_XML/CODE_DiffBundle.xml` — objets : <liste>
Fichiers modifiés : ...
Hors scope constaté (devoir d'alerte) : ...
```

## Interdits absolus pour un sous-agent

- Commit, push, reset, rebase — **jamais**, la validation est humaine
- Modifier `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export`
- Créer des scripts ou fichiers temporaires jetables (`_tmp_*.py`, `tmp.sh`) ou bricoler des écritures via Heredoc shell (`cat << EOF`) : utiliser exclusivement les outils d'édition natifs (`view_file`, `replace_file_content`, `write_to_file`).
- Créer un dossier scratch `.tmp_*`, `.dsh_tmp`, `tmp`, `.tmpsandbox`, `scratch` ou
  `CODE_XML.freshness` à la racine, ou rediriger `TEMP`/`TMP` vers la racine. Un runner peut
  seulement utiliser le temp système hors dépôt ou son scratch autorisé par
  `STRUCTURE_AND_CLEANUP.md`. Avant et après tout test/gate : exécuter `git status --short`
  et signaler tout chemin hors table ; ne jamais l'ignorer pour le masquer.
- **Rediriger une sortie shell (`>`, `>>`) vers `/tmp/...` ou tout chemin hors du répertoire de
  travail** : le sandbox bloque systématiquement ces écritures/lectures (garde-fou
  `blockReadsOutsideWorkingDirectories`) et déclenche une validation humaine évitable. Utiliser
  le scratchpad de session fourni (dans le repo ou le dossier scratch autorisé de l'agent), jamais
  `/tmp` en dur.
- **Chaîner plusieurs commandes `awk`/`sed`/`grep` avec `&&`, `;` ou plusieurs invocations dans
  une seule commande Bash** (ex. `cd ... && awk '...' f1; echo ---; awk '...' f2`) : le sandbox ne
  peut pas analyser statiquement quels fichiers seront lus et redemande une validation humaine à
  chaque fois, même pour une lecture triviale dans le repo. Utiliser l'outil `Read` natif avec
  `offset`/`limit`, ou `Grep`, pour extraire une plage de lignes d'un fichier connu — c'est plus
  rapide et ne déclenche aucun prompt. Réserver `awk` en Bash aux cas où aucun outil natif ne
  convient, et **une seule invocation par commande Bash**.
- Supprimer, déplacer ou désindexer automatiquement un artefact, même temporaire : l'outil doit
  seulement le détecter et signaler son chemin ; le nettoyage est une action humaine explicite.
- Élargir le scope au-delà de la tâche : signaler, ne pas décider
- Annoncer « terminé » sans les preuves ci-dessus

---

## Rôle du reviewer (revue read-only)

Vérifier **dans cet ordre** — l'intégration structurelle AVANT la logique métier, car c'est
l'inversion inverse qui a laissé passer le bug :

1. Liaison : instances déclarées/appelées au bon endroit, aucune orpheline, tâche cohérente
2. Contrat FB et nommage
3. Encapsulation : producteur unique, internes non traversés, pas de GVL-canal-caché
4. Logique métier et sécurité (états, temporisations, fronts)
5. Tests présents et exécutés

Verdict : `BLOCK` / `MAJOR` / `MINOR` / `PASS`, avec fichier:ligne et preuve. Aucune édition.

---

# §1 — OBJECTIF

Rendre le **diagnostic de mouvement** (`MotionM1` / `MotionM2` / `MotionM3` dans
`GVL_Troubleshooting`) **fidèle au refus réel de la barrière finale** : plus aucun `Step8` ni
`AllConditionsMet` vert alors que la barrière refuse effectivement le mouvement.

**Résultat utilisateur attendu** : un technicien qui ouvre l'outil de diagnostic pendant un
blocage en maintenance lit la **cause réelle** (état + raison de la barrière), au lieu d'un
« tout est vert, les relais doivent coller » faux.

**Ce n'est PAS** un lot de conduite ni de sécurité : **aucune ligne de logique de barrière n'est
touchée** (§2).

---

# §2 — PÉRIMÈTRE / INTERDITS

## 2.1 Le point dur corrigé par rapport au brief v1 — à lire avant tout

Le v1 demandait d'**ajouter des `VAR_OUTPUT`** à `FB_WinchOutputInterlock.st`. **C'est inutile et
faux** : les sorties existent **déjà**, sont **déjà routées**, et le faux vert vient d'une
**consommation tronquée**. Preuves (re-vérifie-les toi-même, ne me crois pas) :

| Fait | Preuve |
|---|---|
| `Reason` / `State` / `StateAtError` / `Fault` **déjà en `VAR_OUTPUT`** | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:53-56` |
| **Déjà routés** vers `ST_WinchState` | `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st:112-115` (M1) · `:179-182` (M2) · `CODE/M_MAIN/PRG_05_Translation.st:756` (M3) |
| Le diagnostic **ne lit que le bit défaut** | `CODE/J_SUPERVISION/FB_TroubleshootingView.st:577` (M1) · `:609` (M2) · `:644` (M3) |
| `Fault.Error` n'est armé que par **une seule cause** (timeout frein) | `FB_WinchOutputInterlock.st:516-519` → `:528-532` |
| Le **même** FB publie déjà la vérité ailleurs | `FB_TroubleshootingView.st:222-223` · `:301-302` · `:417-418` (`Control_400.Idx405/406`) |

## 2.2 Les 4 modes de refus à faux vert — c'est TOI qui les reproduis en CI

| # | Site `FB_WinchOutputInterlock.st` | Condition | `State` | `Reason` | `Fault.Error` | `Step8` actuel |
|---|---|---|---|---|---|---|
| **F1** | `:357-363` | `RestartInhibit` | `FAULT` | `RESTART_INHIBITED` | FALSE | 🟢 **TRUE (faux)** |
| **F2** | `:364-373` | `ContactorStuckLatched` | `FAULT` | `SENSE_DROP_TIMEOUT` | FALSE | 🟢 **TRUE (faux)** |
| **F3** | `:393-404` | `SafeStop OR PermitFinalBlocked` | **`READY`** | `NONE` | FALSE | 🟢 **TRUE (faux)** |
| **F4** | `:424-429` | `RestartRequired OR DeadTimePending` | `WAIT_RESTART_DELAY` | `NONE` | FALSE | 🟢 **TRUE (faux)** |

⚠️ **F4 impose de lire `State` ET `Reason`** : `Reason` y reste `NONE`. Un correctif qui ne lit que
`Reason` raterait F4 et F3.

## 2.3 Fichiers autorisés en écriture

| Fichier | Autorisé |
|---|---|
| `CODE/J_SUPERVISION/FB_TroubleshootingView.st` | ✅ **UNIQUEMENT** les 3 affectations `Step8_OutputInterlockOk` (`:577`, `:609`, `:644`) et leurs 2 champs de lecture ajoutés |
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st` | ✅ ajout de champs **de lecture** (`Step8_InterlockState`, `Step8_InterlockReason`) |
| `TOOLS/TEST_AUTO_CI/RESULTS/J_SUPERVISION/tests/test_fb_troubleshootingview.st` | ✅ tests CI (fichier existant, harnais déjà en place) |
| `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T371_*.yaml` | ✅ contrat C4, **à écrire AVANT toute ligne de code** |
| `DOC/WFLOW/CONTRACTS/BRIEF_T371_*` (v1 conservé), `DOC/WFLOW/AUDITS/DESIGN/`, `DOC/WFLOW/TASKS.yaml` (entrée T371 seule), `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml`, `TASK_LOCKS.json` (ton verrou), `TOOLS/AGENT_WORKFLOW/status/`, `CODE_XML/` | ✅ |
| Fiche AF concernée si la sémantique publiée change | ✅ **signalement préalable**, pas d'écriture spontanée |

## 2.4 INTERDITS ABSOLUS

- ⛔ **`CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` : ZÉRO LIGNE.** Pas une ligne, pas un
  commentaire, pas un `VAR_OUTPUT`. `git diff -- CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st`
  doit rester **vide** à la restitution : c'est ta **preuve mécanique** que les 3 causes et la
  logique de barrière sont intactes.
  *(Si tu penses qu'une sortie manque vraiment : **remonte-le**, ne l'ajoute pas.)*
- ⛔ Toute modification de **logique de barrière / interlock / sécurité**, de quelque nature que ce soit.
- ⛔ `FB_WinchStateProjection.st`, `PRG_04_Treuils_Benne.st` (verrou vif **T364/AGY01** + T291-B),
  `PRG_02`, `PRG_03`, `PRG_06_Outputs.st`, `FB_Winch.st`, `FB_Safety_Winch.st`.
- ⛔ **Toute ligne de CONDUITE consommant `State`/`Reason`** : ces champs sont lus en `N-1`
  (`FB_WinchStateProjection` est appelé en `PRG_04:1688-1696` et lit l'instance `PRG_06`)
  → **usage diagnostic uniquement**, jamais une autorisation de mouvement.
- ⛔ Renommer, supprimer ou réaffecter `Step8_OutputInterlockOk` (rétro-compatibilité IHM).
- ⛔ `Device.export`, `PRJ_CODESYS/**`, exempting/allowlist de gate, tout scratch racine.
- ⛔ **AUCUN COMMIT** sans accord explicite **distinct** du GO.
- ⛔ Élargir aux axes/symptômes T224 / T370 (sérialisation exigée).

---

# §3 — PHASES ET POINTS D'ARRÊT

1. **Lire** : contrat C4 à écrire, `AGENTS.md`, `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md`,
   `AF_Partie-03 §3`, `AF_Partie-14` (troubleshooting), le challenge
   `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T371_FAUX_VERT_20260921.md`, puis **le code réel** :
   `FB_WinchOutputInterlock.st` (548 l.) **en entier**, `FB_TroubleshootingView.st:563-659`,
   `ST_MotionChecklist.st`, `FB_WinchStateProjection.st:100-182`.
2. **Vérifier les collisions** : `DOC/WFLOW/TASK_LOCKS.json` (verrou T371 **à poser**, acteur =
   ton tag réel, vérifié libre **avant** la prise ; `edit_flags` vide attendu) + `git status --short`.
3. **Challenge** : confirme ou réfute **par preuve** les 4 modes F1-F4, **re-cherche** une sortie
   déjà existante (le v1 avait raté `ST_WinchState.FinalInterlockState/FinalInterlockReason:38-39`)
   et **signale toute dépendance à l'encapsulation** que l'exposition casserait.
4. **Écrire le contrat C4** `TASK_CONTRACT_T371_FAUX_VERT_MOTIONCHECKLIST.yaml`
   (gabarit `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`) →
   `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <contrat>` **PASS 0 erreur**.
5. 🛑 **ARRÊT VALIDATION HUMAINE** : présente le plan + les AC, **attends le GO**. C'est une tâche
   **C4** : pas de GO = pas de code.
6. **Reproduire le ROUGE AVANT correctif** dans `test_fb_troubleshootingview.st` : un cas où la
   barrière refuse (`Reason` ≠ `NONE` **ou** `State` ≠ `READY`, `Fault.Error = FALSE`) et où
   `Step8` = TRUE / `AllConditionsMet` = TRUE. **Lance-le, colle la sortie rouge.** Sans ce rouge,
   le correctif est invérifiable.
7. **Corriger** (après GO) : `Step8` lit `FinalInterlockState` + `FinalInterlockReason` (+ les 2
   champs de lecture ajoutés au DUT). Repasses **VERT** avec le même cas.
8. **Non-régression des 3 causes** (`RESTART_INHIBITED` `:362`, `SENSE_DROP_TIMEOUT` `:372`,
   `BRAKE_COMMAND_NOT_CONFIRMED` `:508`, + la remise à `NONE` `:210`) : preuve **avant/après
   identique** sur `State`, `Reason`, `ErrorId`, `Fault.Error`, `RelayFwd/Rev`, `BrakeCmd`,
   `AuthorizedStep` — plus `git diff` **vide** sur `FB_WinchOutputInterlock.st`.
9. **Garde-fou** (règle `fix:` + `guard:`) : gate `G5xx` détectant toute affectation d'un
   `Step8_*OutputInterlock*` dérivée du seul `FinalInterlockError` + ligne `PLANS` de
   `run_all_gates.py`, avec `--selftest`.
10. **Revue indépendante** par un agent **différent de toi**, read-only, verdict
    `BLOCK/MAJOR/MINOR/PASS` sourcé.
11. **Corriger les BLOCK/MAJOR**, puis bundle + diff bundle + G200 + gates palier C.

---

# §4 — CRITÈRES TESTABLES (AC)

| # | Critère | `verified_by` |
|---|---|---|
| **AC1** | Les 4 modes F1-F4 sont reproduits en CI, avec `Step8` = TRUE **avant** correctif (preuve rouge) | sortie du test CI, avant/après |
| **AC2** | Après correctif, aucun des 4 modes ne produit `Step8 = TRUE` ni `AllConditionsMet = TRUE` (preuve verte) | idem |
| **AC3** | `FB_WinchOutputInterlock.st` : **`git diff` vide**, `VAR_OUTPUT` inchangé (53-56), 3 causes inchangées | `git diff --stat -- CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` = vide |
| **AC4** | Non-régression des 3 causes + reset `NONE` : `State/Reason/ErrorId/Fault/RelayFwd/RelayRev/BrakeCmd/AuthorizedStep` **identiques** avant/après | test CI avant/après, diff des valeurs |
| **AC5** | Les 3 axes M1/M2/M3 traités (`:577`, `:609`, `:644`) | grep + diff |
| **AC6** | `Step8_OutputInterlockOk` **conservé** (aucun renommage) ; seuls 2 champs de lecture ajoutés au DUT | diff `ST_MotionChecklist.st` |
| **AC7** | Aucune ligne de **conduite** ne consomme les nouveaux champs (usage diagnostic seul) — traçabilité producteur→routeur→consommateur nommée dans la restitution | `CODE_QUALITY_STANDARDS.md §3ter`, grep |
| **AC8** | Contrat C4 écrit **avant** code, `check_task_contract.py` **PASS 0 erreur** | sortie du script |
| **AC9** | Garde-fou `G5xx` + `--selftest` **PASS**, branché dans `PLANS` de `run_all_gates.py` | sortie du gate |
| **AC10** | Bundle frais + diff bundle + `G200 --report` **PASS 0 erreur** + palier C sans **nouvel** échec | blocs de sortie collés |
| **AC11** | Aucun commit ; `git status --short` sans chemin hors table | `git status --short` collé |
| **AC12** | Latence `N-1` documentée dans le livrable (et **pas** présentée comme une mesure temps réel) | livrable |

---

# §5 — SOUS-AGENTS AUTORISÉS

- **Challenger** read-only (contexte frais) : le cadrage et les AC, **avant** le GO.
- **Reviewer** read-only : le diff après implémentation, verdict sourcé.
- **Un seul écrivain** dans le périmètre du §2.3 : toi.
- Tu restes **seul responsable** du code, des tests, des preuves et du rapport final.

---

# §6 — PREUVES ATTENDUES

1. **Rouge avant** (sortie CI brute, pas un résumé).
2. **Vert après** sur les 4 modes F1-F4.
3. **Non-régression** des 3 causes + `NONE` (valeurs avant/après).
4. `git diff` **vide** sur `FB_WinchOutputInterlock.st` (**preuve de borne §2.4**).
5. `git diff` réel des fichiers touchés.
6. Bundle complet + **diff bundle** (objets listés) + **bloc `Auto-vérification liaison` G200** collé.
7. Gates palier C, avec le compte d'échecs **preexistants** distingué des échecs introduits.
8. Contrat `TASK_CONTRACT_T371_*.yaml` + sortie `check_task_contract.py`.
9. **Hors scope constaté** (devoir d'alerte).

---

# §7 — RESPONSABILITÉ DU PRINCIPAL

- Tu **vérifies** le challenge `CHALLENGE_T371_FAUX_VERT_20260921.md` — tu ne le recopies pas comme
  preuve. S'il est faux quelque part, **dis-le** : le challenge est un devoir d'alerte, pas un oracle.
- Tu ne recopies **jamais** une affirmation d'agent comme preuve : `fichier:ligne` ou rien.
- Tu **remontes** immédiatement à l'orchestrateur : une sortie manquante non anticipée, un refus
  que F1-F4 ne couvrent pas, une dépendance d'encapsulation, un élargissement nécessaire du scope.

---

# §8 — FORMAT DE RESTITUTION

```text
VERDICT : <1 ligne>
Fichiers modifiés : ...
Preuve ROUGE (avant) : <sortie CI>
Preuve VERTE (après) : <sortie CI>
Non-régression 3 causes (avant == après) : <tableau de valeurs>
git diff FB_WinchOutputInterlock.st : VIDE  <-- borne §2.4
AC1..AC12 : <un par un, PASS/FAIL + preuve>
Auto-vérification liaison (G200) : PASS|FAIL
Gates palier C : <compte, échecs preexistants distingués>
Diff bundle : CODE_XML/CODE_DiffBundle.xml — objets : <liste>
Hors scope constaté : ...
Aucun commit : confirmé
```

---

*Fin du brief v2 T371 — corrigé après challenge pré-transmission. v1 conservé tel quel.*

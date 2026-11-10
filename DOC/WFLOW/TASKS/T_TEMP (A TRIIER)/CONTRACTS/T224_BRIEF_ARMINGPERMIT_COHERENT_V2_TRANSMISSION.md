# BRIEF v2 — T224 « ArmingPermit cohérent avec la disponibilité réelle » (transmission agent)

> ⚠️ **Version corrigée** de `BRIEF_T224_ARMINGPERMIT_COHERENT.md` (v1). Le v1 contient
> **3 affirmations fausses et 1 risque majeur**, prouvés au §2 et §4 — **transmettez ce fichier-ci**,
> pas le v1. Le v1 n'est ni déplacé ni supprimé (décision humaine).
>
> Rédigé par l'orchestrateur **DSH01** — 2026-09-21T10:54+02:00.
> Statut : **arrêt en attente d'arbitrage humain (§5 Étape B)** avant toute écriture de code.
>
> 🔄 **ADDENDUM 2026-09-21T12:30 — AJOUT SEUL, le corps ci-dessous reste inchangé.** Cinq faits
> **prouvés depuis la rédaction** corrigent des éléments de ce brief :
> 1. **§4 / contrainte A6 — le contrat T228 n'est PAS utilisable comme référence en l'état** : ses
>    deux décisions de fond sont **périmées**. La **l.89** (bypass MES groupe) a été implémentée
>    par `44187804` (`ArmM1MoveInhibited := PRG_06_Outputs.Data.M1MovementInhibited AND NOT
>    GVL_IHM.M1TreuilRetenue.Bypass.Global`) puis **retirée par `b96a8988`** — l'affectation perd
>    le terme bypass (vérifié sur les deux révisions). La **l.87** décrit l'agrégat de `e2f5b9dc`,
>    abandonné avant la fin du lot.
> 2. **G3 = DEUX causes indépendantes**, pas une : (A) chemin rapide `TonNoMoveContactor` sur DI
>    figé — commit **`18edd8a5`**, qui n'est **PAS un commit T228** (aucun commit T228 ne touche
>    `FB_Safety_Winch.st` : vérifié `git log 7e46d6d7..263fae18 -- …/FB_Safety_Winch.st`) ;
>    (B) agrégat contenant `RestartRequired`/`DeadTimePending` **bruts**, or `RestartRequired` est
>    **ré-armé à CHAQUE scan au repos** (`FB_WinchOutputInterlock.st:221-223`) ⇒ `ArmingPermit`
>    bloqué à `FALSE` à l'arrêt. Le commentaire de la révision finale `72ce5eec` l'écrit lui-même.
>    ➡️ **Corriger le DI ne suffit pas ; corriger l'agrégat ne suffit pas.**
> 3. **La fenêtre annulée compte 11 commits** (`7e46d6d7..263fae18`), dont **4 hors T228**
>    (`b9e9402a` T225, `18edd8a5`, `2a1b3c58`, `5a531d38`) plus le revert ⇒ **aucun retour arrière
>    chirurgical n'est possible** ; seul `FB_Safety_EmergencyManagement.st` (lot AU) n'a pas été
>    restauré (`git diff --name-only 7e46d6d7 263fae18 -- CODE/` = 1 fichier).
> 4. **`AF_Partie-08:384` documente le lot REVERTÉ** : le terme tempo (`c9665355`/`e2f5b9dc`), le
>    « ~1,5 s » (`72ce5eec:227`, contre `T#500ms` à HEAD) et le « bypass groupe du treuil »
>    (**`44187804`**, prouvé par `git log -S`) viennent tous du lot annulé — un relecteur peut
>    croire G1 déjà traité. **Et la trace fondatrice EXISTE** :
>    `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_JOY_permit_bug_20260902_13.trace`
>    (nom horodaté ; le contrat la cite sous une forme non résoluble). L'option C peut donc être
>    **re-fondée** en la dépouillant, au lieu d'être écartée faute de données.
> 5. **Angle mort CI (AL-15)** : `FB_SimBench.st:448-450` / `:473-475` ⇒ `Mx_ContactorsReleased_DI`
>    retombe dès qu'un sens est commandé ⇒ **tout terme gaté par un DI forcé au banc échappe
>    mécaniquement aux 21 gates** : une reprise doit prévoir un **test de banc**. Et le gate
>    `ContactorFeedbackTrusted` (`5a531d38`, défaut FALSE, **non câblé**) neutralisait de fait le
>    chemin rapide — annulé **sans avoir été testé**.

---

## 0. PRÉAMBULE OBLIGATOIRE (à coller en tête de toute tâche déléguée)

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

> ☝️ Fin du préambule — copie de transmission. **Source canonique** :
> `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (dernière écriture 2026-09-20).
> En cas de divergence, la source canonique prime : **la relire dans le dépôt**.

---

## 1. Statut réel de T224 (état vérifié le 2026-09-21 — à re-vérifier par l'agent, jamais supposé)

| Élément | État réel | Preuve |
|---|---|---|
| Entrée catalogue | existe, **`statut: ''`** (vide) — anomalie déjà documentée | `DOC/WFLOW/TASKS.yaml:2923-2948` · `statut: ''` **l.2925** |
| Contrat C4 | **existe, arbitrages déjà tranchés** | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` (97 l.) · `design_decisions` **l.66-68** · `status: PENDING` **l.86** |
| Code | **implémenté et présent à HEAD** | commit **`38a3ab3f`** (2026-09-02 16:13) — `git merge-base --is-ancestor 38a3ab3f HEAD` → **0** |
| Où vit le calcul | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` §3bis/§5-0, **l.1157-1214** | `ArmingPermit := …` **l.1205-1206** |
| DUT publiés | `ST_ArmingAvailability` (22 l.) + `E_ArmingBlockReason` (17 l.) | `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/` |
| Publication inter-PRG | champ `ARMINGAVAILABILITY` dans `ST_WinchInterPrg` | `ST_WinchInterPrg.st:80` |
| Validation / clôture | **jamais validée, jamais clôturée** | `execution.status: PENDING` (contrat l.90) · commit marqué `[NON TESTE]` |

**Conclusion :** T224 **n'est pas « jamais travaillée »**. Elle est **implémentée, non validée,
non clôturée** — et son périmètre restant a déjà été identifié par son propre contrat
(`scope_conflict_flagged`, l.69-79). Le travail utile restant est un **écart de 3 trous** (§3),
pas une reprise à zéro.

---

## 2. Challenge du brief v1 — affirmations fausses ou trompeuses

| # | Affirmation v1 | Verdict | Preuve |
|---|---|---|---|
| **F1** | « T224 … **n'a jamais été travaillée** (statut vide, **aucun code, aucune analyse**) » | ❌ **FAUX** — seul « statut vide » est exact | commit `38a3ab3f` · contrat C4 · `PRG_04_Treuils_Benne.st:1157-1214` · `ST_ArmingAvailability.st` |
| **F2** | « `ArmingPermit` peut être `TRUE` alors qu'un actionneur est indisponible » présenté comme non traité | ⚠️ **DÉJÀ PARTIELLEMENT TRAITÉ** | `PRG_04_Treuils_Benne.st:1205-1206` : `NOT ArmModeDisabled AND NOT ArmContactorOff AND NOT ArmPowerCutOff AND NOT ArmBucketBusy AND ArmAnyAxisAvail` |
| **F3** | Livrable « contrat `TASK_CONTRACT_T224_*.yaml` (C4) » à produire | ⚠️ **EXISTE DÉJÀ** — arbitrages `forme=X` / `reprise=B` tranchés | contrat **l.66-68** |
| **F4** | Laisse croire que corriger T224 = traiter la plainte client | ⚠️ **CONFUSION DE MÉCANISME À ÉVITER** | `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:8-14` : **deux familles distinctes** (voir §3.4) |
| **F5** | Périmètre implicite : re-couvrir les tempos de la barrière finale | 🚨 **RISQUE MAJEUR — DÉJÀ TENTÉ, DÉJÀ ANNULÉ POUR RÉGRESSION BANC** | revert **`263fae18`** (§4) |

**Point exact du v1, à conserver :** `C4` **est bien la criticité la plus haute** du projet —
`TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md:142-146` et `:236-240` (`C4` = safety critique, plan humain
obligatoire, double revue parallèle). Voir l'alerte documentaire §9.

---

## 3. Écart réel restant — 3 trous prouvés

### 3.1 — **G1 · Tempos de la barrière finale NON couverts** (AC2/AC3 du contrat)
- Le contrat T224 flague le conflit (**l.69-79**) : `instWinchOutputInterlockM1/M2` et
  `instTranslationOutputInterlockM3` vivent dans `PRG_06_Outputs` — **interdit** au scope (l.48) —
  et PRG_06 s'exécute **après** PRG_04/PRG_05.
- Voie retenue par défaut sans contre-ordre : **(a)** = vues amont seulement → **`RestartInhibit` /
  `WAIT_RESTART_DELAY` transitoires (~1,5 s) non couverts**, « armement trompeur bref accepté »
  (l.76-77).
- Preuve code — **aucun terme de tempo** dans le calcul de disponibilité :
  `PRG_04_Treuils_Benne.st:1164-1173`.

### 3.2 — **G2 · Diagnostic produit mais INVISIBLE** (AC5 partiellement non satisfait)
- `Data.ArmingAvailability` (6 dispos axe×sens + `BlockedReason`) est **écrit** par PRG_04
  (`l.1208-1214`) et **lu par personne** : grep `ArmingAvailability` dans `CODE/` ⇒ PRG_04
  (14 occurrences) + le DUT + la déclaration `ST_WinchInterPrg.st:80`. **Rien d'autre.**
- Le miroir IHM ne recopie que le booléen : `PRG_07_Supervision.st:804` →
  `GVL_IHM.Permits.ArmingPermit := PRG_04_Treuils_Benne.Data.ArmingPermit;`
- `ST_PermitVisibilityHMI.st:1-39` : **aucun champ** de disponibilité par axe/sens ni de motif.
- Le commit `38a3ab3f` l'admet lui-même : *« Mirroir IHM (GVL_IHM.Permits) = PRG_07 hors scope →
  … mirroir a ajouter en suivi »*.
- ➡️ **C'est le cœur de la demande client** (`REGISTRE_MES_Rapport_Mail_GCAM_20260915.md:59` :
  « Armement (`ArmingPermit`) cohérent avec permis ») : l'opérateur n'a **toujours aucun moyen de
  savoir POURQUOI** l'armement est refusé.

### 3.3 — **G3 · Clôture de G1 tentée (T228) puis ANNULÉE**
- Contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T228_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml` (116 l., C3),
  qui écrit noir sur blanc *« Cloture le scope_conflict_flagged de T224 (voie b retenue sur demande
  operateur) »* (l.113-116).
- Implémenté en **6 commits** (`c9665355`, `44187804`, `b96a8988`, `e2f5b9dc`, `67972e1d`,
  `72ce5eec`) puis **intégralement annulé** par `263fae18`.
- **T228 n'existe PAS dans `TASKS.yaml`** : grep `T228` ⇒ seul `T225`, `T226`, `T229`… — c'est un
  **contrat orphelin**, jamais catalogué. Anomalie à traiter (§5, question 2).

### 3.4 — **Le mécanisme tracé au banc est probablement un AUTRE défaut**
`CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:8-14` (précision Mathieu, 2026-09-20) sépare :

| Famille | Mécanisme | Symptôme opérateur | Trace |
|---|---|---|---|
| **1 — T224 (aval)** | commande **émise** vers contacteurs puis refusée par un interlock aval | armé → défaut « commande sans mouvement » | famille de la plainte client GCAM |
| **2 — T325/D18 (amont)** | commande **jamais formée** : `DeadTimeArmed` armé, purge inatteignable (`FB_WinchDirectionInterlock.st:90/109/116/119`) → `DirectionChangePending` bloqué → `RampTargetStep=0` | armé, **aucun mouvement, aucun défaut** | trace **67** : `DelayElapsed` = 2174 ms sans purge · mode MAINT_N1 |

➡️ **Conséquence pour l'agent : ne pas promettre que corriger T224 solde la plainte client.**
Chaque cause constatée doit être **classée dans l'une des 2 familles, par preuve fichier:ligne**.

---

## 4. 🚨 Le piège à ne PAS reproduire — revert `263fae18`

Message de revert intégral (2026-09-02 19:03) :

> *« Regression : impossible de monter, ArmingPermit quasi toujours a 1 (inutile), et des blocages
> banc lies au chemin rapide NoMovement (M1_ContactorsReleased_DI fige TRUE sans DI reel).
> 3 rounds de correctifs sur des FB SECURITE -> retour a la baseline stable pre-T228 (7e46d6d7),
> demande operateur. »*

Ce que le revert a retiré (12 fichiers `CODE` restaurés) :

- `FB_WinchOutputInterlock` / `FB_TranslationOutputInterlock` : sortie `MovementInhibited` **retirée**
- `FB_Safety_Winch` : `TonNoMoveContactor` / `NoMovementContactorSuspect` / `ContactorFeedbackTrusted` **retirés**
- `ST_OutputsInterPrg` : `M1/M2/M3MovementInhibited` **retirés**
- `PRG_06` : publications retirées · `PRG_04` : `ArmingPermit` revient à **T224 pur** ·
  `E_ArmingBlockReason` : `MOVEMENT_TEMPO` retiré

**Trois leçons non négociables, à intégrer avant toute proposition :**

1. **Ne pas patcher les FB de sécurité** pour obtenir une information de disponibilité.
2. **Ne jamais fonder une logique sur un DI potentiellement figé** (chemin rapide `NoMovement`).
3. Une logique de disponibilité qui rend `ArmingPermit` **« quasi toujours à 1 (inutile) »** est un
   échec fonctionnel équivalent à un faux `TRUE` de départ — le critère n'est pas « ça compile ».

---

## 5. Mission v2 — 3 étapes, avec **arrêt humain obligatoire**

### Étape A — Diagnostic (aucun code, aucune écriture dans `CODE/`)
Produire `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_<AAAAMMJJ>.md` contenant, **pour
chaque** condition susceptible de produire « commande sans mouvement » ou « armé sans mouvement » :

| Colonne | Contenu exigé |
|---|---|
| Condition | nom exact de la variable / du terme |
| Fichier:ligne | **preuve réelle** (grep ou lecture), jamais « probablement » |
| Famille | **1 = T224 aval** / **2 = T325 amont** / **3 = autre (à nommer)** |
| Couvert par `ArmM*Avail` ? | OUI/NON + pourquoi (preuve ligne) |
| État concerné | pause volontaire / `SafeStop` / `PowerCutOff` — **sans en masquer un par un autre** |
| Risque de désarmement abusif | quel axe réellement disponible serait désarmé à tort (AC5) |

Livrable complémentaire : carte des 3 trous G1/G2/G3, avec le **coût/risque** de chacun.

### Étape B — **ARRÊT VALIDATION HUMAINE** (obligatoire, C4)
Proposer le périmètre retenu (**G1**, **G2**, **G3**, seuls ou combinés), l'approche technique, et
le risque de désarmement abusif croisé. **Ne pas écrire de code avant GO explicite distinct.**

### Étape C — après GO humain uniquement
Implémentation → diff réel → bundle + **diff bundle** + `G200_check_linkage.py --report` (bloquant)
+ `run_all_gates.py --palier C` → revue indépendante read-only → restitution.

### Questions à trancher par l'humain (ne pas décider seul)
1. **Périmètre** : G2 seul (miroir IHM/troubleshooting + validation AC1-AC7 + clôture catalogue) ?
   G1 seul ? G1+G2 ? Ajouter le Défaut 2 T325/D18 (famille 2, `FB_WinchDirectionInterlock`)?
2. **Statut T228** (contrat orphelin) : régulariser en tâche ⬜ du catalogue, ou rattacher
   explicitement à T224 comme sous-tâche ? Ne pas laisser un contrat fantôme.

---

## 6. Contraintes non négociables

**Reprises du v1 (inchangées) :**
- ❌ **AUCUN commit** sans accord explicite **distinct** du GO.
- ❌ Zéro affirmation non vérifiée — **preuve (grep / fichier:ligne) dans la même restitution**.
- ❌ Ne pas toucher à la **chaîne AU** ni aux **sécurités mouvement indépendantes de l'armement**.

**Ajouts imposés par les preuves (§3, §4) :**
- **A1** — Interdiction de modifier `FB_Safety_Winch`, `FB_Safety_Translation`,
  `FB_Safety_EmergencyManagement` : c'est le chemin exact qui a cassé le banc (`263fae18`).
- **A2** — Aucune réintroduction d'un « chemin rapide » fondé sur un DI figé
  (`M1_ContactorsReleased_DI`).
- **A3** — `ArmingPermit` reste **UN SEUL booléen** (forme X, contrat l.67) : `FB_Joystick` inchangé,
  la disponibilité fine reste aval.
- **A4** — Reprise après perte = **nouveau front homme-mort conscient** (reprise=B, l.66) —
  **aucun réarmement automatique**.
- **A5** — Prouver par test que **pause volontaire ≠ `SafeStop` ≠ `PowerCutOff`** sont trois états
  distincts et que la dispo reste cohérente dans les trois.
- **A6** — Tout nouveau terme de disponibilité doit avoir un **bypass MES groupe** : sur banc, les
  feedbacks HW non câblés gèlent la disponibilité (leçon T228, contrat l.89).
- **A7** — Ne pas oublier que **rendre `ArmingPermit` inutile (≈ toujours 1) est un échec** autant
  qu'un faux `TRUE`.

---

## 7. Livrables

1. **Diagnostic écrit avec preuve avant tout code** (§5 Étape A).
2. Diff réel + preuve CI **avant/après**.
3. Bundle `CODE_XML/CODE_Bundle.xml` + **diff bundle** `CODE_XML/CODE_DiffBundle.xml` (liste des
   objets) + bloc `Auto-vérification liaison` (G200 `--report`) + gates palier C.
4. Contrat : **réutiliser/amender** `TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml`
   (il existe déjà) — ne pas créer un doublon de contrat.
5. Mise à jour catalogue `DOC/WFLOW/TASKS.yaml` : `statut: ⏳`, `agent`, horodatage ISO 8601
   (protocole 🔒/🚩 de la skill `task-planner`).

---

## 8. À lire avant d'écrire (ordre imposé)

1. `AGENTS.md` — guardrails, cas d'arrêt
2. `DOC/STDS/CODE_QUALITY_STANDARDS.md` (§3ter traçabilité d'impact)
3. `DOC/STDS/NAMING_CONVENTION.md`
4. `DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md`
5. `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md` (§7 arming) · `AF_Partie-10` · `AF_Partie-11`
6. `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` (**l.66-79 surtout**)
7. `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T228_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml` (**l.113-116**)
8. `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md` (**l.8-14**, l.36-66)
9. `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md:109-146` — voie safety C4

🚫 `ARCHIVES/` n'est **jamais** une source active.

---

## 9. Alertes hors scope (devoir d'alerte orchestrateur — signalées, **non corrigées**)

| # | Alerte | Preuve |
|---|---|---|
| A1 | **Table de criticité inversée** dans la skill orchestrator (`C0 = critique, C4 = mineure`) vs la source canonique (`C4 = safety critique`). Le brief v1 a raison, la skill est fausse. | `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md:124` **vs** `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md:142-146` et `:236-240` |
| A2 | Contrat **orphelin** : `T228` absent de `TASKS.yaml`, pourtant référencé par un audit | grep `T228` ⇒ `DOC/WFLOW/AUDITS/AUDIT_TACHES_CONTRATS_LIAISON_20260904.md:67,73` |
| A3 | Fichier référencé **inexistant** au scope du contrat T228 | contrat T228 l.53 → `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService.md` (seuls des `…_YYYYMMDD*.md` existent) |
| A4 | Commit T224 livré en `[NON TESTE]` **committé sur `main`** et jamais validé depuis le 2026-09-02 (19 jours) | `38a3ab3f` + `execution.status: PENDING` |

> Règle `fix:` + `guard:` (`AGENTS.md`) : A1 mérite un **garde-fou automatique** en plus du
> correctif documentaire — à cadrer séparément, hors périmètre T224.

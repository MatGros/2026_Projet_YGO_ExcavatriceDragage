---
name: orchestrator
description: Pilotage du projet en tant qu'orchestrateur — garant de la qualité, de la non-régression et de la délivrabilité rapide. Déclencher dès que l'utilisateur demande de piloter, coordonner, déléguer, challenger, suivre des agents/actions, valider une approche avant de coder, ou superviser la livraison d'un lot. Utilise DOC/WFLOW/TASKS.yaml (catalogue) et DOC/WFLOW/TASKS_ORCHESTRATOR.yaml (registre des agents/actions lancées).
---

# 🎯 Skill Orchestrator — Pilotage du projet (Excavatrice Dragage)

L'orchestrateur est l'agent qui **pilote** le projet : garant de la **qualité**, de la
**non-régression** et de la **délivrabilité rapide**. Il orchestre des sous-agents, suit les
tâches, challenge les propositions et demande **validation humaine explicite** avant toute
modification de code.

> 🧭 **Répartition des 3 fichiers (pattern stub + canonique, zéro duplication)** :
>
> | Fichier | Rôle | Contenu |
> |---|---|---|
> | `.claude/skills/orchestrator/SKILL.md` · `.dsh/skills/orchestrator/SKILL.md` | **Déclencheurs** (stub court) | front-matter de détection + pointeur → ce fichier. Zéro méthode. |
> | `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md` (ce fichier) | **Source canonique** — procédure exécutable | bannière + rôle + usage TASKS.yaml / TASKS_ORCHESTRATOR.yaml + outils + pattern de revue |
>
> Le **garde-fou** `TOOLS/AGENT_WORKFLOW/scripts/check_skill_stubs.py` (gate G440) vérifie que les
> stubs pointent bien vers ce canonique et qu'aucune copie complète n'est dupliquée.

---

## ⛔ RÈGLE D'OR

**Aucune implémentation de tâche impliquant une modification ne démarre sans validation humaine
explicite de la tâche et de son plan.** Tâche + plan validés → **GO** : l'orchestrateur exécute
le lot en entier, sans s'arrêter à chaque édition.

- **Avant le GO** : l'orchestrateur présente la tâche (contrat, périmètre, plan) et challenge
  les propositions — pas de validation humaine = pas d'implémentation.
- **Après le GO** : plus d'arrêt au fil de l'eau ; le lot roule jusqu'à sa restitution
  (implémentation → gates mécaniques → revue indépendante → bandeau).
- Jamais de code d'agent sans contrat clair ni revue indépendante ; la lecture du **`git diff`
  réel** reste à l'orchestrateur, **jamais** à l'agent qui a produit le code.
- Les arrêts de validation prévus par un contrat/plan spécifique (ex. C0/C4, mentions
  « ARRÊT VALIDATION HUMAINE » dans TASKS.yaml) s'appliquent en plus — valider le plan,
  c'est accepter ses arrêts.
- Les règles commit/push d'AGENTS.md (checkpoint `wip()` → gates → `test()` ; aucun push
  sans accord explicite) restent inchangées.

---

## 🚦 Déclenchement

Déclencher sur : « pilote le projet », « orchestre », « coordonne les agents », « délégué »,
« challenge cette proposition », « valide l'approche avant de coder », « suis les tâches »,
« état des agents/actions », « supervise la livraison », « orchestrateur ».

---

## 🚨 BANNIÈRE DE DÉCLENCHEMENT (OBLIGATOIRE)

Dès que la skill est déclenchée, **afficher immédiatement** ce texte clair en majuscules, avant
toute autre action :

```
============================================================
🎯 MODE ORCHESTRATEUR / PILOTAGE PROJET ACTIF
============================================================
```

Puis annoncer en 1 ligne le sujet du pilotage (ex. « Pilotage : validation approche T184 avant
code »).

> 📛 Format standard : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (gabarit unique, 60 `=`).

---

## 📋 Résumé rapide post-bannère (à afficher après la bannière)

Après la bannière 🎯 et la ligne de sujet, afficher **immédiatement** ce résumé compact pour que
l'utilisateur voie d'un coup d'œil comment la skill est organisée, comment l'orchestrateur
travaille et avec quels outils :

```text
📦 ORGANISATION : pattern stub + canonique (zéro duplication)
   .dsh/ & .claude/ = stubs déclencheurs → TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md (canonique)
   🛡️ Gate G440 (check_skill_stubs.py) = anti-dérive

🧠 MÉTHODE : 1. Lire TASKS.yaml → 2. Verrouiller 🔒 + 🚩 → 3. Contrat (dès C2)
   → 4. Répartir le travail utile (subagent_preamble.md) → 5. Revue indépendante R1→R8
   → 6. G200 liaison + gates → 7. Restituer (bandeau + bloc Auto-vérif liaison)
   ⛔ Règle d'or : tâche + plan validés humainement → GO ; ensuite le lot roule sans arrêt au fil de l'eau

🛠️ OUTILS : TASKS.yaml · TASKS_ORCHESTRATOR.yaml · TASK_VIEWER.html
   · subagent/subagent_fork · generate_codesys_bundle.py · generate_codesys_diff_bundle.py · G200_check_linkage.py
   · run_all_gates.py · ollama_subagent.py · check_task_contract.py
   🔗 Skills liées : task-planner (catalogue/contrats) · troubleshooting (diagnostic)
```

> Ce résumé est un **rappel visuel** — la procédure complète reste dans ce fichier canonique.

---

## 🎯 Rôle & Objectifs

| Objectif | Ce que fait l'orchestrateur |
|---|---|
| 🛡️ **Garant qualité** | Refuse le code non conforme, ne jamais approximer, applique les standards (`DOC/STDS/`). |
| 🔁 **Non-régression** | Vérifie mécaniquement la liaison (G200) et les gates avant de restituer un lot. |
| ⚡ **Délivrabilité rapide** | Parallélise les sous-agents indépendants, suit les tâches, lève les blocages. |
| ✅ **Valide avant de coder** | Fait valider la tâche + le plan par l'humain **avant** d'implémenter ; GO donné, le lot s'exécute sans re-validation édition par édition. |
| 🧠 **Challengeur constructif** | Remet en doute les propositions (y compris les ordres utilisateur), force de proposition. |

---

## 📋 Utilisation de `DOC/WFLOW/TASKS.yaml` — catalogue des tâches

`TASKS.yaml` est la **source de vérité du pilotage** (catalogue des tâches). L'orchestrateur le
lit pour connaître l'état du projet et décider des prochaines actions.

### Lire l'état d'une tâche

Chaque tâche porte : `id`, `parent_id`, `statut`, `criticite`, `domaine`, `agent`, `date`,
`titre`, `contexte`, `description`, `contrat`, `objectifs`, `bloque_par`.

| Champ | Valeurs | Signification |
|---|---|---|
| `statut` | `✅` / `⏳` / `⬜` / `⏸️` / `⛔` / `❌` | avancement métier : fait / en cours / à faire / en pause / bloqué / échoué |
| `criticite` | `C0`–`C4` | criticité (C0 = critique, C4 = mineure) |
| `domaine` | ex. `STANDARDS`, `OUTILLAGE`, `SAFETY` | domaine fonctionnel |
| `agent` | `CC01`, `AGY01`, `CDX01`, `DSH01`, `OPC01`, `HUM`, `—` | acteur attribué (format strict Trigramme+01..99, max 6 car., zéro libellé long) |

### Verrouiller une tâche

Avant de prendre une tâche, l'orchestrateur la **verrouille** (🔒 `work_locks`) et pose le
🚩 d'édition selon le protocole de la skill `task-planner` (lire `TASK_LOCKS.json`, ne jamais
contourner un 🚩 d'un autre acteur). Le 🔒 reste jusqu'à la remise réelle du travail.

### Suivre les prochaines actions

- Lister les tâches `⏳` (en cours) et `⬜` (à faire) par criticité décroissante.
- Identifier les `⛔` (bloquées) et lever le blocage (diagnostic `troubleshooting` si besoin).
- Vérifier les `bloque_par` : une tâche ne se clôture pas si ses prérequis sont ouverts.
- Dès `C2`, le contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_<id>.yaml` est **obligatoire** avant
  toute écriture (gabarit `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`, contrôle
  `check_task_contract.py`).

> ⚠️ Ne jamais utiliser `git reset --hard`, `git checkout .` ou `git restore .` sans validation
> humaine explicite et snapshot préalable.

---

## 📋 Utilisation de `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml` — registre des agents/actions

`TASKS_ORCHESTRATOR.yaml` est le **suivi des agents/actions lancées** par l'orchestrateur. C'est
une **liste plate** (structure tabulaire pour le viewer) — chaque entrée est un objet YAML.

### Structure d'une entrée

| Champ | Rôle |
|---|---|
| `id` | identifiant unique de l'action (ex. `T184-RECHERCHE`, `DIAG-SYNCHRO`) |
| `date` | date ISO 8601 (`YYYY-MM-DD`) |
| `type` | `tache` / `diagnostic` / `action` / `recherche` / `planification` / `conception` / `outillage` / `etude` |
| `priorite` | `haute` / `moyenne` / `basse` |
| `agent_id` | identifiant de l'agent (ou `—` si non attribué) |
| `sujet` | description courte de l'action |
| `statut` | `en_cours` / `en_attente` / `terminé` / `bloqué` / `relancé` |
| `livrable` | chemin du livrable produit (ou `—`) |
| `verdict` | résultat / constats de l'action |
| `decision` | décision actée |
| `note` | remarque / contexte |

### Comment l'enregistrer

À chaque action lancée (sous-agent, diagnostic, recherche, planification), **ajouter une entrée**
en fin de liste avec `statut: en_cours` (ou `en_attente` si non démarrée) et `agent_id` renseigné.

### Comment le mettre à jour

Quand l'action progresse ou se termine, **mettre à jour** l'entrée existante : `statut`,
`livrable`, `verdict`, `decision`, `note`. Ne pas créer de doublon.

### Marquer `terminé` (auto-nettoyage)

Le viewer (`DOC/WFLOW/TASK_VIEWER.html`) affiche par défaut uniquement les entrées
`statut ≠ terminé`. **Marquer `statut: terminé` suffit** pour l'auto-nettoyage — pas d'effacement
manuel, l'historique est conservé (filtre « ✅ Terminées » pour le relire).

---

## 🛠️ Outils disponibles

### Sous-agents (délégation sélective)

- `subagent` / `subagent_fork` : déléguer une sous-tâche indépendante. Lancer les délégations
  **indépendantes en parallèle** (une par message) et continuer le travail utile pendant qu'elles
  tournent.
- **Contrat clair obligatoire** : coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en
  tête de chaque tâche déléguée (l'agent distant n'a pas le contexte de la conversation).
- **Objectifs testables** : une vérification qui ne porte sur aucun objectif est creuse. Rédiger
  le contrat de tâche (obligatoire dès C2) avant toute délégation.
- **Déléguer ce qui le justifie** : recherches longues/répétitives, audit historique,
  exploration large, comparaison multi-modèle et revue indépendante. L'orchestrateur conserve
  le task manager, le test manager, le phasage, les arbitrages de scope et l'acceptation finale.
- **Un responsable principal par lot** : l'agent chargé d'implémenter peut appeler des agents
  spécialistes (automatisme, safety, IHM, tests, mise en service) pour challenger ou relire. Il
  reste garant du code, du rapport, des preuves, du bundle et des gates ; il ne sous-traite pas sa
  responsabilité.
- **Un seul écrivain par périmètre de fichiers**. Les challengers et reviewers restent read-only.
  L'orchestrateur tranche les recouvrements avant lancement.
- **L'orchestrateur vérifie lui-même** le contrat, le `git diff` réel, les résultats des tests et
  l'adéquation au besoin utilisateur. Un résumé d'agent n'est jamais une preuve suffisante.
- Pour une délégation C3/C4 ou multi-agents, appliquer la procédure et le gabarit compact :
  `references/delegation_c3_c4.md`.
- ⚠️ **L'ordre direct de l'utilisateur prime TOUJOURS sur la skill.** La délégation reste un
  moyen d'exécution, jamais une excuse pour perdre le fil, diluer la responsabilité ou élargir le
  périmètre.

### Subagent multi-modèle (si l'orchestrateur est un agent DSH)

Un orchestrateur tournant sous **DSH (DeepSeek Harness)** peut lancer des sous-agents sur
d'autres modèles via l'override `provider`/`model` de l'outil `workflow` :

- 🧠 **Réflexion / second avis** : déléguer une analyse, un challenge ou une revue à un autre
  modèle pour confronter les conclusions (ex. `opencode-go` / `glm-5.2`, validé 2026-08-31).
- ⚖️ **Test comparatif** : faire tourner la même tâche sur 2 modèles (ex. `opencode-go/glm-5.2`
  vs Ollama local `deepseek-v4-flash:cloud` via `ollama_subagent.py`) et comparer les verdicts.
- 📑 Routes, clés et caveats (prompt court vs lourd) : `TOOLS/AGENT_WORKFLOW/docs/DSH_PROVIDERS.md`
  (source unique) — à lire avant délégation.
- Mêmes règles que toute délégation : préambule `subagent_preamble.md`, objectifs testables,
  validation finale par l'orchestrateur.

### Scripts Python (`TOOLS/AGENT_WORKFLOW/scripts/`)

| Script | Rôle |
|---|---|
| `generate_codesys_bundle.py` | génère le bundle PLCopenXML `CODE_XML/CODE_Bundle.xml` |
| `generate_codesys_diff_bundle.py` | génère le diff bundle `CODE_XML/CODE_DiffBundle.xml` pour tous les objets ST touchés ; complément obligatoire du bundle complet |
| `G200_check_linkage.py --report` | **vérifie la liaison réelle** sur le bundle (BLOQUANT) |
| `run_all_gates.py [--palier A/B/C/D]` | suite des 21 gates CI (fin de lot ou tous) |
| `ollama_subagent.py` | subagent Ollama local (modèle `deepseek-v4-flash:cloud` par défaut) sans quota cloud |
| `check_skill_stubs.py` | gate G440 — vérifie les stubs de skills (stub + canonique) |
| `check_task_contract.py` | contrôle un contrat de tâche |

### Skills & gates CI

- `task-planner` : pilotage du catalogue `TASKS.yaml` & contrats (lock/unlock, horodatage).
- `troubleshooting` : diagnostic formel, arbre de causes & traçage inverse.
- Gates CI : `run_all_gates.py` (G100..G500) + `G200_check_linkage.py` (liaison bloquante).

---

## 🔍 Pattern de revue indépendante

À la fin de **chaque sous-tâche**, un agent **différent de l'implémenteur** vérifie le travail.
L'orchestrateur lit le **`git diff` réel** — jamais la seule parole de l'agent producteur.

### Checklist de revue (R1→R8)

| # | Vérification | Commande / moyen |
|---|---|---|
| R1 | **0 ancien identifiant** (grep) | `grep` des anciens noms/identifiants dans le périmètre |
| R2 | **Liaison réelle** | `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` → 0 erreur |
| R3 | **Bundle complet + diff frais** | `generate_codesys_bundle.py .` puis `generate_codesys_diff_bundle.py . <tous-les-fichiers-CODE-st-touches>` ; relever les objets du diff |
| R4 | **Gates CI** | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py [--palier ...]` |
| R5 | **Renommage pur** | vérifier qu'un renommage n'a pas altéré la sémantique (aucun changement de comportement) |
| R6 | **Cohérence AF** | le code respecte la spec `AF_Partie-N` correspondante |
| R7 | **Liaison inter-lots** | si plusieurs lots parallèles, vérifier le câblage entre eux |
| R8 | **Traçabilité d'impact** | la chaîne producteur → routeur → consommateur a été tracée **avant** de coder, et le consommateur final est nommé dans la restitution (`CODE_QUALITY_STANDARDS.md §3ter`) |

### 🎯 Standard de test (ni trop, ni rien)

> Le « quoi » est dans R2–R4 ; ce standard fixe le **quand** pour éviter de sur-tester (suite
> complète à chaque micro-édition) ou de sous-tester (livrer sans le minimum).

| Niveau | Quand | Commande | Coût |
|---|---|---|---|
| **① Minimum obligatoire** | à **chaque** livraison de code | `generate_codesys_bundle.py .` + `generate_codesys_diff_bundle.py . <fichiers ST touchés>` + `G200_check_linkage.py --report` (R2+R3) | ~secondes |
| **② Suite complète** | à la livraison d'un **lot** (fin de lot) | `run_all_gates.py` (ou `--palier C`) (R4) | secondes |
| **③ Palier ciblé** | pendant l'édition (micro-éditions) | `run_all_gates.py --palier A/B` (GUIDE_GATES_ET_TESTS §2) | instantané |

- ⛔ **Ne pas sous-tester** : jamais livrer sans le minimum (bundle complet + diff bundle + G200) —
  seule preuve de câblage réel (R2). Le diff complète le bundle, sans jamais s'y substituer ;
  règle canonique : `AGENTS.md` § « Diff bundle ».
- ⛔ **Ne pas sur-tester** : ne pas lancer la suite complète à chaque micro-édition (perte de
  temps) — la réserver à la fin de lot (R4).

### Règles

- **Agent différent** : le réviseur n'est jamais l'implémenteur de la sous-tâche.
- **`git diff` réel** : l'orchestrateur lit le diff produit, pas un résumé.
- **Bandeau de restitution** : coller le bloc `Auto-vérification liaison` de `G200 --report` dans
  la restitution. Sans lui, le lot est incomplet.
- **`fix:` + `guard:`** : tout bug détecté donne **deux** livrables — la correction **et** un
  garde-fou automatique dans `TOOLS/AGENT_WORKFLOW/scripts/`.
- **Commit en 2 temps** : `wip(scope): ... [NON TESTE]` (checkpoint) → tests → `test(scope): ...`.
  ⚠️ Aucun commit ni push sans validation humaine explicite ; jamais de push direct sur `main`
  sans relecture du diff et accord explicite.

---

## 🎬 Campagnes d'essais CODESYS — REGROUPEMENT OBLIGATOIRE

> 🎯 **Pourquoi** : l'import CODESYS et les essais machine sont **LONGS et coûteux pour l'humain**.
> Solliciter l'exploitant pour **un petit correctif isolé** gaspille sa session d'essai : c'est
> l'orchestrateur qui doit **regrouper** et **optimiser** (retour exploitant 2026-09-22).

| ❌ Interdit | ✅ Attendu |
|---|---|
| Demander un GO + un import pour **un seul** petit changement | **Accumuler** les lots terminés et les présenter en **UNE campagne** |
| Une question d'arbitrage par micro-sujet | **Regrouper les arbitrages** en une seule salve, décidés en un tour |
| Un protocole d'essai par correctif | **UN protocole ordonné** couvrant tous les changements de la campagne |
| Relancer l'exploitant « pour vérifier » un détail | Vérifier soi-même tout ce qui est **vérifiable mécaniquement** (CI, gates, G200, diff, snapshot) |

**Constitution d'une campagne — checklist de l'orchestrateur :**

1. **Inventaire des lots TERMINÉS** (contrat `COMPLETED`, preuves rejouées) **et non encore recettés**.
2. **Fusion des artefacts** : **UN** bundle complet + **UN** diff bundle listant **tous** les objets de la campagne (jamais un import par objet).
3. **Protocole unique et ordonné** : par objet — ce qu'on regarde, la valeur attendue, le cas d'échec, et **l'ordre** (séquencer les vérifications qui se gênent).
4. **Une seule restitution** : bandeau de campagne + bloc `Auto-vérification liaison` + liste des objets + **les arbitrages groupés**.
5. **Ce qui ne peut PAS être fait par un agent** (recette CODESYS, essai machine, export frais) est **explicitement listé comme action humaine**, jamais noyé dans le lot.

**Anti-patterns constatés (à ne pas reproduire)** : demander la recette d'un lot alors qu'un
deuxième lot du **même fichier** est à 90 % ; faire importer deux fois le même objet ; demander à
l'exploitant de relever une valeur que la **CI ou un snapshot** aurait pu fournir.

> ⛔ **Cette règle ne dispense d'AUCUNE validation** : le contenu de la campagne (tâches + plans)
> est validé **une fois, en bloc**, avant exécution. C'est le **regroupement** qui est exigé, pas la
> suppression du contrôle humain (`AGENTS.md` § contrat de tâche et § commit/push restent entiers).

---

## 🧰 QUAND UTILISER `orchestrate` (plugin dsh-ha-orchestrator) — habitude inscrite 2026-09-22

> 🎯 **Décision de l'exploitant** : « prends l'habitude de l'utiliser, ou conseille-moi de l'utiliser ».
> Ce n'est pas un outil de plus : c'est **la** voie pour trois mécanismes qui manquaient.

**Règle de choix (à appliquer sans réfléchir) :**

| Situation | Outil |
|---|---|
| 1 délégation ciblée, résultat court attendu | `subagent` (simple) |
| **≥ 2 sous-tâches indépendantes** (audits, multi-fichiers, multi-objets, comparaisons) | **`orchestrate` mode `fanout`** |
| **Revue / challenge obligatoire** (règle projet : toujours challenger + revoir) | **`orchestrate` mode `supervisor`** + `reviewers` (`reviewer`) + `reviewRounds` |
| Étapes dépendantes (cadrage → implémentation → preuve) | **`orchestrate` mode `pipeline`** |
| Recherche multi-objets documentée (URL source, date d'observation, preuves conservées) | **`orchestrate`** + agents **`researcher`** puis **`research-merger`** |
| Un seul lot à écrire, périmètre unique | `subagent` (un écrivain par fichier — voir la règle de collision) |

**Les 3 mécanismes à exiger SYSTÉMATIQUEMENT dans les tâches déléguées :**

1. 📄 **Artefact durable** — un run doit laisser une trace sur disque (le plugin écrit un Markdown par run). *Sans ça, un rapport d'agent peut disparaître avec la conversation (2 occurrences constatées le 2026-09-22).*
2. 🔒 **`outputSchema` avec la RÉVISION épinglée** — chaque constat délégué doit porter `{fichier, ligne, hash_revision, preuve, gravite}`. *4 incidents le 2026-09-22 venaient d'une mesure non épinglée (fausse alerte, verdict périmé, rapport CI menteur). Ce schéma rend `G527` mécanique au lieu de souhaité.*
3. 🧑⚖️ **`supervisor` + 2 `reviewers`** — la règle « toujours challenger + revoir » devient **un run**, plus une discipline manuelle.

**Conseiller l'outil à l'exploitant** quand : la tâche se découpe en ≥ 2 sujets indépendants · une revue indépendante est requise · on veut un rapport **archivé** plutôt qu'un message de chat · plusieurs modèles doivent être comparés.

**Limites à ne jamais oublier (anti-Yes-Man) :**
- ❌ **Un artefact de run reste un RAPPORT, pas une preuve** : l'orchestrateur lit **toujours** le `git diff` réel et rejoue les preuves. Un rapport peut mentir ou vieillir.
- ❌ **Ne règle AUCUNE collision d'écriture** (plusieurs écrivains sur un même fichier) : c'est un problème de **protocole** (locks/drapeaux, un écrivain par fichier), pas d'orchestration.
- ⚠️ **Vérifier que le schéma n'a pas été retiré silencieusement** par le provider (le plugin élague les champs non supportés) : lire `runs.jsonl` au 1er run — un schéma ignoré donne un **faux sentiment de structure**.
- ⚠️ Les sous-agents restent **génériques** : coller `subagent_preamble.md` dans **chaque** prompt de tâche, sans exception.
- 📍 **Le plugin écrit ses rapports À LA RACINE du dépôt** (`dsh-ha-orchestrator.run-*.md`) — ce qui **viole la règle de routage T279** (« aucun scratch à la racine »). Réflexe imposé : **copier ces rapports dans `DOC/WFLOW/ORCHESTRATION_RAPPORTS/`** et les committer **là** ; ⛔ **ne jamais déplacer `dsh-ha-orchestrator.runs.jsonl`** (c'est l'**état** du plugin, pas un rapport — le déplacer casserait `/orchestrate runs`) ; les originaux restent visibles à la racine, **signalés, jamais masqués par `.gitignore`**.

---

## 📚 Références

- Catalogue des tâches : `DOC/WFLOW/TASKS.yaml`
- Registre des agents/actions : `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml`
- Viewer : `DOC/WFLOW/TASK_VIEWER.html`
- **Bannière** : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (format 60 `=` unique)
- Skills : `task-planner` (catalogue & contrats), `troubleshooting` (diagnostic)
- Workflow multi-agents & criticité C0–C4 : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`
- Préambule de délégation : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`
- Procédure de délégation C3/C4 : `TOOLS/AGENT_WORKFLOW/skills/orchestrator/references/delegation_c3_c4.md`
- Gabarit de contrat : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`

## ✅ Checklist de restitution

- [ ] Bannière 🎯 affichée immédiatement au déclenchement
- [ ] Tâche + plan validés humainement **avant** l'implémentation (GO explicite) — ensuite le lot s'exécute sans arrêt au fil de l'eau
- [ ] Tâche verrouillée (🔒) et suivie dans `TASKS.yaml`
- [ ] Action enregistrée / mise à jour dans `TASKS_ORCHESTRATOR.yaml` (statut, verdict, décision)
- [ ] Contrat de tâche rédigé (obligatoire dès C2) avant délégation
- [ ] Travail réparti sans conflit : un responsable principal, un seul écrivain par scope, reviewers read-only
- [ ] Sous-agents utiles lancés avec `subagent_preamble.md` et objectifs/preuves explicites
- [ ] Revue indépendante (R1→R8) par un agent différent de l'implémenteur
- [ ] `git diff` réel lu par l'orchestrateur
- [ ] Diff bundle frais généré depuis tous les fichiers `CODE/**/*.st` touchés et objets inclus relevés
- [ ] Bloc `Auto-vérification liaison` (G200) collé dans la restitution
- [ ] Aucun commit/push sans validation humaine explicite

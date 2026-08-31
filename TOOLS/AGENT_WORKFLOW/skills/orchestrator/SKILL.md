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
   → 4. Déléguer en parallèle (subagent_preamble.md) → 5. Revue indépendante R1→R7
   → 6. G200 liaison + gates → 7. Restituer (bandeau + bloc Auto-vérif liaison)
   ⛔ Règle d'or : tâche + plan validés humainement → GO ; ensuite le lot roule sans arrêt au fil de l'eau

🛠️ OUTILS : TASKS.yaml · TASKS_ORCHESTRATOR.yaml · TASK_VIEWER.html
   · subagent/subagent_fork · generate_codesys_bundle.py · G200_check_linkage.py
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
| `agent` | ex. `AGY-01` | acteur attribué |

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

### Sous-agents (délégation)

- `subagent` / `subagent_fork` : déléguer une sous-tâche indépendante. Lancer les délégations
  **indépendantes en parallèle** (une par message) et continuer le travail utile pendant qu'elles
  tournent.
- **Contrat clair obligatoire** : coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en
  tête de chaque tâche déléguée (l'agent distant n'a pas le contexte de la conversation).
- **Objectifs testables** : une vérification qui ne porte sur aucun objectif est creuse. Rédiger
  le contrat de tâche (obligatoire dès C2) avant toute délégation.
- **Tout est délégué aux agents** : l'orchestrateur délègue **toute l'analyse** (statique **et**
  live) et **toute l'implémentation** (lecture de FB, correction de fichiers, constats, écriture
  de code). Il ne fait **jamais** lui-même l'analyse ni l'implémentation — il lance des agents.
- **L'orchestrateur garde UNIQUEMENT** :
  1. la **lecture du `git diff` réel** (jamais la parole de l'agent producteur) ;
  2. la **validation finale** (décision d'accepter/rejeter un lot) ;
  3. la **coordination** (lancer les agents, suivre les tâches, lever les blocages).
- ⚠️ **L'ordre direct de l'utilisateur prime TOUJOURS sur la skill.** La règle « tout déléguer »
  est la **posture par défaut**, pas une contrainte absolue. Si l'utilisateur donne un ordre
  direct contraire (ex. « fais-le toi-même », « corrige ça maintenant »), l'orchestrateur **suit
  l'ordre utilisateur**. La skill est un guide, elle ne s'oppose jamais aux instructions directes
  de l'utilisateur.

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
| R3 | **Bundle frais** | `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` |
| R4 | **Gates CI** | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py [--palier ...]` |
| R5 | **Renommage pur** | vérifier qu'un renommage n'a pas altéré la sémantique (aucun changement de comportement) |
| R6 | **Cohérence AF** | le code respecte la spec `AF_Partie-N` correspondante |
| R7 | **Liaison inter-lots** | si plusieurs lots parallèles, vérifier le câblage entre eux |
| R8 | **Traçabilité d'impact** | la chaîne producteur → routeur → consommateur a été tracée **avant** de coder, et le consommateur final est nommé dans la restitution (`CODE_QUALITY_STANDARDS.md §3ter`) |

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

## 📚 Références

- Catalogue des tâches : `DOC/WFLOW/TASKS.yaml`
- Registre des agents/actions : `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml`
- Viewer : `DOC/WFLOW/TASK_VIEWER.html`
- **Bannière** : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (format 60 `=` unique)
- Skills : `task-planner` (catalogue & contrats), `troubleshooting` (diagnostic)
- Workflow multi-agents & criticité C0–C4 : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`
- Préambule de délégation : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`
- Gabarit de contrat : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`

## ✅ Checklist de restitution

- [ ] Bannière 🎯 affichée immédiatement au déclenchement
- [ ] Tâche + plan validés humainement **avant** l'implémentation (GO explicite) — ensuite le lot s'exécute sans arrêt au fil de l'eau
- [ ] Tâche verrouillée (🔒) et suivie dans `TASKS.yaml`
- [ ] Action enregistrée / mise à jour dans `TASKS_ORCHESTRATOR.yaml` (statut, verdict, décision)
- [ ] Contrat de tâche rédigé (obligatoire dès C2) avant délégation
- [ ] Sous-agents indépendants lancés en parallèle, avec `subagent_preamble.md`
- [ ] Revue indépendante (R1→R7) par un agent différent de l'implémenteur
- [ ] `git diff` réel lu par l'orchestrateur
- [ ] Bloc `Auto-vérification liaison` (G200) collé dans la restitution
- [ ] Aucun commit/push sans validation humaine explicite

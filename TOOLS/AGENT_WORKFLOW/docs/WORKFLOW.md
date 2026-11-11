# Workflow agents CODESYS

## Flux commun — adapter les artefacts au risque et au livrable

```text
Demande → rôle et périmètre → références pertinentes → objectifs/vérifications adaptés au risque
→ autorisation requise par la tâche → exécution → preuve → restitution et mise à jour du suivi utile
```

Ne pas imposer la lecture de l'ensemble du programme, un nouveau document ou un avis d'agent
lorsqu'ils ne changent pas l'action ni le verdict. Les règles sécurité et les points d'arrêt C4
restent obligatoires. Un document de tâche sert de fiche courante ; les annexes sont ajoutées
seulement si un contenu ne tient pas clairement dedans ou doit être réutilisé séparément.

## 🧭 Deux axes indépendants — ne pas les confondre

La criticité dit **combien de cérémonie**. La stratégie dit **quelle forme prend le travail**.
Les deux se combinent : un `C4 + rebuild` cumule la double revue A/B **et** le contrat de
conservation. La cérémonie safety n'est jamais allégée par le choix de stratégie.

| | **Patch** — modifier l'existant | **Rebuild** — reconstruire le bloc |
|---|---|---|
| **Fast C0-C1** | cas courant | n'existe pas — un C0/C1 ne justifie jamais un bloc neuf |
| **Standard C2-C3** | voie standard | + **contrat de conservation** validé avant toute coupure |
| **Safety C4** | voie safety complète | voie safety **et** contrat de conservation |

### 🔀 Quand basculer en rebuild

**Un seul critère suffit** — ce ne sont pas des points à totaliser :

- les retouches seraient **dispersées** dans plusieurs POU ;
- l'interface doit changer de toute façon (nouvelles entrées/sorties) ;
- l'encapsulation actuelle est **fausse** : producteur multiple, GVL-canal-caché, internes traversés ;
- le FB a dérivé du contrat `AF_Partie-03` et accumule des responsabilités ;
- comprendre l'existant coûte **autant** que le réécrire.

En cas d'hésitation → **patch par défaut** : il est réversible, le rebuild beaucoup moins.

### 🧱 Séquence rebuild (obligatoire si stratégie = rebuild)

```text
1. Inventaire du périmètre    → G200_check_linkage.py donne les consommateurs
2. CONTRAT DE CONSERVATION    → ce qui doit survivre / ce qu'on abandonne sciemment
   ⛔ arrêt : validation humaine du contrat AVANT toute suppression de lien
3. Nouveau FB, interface propre
4. Remap des consommateurs
5. Preuve de non-dégradation  → chaque ligne du contrat vérifiée
6. Suppression de l'ancien    → G200_check_linkage.py prouve zéro orphelin
```

⚠️ **Écrire ce qui doit survivre AVANT de couper.** Sans ce contrat écrit en amont,
« pas de dégradation » n'est qu'une impression.

## 📝 Contrat de tâche — la référence de toute vérification

> REX 2026-07-29 : sur 53 tâches déléguées, les critères d'acceptation étaient **3 phrases
> génériques** réutilisées telles quelles. Un agent rendait donc un rapport « conforme » à rien.
> Une vérification qui ne porte sur aucun objectif reste creuse, même rendue obligatoire.

Rédigé par l'**orchestrateur**, **avant la première écriture du livrable** ou sa délégation.
Obligatoire dès **C2**.

**Dispensés de contrat préalable** (définition unique, les autres documents y renvoient) :
investigation et diagnostic en lecture seule, analyse de traces, tests ad hoc
`TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/`, scripts locaux dans `TOOLS/`.

**Jamais dispensés** : toute écriture dans `CODE/`, y compris pour instrumenter un diagnostic ;
`TOOLS/CONVERTER_ST2XML_PLCopenXML/`, les gates et les hooks, car ils produisent ou contrôlent ce
qui part sur la machine ; tout sujet safety.

⚠️ Une dispense de contrat n'est pas une dispense d'accord : l'action reste demandée par
l'utilisateur et dans le périmètre.

- Gabarit : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`
- Emplacement canonique : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_<id>.yaml`, référencé depuis `TASKS.yaml`
- Contrôle : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier>`

Il porte : objectif métier · **critères testables** (chacun avec son `verified_by`) · périmètre
autorisé/interdit · contrat de conservation si rebuild · preuves attendues · modèles autorisés ·
devoir d'alerte.

🧱 Si `contract.scope.allowed` touche `CODE/MAIN/`, deux critères sont obligatoires :
1. nom de fichier = nom du POU ;
2. suffixe de langage = langage généré dans le bundle.

`check_task_contract.py` contrôle ces critères **dans le contrat** (T8), avant toute
écriture. `G310_check_code_structure.py` contrôle ensuite leur réalité dans le code et le bundle.

🔁 Le contrat est un artefact lisible par tous les runtimes. Les hooks, quand ils existent, sont
spécifiques à leur outil et ne remplacent ni le contrat ni une revue de pertinence.

## 🔀 3 Voies selon criticité

### ⚡ Fast Lane — C0-C1
> Typo, renommage, doc, param mineur, refactor sans impact safety.

```text
Besoin cadré → action proportionnée → vérification adaptée → restitution concise
```
- Pas de multi-modèle, pas de REGISTRE, pas de revue complémentaire.
- Gate 5 (compilation CODESYS) optionnel.

### 🔵 Standard Lane — C2-C3
> Nouveau FB, évolution feature, mouvement/interlock.

```text
Contrat ciblé → plan et autorisations → exécution → contrôles correspondant aux critères → restitution
```
- Le contrat est requis dès C2 (dispenses : § Contrat de tâche). Un registre ou `TASK_CONTEXT.yaml` n'est ajouté que si le suivi
  apporte une information qui ne tient pas déjà au contrat et au catalogue.
- Une revue indépendante est choisie selon le risque, un contrat, une anomalie ou une demande
  explicite ; elle n'est pas un rituel après chaque sous-tâche.
- Après un GO explicite sur un plan, l'exécutant peut terminer le périmètre approuvé sans demander
  une autorisation à chaque édition. Extension de périmètre, action externe, commit/push ou étape
  explicitement réservée restent hors de ce GO.

### 🔴 Safety Lane — C4 (et C3 safety détectée)
> AU, PowerCutOff, SafeStop, frein, contacteur, redondance, homing safety, FAT/SAT.

```text
hook PreToolUse (bloque si specs non lues)
→ CONTRAT DE TÂCHE unique (obligatoire ; inclut critères, risques et approche de test)
→ ⚠️ ALERTE RISQUES explicite
→ 🔴 DOUBLE AVIS AGENTS NATIFS PARALLÈLES A/B (ex. antigravity + Codex, read-only, même contexte, sans se voir)
→ synthèse : consensus ✅ / divergence 🚨
→ **validation humaine obligatoire : contrat, plan et décision safety**
→ Code ST (High Effort, un seul exécutant)
→ Gates → hook Stop (bloque si liaison rouge) → CODESYS import → simulation CODESYS manuelle → Terrain
```

## 🔴 Règle Double Revue Parallèle (C4)

- **Scope** : revue du contrat et du plan, puis du ST généré ou du livrable safety C4.
- **Méthode B — Parallèle** : les 2 agents reçoivent **exactement le même contexte**, sans connaissance du résultat de l'autre.
- **Résultat** :
  - Consensus (aucun blocage contradictoire) → synthèse présentée à l'humain.
  - Divergence (≥1 point contradictoire) → 🚨 alerte humain + résumé des 2 positions côte à côte.
- **Les agents ne commitent pas et ne modifient pas le code.**
- Ponytail interdit sur toute analyse safety.

Un fichier `TEST_DESIGN.md` ou `TASK_CONTEXT.yaml` séparé n'est ajouté que si le volume ou la
structure du contenu empêche de le maintenir lisiblement dans le contrat. Le registre ne duplique
pas la tâche : il suit seulement une coordination ou délégation qui mérite un état séparé.

## 🏷️ Qualification criticité

L'orchestrateur qualifie. Une validation humaine est demandée aux points d'arrêt prévus par la
criticité, le contrat ou la sécurité ; elle n'est pas un rituel pour les tâches simples.

| Niveau | Exemple | Artefacts |
|---|---|---|
| C0 | format, typo | Aucun artefact ; vérification simple |
| C1 | documentation non-safety | Aucun artefact par défaut ; revue seulement si utile au livrable |
| C2 | code métier | Contrat avec critères vérifiables ; registre si coordination utile |
| C3 | mouvement/interlock | Contrat avec preuves/tests ; revue selon risque, anomalie ou demande |
| C4 | safety critique | Contrat, alertes, revue A/B et décision humaine ; annexe si nécessaire |

## Règles générales

- 🎯 **L'orchestrateur désigné reste propriétaire du résultat** : phasage, arbitrage des scopes,
  lecture du `git diff` réel et acceptation finale. Les droits Task Manager sont définis dans la
  skill canonique `skills/task-planner/SKILL.md`. Il délègue en priorité
  les investigations longues/répétitives et les revues indépendantes, pas sa responsabilité.
- 🛠️ **Un responsable principal et un seul écrivain par scope de fichiers.** Le responsable peut
  solliciter des spécialistes pour challenger son plan ou relire son diff ; ces reviewers restent
  read-only. Procédure C3/C4 :
  `TOOLS/AGENT_WORKFLOW/skills/orchestrator/references/delegation_c3_c4.md`.
- 📌 Toute délégation significative reçoit un brief basé sur
  `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`, complété avec demande d'origine, contexte,
  preuves, critères mesurables, rôle, périmètre, permissions, alertes attendues et auto-revue.
- 🤖 **Aucun lot n'est restitué sans `G200_check_linkage.py --report`.** Bundle généré et tests Python
  verts ne prouvent jamais qu'une fonction est reliée.
- `TOOLS/` reste séparé de `DOC/` et `CODE/`.
- `CONVERTER_ST2XML_PLCopenXML` reste autonome ; le workflow peut l'appeler pour générer le bundle `CODE_XML/CODE_Bundle.xml` à partir des sources ST et des POU XML natifs/CFC présents dans `CODE/`.
- Les agents ne modifient pas le XML final du bundle à la main ; ils préservent les sources ST/XML natif/CFC et la cohérence des interfaces, noms et références avant génération.
- `OUTILS_ST2PY` est un outil externe de simulation et de tests hors-PLC ; il sert à valider la logique et la non-régression, mais ne remplace ni la compilation CODESYS ni les essais terrain.
- Les scripts déterministes vérifient avant l'avis des modèles.
- Aucun commit automatique — validation humaine obligatoire.
- Toute modification safety exige une validation humaine.
- Ponytail est interdit dès qu'un sujet safety, norme ou redondance est détecté.
- Les reviewers restent read-only. Un avis indépendant est lancé quand le risque ou la valeur
  discriminante le justifie ; tout avis lancé est lu et synthétisé avant de conclure.

## 🕵️ Diagnostic / Recherche de blocage

> Déclenché par « cherche le blocage », « pourquoi ça bloque », « diagnostic », « troubleshooting ».
> Skill : `.claude/skills/troubleshooting/SKILL.md` · Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`
> Fiches utiles : `DOC/WFLOW/TROUBLESHOOTING/` (gabarit existant).

1. Créer/mettre à jour une fiche si l'investigation est multi-étapes, récurrente, déléguée,
   safety-related ou si une preuve durable est nécessaire ; sinon répondre directement.
2. Lire les éléments disponibles. Demander seulement les données absentes qui changent la
   décision ; poursuivre en parallèle toute analyse indépendante.
3. **Méthode** : caractériser le symptôme → arbre des causes utile au cas → traçage inverse →
   élimination par preuve (lecture `GVL_Troubleshooting` lorsque pertinent, jamais forcer).
4. **Critère d'arrêt** : cause racine prouvée, ou frontière au-delà du PLC, ou étape suivante = modifier/forcer → **hand-off humain**.
5. **Règle `fix:` + `guard:`** : toute cause racine confirmée donne correction **et** garde-fou (cf. double boucle ci-dessous).
6. **Ne jamais modifier le code ni forcer une variable sans autorisation et procédure explicites.**

## 🔄 Règle d'apprentissage continu (Double boucle)

Toute erreur détectée — **à n'importe quelle étape** (édition, gate, compilation, test, audit, terrain) — déclenche **deux actions** :

1. **`fix:`** — Correction locale de l'erreur (code, doc, config)
2. **`guard:`** — Garde-fou technique ajouté dans `TOOLS/AGENT_WORKFLOW/scripts/` ou templates pour que **cette classe d'erreur soit détectée automatiquement plus tôt** la prochaine fois

### Exemples de correspondance

| Origine erreur | Garde-fou ajouté |
|---|---|
| **Instance déclarée jamais appelée (`PRG_10_Outputs_LD`, 2026-07-29)** | **`G200_check_linkage.py` — gate 2bis + hook PostToolUse** |
| **Nom de fichier/POU ou suffixe/langage incohérent (audit 2026-08)** | **`G310_check_code_structure.py` — gate 1bis + tests unitaires** |
| **CFC natif aux fils invisibles (connecteurs empilés/à 0,0)** | **`G210_check_cfc_wiring.py` — gate 2bis-bis** |
| **Consignes pointant des specs supprimées** | **`G340_check_doc_links.py` (+ `--fix` automatique)** |
| **Document amputé de sa tête sans être vu (`NAMING_CONVENTION`)** | **`G340_check_doc_links.py` D6 — titre H1 obligatoire** |
| Compilation CODESYS C0037 | Règle `G100_check_code_style` détection écriture VAR_OUTPUT |
| Oubli homme-mort boutons | Pattern `StartStop.*DeadmanArmed` obligatoire |
| FDC sans rampe | Template `motion_fb_header` section FDC_EXTRÊMES |
| Bit safety non classifié | Template `requirement_intake` champ `safetyClassification` |
| Struct IHM incomplète | Script `doc_sync` compare AF07 ↔ CODE/SUPERVISION |

### Processus

```text
Erreur détectée
    ↓
Analyse cause racine (5 pourquoi)
    ↓
fix: correction immédiate
guard: gate/template/script ajouté dans TOOLS/
    ↓
Validation : gate suivant attrape la régression
    ↓
Commit unique : fix + guard ensemble
```

## Entrées

- `CODE_CHANGE` : modification issue du programme ou d'un bug identifié.
- `NEW_INFORMATION` : donnée client, réunion, chantier, essai ou observation terrain.

`NEW_INFORMATION` passe obligatoirement par le refinement avant toute modification DOC/CODE.

## Criticité

| Niveau | Exemple | Traitement |
|---|---|---|
| C0 | format, typo | aucun artefact ; contrôle ciblé |
| C1 | documentation non-safety | aucun artefact/review par défaut ; contrôle selon le livrable |
| C2 | code métier | contrat avec critères vérifiables et tests adaptés |
| C3 | mouvement/interlock | preuves/tests ciblés ; revue selon risque, contrat ou anomalie |
| C4 | AU, PowerCutOff, redondance | contrat, revue A/B, plan et décision humaine ; Ponytail interdit |

---

## 📐 Formats de Restitution & Personas Spécialisés

Tout rapport d'audit, revue de code ou évaluation par un agent ou sous-agent respecte le standard :
- **Spécification de restitution** : [`AGENT_OUTPUT_STANDARD.md`](AGENT_OUTPUT_STANDARD.md).
- **Structure TDAH unifiée** : Bannière Niveau 0 avec métrique de durée (`⏱️ Durée : X.Xs`), Grille Niveau 1 en **liste numérotée sans tableau Markdown**, Argumentaire technique concis mais non bridé, et Plan d'action Niveau 2 relié aux scripts déterministes de `TOOLS/`.
- **Catalogue des Prompts Markdown** : [`DOC/WFLOW/PROMPTS/SPECIALISTS/`](../../DOC/WFLOW/PROMPTS/SPECIALISTS/) (visualisation CLI : `python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --list-prompts`).
- **Arène Dialectique & Devil's Advocate** : [`challenge_runner.py`](../scripts/challenge_runner.py) avec Étape 0 de cadrage préalable obligatoire (Anti-Garbage-In).

---

## 🛡️ Commits — accord humain explicite

Aucun commit n'est automatique : appliquer la règle d'`AGENTS.md` et obtenir un accord humain
explicite avant tout commit. Si l'accord est donné, un checkpoint `wip(scope): ... [NON TESTE]`
peut précéder des tests longs ; après validation, un commit final peut enregistrer les résultats.
Sans accord, laisser le travail dans le checkout et restituer le diff, les vérifications et l'état.

RÔLE : Red Team. QUESTION : comment la V2 (§E) échouera-t-elle en pratique ? Cherche les risques indirects non évidents : agents multiples en parallèle, compaction de contexte, agent qui ment sur sa lecture, Codex/Antigravity sans hooks, fatigue de l'opérateur, faux blocages qui poussent à contourner. Pour chaque risque : scénario concret + parade minimale.

Lis le DOSSIER ci-dessous (seule source ; tu n'as aucun outil). Règles de sortie strictes : français ; 30 lignes max ; aucune flatterie ; chaque point numéroté porte [FAIT §x] (citation du dossier) ou [HYPOTHÈSE] ; une affirmation sans source est interdite ; termine par 'DÉCISION :' en 3 lignes max.

# DOSSIER COMMUN — Collège d'experts workflow agents (projet automate CODESYS, machine de dragage réelle, sécurité machine)

## A. ANCIEN WORKFLOW — section AGENTS.md « Démarrage de session — briefing obligatoire » (présente jusqu'au commit 2a5bf86d du 2026-11-01, supprimée par un commit WIP intitulé « prototype advisory task tracking »)
## 🎬 Démarrage de session — briefing obligatoire

> Concerne **tout agent** (Claude Code, Codex, Antigravity, autre) et tout humain qui reprend le projet —
> `AGENTS.md` est la source unique commune à tous les outils.

**Déclenchement** : automatique au 1er message de toute session sur ce repo. Rejouable à la
demande à tout moment (« rappelle-moi le briefing workflow » ou équivalent) — même séquence.

**Séquence de Restitution Obligatoire :**
0. **Afficher immédiatement la bannière de briefing** (format standard, gabarit
   `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md`) :
   ```text
   ============================================================
   🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
   ============================================================
   ```
   Puis 1 ligne : *« Briefing session <projet> — reprise par <agent> »*.

1. **Restituer le tableau des 2 skills actives du projet** :
   - `task-planner` : Pilotage catalogue `TASKS.yaml` & contrats `CONTRACTS/` · Déclencheur : « planifie tâche », « état des tâches », « tasks ».
   - `troubleshooting` : Diagnostic formel, arbre de causes & traçage inverse · Déclencheur : « cherche le blocage », « diagnostic », « panne ».

2. **Snapshot rapide de [DOC/WFLOW/TASKS.yaml](DOC/WFLOW/TASKS.yaml)** : nombre de tâches
   verrouillées 🔒 / en cours ⏳ / à faire ⬜.

3. **Preuve de repérage des 3 piliers projet (Niveau 1 — systématique)** :
   - 📐 **Standards & Guides (`DOC/STDS/`)** : `CODE_QUALITY_STANDARDS.md` (POO, encapsulation), `NAMING_CONVENTION.md` (PascalCase, NC-010..080, zéro Ref pour consignes), guides (`GUIDE_GATES_ET_TESTS`, `GUIDE_SEQUENCEUR`, `GUIDE_IDE_CODESYS`, `GUIDE_TEST_HEADLESS_CODESYS`).
   - 🏗️ **Architecture & Specs (`DOC/AF/` & `CODE/`)** : Architecture 7 POU (`PRG_02_Acquisition` ➔ `PRG_07_Supervision`, tâches 4ms/20ms/10ms), Fondations (AF01-03), Transverses (AF04-06), Métiers (AF08-14).
   - 🛠️ **Outillage CI/CD & Validation mécanique (`TOOLS/`)** : Bundle PLCopenXML (`generate_codesys_bundle.py`), Vérification liaison bloquante (`G200_check_linkage.py`), Suite de 21 Gates (`run_all_gates.py`), Tests unitaires CI (`TOOLS/TEST_AUTO_CI/`).

4. **Diagramme du Workflow Standard d'Implémentation** :
   ```text
   1. Cadrage & Tâche (ID, criticité C0-C4, stratégie Patch / Rebuild)
      ↓
   2. Contrat de tâche (Objectifs testables, scope, critères d'acceptation — obligatoire dès C2)
      ↓
   3. Plan technique & Validation humaine (Arrêt obligatoire avant de toucher au code)
      ↓
   4. Implémentation ST (Respect AF_Partie-02/03 + NAMING_CONVENTION)
      ↓
   5. Gates mécaniques bloquants (G200 Liaison, G310 Structure, Bundle XML, 21 Gates)
      ↓
   6. Restitution (Bandeau de conformité + intégration CODESYS manuelle par tes soins)
   ```

5. **Cas pratique & Justification de conception (Niveau 2 — Anti-Récitation)** :
   - L'agent ne doit jamais réciter des phrases génériques apprises par cœur.
   - Sur toute question de nommage, d'architecture ou de variable, il doit **justifier son cheminement technique** : citer la règle exacte (`NC-xxx`), nommer la documentation source (`NAMING_CONVENTION.md`, `AF_Partie-xx`), et expliquer la sémantique de la chaîne (`Req` ➔ `Tgt` ➔ `Cmd` ➔ `Act`).

6. **Proposer les options d'action réelles (Menu de démarrage)** :
   - 🔹 **Option 1 : Tâche du catalogue (`task-planner`)** — Sélectionner et verrouiller une tâche existante de `TASKS.yaml`.
   - 🔹 **Option 2 : Dépannage / Diagnostic (`troubleshooting`)** — Lancer une analyse causale structurée sur un blocage ou un comportement inattendu.
   - 🔹 **Option 3 : Cadrer un nouveau besoin / refactor** — Qualifier la criticité (C1..C4), rédiger le contrat `TASK_CONTRACT_*.yaml` et planifier.
   - 🔹 **Option 4 : Contrôle outillage & Gates** — Exécuter la suite complète des 21 gates (`run_all_gates.py`) ou un audit mécanique spécifique.

---

## 🎯 Avant de coder — lire dans cet ordre

## B. CE QUI L'A REMPLACÉ (AGENTS.md actuel, § Démarrage)
## 🧭 Démarrage — consignes selon la demande

Lire ce fichier comme source commune des règles. Identifier le rôle attendu (orchestrateur,
exécutant délégué ou reviewer), le résultat demandé et le périmètre avant d'agir. Ne pas dérouler
un briefing complet, un inventaire du dépôt ou un menu d'options sans utilité pour la demande.

**Références à charger selon le besoin :**

| Besoin | Référence à charger |
|---|---|
| Pilotage ou délégation | `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md` |
| Édition du catalogue des tâches | `TOOLS/AGENT_WORKFLOW/skills/task-planner/SKILL.md` |
| Diagnostic d'un incident | `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md` |
| Changement CODESYS/ST | Standards, architecture et spécification métier concernés |
| Autre demande | Seulement les règles et fichiers directement pertinents |

### Gestion du Task Manager

## C. AUTRES PERTES MESURÉES DEPUIS 2026-10-15 (git)
- orchestrator/SKILL.md 385 -> 369 lignes ; sections retirées : BANNIÈRE DE DÉCLENCHEMENT (OBLIGATOIRE), Résumé rapide post-bannière, mode d'emploi du registre TASKS_ORCHESTRATOR.
- troubleshooting/SKILL.md 167 -> 70 lignes ; retirés : RÈGLE D'OR, BANNIÈRE OBLIGATOIRE, ORIENTATION MÉTHODE, Procédure étapes 0 à 4ter (fiche de session, contexte figé, indices, symptôme, arbre des causes, acquisition par SNAPSHOT, test CI ad hoc). Possiblement déplacé dans prompts/troubleshooting.md : NON VÉRIFIÉ.
- task-planner : retiré le titre « Protocole obligatoire avant toute écriture dans TASKS.yaml » (règle reformulée pour le coordinateur).
- 2026-11-03 (e06047d1) : retiré « l'agent DOIT interpeller et poser des questions » ; ajouté « action demandée, locale, réversible : la faire sans question ».
- AGENTS.md 04->13/11 : délégation Ollama passée de « uniquement sur demande explicite » à « utilisable par défaut ».

## D. MÉCANISMES RÉELS (vérifiés)
- Hooks Claude (.claude/settings.json) inchangés depuis août : PreToolUse matcher Edit|Write|MultiEdit -> hook_pre_edit.py (bloque l'écriture dans CODE/ si CODE_QUALITY_STANDARDS, NAMING_CONVENTION et la spec AF n'ont pas été lus via l'outil Read dans le transcript ; laisse passer si transcript illisible) ; PostToolUse -> G200 liaison et G340 liens doc après édition ; Stop -> empêche de déclarer un lot terminé si liaison rouge. Aucun hook de démarrage n'a jamais existé.
- Les écritures par Bash ne passent pas par le hook. Codex/Antigravity : aucun hook configuré dans le dépôt. Hook git pre-commit existant = garde de portée sur fichiers partagés (pre_commit_scope.py). git commit --no-verify le contourne.
- CLAUDE.md importe @AGENTS.md (injection automatique pour Claude, n'apparaît pas comme un Read). Codex lit AGENTS.md nativement.
- Volumes : AGENTS.md 26,5 Ko (364 lignes) ; TASKS.yaml 725 Ko, 231 tâches dont 150 ouvertes ; résumé id+statut+agent+titre des ouvertes = 17,7 Ko ; DOC/README.md 6,7 Ko. L'outil Read tronque à 2000 lignes par défaut.
- Superviseur de sessions : une affectation T427 a disparu après transfert ; une session T000-CC10 non voulue est apparue. Les commandes /rename-session et /connect-session-supervisor ont échoué ou se sont contredites.

## E. NOUVELLE PROPOSITION À CHALLENGER (V2 « Entonnoir réflexe »)
- Portée : 1er message de session ou après compaction. Exemption : sous-agent délégué (subagent_preamble.md) ou reviewer pur.
- Étape 1 Survol du socle léger, lu intégralement : AGENTS.md + DOC/WFLOW/TASKS_ACTIVE_SUMMARY.md (généré par script, tâches ouvertes) + DOC/README.md. Verrou : blocage fail-closed des écritures sous Claude tant que les 3 fichiers ne sont pas lus ; pre-commit git commun (check_workflow.py, à créer).
- Étape 2 Tri de l'intention : flou -> questionner ; objectif incomplet -> reformuler et demander précision sans toucher CODE/ ni périmètre sous contrat ; clair -> étape 3.
- Étape 3 Aiguillage sur 4 voies : Réponse directe (question ou action locale réversible) ; Orchestrator ; Task ; Troubleshooting — charger uniquement la SKILL.md canonique.
- Liaison superviseur : pointeur par ID natif de session (.agent/sessions/<ID>.json) écrit par hook/script, sans /rename-session.
- Défauts déjà relevés par une revue : socle réel ≈ 51 Ko et non 10 ; résumé 17,7 Ko et non 3 ; @import de AGENTS.md non vu comme Read -> faux blocage ; Bash contourne ; fail-closed = panne générale si format transcript change ; fraîcheur du résumé non déclenchée ; le hook ne connaît pas le TASK_ID ; .agent/ = nouveau dossier racine interdit par la règle de routage T279 ; « DOC/WFLOW sous contrat » contredit WORKFLOW.md ; pas de marqueur pour reconnaître un sous-agent.

## F. CONTRAINTES UTILISATEUR
Un seul workflow commun à tous les agents (Claude, Codex, Antigravity, DSH), branches guidées ; simple à installer ; très fiable ; ne perdre ni les bonnes idées ni la qualité/sécurité de l'ancien ; ne pas cramer les tokens ; l'utilisateur constate que depuis peu les agents ne lisent plus les documents au démarrage.

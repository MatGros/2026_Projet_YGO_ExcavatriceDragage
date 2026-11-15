# Notice — Orchestrateur projet (brouillon v0.1, 2026-11-14)

> Notice d'usage, comme pour un produit : ce que fait l'orchestrateur, ce qu'on peut lui demander,
> ce qu'il lance lui-même, et ce qui manque. Brouillon à challenger, non validé.

## 1. Rôle

- Un seul orchestrateur actif dans le projet.
- Il tient le planning et les affectations, fixe les périmètres pour éviter les conflits, et
  relie les sessions entre elles.
- Il ne code pas les gros lots. Il ne valide jamais son propre travail.

## 2. Ce que l'humain lance (et qui fait appel à l'orchestrateur)

- `/workflow-project 1` : entrer en voie Orchestrateur. **Existe**.
- `/workflow-project-orchestrator` : lancement direct du rôle. **N'existe pas** (chantier O1).
- « pilote ce lot », « délègue », « challenge cette proposition » : déclenchent la skill `orchestrator`. **Existe**.
- « état des tâches » : lecture du catalogue. **Existe** (skill `task-planner`).
- `/connect-session-supervisor`, `/review-session-supervisor` : suivi par le Superviseur. **Existe**.

## 3. Ce que l'orchestrateur lance lui-même

- Sous-agents de lecture, revue ou challenge (Ollama par défaut, agents natifs sinon). **Existe**.
- Workflow dynamique pour un sprint (outil Workflow, si activé). **Exigence notée** (plan §15).
- Messages vers d'autres sessions (`SendMessage`) selon la procédure de secours. **Existe**, intégré le 2026-11-14.
- Gates et contrôles (`run_all_gates.py`, `G200`, `check_task_contract.py`). **Existe**.
- Écriture du catalogue et des verrous, uniquement via le Task Manager. **Existe**.

## 4. Moment « je gère qui, quoi ? »

Au premier message, l'orchestrateur :
1. se présente (rôle, session, humain qui pilote) ;
2. demande quelles sessions et quelles tâches il pilote ;
3. selon la réponse de l'humain :
   - « pas maintenant » → il n'en contacte **aucune** et l'indique en une ligne ;
   - une liste de sessions → il les relie (consigne courte, accusé attendu, une seule relance).

**État** : les points 1 et 3 sont écrits dans la procédure de secours. Le point 2 (la question
explicite « je gère qui, quoi ? ») n'est écrit **nulle part**.

**Précisions issues du challenge (à valider)**
- **Point d'entrée du premier message** : aujourd'hui `/workflow-project 1` (seul chemin garanti) ;
  demain `/workflow-project-orchestrator` (O1).
- **Après désignation** : l'acte est l'envoi d'une consigne par `SendMessage` à chaque session
  désignée (rôle, objectif, interdits, demande d'accusé). Test : un accusé horodaté par session,
  0 session sans accusé après la relance unique.
- **Après « pas maintenant »** : proposition, ne pas redemander d'office ; reposer la question
  seulement si l'humain la relance ou si une tâche exige une coordination. À trancher.
- **Test de la question** : la phrase « je gère qui, quoi ? » présente une seule fois dans la skill.

## 5. Visibilité dans le Superviseur

- **Besoin** : voir le prompt de l'orchestrateur dans le Superviseur, à côté des autres agents.
- **État** : les 6 personas spécialistes ont leur prompt (`DOC/WFLOW/PROMPTS/SPECIALISTS/`).
  L'orchestrateur n'y a pas de prompt dédié. **Absent**.

## 6. Écarts entre les besoins exprimés et l'existant

- [X] Commande directe `/workflow-project-orchestrator` : absente (O1, bloqué faute de GO).
- [X] Fiche de rôle courte (`roles/orchestrator/ROLE.md`) : absente (O3, bloqué faute de GO).
- [X] Question « je gère qui, quoi ? » au démarrage : non écrite.
- [X] Prompt de l'orchestrateur visible dans le Superviseur : absent.
- [X] Lecture approfondie à l'entrée du rôle (nommage, AF, outils) : notée (plan §11), non faite.
- [!] Deux sessions portent le même nom « T000-CC10 » : messages ambigus.
- [!] Le choix « 1 » en message libre n'est pas garanti : seule la commande `/workflow-project 1` l'est.
- [OK] Procédure d'échange entre sessions : intégrée à la skill.
- [OK] Messagerie entre sessions : prouvée par accusés (2026-11-14).

## 7. Futures fonctionnalités (feuille de route)

- **F1 · Commande `/workflow-project-orchestrator`** — NO-GO. Déblocage : GO T000-CC10 + les 3 oui/non du cadrage v2.
- **F2 · Fiche de rôle `roles/orchestrator/ROLE.md`** — NO-GO. Même déblocage (O3).
- **F3 · Question « je gère qui, quoi ? »** — à écrire dans la skill. Déblocage : validation du §4.
- **F4 · Prompt orchestrateur dans le Superviseur** — à concevoir avec l'agent du Superviseur (T429).
  Déblocage : accord exploitant sur l'emplacement (`DOC/WFLOW/PROMPTS/`).
- **F5 · Lecture approfondie à l'entrée du rôle** — plan §11. Déblocage : F2 livrée.
- **F6 · Workflow dynamique par sprint** — plan §15. Déblocage : F2 livrée.

- **F7 · Veille proactive (procédure §5bis, souple)** — INTÉGRÉE à la skill orchestrateur le 2026-11-15 (GO T000-CC10 sur demande exploitant) ; volet coordinateur en attente de F2.
  L'agent note ce qu'il attend, se réveille une fois (ex. 25 min), se rend compte si rien n'a changé,
  agit ou remonte à l'humain sinon. Coordinateur : même veille sur ses sous-agents, une demande par cycle.
  Cibles : skill orchestrateur, fiche coordinateur (F2). Sans rigidité. Déblocage : GO T000-CC10.

## 8. Historique

- v0.1 (2026-11-14) : brouillon ; challenge Ollama (glm-5.3) → « À COMPLÉTER » ; ajouts §4 et §7.

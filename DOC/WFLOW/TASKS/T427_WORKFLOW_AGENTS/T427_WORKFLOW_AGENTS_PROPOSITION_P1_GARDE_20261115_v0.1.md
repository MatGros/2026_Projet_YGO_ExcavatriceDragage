# Proposition P1 — Correction du garde de périmètre (v0.1, 2026-11-15)

> Proposition seulement. **Aucun garde-fou n'est modifié** : `task_scope.py` et `hook_scope_guard.py`
> sont dans la liste d'interdiction absolue, et l'agent ne réécrit pas ses propres garde-fous sur un
> GO relayé par une autre session. Application : sur confirmation directe de l'exploitant.

## 1. Ce que dit le code (lu le 2026-11-15)

- `hook_scope_guard.evaluate()` l. 64-71 : **premier contrôle** = `is_absolute_denied(chemin, périmètre épinglé)`.
  Si le chemin est interdit et non couvert par le périmètre épinglé du contrat → **refus**, avant toute dérogation.
- l. 94 : `classify()` rappelle `is_absolute_denied(relative)` **sans** le périmètre épinglé
  (`task_scope.py` l. 244-246) → un chemin pourtant autorisé par le contrat (ex. `skills/orchestrator/`) est classé « hors ».
- l. 99-101 : un chemin « hors » dérogé est **autorisé**.
- `task_scope.py` l. 591 : `--motif` facultatif (`default=""`).

## 2. Correction du constat bloquant de la revue

- [X] **« Une dérogation lève CODE/** » est faux pour T427** : `CODE/**` n'est pas dans le périmètre
  épinglé de T427, donc le contrôle l. 68 refuse **avant** la dérogation. La revue (relecteur et
  contradicteur) a manqué ce premier contrôle.
- [OK] **Défaut réel n° 1** : `classify()` ignore le périmètre épinglé → les chemins protégés que le
  contrat autorise exigent une dérogation (c'est ce qui a bloqué `skills/orchestrator/`).
- [OK] **Défaut réel n° 2** : motif de dérogation vide accepté, et texte libre écrit par l'agent.
- [OK] **Défaut réel n° 3** : le registre des dérogations est écrit par l'agent (CLI + `%LOCALAPPDATA%`).

## 3. Correctif proposé

1. `classify(relative, product, forbidden, process, pinned_allowed=None)` → `is_absolute_denied(relative, pinned_allowed)` ;
   `evaluate()` lui passe le périmètre épinglé.
2. **Interdiction dure** (aucune dérogation ne la lève) : `CODE/**`, `CODE_XML/**`, `PRJ_CODESYS/**`
   et les fichiers de garde. Testée **avant** `is_derogated()`.
3. `deroge` : `--motif` **obligatoire et non vide**, remplacé par `--citation "<texte exact>"` ; le script
   vérifie que la citation figure **mot pour mot** dans un message `user` du transcript de la session.
   Sinon : refus. L'agent ne peut plus reformuler.
4. Tests (`test_workflow_backlog.py`, garde-fous fix+guard) :
   - écriture `CODE/x.st` + dérogation présente → refusée ;
   - écriture `TOOLS/AGENT_WORKFLOW/skills/orchestrator/x.md` sous contrat T427 → autorisée, sans dérogation ;
   - `deroge` sans motif / motif vide → refus ;
   - `deroge` avec une citation absente du transcript → refus.

## 4. Point à trancher AVANT d'appliquer (risque de régression)

- [?] « `CODE/**` refusé **sans exception** » : un **contrat PLC** dont le périmètre épinglé autorise
  `CODE/…` reste-t-il permis ? Si l'interdiction est totale, plus aucune tâche PLC ne peut écrire
  dans `CODE/` (régression critique). Proposition : interdiction totale pour les **dérogations**,
  mais le **périmètre épinglé** d'un contrat PLC validé reste valable (comportement actuel l. 68).

# 🧭 Workflow projet — Besoins vs Réalité

> 🎯 **Objectif** : chaque point part d'un **besoin utilisateur** réel, puis montre la **réalité constatée**, puis impose une **preuve** qui répond au besoin.
> 🚫 Pas de tests pour tester. Un test = un besoin vérifié.
> 🔁 Chaque scénario doit pouvoir être **rejoué à l'identique** par l'exploitant.

---

## 1. 🚀 Lancer le workflow et avancer

- 🧑 **Besoin** : taper `/workflow-project`, puis que l'orchestrateur **propose et fasse avancer**, sans attendre.
- ❌ **Réalité** : le menu s'affiche, puis l'orchestrateur reste en attente de choix. Aucune proposition concrète.
- 🧪 **Scénario à rejouer** :
  1. Nouveau chat.
  2. `/workflow-project fresh`.
  3. Choisir `1` (Orchestrateur).
  4. Demander : « Quelle est la prochaine action utile ? »
- ✅ **Preuve attendue** : une action concrète proposée dans la réponse, avec sa cible (fichier, tâche ou commande). Pas de simple question.

---

## 2. 📚 Lire les règles au démarrage

- 🧑 **Besoin** : chaque chat démarre avec `AGENTS.md` et le résumé du catalogue lus.
- ❌ **Réalité** : le menu affiche « AGENTS.md : présent », mais rien ne prouve la lecture.
- 🧪 **Scénario à rejouer** :
  1. Nouveau chat.
  2. `/workflow-project fresh`.
  3. Demander la liste exacte des fichiers lus.
- ✅ **Preuve attendue** : la liste des fichiers ouverts, avec leur heure de lecture, affichée dans la réponse.

---

## 3. 🏷️ Renommer la session avec un titre cohérent

- 🧑 **Besoin** : `T000-CC10` + un titre clair, visible dans l'onglet et dans le Superviseur.
- ❌ **Réalité** :
  - `/rename-session` sans paramètre échoue (« Paramètre manquant », code 2).
  - Les refus (codes 4 et 1) ne s'affichent pas dans Claude Code. 🔎 Hypothèse : le motif part sur stderr, non restitué.
  - Le titre terminal et le titre du chat passent par des mécanismes différents, non vérifiés à l'écran.
- 🧪 **Scénario à rejouer** :
  1. Session déjà reliée au Superviseur.
  2. `/rename-session T000-CC10 MULTITASK ORCHESTRATOR AGENT`.
  3. Regarder l'onglet VS Code et le titre du chat.
  4. Relancer sans paramètre.
- ✅ **Preuve attendue** : capture ou description visuelle du titre après l'étape 2 ; message clair à l'étape 4 (reprise de l'alias existant, ou refus explicite avec la raison).

---

## 4. 🔗 Relier une session au Superviseur

- 🧑 **Besoin** : relier la session **à la main, en direct**, sans la commande bugguée.
- ❌ **Réalité** : le script `connect_session.py` a été lancé alors que l'exploitant avait demandé le manuel. Alarme fc75343c ouverte.
- 🧪 **Scénario à rejouer** :
  1. Nouvelle session.
  2. Demander la liaison **manuelle**.
  3. Vérifier que le script n'est pas lancé.
  4. Vérifier le statut dans le Superviseur.
- ✅ **Preuve attendue** : statut `attached` visible dans le Superviseur, avec la voie utilisée (manuelle).

---

## 5. 📋 Copier la dernière réponse

- 🧑 **Besoin** : copier la dernière réponse **sans sélection manuelle**, sur Claude, AGY et Codex.
- ❌ **Réalité** :
  - Claude : `/copy` fonctionne. Raccourci `Ctrl+Alt+C` → envoie `/copy` + Entrée : OK sur Claude et AGY.
  - Codex : `Ctrl+O` copie la dernière réponse. `/copy` n'existe pas comme commande.
  - `Ctrl+Alt+C` sur Codex tape `/copy` sans l'exécuter.
- 🧪 **Scénario à rejouer** :
  1. Dans chaque CLI, produire une réponse.
  2. Appuyer sur le raccourci propre à la session (Claude/AGY : `Ctrl+Alt+C` ; Codex : `Ctrl+O`).
  3. Coller dans un éditeur.
- ✅ **Preuve attendue** : le texte collé correspond à la dernière réponse, sans sélection manuelle.

---

## 6. 🗂️ Suivi Task Manager à jour

- 🧑 **Besoin** : chaque état d'agent reçu est reporté au catalogue.
- ❌ **Réalité** : l'état de T427 reçu de T427-CC02 n'a pas été reporté. Oubli de l'orchestrateur.
- 🧪 **Scénario à rejouer** :
  1. Recevoir un état d'agent (message ou restitution).
  2. Vérifier que l'entrée correspondante existe dans le registre d'orchestration.
- ✅ **Preuve attendue** : entrée datée dans `TASKS_ORCHESTRATOR.yaml`, avec statut et décision en attente.

---

## 7. 🔀 Un seul workflow pour tous les agents

- 🧑 **Besoin** : Claude, Codex et Antigravity suivent la **même** règle de démarrage.
- ❌ **Réalité** : Codex a des raccourcis et des commandes différents. Deux voies de rattachement coexistent.
- 🧪 **Scénario à rejouer** :
  1. Lancer le même scénario (§ 2) dans Claude, puis dans Codex.
  2. Comparer les preuves de lecture.
- ✅ **Preuve attendue** : même liste de fichiers lus dans les deux CLI.

---

## 8. 🚧 Blocages à lever avant le test

- 🔴 Rattachement T427-CC02 refusé (`source_changed_during_read`), non résolu.
- 🟠 Alias `MMX` accepté par le Superviseur, refusé par le catalogue (T429 R3).
- 🟠 Écritures hors périmètre T000 bloquées : décision exploitant requise pour une dérogation.
- 🟡 `TASKS_ACTIVE_SUMMARY.md` écrit à la main, risque de dérive.

---

## 9. 🧭 Ordre de travail proposé

1. 🔎 Confirmer les hypothèses marquées 🔎 (stderr, titre).
2. 🧪 Rejouer §§ 1 à 7 dans l'ordre, une preuve par besoin.
3. 🛠️ Corriger un besoin à la fois, puis le rejouer.
4. 📣 Restituer : besoin → réalité → preuve, pour chaque point.

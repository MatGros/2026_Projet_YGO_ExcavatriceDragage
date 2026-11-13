---
name: workflow-project
description: Lance ou relance le workflow projet dans n'importe quel chat (neuf ou déjà ouvert). Argument `resume` (avec récupération du contexte) ou `fresh` (sans récupération).
---

# 🧭 workflow-project — Lancer le workflow projet

> 📌 **Source canonique de la commande `/workflow-project`** (stubs : `.claude/skills/` et `.dsh/skills/`).
> Cette commande **ne contient aucune règle** : les règles vivent dans `AGENTS.md` § « Démarrage de
> session — Entonnoir réflexe ». Elle sert seulement à le **rejouer** à la demande.
> Origine : T427, incrément I1b (2026-11-13).

## 1. 📚 Toujours, en premier

1. Relire **`AGENTS.md` en entier, à jour sur disque** (le contexte du chat peut contenir une
   version périmée chargée au démarrage de la session).
2. Lire `DOC/WFLOW/TASKS_ACTIVE_SUMMARY.md`. Ne jamais lire `DOC/WFLOW/TASKS.yaml` en entier.
3. Appliquer le § Démarrage selon l'argument ci-dessous.

## 2. 🔀 Selon l'argument

**🔁 `resume` — avec récupération du contexte**
- Résumer le fil en cours en **5 lignes max** : tâche · étape · dernière décision · prochaine action · ce qui attend une validation.
- Poser la **ligne d'étape** correspondant à ce résumé.
- Finir par le pied `➡️ Choix`.

**🆕 `fresh` — sans récupération**
- Faire la restitution standard du § Démarrage : rôle · compteurs 🔒/⏳/⏸️/⬜ · une question.
- Ne pas s'appuyer sur l'historique du chat pour le cadrage.
- ⚠️ Limite à dire en une ligne si utile : l'historique reste dans le contexte ; seul `/clear` ou un nouveau chat repart réellement de zéro.

**❓ Sans argument**
- Proposer en une ligne : `resume` (reprendre le fil) ou `fresh` (repartir du cadrage).

## 3. 🚫 Ce que la commande ne fait pas
- Aucune écriture de fichier, aucun changement de statut au catalogue.
- Aucune règle propre : en cas d'écart, `AGENTS.md` fait foi.

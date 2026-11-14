---
name: workflow-project
description: Commande explicite /workflow-project [resume|fresh|off]. Toujours exécuter via le script workflow_state.py ; son résultat fait foi. Ne prend aucune tâche.
---

# 🧭 workflow-project — commande déterministe

> 📌 Source canonique de `/workflow-project` (stubs : `.claude/skills/` et `.dsh/skills/`).
> Origine : T427, incrément I1c (2026-11-13). Plan : `DOC/WFLOW/TASKS/T427_WORKFLOW_AGENTS/`.

## 0. ⚠️ Règle absolue

- Une commande **tapée par l'utilisateur s'exécute toujours**, dans le chat en cours, quelle que
  soit la tâche en cours. Ne jamais la refuser, ni la renvoyer vers un autre agent.
- Elle **ne prend aucune tâche** et ne change aucun verrou.
- Chaque invocation est **indépendante** : ne pas se fonder sur un refus ou un choix antérieur.
- Aucune question avant d'exécuter.

## 1. 🔧 Étape unique : appeler le script

Lancer, depuis la racine du dépôt, **la commande exacte** ci-dessous, en passant l'ID natif
de la session (`CLAUDE_CODE_SESSION_ID` pour Claude) :

```text
python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py <enter|off|status> [fresh|resume] --session "$CLAUDE_CODE_SESSION_ID"
```

| Commande utilisateur | Appel du script |
|---|---|
| `/workflow-project` ou `/workflow-project fresh` | `enter fresh` |
| `/workflow-project resume` | `enter resume` |
| `/workflow-project off` | `off` |

Le script écrit l'état hors dépôt et imprime le bloc de sortie. **Ce bloc fait foi** :
- il indique `WORKFLOW ACTIF`, `OFF` ou `INDÉTERMINÉ` ;
- il donne les compteurs du catalogue et dit si le résumé est à jour ;
- il dit si `AGENTS.md` est présent.

## 2. ✍️ Ce que l'agent remplit (et seulement ça)

Le bloc est complet : rien à compléter.
- 📍 **Ce chat** : la tâche en cours, ou « aucune », avec le dernier point en une phrase ;
- ⏸️ **En attente** : ce qui attend l'utilisateur, ou « rien » ;
- ➡️ **Choix** : 2 à 4 suites possibles.

Pour `resume` : résumer le fil du chat en 5 lignes au maximum dans 📍 (il reprend le **fil de ce chat**,
pas une tâche du catalogue).

## 3. 🔀 Cas du script

- **`ACTIF`** : appliquer le § Démarrage de `AGENTS.md` (ligne d'étape, pied de réponse).
- **`OFF`** : répondre en simple assistant. Pas de ligne d'étape ni de pied `➡️`.
- **`INDÉTERMINÉ`** : dire que l'état n'est pas connu, sans rien supposer. Demander de relancer
  avec `/workflow-project` ou `off`.
- **Résumé `PÉRIMÉ` ou `ABSENT`** : le signaler dans 📊, sans lire `TASKS.yaml` entier.

## 3bis. 🪜 Tenir l'étape à jour (alimente la ligne de statut)

La ligne de statut du terminal affiche l'état du workflow **et** l'étape en cours. Elle se met
à jour **au changement**, jamais à chaque message. Quand l'étape change (CADRAGE, ÉTUDE,
RÉALISATION, TEST, RESTITUTION, DIAGNOSTIC, ARRÊT — cf. `AGENTS.md` § « Ligne d'étape »),
appeler une seule fois :

```text
python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py etape "<ÉTAPE>" --session "$CLAUDE_CODE_SESSION_ID"
```

L'étape est refusée si elle n'est pas dans la liste fermée ci-dessus ; le workflow doit être
`ACTIF` pour qu'elle soit mémorisée. Aucun effet sur le catalogue ni sur les verrous.

## 4. 🚫 Ce que la commande ne fait pas

- Aucune écriture dans le dépôt : l'état vit dans `%LOCALAPPDATA%/ExcavatriceDragage/workflow/`.
- Aucune modification du catalogue, des verrous ou du code.
- Aucune règle propre : `AGENTS.md` fait foi.

## 5. ⚠️ Limites à connaître

- Un **nouveau chat** n'a pas de clé de session connue pour Codex : le script répond `INDÉTERMINÉ`.
- Le déclenchement automatique à chaque message (hook) n'est **pas** configuré : tant que
  l'utilisateur ne lance pas la commande, rien n'est rejoué.

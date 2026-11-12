---
name: project-workflow
description: Routeur unique du workflow agents du projet — tronc commun + aiguillage vers les 3 voies (task-planner, orchestrator, troubleshooting).
---

# 🎯 project-workflow — Routeur du workflow agents (Excavatrice Dragage)

> **Source canonique unique** (pattern stub + canonique, zéro duplication).
> Les stubs `.claude/skills/project-workflow/` et `.dsh/skills/project-workflow/` pointent ici.
> 🚫 **Cette skill ne portera JAMAIS de règles nouvelles propres** : une règle écrite deux fois
> dérive toujours (anti-duplication). Le tronc commun est le seul contenu de ce fichier.

## 1. Tronc commun (≤ 1500 tokens — seul contenu normatif de ce fichier)

1. 🏟️ **Règle d'or** : toute implémentation modifiante démarre après validation humaine de
   **tâche + plan** (GO explicite). Après GO, le lot roule jusqu'à restitution sans arrêt au fil
   de l'eau. Une question reçoit une réponse, pas une modification.
2. 🏭 **Sécurité machine réelle** : liste fermée de blocage (humain, données, régression
   critique, cas d'arrêt C4). `Enable=FALSE` neutralise · `SafeStop` (par métier) rampe rapide ·
   `StartStop=FALSE` rampe normale · l'**AU physique seul** coupe brutalement · **jamais
   de redémarrage auto après défaut** · `Reset` sur front.
3. 📚 **Sources actives** : standards `DOC/STDS/` (version `_vX.Y` la plus élevée), specs métier
   `AF_Partie-03+`, `AGENTS.md` = pointeur unique des consignes. `ARCHIVES/` jamais active.
4. 🔒 **Preuves** : tout lot CODE/ → bundle + diff bundle + `G200 --report` **BLOQUANT** ;
   fin de lot → `run_all_gates.py`. `Device.export` n'est jamais une référence. Contrat de
   tâche dès C2, contrôlé par `check_task_contract.py` (T1-T11 : T9-T11 en avertissements).
5. 🚦 **Commits** : jamais sans validation humaine explicite ; jamais de push sur `main` sans
   rel relecture du diff. Sous-agent ne commite jamais seul ; GO d'implémentation ≠ GO de commit.
6. 🧹 **Sorties** : routées par la table `STRUCTURE_AND_CLEANUP.md` (T279). Pas de scratch à la
   racine ; pas de suppression automatique d'artefacts.

## 2. Routage — choisir la voie, une seule règle s'applique à la fois

| Situation | Voie (skill canonique) |
|---|---|
| Écrire, livrer, ranger une tâche du catalogue ; contrats et locks | `TOOLS/AGENT_WORKFLOW/skills/task-planner/SKILL.md` |
| Piloter, déléguer, challenger, revanche, valider, superviser un lot | `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md` |
| Diagnostiquer un incident, un comportement inattendu | `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md` |

En cas de doute sur la voie : **troubleshooting d'abord si un incident est décrit**, sinon
orchestrateur pour cadrer la demande, puis task-planner pour la fiche. Le doute se résout en
annonçant la voie prise en une ligne, pas en ouvrant plusieurs journals.

## 3. Anti-patterns interdits sous toutes les voies

- Second journal, registre parallèle ou double saisie d'une même information.
- Hook ou contrôle de nouvelle génération activé en bloquant sans plan validé (démarrage en
  avertissement uniquement).
- Approximation d'une spec manquante : on demande, on ne devine pas.
- Copie de contenu de skill hors sa source canonique.

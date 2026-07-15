# 📋 Queue Agents — Claude (orchestrateur) ↔ Gemini (exécution)

> 🎯 Tableau de bord des tâches déléguées. Une ligne = une tâche = un fichier `tasks/TASK-00NN-slug.md`.
> **Seul Claude ajoute des lignes ici.** Chaque agent met à jour `Status` sur SES tâches assignées.
> 📌 Onboarding Gemini : lire `GEMINI_BRIEF.md` d'abord, à chaque session.
> 🧪 Test hook 2026-07-15 : commit de contrôle pour vérifier le réveil `push_server.py` (6e itération).

| ID | Titre | Assigned | Status | Maj |
|---|---|---|---|---|
| [TASK-0002](tasks/TASK-0002-rename-fdc-grappin-enable.md) | Renommer FdcGrappinOpen/Close en FdcGrappinOpenEnable/CloseEnable | Gemini | TODO | 2026-07-15 |
| [TASK-0003](tasks/TASK-0003-test-pipeline-hook.md) | [TEST PIPELINE] Vérification bout-en-bout queue/hook (motif factice) | Gemini | REVIEW | 2026-07-15 |
| [TASK-0004](tasks/TASK-0004-test-pipeline-hook.md) | [TEST] Vérification pipeline queue/hook (motif factice) | Gemini | TODO | 2026-07-15 |

---

## Légende `Status`

| Valeur | Sens | Qui peut le mettre |
|---|---|---|
| `TODO` | Prête à démarrer, pas encore prise | Claude (création) |
| `IN_PROGRESS` | En cours | Agent assigné |
| `BLOCKED` | Question/ambiguïté — voir `Log` du fichier tâche | Agent assigné |
| `REVIEW` | Terminé côté agent, en attente de vérification | Agent assigné |
| `DONE` | Vérifié et accepté | **Claude uniquement** |

## Convention ID

`TASK-00NN`, incrémental, jamais réutilisé même si une tâche est abandonnée (garde `BLOCKED`/annotation plutôt que de supprimer la ligne).

---

## 🗑️ Cycle de vie / nettoyage (fait UNIQUEMENT par Claude, jamais par Gemini)

Quand une tâche passe `REVIEW → DONE` (ou est abandonnée définitivement) :
1. Déplacer sa ligne de la table active ci-dessus vers la table **Archive** ci-dessous (1 ligne compacte : ID, titre, date, statut final)
2. Supprimer le fichier détaillé `tasks/TASK-00NN-slug.md` — son contenu est déjà capturé par : le commit git (trailer `Task-file:`), cette ligne d'archive, et `VERSION_HISTORY.md` si le changement était un jalon significatif
3. **Jamais de suppression avant que le commit correspondant soit validé par l'utilisateur** — la trace git doit toujours exister avant que le fichier de travail disparaisse

Les tâches `TODO`/`IN_PROGRESS`/`BLOCKED`/`REVIEW` ne sont **jamais** supprimées, seulement `DONE` ou abandon explicite (noté comme tel dans l'archive, pas silencieusement effacé).

### Archive (tâches terminées)
| ID | Titre | Statut final | Date |
|---|---|---|---|
| TASK-0001 | Restreindre JoystickWinchSelect (M1/M2 seul) à MAINT_N2 | DONE | 2026-07-15 |

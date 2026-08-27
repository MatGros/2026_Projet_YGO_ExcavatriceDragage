# Task Manager

Interface locale de consultation et d'edition de `DOC/WFLOW/TASKS.yaml`.

## Demarrage

- Dans VS Code : la session Terminal Keeper `AI` ouvre le terminal `Task Manager` au demarrage.
- Manuellement : lancer `LANCER_TASK_MANAGER.bat` a la racine du projet, ou
  `TOOLS/TASK_MANAGER/LANCER_TASK_MANAGER.bat`.
- Le serveur ouvre le navigateur externe sur `http://127.0.0.1:8081/TASK_VIEWER.html`.

Le port `8081` est reserve a cet outil. Les lanceurs arretent toute instance precedente qui
ecoute sur ce port avant de demarrer le serveur : une seule instance applicative reste active.

## Donnees et verrous

- `TASKS.yaml` : catalogue des taches, source de verite versionnee.
- `TASK_LOCKS.json` : etat runtime local, volontairement ignore par Git.
- `LOCK` (`work_lock`) : tache prise en charge pour travailler ; affiche un cadenas.
- `EDIT` (`edit_flag`) : edition courte depuis l'IHM ; affiche un drapeau et interdit la
  modification ou la suppression concurrente.

Le bouton `RAZ flags` de l'IHM retire uniquement les `EDIT` restants. Il ne supprime jamais les
`LOCK` de travail attribue.

## Regle agents

Avant d'editer une tache, lire les verrous et signaler une edition en cours ; apres l'ecriture
de la tache, liberer le flag d'edition. Cette procedure est obligatoire ; `task_lock.py` est un
outil facultatif pour la realiser via le serveur.

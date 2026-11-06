# POC — collage de l'affectation AGY

## Contrat et portée

Comparer les valeurs préremplies par l'interface actuelle avec les valeurs d'un bloc synthétique. Les attendus sont codés dans `replay.mjs` avant l'appel au DOM. Le script utilise `linkedom` et simule toutes les requêtes HTTP : il ne crée aucune affectation, ne contacte pas le service et ne vérifie pas le Task Manager. Le bloc T427 reprend le texte transmis par l'utilisateur avec un UUID synthétique ; aucune conversation n'est ouverte.

```powershell
node TOOLS/AGENT_SUPERVISOR/poc/collage/replay.mjs
```

Chaque exécution conserve un fichier JSON horodaté contenant entrées, valeurs observées, messages et attentes. Le code de sortie vaut 1 si un cas contredit son attente ; il n'indique pas que l'essai lui-même a échoué à s'exécuter.

## Résultats du passage 2026-11-05 03:28:13 UTC

Dans [la trace complète](results-2026-11-05T03-28-13-471Z.json), **9 attentes sur 12** sont satisfaites. Trois anomalies restent visibles :

1. Un JSON avec deux clés `native_id` est accepté ; la dernière prend le dessus. Un refus était attendu pour éviter une identité ambiguë.
2. Un retour à la ligne physique au milieu de l'identifiant JSON est transformé en espaces, puis accepté dans le préremplissage ; l'ID ainsi modifié ne correspond plus à l'UUID initial.
3. Si l'ID change sur la même plateforme et qu'aucun alias n'est fourni, l'ancien alias reste affiché ; un alias vide était attendu pour éviter une association trompeuse. Un avertissement générique signale néanmoins que des valeurs diffèrent.

Le bloc T427 fourni, avec UUID synthétique, est prérempli dans la version courante et la continuation « code automate interdit » est conservée. Cela ne permet pas de reconstituer la version du serveur, les clics ou le message d'erreur au moment de l'échec historique.

## Formats observés

- Le bloc `VEILLEUR_ASSIGN_V1` / `END_VEILLEUR_ASSIGN_V1` reste obligatoire, avec les marqueurs chacun sur leur ligne.
- Les paires `champ: valeur` indentées et une continuation indentée sans forme de nouveau champ sont acceptées. Une continuation telle que `code: interdit` est interprétée comme un champ inconnu et refusée.
- Un objet JSON placé entre les marqueurs est accepté. Un JSON seul sans marqueurs, une clôture Markdown interne, une clé inconnue et une mission assemblée dépassant 1 500 caractères sont refusés.
- Le préremplissage ne crée pas la session ; le bouton d'ajout et la résolution du fichier source sont une étape séparée. Les résultats ne prouvent pas qu'un UUID synthétique existe réellement.

Les résultats horodatés antérieurs sont conservés : le corpus a été enrichi entre les passages, sans réécrire les anciennes sorties.

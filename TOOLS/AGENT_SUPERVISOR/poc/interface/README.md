# POC — panneaux et lisibilité du Veilleur

## Résultat observé

La [preuve brute](results.json) contient les versions, les empreintes SHA-256 et les sorties complètes de deux essais Node sur DOM simulé (`linkedom`) :

| Essai | Résultat | Portée |
|---|---|---|
| Test du produit `tests/test_ui.mjs` | Échec : quatre panneaux observés, trois attendus | Le test existant est périmé ; son exécution s'arrête à cette assertion. |
| Copie `test_ui_adapte.mjs` | Réussite | Les assertions parcourues vérifient les panneaux repliables, l'identité de la carte au rafraîchissement identique, l'état ouvert après changement, le payload factice du juge et Entrée/Maj+Entrée dans le chat. |

La copie adapte le nombre de panneaux de 3 à 4 et le sélecteur du juge de `button` à `summary` ; elle ajoute des traces descriptives. Ce résultat ne corrige pas le test d'origine.

La [capture Chrome avec une session fictive](capture_synthetique.png) montre les panneaux ouverts. Elle est produite sans service : les requêtes réseau sont remplacées par des réponses synthétiques, et les autres sections de la page sont masquées pour cadrer la carte. Les panneaux ont été ouverts par le script. **Ce n'est pas une validation d'interactions dans un navigateur connecté au service.**

La zone « Ce que le juge a reçu » apparaît en texte monospace, sans ascenseur propre visible sur ce petit contenu ; le code construit un `<pre>` sans hauteur bornée ou `overflow` explicite. La demande d'un style similaire aux autres champs et d'un défilement interne n'est pas démontrée comme satisfaite.

## Rejouer

Depuis la racine du dépôt, avec Node et `linkedom` 0.18.12 disponibles :

```powershell
node TOOLS/AGENT_SUPERVISOR/poc/interface/replay.mjs
node TOOLS/AGENT_SUPERVISOR/poc/interface/browser_fixture.mjs
```

Le premier script cherche `linkedom` via `SUPERVISION_DOM_MODULES` ou `%TEMP%/supervision-dom-tests/package.json`, comme le test d'origine. Sur ce poste, la dépendance 0.18.12 est installée dans ce dossier temporaire. Le paramètre `--record` réécrit `results.json` avec les résultats du nouveau passage. Le script Chrome crée un dossier temporaire et affiche le chemin de son HTML synthétique et de sa capture ; il ne le supprime pas. `VEILLEUR_CHROME` permet d'indiquer un autre exécutable Chrome.

## Limites

- Les `fetch` sont simulés : la collecte, le serveur 8082, la persistance et le comportement réseau ne sont pas vérifiés ici.
- La capture est statique : elle ne prouve ni la stabilité visuelle sur plusieurs rafraîchissements ni le fonctionnement d'un ascenseur sur un contexte long.
- Les scénarios d'affectation, le clavier et le panneau du juge sont des données synthétiques ; aucun transcript réel n'a été ouvert.
- Le test adapté est une preuve exploratoire distincte, et non un remplacement du test produit.

## Rejeu après correction de l'interface

Les résultats et captures ci-dessus décrivent le premier état observé. Après correction de l'interface et du test produit, `node TOOLS/AGENT_SUPERVISOR/poc/interface/replay.mjs` donne deux codes 0 ; la nouvelle preuve avec empreintes est `results_after_ui_fix.json`. La capture `capture_apres_correction.png` montre la police alignée sur les autres blocs, avec données et réponses simulées. Le test produit vérifie un volet repliable et un contenu à hauteur bornée avec défilement automatique. La capture courte ne prouve pas l'interaction avec un long texte ni avec le service réel.

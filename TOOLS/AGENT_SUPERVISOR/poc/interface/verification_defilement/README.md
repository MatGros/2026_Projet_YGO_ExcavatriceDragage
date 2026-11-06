# Vérification du défilement du contexte du juge

Depuis la racine du dépôt :

```powershell
node TOOLS/AGENT_SUPERVISOR/poc/interface/verification_defilement/replay.mjs
```

Le script ouvre dans Chrome headless une copie du HTML actuel, avec une session et des messages fictifs. Les requêtes `fetch` sont simulées ; aucun service ni transcript utilisateur n'est contacté. Le navigateur mesure la hauteur visible, la hauteur totale et la position avant et après un défilement programmatique. Chaque rejeu crée un résultat et une capture horodatés et garde son profil Chrome temporaire.

Le passage du 5 novembre à 03:21:50 UTC a mesuré une hauteur visible de 320 px, une hauteur totale de 1 312 px et un déplacement de 0 à 992 px. La capture correspondante montre l'ascenseur au bas du bloc. Ce contrôle ne vérifie pas le service réel ni le clignotement au rafraîchissement.

Un premier passage a produit `results.json` avec `metrics: null` : le sélecteur lisait le code du script avant l'élément rendu. Le script a été corrigé et la capture et le résultat initiaux sont conservés.

# POC Claude — ciblage de deux sessions synthétiques

## Contrat fixé avant exécution

Créer deux nouvelles sessions Claude A et B identifiées par UUID générés pour l'essai. Les initialiser sans outils puis envoyer uniquement à A un marqueur aléatoire. Reprendre chacune et demander le marqueur connu. Attendu : A cite exactement le marqueur et B répond `AUCUNE`. Chaque commande doit réussir et retourner l'UUID attendu. Toutes les entrées sont artificielles.

La preuve porte sur des reprises **non interactives** : elle ne démontre pas l'injection dans une interface interactive déjà ouverte, ni une mise en file automatique par Veilleur. Les réponses du modèle restent sujettes à erreur. L'essai consomme des appels Claude et crée deux nouvelles sessions conservées.

Depuis la racine du dépôt :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/claude_routage/probe.py
```

Chaque exécution écrit un rapport JSON distinct dans ce dossier et utilise un dossier temporaire système distinct. Aucun nettoyage automatique. Les sorties détaillent arguments, codes de retour, réponses JSON, durée et usage retourné par Claude. Le test s'arrête avant tout envoi si la création d'une session échoue ou si son UUID ne correspond pas.

## Résultat du 5 novembre 2026

Le fichier `evidence_e85769e145824c9185b534d920e49aa6.json` conserve cinq réponses JSON Claude complètes. Les cinq commandes ont réussi et confirmé l'UUID demandé. A a répondu avec le marqueur exact et B `AUCUNE`. Durées des appels : 6,239 s, 5,550 s, 5,630 s, 5,800 s et 5,598 s. La somme des champs `total_cost_usd` retournés est 0,0773928 USD ; il s'agit de la valeur rapportée par le CLI, pas d'une facture vérifiée. Les outils intégrés étaient désactivés. Les deux sessions ont été créées pour cet essai et conservées.

La remise à A a utilisé `claude --resume` pour lancer un **nouveau tour non interactif**. Ce n'est pas une injection dans un tour déjà en cours ou une fenêtre interactive ; aucun comportement de file d'attente n'est démontré pour Claude.

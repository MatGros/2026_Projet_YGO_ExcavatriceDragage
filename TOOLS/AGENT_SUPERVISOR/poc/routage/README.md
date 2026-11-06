# POC — routage d'une alerte vers une session

## Objectif et périmètre

Vérifier qu'un message synthétique peut être ciblé sur une session créée par l'essai, et qu'une seconde session ne le reçoit pas. Aucun message n'est envoyé aux conversations préexistantes. Aucun fichier du produit ni catalogue de tâches n'est modifié.

## Résultat Codex réel

`codex_probe.py` crée deux conversations Codex synthétiques, utilise `codex queue` sur l'UUID de la première, puis reprend les deux par leur UUID. Sur le passage conservé dans `codex_evidence.json`, chaque commande a renvoyé le code 0 :

- A a répondu `POC_ALERTE_650C3EDEB475`, identifiant émis par le script et transmis uniquement à A ;
- B a répondu `AUCUNE` à la même question, sans que le marqueur lui soit envoyé.

Les sorties et usages en tokens sont conservés dans le JSON. L'essai consomme l'offre Codex configurée ; les valeurs d'usage sont celles renvoyées par Codex, pas un coût financier calculé. Il prouve la mise en file et la réception lors d'une **reprise non interactive** de ces deux sessions. Il ne prouve pas la réception dans une fenêtre interactive déjà active, ni un fonctionnement intégré au Veilleur.

Le lecteur de preuve vérifie désormais le `thread.started` attendu et extrait uniquement le texte d'un événement `item.completed` de type `agent_message`. Une mention du marqueur dans un message utilisateur ne suffit pas. Les tests `python -B TOOLS/AGENT_SUPERVISOR/poc/routage/test_evidence_parser.py` couvrent notamment un écho utilisateur, l'absence de message assistant et un mauvais thread. La trace `codex_evidence.json` conservée avant ce renforcement a été relue avec le nouveau lecteur : A retourne exactement le marqueur, B `AUCUNE`.

Commande à lancer depuis la racine du dépôt :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/routage/codex_probe.py
```

Chaque lancement crée deux nouvelles sessions Codex et un nouveau dossier dans le répertoire temporaire système contenant `evidence.json`. Aucun nettoyage automatique n'est effectué. Un marqueur nouveau est généré pour chaque lancement. L'essai nécessite un Codex authentifié et utilisera des tokens.

## Simulation de garde-fous

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/routage/simulation.py
```

Cette simulation indépendante vérifie : A et B reçoivent chacun leur alerte, un ID absent, un ID ambigu et une deuxième distribution de la même alerte sont refusés. Elle ne prouve pas que Veilleur applique déjà ces garde-fous ni que les CLI réels refusent ces cas.

## Autres plateformes et réserves

- **Claude Code** : `claude --help` documente la reprise d'une session par ID ; l'aide indique qu'une reprise en arrière-plan peut créer une copie si la session est active. Aucun essai d'envoi à un chat actif n'a été réalisé.
- **Antigravity / AGY** : `agy --help` documente `--conversation`, mais cela ne prouve pas l'injection dans une fenêtre active. Le quota AGY était épuisé lors de l'essai précédent. Aucun envoi réel vérifié ici.
- Le premier lancement du script automatisé a échoué parce qu'il cherchait `codex.cmd` au lieu de `codex.exe` sur ce poste ; le script corrigé a produit le résultat ci-dessus.
- La décision d'envoyer automatiquement une alerte vers une conversation réelle est distincte de cette démonstration : gérer consentement, doublons, provenance, échec et état de la session reste nécessaire.

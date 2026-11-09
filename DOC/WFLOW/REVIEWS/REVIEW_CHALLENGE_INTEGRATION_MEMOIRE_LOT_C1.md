## Cadre de l'audit

Rôle retenu : reviewer indépendant, lecture seule, aucune écriture ni commit. **Aucun dépôt n'a été lu dans cette session** : l'analyse s'appuie sur les faits énoncés dans la demande ; tout ce qui concerne le contenu réel de `judge_prompt.py` ou `supervisor_service.py` est une inférence, à confirmer avant exécution. Aucun verdict PASS n'est porté sur une vérification non exécutée.

## Comparaison des options

| Option | Faisabilité | Risque conflit Git | Charge cognitive (agent C1) | Verdict |
|---|---|---|---|---|
| 1 — Tout dans C1 | Faible : nécessite réouverture du périmètre | Élevé | Élevée | À écarter |
| 2 — Séparation stricte | Bonne : C1 reste dans son exclusivité ; C2 = nouveau lot à autoriser | Faible (exclusivités disjointes, intégration en fin) | Maîtrisée | **Recommandée** |
| 3 — Report post-Golden | Bonne, mais ne répond pas au « qui » | Reporté, pas supprimé (risque de reprise sur `judge_prompt.py`) | Inchangée à court terme | Séquencement possible, pas une architecture |

## Arguments clés

**La frontière de l'Option 2 est la seule naturelle.** La cadence « tous les 8 messages » est mécanique : un LLM ne compte pas ses tours de façon fiable — le compteur et la persistance ne peuvent pas vivre dans le prompt. Inversement, lire la section mémoire, décider d'émettre `state_update` et produire l'audit de trajectoire (Cap initial vs jalons) sont des compétences comportementales, formulées et testées dans le prompt. L'Option 2 sépare le déterministe du déterminisme (moteur) et l'empirique (prompt) ; les Options 1 et 3 mélangent ou évitent la question.

**Option 1.** Elle impose à C1 une écriture hors de son exclusivité (`supervisor_service.py`) : extension de périmètre non couverte par l'autorisation de lot existante, donc réouverture du plan et de la revue. Elle mélange deux boucles de test (comportementale vs unitaire sur service), gonfle le diff à relire, et crée un second écrivain sur le fichier moteur — précisément le risque de collision visé.

**Option 2 — point de vigilance principal : la dérive d'interface.** C1 peut développer lisible-mémoire avec de simples fixtures, sans que le moteur existe : parallélisation possible. Le risque est que le format de mémoire attendu par le prompt diverge de celui injecté par le moteur. Mitigation : figer un contrat d'interface court + fixtures partagées **avant** le lancement des deux lots.

**Option 3.** Elle n'a de sens que comme calendrier, combinable avec l'Option 2 : geler le contrat d'interface maintenant (coût faible), implémenter après ou en parallèle de la validation Golden. Le garde-fou décisif rend ce report facultatif : exiger de C1 que le comportement du prompt **en l'absence de section mémoire soit identique au baseline** (non-régression Golden vérifiable par tests).

## Contrat d'interface à figer avant lancement

1. Format du document mémoire (sections, champs, taille max).
2. Schéma `state_update` (champs obligatoires) et sémantique de fusion côté moteur (remplacement vs patch, refus si invalide).
3. Point et politique d'injection (system prompt vs message dédié ; chaque tour vs au déclencheur uniquement — impact tokens).
4. Définition exacte de « message » pour le compteur de 8 (messages utilisateur, tours complets, sorties d'outils ?).
5. Comportement attendu sur chemin « mémoire absente » (identique au baseline).

## Critères d'acceptation proposés

- **C1** : le prompt lit une section mémoire factice et émet un `state_update` conforme au schéma sur les scénarios de test ; non-régression confirmée avec mémoire absente ; tous les tests de `test_judge_behavior.py` passent.
- **C2** : compteur déterministe (définition du contrat), déclenchement à chaque 8ᵉ message, persistance avec fusion conforme, injection au point convenu ; aucune écriture sur `judge_prompt.py` / `test_judge_behavior.py`.
- **Intégration (responsable)** : scénario bout-en-bout de 16 messages ; audits déclenchés à 8 et 16 ; mémoire reflète les updates ; preuve = exécution réelle, pas une simulation présentée comme terrain.

## Inconnues minimales à lever

1. Propriétaire actuel de `supervisor_service.py` (coordonnateur ou lot existant ?) et existence d'une entrée C2 dans `TASKS.yaml`.
2. Schéma `state_update` éventuellement déjà présent dans le prompt.
3. État du Golden Dataset (brouillon / en validation) et capacité de `test_judge_behavior.py` à charger une fixture mémoire.
4. Périmètre de persistance : mémoire de session vivante ou reprise après redémarrage.

## Décision attendue du coordonnateur

Valider l'Option 2 (architecture) + figer le contrat d'interface + créer/autoriser le lot C2 (exécutant, écriture exclusive sur `supervisor_service.py` et ses tests) + arbitrer le séquencement vis-à-vis du Golden, rendu sûr par le garde-fou de non-régression. L'entrée C2 dans `TASKS.yaml` relève du coordonnateur, les exécutants n'y touchent pas.
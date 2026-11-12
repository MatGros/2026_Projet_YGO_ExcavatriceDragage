# Choix des agents et des modèles

> Référence commune aux orchestrateurs de projet, responsables de tâche et agents délégués.
> Cette politique décrit les choix et limites d'exécution ; elle ne garantit pas qu'un outil tiers
> applique automatiquement le modèle demandé. Les appels déterministes doivent préciser le modèle.

Cette même règle de routage sert aux deux niveaux : pilotage du projet et réalisation d'une tâche
attribuée, y compris la préparation d'un brief, d'une spécification ou d'un contrat. L'agent
responsable peut utiliser des sous-agents, suivre leur avancement et vérifier les tests et preuves ;
les règles de chaque workflow continuent de définir ses responsabilités et droits.

## Règles de choix

1. **Suivre la demande de l'utilisateur.** Un modèle ou fournisseur demandé explicitement prime,
   sous réserve des contraintes de sécurité et du contrat de tâche.
2. **Déléguer selon le besoin, pas selon un nom de modèle figé.** Un sous-agent natif utilise le
   modèle de la plateforme/configuration courante si aucun override n'est disponible. Les familles
   rapides conviennent au repérage et au tri ; une revue, une décision ou une tâche de code exige
   un modèle adapté à la difficulté et au risque. Les noms et capacités des modèles évoluent :
   vérifier le catalogue au moment d'un appel.
3. **Pour une délégation Ollama économique**, le modèle par défaut des scripts du projet est
   `deepseek-v4.1-flash:cloud`. On peut en choisir un autre avec `--model <identifiant>`.
4. **Pour une tâche risquée**, suivre le contrat et les règles C3/C4 : une faible consommation
   ou un grand nombre d'agents ne remplace ni une revue indépendante requise, ni la validation
   de l'orchestrateur et de l'humain.

## Budget de délégation Ollama par session

- Jusqu'à **4 agents Ollama simultanés** et **20 appels Ollama au total dans une session** :
  le responsable de la tâche peut les lancer sans demander un accord supplémentaire, si la tâche y gagne.
- Au-delà de l'une de ces limites, demander l'accord de l'utilisateur avant de lancer les appels
  supplémentaires.
- Favoriser des sous-tâches indépendantes, avec des livrables distincts et un brief commun
  suffisant. L'orchestrateur compare les résultats et reste responsable de la synthèse.
- Ce budget concerne les appels aux runners Ollama du projet ; il ne constitue pas un objectif
  à atteindre ni une autorisation de multiplier les tâches sans utilité.

## Spécialistes du projet et modèles

Les personas `safety`, `plc`, `hmi`, `testing`, `standards` et `challenger` sont des assistants
spécialisés conçus d'abord pour le Superviseur. Leur rôle détermine leur consigne et leur domaine,
pas un modèle dédié. Ils peuvent aussi être appelés directement par l'utilisateur ou un agent.

Le lanceur `specialist_supervisor.py` utilise le runner Ollama commun et son modèle par défaut ;
`--model <identifiant>` permet de choisir un autre modèle. Si le persona s'avère trop lié au
Superviseur pour un autre workflow, traiter cette limite au niveau du workflow au lieu de créer
une nouvelle voie de lancement sans besoin établi.

## Identifiants exacts et documentation

- Dans une **commande, un script, un contrat ou `models_allowed`**, employer l'identifiant exact
  attendu par le fournisseur. Un changement de nom de modèle se vérifie avec le fournisseur ou
  `--list-models` lorsque le runner le propose.
- Dans les consignes générales, parler de capacités/familles (rapide, raisonnement, code) plutôt
  que d'épingler une version précise. Les exemples de modèles sont temporaires.
- `DSH_PROVIDERS.md` documente les routes et détails techniques DSH/Ollama/OmniRoute ; ses mesures
  de performance datées sont des observations historiques, pas un catalogue actuel.
- `AGENTS.md` pointe ici comme référence commune. Le workflow d'orchestration précise quand et
  comment déléguer ; les contrats de tâche priment s'ils limitent les modèles autorisés.

## Limites de vérification

Le choix réellement exécuté par un agent natif ou un service distant n'est pas toujours exposé au
dépôt. Ne pas prétendre qu'un modèle a été vérifié si l'outil n'en fournit pas la preuve. Les
runners Ollama du projet reçoivent l'identifiant exact dans leur paramètre `model` et acceptent
`--model` en ligne de commande.

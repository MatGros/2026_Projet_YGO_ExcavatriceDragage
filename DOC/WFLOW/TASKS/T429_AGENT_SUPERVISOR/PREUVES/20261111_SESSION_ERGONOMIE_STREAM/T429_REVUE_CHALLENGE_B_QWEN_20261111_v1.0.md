# Brief de délégation — gabarit commun

## Mission

- **Utilisateur / besoin d'origine :** Évaluation critique des modifications récentes du Veilleur (Agent Supervisor) sur l'excavatrice industrielle (T429 Fiabilisation Veilleur)
- **Objectif de cette sous-tâche :** Identifier les risques, ambigüités et limites des modifications apportées au Veilleur
- **Historique utile et preuves disponibles :** Modifications de flux d'événements (collapsing, copie au clic, badges de session), repositionnement des boutons de gestion des constats, CLI `/review-session-supervisor` avec format [CONSTAT], [PREUVE BRUTE], [VERDICT]
- **Décision que le résultat doit permettre :** Évaluer si la tâche est achevée ou si des points bloquants subsistent
- **Critères d'acceptation :** 
  - Couverture ergonomique des exigences utilisateur
  - Absence de risques de régression ou de surcharge visuelle
  - Robustesse des alertes SCADA
  - Validité du format CLI et des preuves brutes

## Rôle et autorisations

- **Rôle :** Reviewer indépendant (Challenge A/B)
- **Périmètre autorisé :** Analyse ergonomique, vérification des critères de clôture, validation des risques
- **Actions interdites :** Modification du catalogue `TASKS.yaml`, accès machine, injection de code
- **Outils autorisés :** Documentation `AGENTS.md`, outils de vérification de contraste, analyse de flux d'événements
- **Responsable/coordonateur :** [Identifiant et canal de retour]

## Méthode et restitution

1. **Vérification ergonomique :** 
   - Les badges de session (couleurs + fond transparent) améliorent la lisibilité, mais les contrastes avec le fond ne sont pas quantifiés (risque de mauvaise accessibilité)
   - Les émojis de tri sont utiles, mais leur interprétation pourrait varier (ex. `🤖 AGENT` vs `🛠️ TOOL`) → ambiguïté possible
   - La suppression du bouton 'Copier' et la copie au clic réduit la surcharge, mais la fonctionnalité est limitée à un clic unique (risque de perte de contexte)

2. **Risques et robustesse :**
   - Les appels d'outils (`Appel outil : <nom>`) sont déterministes, mais leur format n'est pas standardisé (ex. `sommaire` vs `méthode`) → risque de confusion
   - Le CLI `/review-session-supervisor` impose un format strict, mais les outils requis pour les preuves brutes ne sont pas tous disponibles dans tous les environnements (risque de blocage)
   - Le repositionnement des boutons `Re-evaluate`/`Mark seen` améliore l'accessibilité, mais leur placement pourrait générer une surcharge visuelle si non maîtrisé

3. **Verdict final :**
   - **Critère 1 (Couverture utilisateur) :** Partiellement atteint. Les fonctionnalités sont pertinentes, mais manquent de quantification des contrastes et de standardisation des émojis
   - **Critère 2 (Robustesse) :** Risque de régression dans les appels d'outils et les CLI. Aucune preuve de test sur des scénarios de surcharge visuelle
   - **Critère 3 (Clôture) :** Non achevée. Les risques de mauvaise accessibilité et de confusion dans les appels d'outils nécessitent une validation supplémentaire

## Règles de projet

- Les émojis de tri et les badges de session sont validés selon `AGENTS.md` § Discipline de session
- Aucun essai sur machine réelle sans procédure explicite
- Les outils de vérification de contraste et de standardisation des émojis sont autorisés
- Le CLI `/review-session-supervisor` doit être testé avec des outils de preuve brute disponibles

**Verdict recommandé :** La tâche est *partiellement achevée*. Des ajustements sont nécessaires pour standardiser les émojis, quantifier les contrastes, et valider la robustesse des appels d'outils. La clôture doit être reportée après tests supplémentaires.
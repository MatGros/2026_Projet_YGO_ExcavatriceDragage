# Délégation C3/C4 — cadrage compact et responsabilité

Cette référence s'applique aux lots mouvement/interlock/safety, aux missions multi-agents et aux
travaux dont l'investigation peut devenir longue. Elle complète `AGENTS.md`, le contrat de tâche
et `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md` sans les remplacer.

## Règle de répartition

| Rôle | Responsabilité |
|---|---|
| Orchestrateur | Catalogue, contrat, priorités, phasage, conflits de scope, test manager, lecture du diff réel, acceptation/rejet. |
| Agent principal | Challenge le cadrage, implémente le lot, vérifie le code, exécute les tests/gates et restitue les preuves. |
| Challenger | Analyse le besoin ou le plan avec un contexte frais ; read-only ; signale hypothèses, risques et alternatives. |
| Reviewer | Relit le diff et les preuves après implémentation ; read-only ; verdict `BLOCK/MAJOR/MINOR/PASS`. |

Un agent principal peut constituer une petite équipe de spécialistes (automatisme industriel,
safety, IHM/ergonomie, tests, mise en service), mais reste seul responsable de son rapport final.

## Ce qu'il faut déléguer

- recherches historiques ou transverses longues ;
- inventaires et vérifications répétitives ;
- challenge indépendant d'un plan C3/C4 ;
- revue du diff avec contexte frais ;
- comparaison de deux hypothèses ou deux modèles.

Ne pas déléguer le simple suivi du catalogue, l'arbitrage du besoin utilisateur, la lecture finale
du diff ni la décision de livraison : ces points appartiennent à l'orchestrateur.

## Trois couches de prompt

1. **Socle invariant** : coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
2. **Mission spécifique** : utiliser les huit rubriques ci-dessous.
3. **Annexe spécialiste facultative** : ajouter uniquement les questions safety, IHM, tests ou
   mise en service qui concernent réellement la mission.

Le cadrage détaillé d'une tâche comme T330 est un bon exemple C3/C4, pas un texte à recopier
pour chaque micro-tâche.

## Gabarit de mission

```text
OBJECTIF
- Résultat utilisateur attendu, exprimé sans imposer trop tôt une solution.

PÉRIMÈTRE / INTERDITS
- Fichiers ou fonctions autorisés.
- Hors scope explicites ; aucun nettoyage, revert ou correction opportuniste.

PHASES ET POINTS D'ARRÊT
1. Lire contrat, standards et code réel.
2. Challenger le besoin et produire le plan.
3. Respecter l'arrêt humain prévu par le contrat.
4. Implémenter soi-même après GO.
5. Faire relire le diff par un agent indépendant.
6. Corriger les BLOCK/MAJOR, puis exécuter tests, bundle, G200 et gates.

CRITÈRES TESTABLES
- Reprendre chaque critère du contrat avec son moyen de preuve (`verified_by`).

SOUS-AGENTS AUTORISÉS
- Contextes frais et compétences utiles seulement.
- Challengers/reviewers read-only ; un seul écrivain dans le scope.

PREUVES ATTENDUES
- Faits code/trace, tests ciblés, diff réel, bundle complet + diff bundle, G200, gates.

RESPONSABILITÉ DU PRINCIPAL
- Tu restes garant du code, du rapport, des tests et de la cohérence avec le besoin.
- Tu vérifies les conclusions des agents ; tu ne recopies pas leurs affirmations comme preuves.

FORMAT DE RESTITUTION
- Verdict court ; fichiers touchés ; critères AC un par un ; tests/gates ; risques résiduels ;
  hors scope constaté ; bloc Auto-vérification liaison.
```

## Points d'arrêt immédiat

- contrat C2+ absent, ambigu ou non testable ;
- hypothèse safety non tranchée ;
- conflit d'écriture ou modification concurrente du même fichier ;
- diff contenant un fichier inattendu, une suppression ou un élargissement de scope ;
- divergence majeure entre reviewers sur un sujet C4 ;
- preuve mécanique manquante ou gate bloquant rouge.

Dans ces cas, l'agent principal remonte le point à l'orchestrateur. Il ne contourne pas le blocage.

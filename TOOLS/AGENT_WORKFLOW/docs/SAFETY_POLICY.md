# Politique safety

## Règle absolue

Le workflow agent ne certifie jamais une fonction de sécurité. Il assiste l'analyse ; la validation revient à l'automaticien, à CODESYS et aux essais requis.

Tout rapport Herdr/LLM doit rester `advisory-only` tant qu'un automaticien n'a pas validé explicitement.
Le statut `human-validated` ne peut jamais être produit automatiquement par un agent.

## Déclencheurs safety

AU, PowerCutOff, SafeStop, frein, contacteur, redondance, fin de course, homing safety, interlock, limite physique, norme, FAT/SAT.

Pour ces sujets :

- Ponytail désactivé pour l'analyse et la justification ;
- **Double revue parallèle A/B obligatoire** (voir `MODEL_ROUTING.md`) ;
- tests et preuves explicitement listés ;
- aucune modification silencieuse ;
- aucun rapport ne peut conclure à une validation Safety normative.

## 🔴 Double revue parallèle A/B — Procédure

S'applique à : TEST_DESIGN, ST généré, toute revue C4 safety.

1. Agent A et Agent B reçoivent **identiquement** le même contexte (TASK_CONTEXT + artefact).
2. Les agents travaillent **sans se voir** — résultats collectés séparément.
3. Pi analyse : consensus → synthèse humain ; divergence → 🚨 alerte + positions A/B côte à côte.
4. L'humain tranche en cas de divergence. Aucun agent ne valide la safety.

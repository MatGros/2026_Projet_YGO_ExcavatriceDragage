# Politique safety

## Règle absolue

Le workflow agent ne certifie jamais une fonction de sécurité. Il assiste l'analyse ; la validation revient à l'automaticien, à CODESYS et aux essais requis.

Tout rapport Herdr/LLM doit rester `advisory-only` tant qu'un automaticien n'a pas validé explicitement.
Le statut `human-validated` ne peut jamais être produit automatiquement par un agent.

## Déclencheurs safety

AU, PowerCutOff, SafeStop, frein, contacteur, redondance, fin de course, homing safety, interlock, limite physique, norme, FAT/SAT.

Pour ces sujets :

- Ponytail désactivé pour l'analyse et la justification ;
- review croisée read-only ;
- tests et preuves explicitement listés ;
- aucune modification silencieuse ;
- aucun rapport ne peut conclure à une validation Safety normative.

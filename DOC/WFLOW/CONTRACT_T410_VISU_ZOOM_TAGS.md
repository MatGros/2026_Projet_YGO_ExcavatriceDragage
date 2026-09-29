# Contrat T410 — Zoom capteurs, butées et tags

## Objectif

Rendre visibles sans ambiguïté les capteurs M3, le frein, les deux butées et les hypothèses de modèle dans la même animation FMU.

## Critères d’acceptation

- Une zone dédiée affiche les cinq capteurs avec leur position nominale.
- Les butées Trémie (-0,30 m) et Maintenance (30,30 m) sont visibles.
- Le frein affiche séparément demande et retour.
- La position courante et l’état de butée sont visibles.
- Les hypothèses sont affichées par tags courts, sans surcharge de couleurs.
- Le test headless QML démarre et se termine sans erreur.
- Aucun changement PLC ou écriture réseau n’est introduit.

## Review

- comparer les positions affichées avec M3_POC.mo ;
- vérifier qu’un capteur actif ne masque pas les autres ;
- vérifier que l’état butée ne dépend pas uniquement de la couleur ;
- contrôler l’absence de régression sur joystick, trace et fréquence.

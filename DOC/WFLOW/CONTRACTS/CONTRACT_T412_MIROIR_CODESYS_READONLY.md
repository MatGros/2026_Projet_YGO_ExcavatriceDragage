# Contrat T412 — Miroir CODESYS vers animation

## Objectif

Permettre à l'interface QML existante d'afficher les données Control Win ou PLC en lecture seule.

## Sécurité

- le script ne fait aucune écriture PLC ;
- il envoie uniquement vers 127.0.0.1:29072 (port télémétrie dédié) ;
- aucune connexion au PLC réel n'est créée par le script ;
- une expression introuvable est signalée, jamais remplacée silencieusement.

## Données

Position, vitesse, fréquence consigne, fréquence mesurée, frein, mot d'état,
cinq capteurs, butée et séquence.

## Critères

- syntaxe compatible IronPython CODESYS ;
- socket fermé dans finally ;
- 20 trames consécutives lisibles par l'adaptateur ;
- perte du script => état STALE côté interface ;
- aucune commande n'est envoyée vers le PLC.

## Review

- rechercher toute méthode write/set dans le script ;
- vérifier la destination UDP ;
- interrompre le script et vérifier DONNÉES PERDUES ;
- comparer les valeurs CODESYS avec celles affichées.

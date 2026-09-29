# Contrat T411 — Adaptateur PLC lecture seule

## Objectif

Fournir à la même animation un flux M3 externe sans écrire de variable PLC.

## Périmètre

- nouvel adaptateur Python de télémétrie UDP ;
- réutilisation du format de trame T409 ;
- aucune commande envoyée ;
- aucun changement CODESYS/PLC.

## Critères

- accepte uniquement les trames T409 valides ;
- rejette taille, magic, version et valeurs invalides ;
- expose position, vitesse, Hz mesurés, frein, capteurs et butée ;
- signale STALE après perte de trame ;
- fournit SIMULATION ou PLC_READONLY comme source ;
- tests unitaires sans PLC.

## Review

- prouver qu’aucun sendto n’existe dans l’adaptateur ;
- injecter une trame valide puis une trame corrompue ;
- vérifier l’état stale ;
- comparer les valeurs avec unpack_plant ;
- vérifier qu’une perte réseau n’entraîne aucun mouvement local.

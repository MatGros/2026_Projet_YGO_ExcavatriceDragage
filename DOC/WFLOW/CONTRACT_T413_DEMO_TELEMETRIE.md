# Contrat T413 — Démo télémétrie PLC

## Objectif

Tester le chemin PLC LECTURE de l'interface sans PLC réel, avec les mêmes trames et le même adaptateur.

## Invariants

- aucune connexion CODESYS ;
- aucune écriture PLC ;
- destination loopback 127.0.0.1:29072 uniquement ;
- capteurs cumulatifs conformes au modèle M3 ;
- position bornée entre -0,30 m et 30,30 m.

## Critères

- la démo produit au moins 20 trames par seconde ;
- position, vitesse, Hz, frein et capteurs évoluent ;
- l'interface affiche PLC LECTURE ;
- arrêt de la démo provoque DONNÉES PERDUES ;
- le test ne modifie aucun fichier projet.

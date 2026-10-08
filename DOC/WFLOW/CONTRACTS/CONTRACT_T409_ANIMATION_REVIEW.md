# Contrat de challenge — T409 M3 et animation

## Objectif

Valider le lot FMU M3, son bridge Control Win et l’animation sans régression de la logique PLC existante.

## Invariants

- Aucun fichier du PLC réel, PRG_02, IHM ou GVL existante n’est modifié.
- Les capteurs restent ceux du modèle actuel : chaîne cumulative 11111 → 01111 → 00111 → 00011 → 00001 → 00000.
- Frein appliqué : position constante.
- Position bornée entre -0,30 m et 30,30 m.
- Une perte UDP ne doit jamais produire de mouvement ni de capteur faux.

## Critères de validation

1. Tests Python T409 : protocole, cinématique, round-trip 10 ms et reprise : PASS.
2. Control Win : LinkReady=TRUE, Timeout=FALSE, LinkInvalid=FALSE en régime établi.
3. Trajet vers Trémie puis Maintenance : sens, frein, fréquence mesurée et capteurs cohérents.
4. Butées : arrêt avant dépassement, état HardStop visible.
5. Animation FMU : chariot, capteurs, frein, consigne/mesure Hz, trace 10 ms.
6. Perte passerelle : tag défaut visible, capteurs sûrs, récupération contrôlée.

## Challenge obligatoire

- rechercher toute écriture hors GVL_Simulation.SimM3OpenModelica.* ;
- vérifier les effets de bord du bridge sur le code PLC ;
- provoquer une perte UDP et une trame invalide ;
- vérifier que les capteurs ne sautent pas de manière impossible ;
- comparer les valeurs affichées avec le log FMU.

## Livrables de review

- tableau PASS/FAIL par critère ;
- logs et captures ;
- liste des régressions éventuelles ;
- verdict : accepté, accepté avec réserves ou refusé.

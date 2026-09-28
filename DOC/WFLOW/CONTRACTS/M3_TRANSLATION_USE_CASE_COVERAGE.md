# M3 — couverture des cas d’utilisation de translation

Référentiel : `AF_Partie-11_Fonction_Translation_v2.4.md` §§3–3quater et `AF_Partie-13_Fonction_Simulation_v2.5.md`.

## Règle de représentation

Chaque cas doit être visible simultanément sur quatre niveaux :

1. **Commande** : sens, consigne Hz, demande de desserrage frein.
2. **Plante** : fréquence mesurée, vitesse, position, frein réel, butée mécanique.
3. **Capteurs** : mot thermomètre admissible et capteur actif.
4. **Automate** : image `GVL_Simulation.SimM3OpenModelica`, état `LinkReady/Timeout/LinkInvalid` et diagnostic.

## Matrice de couverture

| ID | Cas | Attendu principal | FMU/PLC | État |
|---|---|---|---|---|
| M3-01 | Repos, frein serré, aucune commande | vitesse/Hz/position stables, capteurs cohérents | T409 | À tester |
| M3-02 | Ouverture frein à l'arrêt | ouverture après délai, aucun saut de position | T409 | À tester |
| M3-03 | Départ vers Maintenance | rampe, vitesse positive, position croissante | T409 | À tester |
| M3-04 | Départ vers Trémie | rampe, vitesse négative, position décroissante | T409 | À tester |
| M3-05 | PV / vitesse lente | consigne limitée à 15 Hz selon le mode | PLC + FMU | À compléter |
| M3-06 | Vitesse nominale | consigne et mesure distinctes, mesure bornée | T409 | Couvert protocole |
| M3-07 | Retour neutre | décélération puis frein, pas de redémarrage automatique | PLC + FMU | À tester |
| M3-08 | Passage PV, P2, P1 | mots capteurs `01111/00111/00011`, puis position recalée | T409 | À tester |
| M3-09 | Arrivée Trémie | capteur `11111`, butée à -0,30 m, sens Trémie interdit | FMU + PLC | À compléter |
| M3-10 | Arrivée Maintenance | capteur `00001`, butée à 30,30 m, sens Maintenance interdit | FMU + PLC | À compléter |
| M3-11 | Rebroussement près d’un capteur | pas de claquement ni mot incohérent | FMU + PLC | À compléter |
| M3-12 | Rebond/perte capteur transitoire | filtrage conforme, pas de faux freinage | PLC | À compléter |
| M3-13 | Mot capteurs incohérent | rejet image, `LinkInvalid`, aucun mouvement autorisé | T409 | Garde ajoutée |
| M3-14 | Frein non confirmé >500 ms | watchdog, fréquence/mot à zéro, défaut mémorisé | PLC + FMU | FMU partiel |
| M3-15 | Anti-télescopage benne actif | translation neutralisée au même scan | PLC | Non représenté FMU |
| M3-16 | Autorisation Maintenance absente | mouvement Maintenance refusé | PLC/IHM | Non représenté FMU |
| M3-17 | Perte gateway UDP | timeout, image invalidée, frein appliqué | T409 | Partiel, à mesurer |
| M3-18 | Reprise gateway | resynchronisation explicite, aucune téléportation | T409 | À concevoir |
| M3-19 | Simulation désactivée | aucun effet sur la machine simulée | PLC | Exigence conservée |
| M3-20 | Passage simulation → réel | sortie simulation désactivée avant reprise réelle | PLC | Procédure à valider |

## Gaps bloquants identifiés

- La FMU possède position/vitesse, mais ces mesures ne sont pas encore intégrées dans l’image PLC standard ; elles restent dans la télémétrie T409.
- La synchronisation initiale de position n’est pas définie : la FMU démarre à P1 (20 m). Il faut choisir `position connue`, `homing`, ou `démarrage inconnu bloqué`.
- Les rebonds capteurs, le watchdog frein 500 ms et l’anti-télescopage doivent être testés dans la logique PLC réelle de la copie Control Win ; une FMU seule ne peut pas les valider.
- Les butées mécaniques sont modélisées côté FMU, mais la réaction graduée PLC (2,5 s / 5 s) doit être observée et tracée.
- La position initiale est désormais le paramètre `M3Configuration.initialPosition_M`, borné entre les deux butées ; le scénario par défaut reste P1 à 20 m.

## Critère de complétude

La simulation ne sera déclarée aboutie que lorsque chaque ligne aura :

- un scénario reproductible ;
- une trace commande/plante/capteurs/PLC ;
- un résultat PASS/FAIL ;
- une preuve que le mode simulation désactivé ne modifie aucune sortie réelle.

## Première preuve SIL exécutée

Commande :

```text
python TOOLS/TWINBENCH/udp_m3_link/test_t409_fmu_scenarios.py
```

Résultat : `PASS` pour frein fermé sans mouvement, marche avant/arrière, vitesse bornée et mots capteurs admissibles. La campagne a atteint les deux butées (`-0,30 m` et `30,30 m`) et a observé les six mots `31, 15, 7, 3, 1, 0` au retour vers la Trémie. Cette preuve valide la plante FMU seule ; elle ne valide pas encore les réactions de la logique PLC.

## Contrôle de convention de sens

La convention AF-P11 est appliquée dans la passerelle : `DriveControlWord=1` signifie Trémie et doit faire décroître la cote ; `DriveControlWord=2` signifie Maintenance et doit faire croître la cote. Ce point est testé par `test_t409_recovery.py`.

## Audit CI projet

La suite globale `TOOLS/TEST_AUTO_CI/run_all_tests.bat` a été exécutée le 2026-09-28. Résultat : **40 PASS / 16 FAIL**. Les 14 scénarios `FB_Sim_Translation` passent, ainsi que les scénarios `FB_Sim_TranslationBrake`, `FB_Sim_TranslationDrive` et `FB_Sim_SuspendedLoad`. Un échec restant concerne `TC-T386-M3-001` dans `FB_Safety_Translation` (`PowerCutOff` attendu TRUE, obtenu FALSE) ; il relève du code safety PLC et doit être traité dans un lot séparé avant de déclarer la validation globale complète. Aucun code PLC existant n'a été modifié pour masquer cet écart.

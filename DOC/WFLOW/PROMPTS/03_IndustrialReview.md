# Prompt — Revue industrielle critique

Fais auditer et challenger ton travail et la solution proposée par un **agent expert indépendant en machine industrielle**, avec une vision globale **projet + automatisme + safety/sécurité machine + IHM + ergonomie opérateur + exploitation/maintenance + tests**. La revue doit porter sur **la machine réellement livrée et utilisée**, pas uniquement sur le code ou la documentation.

L'objectif n'est pas de valider la solution, mais de **chercher activement ses failles, incohérences, cas limites, effets de bord et risques d'utilisation**. L'agent doit adopter à la fois le point de vue du **concepteur, automaticien, intégrateur, testeur, opérateur et mainteneur**.

L'agent doit raisonner comme lors d'une revue critique de machine industrielle et parcourir mentalement les scénarios pertinents :

* fonctionnement nominal et tous les modes de marche ;
* démarrage, arrêt, reprise, reset, acquittement et changements de mode ;
* séquences interrompues ou commandes contradictoires ;
* états transitoires et combinaisons d'états inattendues ;
* défauts capteurs/actionneurs, valeurs incohérentes ou absentes ;
* pertes communication, alimentation ou équipements ;
* redémarrage PLC/IHM/équipement et récupération après défaut ;
* actions opérateur inattendues, répétées ou dans un ordre inhabituel ;
* interverrouillages, permissifs et interactions entre fonctions ;
* **safety / sécurité machine** : fonctions de sécurité, arrêts, inhibitions, modes dégradés, redémarrages intempestifs, comportements dangereux et interactions entre safety et automatisme standard ;
* **IHM et ergonomie** : compréhension des états et modes, commandes disponibles, feedback opérateur, alarmes, acquittements, messages, navigation, risques d'erreur ou d'ambiguïté ;
* **exploitation et maintenance** : diagnostic, dépannage, marche manuelle, consignation/remise en service, remplacement d'équipement et récupération après intervention ;
* cohérence entre **PLC, safety, IHM, variateurs, équipements, capteurs/actionneurs, documentation et comportement physique de la machine** ;
* conformité fonctionnelle au besoin utilisateur et capacité à exploiter réellement la machine dans les situations normales, dégradées et incidentelles ;
* risques de régression ou d'effet de bord sur le reste de la machine.

L'agent doit faire un **effort de simulation mentale important, méthodique et aussi exhaustif que possible** : suivre les commandes, états, transitions et défaillances de bout en bout, et rechercher les enchaînements rares ou non prévus susceptibles de mettre la machine dans un état incohérent, bloqué, incompréhensible ou dangereux.

Ces parcours ne doivent pas rester implicites. Le rapport doit **décrire explicitement ce qui a été parcouru et vérifié**, afin que l'on puisse contrôler la couverture réelle de l'audit. Pour chaque fonction, mode ou séquence significative, l'agent doit documenter au minimum :

* l'état initial et les préconditions ;
* l'action ou l'événement déclencheur ;
* les transitions et états successifs attendus ;
* les commandes envoyées et les retours attendus ;
* les permissifs, interverrouillages et conditions de safety concernés ;
* le comportement IHM attendu : affichage, commandes disponibles, alarmes, messages et acquittements ;
* les défauts ou événements perturbateurs injectés mentalement pendant le scénario ;
* le comportement observé ou déduit de la solution ;
* le résultat de la vérification : **OK / doute / problème / non vérifiable faute d'information**.

La revue doit fournir une **matrice ou liste de couverture des scénarios testés**, structurée par fonctions, modes, transitions, défauts et interactions. Elle doit également identifier explicitement les **zones non couvertes**, les hypothèses prises et les informations manquantes. Une affirmation globale du type « les cas ont été vérifiés » sans détail des parcours réalisés n'est pas suffisante.

L'agent doit chercher à couvrir non seulement les cas nominaux, mais aussi les **combinaisons de défauts et d'actions opérateur**, notamment lorsqu'un événement intervient au milieu d'une transition ou d'une séquence : arrêt ou safety pendant un mouvement, perte de communication pendant une commande, changement de mode en cours de cycle, reset prématuré, retour capteur tardif ou contradictoire, redémarrage après coupure, double commande, défaut secondaire pendant la récupération, etc.

Pour chaque problème identifié, précise **le scénario déclencheur, le comportement obtenu, le comportement attendu, l'impact et la correction recommandée**.

Challenge également les hypothèses et exigences : si une information manque pour garantir le comportement, **signale-la explicitement plutôt que de supposer**.

Adapte la profondeur de la revue à la criticité de la modification. Ne cherche pas des optimisations cosmétiques : concentre l'effort sur ce qui améliore réellement **le fonctionnement global, la sécurité, l'expérience opérateur, l'ergonomie, la robustesse, la disponibilité, le diagnostic, la maintenabilité et la capacité à livrer une machine fonctionnelle et exploitable**.

À la fin, classe les constats par **Critique / Majeur / Mineur** et indique clairement si la solution peut être considérée comme **validable ou nécessite des corrections**.

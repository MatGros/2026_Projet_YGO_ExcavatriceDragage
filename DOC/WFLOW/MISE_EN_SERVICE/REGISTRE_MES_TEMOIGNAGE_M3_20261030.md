# Registre MES — Témoignage exploitant M3 — 2026-10-30

## Provenance et valeur du récit

Consigné le **30 octobre 2026**, à la demande explicite de l'exploitant. Cette date est celle du recueil, pas celle des essais machine. Le récit ci-dessous repose notamment sur des souvenirs et peut être altéré par la mémoire : il constitue une référence de ce que l'exploitant rapporte, **pas une preuve instrumentée des causes ni des chronologies**. Les vérifications devront s'appuyer sur les données et traces du projet et sur l'historique Git pour identifier les versions correspondantes. Une trace de simulation ne prouve pas le comportement de la machine réelle. Aucune trace réelle n'est validée ou analysée par cette consignation.

Ce témoignage corrige et remplace les reformulations antérieures de l'agent concernant les « observations sur la machine réelle », explicitement rejetées par l'exploitant. Les anciens documents restent historiques ; en cas de divergence sur le témoignage, revenir au présent texte, sans fusionner réel, simulation et hypothèses.

## Texte de l'exploitant — conservé sans correction

> - Visuel réel (Translation M3 en semi auto) : en approche Trémie / vidage benne, le chariot continue de bouger doucement vers la butée après l'arrêt même pendant l'ouverture benne. On a pensé à une roue libre sur l'inertie ou une pente de rail, avec un frein qui arrive en douceur… A confirmer mais le variateur utilise toujours sa résistance de freinage donc rampe contrôlée. Donc ma dernière hypotèse cest plus un relâchement du frein silencieux ou pas (aucun souvenir si IHM affiche etat frein) mais si frein relaché et que le rail chariot est en pente on peut avoir cet effet de déplacement vers butée mécanique tres lentement…
> J'ai constaté aussi des défaut brake M3 au passage de AX14 à AX15 mais qui ont été aténué par hazard car la PV 20HZ a quasiment masqué le défaut ... alors que 10Hz bcp plus souvent le défaut et commande électrique moins bonne saccade plus.
> Et le défaut pouvait arriver au retour P1 mais pas souvent (infirmation moins fiable pas certain).
>
> - Manuel vs Auto : en Manuel, l'arrêt sur Trémie et P1 est propre, avec une décélération correcte et un arrêt à environ 10 cm après le capteur. En Auto, l'automate affiche 0,0 m (Trémie) et 5,0 m (P1), mais la simulation continue jusqu'à −0,45 m et +5,38 m. alors que l'on devrait être proche du manuel … apres il y a peut être un bug mais ca peut pas être la cause du déplacement lent de 30 à 50cm vers butée meca.
>
> - Oscilloscope CODESYS (test en simulation pas machin relle) : au capteur Trémie, TranslationFinalInterlockRequest.BrakeReleaseRequest passe à 0 instantanément, sans maintien de 2 s (comme hypotèse agent). Le contact physique simulé M3_BrakeIsOpen_DI retombe peu après (temps mécanique). En revanche, TranslationState.BrakeCmd met environ 1 s de plus à descendre.
>
> Je demande que le simulateur reproduise les bug problème de la machine reele sans modifier le code automate (quon modifie plustard apres simu OK)

## Règles d'utilisation pour la reprise

- **Réel rapporté** : déplacement lent vers la butée pendant l'ouverture benne ; défauts brake M3 à AX14 → AX15, moins fréquents à PV 20 Hz qu'à 10 Hz avec davantage de saccades à 10 Hz. Retour P1 : souvenir explicitement incertain.
- **Hypothèse actuelle de l'exploitant** : relâchement du frein et pente permettant un déplacement très lent. Ni la pente, ni le relâchement, ni leur causalité ne sont établis par ce récit. Le fonctionnement avec résistance de freinage et rampe contrôlée est une information rapportée à confronter aux données ; ne pas postuler une roue libre immédiate au retrait de commande.
- **Simulation explicitement identifiée** : positions −0,45 m / +5,38 m face à l'affichage 0 / 5 m ; observation oscilloscope des trois signaux de frein. Ne pas les réattribuer au réel. Le contexte du constat manuel est conservé tel qu'écrit, sans attribution supplémentaire.
- **Deux phénomènes à distinguer** : dépassement à l'arrêt et déplacement très lent pendant le vidage. Ne pas imposer une cause commune ; ne pas transformer l'interprétation de l'exploitant en causalité démontrée.
- **Objectif confirmé** : simulateur plausible et isolé, priorité AX14–AX15–AX18 et suite du cycle, pour reproduire naturellement les problèmes et évaluer la fiabilité de la position estimée par l'automate. Le reste de M3 fonctionne globalement selon le retour exploitant.
- **Ordre imposé** : valider d'abord le simulateur, puis seulement traiter les éventuels bugs du programme machine dans un lot ultérieur. Aucune modification du code automate dans le présent travail de simulation ; aucune alimentation de l'estimateur par la position vraie du simulateur pour masquer un écart.

## Documents antérieurs à lire avec cette correction

- [Passation T417 du 30 octobre](../TROUBLESHOOTING/FICHES/PASSATION_T417_SimM3_20261030.md).
- [Étude T417, notamment §5bis](../ETUDES/ETUDE_CONCEPTION_T417_SIMULATION_TRANSLATION_M3.md).
- [Reprise du 28 octobre](<../TASKS/T_TEMP (A TRIIER)/AUDITS/T417_PASSATION_SIMULATION_M3_20261028.md>).

Ces liens facilitent la reprise ; ils ne valent pas validation des affirmations contenues dans ces documents.

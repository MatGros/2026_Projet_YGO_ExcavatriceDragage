# Note pour le collègue IHM — bouton « Joystick / Manuel local » sur la page Manu N2, compteurs horaires et RAZ du compteur journalier (18/11/2026)

> Rédigée par TORC-CC10 à la demande de l'exploitant (mise en service du 18/11). À transmettre par l'exploitant. Aucun changement automate n'est demandé.

## Demande
Ajouter, sur la **page Manu N2**, le **même bouton de sélection joystick / manuel local** que celui qui existe déjà sur une autre page.

## Variable (une seule, aucune nouvelle)
- `GVL_IHM.Modes.Cmd.TglJoystickMaster` : `BOOL`, **TRUE par défaut**.
  - **TRUE = le joystick pilote** les treuils M1/M2 et la translation M3.
  - **FALSE = les boutons de l'IHM pilotent** (montée / descente, avance / recul).
- Même variable que sur l'autre page : les deux boutons lisent **et** écrivent la même valeur, jamais une copie.

## Pourquoi
En MAINT_N2, les boutons de montée et de descente de M1/M2 **ne produisent aucune demande tant que le sélecteur est sur « joystick »**, même si le joystick est absent. Constaté sur la machine le 18/11 (trace `Suivi_105`) : seuls les boutons de relâche-frein agissaient. Il faut donc pouvoir basculer en « manuel local » **depuis la page où l'on pilote**, sans changer de page.

## Points d'attention
1. **Afficher l'état réel au chargement de la page** (lire la variable) : après un redémarrage de l'automate elle repasse à TRUE (joystick), il ne faut pas supposer la dernière valeur de l'IHM.
2. **Libellé sans ambiguïté**, par exemple « PILOTAGE : JOYSTICK » / « PILOTAGE : BOUTONS IHM », avec une couleur différente pour « boutons IHM » (c'est l'état dégradé).
3. **Pas de mémorisation côté IHM** : l'automate ne réécrit jamais cette variable ; la valeur affichée doit venir de l'automate.
4. Les boutons de montée / descente restent des **commandes maintenues** : relâché = arrêt, comme aujourd'hui.
5. Ne pas ajouter de champ dans les tables IHM déjà livrées (`ST_IHM_MANU`) : aucune structure ne change.

## Demande 1 bis : sélecteur de treuil à 3 positions (constaté par l'exploitant le 18/11)
- Variable : `GVL_IHM.Modes.Cmd.SelJoystickWinch` (`INT`). Valeurs lues dans le code (`FB_Modes.st:30`) : **0 = couplé M1+M2, 1 = M1 seul, 2 = M2 seul**.
- **Constat** : le sélecteur actuel de la page Manu N1 n'offre que **0 et 2**. La valeur **1 (M1 seul)** n'est pas sélectionnable à l'IHM.
- **Conséquence** : en MAINT_N2, le homing unitaire de M1 exige la valeur 1 (`Step2_WinchSelected`, `FB_TroubleshootingView.st:437`). Sans elle, M1 ne peut pas être référencé (hypothèse à confirmer par essai : écrire 1 dans la variable depuis CODESYS puis snapshot).
- **Demande** : sur la page Manu N2, proposer les **trois positions** (Couplé / M1 / M2), lire et écrire la même variable que la page Manu N1, afficher la valeur réelle au chargement de la page. À valider avec l'exploitant avant de coder : la valeur 1 a peut-être été retirée volontairement de la page N1.

## Demande 2 : afficher les compteurs horaires
Structure existante, déjà alimentée par l'automate (lecture seule côté IHM) : `GVL_IHM.Commun.RunningHours` (`ST_RunningHoursHMI`).

| Champ | Type | Sens |
|---|---|---|
| `MachineHours_H`, `MachineHours_Min` | `DINT`, `INT` (0..59) | durée **automate sous tension** (compte dès le démarrage, même sans mouvement) |
| `M1Hours_H`, `M1Hours_Min` | `DINT`, `INT` | durée de marche du treuil M1 (relais de sens collé) |
| `M2Hours_H`, `M2Hours_Min` | `DINT`, `INT` | durée de marche du treuil M2 (relais de sens collé) |
| `M3Hours_H`, `M3Hours_Min` | `DINT`, `INT` | durée de marche de la translation M3 (mot de commande actif) |

- Source : totaux en secondes dans la zone persistante (`_RunningHoursMachine_S`, `_RunningHoursM1_S`, `_RunningHoursM2_S`, `_RunningHoursM3_S`), conservés après une coupure ; **l'IHM ne les écrit jamais**.
- Affichage suggéré : « 19 h 29 min » ; une seule page de maintenance, lisible hors mouvement.
- Valeurs relevées le 18/11 à 09:03 pour contrôler l'affichage : machine 70 192 s (19 h 29 min), M1 35 s, M2 131 s (2 min 11 s), M3 251 s (4 min 11 s) ; elles augmentent depuis.
- Contrôle après intégration : les compteurs M1, M2 et M3 ne s'incrémentent que pendant une marche réelle ; celui de la machine s'incrémente en continu.

## Demande 3 : bouton de remise à zéro du compteur journalier de prélèvements
- Variable à écrire : `GVL_IHM.CycleSemiAuto.Cmd.BtnResetSampleCount` (`BOOL`, **sur front** : une impulsion, pas un maintien).
- Effet (lu dans `FB_CycleSemiAuto.st:623-629`) : remet à zéro **uniquement** le compteur **journalier** `SampleCount` (`GVL_PERSISTENT._CycleSampleCount`, conservé en RETAIN).
- **Le totalisateur** `SampleCountTotal` (`_CycleSampleCountTotal`) n'est **jamais** touché : lecture seule, aucune commande.
- Affichage des deux valeurs : `SampleCount` (journalier) et `SampleCountTotal` (totalisateur) du bloc d'état du cycle (`ST_CycleState`), lecture seule.
- Points d'attention : (1) **geste volontaire** : confirmation avant l'impulsion (une RAZ efface le décompte du jour) ; (2) libeller sans ambiguïté « RAZ compteur JOURNALIER » pour ne pas le confondre avec le totalisateur ; (3) la variable repasse à FALSE d'elle-même côté IHM après l'impulsion ; (4) si une RAZ tombe sur le scan où un cycle se termine, le journalier finit à 1 (la dépose en cours est comptée) : comportement voulu.
- La remise à zéro automatique (réglage `SampleCountResetMode`, défaut `NEVER`) n'est pas concernée : par défaut, **seul ce bouton** remet le journalier à zéro.

## Pas de migration de variable
Aucun nom ni chemin ne change : rien à reparamétrer côté `IHM_VARIABLES_MIGRATION.md`.

## À confirmer avec l'exploitant
- Nom exact de la page « Manu N2 » (les pages 3, 4, 6, 7 et 8 donnent MAINT_N2 dans le programme provisoire actuel) ; faut-il aussi le bouton sur la page maintenance N1 ?
- Essai sur la machine après intégration : en MAINT_N2, bouton sur « boutons IHM », appui court sur montée / descente M1 : relais de sens et contacteur de vitesse doivent coller.

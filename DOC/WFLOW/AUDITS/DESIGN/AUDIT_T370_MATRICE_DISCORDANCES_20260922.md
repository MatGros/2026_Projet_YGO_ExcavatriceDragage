# T370 — Matrice des discordances contacteurs M1/M2 (analyse statique, 2026-09-22)

**Statut : décision de conception et validation terrain requises. Aucun code ni essai CODESYS dans ce lot.** Les références désignent l'arbre de travail du 22 septembre. Sources : `CODE/*.st`, AF02/03/06/10 actives, fiche `TROUBLESHOOTING_T370_DISCORDANCE_CONTACTEURS_20260921.md`. `Device.export` exclu.

## 1. Faits et frontière de détection

La chaîne est : demande mode/cycle `PRG_03` → arbitres métier `PRG_04` et ordres `FB_Winch` (`CODE/M_MAIN/PRG_04_Treuils_Benne.st:1457,1523`) → demandes de barrière (`:1602,1619`) → `FB_WinchOutputInterlock` → protecteurs de sorties → `M1/M2RelayFwd/Rev`, `M1/M2SpeedContactor1..4` **finaux** → DQ (`CODE/M_MAIN/PRG_06_Outputs.st:157-174,223-240,280-304,369-389`). Des discordances **internes entre demande métier, ordre FB, sortie de barrière et DQ finale** sont possibles, mais ne se déduisent pas de la DI : elles exigent une comparaison entre étages et une explication des suppressions intentionnelles (safety, temporisateurs, protecteurs). `FB_SyncContactor` compare M1/M2 à deux étages, pas demande individuelle contre DQ.

En face, **une seule DI collective par treuil** : `M1/M2_ContactorsReleased_DI`, `TRUE` = relâchés (`CODE/M_MAIN/PRG_02_Acquisition.st:145,149`; `DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md:457,459`). Ces DI arrivent à la sûreté (`CODE/M_MAIN/PRG_04_Treuils_Benne.st:959,1028`), au FB treuil (`:1424,1506`) et à la barrière finale (`:1602,1619`). Le modèle de simulation agrège sens et C1..C4 (`CODE/L_SIMULATION/FB_SimBench.st:448-473`), alors que la description d'E/S AF06 parle des **contacteurs de sens** seulement. **Contradiction à résoudre au bornier avant de spécifier une détection des C1..C4.**

Notations : `C_sens=1` si un ordre DQ final montée/descente est actif ; `C_palier=1` si un ordre DQ final C1..C4 est actif ; `R=1` si la DI dit « relâchés » ; `V_DI=LocalDigitalIoOk` (`CODE/M_MAIN/PRG_02_Acquisition.st:210`) ; `T` = délai d'établissement/retombée à mesurer. `InputModules.Fault` est un **agrégat de plusieurs modules** (`:216`) ; `Vh0008ErOk` surveille une **carte de sortie** (`:213`), et ne qualifie pas la DI `Local_Digital_IO`. La comparaison suit `Cmd` (ordre final) puis `Act` (retour), selon `DOC/STDS/NAMING_CONVENTION.md` §1bis.

| C_sens | C_palier | R | V_DI | Classe après T et hors transition, si boucle **sens seuls** selon AF06 | Si boucle sens + paliers confirmée au bornier |
|---|---|---|---|---|---|
| 0 | 0 | 1 | 1 | Repos compatible | Repos compatible. |
| 0 | 0 | 0 | 1 | Sens encore engagé ou DI trompeuse | Un élément couvert encore engagé ou DI trompeuse. |
| 0 | 1 | 1 | 1 | **Compatible** : palier seul n'est pas couvert par hypothèse AF06 ; combinaison de commandes à expliquer | Discordance ON/repos possible, mais palier seul peut être transitoire du protecteur `PRG_06:280-304`. |
| 0 | 1 | 0 | 1 | Sens engagé sans ordre, ou DI trompeuse ; palier ne l'explique pas | Retour engagé compatible avec palier ; sens indiscernable. |
| 1 | 0 | 1 | 1 | Discordance sens ON/repos possible | Discordance ON/repos possible. |
| 1 | 0 | 0 | 1 | Compatible, sens non individualisable | Compatible, organe non individualisable. |
| 1 | 1 | 1 | 1 | Discordance sens ON/repos possible ; palier indiscernable | Discordance ON/repos possible pour la boucle agrégée. |
| 1 | 1 | 0 | 1 | Compatible ; sens précis et palier indiscernables | Compatible ; organes précis indiscernables. |
| * | * | * | 0 | Retour non qualifié : diagnostic module DI | Retour non qualifié : diagnostic module DI. |

Un retour `R=0` lors d'une commande de montée ne distingue **ni montée de descente**, ni C1 de C4 si ceux-ci sont câblés, ni un contacteur collé non commandé masqué par celui commandé. Une commande simultanée des deux sens, deux paliers incohérents, ou une sortie finale différente de la demande métier relèvent de diagnostics **d'ordres** séparés ; la DI collective ne les départage pas. Sous l'hypothèse AF06 « sens seuls », les paliers ne sont simplement **pas observables** par cette DI.

## 2. Détecteurs actuels, destination et limites

| Détecteur | Producteur → routeur → consommateur / comportement | Angle mort |
|---|---|---|
| `FB_SyncContactor` amont et final | Compare les **ordres M1/M2** lorsqu'ils sont tous deux commandés ou `SyncEnable` ; 500 ms puis escalade 3 s (`CODE/H_TREUILS_BENNE/FB_SyncContactor.st:98-109,140-145` ; appels `CODE/M_MAIN/PRG_04_Treuils_Benne.st:644-659`, `CODE/M_MAIN/PRG_06_Outputs.st:341-362`). Niveau 1 → `SafeStopM1/M2_Raw` (`PRG_04:713-716`), escalade vers coupure via sûreté. | Aucun retour physique ; une panne symétrique ou unitaire hors armement passe. `BothCommanded OR SyncEnable` peut armer une divergence normale de homing : vérifier les vecteurs réels. |
| `FB_Safety_Winch` Meca B | Joystick neutre et arrêt physique non confirmé durant 3 s → latch, `ContactorStuck`, cause bit 8, arrêt/coupure (`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:341-348,480-484,523-525,584`). Routage DI `PRG_04:959,1028`. | Mélange retour contacteurs **et frein** ; ne détecte pas ON/retour repos. Une DI douteuse peut provoquer la sanction. |
| `FB_WinchOutputInterlock` | Lors du maintien de sens en attente de retombée, `MaxSenseHoldTime` → latch `ContactorStuck`, `Reason=SENSE_DROP_TIMEOUT` ; Reset à `:513` (`CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:277-324,364-372,513`). Appels `PRG_06:157,223`. | Cas OFF/engagé uniquement dans ce transitoire ; pas un comparateur universel. Le diagnostic de barrière est peu visible dans le bandeau M1/M2. |
| `FB_Winch.ContactorsCheck` | `Command := NOT AllContactorsCommandedOff`, `Feedback := NOT Sensors.ContactorsAllOff` ; `StuckClosed` et `StuckOpen` forcés à `FALSE` (`CODE/H_TREUILS_BENNE/FB_Winch.st:314-318`). | Câblage d'opérandes existant mais **détection dormante** ; ne pas annoncer comme protection active. |
| Absence de mouvement | Commande + frein confirmé + codeur disponible + position immobile, 3 s → cause bit 15, SafeStop (`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:437-445,555-559`), bandeau filtré par codeur (`CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:944,992`). | Diagnostic mécanique indirect, aucune attribution contacteur ; phase T288 provisoire, faux positifs terrain déjà signalés. |
| Défaut module DI | `LocalDigitalIoOk` qualifie le module portant les DI M1/M2 (`CODE/M_MAIN/PRG_02_Acquisition.st:145,149,210`). `InputModules.Fault` agrège ce diagnostic avec les autres cartes (`:216`) → SafeStop axes (`PRG_04:713-715`). | Ni santé par voie, ni détection DI figée lorsque module RUNNING. |
| Défaut module DO | `Vh0008ErOk` / `Vh0008Er1Ok` contrôlent des cartes de **sortie** (`PRG_02:213-214`) et alimentent aussi l'agrégat `InputModules.Fault` (`:216`) + message IHM (`CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:887-891`). | N'invalide pas directement `R` ; indique que l'ordre logique DQ peut ne pas avoir été appliqué physiquement. Aucune attribution par voie. |

Le `FB_Safety_Winch` occupe déjà ses 16 causes, bit 0 à 15 (`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:269-445,494-509`). Ajouter une cause au bitfield existant exige refonte de contrat et de consommateurs. La tentative T224 `TonNoMoveContactor` a été revertée (`DOC/WFLOW/TASKS.yaml`, entrée T224 ; fiche T370 §8.b). La phase 1 T288 doit être réexaminée pour séparer les causes (`DOC/WFLOW/REVIEWS/REVIEW_T288_PHASE2_REGISTRE_ERREURS_20260915.md:11-23`). **Diagnostic ≠ fonction de sécurité certifiée.**

## 3. Scénarios à ne pas classer trop tôt comme défaut

| Scénario | Séquence attendue et risque | Essai à spécifier |
|---|---|---|
| Démarrage, palier protecteur | Repos `C_sens=0,C_palier=0,R=1` → demande métier → protecteurs peuvent produire `C_palier=1,C_sens=0` temporairement (`PRG_06:280-304`) → `C_sens=1` → `R=0` après délai physique. | `R=1` avec palier seul est **compatible si AF06 sens seuls**. Si boucle complète, évaluer seulement après stabilisation ; horodater les six DQ. |
| Changement de palier en mouvement | `C_sens=1,R=0` ; un palier tombe et un autre monte, parfois tous paliers 0 ou chevauchés pendant protecteurs. | `R` reste normalement 0 si sens couvert et tenu ; ne pas attribuer la DI à un palier. |
| Arrêt / coast frein | Demande 0 → paliers tombent → sens peut être maintenu le temps de confirmer retombée (`FB_WinchOutputInterlock.st:277-324`) → DQ sens 0 → `R=1` après délai physique. | `C_sens=0,R=0` est transitoire ; après T, suspect. Vérifier frein séparément. |
| Inversion de sens | Sens A 1/R0 → palier 0 → sens A 0 → R1 → temps mort → sens B 1 → R0. | Aucune alarme au passage si chaque fenêtre est bornée ; un chevauchement A/B relève des ordres, pas de R. |
| Both / unitaire | Deux axes au repos R1 → commandes des axes sélectionnés → retour R0 par axe après T ; l'axe non sélectionné doit rester R1. | `FB_SyncContactor.st:98-109` peut comparer les ordres si BothCommanded/SyncEnable ; vérifier armement en unitaire. |
| Homing / benne | Selon étape, repos ou commandes unitaire/couplée ; `SyncOperationPermit` varie (`PRG_04:426-446`) tandis que `BothCommanded` peut rester vrai. | Relever chaque vecteur réel ; aucune exclusion universelle ne peut être affirmée. |
| AU / SafeStop / PowerCutOff | Commande marche/R0 → DQ finales chutent ou rampent selon cause → R1 après chute physique ; KM Power a son propre retour. | Fenêtre C_sens0/R0 normale transitoirement ; les sanctions de défaut capteur restent à arbitrer. |
| Module DI perdu / DO perdu | `LocalDigitalIoOk=0` → R non qualifié ; `Vh0008ErOk=0` peut laisser ordre logique 1 sans application physique (`PRG_02:210,213-216`). | Ne pas fusionner ces causes ; une DI figée avec module RUNNING reste indiscernable. |
| Bypass / Reset | Cause active → bypass peut désarmer certains TON ; front Reset après disparition de cause, commande nouvelle requise (`FB_Safety_Winch.st:437-445`, `PRG_04:974,1042`, `FB_WinchOutputInterlock.st:513`). | Vérifier causes simultanées, bypass par mode et absence de redémarrage automatique. |

## 4. Choix d'architecture des alarmes — à arbitrer

| Option | Avantage | Limite et coût |
|---|---|---|
| A — 1 bit par discordance + 1 message | Plusieurs causes simultanées visibles, correspondance simple test/message, latch indépendant. | Seulement **deux classes physiques par axe** démontrables (ON/repos, OFF/engagé), plus défaut module séparé. Multiplier par organe serait fictif. Bitfield safety 16/16 saturé ; nouveaux champs/interfaces et IHM, migration de contrats. |
| B — 1 bit agrégé par axe + plusieurs codes/messages | Un point global d'arrêt et interface simple ; détails portés par code cause. | Un code unique perd les causes simultanées ou impose priorité ; Reset/latche de causes distinctes difficile ; un message changeant peut effacer la première cause. Risque de conserver l'ambiguïté actuelle d'`ErrorID 16`. |
| C — bit d'état agrégé par axe **et** registre diagnostic de causes distinct, hors bitfield safety existant | Sépare action globale et diagnostic simultané, sans prétendre ajouter un bit safety ni créer de détail par contacteur. Extension IHM explicite et rétrocompatible possible si ancien bit conservé. | Nouvelle structure et routage, règle d'historisation/priorité/Reset, tests de chaque consommateur ; choix des sanctions safety à valider indépendamment. |

**Attention à l'homonyme « B » :** l'**option B de la table ci-dessus** signifie « un seul bit agrégé + messages » (question de l'utilisateur). L'**architecture B de la revue T288** signifie « registre d'erreurs dédié aux treuils » ; ce sont deux nomenclatures indépendantes. `DOC/WFLOW/REVIEWS/REVIEW_T288_PHASE2_REGISTRE_ERREURS_20260915.md:3-23` rend un verdict **MAJOR** et recommande ce registre dédié : `ErrorID 16` reste l'absence de mouvement codeur ; discordance contacteur reçoit un identifiant et un texte distincts, sans garde codeur ; les causes simultanées ne sont pas fusionnées ; aucun message ne nomme direction, vitesse ou frein ; le délai de 3 s est provisoire. Cela écarte l'option B **si son unique code écrase les causes simultanées**. A et C peuvent respecter ces exigences ; C correspond le mieux à la recommandation de registre dédié, mais sa définition exacte reste à approuver. Le registre doit aussi définir liveness, latch, Reset sur front, Enable, BypassGlobal, SafeStop et PowerCutOff. La modification précédente de la garde `TonNoMovement` est à annuler ou réécrire dans le plan T288, selon cette revue.

**Proposition pour discussion, pas décision :** étudier C avec exactement les états observables, et garder le défaut de module comme cause distincte. Le bit agrégé piloterait au plus la logique validée par analyse de risques ; les messages décriraient les deux discordances observées, sans attribuer de bobine ni de contacteur. Priorité d'affichage et mémorisation des événements simultanés restent à définir. Les informations existantes `ErrorID 16` (absence de mouvement) et `FB_SyncContactor` (asymétrie d'ordres) doivent garder des libellés séparés.

## 5. Questions terrain et validation avant code

1. **Schéma bornier :** quels auxiliaires exacts composent chaque `Mx_ContactorsReleased_DI` : sens seuls ou sens + C1..C4 ? Sont-ils en série et quel état électrique traduit `TRUE` ? AF06 (`:457,459`) contredit `ST_fbWinch_Sensors.st:21` et `FB_SimBench.st:448-473`.
2. **Incident :** LED de sortie carte et tension à la bobine réellement présentes ? `VH_0008ER` en RUNNING ? État `KM_Power` et alarmes `[IO]`/`[AU]` ? Sans cela, distinguer sortie non appliquée, circuit de puissance et DI est impossible.
3. **Politique :** après timeout ON/repos ou OFF/engagé, faut-il seulement alarme, SafeStop, ou PowerCutOff ? Une DI collective mono-voie ne suffit pas à justifier une nouvelle fonction PL. Préciser si diagnostic de capteur suspect doit être distinct de défaut contacteur.
4. **IHM :** faut-il voir simultanément plusieurs causes par axe, conserver la première cause, et comment acquitter sans redémarrage ? Cela détermine A/B/C et la rétrocompatibilité.

**Plan de tests proposé :** table §1 pour M1 et M2, deux sens, chacun des paliers, M1 seul/M2 seul/Both ; injecter DI figée et perte module séparément ; mesurer les transitoires de §3 ; vérifier défauts simultanés, priorité messages, latch, front Reset et absence de redémarrage. Simulation ensuite vérification CODESYS et terrain avec électricien habilité ; aucun résultat de simulation ne prouve le câblage réel.

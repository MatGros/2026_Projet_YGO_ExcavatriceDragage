# Plan de reprise — T291 prioritaire, limites treuils, T290

## Addendum decisionnel 2026-09-15 matin

Cet addendum prime sur les hypotheses plus anciennes du document.

- T291-A urgent = cycle automatique `SEMI_AUTO` uniquement, descente AX4..AX7.
- Profil d'essai : M1 reste palier 4, M2 vise palier 5.
- Sequence conservee : pas de saut direct ; le cadencement existant 1->2->3->4 puis 5 cote M2 reste porte par les FB treuils.
- Table paliers -> contacteurs inchangee.
- Manuel, MAINT_N1 et MAINT_N2 restent inchanges.
- T290 est recadre : pas de temporisation nouvelle ; objectif ulterieur = autoriser palier 2 en remontee extraction controlee du cycle auto, avec interlocks existants prioritaires.
- Limites haut/bas H+1/H+2 restent un lot separe, non inclus dans T291-A.

Date : 2026-09-15 · Responsable : Codex · Statut : PROPOSITION REVUE, décisions avant code.
Sauvegarde préalable : `3265abf5`, poussée sur origin/main.

## 1. Objectifs et décisions

Trois lots séparés, un seul changement fonctionnel livré à la fois. Chaque livraison comporte
contrat, tests ciblés, bundle complet et diff bundle, G200 et gates adaptés, puis essai humain
avant la phase suivante. Aucun cumul de fonctions non recettées sur la machine.

- T291 (C4) : descente Both volontairement asymétrique, exemple M1=P1/M2=P5, activation simple et explicite.
- Limites (C4) : conduite commune sur altitude M1 en Both ; protections individuelles M1/M2,
  seuils hauts relatifs et escalade physique ; correction de la limite basse légale.
- T290 (C3) : extraction P1 pendant une durée validée puis plafond P2, toutes autres bornes prioritaires.

Les paliers désignent des commandes électriques : un même palier ne garantit pas une même vitesse
physique. Inversement, changer uniquement une table électrique ne supprime pas les contrôles
qui comparent les sorties réelles de commande.

## 2. Constats source vérifiés

| Sujet | Preuve | Conséquence |
|---|---|---|
| Ralentissements locaux haut/bas | `CODE/H_TREUILS_BENNE/FB_Winch.st:173` | Positions différentes => changements de palier différents |
| Limites basses effectives | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:669` | MAX(limite câble, limite légale), décalage géométrique M2 |
| Limite légale publiée | `CODE/M_MAIN/PRG_07_Supervision.st:349` | Comparaison brute M1 OU M2, produite après PRG04, retard de scan |
| Égalité finale semi-auto | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1553` | Compare sens, 4 contacteurs ET palier ; neutralise les demandes si incohérentes |
| Concordance finale | `CODE/M_MAIN/PRG_06_Outputs.st:334` | FB_SyncContactor compare les commandes finales ; nombreux bypass |
| Escalade capteur haut | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:372` | Méca D, délai partagé PostRampTimeout=3s, exemptions benne/homing |
| Correction benne | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:612` | ActiveOffsetM dynamique ; validité et stabilisation à vérifier |
| Extraction | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1204` | Deux sources : extraction programme OU extraction manuelle |

La trace précédente prouve les sorties divergentes aux instants échantillonnés, pas la durée
exacte à l'échelle du scan ni la cause de l'arrêt final : intervalle de trace voisin de 100 ms.
Les 502 ms affichées ne permettent pas de conclure si le filtre 500 ms a déclenché.
`Enable := TRUE` prouve un raccordement source, pas l'absence de bypass pendant l'essai.
La chute réelle reste une causalité à établir indépendamment.

## 3. T291 — options et premier incrément

| Option | Principe | Impacts et risque | Avis initial |
|---|---|---|---|
| A | Table électrique distincte par axe, sélectionnée sous profil | Les comparateurs finaux voient toujours des contacteurs différents ; palier affiché/apprentissage peuvent perdre leur sens ; touche le décodage générique | Non privilégiée |
| B | Paliers demandés explicitement par axe + profil attendu surveillé | Adapter l'arbitrage, agrégation plafonds, concordance amont/finale et égalité semi-auto ; conserver indépendamment sens, prêts, arrêts et surveillance mécanique | Préférée sous réserve revue |

T291 reste une étude selon son contrat actuel ; les incréments d'implémentation auront chacun
un contrat enfant après décision sur le profil. Ne pas affaiblir un contrôle en lui donnant comme
« attendu » sa propre sortie : la référence attendue vient du profil arbitré, indépendante du vecteur observé.

### T291-A — banc du profil et contrat d'activation

Avant essai machine, expliciter mode (maintenance Both proposé en premier), commande homme-mort,
autorisation, armement à l'arrêt, indicateur IHM et palier de chaque axe. OFF au démarrage proposé.
Interdire un changement de profil en mouvement ; perte d'éligibilité => arrêt commun, retour neutre
puis nouvelle commande. Hors descente Both, comportement nominal conservé.

Tests : activation/refus, OFF, redémarrage PLC, arrêt utilisateur, inversion, défaut d'un axe,
profil incohérent, mode changé, perte référencement, mou de câble, benne en action et approche de limite.

### T291-B — première livraison exploitable

Commandes M1=P1/M2=P5 uniquement dans le contexte autorisé. Conserver le cadencement d'accélération
M2, ne pas sauter directement de P1 à P5. Surveiller sens concordants et vecteurs attendus pendant
chaque transition. Conserver arrêts communs et interdictions individuelles. Les clamps de sécurité
continuent de gagner ; un plafond commun à P1 interdit effectivement P5 à M2.

La surveillance de position ne peut être simplement bypassée : le profil fait varier la géométrie
benne. L'enveloppe admissible et la fin de phase doivent être définies avant l'essai ; un seuil
géométrique normal ne doit être ni contourné ni absorbé dans un offset qui suit la mesure.

Sortie de profil à une limite : arrêt commun proposé pour la première version ; aucune transition
automatique vers une nouvelle marche symétrique. Le rapprochement contrôlé ultérieur sera un lot distinct.

### T291-C — extension après recette

Extension au semi-auto uniquement après recette T291-B et adaptation explicite des étapes du cycle,
notamment AX8 à AX12, de la géométrie benne et du contrôle d'égalité de PRG04 §7.
Si l'essai demandé est semi-auto, T291-C devient un prérequis de cette première livraison.

## 4. Lot limites — seuils fonctionnels demandés

H = limite haute nominale configurée (7,50 m par défaut). Les offsets ne suivent pas la position
instantanée du capteur et ne s'additionnent pas aux overrides de conduite.

| Niveau | Condition proposée | Réaction |
|---|---|---|
| Approche haute Both | M1 >= H - distance de ralentissement configurée | Plafond commun aux deux treuils |
| Arrêt normal haut Both | M1 >= H | Arrêt normal commun ; pas besoin d'égalité parfaite des positions |
| Filet position | M1 OU M2 corrigé >= H + 1 m | SafeStop des deux, y compris en unitaire |
| Capteur haut physique commun NC | TopPositionFree_DI = FALSE | SafeStop des deux |
| Escalade temporelle | 1 s après événement capteur haut, mouvement dangereux ou contacteurs non relâchés | PowerCutOff mémorisé |
| Escalade spatiale | M1 OU M2 corrigé >= H + 2 m | PowerCutOff sans TON, dès le scan de détection |

Exemple : H=7,50 => SafeStop position à 8,50 et PowerCutOff à 9,50. H=8 => seuils 9 et 10.
À confirmer : référence M2 corrigée et traitement en manipulation benne, validité de la correction,
politique homing/override et dégagement descendant après arrêt sûr. La montée sur capteur actif
doit rester interdite ; ne pas désarmer l'escalade par relâchement joystick ou changement de mode.

Ne pas modifier PostRampTimeout global pour obtenir 1 s : il sert à d'autres mécanismes.
Prévoir une temporisation dédiée, déclenchée sur l'événement de butée avec mémoire adaptée aux rebonds.
Le retour disponible `ContactorsReleased_DI` est collectif : il ne prouve pas quel contacteur est collé.
Les DQ prouvent une commande électrique, pas l'état mécanique. Le mouvement doit aussi être surveillé
par mesure valide, même si les contacteurs sont annoncés relâchés.

### L-A — référentiel commun haut et bas

Définir le producteur métier de la limite légale, consommé au bon scan et projeté ensuite à l'IHM.
La conduite Both suit M1 pour approche et arrêt, mais les limites physiques de longueur câble par axe
restent prioritaires. En unitaire, chaque axe garde ses limites propres, M2 dans son référentiel pertinent.
Ne pas recopier la mesure M1 dans les capteurs M2 pour réaliser ce changement.

Décision utilisateur 2026-09-15 : en M1 seul et en M1+M2 Both, M1 est l'autorité du FDC logiciel
nominal H et du profil d'approche. En Both, M2 est suiveur et reçoit le même palier que M1. En M2
seul, la position M2 corrigée reste la référence. M2 corrigé ne doit pas arrêter nominalement le
Both à H : il conserve ses filets indépendants SafeStop H+1 et PowerCutOff H+2.

REX snapshot `Snapshot_Troubleshooting_20260915_111950.csv` : à M1=7,367 m, M1 était dans la zone
haute et bridé P1 tandis que M2 corrigé, décalé d'environ 0,73 m, restait hors zone et demandait P5.
La barrière d'égalité finale neutralise alors les demandes Both sans message. Ce mécanisme existe
aussi hors simulation ; seule l'évolution physique de l'écart change.

Audit Git indépendant 2026-09-15 : **régression identifiée, confiance 95 %**. `f36c4480` a introduit
la neutralisation Both sur toute différence de demandes finales ; `92601d2c` a ensuite passé AX12
de P4 à P5, rendant visible le couple P1/P5. T291-A (`196abd5c`) est limitée à la descente AX4..AX7.
T292/T293 (`9a6aa738`, `885ad4b1`) n'ont pas modifié la commande réelle : la simulation a seulement
révélé le défaut latent en reproduisant un écart M1/M2. La mesure codeur n'est pas mise en cause.

### L-B — filets hauts position et capteur

Implémenter séparément SafeStop H+1 et capteur NC. Tests : M1 seul, M2 seul, Both, offset modifié,
position invalidée, bypass/override, capteur atteint à l'arrêt, déplacement descendant de dégagement.

### L-C — escalades indépendantes

Implémenter timer 1 s et seuil H+2. Tests autour des bornes temporelles et spatiales ; contacteurs
déclarés OFF mais codeur mobile ; codeur immobile mais retour contacteurs ON ; capteur rebondissant ;
reset avec cause présente ; disparition cause sans acquittement ; aucun redémarrage spontané.
Sans mesure fiable, H+1/H+2 ne constituent pas une protection disponible : définir le repli explicitement.

## 5. T290 — dernier lot, découplé

Une TON dédiée sur l'OR des deux sources d'extraction. Proposition 1,5 s (choix humain en attente).
Plafond extraction 1 avant échéance, 2 après ; agrégation par MIN avec toutes les autres bornes.
Tester 1490/1500/1510 ms au scan nominal, sortie/rentrée de phase et sources auto/manuelle ; ajouter
successivement chaque clamp existant pour démontrer qu'il reste prioritaire.

## 6. Séquence de livraison et preuves

1. Sauvegarde initiale (faite), revue expert, décisions utilisateur et contrats précis.
2. T291-A/B en priorité ; un seul profil et mode initial, version OFF nominalement.
3. Essai utilisateur avec chronogramme court : paliers, DQ, retours contacteurs/freins, positions,
   profil actif/refusé, causes d'arrêt. Recette ou retour au bundle précédent identifié.
4. L-A puis L-B puis L-C avec recette à chaque frontière (ordre à ajuster si revue impose un prérequis T291).
5. T290, puis recette combinée des trois lots.

À chaque lot : tests ST et intégration ciblés, garde automatique `fix:` + `guard:` pour bugs corrigés,
bundle complet + diff des objets touchés, G200 --report et gates palier C ; suite complète fin d'ensemble.
Nom de fichier identique au nom de POU et langage généré cohérent, sources ST conservées.
Table d'impact producteurs → routage → consommateurs revue avec diff réel avant restitution.
Ne pas annoncer une absence absolue d'effets de bord : documenter les scénarios couverts et limites.

Nommage : NC-050 demande/commande, NC-030 unités, NC-100 permis positifs, NC-110 DUT propriétaire.
Chaîne : intention Req → cible Tgt bornée par profil et limites → Cmd final → Act/retour mesuré.
Sources : NAMING_CONVENTION.md, AF-02, AF-03 et AF-10 ; compléter lecture intégrale avant code.

## 7. Points à trancher avant le premier code concerné

- T291 : mode d'essai et enveloppe mécanique autorisée pour M1=P1/M2=P5, arrêt de cette phase.
- Limites : M2 corrigé fiable, dégagement descendant et exceptions homing explicitement définis.
- T290 : durée initiale exacte (1,5 s proposée).
- Coordination : T288 reste verrouillée par Antigravity et touche les mêmes mécanismes ; vérifier
  l'absence d'édition concurrente avant toute modification de FB_Safety_Winch.

## 8. Revue indépendante reçue et intégrée

Reviewer : sous-agent `challenge_plan`, 2026-09-15. Verdict : BLOCK avant implémentation,
phasage pertinent après résolution des points suivants. Aucune autorisation d'essai déduite.

1. **BLOCK référence M2** : `FB_Bucket.st:587-590` peut fixer OffsetTargetM à M2-M1 en
   manœuvre ; `:628-632` applique ce résultat à ActiveOffsetM. M2-ActiveOffsetM peut donc
   devenir M1 : cette correction ne constitue pas une barrière M2 indépendante en unitaire.
   L'affichage M2PositionCorrected utilise DisplayOffsetM (`PRG04:1672`), autre référence.
   Il faut choisir et qualifier une référence calibrée, avec évolution autorisée explicitement
   bornée. La réponse « position corrigée » seule ne suffit pas à lever ce point.
2. **MAJOR timer top** : référence temporelle = événement de capteur, mémoire et gestion de
   rebond ; aucune inhibition héritée benne/homing admise implicitement. Dégagement à spécifier.
3. **MAJOR retours** : concordance DQ prouve les commandes, pas le collage mécanique ; retours
   collectifs et mouvement mesuré à traiter indépendamment.
4. **MAJOR limite légale** : aucun offset de dépassement bas autorisé par analogie avec H+1/H+2.
   Corriger ensemble producteur et consommateurs, sans accroître la profondeur admissible.
5. **Arrêt normal** : perte de permis actuelle devient EffectiveSafeStop (`FB_Winch:169-171`).
   Le remplacement par un arrêt normal est une évolution fonctionnelle dédiée, à tester avec
   le maintien de sens et les retours de frein ; ne pas le présenter comme déjà existant.

Option B retenue comme recommandation de revue. L'option A peut inverser la signification d'un
plafond P1 et nécessite malgré tout une adaptation des comparateurs ; elle est écartée du premier essai.
T291 ne pourra être testé qu'après définition de l'enveloppe mécanique de sa phase asymétrique.
La revue logicielle ne vaut pas recette de la machine.

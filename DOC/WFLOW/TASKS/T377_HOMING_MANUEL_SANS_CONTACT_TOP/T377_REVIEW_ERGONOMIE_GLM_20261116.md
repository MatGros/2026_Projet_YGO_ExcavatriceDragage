🟡 **ADVISORY** — Revue par simulation mentale du grafcet T377 : 6 pièges MAJOR identifiés, dont 1 risque de corruption du datum post-preset à trancher sur le code réel. Durée : n/a (analytique, sans exécution).

*Portée : pas d'accès fichiers (lecture seule demandée). Tout constat est une inférence du descriptif fourni ; les « à vérifier » doivent être tranchés sur le code. Note : `AGENTS.md` non chargé ( inaccessible) — n'a pas bloqué l'analyse.*

## A. Constats (parcours dans l'ordre)

**P1**
1. Démarrage spontané au boot : impossible (edges + MAINT_N2 + manche neutre) — conforme par conception décrite.
2. Homing unitaire (BtnHome/BtnHomingAtZero) pendant le cycle : masquage non démontré ; un préset unitaire accidentel en cycle casse la cohérence M1/M2 — BLOQUANT si absent → interlock explicite `hx==HX0` sur les 2 boutons + test.

**P2**
3. Expiration ClimbTimer 300 s : comportement/message/reprise non spécifiés, atteignable au palier 1 ; remise à zéro sur chute de commande = garde contournable par impulsions — MAJOR → définir l'expiration (coupure + cause « budget montée » + reprise après relâchement) et tracer le cumul.
4. Perte de cohérence M1/M2 (skew) en montée : stop autorisé mais sans cause/message décrit → reprise à l'aveugle sur un couple désynchronisé — MAJOR → cause dédiée + message « ne pas reprendre » + condition de reprise.
5. Fatigue homme-mort (benne HX1 + montée HX2 en continu) : risque de calage du BP — MINEUR → afficher « relâcher = arrêt sûr, reprise libre ».
- Relâche homme-mort en HX2 : conforme — arrêt net, pas de latch, reprise par simple traction.

**P3**
6. Contacts capteur reproductibles sans limite, sans compteur ni trace → banalisation d'un contact mécanique haut — MINEUR → compteur contacts + trace C8 datée (miroir du compteur de refus).
7. C8 non-latchant disparaît à la libération alors que le blocage persiste : l'opérateur perd la raison de l'interdiction — MAJOR → bannière persistante « contact capteur — descendre » tant que latch actif.
8. Effacement du latch à la transition HX2A→HX2 non spécifié ; si résiduel, la garde « pas de latch » bloque la montée en silence — MINEUR (vérif.) → effacer le latch exactement sur la transition + test.

**P4**
9. Refus de validation sans révélation de la garde fautive (5 gardes) ni compteur visible → répétitions à l'aveugle — MAJOR → checklist IHM temps réel des 5 gardes + compteur affiché.
- Rien d'écrit au refus (pas de HomeReq prématuré) : conforme.

**P5**
10. Validation en HX1/HX1a/HX4/HX5 : inertie totale sans message → gestes parasites (« ça bloque ») — MINEUR → geste attendu affiché par étape, bouton hors contexte = neutre affiché.
11. Après HX6 (retour HX0), un appui de Validation (réflexe d'acquittement) redémarre un cycle complet — bouton polymorphe sans confirmation — MAJOR → réserver le démarrage au Start IHM ou re-confirmation après MachineHomed.

**P6**
12. HX3 « un seul HomeReq » : pulse perdue (coupure, drive absent) → pend jusqu'au timeout 60 s, récupération opaque — MINEUR → ré-armement sur front drive-ready ou diagnostic affiché pendant l'attente.
13. Coupure puissance non signalée (PowerCutOff masquée MAINT_N2) : treuils morts sans cause à l'écran — MINEUR → bandeau info « puissance coupée (masquée MAINT_N2) ».
14. Rétentivité de l'état cycle/latches au reboot API non spécifiée : retour HX0 implicite relâche M3Locked et le forçage WinchSel avec benne fermée/couplée — MAJOR (si non retentif) → état retentif OU procédure boot tranchée et testée.
- Preset accidentel : non démontrable par les gardes décrites — conforme, sous réserve du point 16.

**P7**
15. Pas d'abandon documenté entre HX1 et HX6 (Reset seulement HX2A/HX7) + M3Locked → opérateur captif (translation légitime impossible, benne mal fermée, urgence) — MAJOR → « Annuler le cycle » à chaque étape (arrêt + neutre + confirmation), réouverture benne encadrée. M3Locked est légitime en soi (skews câbles) ; ne l'est plus sans porte de sortie.

**P8**
16. Bascule du sélecteur pendant HX2/HX2A : sans effet (commande forcée) mais aucun message décrit ; inversion possible treuil affiché/commandé si un consommateur suit le sélecteur physique (risque codeur) — MAJOR si le routage affichage suit le sélecteur, sinon MINEUR → bannière « FORÇAGE treuil : 0 (couplé) » + figer l'indicateur sur la commande réelle.

**P9**
17. HX7 : relance possible sans réparation ni prérequis affiché ; si la cause (timeout 60 s / bande ±0,10) n'est pas montrée, boucles à l'aveugle — MAJOR → écran HX7 = cause du dernier échec + n° de tentative + prérequis avant « Relancer ». Chemin de sortie unique : conforme.

**P10 + intégrité datum**
18. **Risque datum** : entre HX3 et HX6, la montée n'est pas décrite comme interdite (latch seulement HX2/HX2A) ; un rappel de manche après preset fait tourner les codeurs dans la butée → dérive du datum, et HX4/HX6 ne re-vérifient pas la bande ±0,10 après mouvement. La barrière montée (PRG_04:1126) couvre-t-elle ce cas ? À trancher — BLOQUANT si ClimbPermit est global et barrière muette → étendre « montée interdite » (ou re-vérification ±0,10 à l'entrée HX6) de HX3 à HX6 + cause à la tentative.
19. BP console (JoyBtnRaw) retiré du démarrage : gestuelle héritée sans effet, vécue comme panne — MINEUR → libellé contextuel du bouton Validation + brief de conduite.
20. Confusion BtnValidate (IHM, press) vs homme-mort (BP manche, maintien) : deux grammar d'actions différents pour des gestes voisins — MINEUR → consigne « geste de fin = relâcher, puis valider » affichée en HX2.

## B. Conformes par conception décrite (à confirmer sur code)

- Relâche homme-mort en montée : arrêt net, pas de latch, ClimbTimer reset.
- Refus validation : rien d'écrit.
- Perte datum en mouvement : cause 0 latchée + Reset requis.
- HX2A : HomeReq impossible — la voie preset ne peut pas s'armer avec un latch contact.
- HX4 : échec bande → 1 ré-émission puis HX7, pas de commit sous bande fausse.

## C. Question A — effets de bord hors parcours

21. MachineHomed sans invalidation décrite : les lecteurs (interlocks aval, checklist, IHM) croient le datum bon après drift/cause 0 post-commit — MAJOR → auditer tous les lecteurs, invalider sur cause 0/Reset.
22. Edge partagé BtnValidationEdge (start + éventuels consommateurs checklist/sim) → double consommation, décisions divergentes — MINEUR → un seul producteur d'edge, lecteurs sur copie latched 1 cycle.
23. Checklist et simulation à réécrire pour la méthode « sans contact TOP » ; le sim doit modéliser JoystickDeflected au démarrage, sinon scénarios faux — MINEUR → MAJ checklist + scénarios sim avant recette.
24. WinchSel forcé tout le cycle : consommateurs « dernière sélection » (logs, autres FB) faussés ; restauration post-HX6 non décrite — MINEUR → restaurer/restater et documenter.

## D. Question B — Top 5 cadrage

- **R1** : écran par étape (HX1→HX7) + gardes temps réel (start, 5 gardes validation, latches) — zéro refus/arrêt silencieux (couvre 3,4,7,9,10,13).
- **R2** : désambiguïser le bouton unique — libellé contextuel ou boutons distincts, confirmation avant relance post-HX6/HX7 (11,17,19).
- **R3** : traçabilité — compteurs datés (refus, contacts, tentatives), bannière persistante latch, message ClimbTimer (6,7,17).
- **R4** : abort universel par étape + trancher rétentivité boot API et expiration ClimbTimer (14,15).
- **R5** : intégrité datum — interdire la montée ou re-vérifier ±0,10 de HX3 à HX6 ; audit MachineHomed + invalidation cause 0 (18,21).
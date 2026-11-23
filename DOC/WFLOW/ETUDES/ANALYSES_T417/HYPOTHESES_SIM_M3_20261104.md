# T417-F — Dossier constats et hypothèses de simulation M3

> 2026-11-04 · Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T417-F_SIMU_M3_HYPOTHESES.yaml` · Statut : **brouillon Phase 1, à valider à PA1**
> Aucune hypothèse de ce dossier n'est validée. Aucun essai n'a été lancé pour ce dossier.
> Audit Auditeur A du 04/11 : verdict MAJOR, écarts corrigés dans cette version ; T8, C3 et les cotes `da7ba246` revérifiés sur source par CC01.

## 1. Règles

- Les constats sont des repères approximatifs pour juger des hypothèses, jamais des cibles. Coller exactement à une observation approximative est une tromperie.
- Une trace n'est utilisable que si son nom ne contient pas SIMU ; elle est citée par nom de fichier et timecode.
- Un constat n'est pas une cause. Les interprétations sont séparées des faits.

## 2. Constats exploitant

Chemins relatifs à `DOC/WFLOW/`. `TEMOIGNAGE` = `REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md`. Citations conservées telles qu'écrites dans la source.

**Valeur du témoignage** : il « repose notamment sur des souvenirs » et n'est « pas une preuve instrumentée » (`TEMOIGNAGE:5`). Le registre demande de distinguer dépassement à l'arrêt et déplacement très lent, sans cause commune imposée (`:26`).

| # | Constat | Citation | Source | Date |
|---|---|---|---|---|
| C1 | Arrêt manuel propre **(réel ou simulé non attribué)** | « en Manuel, l'arrêt sur Trémie et P1 est propre, avec une décélération correcte et un arrêt à environ 10 cm après le capteur » ; le registre précise : « Le contexte du constat manuel est conservé tel qu'écrit, sans attribution supplémentaire » | `TEMOIGNAGE:15,25` | Recueil 30/10 |
| C2 | Cycle : le chariot continue | « en manuel et en maintenance, M3 s'arrête correctement sur les fins de course » ; « en cycle automatique, à l'arrivée sur P1 ou Trémie, le chariot continue d'avancer ». Conditions : « reproductible (à chaque cycle), non instrumenté », joystick maintenu | `TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md:31,48,56` | 20/09 |
| C3 | Dépassement rapporté avant le passage à 20 Hz | « lors de l'arrivée sur une position, la translation peut continuer et dépasser le capteur. Cause non établie : rebond/clignotement capteur, effet de charge mécanique ou logique de séquence » | `REGISTRES/REGISTRE_MES_Rapport_Mail_GCAM_20260915.md:3,32` | 15/09 |
| C3b | Régression d'arrêt | « une régression flagrante a été relevée le 25/09 : le chariot s'arrête bien au-delà du capteur physique P1 » ; « Une suspicion analogue avait été perçue en fin de journée de MES côté Trémie » (non datée) | `REGISTRES/REGISTRE_PrepaNextMES_20260926.md:30-31` | 25/09 |
| C4 | Capteur instable | « un capteur peut commuter rapidement entre 0 et 1 pendant environ 1 s » | `TROUBLESHOOTING/FICHES/TROUBLESHOOTING_M3_FDC_Frein_RebondCapteurs_20260915.md:19` | 15/09 |
| C5 | Défaut frein selon la fréquence | « des défaut brake M3 au passage de AX14 à AX15 » ; « la PV 20HZ a quasiment masqué le défaut ... alors que 10Hz bcp plus souvent le défaut et commande électrique moins bonne saccade plus » | `TEMOIGNAGE:12` | Recueil 30/10 |
| C5b | Défaut au retour P1 | « le défaut pouvait arriver au retour P1 mais pas souvent (infirmation moins fiable pas certain) » | `TEMOIGNAGE:13` | Recueil 30/10 |
| C6 | Déplacement lent en semi-auto | « le chariot continue de bouger doucement vers la butée après l'arrêt même pendant l'ouverture benne » (réel) | `TEMOIGNAGE:11,23` | Recueil 30/10 |
| C6b | Ampleur du déplacement **(attribution à préciser)** | « déplacement lent de 30 à 50cm vers butée meca » : phrase d'un bloc mêlant réel et simulation, chiffre absent de la liste « Réel rapporté » | `TEMOIGNAGE:15,23` | Recueil 30/10 |
| C7 | Saccades à 10 Hz | Inclus dans C5 : « commande électrique moins bonne saccade plus » | `TEMOIGNAGE:12` | Recueil 30/10 |
| C8 | Freinage variateur | « le variateur utilise toujours sa résistance de freinage donc rampe contrôlée » (« A confirmer ») | `TEMOIGNAGE:11` | Recueil 30/10 |
| C9 | Production | « ~100 cycles automatiques complets réalisés sans blocage majeur » | `REGISTRES/REGISTRE_PrepaNextMES_20260926.md:12` | 24/09 |
| C10 | Disparition puis retour du défaut | MES-056, lieu « Banc d'essais / Machine », « A surveiller » : « ne presente plus, a ce stade, le defaut de sequence/retour frein » ; 15/09 : défaut réapparu aux positions Trémie et P1 | `REGISTRES/REGISTRE_Suivi_MiseEnService_20260907.md:138-141` ; fiche Rebond `:7` | 07/09, 15/09 |
| C11 | Réglages MES | F01.22/23 : « Accel = 1,5 s · Decel = 2 s » ; rampes automate 40 et 50 %/s en série | `REGISTRES/REGISTRE_Suivi_MiseEnService_20260902.md:283-285` | 05/08 |
| C13 | Blocage et correctifs programme | « Chariot M3 bloqué à l'étape P1 en route vers la trémie » ; « Déblocage terrain confirmé par l'opérateur » ; « jeton d'état insensible aux rebonds mécaniques » | `REGISTRES/REGISTRE_Suivi_MiseEnService_20260922.md:16`, `...20260923.md:42,47` | 22-23/09 |

**Pistes écrites, pas des constats** : approche 10 → 20 Hz du 23/09 et délai retour frein 800 → 1000 ms, non daté (« Pistes causales à investiguer », `REGISTRES/REGISTRE_PrepaNextMES_20260926.md:33-35`).

**Hypothèses de l'exploitant, pas des faits** : « roue libre sur l'inertie ou une pente de rail », puis « relâchement du frein silencieux ou pas (aucun souvenir si IHM affiche etat frein) » (`TEMOIGNAGE:11`). Le registre demande de ne pas postuler une roue libre immédiate au retrait de commande (`:24`).

**Simulation, à ne pas attribuer au réel** : −0,45 m, +5,38 m, observations à l'oscilloscope (`TEMOIGNAGE:15,17,25`).

**Inconnues** : gain Hz ↔ m/s (tableau vide `REGISTRES/REGISTRE_Suivi_MiseEnService_20260902.md:339-343`, T301 non fait, estimation 0,0551 sous hypothèses contre 0,02 en repli : `AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:134,149`), positions des cames et butées, pente, couple et temps de frein.

**Attention source** : `TROUBLESHOOTING_T334…:455` titre « traces terrain 71/72/73 », mais ces fichiers portent SIMU dans leur nom : exclus.

## 3. Observations de traces

Traces sous `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/`, sans SIMU dans le nom. Pas médian 100 ms : un événement de quelques scans n'y est pas résolu. Fréquence brute divisée par 100.

| Réf | Fichier | Timecode | Observation |
|---|---|---|---|
| T1 | `Suivi_90_MES_SoirDisj_M3_20260923.trace` | 34,49 → 36,02 s | AX2 : P1 1→0 et mot 2→0 à 20,0 Hz ; P1 rebascule 34,59 et 34,69 ; fréquence nulle vers 35,52 ; frein DI 1→0 à 36,02 |
| T2 | idem | 108,24 → 109,78 s | AX14 : Trémie 0→1 et mot 1→0 à 20,0 Hz ; pas de rebond Trémie échantillonné ; AX15A et frein DI 1→0 à 109,78 |
| T3 | idem | 135,97 → 138,01 s | AX2 : P1 1→0 puis rebascule 136,07 et 136,18 ; frein DI 1→0 à 138,01 |
| T4 | idem | 95,83 → 96,02 s | Départ de P1 : P1 bascule trois fois entre 23 et 28 Hz |
| T5 | idem | toute la trace | Trois arrivées à 20 Hz sans transition de `TranslationState.Error` |
| T6 | `archives/Suivi_TranslationM3bug_20260904_27.trace` | ≈ 26,44 → 27,06 s | Arrivée à 10 Hz : Trémie 0→1, mot 1→0, frein DI 1→0 et `State.ErrorId` 64 sur le même échantillon ; Trémie 1→0 vers 26,54 et non repris ; fréquence nulle vers 27,06 |
| T7 | idem | 14,86 → 15,06 s | PV bascule trois fois entre 29 et 25 Hz, mot déjà à 0 |
| T8 | `archives/Suivi_Cycle_M3_20260906_49.trace` | 23,283 → 25,268 s | Arrivée à 10 Hz : à 23,283 Trémie 0→1, mot 1→0, frein DI 1→0 à 10,00 Hz ; à 23,368 frein DI 0→1 à 9,92 Hz ; Trémie reste à 1 ; frein DI 1→0 définitif à 25,268 |
| T9 | `Suivi_89_MES_SoirDisj_20260923.trace` | 30,59 ; 37,61 ; 40,39 s | `EstimatedPosM3_M` : 1,764→5,020 ; 11,860→15,010 ; 16,503→20,000 |
| T10 | idem | 103,66 ; 110,69 ; 114,14 s | `EstimatedPosM3_M` : 18,502→14,980 ; 8,178→4,980 ; 3,205→−0,004 |

**Calcul à challenger** (T11, `Suivi_90_MES_SoirDisj_M3_20260923.trace`, trajets démarrant à 21,40 / 94,41 / 122,94 s) : intégrale de fréquence de 550,8 / 553,6 / 551,2 Hz·s jusqu'à fréquence nulle (14,1 à 14,9 s), ou 540,7 / 543,2 / 540,2 Hz·s mot actif seul (13,0 à 13,8 s). Le banc actuel vaut 250 Hz·s entre capteurs par construction (5 m / 0,02). Le programme du 23/09 n'avait pas ces 5 m : `da7ba246` porte PV/P2/P1/Maintenance = 5/15/20/30 m, gain 0,02, soit 1000 Hz·s attendus sur 20 m, et T9/T10 montrent les recalages sur ces cotes. Le passage à 1,5/3,5/5/10 m date de `d3dc9385` (28/10). Ce calcul pose une question, pas une conclusion : il suppose que la fréquence retournée suit la vitesse du chariot.

**Lecture prudente** : T6 et T8, deux arrivées à 10 Hz, montrent la même signature à l'arrivée (frein DI 1→0 sur l'échantillon de Trémie, fréquence à 10 Hz). Elles divergent ensuite : T6 frein non rouvert, `ErrorId` 64, Trémie perdue ; T8 frein rouvert au scan échantillonné suivant, pas de défaut, Trémie tenue. Un cas de chaque, à deux dates et deux versions de programme : rien à généraliser. Les arrivées Trémie à 20 Hz de T2 ne montrent pas cette chute, mais elles datent d'une autre version : aucune comparaison à conditions identiques n'existe.

## 4. Limites du modèle actuel

Lecture de `CODE/L_SIMULATION/` et `CODE/M_MAIN/PRG_02_Acquisition.st`.

| # | Limite | Conséquence | Source |
|---|---|---|---|
| L1 | Vitesse esclave de la fréquence, frein ouvert | Ni couple, ni glissement moteur, ni saccade | `FB_Sim_Translation.st:294,338` |
| L2 | Frein serré : décélération puis blocage | Pas de patinage possible | `:339-345` |
| L3 | Roue libre seulement frein ouvert sans couple | Pente et charge inactives frein fermé | `:301-302` |
| L4 | Cotes et gain recopiés de l'automate | Pas d'écart de gain ni de cote possible : seuls les chemins frein et roue libre créent un écart vrai/estimé | `PRG_02_Acquisition.st:378-383`, `FB_Sim_Translation.st:9-14,303-345`, `GVL_Simulation.st:79,84` |
| L5 | Intermittence capteur désactivée par défaut, came hypothétique | Instabilité d'environ 1 s absente du nominal ; la zone de perte active reste courte (0,04 m) | `GVL_Simulation.st:43,90-92`, `FB_Sim_PositionSensor.st:28-30` |
| L6 | Bruit capteur lié à l'angle de charge, zone de came spatiale de largeur fixe | Durée liée à la vitesse pour la came seulement ; forme et largeur hypothétiques | `FB_Sim_Translation.st:414-423` |
| L7 | La charge suspendue agit sur le chariot, mais aucune entrée ne reflète l'état de la benne | Ouverture benne sans effet propre en AX15B | `FB_Sim_Translation.st:54-58,304-307,397`, `FB_SimBench.st:669-706` |

## 5. Hypothèses

Chaque ligne est réfutable : « Infirmée si » décrit ce qui l'écarterait. Les paramètres seront explorés sur une plage, jamais réglés sur un constat.

| ID | Constats | Mécanisme proposé | Paramètres inconnus | Sens attendu si vraie | Infirmée si | Code de référence |
|---|---|---|---|---|---|---|
| H-P | Fiabilité position, T9, T10, T11 | Le procédé a sa propre géométrie et son propre gain, différents des réglages automate | Cotes, gain | Écart vrai/estimé et recalages aux capteurs, sans modifier l'automate | Aucun effet sur l'estimation avec plage large | Courant, à trancher à PA2 |
| H-A | C2, C3, C3b | Le cycle arrête par retrait de demande (rampe), le manuel par verrou axe et coupure Trémie. Le dépassement du 15/09 précède le passage à 20 Hz : la fréquence ne peut pas être sa seule cause | Rampes en série (C11) | Arrêt plus loin en cycle, distance croissante avec la fréquence d'approche | Distance identique entre cycle et manuel à fréquence égale | À trancher : la logique a évolué depuis T334 |
| H-K | C4, T1, T3, T4, T7 | Instabilité physique au seuil : vibration ou balancement combinés à la forme de came | Forme de came, amplitude, fréquence | Durée instable plus longue à faible vitesse de passage | Durée indépendante de la vitesse | Sans objet (procédé) |
| H-F | C5, C5b, C10 | À 10 Hz, l'instabilité recouvre la fin de rampe et la séquence frein ; un rebond relance demande ou desserrage, le watchdog 500 ms déclenche | Durée d'instabilité (H-K), temps de frein | Défaut plus fréquent à 10 Hz, sans faute injectée | Aucune relance de desserrage quelle que soit la plage | Version machine requise |
| H-S | C5, T6, T8 | Coupure Trémie de `PRG_06_Outputs` non filtrée : le front capteur ferme le frein en mouvement | H-K | Frein fermé en mouvement à l'arrivée, défaut selon la suite de la séquence | Coupure absente de la version machine | Version machine requise |
| H-G | C6 | Capacité de maintien finie : le frein patine lentement si l'effort dépasse le maintien | Capacité, effort | Déplacement frein « fermé », contact inchangé | Pas d'effort plausible dépassant le maintien | Sans objet (procédé) |
| H-R | C6 | Effort horizontal lors de l'ouverture benne (charge, câbles) | Géométrie câbles, masses | Mouvement concentré en AX15B | Effort négligeable sur toute la plage | Sans objet (procédé) |
| H-T | C6 (hypothèse exploitant) | Pente et frein réellement relâché | Pente, état réel du frein | Dérive tant que le frein ne tient pas | Le frein tient sur la plage de pente | Sans objet (procédé) |
| H-C | C7 | Couple simple : faible à basse fréquence, plus frottement | Courbe de couple, frottement | Vitesse irrégulière à 10 Hz, moins à 20 Hz | Vitesse régulière sur toute la plage | Sans objet (procédé) |

**Cas particulier C6** : aucune hypothèse H-G, H-R, H-T n'a d'effet attendu sur la logique automate tant que le mot capteurs ne change pas. Leur intérêt dépend de ce que le déplacement lent apporte aux tests AX15, point à challenger.

**À tracer** : le watchdog frein est de 500 ms (`FB_TranslationOutputInterlock.st:91`), le registre évoque 800 → 1000 ms. Le lien entre ces temporisations n'est pas établi ; H-F doit le préciser.

## 6. Points soumis au challenge

1. Mécanismes manquants ou redondants.
2. Hypothèses mal réfutables.
3. Risque de calage sur un constat.
4. Conflit de H-P avec la règle « source unique » et le gate G518 : un réglage automate et une vérité procédé sont-ils deux sources d'une même donnée ?
5. Code de référence : `main` ou programme machine v0.7.25 ≈ `da7ba246`.
6. Ordre proposé : H-P, H-A, H-K, H-F, H-S, H-G, H-R, H-T, H-C.
7. Modèle minimal suffisant : qu'est-ce qui change réellement une décision sur AX14–AX18 ?

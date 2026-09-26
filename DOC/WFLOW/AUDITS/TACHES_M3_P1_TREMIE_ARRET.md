# 📑 Inventaire des Tâches : Translation M3, Arrêt, P1 et Trémie en Cycle Auto
Total tâches identifiées : 25

| ID | Statut | Crit. | Domaine | Titre | Tags |
|---|---|---|---|---|---|
| **T392** | ⏳ | C1 | SAFETY / TRANSLATION M3 / SEQUENCEUR | M3 SEMI_AUTO bloque en boucle : ArrivalLock ne se leve pas P1->Tremie, mapping SelTarget=3 fausse ArrivalWasTremie | `P1, Trémie, Arrêt/Frein, Cycle Auto` |
| **T383** | ⬜ | C4 | CYCLE_SEMI_AUTO / SEQUENCEUR / BENNE / TRACABILITE_GEL | DECHARGE — MICRO-STEP de sequencage benne a la tremie (AX15D) + retrait du saut HORS GEL AX15B vers AX10 + amendement du GEL + garde-fou GEL<->code | `P1, Trémie, Arrêt/Frein, Cycle Auto` |
| **T334** | ⏳ | C3 | CYCLE_SEMIAUTO / TRANSLATION_M3 / SECURITE_MOUVEMENTS | Translation M3 : pourquoi deux chemins de commande (manuel/MAINT vs cycle auto) ? Chaînes complètes, comparatif, et dépassement P1/Trémie en cycle | `P1, Trémie, Arrêt/Frein, Cycle Auto` |
| **T249** | ✅ | C2 | TRANSLATION M3 / IHM / SECURITE | Remontee statut position M3 (bannier/messages) + verrou descente treuil general | `P1, Trémie, Arrêt/Frein, Cycle Auto` |
| **T252** | ✅ | C2 | REGISTRE MES 2026-09-04 - A TRAITER DEMAIN | Registre des points ouverts session MES 2026-09-04 (a traiter/verifier demain) | `P1, Trémie, Arrêt/Frein, Cycle Auto` |
| **T287** | ⏳ | C3 | TRANSLATION_M3 | Régression M3 sur butées — escalade graduée sans toucher FB_Brake | `P1, Trémie, Arrêt/Frein` |
| **T382** | ⬜ | C3 | CYCLE_SEMI_AUTO / MOUVEMENT / BENNE | AX3 (a P1) : le pilotage benne annonce BIDIRECTIONNEL depuis le 05/09 mais le code ne genere JAMAIS ReqClose — incompletude prouvee, non couverte par les tests | `P1, Arrêt/Frein, Cycle Auto` |
| **T348** | ⬜ | C3 | TRANSLATION / DIAGNOSTIC | Run de trace 10 ms M3 / Tremie, scenarios A-B-C — prealable de mesure du plan T334 Phase 3 (lot L0), RUN HUMAIN | `Trémie, Arrêt/Frein, Cycle Auto` |
| **T345** | ⏳ | C3 | CYCLE_AUTO / TRANSLATION | AX14 vers AX15A : supprimer le relachement joystick exige a l arrivee Tremie (continuite sans a-coup) — REQUALIFIEE CANDIDAT L3, BLOQUEE · LOT L1 « L AXE POSSEDE SON ARRET » IMPLEMENTE, TESTE, NON COMMITE (DSH23) | `Trémie, Arrêt/Frein, Cycle Auto` |
| **T331** | ⏳ | C3 | CYCLE_SEMIAUTO / AX1_POSTURE / DIAGNOSTIC_IHM / SECURITE_MOUVEMENTS | Cycle SEMI_AUTO — famille "retour arrière contrôlé" : remise en posture AX1 (départ) ET repli AX15b (vidage, treuils bloqués) | `P1, Arrêt/Frein, Cycle Auto` |
| **T325** | ⬜ | C2 | TREUILS / SECURITE_MACHINE / INTERLOCK_DIRECTION | Analyse de risque - FB_WinchDirectionInterlock (D18) ne credite pas le temps reel deja passe au neutre | `P1, Arrêt/Frein, Cycle Auto` |
| **T250** | ⬜ | C3 | MESURE POSITION / REFERENTIEL BENNE (ActiveOffsetM) - TRANSVERSE | Rendre offset-aware tous les consommateurs de la position M2 (cycle, safety dure, legal, dive, HMI) | `Trémie, Arrêt/Frein, Cycle Auto` |
| **T361** | ✅ | C3 | TRANSLATION_M3 / ESTIMATEUR_POSITION / SIMULATION | URGENT - Recalage estimateur M3 : desynchro simulateur/estimateur + proposition utilisateur de recalage Tremie-seul | `P1, Trémie` |
| **T350** | ❌ | C3 |  | SimBench M3 — largeur de rebond capteur PAR CAPTEUR (limite F11 connue de T300) | `P1, Trémie` |
| **T301** | ⬜ | C1 | TRANSLATION_M3 / ETALONNAGE_ODOMETRIE | Translation M3 — Procédure et étalonnage terrain du ratio fréquence/déplacement et recalage des 5 capteurs | `P1, Trémie` |
| **T242** | ✅ | C2 | TRANSLATION M3 / POSITION | M3 translation - bits at position (tremie / P1 / zone maintenance) ne s activent pas | `P1, Trémie` |
| **T276** | ✅ | C3 | TREUILS_BENNE_TRANSLATION | Déblocage translation M3 depuis AtP1 vers Maintenance lors de l activation zone maintenance (FdC soft) | `P1, Trémie` |
| **T394** | ⬜ | C2 | CYCLE / TRANSLATION M3 / INTERLOCKS | Robustesse position P1 apres reboot sous l eau : qualification AtP1, translation PV/P2 et etude TglEnableWinchDescentLock_M3 | `P1, Cycle Auto` |
| **T319** | ✅ | C3 | CYCLE_AUTO / TRANSLATION | Cycle — continuité AX2 lorsque la translation est déjà confirmée P1 | `P1, Cycle Auto` |
| **T232** | ⏳ | C1 | TESTS & SPECIFICATIONS (TRANSLATION & SIMULATION) | Granularisation des tests unitaires et fiches AF pour Translation et Simulation (I_TRANSLATION & L_SIMULATION) | `P1, Cycle Auto` |
| **T233** | ✅ | C3 | CYCLE / HOMING MACHINE (G_CYCLE) | Implementation du GRAFCET de homing machine (FB_MachineHomingCycle HX0..HX6) | `P1, Cycle Auto` |
| **T273** | ⬜ | C3 | TREUILS_BENNE_TRANSLATION | Révision cinématique treuils en maintenance (Descente frein, Remontée synchro/fermée P1 & Inhibition défauts) | `P1, Arrêt/Frein` |
| **T366** | ⬜ | C3 | TRANSLATION_M3 / SIMULATION | PAS URGENT - Simulation rebond/bagotement capteurs M3 non visible au test (T300) | `Trémie` |
| **T214** | ✅ | C2 | SIMULATION / IHM | Stimuli de simulation des boutons IHM M3 (testabilité pilotage IHM) | `Trémie` |
| **T272** | ⏳ | C3 | TREUILS_BENNE_TRANSLATION | Verrou descente M3 basé sur State.AtMaintenance/AtP1 | `P1` |

---

## Détail des Tâches les plus pertinentes

### [T392] M3 SEMI_AUTO bloque en boucle : ArrivalLock ne se leve pas P1->Tremie, mapping SelTarget=3 fausse ArrivalWasTremie
- **Statut** : ⏳ | **Criticité** : C1 | **Domaine** : SAFETY / TRANSLATION M3 / SEQUENCEUR
- **Tags** : `P1, Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : URGENCE TERRAIN 2026-09-23 : chariot M3 bloque a AX14_TRANSLATE_DUMP (SEMI_AUTO), toute la chaine de permis est verte (Step4-6/8 OK, FinalInterlockState=READY, EffectivePermitM3_Tremie=TRUE, HeightInterlock OK) mais RampTargetPct reste a 0. Cause confirmee en live (watch CODESYS avec l operateur) : ...
- **Description** : Corriger le mapping ReqTremie/ReqMaintenance pour SelTarget=3 (P1) dans FB_TranslationCmdArbitrationM3.st afin qu une arrivee a P1 ne soit plus taguee comme "arrivee sens Tremie" dans FB_Translation.st (ArrivalWasTremie). Etudier si P1 doit produire un troisieme etat neutre (ni ArrivalWasTremie ni A...

### [T383] DECHARGE — MICRO-STEP de sequencage benne a la tremie (AX15D) + retrait du saut HORS GEL AX15B vers AX10 + amendement du GEL + garde-fou GEL<->code
- **Statut** : ⬜ | **Criticité** : C4 | **Domaine** : CYCLE_SEMI_AUTO / SEQUENCEUR / BENNE / TRACABILITE_GEL
- **Tags** : `P1, Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : DECISION EXPLOITANT 2026-09-22 : « si c est plus simple et sur d integrer une micro step de sequencage j avais dit pas de probleme ... en plus on peut ajouter un message utilisateur pour expliquer ». LE PROBLEME, PROUVE : le GRAFCET semi-auto est GELE (DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903....
- **Description** : Solution retenue par l exploitant : une MICRO-STEP de sequencage dediee, declaree au GEL, plutot qu une distorsion de la semantique d AX15B. A creer : un step AX15D_DUMP_BUCKET_JOG (nouvelle valeur d enum, a placer dans la logique de numerotation et A DECLARER au GEL — lien T324 qui regularise les s...

### [T334] Translation M3 : pourquoi deux chemins de commande (manuel/MAINT vs cycle auto) ? Chaînes complètes, comparatif, et dépassement P1/Trémie en cycle
- **Statut** : ⏳ | **Criticité** : C3 | **Domaine** : CYCLE_SEMIAUTO / TRANSLATION_M3 / SECURITE_MOUVEMENTS
- **Tags** : `P1, Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : Constat utilisateur 2026-09-20 : en manuel et en maintenance, M3 s'arrête correctement sur les fins de course (machine en service depuis des semaines). En cycle automatique, à l'arrivée sur P1 ou Trémie, le chariot continue d'avancer. Question de fond posée par l'utilisateur (recadrage 15:45) : en P...
- **Description** : ANALYSE D'ABORD, façon troubleshooting descendant. (1) Chaîne MANUELLE complète, de haut en bas : joystick -> variables intermédiaires -> arbitrage -> FB_Translation -> interlock final -> mots variateur (CommandWord / SetpointFrequency / frein), chaque variable nommée avec producteur et consommateur...

### [T249] Remontee statut position M3 (bannier/messages) + verrou descente treuil general
- **Statut** : ✅ | **Criticité** : C2 | **Domaine** : TRANSLATION M3 / IHM / SECURITE
- **Tags** : `P1, Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : MES 2026-09-04. (1) Aucune info M3 dans la banniere : l'operateur ne sait pas entre quels capteurs se trouve le pont ni s'il est arrete a une position. (2) Le verrou "descente M1/M2 interdite si M3 pas a P1/Maintenance" (DumpAtTremieDescentLocked) n'etait actif que pendant l'assist vidage-tremie. Pa...
- **Description** : Lot 2 volets, meme domaine M3 : A) INTERLOCK (fait, a valider banc) : PRG_03 - DumpAtTremieDescentLocked :=
   NOT (M3_AtP1Stable OR M3_AtMaintenanceStable) AND NOT Bypass.LimitSwitch
   AND NOT Bypass.Global, en MAINT_N1/N2. Reste a faire : bit IHM
   TglAllowWinchMoveAtTremie (autorise montee+desc...

### [T252] Registre des points ouverts session MES 2026-09-04 (a traiter/verifier demain)
- **Statut** : ✅ | **Criticité** : C2 | **Domaine** : REGISTRE MES 2026-09-04 - A TRAITER DEMAIN
- **Tags** : `P1, Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : Session MES longue 2026-09-04. Point general : validation operateur confirmee - pilotage benne fonctionne en MAINT y compris benne en position haute et benne a la Tremie (garde WinchSel=2 forcee + bouton override T249). Plusieurs points restent ouverts, non resolus faute de trace/donnees suffisantes...
- **Description** : A TRACER/DIAGNOSTIQUER (pas de donnees suffisantes aujourd'hui) : 1. A-coup a la fermeture benne au moment du passage en couple (transition
   WinchSel 2->0) - cause non tranchee (transition logicielle WinchSelTransitionHold
   vs mecanique). Grille de lecture donnee a l'operateur (WinchSelTransitio...

### [T287] Régression M3 sur butées — escalade graduée sans toucher FB_Brake
- **Statut** : ⏳ | **Criticité** : C3 | **Domaine** : TRANSLATION_M3
- **Tags** : `P1, Trémie, Arrêt/Frein`
- **Contexte** : Arrêt directionnel immédiat conservé ; qualifie un mouvement réel persistant après arrêt. Retour terrain 2026-09-15 : récidive du défaut séquence/retour frein M3 aux arrivées Trémie et P1. Une trace réelle montre des commutations capteur 0↔1 rapides pendant environ 1 s ; chemin exact encore attendu.
- **Description** : Phases contrôlées. Ajouter une phase de reproduction SimBench déterministe des fronts/rebonds capteurs et du retour frein avant toute correction de la séquence réelle. Contrat: TASK_CONTRACT_T287_M3_BUTEES_ESCALADE_GRADUEE.yaml

### [T382] AX3 (a P1) : le pilotage benne annonce BIDIRECTIONNEL depuis le 05/09 mais le code ne genere JAMAIS ReqClose — incompletude prouvee, non couverte par les tests
- **Statut** : ⬜ | **Criticité** : C3 | **Domaine** : CYCLE_SEMI_AUTO / MOUVEMENT / BENNE
- **Tags** : `P1, Arrêt/Frein, Cycle Auto`
- **Contexte** : DECOUVERTE 2026-09-22 (session exploitant sur le passage translation M3 -> treuils), VERIFIEE PAR L ORCHESTRATEUR SUR LE CODE, PAS SUR DECLARATION. Le commit ba95cbcd (2026-09-05T11:49:53, « fix(cycle): deblocage AX3 open bucket, interlock arming permit et ajout forcage etape », +87 lignes sur FB_Cy...
- **Description** : Rendre AX3 reellement bidirectionnel, sur le MODELE DEJA EXISTANT en AX10 (FB_CycleSemiAuto.st:1316) plutot qu en inventant une nouvelle forme : PUSH (Y-) -> ReqOpen := TRUE, ReqClose := FALSE ; PULL (Y+) -> ReqOpen := FALSE, ReqClose := TRUE ; NEUTRE -> les deux a FALSE. Rester en AX3 tant que l op...

### [T348] Run de trace 10 ms M3 / Tremie, scenarios A-B-C — prealable de mesure du plan T334 Phase 3 (lot L0), RUN HUMAIN
- **Statut** : ⬜ | **Criticité** : C3 | **Domaine** : TRANSLATION / DIAGNOSTIC
- **Tags** : `Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : Le plan T334 Phase 3 exige une mesure avant toute decision sur l arret de l axe M3. Aucune des 3 experiences du protocole de trace n existe dans le depot : les traces M3 existantes ont un pas MEDIAN de 100 ms, structurellement aveugles a l echelle de 1 a 10 scans ou se joue le verrou d arret (deboun...
- **Description** : Executer la procedure de trace 10 ms deja redigee (DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md) sur la tache MainTask, pour les 3 scenarios A (cycle nominal), B (cycle avec intermittence capteur d environ 1 s) et C (MAINT manuel, geste identique). Puis depouiller les CSV pour chiffre...

### [T345] AX14 vers AX15A : supprimer le relachement joystick exige a l arrivee Tremie (continuite sans a-coup) — REQUALIFIEE CANDIDAT L3, BLOQUEE · LOT L1 « L AXE POSSEDE SON ARRET » IMPLEMENTE, TESTE, NON COMMITE (DSH23)
- **Statut** : ⏳ | **Criticité** : C3 | **Domaine** : CYCLE_AUTO / TRANSLATION
- **Tags** : `Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : Le grafcet semi-auto gele le 2026-09-03 (DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md, table AT14) prevoit JoystickDeflected AND Translation_At_Tremie vers AX15A : un MAINTIEN, pas un relachement. Le code exige un relachement du joystick. Le brief T345 demandait d aligner le code sur la spec en...
- **Description** : REQUALIFIEE : ce n est pas un bug non corrige mais le lot L3 du plan T334, marque OPTIONNEL et conditionne. Le lot jumeau « uniformiser AX2/AX14 sur AX3 » a ete DEFINITIVEMENT ARRETE sur verdict de challenge independant (§10bis, MAJOR) : sans neutre, la demande M3 est recreee a chaque intermittence ...

### [T331] Cycle SEMI_AUTO — famille "retour arrière contrôlé" : remise en posture AX1 (départ) ET repli AX15b (vidage, treuils bloqués)
- **Statut** : ⏳ | **Criticité** : C3 | **Domaine** : CYCLE_SEMIAUTO / AX1_POSTURE / DIAGNOSTIC_IHM / SECURITE_MOUVEMENTS
- **Tags** : `P1, Arrêt/Frein, Cycle Auto`
- **Contexte** : Le message « Posture depart incorrecte (M3, FDC haut M1 ou benne) » est trop global : il peut citer M3 alors que M3 est déjà à P1, ou ne pas distinguer un M1 hors FDC logiciel haut d'une benne non qualifiée. AX1 doit exposer uniquement les causes réellement fausses et l'action associée. Si une remis...
- **Description** : Cadrer puis implémenter séparément DEUX diagnostics/procédures de la même famille (retour arrière opérateur contrôlé, phase 2 ensemble) : (1) AX1 : diagnostic par cause + remise en posture (M3→P1, FDC haut M1, benne). La montée de remise en posture conserve le TOP mécanique, AU, permis, FDC/limites ...

### [T325] Analyse de risque - FB_WinchDirectionInterlock (D18) ne credite pas le temps reel deja passe au neutre
- **Statut** : ⬜ | **Criticité** : C2 | **Domaine** : TREUILS / SECURITE_MACHINE / INTERLOCK_DIRECTION
- **Tags** : `P1, Arrêt/Frein, Cycle Auto`
- **Contexte** : Discussion troubleshooting AX10->AX11 (2026-09-20) : FB_WinchDirectionInterlock (D18, delais M1WinchCfg.DirectionInterlockDelayAscent/Descent = 800ms/500ms) impose la temporisation complete d'inversion de sens en la comptant UNIQUEMENT a partir de l'instant de la nouvelle demande (TON DirectionChang...
- **Description** : Tache d'ANALYSE et de CADRAGE uniquement -- aucune modification de code. Reference de comportement attendu = ce que Mathieu a defini fonctionnellement dans la discussion (credit systematique du temps d'arret reel), PAS le contenu des fiches AF qui peuvent etre perimees -- auditer leur fraicheur (dat...

### [T250] Rendre offset-aware tous les consommateurs de la position M2 (cycle, safety dure, legal, dive, HMI)
- **Statut** : ⬜ | **Criticité** : C3 | **Domaine** : MESURE POSITION / REFERENTIEL BENNE (ActiveOffsetM) - TRANSVERSE
- **Tags** : `Trémie, Arrêt/Frein, Cycle Auto`
- **Contexte** : MES 2026-09-04. Audit position par 3 agents (treuils/benne, M3, cycle/modes/safety). Cause racine des petites modifications a repetition : seule la couche FB_Winch (ralentissement) et FB_SyncDeviation / cross-check MecaE sont offset-aware. Le cycle SEMI_AUTO, les coupures dures FB_Safety_Winch cote ...
- **Description** : BLOCKERS. B1 PRG_07:373-374 - LimitLegalReached global calcule sur M2 brute -> corriger le terme M2 (- ActiveOffset_M) ou ne garder que M1. Reglementaire + coupe DescendPermit M1+M2 trop tot. B2 PRG_04:917 - CfgCableLimitDescentM (vers FB_Safety_Winch:305/536, coupure DURE descente M2) fourni brut -...

### [T361] URGENT - Recalage estimateur M3 : desynchro simulateur/estimateur + proposition utilisateur de recalage Tremie-seul
- **Statut** : ✅ | **Criticité** : C3 | **Domaine** : TRANSLATION_M3 / ESTIMATEUR_POSITION / SIMULATION
- **Tags** : `P1, Trémie`
- **Contexte** : URGENT, observation machine directe 2026-09-21. Deux constats lies : (1) FB_Sim_Translation.st:229 calcule sa vitesse physique via FullTravelTimeS=8.0s independamment de GVL_PERSISTENT._TranslationGainMetersPerHzSec utilise par instPosEstimatorM3 -- les deux vitesses divergent en simulation, causant...
- **Description** : Deux volets. VOLET A (correctif rapide simulation) : aligner FullTravelTimeS du simulateur sur le ratio GVL_PERSISTENT._TranslationGainMetersPerHzSec actuel (0.02, 50Hz=1m/s), pour que la simulation soit coherente en interne et testable. VOLET B (proposition utilisateur, ANALYSE + CHALLENGE avant im...

### [T350] SimBench M3 — largeur de rebond capteur PAR CAPTEUR (limite F11 connue de T300)
- **Statut** : ❌ | **Criticité** : C3 | **Domaine** : 
- **Tags** : `P1, Trémie`
- **Contexte** : T300 (livre, DSH03) a modelise le profil "BLIP COURT" de rebond capteur M3 (FB_Sim_Translation.st:42-52), avec les valeurs EXACTES de la trace terrain reelle du 2026-09-04 (Suivi_TranslationM3bug_20260904_27) : Tremie 1 excursion de 0,200 s, PV 1 excursion de 0,100 s. Retrouve et confirme le 2026-09...
- **Description** : Remplacer SensorBlipDurationS (REAL unique) par un ARRAY[1..5] OF REAL (une largeur de blip par capteur : Tremie/PV/P2/P1/Maintenance), comme deja envisage et ecarte dans T300 faute de perimetre. Permettre de rejouer en une seule execution la trace reelle complete (Tremie 0,2 s + PV 0,1 s simultanes...

### [T301] Translation M3 — Procédure et étalonnage terrain du ratio fréquence/déplacement et recalage des 5 capteurs
- **Statut** : ⬜ | **Criticité** : C1 | **Domaine** : TRANSLATION_M3 / ETALONNAGE_ODOMETRIE
- **Tags** : `P1, Trémie`
- **Contexte** : L estimateur de position FB_Translation_PositionEstimator s appuie sur un ratio arbitraire _TranslationGainMetersPerHzSec := 0.008333 m/s/Hz (50 Hz = 0.416 m/s) et des cotes théoriques de capteurs (Trémie 0m, PV 5m, P2 15m, P1 20m, Maintenance 30m). Une procédure d étalonnage simple sur machine perm...
- **Description** : Documenter et cadrer la procédure d étalonnage du ratio odométrique M3 et des cotes physiques : 1) Origine 0.0 m = Trémie (extrême gauche), 30.0 m = Maintenance (extrême droite), sens +1 vers Trémie (décroissant), sens -1 vers Maintenance (croissant). 2) Mesure terrain au décamètre/laser des cotes r...

### [T242] M3 translation - bits at position (tremie / P1 / zone maintenance) ne s activent pas
- **Statut** : ✅ | **Criticité** : C2 | **Domaine** : TRANSLATION M3 / POSITION
- **Tags** : `P1, Trémie`
- **Contexte** : Mise en service 2026-09-03/04 (objectif seance 3). A l arrivee sur la position tremie ou P1, et sans doute en zone maintenance, les bits at position M3 ne s activent pas / ne se calculent pas. Bloque l enchainement (verrous descente treuils lies a M3 a P1 / maintenance).

- **Description** : Diagnostic banc puis correction. Pistes : a) fenetre de tolerance position trop serree vs precision decodage capteurs M3 (FB_Translation_PositionDecoder / PositionEstimator) ; b) logique de detection de zone (maintenance) incorrecte ; c) position M3 pas mise a jour (reference M3 non faite / decodage...

### [T276] Déblocage translation M3 depuis AtP1 vers Maintenance lors de l activation zone maintenance (FdC soft)
- **Statut** : ✅ | **Criticité** : C3 | **Domaine** : TREUILS_BENNE_TRANSLATION
- **Tags** : `P1, Trémie`
- **Contexte** : À la position P1, si l opérateur active la zone maintenance, le mouvement direct vers Maintenance est verrouillé par le latch de coupure dure P1 et impose un recul vers Trémie.
- **Description** : Analyse et adaptation de la logique de coupure et de latch de limite de maintenance (M3_LimitSwitchMaintenanceStable) pour permettre le départ direct P1 vers Maintenance lors de l activation de la zone, tout en conservant la protection dure quand la zone est interdite.

### [T394] Robustesse position P1 apres reboot sous l eau : qualification AtP1, translation PV/P2 et etude TglEnableWinchDescentLock_M3
- **Statut** : ⬜ | **Criticité** : C2 | **Domaine** : CYCLE / TRANSLATION M3 / INTERLOCKS
- **Tags** : `P1, Cycle Auto`
- **Contexte** : REX terrain 2026-09-25 : suite au blocage a -6m, l equipe a suspecte la perte de l etat AtP1 apres coupure/reboot PLC. Si le PLC reboote alors que la benne est descendue (ou si la position intermediaire P1 n est plus qualifiee), verifier les conditions de reprise, l autorisation de translation vers ...
- **Description** : Etudier la possibilite de forcer ou requalifier l etat AtP1 pour eviter les blocages de descente au reboot sous l eau. Verifier les permis de translation M3 vers PV et P2. Etudier l exposition IHM de TglEnableWinchDescentLock_M3 pour debrayer le verrou de descente treuil lie au pont M3.

### [T319] Cycle — continuité AX2 lorsque la translation est déjà confirmée P1
- **Statut** : ✅ | **Criticité** : C3 | **Domaine** : CYCLE_AUTO / TRANSLATION
- **Tags** : `P1, Cycle Auto`
- **Contexte** : Après réinitialisation du graphe 7, un lancement avec joystick déjà poussé reste en AX2 même si M3 est déjà à P1 ; l'opérateur doit relâcher puis réenclencher.
- **Description** : Si la position P1 est déjà stable et qualifiée au démarrage, mémoriser ce fait et enchaîner AX2 vers AX3 ouverture benne puis plongée sous le même geste maintenu. Aucun saut de sécurité ni reprise automatique hors geste.

### [T232] Granularisation des tests unitaires et fiches AF pour Translation et Simulation (I_TRANSLATION & L_SIMULATION)
- **Statut** : ⏳ | **Criticité** : C1 | **Domaine** : TESTS & SPECIFICATIONS (TRANSLATION & SIMULATION)
- **Tags** : `P1, Cycle Auto`
- **Contexte** : Actuellement, I_TRANSLATION et L_SIMULATION ne disposent que d'un test monolithique (FB_Translation et FB_SimBench), masquant la visibilité unitaire des sous-briques. L'objectif est d'aligner ces deux domaines sur le modèle granulaire de H_TREUILS_BENNE en créant les fiches AF manquantes et les test...
- **Description** : 1. Créer la fiche AF manquante DOC/AF/AF_Partie-11_Fonction_Translation/FB_Translation_PositionEstimator_v1.0.md. 2. Créer les tests unitaires ST dans RESULTS/I_TRANSLATION/tests/ :
   - test_fb_safety_translation.st (TC-P11-SAF-001..003 : Enable, défauts Meca A/rotation/survitesse)
   - test_fb_tra...

### [T233] Implementation du GRAFCET de homing machine (FB_MachineHomingCycle HX0..HX6)
- **Statut** : ✅ | **Criticité** : C3 | **Domaine** : CYCLE / HOMING MACHINE (G_CYCLE)
- **Tags** : `P1, Cycle Auto`
- **Contexte** : Realise la spec figee DOC/WFLOW/CONTRACTS/GEL_GRAFCET_HOMING_CYCLE_20260903.md (partie 1). Transforme FB_MachineHomingCycle d'un guide passif en un cycle de homing machine sequentiel qui coordonne montee capteur, reference axes M1/M2 au vol sur front descendant, mise en position benne fermee et comm...
- **Description** : P1 : types + interface FB (Cfg +timeouts, nouveaux VAR_INPUT/VAR_OUTPUT, squelette CASE). P2 : corps GRAFCET complet (CASE HX0..HXF, sous-machine 3 appuis, SeenNeutral, guide S6) + rebuild tests StruCpp. P3 : cablage PRG_02/PRG_03 (Cfg, WinchM1/M2Cmd -> PRG_04, M3Locked) + bundle + G200 + gates pali...

### [T273] Révision cinématique treuils en maintenance (Descente frein, Remontée synchro/fermée P1 & Inhibition défauts)
- **Statut** : ⬜ | **Criticité** : C3 | **Domaine** : TREUILS_BENNE_TRANSLATION
- **Tags** : `P1, Arrêt/Frein`
- **Contexte** : Besoin d optimiser et sécuriser les mouvements treuils en maintenance : descente par relâchement de frein, remontée assistée synchro/fermée en P1 et étude d inhibition ciblée de certains défauts.
- **Description** : Étude d architecture et proposition technique pour la commande de descente par ouverture frein contrôlée, la remontée sécurisée M1+M2 bridée au Palier 1, et l inhibition sélective de défauts non critiques en mode Maintenance (MAINT_N1 / MAINT_N2).

### [T366] PAS URGENT - Simulation rebond/bagotement capteurs M3 non visible au test (T300)
- **Statut** : ⬜ | **Criticité** : C3 | **Domaine** : TRANSLATION_M3 / SIMULATION
- **Tags** : `Trémie`
- **Contexte** : Observation utilisateur 2026-09-21, apres test T345 : le rebond de capteur simule par SimBench (T300, blip Tremie ~0.2s / PV ~0.1s) n est pas visible/observe pendant un test manuel M3. Pas urgent selon l utilisateur (autres sujets prioritaires), a investiguer plus tard : verifier si le blip est bien...
- **Description** : Reproduire en simulation, verifier activation SensorBlipTransitions/SensorBlipDurationS par defaut, confirmer que le rebond est bien injecte (log/trace) meme si non visible a l oeil nu sur IHM. Pas de correction avant diagnostic.

### [T214] Stimuli de simulation des boutons IHM M3 (testabilité pilotage IHM)
- **Statut** : ✅ | **Criticité** : C2 | **Domaine** : SIMULATION / IHM
- **Tags** : `Trémie`
- **Contexte** : Intitulé complet : Ajouter des stimuli de simulation des boutons IHM M3 (SimBtnTremie/SimBtnMaintenance) pour tester le pilotage IHM en simulation quand JoyMaster est inactif.
- **Description** : Diagnostic 2026-09-01 : l'arbitrage M3 (FB_TranslationCmdArbitrationM3) utilise une sélection de source EXCLUSIVE pilotée par TglJoystickMaster. Quand JoyMaster est inactif, l'arbitrage utilise les boutons IHM (IHM.BtnTremie/BtnMaintenance), qui ne sont PAS simulés → impossible de tester le pilotage...

### [T272] Verrou descente M3 basé sur State.AtMaintenance/AtP1
- **Statut** : ⏳ | **Criticité** : C3 | **Domaine** : TREUILS_BENNE_TRANSLATION
- **Tags** : `P1`
- **Contexte** : Le verrou de descente ne doit pas utiliser les entrées brutes de position. La source consommée est l état validé GVL_IHM.M3Translation.State.
- **Description** : Remplacer les faits internes PRG_05 utilisés dans WinchDescentAuth_M3 par State.AtP1 et State.AtMaintenance, sans modifier les bypass ni les sorties physiques.

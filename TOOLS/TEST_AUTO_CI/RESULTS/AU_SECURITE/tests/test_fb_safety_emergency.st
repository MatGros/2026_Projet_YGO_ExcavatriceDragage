SETUP
VAR
    fb : FB_SAFETY_EMERGENCYMANAGEMENT;
END_VAR
END_SETUP

(* TC-P01-002 est classee SITE+AUTO dans l AF (mixte). Ce test ne couvre QUE la partie AUTO
   (commande logicielle) : preuve qu un seul canal est coupe a la fois et que le FB interprete
   correctement le retour de boucle fourni en entree. Il ne peut PAS prouver que la coupure
   physique de MaintainA/B_RQ ouvre reellement la boucle materielle -- ca reste une verification
   SITE, sur l automate reel, jamais automatisable en logiciel. *)
TEST 'TC-P01-002 (partie AUTO) chaque canal est commande independamment, l autre reste maintenu'
    (* demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.MAINTAINA_RQ, 'hors defaut, canal A maintenu');
    ASSERT_TRUE(fb.MAINTAINB_RQ, 'hors defaut, canal B maintenu');

    (* front ArmRequest -> TestA (step 1) : SEUL le canal A doit se couper *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 1, 'front doit lancer TestA');
    ASSERT_FALSE(fb.MAINTAINA_RQ, 'TestA : canal A seul doit se couper');
    ASSERT_TRUE(fb.MAINTAINB_RQ, 'TestA : canal B ne doit PAS etre affecte');

    (* 200ms plus tard : la boucle reagit reellement a la coupure de A (preuve physique reelle) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 2, 'TestA reussi (boucle a reagi) -> RestoreA');
    ASSERT_FALSE(fb.ERROR, 'pas de defaut si le canal reagit correctement au test');
    ASSERT_TRUE(fb.MAINTAINA_RQ, 'canal A restaure immediatement apres son test');

    (* 200ms plus tard : boucle refermee (A restaure) -> passage a TestB (step 3) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 3, 'RestoreA reussi -> TestB');
    ASSERT_FALSE(fb.MAINTAINB_RQ, 'TestB : canal B seul doit se couper');
    ASSERT_TRUE(fb.MAINTAINA_RQ, 'TestB : canal A ne doit PAS etre affecte');

    (* 200ms plus tard : boucle reagit a la coupure de B *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 4, 'TestB reussi -> RestoreB');
    ASSERT_FALSE(fb.ERROR, 'pas de defaut si le canal B reagit correctement au test');
    ASSERT_TRUE(fb.MAINTAINB_RQ, 'canal B restaure immediatement apres son test');
END_TEST

TEST 'TC-P01-003 front ArmRequest + boucle OK sur les 2 canaux -> pulse 1s puis confirmation'
    (* demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* front ArmRequest -> TestA *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* TestA reussi (boucle reagit) -> RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);

    (* RestoreA reussi -> TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* TestB reussi (boucle reagit) -> RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);

    (* RestoreB reussi -> Pulse (step 5), impulsion 1s *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 5, 'les 2 canaux valides -> impulsion de reamement');
    ASSERT_TRUE(fb.ARMPULSE_RQ, 'pulse de reamement doit etre actif (TC-P01-003)');

    (* 1s plus tard : pulse termine -> Confirm (step 6) *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 6, 'pulse de 1s termine -> attente confirmation contacteur');
    ASSERT_FALSE(fb.ARMPULSE_RQ, 'pulse retombe apres 1s');
    ASSERT_TRUE(fb.BUSY, 'sequence toujours en cours (attente confirmation)');

    (* contacteur confirme engage -> succes, retour IDLE *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := TRUE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'confirmation contacteur -> retour IDLE');
    ASSERT_TRUE(fb.DONE, 'contacteur engage confirme -> Done');
    ASSERT_FALSE(fb.BUSY, 'sequence terminee');
    ASSERT_FALSE(fb.EMERGENCYARMINGLOCKOUTACTIVE, 'succes -> pas de lockout');
    ASSERT_FALSE(fb.ERROR, 'reamement reussi -> pas de defaut');
END_TEST

TEST 'TC-P01-004/009 Reset acquitte l affichage mais re-alarme si la cause persiste'
    (* reproduit l etat "canal colle" de TC-P01-006 -- setup independant, propre a ce test *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.ERROR, 'precondition : canal colle doit avoir leve une erreur');

    (* Reset : doit acquitter l affichage sans redemarrage auto (TC-P01-004) -- +1 cycle *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.ERROR, 'Reset doit effacer l affichage du defaut');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'Reset seul ne relance jamais de sequence (pas de redemarrage auto)');
    (* Complete TC-P01-004 : sa colonne "Comportement attendu" precise "Reset efface l affichage
       (interlock reste sur Cause)" -- assertion manquante jusqu ici. Le canal n a JAMAIS ete
       re-teste physiquement a ce stade (aucun nouveau ArmRequest), donc le maintien de puissance
       ne doit PAS etre restaure par le seul Reset (AF §3.4bis : interlock sur Cause brute,
       jamais sur l Ack). *)
    ASSERT_FALSE(fb.MAINTAINA_RQ, 'TC-P01-004 : Reset seul ne doit PAS restaurer le maintien (interlock reste sur Cause, AF §3.4bis)');

    (* nouvel essai : cause toujours presente (canal toujours colle) -> doit re-alarmer (TC-P01-009) -- +1 cycle *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 1, 'un nouveau front ArmRequest doit relancer TestA');

    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.ERROR, 'cause persistante doit re-alarmer au nouvel essai, meme apres Reset');
END_TEST

TEST 'TC-P01-006 canal colle bloque le reamement (echec auto-test)'
    (* scans 1-2 : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* front ArmRequest -> ArmingSeqStep passe a 1 (TestA), boucle encore saine ce scan -- +1 cycle *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 1, 'front ArmRequest doit lancer TestA (step 1)');

    (* 200ms plus tard : le canal A est cense etre coupe, mais la boucle reste fermee -> collage *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.ERROR, 'canal colle doit lever une erreur (RedundancyTestFailed)');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'echec auto-test doit ramener la sequence a IDLE');
    ASSERT_FALSE(fb.MAINTAINA_RQ, 'un canal colle bloque aussi le maintien normal (interlock sur Cause brute)');
END_TEST

TEST 'TC-P01-007 timeout confirmation contacteur -> lockout 5s'
    (* meme montee en sequence que TC-P01-003 : les 2 canaux valides, jusqu au pulse *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 5, 'les 2 canaux valides -> pulse');

    (* 1s plus tard : pulse termine -> Confirm (step 6), contacteur PAS engage *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 6, 'attente confirmation contacteur');

    (* 2s plus tard (timeout confirmation) : contacteur toujours pas confirme -> echec + lockout *)
    ADVANCE_TIME(2000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'timeout confirmation doit ramener la sequence a IDLE');
    ASSERT_TRUE(fb.EMERGENCYARMINGLOCKOUTACTIVE, 'timeout doit declencher le lockout (TC-P01-007)');
    ASSERT_TRUE(fb.EMERGENCYARMINGFAILED, 'timeout doit lever le defaut EmergencyArmingFailed');
    ASSERT_TRUE(fb.ERROR, 'defaut doit etre visible sur Error');

    (* pendant le lockout : un nouveau front ArmRequest doit etre bloque *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'lockout actif doit bloquer toute nouvelle tentative de reamement');

    (* 5s apres le debut du lockout : le verrouillage doit se lever automatiquement *)
    ADVANCE_TIME(5000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.EMERGENCYARMINGLOCKOUTACTIVE, 'lockout 5s ecoule -> leve automatiquement');

    (* preuve OPERATIONNELLE (pas juste le drapeau) : un nouveau front doit maintenant relancer
       reellement la sequence -- +1 cycle pour que le retrait du lockout soit visible au scan
       suivant avant de tenter le nouveau front (ordre de calcul : trigger avant re-evaluation
       du lockout dans le meme scan, cf. Logic.st) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 1, 'apres le lockout, un nouveau front doit reellement relancer TestA (pas juste le drapeau qui retombe)');
END_TEST

TEST 'TC-P01-008 PowerCutOffRequest coupe A et B sans armer'
    (* scan 1 : autotest demarrage (1 cycle, boucle saine, contacteur repos) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* scan 2 : regime etabli, maintien sain attendu -- +1 cycle automate (10ms) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.MAINTAINA_RQ, 'hors defaut, canal A doit etre maintenu');
    ASSERT_TRUE(fb.MAINTAINB_RQ, 'hors defaut, canal B doit etre maintenu');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'pas de sequence en cours');

    (* scan 3 : coupure demandee par un metier (Winch/Translation) -- +1 cycle automate *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.MAINTAINA_RQ, 'PowerCutOffRequest doit couper le canal A');
    ASSERT_FALSE(fb.MAINTAINB_RQ, 'PowerCutOffRequest doit couper le canal B');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'PowerCutOffRequest ne doit jamais declencher une sequence armement');
END_TEST

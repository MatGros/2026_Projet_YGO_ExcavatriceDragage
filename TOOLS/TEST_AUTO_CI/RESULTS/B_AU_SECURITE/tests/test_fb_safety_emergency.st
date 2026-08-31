SETUP
VAR
    fb : FB_SAFETY_EMERGENCYMANAGEMENT;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    fb(ENABLE := FALSE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.READY, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Enable=FALSE -> Pas d erreur');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.READY, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Au repos -> Pas d erreur');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    fb(ENABLE := FALSE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.READY, 'Coupure -> Ready retombe a FALSE');
END_TEST

(* =========================================================================
   1. GRANDS SCÉNARIOS OPÉRATIONNELS EN SERVICE (TEMPORELS & DYNAMIQUES)
   ========================================================================= *)

TEST 'TC-P01-SCEN-NOM Scenario Nominal : Sequence complete de rearmement sans blocage'
    (* 💤 Étape 0 : Repos initial (boucle saine, contacteur au repos) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'Au repos boucle saine -> Armable=TRUE');
    ASSERT_FALSE(fb.STATUS.DONE, 'Puissance non encore engagee -> Done=FALSE');

    (* 🚀 Étape 1 : Demande de réarmement (Front ArmRequest -> TestA) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'Front ArmRequest lance TestA');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'TestA coupe canal A');

    (* 🔍 Étape 2 : Réaction boucle à TestA -> Passage à RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 2, 'Boucle tombee -> RestoreA');
    ASSERT_TRUE(fb.CMD.MAINTAINA_CMD, 'Canal A restaure');

    (* 🔍 Étape 3 : Restauration boucle A -> Passage à TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 3, 'Boucle refermee -> TestB');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'TestB coupe canal B');

    (* 🔍 Étape 4 : Réaction boucle à TestB -> Passage à RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 4, 'Boucle tombee -> RestoreB');
    ASSERT_TRUE(fb.CMD.MAINTAINB_CMD, 'Canal B restaure');

    (* ⚡ Étape 5 : Restauration boucle B -> Impulsion collage contacteur 1s *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'Auto-test A/B valide -> Step 5 Impulsion contacteur');
    ASSERT_TRUE(fb.CMD.ARMPULSE_CMD, 'Impulsion 1s active');

    (* ⏱️ Étape 6 : Fin impulsion 1s -> Attente confirmation contacteur *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 6, 'Impulsion terminee -> Step 6 Confirmation');
    ASSERT_FALSE(fb.CMD.ARMPULSE_CMD, 'Impulsion retombe');

    (* ✅ Étape 7 : Confirmation contacteur engagé -> Puissance engagée *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := TRUE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'Contacteur confirme -> Retour repos IDLE');
    ASSERT_TRUE(fb.STATUS.DONE, 'Puissance engagee -> Done=TRUE');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Cycle nominal termine sans defaut');
END_TEST

TEST 'TC-P01-SCEN-DYN Scenario Dynamique : Enchainement nominal puis perturbations reelles en service'
    (* 🚀 Phase 1 : Réarmement nominal réussi et mise en service *)
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
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := TRUE);
    ASSERT_TRUE(fb.STATUS.DONE, 'Machine armee en service');

    (* ⚡ Phase 2 : Coupure sécurité métier intempestive en pleine marche *)
    ADVANCE_TIME(500000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'Coupure metier -> Retombee immediate canal A');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'Coupure metier -> Retombee immediate canal B');
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'Coupure metier active -> Armable=FALSE');

    (* 🛡️ Phase 3 : Tentative de réarmement bloquée sous défaut *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'Rearmement refuse : reste a Step 0');

    (* 🔄 Phase 4 : Disparition de la dérive métier + Acquittement Reset *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'Defaut acquitte et disparu -> Armable redevient TRUE');

    (* ⚠️ Phase 5 : Nouvel armement avec échec de collage contacteur (timeout 2s) *)
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
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    
    (* Timeout 2s à l'étape 6 sans retour PowerContactorEngaged *)
    ADVANCE_TIME(2000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'Echec collage contacteur -> Alarme levee');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'Verrouillage Lockout 5s active');
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'Pendant lockout -> Armable=FALSE');

    (* 🔓 Phase 6 : Expiration du lockout 5s + Reset -> Prêt pour nouvel essai *)
    ADVANCE_TIME(5000000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'Lockout 5s expire');
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'Machine prete a etre reessayee');
END_TEST

(* =========================================================================
   2. TESTS UNITAIRES GRANULAIRES (ORDRE CHRONOLOGIQUE DES FONCTIONS TC)
   ========================================================================= *)

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
    ASSERT_TRUE(fb.CMD.MAINTAINA_CMD, 'hors defaut, canal A maintenu');
    ASSERT_TRUE(fb.CMD.MAINTAINB_CMD, 'hors defaut, canal B maintenu');

    (* front ArmRequest -> TestA (step 1) : SEUL le canal A doit se couper *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'front doit lancer TestA');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'TestA : canal A seul doit se couper');
    ASSERT_TRUE(fb.CMD.MAINTAINB_CMD, 'TestA : canal B ne doit PAS etre affecte');

    (* 200ms plus tard : la boucle reagit reellement a la coupure de A (preuve physique reelle) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 2, 'TestA reussi (boucle a reagi) -> RestoreA');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'pas de defaut si le canal reagit correctement au test');
    ASSERT_TRUE(fb.CMD.MAINTAINA_CMD, 'canal A restaure immediatement apres son test');

    (* 200ms plus tard : boucle refermee (A restaure) -> passage a TestB (step 3) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 3, 'RestoreA reussi -> TestB');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'TestB : canal B seul doit se couper');
    ASSERT_TRUE(fb.CMD.MAINTAINA_CMD, 'TestB : canal A ne doit PAS etre affecte');

    (* 200ms plus tard : boucle reagit a la coupure de B *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 4, 'TestB reussi -> RestoreB');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'pas de defaut si le canal B reagit correctement au test');
    ASSERT_TRUE(fb.CMD.MAINTAINB_CMD, 'canal B restaure immediatement apres son test');
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> impulsion de reamement');
    ASSERT_TRUE(fb.CMD.ARMPULSE_CMD, 'pulse de reamement doit etre actif (TC-P01-003)');

    (* 1s plus tard : pulse termine -> Confirm (step 6) *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 6, 'pulse de 1s termine -> attente confirmation contacteur');
    ASSERT_FALSE(fb.CMD.ARMPULSE_CMD, 'pulse retombe apres 1s');
    ASSERT_TRUE(fb.STATUS.BUSY, 'sequence toujours en cours (attente confirmation)');

    (* contacteur confirme engage -> succes, retour IDLE *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := TRUE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'confirmation contacteur -> retour IDLE');
    ASSERT_TRUE(fb.STATUS.DONE, 'contacteur engage confirme -> Done');
    ASSERT_FALSE(fb.STATUS.BUSY, 'sequence terminee');
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'succes -> pas de lockout');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'reamement reussi -> pas de defaut');
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
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'precondition : canal colle doit avoir leve une erreur');

    (* Reset : doit acquitter l affichage sans redemarrage auto (TC-P01-004) -- +1 cycle *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Reset doit effacer l affichage du defaut');
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'Reset seul ne relance jamais de sequence (pas de redemarrage auto)');
    (* Complete TC-P01-004 : sa colonne "Comportement attendu" precise "Reset efface l affichage
       (interlock reste sur Cause)" -- assertion manquante jusqu ici. Le canal n a JAMAIS ete
       re-teste physiquement a ce stade (aucun nouveau ArmRequest), donc le maintien de puissance
       ne doit PAS etre restaure par le seul Reset (AF 3.4bis : interlock sur Cause brute,
       jamais sur l Ack). *)
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'TC-P01-004 : Reset seul ne doit PAS restaurer le maintien (interlock reste sur Cause, AF 3.4bis)');

    (* nouvel essai : cause toujours presente (canal toujours colle) -> doit re-alarmer (TC-P01-009) -- +1 cycle *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'un nouveau front ArmRequest doit relancer TestA');

    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'cause persistante doit re-alarmer au nouvel essai, meme apres Reset');
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'front ArmRequest doit lancer TestA (step 1)');

    (* 200ms plus tard : le canal A est cense etre coupe, mais la boucle reste fermee -> collage *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'canal colle doit lever une erreur (RedundancyTestFailed)');
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'echec auto-test doit ramener la sequence a IDLE');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'un canal colle bloque aussi le maintien normal (interlock sur Cause brute)');
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse');

    (* 1s plus tard : pulse termine -> Confirm (step 6), contacteur PAS engage *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 6, 'attente confirmation contacteur');

    (* 2s plus tard (timeout confirmation) : contacteur toujours pas confirme -> echec + lockout *)
    ADVANCE_TIME(2000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'timeout confirmation doit ramener la sequence a IDLE');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'timeout doit declencher le lockout (TC-P01-007)');
    ASSERT_TRUE(fb.STATUS.DIAG.ARMFAILED, 'timeout doit lever le defaut EmergencyArmingFailed');
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'defaut doit etre visible sur Error');

    (* pendant le lockout : un nouveau front ArmRequest doit etre bloque *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'lockout actif doit bloquer toute nouvelle tentative de reamement');

    (* 5s apres le debut du lockout : le verrouillage doit se lever automatiquement *)
    ADVANCE_TIME(5000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'lockout 5s ecoule -> leve automatiquement');

    (* preuve OPERATIONNELLE (pas juste le drapeau) : un nouveau front doit maintenant relancer
       reellement la sequence -- +1 cycle pour que le retrait du lockout soit visible au scan
       suivant avant de tenter le nouveau front (ordre de calcul : trigger avant re-evaluation
       du lockout dans le meme scan, cf. Logic.st) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'apres le lockout, un nouveau front doit reellement relancer TestA (pas juste le drapeau qui retombe)');
END_TEST

TEST 'TC-P01-010 BtnEmergencyCutOff pendant le pulse de reamement (step 5) doit couper le pulse comme le maintien'
    (* Meme montee en sequence que TC-P01-003 jusqu au pulse (step 5) *)
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse (step 5)');
    ASSERT_TRUE(fb.CMD.ARMPULSE_CMD, 'precondition : pulse actif');

    (* Operateur appuie sur la coupure d urgence IHM PENDANT l impulsion mecanique de reamement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := TRUE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'BtnEmergencyCutOff coupe bien le maintien canal A (comportement attendu, deja correct)');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'BtnEmergencyCutOff coupe bien le maintien canal B (comportement attendu, deja correct)');
    (* Coherence attendue : si la coupure d urgence IHM coupe le maintien de puissance, elle doit
       aussi couper l impulsion mecanique de reamement en cours -- continuer a pulser le contacteur
       de reamement pendant qu on demande sa coupure est incoherent (Cmd.ArmPulse_Cmd n est
       conditionne par aucune des memes gardes que Cmd.MaintainA/B_Cmd dans
       FB_Safety_EmergencyManagementLogic.st §7 -- ecart releve par l audit du 2026-08-22). *)
    ASSERT_FALSE(fb.CMD.ARMPULSE_CMD, 'BtnEmergencyCutOff doit aussi couper le pulse de reamement en cours (coherence avec la coupure du maintien)');
END_TEST

TEST 'TC-P01-008 PowerCutOffRequest coupe A et B sans armer'
    (* scan 1 : autotest demarrage (1 cycle, boucle saine, contacteur repos) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* scan 2 : regime etabli, maintien sain attendu -- +1 cycle automate (10ms) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.CMD.MAINTAINA_CMD, 'hors defaut, canal A doit etre maintenu');
    ASSERT_TRUE(fb.CMD.MAINTAINB_CMD, 'hors defaut, canal B doit etre maintenu');
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'pas de sequence en cours');

    (* scan 3 : coupure demandee par un metier (Winch/Translation) -- +1 cycle automate *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'PowerCutOffRequest doit couper le canal A');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'PowerCutOffRequest doit couper le canal B');
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'PowerCutOffRequest ne doit jamais declencher une sequence armement');
END_TEST

TEST 'TC-P01-001 Coupure AU physique (essai site, non automatise)'
    (* 🟢 SITE — essai terrain, non automatisable en logiciel.
       Enfoncement du coup de poing AU physique sur site -> ouverture materielle
       immediate de la boucle 24V de securite -> retombee instantanee du contacteur
       de puissance ligne (API reste sous tension). Stub logique : le FB ne peut pas
       prouver la coupure physique ; il ne fait qu observer EmergencyChainClosed=FALSE
       et reflete l'ouverture dans Armable. La verification reelle reste un essai SITE. *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'chaine AU ouverte -> Armable=FALSE (reflet logiciel de la coupure physique)');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'chaine AU ouverte -> maintien canal A retombe');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'chaine AU ouverte -> maintien canal B retombe');
END_TEST

TEST 'TC-P01-005 Sequence 2 temps : ArmRequest sans Reset bloque ; Reset puis ArmRequest arme'
    (* ⚡ MIXTE — partie AUTO : sequencement logique Reset puis ArmRequest.
       Temps 1 : ArmRequest SEUL (sans Reset) est bloque tant qu un defaut/lockout est actif.
       Temps 2 : Reset acquitte et purge, puis un ArmRequest distinct et conscient arme.
       La partie SITE (double action physique acquittement IHM puis rearmement pupitre)
       reste une verification terrain ; ici on prouve le sequencement logiciel. *)
    (* Setup : montee en sequence jusqu au pulse (steps 1-5), puis timeout confirmation 2s
       -> EmergencyArmingFailed + lockout 5s (meme montee que TC-P01-007) *)
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
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* timeout 2s confirmation -> EmergencyArmingFailed + lockout *)
    ADVANCE_TIME(2000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'precondition : lockout 5s actif apres echec');
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'precondition : Armable=FALSE sous lockout');

    (* Temps 1 : ArmRequest SANS Reset -> bloque (lockout actif), reste Step 0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'Temps 1 : ArmRequest sans Reset bloque -> reste Step 0');

    (* Temps 2a : Reset acquitte et purge le defaut + lockout *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'Reset purge le lockout');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Reset acquitte l affichage du defaut');

    (* Temps 2b : ArmRequest distinct et conscient -> arme (Step 1) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'Temps 2 : Reset puis ArmRequest -> sequence armee (Step 1)');
END_TEST

(* =========================================================================
   REX 2026-08-27 — Réarmement AU échouant silencieusement à l'étape 5 (PowerCutOff).
   TC-P01-011/012/013 : preuves du comportement du FB_Safety_EmergencyManagement
   (cause 16#0010, lockout, Error=FALSE, récupération Reset). Le correctif IHM
   (affichage de la cause) est couvert par TC-P07-030 dans le domaine J_SUPERVISION.
   ========================================================================= *)

TEST 'TC-P01-011 PowerCutOffRequest pendant l impulsion (step 5) -> abandon 16#0010 + lockout + Error=FALSE'
    (* Montee nominale jusqu au pulse (step 5), comme TC-P01-003 *)
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse (step 5)');
    ASSERT_TRUE(fb.CMD.ARMPULSE_CMD, 'precondition : pulse actif');

    (* Coupure metier PowerCutOffRequest PENDANT l impulsion (step 5) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'PowerCutOff pendant pulse -> sequence ramenee a IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0010, 'cause abandon = 16#0010 (PowerCutOff metier)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 5, 'abandon a l etape 5 (impulsion)');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'lockout 5s actif apres coupure metier');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'coupure metier voulue -> PAS de defaut d armement (Error=FALSE)');
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'interlock : PowerCutOffRequest actif -> Armable=FALSE');
END_TEST

TEST 'TC-P01-012 Armable=1 mais rearmement echoue a l etape 5 (PowerCutOff pendant pulse)'
    (* Precondition : au repos boucle saine, Armable=TRUE (rearmement autorise) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'precondition : Armable=TRUE (rearmement autorise)');

    (* Rearmement lance -> sequence demarre *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'ArmRequest -> sequence lancee (step 1)');

    (* Montee nominale jusqu au pulse (step 5) *)
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse (step 5)');

    (* Coupure metier pendant l impulsion -> echec a l etape 5 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'echec a l etape 5 -> sequence ramenee a IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 5, 'abandon a l etape 5');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0010, 'cause = 16#0010 (PowerCutOff metier)');
    ASSERT_FALSE(fb.STATUS.DONE, 'rearmement NON abouti (Done=FALSE, contacteur non engage)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'echec silencieux : PAS de defaut d armement (Error=FALSE)');
END_TEST

TEST 'TC-P01-013 Recuperation Reset : cause latched -> Reset -> cause levee -> rearmement reussi'
    (* Montee nominale jusqu au pulse (step 5), puis coupure metier -> abandon 16#0010 + lockout *)
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
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'pulse (step 5)');

    (* Coupure metier -> abandon 16#0010 + lockout *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0010, 'cause latched = 16#0010');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'lockout actif');

    (* Cause levee (PowerCutOffRequest=FALSE) + Reset -> lockout purge, Armable redevient TRUE *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'Reset purge le lockout');
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'cause levee + Reset -> Armable=TRUE');

    (* Nouveau rearmement -> reussite (contacteur engage) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'nouveau front ArmRequest -> sequence relancee');
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
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 6, 'pulse termine -> attente confirmation');
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := TRUE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'contacteur confirme -> retour IDLE');
    ASSERT_TRUE(fb.STATUS.DONE, 'rearmement reussi (Done=TRUE)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'aucun defaut apres reussite');
END_TEST

(* =========================================================================
   REX 2026-08-29 — Complément de couverture des modes de défaillance AU.
   TC-P01-014..020 : chronogrammes réalistes (respect CST_TestDuration=200ms,
   CST_ArmingPulseDuration=1s, CST_ArmingConfirmTimeout=2s, CST_ArmingLockout=5s)
   pour les scénarios non couverts par les tests existants :
     - 014 : redondance B (canal B collé pendant TestB) -> 16#0040
     - 015 : timeout restauration A -> 16#0004
     - 016 : timeout restauration B -> 16#0008
     - 017 : chute de boucle pendant PULSE (step 5) -> 16#0002 + lockout
     - 018 : chute de boucle pendant CONFIRM (step 6) -> 16#0002 + lockout
     - 019 : coupure IHM pendant séquence -> 16#0001 (avortement propre, sans alarme)
     - 020 : autotest démarrage (StartupFail si chaîne ouverte au 1er Enable)
   Lecture uniquement des sorties publiques (Status / Cmd), jamais des internes.
   ========================================================================= *)

TEST 'TC-P01-014 Defaillance redondance B : canal B colle pendant TestB -> abandon 16#0040'
    (* 💤 Setup : demarrage + regime etabli, sain (boucle fermee, contacteur repos) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* 🚀 t=0 : front ArmRequest -> TestA (step 1) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'front ArmRequest -> TestA (step 1)');

    (* 🔍 t=200ms : TestA reussi (boucle tombe) -> RestoreA (step 2) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 2, 'TestA reussi -> RestoreA (step 2)');

    (* 🔍 t=400ms : RestoreA reussi (boucle refermee) -> TestB (step 3) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 3, 'RestoreA reussi -> TestB (step 3)');

    (* ⚠️ t=600ms : TestB -> canal B colle : boucle RESTE fermee apres 200ms -> defaut redondance B *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'canal B colle -> retour IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 3, 'abandon a l etape 3 (TestB)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0040, 'cause = 16#0040 (Redundancy B)');
    ASSERT_TRUE(fb.STATUS.DIAG.REDUNDANCYTESTFAILED, 'defaut redondance leve');
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'defaut visible sur Error');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'canal colle bloque le maintien A (interlock Cause brute)');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'canal colle bloque le maintien B (interlock Cause brute)');
END_TEST

TEST 'TC-P01-015 Timeout restauration A : boucle ne revient pas apres TestA -> abandon 16#0004'
    (* 💤 Setup : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* 🚀 t=0 : front ArmRequest -> TestA (step 1) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 1, 'front ArmRequest -> TestA (step 1)');

    (* 🔍 t=200ms : TestA reussi (boucle tombe) -> RestoreA (step 2) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 2, 'TestA reussi -> RestoreA (step 2)');

    (* ⚠️ t=400ms : RestoreA timeout -> boucle ne revient PAS apres 200ms -> abandon 16#0004 *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'timeout restauration A -> retour IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 2, 'abandon a l etape 2 (RestoreA)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0004, 'cause = 16#0004 (Timeout Restore A)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'timeout restauration -> PAS de defaut d armement (Error=FALSE)');
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'timeout restauration -> PAS de lockout');
END_TEST

TEST 'TC-P01-016 Timeout restauration B : boucle ne revient pas apres TestB -> abandon 16#0008'
    (* 💤 Setup : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* 🚀 t=0 : front ArmRequest -> TestA (step 1) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=200ms : TestA -> RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=400ms : RestoreA -> TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=600ms : TestB -> RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 4, 'TestB reussi -> RestoreB (step 4)');

    (* ⚠️ t=800ms : RestoreB timeout -> boucle ne revient PAS apres 200ms -> abandon 16#0008 *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'timeout restauration B -> retour IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 4, 'abandon a l etape 4 (RestoreB)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0008, 'cause = 16#0008 (Timeout Restore B)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'timeout restauration B -> PAS de defaut d armement (Error=FALSE)');
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'timeout restauration B -> PAS de lockout');
END_TEST

TEST 'TC-P01-017 Chute de boucle pendant PULSE (step 5) -> abandon 16#0002 + lockout'
    (* 💤 Setup : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🚀 t=0 : front ArmRequest -> TestA *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=200ms : TestA -> RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=400ms : RestoreA -> TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=600ms : TestB -> RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=800ms : RestoreB -> PULSE (step 5) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse (step 5)');
    ASSERT_TRUE(fb.CMD.ARMPULSE_CMD, 'precondition : pulse actif');

    (* ⚠️ t=810ms : chute de boucle materielle PENDANT l impulsion (step 5) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'chute boucle pendant pulse -> sequence ramenee a IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 5, 'abandon a l etape 5 (pulse)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0002, 'cause = 16#0002 (Chute chaine)');
    ASSERT_TRUE(fb.STATUS.DIAG.ARMFAILED, 'chute boucle -> defaut EmergencyArmingFailed leve');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'chute boucle -> lockout 5s actif');
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'defaut visible sur Error');
    ASSERT_FALSE(fb.CMD.ARMPULSE_CMD, 'pulse coupe immediatement');
END_TEST

TEST 'TC-P01-018 Chute de boucle pendant CONFIRM (step 6) -> abandon 16#0002 + lockout'
    (* 💤 Setup : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🚀 t=0 : front ArmRequest -> TestA *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=200ms : TestA -> RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=400ms : RestoreA -> TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=600ms : TestB -> RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=800ms : RestoreB -> PULSE (step 5) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* ⏱️ t=1.8s : pulse 1s termine -> CONFIRM (step 6) *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 6, 'pulse termine -> attente confirmation (step 6)');

    (* ⚠️ t=1.81s : chute de boucle materielle PENDANT la confirmation (step 6) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'chute boucle pendant confirm -> sequence ramenee a IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 6, 'abandon a l etape 6 (confirm)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0002, 'cause = 16#0002 (Chute chaine)');
    ASSERT_TRUE(fb.STATUS.DIAG.ARMFAILED, 'chute boucle -> defaut EmergencyArmingFailed leve');
    ASSERT_TRUE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'chute boucle -> lockout 5s actif');
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'defaut visible sur Error');
END_TEST

TEST 'TC-P01-019 Coupure IHM pendant la sequence -> abandon 16#0001 sans alarme ni lockout'
    (* 💤 Setup : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🚀 t=0 : front ArmRequest -> TestA *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=200ms : TestA -> RestoreA *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=400ms : RestoreA -> TestB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=600ms : TestB -> RestoreB *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    (* 🔍 t=800ms : RestoreB -> PULSE (step 5) *)
    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 5, 'les 2 canaux valides -> pulse (step 5)');

    (* 🛑 t=810ms : operateur appuie sur la coupure d urgence IHM PENDANT la sequence (step 5) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := TRUE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.STATUS.STATE.STEP, 0, 'coupure IHM -> sequence ramenee a IDLE');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTSTEP, 5, 'abandon a l etape 5 (pulse)');
    ASSERT_EQ(fb.STATUS.DIAG.LASTABORTCAUSE, 16#0001, 'cause = 16#0001 (Cut IHM)');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'coupure IHM volontaire -> PAS de defaut (Error=FALSE)');
    ASSERT_FALSE(fb.STATUS.DIAG.LOCKOUTACTIVE, 'coupure IHM volontaire -> PAS de lockout');
    ASSERT_FALSE(fb.CMD.ARMPULSE_CMD, 'pulse coupe immediatement');
    ASSERT_FALSE(fb.CMD.MAINTAINA_CMD, 'maintien A coupe');
    ASSERT_FALSE(fb.CMD.MAINTAINB_CMD, 'maintien B coupe');
END_TEST

TEST 'TC-P01-020 Autotest demarrage : chaine ouverte au 1er Enable -> StartupFail, Reset recupere'
    (* 🏁 t=0 : Enable=TRUE avec chaine AU OUVERTE -> autotest demarrage echoue (StartupFail) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := FALSE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.READY, 'chaine ouverte au 1er Enable -> Ready=FALSE (StartupFail)');
    ASSERT_TRUE(fb.STATUS.DIAG.ERROR, 'autotest demarrage echoue -> Error=TRUE');
    ASSERT_EQ(fb.STATUS.DIAG.ERRORID, 16#0008, 'ErrorId bit3 = StartupFail (16#0008)');
    ASSERT_FALSE(fb.STATUS.STATE.ARMABLE, 'StartupFail -> Armable=FALSE');

    (* 🔄 t=10ms : chaine refermee mais StartupFail latche -> toujours pas Ready *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.STATUS.READY, 'StartupFail latche -> Ready reste FALSE meme chaine refermee');

    (* ✅ t=20ms : Reset -> StartupFail purge, Ready=TRUE *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.STATUS.READY, 'Reset purge StartupFail -> Ready=TRUE');
    ASSERT_FALSE(fb.STATUS.DIAG.ERROR, 'Reset acquitte le defaut -> Error=FALSE');
    ASSERT_TRUE(fb.STATUS.STATE.ARMABLE, 'apres Reset -> Armable=TRUE');
END_TEST


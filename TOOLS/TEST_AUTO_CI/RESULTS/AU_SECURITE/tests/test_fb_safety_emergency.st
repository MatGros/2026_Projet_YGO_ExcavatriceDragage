SETUP
VAR
    fb : FB_SAFETY_EMERGENCYMANAGEMENT;
END_VAR
END_SETUP

TEST 'TC-P01-008 PowerCutOffRequest coupe A et B sans armer'
    (* scan 1 : autotest demarrage (1 cycle, boucle saine, contacteur repos) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* scan 2 : regime etabli, maintien sain attendu *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.MAINTAINA_RQ, 'hors defaut, canal A doit etre maintenu');
    ASSERT_TRUE(fb.MAINTAINB_RQ, 'hors defaut, canal B doit etre maintenu');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'pas de sequence en cours');

    (* scan 3 : coupure demandee par un metier (Winch/Translation) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := TRUE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.MAINTAINA_RQ, 'PowerCutOffRequest doit couper le canal A');
    ASSERT_FALSE(fb.MAINTAINB_RQ, 'PowerCutOffRequest doit couper le canal B');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'PowerCutOffRequest ne doit jamais declencher une sequence armement');
END_TEST

TEST 'TC-P01-006 echec auto-test (canal colle) + TC-P01-004/009 Reset et re-latch'
    (* scans 1-2 : demarrage + regime etabli, sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);

    (* front ArmRequest -> ArmingSeqStep passe a 1 (TestA), boucle encore saine ce scan *)
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

    (* Reset : doit acquitter l affichage sans redemarrage auto (TC-P01-004) *)
    fb(ENABLE := TRUE, RESET := TRUE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_FALSE(fb.ERROR, 'Reset doit effacer l affichage du defaut');
    ASSERT_EQ(fb.ARMINGSEQSTEP, 0, 'Reset seul ne relance jamais de sequence (pas de redemarrage auto)');

    (* nouvel essai : cause toujours presente (canal toujours colle) -> doit re-alarmer (TC-P01-009) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := TRUE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_EQ(fb.ARMINGSEQSTEP, 1, 'un nouveau front ArmRequest doit relancer TestA');

    ADVANCE_TIME(200000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMREQUEST := FALSE, POWERCUTOFFREQUEST := FALSE,
       BTNEMERGENCYCUTOFF := FALSE, EMERGENCYCHAINCLOSED := TRUE, POWERCONTACTORENGAGED := FALSE);
    ASSERT_TRUE(fb.ERROR, 'cause persistante doit re-alarmer au nouvel essai, meme apres Reset');
END_TEST

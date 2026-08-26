SETUP
VAR
    fb : FB_BRAKE;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation standard *)
    fb(ENABLE := FALSE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE : FB non pret (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := FALSE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE : FB pret');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    fb(ENABLE := FALSE, RESET := FALSE, MOVEMENTREQUESTED := FALSE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.READY, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'Sequence ouverture : le frein ne s ouvre qu apres DelayMagnetise+DelayContactClose (400ms)'
    (* Bypass du controle contacteur : ce test se concentre sur le seul timing de magnetisation *)
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.BRAKECMD, 't=0 : magnetisation demarre, frein encore colle');
    ASSERT_EQ(fb.STATUS.STATE, E_STATE.BUSY, 'sequence en cours -> BUSY');

    ADVANCE_TIME(399000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.BRAKECMD, 't=399ms < 400ms requis : toujours colle');

    ADVANCE_TIME(2000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.BRAKECMD, 't=401ms >= 400ms : magnetisation acquise, frein relache');
    ASSERT_EQ(fb.STATUS.STATE, E_STATE.DONE, 'sequence terminee -> DONE');
    ASSERT_TRUE(fb.BRAKECOMMANDOPENCONFIRMED, 'bypass actif : confirmation = image de BrakeCmd');
END_TEST

TEST 'Comportement actuel : fermeture immediate sans attendre DelayMotorDecel (TonDecel jamais cable)'
    (* A VERIFIER intentionnellement : DelayMotorDecel/TonDecel sont declares et documentes
       ("Delai deceleration avant collage frein") mais TonDecel.IN est TOUJOURS force a FALSE
       dans FB_Brake.st (§1/§3) -- aucune temporisation n est reellement appliquee avant que le
       frein ne colle. Ce test documente le comportement REEL actuel (immediat), pas une exigence
       validee -- a confirmer avec l utilisateur si une temporisation etait pourtant voulue. *)
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ADVANCE_TIME(401000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.BRAKECMD, 'precondition : frein ouvert');

    (* mouvement arrete : meme scan, frein colle instantanement -- DelayMotorDecel (500ms) ignore *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := FALSE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := TRUE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.BRAKECMD, 'MovementRequested retombe : frein colle DES CE SCAN, aucun delai observe');
    ASSERT_EQ(fb.STATUS.STATE, E_STATE.READY, 'retour a READY immediat');
END_TEST

TEST 'Double verification contacteur : StuckClosed si le retour ne confirme jamais l ouverture'
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ADVANCE_TIME(401000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.BRAKECMD, 'magnetisation acquise : commande ouverture emise (ContactorFeedback ne confirme pas encore)');

    (* 1s de plus (FeedbackTimeout) : le retour n a jamais confirme -> defaut *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.CONTACTORCHECK.STUCKCLOSED, 'commande ouverture emise mais jamais confirmee -> StuckClosed');
    ASSERT_TRUE(fb.STATUS.ERROR, 'defaut visible sur Status.Error');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0001, 'bit0 : incoherence retour contacteur');
    ASSERT_FALSE(fb.BRAKECMD, 'sortie sure sur defaut : BrakeCmd force a FALSE malgre la sequence terminee');
END_TEST

TEST 'Reset n acquitte le defaut contacteur que si la cause (retour) a reellement disparu'
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ADVANCE_TIME(401000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := FALSE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : defaut StuckClosed actif');

    (* la cause disparait (le retour confirme enfin), mais SANS Reset : le defaut reste affiche *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := TRUE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause disparue mais pas acquittee : le defaut reste affiche (pas d auto-effacement)');

    (* front Reset, cause deja disparue : acquitte *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE, MOVEMENTREQUESTED := TRUE,
       CONTACTORFEEDBACK := TRUE, BYPASSCONTACTORCHECK := FALSE,
       DELAYCONTACTCLOSE := T#100MS, DELAYMAGNETISE := T#300MS,
       DELAYMOTORDECEL := T#500MS, FEEDBACKTIMEOUT := T#1S);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset avec cause disparue (retour coherent) : defaut acquitte');
    ASSERT_TRUE(fb.BRAKECMD, 'plus de defaut : frein a nouveau relache (mouvement toujours demande)');
END_TEST

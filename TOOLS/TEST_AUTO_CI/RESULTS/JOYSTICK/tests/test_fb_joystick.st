SETUP
VAR
    fb : FB_JOYSTICK;
    nx : INT := 5000;
    ny : INT := 5000;
    diagOk : ST_DIAG_DEVICE;
    diagDown : ST_DIAG_DEVICE;
END_VAR
END_SETUP

TEST 'TC-P08-001 Perte bus CAN pendant un mouvement arme neutralise, desarme et leve Error (auto-efface au retour)'
    diagDown.ONLINE := FALSE; diagDown.OPERATIONAL := FALSE; diagDown.ERROR := FALSE;
    diagDown.ERRORID := 0; diagDown.STATE := E_DIAG_STATE.INIT; diagDown.STATEATERROR := E_DIAG_STATE.DISABLED;
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre, bus sain *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* deplace le joystick : mouvement actif, bus toujours sain *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 60.0, 0.01, 'mouvement actif : consigne non nulle (RawX=8000, Neutral=5000)');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant pendant le mouvement');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'RawY au neutre : axe Y reste a 0, aucun couplage entre les axes');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, 0, 'axe Y au neutre : Direction=0');

    (* perte du bus CAN EN PLEIN MOUVEMENT : neutralisation immediate + desarmement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagDown, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.READY, 'bus CAN non operationnel doit bloquer Ready');
    ASSERT_TRUE(fb.ERROR, 'perte de comm doit lever Error (AF08)');
    ASSERT_EQ(fb.ERRORID, 16#0004, 'bit2 : HW/bus non operationnel');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'sorties axe X neutralisees des la perte du bus, meme en plein mouvement');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'consigne X coupee immediatement, pas de decel progressive');
    ASSERT_FALSE(fb.AXISCMDY.ENABLE, 'sorties axe Y aussi neutralisees (gate global, pas seulement l axe en mouvement)');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'consigne Y aussi coupee');
    ASSERT_FALSE(fb.DEADMANARMED, 'le geste est desarme par la perte du bus (AF08 TC-P08-001)');

    (* bus revient : pas de rearmement automatique, nouvel appui conscient exige *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.READY, 'bus revenu : FB de nouveau pret');
    ASSERT_FALSE(fb.ERROR, 'bus revenu : Error auto-effacee sans geste operateur (categorie Info/Warning, pas un Fault a acquitter)');
    ASSERT_EQ(fb.ERRORID, 0, 'bit2 efface automatiquement');
    ASSERT_FALSE(fb.DEADMANARMED, 'pas de rearmement automatique au retour du bus : nouvel appui conscient exige');
END_TEST

TEST 'TC-P08-002 Maintien DeadmanArmHoldTime : arme si tenu 100ms, annule si relache avant'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* baseline : neutre, bouton relache *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'baseline : bouton relache, pas arme');

    (* front bouton : demarre le maintien, pas encore arme *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'front bouton seul ne doit pas armer immediatement (maintien requis)');

    (* 50ms plus tard : maintien pas termine -- l operateur bouge DEJA l axe X seul (Y reste
       neutre) pendant l attente : aucune commande ne doit partir tant que ce n est pas arme *)
    ADVANCE_TIME(50000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, '50ms < DeadmanArmHoldTime (100ms) : pas encore arme');
    ASSERT_NEAR(fb.CMDXVAL, 0.0, 0.01, 'consigne interne X (CmdXVal) forcee a 0 : pas encore arme');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'axe X seul pousse (RawX=8000, RawY neutre) mais pas encore arme : aucune commande ne part');

    (* 20ms de plus (toujours < 100ms) : cette fois l axe Y seul est pousse (X revient au
       neutre) -- meme preuve, isolee sur l autre axe *)
    ADVANCE_TIME(20000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 2000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, '70ms < DeadmanArmHoldTime (100ms) : toujours pas arme');
    ASSERT_NEAR(fb.CMDYVAL, 0.0, 0.01, 'consigne interne Y (CmdYVal) forcee a 0 : pas encore arme');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'axe Y seul pousse (RawY=2000, RawX neutre) mais pas encore arme : aucune commande ne part');

    (* relache a 50ms, avant la fin des 100ms de maintien : annule la tentative *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'relachement avant la fin du maintien annule la tentative');

    (* le bouton reste relache PENDANT 1s ENTIERE, manche pousse a fond (RawX=8000) tout du
       long : aucun armement differe, et surtout aucune commande de mouvement ne demarre,
       meme apres une longue attente sur une position hors neutre *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'pas d armement differe sur une tentative deja annulee, meme apres 1s (nouvel appui conscient exige)');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'manche a fond depuis 1s mais jamais arme : toujours aucune commande de mouvement');

    (* nouveau front + maintien complet (110ms) : l armement redevient possible normalement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, '110ms >= DeadmanArmHoldTime (100ms) : geste arme');
END_TEST

TEST 'TC-P08-004 Delai de grace protege l armement au neutre, puis le neutre prolonge desarme apres la grace'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* nx/ny fixes explicitement a 5000 avant CHAQUE appel : STruCpp ne re-copie PAS la sortie
       VAR_IN_OUT vers la variable de test entre deux appels fb() (limite outillage constatee,
       round-trip IN_OUT absent -- cf. README). Sans ce forcage, NeutralXMem retomberait a 0
       (valeur SETUP jamais appliquee non plus) des le 2e scan, et AtNeutral resterait FALSE. *)
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* bouton relache, reste au neutre : 500ms plus tard (largement > NeutralHoldTime seul 100ms) mais < grace (3s) *)
    ADVANCE_TIME(500000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'la grace (3s) protege l armement malgre un neutre deja tenu bien plus longtemps que NeutralHoldTime seul (evite le REX terrain : desarmement 100-200ms apres l armement)');

    (* 2.6s de plus (total 3.1s depuis l armement) : la grace vient de s ecouler ce scan meme --
       NeutralHoldTimer ne fait que DEMARRER (son IN passe a TRUE ce scan), pas encore Q *)
    ADVANCE_TIME(2600000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'grace tout juste ecoulee : NeutralHoldTimer demarre seulement ce scan (pas encore ecoule)');

    (* 100ms de plus (NeutralHoldTime ecoule depuis la fin de la grace) : desarme *)
    ADVANCE_TIME(100000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'grace ecoulee (3s) + neutre tenu (NeutralHoldTime) : desarmement');
END_TEST

TEST 'TC-P08-005 Changement de mode desarme le geste, nouvel appui exige'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme en MAINT_N1 *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* changement de mode : desarmement immediat *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N2, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'changement de mode desarme immediatement');

    (* mode stable ensuite, sans nouvel appui : reste desarme *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N2, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'pas de rearmement automatique apres changement de mode : nouvel appui conscient exige');
END_TEST

TEST 'TC-P08-006 Reset acquitte une erreur de calibration seulement si la cause a disparu'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* RawX/RawY hors zone neutre valide (2000..8000) + front BtnCalibrate *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, BTNCALIBRATE := TRUE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_TRUE(fb.ERROR, 'calibration hors zone doit lever Error');

    (* Reset alors que la cause est toujours presente (axes toujours hors zone) : ne doit PAS acquitter *)
    fb(ENABLE := TRUE, RESET := TRUE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_TRUE(fb.ERROR, 'Reset ne doit PAS acquitter tant que les axes restent hors zone (cause toujours presente)');

    (* Reset retombe (front consomme) ; axes reviennent en zone ; nouveau front Reset : doit acquitter *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    fb(ENABLE := TRUE, RESET := TRUE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_FALSE(fb.ERROR, 'front Reset avec axes revenus en zone valide doit acquitter (cause disparue + appui conscient)');
END_TEST

TEST 'TC-P08-007 SpeedRef sature a +/-100 meme avec RawX/RawY hors plage nominale (defaut capteur)'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    (* init explicite -- STruCpp n applique pas ":= 5000" du SETUP, cf. README limite outillage *)
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX/RawY au maximum nominal (10000) : saturation +100 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 10000, RAWY := 10000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 100.0, 0.01, 'RawX au max nominal (10000) : SpeedRef sature a +100');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 100.0, 0.01, 'meme comportement sur l axe Y');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'Direction coherente avec le signe de la consigne');

    (* RawX/RawY au minimum nominal (0) : saturation -100 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 0, RAWY := 0, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, -100.0, 0.01, 'RawX au min nominal (0) : SpeedRef sature a -100');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, -1, 'Direction coherente avec le signe de la consigne');

    (* Depassement franc au-dela de la plage ADC nominale + marge de tolerance (defaut
       capteur/cablage Hall, ex: fil coupe -> ADC fige a une valeur aberrante) : neutre +
       defaut visible, PAS une saturation a pleine vitesse dans une direction sur une donnee
       dont on ne peut plus garantir la validite (AF08 §5bis). *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 20000, RAWY := 20000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'RawX=20000 (hors plage ADC + marge, defaut capteur) : neutre, PAS une saturation a pleine vitesse');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'meme garde-fou sur l axe Y');
    ASSERT_EQ(fb.ERRORID, 16#0002, 'bit1 : defaut capteur hors plage pendant fonctionnement, visible operateur');

    (* Valeur negative (hors plage ADC + marge, meme scenario defaut cablage) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := -10000, RAWY := -10000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'RawX negatif (hors plage ADC + marge, defaut capteur) : neutre, PAS une saturation a pleine vitesse');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'meme garde-fou sur l axe Y');

    (* Depassement leger (< marge de tolerance) : ne doit PAS declencher le defaut -- evite les
       faux positifs sur bruit ADC/overshoot mineur pres des bornes nominales *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 10200, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 100.0, 0.01, 'RawX=10200 : dans la marge de tolerance (+500), toujours saturation normale +100, pas de defaut');
    ASSERT_EQ(fb.ERRORID, 0, 'leger depassement tolere : aucun defaut leve');
END_TEST

TEST 'TC-P08-011 Fin de cycle benne desarme le geste par defaut'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme le geste *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* BenneBusy actif : ne desarme pas seul (attend le front descendant) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := TRUE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'BenneBusy actif seul ne desarme pas (attend le front descendant, fin de cycle)');

    (* front descendant BenneBusy, sans exception : desarme immediatement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'front descendant BenneBusy sans exception desarme immediatement (pas de M1/M2 surprise)');
END_TEST

TEST 'TC-P08-012 PreserveArmingAfterBucket protege l armement en fin de benne (exception CLOSING Extraction)'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme le geste *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* BenneBusy actif, exception active *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := TRUE, PRESERVEARMINGAFTERBUCKET := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* front descendant BenneBusy, exception active : l armement doit etre conserve *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'PreserveArmingAfterBucket=TRUE : armement conserve malgre la fin de benne (exception documentee AF, alerte P1 : ne jamais elargir hors CLOSING Extraction)');
END_TEST

TEST 'TC-P08-014 Mise a l echelle lineaire (proportionnelle) sur valeurs intermediaires, pas seulement aux bornes'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX=9000 (au-dela du neutre 5000, hors zone morte) : OutPct = (9000-5000)/(10000-5000)*100 = 80% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 80.0, 0.01, 'RawX=9000 : proportionnel, 80% -- pas seulement correct aux bornes 0/10000');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant coherent');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'RawY toujours au neutre : axe Y inchange');

    (* RawY=300 (en-deca du neutre 5000, hors zone morte) : OutPct = (300-5000)/5000*100 = -94% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 300, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, -94.0, 0.01, 'RawY=300 : proportionnel, -94% -- pas seulement correct aux bornes 0/10000');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, -1, 'sens arriere coherent');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'RawX revenu au neutre : axe X inchange');
END_TEST

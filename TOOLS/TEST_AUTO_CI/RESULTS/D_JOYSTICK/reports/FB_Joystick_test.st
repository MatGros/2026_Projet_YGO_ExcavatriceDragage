(* =======================================================================
   🤖 Test CI FB_Joystick (STruCpp / TEST_AUTO_CI)
   ───────────────────────────────────────────────────────────────
   Sémantique des erreurs (socle FB_FbStatus, liste de causes) :
   - BusLost   (perte bus, bit 4)   = WARNING auto-effacé
             -> Status.Warning=TRUE / bit dans Status.WarningId, JAMAIS Error
   - RawOutOfRange (capteur, bit 1) = WARNING auto-effacé
             -> Status.Warning=TRUE / bit dans Status.WarningId, JAMAIS Error
   - CalibFail (échec recalage neutre) = DÉFAUT à acquitter
             -> Status.Error=TRUE / bit dans Status.ErrorId
   Conséquence : Error/ErrorId ne portent QUE les vrais défauts (calibration).
   Un warning seul : Error=FALSE, Status.Warning=TRUE, bit dans Status.WarningId.
   Direction : ST_Joystick_AxisCmd expose les bits DirectionPositive/
   DirectionNegative/AtNeutral ; le FB expose les miroirs INT DirectionX/DirectionY
   (-1/0/+1), dérivés de ces bits.
   ===================================================================== *)

SETUP
VAR
    fb : FB_JOYSTICK;
    nx : INT := 5000;
    ny : INT := 5000;
    cfg : ST_fbJoystick_Cfg;
    diagOk : ST_DIAG_DEVICE;
    diagDown : ST_DIAG_DEVICE;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* Scan 0 : Enable=FALSE -> Neutralisation initiale absolue, Ready=FALSE, sorties neutralisees *)
    fb(ENABLE := FALSE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 8000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Enable=FALSE -> Status.Error=FALSE (neutralise)');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Enable=FALSE -> Status.Warning=FALSE');
    ASSERT_EQ(fb.AXISCMDX.SPEEDTGT, 0.0, 'Enable=FALSE -> Sortie X neutralisee a 0');
    ASSERT_EQ(fb.AXISCMDY.SPEEDTGT, 0.0, 'Enable=FALSE -> Sortie Y neutralisee a 0');

    ADVANCE_TIME(10000000);
    nx := 5000; ny := 5000;

    (* Scan 1 : Front montant Enable=TRUE avec entrees au repos -> Transition nominale prete *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE au repos -> Ready=TRUE (nominal)');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Au repos -> Pas d erreur');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Au repos -> Pas de warning');
    ASSERT_EQ(fb.AXISCMDX.SPEEDTGT, 0.0, 'Au repos -> Sortie X a 0');
    ASSERT_EQ(fb.AXISCMDY.SPEEDTGT, 0.0, 'Au repos -> Sortie Y a 0');

    ADVANCE_TIME(10000000);
    nx := 5000; ny := 5000;

    (* Scan 2 : Front descendant Enable=FALSE -> Coupure nette et re-neutralisation immediate *)
    fb(ENABLE := FALSE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready retombe a FALSE');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Coupure -> Pas d erreur parasite');
    ASSERT_EQ(fb.AXISCMDX.SPEEDTGT, 0.0, 'Coupure -> Sortie X maintenue a 0');
    ASSERT_EQ(fb.AXISCMDY.SPEEDTGT, 0.0, 'Coupure -> Sortie Y maintenue a 0');
END_TEST

TEST 'TC-P08-001 Perte bus CAN pendant un mouvement arme neutralise, desarme et leve Error (auto-efface au retour)'
    diagDown.ONLINE := FALSE; diagDown.OPERATIONAL := FALSE; diagDown.ERROR := FALSE;
    diagDown.ERRORID := 0; diagDown.STATE := E_DIAG_STATE.INIT; diagDown.STATEATERROR := E_DIAG_STATE.DISABLED;
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre, bus sain *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* deplace le joystick : mouvement actif, bus toujours sain *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 60.0, 0.01, 'mouvement actif : consigne non nulle (RawX=8000, Neutral=5000)');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant pendant le mouvement');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'RawY au neutre : axe Y reste a 0, aucun couplage entre les axes');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, 0, 'axe Y au neutre : DirectionY=0');

    (* perte du bus CAN EN PLEIN MOUVEMENT : neutralisation immediate + desarmement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagDown, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.READY, 'bus CAN non operationnel doit bloquer Ready');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'perte bus = Warning auto-efface, PAS un defaut a acquitter (socle FB_FbStatus)');
    ASSERT_TRUE(fb.FAULT.ERROR, 'perte de comm doit lever un Warning (liste de causes)');
    ASSERT_EQ(fb.FAULT.ERRORID, 16#0004, 'bit2 : HW/bus non operationnel porte par WarningId');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'sorties axe X neutralisees des la perte du bus, meme en plein mouvement');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'consigne X coupee immediatement, pas de decel progressive');
    ASSERT_FALSE(fb.AXISCMDY.ENABLE, 'sorties axe Y aussi neutralisees (gate global, pas seulement l axe en mouvement)');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'consigne Y aussi coupee');
    ASSERT_FALSE(fb.DEADMANARMED, 'le geste est desarme par la perte du bus (AF08 TC-P08-001)');

    (* bus revient : pas de rearmement automatique, nouvel appui conscient exige *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.READY, 'bus revenu : FB de nouveau pret');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'bus revenu : pas de defaut (bus = Warning, jamais un Fault a acquitter)');
    ASSERT_FALSE(fb.FAULT.ERROR, 'bus revenu : Warning auto-efface sans geste operateur');
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'bit2 efface automatiquement');
    ASSERT_FALSE(fb.DEADMANARMED, 'pas de rearmement automatique au retour du bus : nouvel appui conscient exige');
END_TEST

TEST 'TC-P08-002 Maintien DeadmanArmHoldTime : arme si tenu 100ms, annule si relache avant'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* baseline : neutre, bouton relache *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'baseline : bouton relache, pas arme');

    (* front bouton : demarre le maintien, pas encore arme *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'front bouton seul ne doit pas armer immediatement (maintien requis)');

    (* 50ms plus tard : maintien pas termine -- l operateur bouge DEJA l axe X seul (Y reste
       neutre) pendant l attente : aucune commande ne doit partir tant que ce n est pas arme *)
    ADVANCE_TIME(50000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, '50ms < DeadmanArmHoldTime (100ms) : pas encore arme');
    ASSERT_NEAR(fb.CMDXVAL, 0.0, 0.01, 'consigne interne X (CmdXVal) forcee a 0 : pas encore arme');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'axe X seul pousse (RawX=8000, RawY neutre) mais pas encore arme : aucune commande ne part');

    (* 20ms de plus (toujours < 100ms) : cette fois l axe Y seul est pousse (X revient au
       neutre) -- meme preuve, isolee sur l autre axe *)
    ADVANCE_TIME(20000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 2000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, '70ms < DeadmanArmHoldTime (100ms) : toujours pas arme');
    ASSERT_NEAR(fb.CMDYVAL, 0.0, 0.01, 'consigne interne Y (CmdYVal) forcee a 0 : pas encore arme');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'axe Y seul pousse (RawY=2000, RawX neutre) mais pas encore arme : aucune commande ne part');

    (* relache a 50ms, avant la fin des 100ms de maintien : annule la tentative *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'relachement avant la fin du maintien annule la tentative');

    (* le bouton reste relache PENDANT 1s ENTIERE, manche pousse a fond (RawX=8000) tout du
       long : aucun armement differe, et surtout aucune commande de mouvement ne demarre,
       meme apres une longue attente sur une position hors neutre *)
    ADVANCE_TIME(1000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'pas d armement differe sur une tentative deja annulee, meme apres 1s (nouvel appui conscient exige)');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'manche a fond depuis 1s mais jamais arme : toujours aucune commande de mouvement');

    (* nouveau front + maintien complet (110ms) : l armement redevient possible normalement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, '110ms >= DeadmanArmHoldTime (100ms) : geste arme');
END_TEST

TEST 'TC-P08-003 Zone morte joystick (Deadband) : signal dans la plage neutre +/- DeadbandRaw donne consigne nulle'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* Arme le geste avec le manche au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'Geste arme au neutre');

    (* Test dans la zone morte superieure : RawX = 5150 (neutre 5000 + 150 < 300) *)
    ADVANCE_TIME(10000000);
    nx := 5000; ny := 5000;
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5150, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX=5150 dans deadband (300) : consigne X strictement 0.0');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 0, 'RawX dans deadband : DirectionX=0');
    ASSERT_TRUE(fb.ATNEUTRALXY, 'Signal dans deadband : considere au neutre');

    (* Test dans la zone morte inferieure : RawY = 4850 (neutre 5000 - 150 > -300) *)
    ADVANCE_TIME(10000000);
    nx := 5000; ny := 5000;
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 4850, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'RawY=4850 dans deadband (300) : consigne Y strictement 0.0');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, 0, 'RawY dans deadband : DirectionY=0');
    ASSERT_TRUE(fb.ATNEUTRALXY, 'Signal dans deadband : considere au neutre');
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
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* bouton relache, reste au neutre : 500ms plus tard (largement > NeutralHoldTime seul 100ms) mais < grace (3s) *)
    ADVANCE_TIME(500000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'la grace (3s) protege l armement malgre un neutre deja tenu bien plus longtemps que NeutralHoldTime seul (evite le REX terrain : desarmement 100-200ms apres l armement)');

    (* 2.6s de plus (total 3.1s depuis l armement) : la grace vient de s ecouler ce scan meme --
       NeutralHoldTimer ne fait que DEMARRER (son IN passe a TRUE ce scan), pas encore Q *)
    ADVANCE_TIME(2600000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'grace tout juste ecoulee : NeutralHoldTimer demarre seulement ce scan (pas encore ecoule)');

    (* 100ms de plus (NeutralHoldTime ecoule depuis la fin de la grace) : desarme *)
    ADVANCE_TIME(100000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'grace ecoulee (3s) + neutre tenu (NeutralHoldTime) : desarmement');
END_TEST

TEST 'TC-P08-005 Changement de mode desarme le geste, nouvel appui exige'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme en MAINT_N1 *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* désarmement externe (ex. changement de mode, fin benne) : ArmingPermit tombe à FALSE *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'ArmingPermit=FALSE desarme immediatement (désarmement externe, ex. changement de mode)');

    (* ArmingPermit reste FALSE, sans nouvel appui : reste desarme *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'pas de rearmement automatique tant que ArmingPermit=FALSE : nouvel appui conscient + permission exigee');
END_TEST

TEST 'TC-P08-006 Reset acquitte une erreur de calibration seulement si la cause a disparu'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* RawX/RawY hors zone neutre valide (2000..8000) + front BtnCalibrate *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := TRUE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_TRUE(fb.FAULT.ERROR, 'calibration hors zone doit lever Error');

    (* Reset alors que la cause est toujours presente (axes toujours hors zone) : ne doit PAS acquitter *)
    fb(ENABLE := TRUE, RESET := TRUE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_TRUE(fb.FAULT.ERROR, 'Reset ne doit PAS acquitter tant que les axes restent hors zone (cause toujours presente)');

    (* Reset retombe (front consomme) ; axes reviennent en zone ; nouveau front Reset : doit acquitter *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    fb(ENABLE := TRUE, RESET := TRUE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_FALSE(fb.FAULT.LATCHED, 'front Reset avec axes revenus en zone valide doit acquitter (cause disparue + appui conscient)');
END_TEST

TEST 'TC-P08-007 SpeedRef sature a +/-100 meme avec RawX/RawY hors plage nominale (defaut capteur)'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    (* init explicite -- STruCpp n applique pas ":= 5000" du SETUP, cf. README limite outillage *)
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX/RawY au maximum nominal (10000) : saturation +100 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 10000, RAWY := 10000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 100.0, 0.01, 'RawX au max nominal (10000) : SpeedRef sature a +100');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 100.0, 0.01, 'meme comportement sur l axe Y');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'Direction coherente avec le signe de la consigne');

    (* RawX/RawY au minimum nominal (0) : saturation -100 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 0, RAWY := 0, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 100.0, 0.01, 'RawX au min nominal (0) : SpeedRef sature a 100');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, -1, 'Direction coherente avec le signe de la consigne');

    (* Depassement franc au-dela de la plage ADC nominale + marge de tolerance (defaut
       capteur/cablage Hall, ex: fil coupe -> ADC fige a une valeur aberrante) : neutre +
       defaut visible, PAS une saturation a pleine vitesse dans une direction sur une donnee
       dont on ne peut plus garantir la validite (AF08 §5bis). *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 20000, RAWY := 20000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX=20000 (hors plage ADC + marge, defaut capteur) : neutre, PAS une saturation a pleine vitesse');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'meme garde-fou sur l axe Y');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'capteur hors plage = Warning, PAS un defaut a acquitter (socle FB_FbStatus)');
    ASSERT_TRUE(fb.FAULT.ERROR, 'capteur hors plage pendant fonctionnement : leve un Warning (visible operateur)');
    ASSERT_EQ(fb.FAULT.ERRORID, 16#0002, 'bit1 : capteur hors plage porte par WarningId');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'AF08 S5bis : Enable doit tomber a FALSE comme pour la perte bus (bit2), pas seulement SpeedRef=0 -- coherence de traitement entre les 2 causes de perte de confiance');
    ASSERT_FALSE(fb.AXISCMDY.ENABLE, 'meme coherence sur l axe Y');

    (* Valeur negative (hors plage ADC + marge, meme scenario defaut cablage) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := -10000, RAWY := -10000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX negatif (hors plage ADC + marge, defaut capteur) : neutre, PAS une saturation a pleine vitesse');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'meme garde-fou sur l axe Y');

    (* Depassement leger (< marge de tolerance) : ne doit PAS declencher le defaut -- evite les
       faux positifs sur bruit ADC/overshoot mineur pres des bornes nominales *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 10200, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 100.0, 0.01, 'RawX=10200 : dans la marge de tolerance (+500), toujours saturation normale +100, pas de defaut');
    ASSERT_FALSE(fb.FAULT.ERROR, 'leger depassement tolere : aucun warning leve');
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'aucun bit warning actif');
END_TEST

TEST 'TC-P08-011 Fin de cycle benne desarme le geste par defaut'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme le geste *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* ArmingPermit actif : ne desarme pas seul (l'armement reste tant que la permission est accordee) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'ArmingPermit actif seul ne desarme pas (attend le retrait de permission, fin de cycle)');

    (* retrait de permission (ex. fin de cycle benne) : desarme immediatement *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'retrait de permission (ex. fin benne) desarme immediatement (pas de M1/M2 surprise)');
END_TEST

TEST 'TC-P08-012 Permission maintenue (ex. exception CLOSING Extraction) : l armement est conserve tant que ArmingPermit=TRUE'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    (* arme le geste *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* permission maintenue (ex. exception CLOSING Extraction) : l'armement est conserve *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* permission toujours maintenue : l armement doit etre conserve *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'ArmingPermit maintenu : armement conserve (exception CLOSING Extraction gere par l externe qui maintient la permission - alerte P1 : ne jamais elargir hors CLOSING Extraction)');
END_TEST

TEST 'TC-P08-014 Mise a l echelle lineaire (proportionnelle) sur valeurs intermediaires, pas seulement aux bornes'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX=9000 (au-dela du neutre 5000, hors zone morte) : OutPct = (9000-5000)/(10000-5000)*100 = 80% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 80.0, 0.01, 'RawX=9000 : proportionnel, 80% -- pas seulement correct aux bornes 0/10000');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant coherent');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'RawY toujours au neutre : axe Y inchange');

    (* RawY=300 (en-deca du neutre 5000, hors zone morte) : OutPct = (300-5000)/5000*100 = -94% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 300, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 94.0, 0.01, 'RawY=300 : proportionnel, 94% -- pas seulement correct aux bornes 0/10000');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, -1, 'sens arriere coherent');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX revenu au neutre : axe X inchange');
END_TEST

(* =========================================================================
   Lot CI AF-08 : TC-P08-010.x (echelle), TC-P08-020.x (homme-mort),
   TC-P08-030/040/050/060 (defaut capteur / calibration / gate / armement refuse)
   Definitions : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md §2
   + fiche FB_AxisScale_v1.0.md §2 (TC-P08-010.1..4).
   ========================================================================= *)

TEST 'TC-P08-010 Acquisition & echelle : pipeline arme, proportionnel, deadband centree'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX=9000 -> 80% ; RawY=300 -> -94% (proportionnel, pas seulement aux bornes) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9000, RAWY := 300, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 80.0, 0.01, 'RawX=9000 : 80%');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant coherent');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 94.0, 0.01, 'RawY=300 : 94%');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, -1, 'sens arriere coherent');

    (* deadband centree : RawX=5150 (neutre+150<300) -> 0, AtNeutralXY *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5150, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX=5150 dans deadband : 0');
    ASSERT_TRUE(fb.ATNEUTRALXY, '2 axes en zone morte -> AtNeutralXY');
END_TEST

TEST 'TC-P08-010.1 Echelle proportionnelle asymetrique : RawX=9000->80%, RawY=300->-94%'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* demi-plage haute : (9000-5000)/(10000-5000)*100 = 80% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 80.0, 0.01, 'RawX=9000 : 80% (demi-plage haute)');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant');

    (* demi-plage basse : (300-5000)/5000*100 = -94% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 300, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 94.0, 0.01, 'RawY=300 : 94% (demi-plage basse)');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, -1, 'sens arriere');
END_TEST

TEST 'TC-P08-010.2 Deadband bornes exactes : |RawIn-Neutral|<=DeadbandRaw -> 0, borne+1 -> >0'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* borne exacte haute : RawX=5300 = 5000+300 -> 0.0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5300, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX=5300 (borne exacte +300) : 0.0');

    (* borne exacte basse : RawX=4700 = 5000-300 -> 0.0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 4700, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX=4700 (borne exacte -300) : 0.0');

    (* borne+1 haute : RawX=5301 -> >0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5301, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.AXISCMDX.SPEEDTGT > 0.0, 'RawX=5301 (borne+1) : sortie de deadband, |OutPct|>0');

    (* borne+1 basse : RawX=4699 -> <0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 4699, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.AXISCMDX.SPEEDTGT > 0.0, 'RawX=4699 (borne-1) : sortie de deadband, |OutPct|>0');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, -1, 'sens arriere coherent');
END_TEST

TEST 'TC-P08-010.3 Saturation stricte : RawIn=10000->+100, RawIn=0->-100, jamais >100'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX=10000 -> +100 (saturation haute) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 10000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 100.0, 0.01, 'RawX=10000 : saturation +100');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, 1, 'sens avant');

    (* RawX=0 -> -100 (saturation basse) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 0, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 100.0, 0.01, 'RawX=0 : saturation -100 (SpeedTgt non signee)');
    ASSERT_EQ(fb.AXISCMDX.DIRECTION, -1, 'sens arriere');
END_TEST

TEST 'TC-P08-010.4 Echelle asymetrique neutre!=5000 : normalisation independante de chaque demi-plage'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 6000; ny := 6000;

    (* arme le geste au neutre calibre 6000 *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 6000, RAWY := 6000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 6000, RAWY := 6000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* demi-plage haute (6000->10000) : (8000-6000)/(10000-6000)*100 = 50% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 6000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 50.0, 0.01, 'RawX=8000, neutre 6000 : 50% (demi-plage haute 4000 pts)');

    (* demi-plage basse (0->6000) : (3000-6000)/6000*100 = -50% *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 6000, RAWY := 3000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 50.0, 0.01, 'RawY=3000, neutre 6000 : 50% (demi-plage basse 6000 pts)');
    ASSERT_EQ(fb.AXISCMDY.DIRECTION, -1, 'sens arriere coherent');
END_TEST

TEST 'TC-P08-020 Homme-mort : armement maintien+permission, relache avant fin annule, desarmement'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* baseline : neutre, bouton relache, pas arme *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'baseline : pas arme');

    (* front bouton + maintien 100ms + permit -> arme *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'maintien 100ms + permit -> arme');

    (* relache bouton : reste arme (pas de resurveillance) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'relache bouton : reste arme (pas de resurveillance)');

    (* perte permission -> desarme immediat *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'ArmingPermit=FALSE -> desarme immediat');
END_TEST

TEST 'TC-P08-020.1 Armement hors neutre : front bouton + 100ms + permit -> arme meme axes devies'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* axes deja devies (RawX=8000) + front bouton + maintien 100ms + permit -> arme *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'front bouton seul : pas encore arme');
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'armement hors neutre : axes devies n empechent pas l armement (FB_Joystick.st:172)');
END_TEST

TEST 'TC-P08-020.2 Desarmement perte permission : ArmingPermit=FALSE -> DeadmanArmed=FALSE immediat, SpeedTgt=0'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* perte permission en plein geste -> desarme immediat + SpeedTgt=0 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'ArmingPermit=FALSE -> DeadmanArmed=FALSE immediat (FB_Joystick.st:180-183)');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'SpeedTgt=0 des la perte de permission');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'Enable axe X retombe (ArmingPermit=FALSE)');
END_TEST

TEST 'TC-P08-020.3 Pas de rearmement auto : retour ArmingPermit ne rearme pas, exige nouveau front+100ms'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* perte permission -> desarme *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'perte permission -> desarme');

    (* retour permission, bouton toujours relache : PAS de rearmement auto *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'retour ArmingPermit seul ne rearme pas (FB_Joystick.st:167-176)');

    (* nouveau front bouton + maintien 100ms -> rearme *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'nouveau front + 100ms -> rearme');
END_TEST

TEST 'TC-P08-020.4 Bornes temporelles : armement 100ms, grace 3s, neutre 100ms'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* front bouton, maintien 99ms (< 100ms) : pas encore arme *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(99000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, '99ms < DeadmanArmHoldTime (100ms) : pas arme');

    (* +1ms (total 100ms) : arme *)
    ADVANCE_TIME(1000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, '100ms >= DeadmanArmHoldTime : arme');

    (* relache bouton, reste au neutre : grace 3s protege, puis neutre 100ms desarme *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'grace 3s : neutre tenu ne desarme pas encore');

    (* grace ecoulee (3s) + neutre 100ms -> desarme *)
    ADVANCE_TIME(3000000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(100000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'grace 3s + neutre 100ms -> desarme (ST_fbJoystick_Cfg.st:15-17)');
END_TEST

TEST 'TC-P08-030 Defaut capteur : hors plage +/-marge -> SpeedTgt=0 2 axes, ErrorId bit1 auto-efface'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste au neutre *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'precondition : geste arme');

    (* RawX hors plage (20000 > 10000+500) -> SpeedTgt=0 2 axes, Warning bit1 *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 20000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_NEAR(fb.AXISCMDX.SPEEDTGT, 0.0, 0.01, 'RawX hors plage : SpeedTgt X = 0');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDTGT, 0.0, 0.01, 'RawX hors plage : SpeedTgt Y aussi = 0 (2 axes)');
    ASSERT_TRUE(fb.FAULT.ERROR, 'defaut capteur : Error leve (Warning visible)');
    ASSERT_EQ(fb.FAULT.ERRORID, 16#0002, 'bit1 : capteur hors plage');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'defaut capteur = Warning auto-efface, PAS un latch');

    (* retour en plage -> auto-efface *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.FAULT.ERROR, 'retour en plage : Warning auto-efface');
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'bit1 efface automatiquement');
END_TEST

TEST 'TC-P08-040 Calibration : hors [2000;8000] -> Fault bit0 a acquitter, Reset en zone acquitte'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* front Calibrate avec axes hors zone valide (9500 > 8000) -> CalibFail latche *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := TRUE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.FAULT.ERROR, 'calibration hors zone : Error leve');
    ASSERT_TRUE(fb.FAULT.LATCHED, 'calibration = defaut a acquitter (latch)');
    ASSERT_EQ(fb.FAULT.LATCHEDID, 16#0001, 'bit0 : echec calibration');

    (* Reset alors que la cause persiste (axes toujours hors zone) : ne doit PAS acquitter *)
    fb(ENABLE := TRUE, RESET := TRUE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 9500, RAWY := 9500, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.FAULT.LATCHED, 'Reset ne doit PAS acquitter tant que les axes restent hors zone');

    (* Reset retombe, axes en zone, nouveau front Reset -> acquitte *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    fb(ENABLE := TRUE, RESET := TRUE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.FAULT.LATCHED, 'front Reset avec axes en zone : acquitte');
    (* (essai SITE -- stub logique) : la persistance du neutre apres redemarrage PLC
       (NeutralXMem/NeutralYMem RETAIN) n est pas testable en boite noire. *)
END_TEST

TEST 'TC-P08-050 Gate consommateurs : DeadmanArmed expose pour le gate G375 (essai SITE - stub logique)'
    (* Le gate F08.07 vit dans PRG_04_Treuils_Benne / PRG_05_Translation (cablage de collage),
       pas dans FB_Joystick (qui ignore Winch/Translation). Ce test verifie l invariant logique
       que le gate consomme : FB_Joystick expose bien DeadmanArmed (et le fait retomber). *)
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* arme le geste -> DeadmanArmed=TRUE (signal que le gate consomme) *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'invariant : DeadmanArmed=TRUE expose pour le gate G375');

    (* desarme -> DeadmanArmed=FALSE (le gate doit alors refuser tout ordre) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'invariant : DeadmanArmed=FALSE apres desarmement (gate bloque)');
END_TEST

TEST 'TC-P08-060 Armement refuse : ArmingPermitDenied=TRUE pendant appui bouton si ArmingPermit=FALSE'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* appui bouton pendant ArmingPermit=FALSE -> ArmingPermitDenied=TRUE *)
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.ARMINGPERMITDENIED, 'appui bouton + ArmingPermit=FALSE -> ArmingPermitDenied=TRUE (F08.08)');
    ASSERT_FALSE(fb.DEADMANARMED, 'armement refuse : pas arme');

    (* appui bouton pendant ArmingPermit=TRUE -> pas de refus *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.ARMINGPERMITDENIED, 'appui bouton + ArmingPermit=TRUE -> pas de refus');

    (* bouton relache + ArmingPermit=FALSE -> pas de refus (niveau, pas front) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE, ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, CALIBRATE := FALSE,
       CFG := cfg, NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.ARMINGPERMITDENIED, 'bouton relache : pas de refus (niveau, pas front)');
END_TEST

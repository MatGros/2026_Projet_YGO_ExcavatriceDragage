(* ═══════════════════════════════════════════════════════════════════════
   🕵️ TEST CI AD HOC — FB_Joystick / ArmingPermit (LOT_JOYSTICK_ARMINGPERMIT)
   ───────────────────────────────────────────────────────────────────────
   Prouve les critères d'acceptation AC1/AC2/AC3 du contrat
   TASK_CONTRACT_JOYSTICK_ARMINGPERMIT.yaml :
     • AC1 : ArmingPermit=FALSE + appui 110ms -> DeadmanArmed=FALSE ;
             ArmingPermit=TRUE  + appui 110ms -> DeadmanArmed=TRUE.
     • AC2 : ArmingPermit=FALSE -> AxisCmdX/Y.Enable=FALSE, SpeedRef=0,
             warning "armement non permis" actif (sortie ArmingPermitDenied).
     • AC3 : RawOutOfRange=TRUE -> Enable=FALSE même si ArmingPermit=TRUE ;
             ArmingPermit=FALSE bloque l'armement même sans défaut capteur.
   ⚠️ Chaque appel fb(...) = 1 scan (10ms) ; ADVANCE_TIME avance le temps simulé
   sans faire tourner le FB. Un maintien de 110ms = front + ADVANCE_TIME + rappel.
   ⚠️ STruCpp ne re-copie PAS la sortie VAR_IN_OUT (NeutralXMem/YMem) entre deux
   appels -> nx/ny ré-injectés avant chaque appel (limite outillage documentée).
   Chaque TEST remet l'état armement à zéro via un premier appel ENABLE:=FALSE
   (le gate remet DeadmanArmed/DeadmanArmPending/ArmingPermitDenied/timers) pour
   être autonome quelle que soit l'instance FB.
   ═══════════════════════════════════════════════════════════════════════ *)

SETUP
VAR
    fb : FB_JOYSTICK;
    nx : INT := 5000;
    ny : INT := 5000;
    diagOk : ST_DIAG_DEVICE;
END_VAR
END_SETUP

TEST 'AC1a : ArmingPermit=FALSE bloque l armement (appui maintenu 110ms)'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    (* reset etat armement via le gate Enable=FALSE *)
    fb(ENABLE := FALSE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* front appui, ArmingPermit=FALSE : la permission refuse le démarrage du timer
       d'armement -> DeadmanArmed ne doit JAMAIS passer à TRUE. *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);   (* maintien 110ms >= DeadmanArmHoldTime 100ms *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'AC1 : ArmingPermit=FALSE + appui 110ms -> DeadmanArmed reste FALSE (armement bloque)');
END_TEST

TEST 'AC1b : ArmingPermit=TRUE autorise l armement (appui maintenu 110ms)'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    fb(ENABLE := FALSE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* front appui, ArmingPermit=TRUE : maintien complet -> armement normal *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);   (* maintien 110ms >= DeadmanArmHoldTime 100ms *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'AC1 : ArmingPermit=TRUE + appui 110ms -> DeadmanArmed=TRUE (armement autorise)');
END_TEST

TEST 'AC2 : ArmingPermit=FALSE -> Enable=FALSE, SpeedRef=0, warning armement non permis actif'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    fb(ENABLE := FALSE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* appui maintenu, ArmingPermit=FALSE : armement bloqué. On pousse même l'axe X/Y
       (RawX/Y=8000) pour prouver qu'AUCUNE commande de mouvement n'est émise. *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 8000, RAWY := 8000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'AC2 : pre-requis - armement bloque (jamais arme)');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'AC2 : ArmingPermit=FALSE -> AxisCmdX.Enable=FALSE (pipeline neutralise)');
    ASSERT_FALSE(fb.AXISCMDY.ENABLE, 'AC2 : ArmingPermit=FALSE -> AxisCmdY.Enable=FALSE');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'AC2 : SpeedRef axe X = 0 (aucune commande de mouvement)');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'AC2 : SpeedRef axe Y = 0');
    ASSERT_TRUE(fb.ARMINGPERMITDENIED, 'AC2 : warning "armement non permis" actif (sortie dediee ArmingPermitDenied)');
END_TEST

TEST 'AC3a : defaut capteur (RawOutOfRange) neutralise Enable meme si ArmingPermit=TRUE'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    fb(ENABLE := FALSE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* arme d'abord avec ArmingPermit=TRUE *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_TRUE(fb.DEADMANARMED, 'AC3a : pre-requis - geste arme avec ArmingPermit=TRUE');

    (* défaut capteur (RawX/RawY hors plage ADC + marge) : Enable doit tomber à FALSE,
       indépendamment d'ArmingPermit (mécanisme interne de perte de confiance) *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := TRUE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 20000, RAWY := 20000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'AC3a : RawOutOfRange=TRUE -> AxisCmdX.Enable=FALSE meme si ArmingPermit=TRUE');
    ASSERT_FALSE(fb.AXISCMDY.ENABLE, 'AC3a : meme comportement axe Y');
    ASSERT_NEAR(fb.AXISCMDX.SPEEDREF, 0.0, 0.01, 'AC3a : SpeedRef X coupee sur defaut capteur');
    ASSERT_NEAR(fb.AXISCMDY.SPEEDREF, 0.0, 0.01, 'AC3a : SpeedRef Y coupee');
END_TEST

TEST 'AC3b : ArmingPermit=FALSE bloque l armement meme sans defaut capteur'
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;
    nx := 5000; ny := 5000;

    fb(ENABLE := FALSE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    (* capteur SAIN (RawX/RawY = 5000, dans plage) + ArmingPermit=FALSE : malgré un appui
       maintenu 110ms, l'armement reste bloqué (la permission, pas un défaut capteur). *)
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ADVANCE_TIME(110000000);
    fb(ENABLE := TRUE, RESET := FALSE,
       ARMINGPERMIT := FALSE,
       BUSCANOPENOP := diagOk, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := TRUE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);
    ASSERT_FALSE(fb.DEADMANARMED, 'AC3b : ArmingPermit=FALSE bloque l armement meme sans defaut capteur');
    ASSERT_EQ(fb.ERRORID, 0, 'AC3b : capteur sain -> aucun defaut capteur leve (blocage purement par permission)');
END_TEST

SETUP
VAR
    fb : FB_JOYSTICK;
    nx : INT := 5000;
    ny : INT := 5000;
    diagOk : ST_DIAG_DEVICE;
    diagDown : ST_DIAG_DEVICE;
END_VAR
END_SETUP

TEST 'Bus non operationnel neutralise les sorties sans lever Error'
    diagDown.ONLINE := FALSE; diagDown.OPERATIONAL := FALSE; diagDown.ERROR := FALSE;
    diagDown.ERRORID := 0; diagDown.STATE := E_DIAG_STATE.INIT; diagDown.STATEATERROR := E_DIAG_STATE.DISABLED;
    diagOk.ONLINE := TRUE; diagOk.OPERATIONAL := TRUE; diagOk.ERROR := FALSE;
    diagOk.ERRORID := 0; diagOk.STATE := E_DIAG_STATE.READY; diagOk.STATEATERROR := E_DIAG_STATE.DISABLED;

    fb(ENABLE := TRUE, RESET := FALSE, POWERCONTACTORENGAGED := TRUE,
       MODE := E_MODE.MAINT_N1, BENNEBUSY := FALSE, PRESERVEARMINGAFTERBUCKET := FALSE,
       BUSCANOPENOP := diagDown, JOYSTICKOP := diagOk,
       RAWX := 5000, RAWY := 5000, RAWBUTTON := FALSE, BTNCALIBRATE := FALSE,
       INVERTX := FALSE, INVERTY := FALSE, DEADBANDRAW := 300, FILTERTIME := T#0MS,
       NEUTRALHOLDTIME := T#100MS, DEADMANARMHOLDTIME := T#100MS, DEADMANARMGRACETIME := T#3S,
       NEUTRALXMEM := nx, NEUTRALYMEM := ny);

    ASSERT_FALSE(fb.READY, 'bus CAN non operationnel doit bloquer Ready');
    ASSERT_FALSE(fb.ERROR, 'un bus down est un GATE de securite, PAS une Error diagnostiquee (pas de bit ErrorId leve ici)');
    ASSERT_FALSE(fb.AXISCMDX.ENABLE, 'sorties axe neutralisees si non operationnel');
END_TEST

TEST 'Reset acquitte une erreur de calibration seulement si la cause a disparu'
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

SETUP
VAR
    fb        : FB_FBSTATUS;
    causes    : ARRAY[0..15] OF ST_FBCAUSE;
END_VAR
END_SETUP

TEST 'TC-P03-001 Enable=FALSE neutralise le statut (gate)'
    fb(ENABLE := FALSE, RESET := FALSE, CAUSES := causes);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_FALSE(fb.STATUS.ERROR, 'Enable=FALSE -> Error=FALSE (statut neutre)');
    ASSERT_FALSE(fb.STATUS.WARNING, 'Enable=FALSE -> Warning=FALSE (statut neutre)');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'Enable=FALSE -> ErrorId=0');
END_TEST

TEST 'Nominal : Enable=TRUE sans cause -> Ready, aucun defaut ni warning'
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_FALSE(fb.STATUS.ERROR, 'aucune cause active -> Error=FALSE');
    ASSERT_FALSE(fb.STATUS.WARNING, 'aucune cause active -> Warning=FALSE');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId=0');
END_TEST

TEST 'TC-P03-007 Warning auto-efface sans Reset des que la cause disparait'
    (* cause 1 = warning (IsWarning=TRUE), auto-efface : jamais de latch, jamais de Reset *)
    causes[1].Active := TRUE;  causes[1].IsWarning := TRUE;  causes[1].Texte := 'Warning cause1';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.WARNING, 'cause1 IsWarning=TRUE -> classe warning');
    ASSERT_EQ(fb.STATUS.WARNINGID, 16#0002, 'WarningId = bit1');
    ASSERT_EQ(fb.STATUS.WARNINGIDTXT, 'Warning cause1', 'texte IHM peuple depuis Causes[1].Texte');
    ASSERT_FALSE(fb.STATUS.ERROR, 'DECISION utilisateur : un warning ne leve JAMAIS Error');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'un warning seul ne demande pas de Reset');

    (* cause disparait, AUCUN Reset : doit s effacer tout seul *)
    causes[1].Active := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.WARNING, 'cause disparue -> Warning auto-efface sans Reset');
    ASSERT_EQ(fb.STATUS.WARNINGID, 0, 'WarningId retombe a 0');
END_TEST

TEST 'TC-P03-002/003 Fault : reste memorise (latche) apres disparition de la cause, jusqu au Reset'
    causes[3].Active := TRUE;  causes[3].IsWarning := FALSE;  causes[3].Texte := 'Fault cause3';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause3 fault actif -> Error=TRUE');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'ErrorId = bit3');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault cause3', 'texte IME peuple depuis Causes[3].Texte');
    ASSERT_TRUE(fb.STATUS.RESETREQUESTED, 'fault actif -> Reset demande');

    (* cause disparait, PAS de Reset : doit rester memorise *)
    causes[3].Active := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause disparue mais PAS de Reset -> Error reste memorise (latche, std 9)');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'ErrorId latche conserve le bit3');

    (* Reset alors que la cause est deja partie : acquitte *)
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset avec cause disparue -> acquitte');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId retombe a 0 apres Reset');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'plus rien a acquitter');
END_TEST

TEST 'TC-P03-006 Reset ne doit PAS acquitter tant que la cause fault reste presente (interlock sur la cause brute)'
    causes[5].Active := TRUE;  causes[5].IsWarning := FALSE;  causes[5].Texte := 'Fault cause5';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : fault actif');

    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'Reset avec cause toujours presente -> ne doit PAS acquitter');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0020, 'bit5 toujours leve, interlock sur la cause brute jamais sur l acquittement');
END_TEST

TEST 'TC-P03-008 Cumul multi-causes latches : un second fault apparait pendant que le premier reste latche'
    causes[3].Active := TRUE;  causes[3].IsWarning := FALSE;  causes[3].Texte := 'Fault cause3';
    causes[5].Active := FALSE; causes[5].IsWarning := FALSE;  causes[5].Texte := 'Fault cause5';

    (* scan 1 : cause3 seule active *)
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'scan 1 : cause3 seule');

    (* scan 2 : cause3 disparait, aucun Reset -> reste latche *)
    causes[3].Active := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'scan 2 : cause3 toujours memorisee');

    (* scan 3 : cause5 apparait -> cumul avec le latch existant *)
    causes[5].Active := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0028, 'scan 3 : cause3 latchee + cause5 active = cumul (0x28)');

    (* scan 4 : cause5 disparait aussi, toujours aucun Reset -> les deux restent latches *)
    causes[5].Active := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0028, 'scan 4 : les 2 causes disparues mais aucun Reset -> cumul conserve');

    (* scan 5 : Reset acquitte le cumul complet *)
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'scan 5 : Reset acquitte le cumul complet');
END_TEST

TEST 'TC-P03-009 Fault et Warning actifs simultanement : texte du fault affiche, warning separe'
    causes[1].Active := TRUE;  causes[1].IsWarning := TRUE;  causes[1].Texte := 'Warning cause1';
    causes[3].Active := TRUE;  causes[3].IsWarning := FALSE; causes[3].Texte := 'Fault cause3';

    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'fault + warning actifs -> Error=TRUE (fault present)');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault cause3', 'le texte Error est celui du fault (un warning ne fournit pas le texte Error)');
    ASSERT_EQ(fb.STATUS.WARNINGIDTXT, 'Warning cause1', 'texte Warning correct');
END_TEST

TEST 'TC-P03-010 Bornes 16 causes : cause0 et cause15 correctement gerees'
    causes[0].Active := TRUE;  causes[0].IsWarning := FALSE; causes[0].Texte := 'Fault cause0';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0001, 'cause0 (borne basse) correctement levee');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault cause0', 'texte cause0 correctement selectionne');

    (* cause0 relachee AVANT le Reset, sinon l interlock cause brute empeche l acquittement (TC-P03-006) *)
    causes[0].Active := FALSE;
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset avec cause disparue -> acquitte');

    causes[15].Active := TRUE; causes[15].IsWarning := FALSE; causes[15].Texte := 'Fault cause15';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#8000, 'cause15 (borne haute) correctement levee');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault cause15', 'texte cause15 correctement selectionne (pas de depassement array)');
END_TEST

TEST 'TC-P03-011 Reset a vide (aucun defaut jamais existe) : aucun effet parasite'
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset sans historique : aucun effet, pas d erreur fantome');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId reste a 0');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'rien a acquitter');

    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'apres relachement du Reset a vide : toujours propre');
END_TEST

TEST 'TC-P03-012 Reset MAINTENU plusieurs scans avec cause active : jamais d acquittement tant que la cause persiste'
    causes[7].Active := TRUE;  causes[7].IsWarning := FALSE; causes[7].Texte := 'Fault cause7 persistant';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : fault actif');

    (* Reset maintenu a TRUE sur 3 scans, cause TOUJOURS presente : re-latch immediat a chaque scan *)
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 1 Reset maintenu, cause presente : ne doit pas acquitter');
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 2 Reset maintenu, cause presente : toujours pas acquitte');
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 3 Reset maintenu, cause presente : toujours pas acquitte');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0080, 'cause7 toujours leve apres 3 scans de Reset maintenu');

    (* cause disparait puis nouveau front Reset -> acquitte *)
    causes[7].Active := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'cause disparue + nouveau front Reset -> acquitte enfin');
END_TEST

TEST 'TC-P03-013 Texte vide si la cause active n a pas de texte configure (pas de plantage)'
    causes[9].Active := TRUE;  causes[9].IsWarning := FALSE;  (* Texte non rempli *)
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause9 active -> Error=TRUE meme sans texte configure');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, '', 'aucun texte configure -> chaine vide, pas de plantage');
END_TEST

TEST 'TC-P03-014 Reset MAINTENU + cause disparait pendant le maintien : PAS d acquittement silencieux (T148, verrou)'
    (* T148 : verrou de non-regression — le latch est une VAR retenue entre scans, jamais remise a zero
       implicitement. Si la cause disparait pendant que Reset reste maintenu (sans nouveau front), Error
       doit RESTER TRUE (le latch garde sa valeur). Un futur refactor qui casserait la retention du latch
       ferait echouer ce test. *)
    causes[7].Active := TRUE;  causes[7].IsWarning := FALSE; causes[7].Texte := 'Fault cause7';
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : fault actif');

    (* Reset maintenu a TRUE sur 3 scans, cause TOUJOURS presente : re-latch immediat a chaque scan *)
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 1 Reset maintenu, cause presente : ne doit pas acquitter');
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 2 Reset maintenu, cause presente : toujours pas acquitte');
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 3 Reset maintenu, cause presente : toujours pas acquitte');

    (* LA FAILLE T148 : cause disparait PENDANT que Reset reste maintenu (aucun nouveau front).
       Le latch (VAR retenue) doit garder TRUE -> Error reste TRUE, PAS d acquittement silencieux. *)
    causes[7].Active := FALSE;
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause disparue pendant Reset maintenu : PAS d acquittement silencieux (latch retenu)');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0080, 'cause7 toujours leve (latch retenu) apres disparition pendant Reset maintenu');

    (* Seul un NOUVEAU front Reset (apres relachement) acquitte *)
    fb(ENABLE := TRUE, RESET := FALSE, CAUSES := causes);
    fb(ENABLE := TRUE, RESET := TRUE, CAUSES := causes);
    ASSERT_FALSE(fb.STATUS.ERROR, 'cause disparue + nouveau front Reset -> acquitte enfin');
END_TEST

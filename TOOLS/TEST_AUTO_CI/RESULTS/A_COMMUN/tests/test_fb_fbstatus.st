SETUP
VAR
    fb        : FB_FBSTATUS;
    errTexts  : ARRAY[0..15] OF STRING;
    warnTexts : ARRAY[0..15] OF STRING;
END_VAR
END_SETUP

TEST 'TC-P03-001 Enable=FALSE neutralise le statut (gate)'
    fb(ENABLE := FALSE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_FALSE(fb.STATUS.ERROR, 'Enable=FALSE -> Error=FALSE (statut neutre)');
    ASSERT_FALSE(fb.STATUS.WARNING, 'Enable=FALSE -> Warning=FALSE (statut neutre)');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'Enable=FALSE -> ErrorId=0');
END_TEST

TEST 'Nominal : Enable=TRUE sans cause -> Ready, aucun defaut ni warning'
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_FALSE(fb.STATUS.ERROR, 'aucune cause active -> Error=FALSE');
    ASSERT_FALSE(fb.STATUS.WARNING, 'aucune cause active -> Warning=FALSE');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId=0');
END_TEST

TEST 'TC-P03-007 Warning auto-efface sans Reset des que la cause disparait'
    warnTexts[1] := 'Warning bit1';

    (* bit1 actif, WarningMask bit1=1 -> classe warning (auto-efface, pas d acquittement) *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0002, WARNINGMASK := 16#0002,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.WARNING, 'bit1 dans WarningMask -> classe warning');
    ASSERT_EQ(fb.STATUS.WARNINGID, 16#0002, 'WarningId = bit1');
    ASSERT_EQ(fb.STATUS.WARNINGIDTXT, 'Warning bit1', 'texte IHM peuple depuis WarningTexts[1]');
    ASSERT_TRUE(fb.STATUS.ERROR, 'ErrorId (union fault+warning) inclut aussi les bits warning actifs (visible operateur)');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'un warning seul (non fault) ne demande pas de Reset');

    (* cause disparait, AUCUN Reset : doit s effacer tout seul *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 16#0002,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.WARNING, 'cause disparue -> Warning auto-efface sans Reset');
    ASSERT_EQ(fb.STATUS.WARNINGID, 0, 'WarningId retombe a 0');
    ASSERT_FALSE(fb.STATUS.ERROR, 'warning non latche : plus de cause active -> Error retombe aussi');
END_TEST

TEST 'TC-P03-002/003 Fault : reste memorise (latche) apres disparition de la cause, jusqu au Reset'
    errTexts[3] := 'Fault bit3 memorise';

    (* bit3 actif, hors WarningMask -> classe fault (a acquitter) *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0008, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'bit3 fault actif -> Error=TRUE');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'ErrorId = bit3');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault bit3 memorise', 'texte IHM peuple depuis ErrorTexts[3]');
    ASSERT_TRUE(fb.STATUS.RESETREQUESTED, 'fault actif -> Reset demande');

    (* cause disparait, PAS de Reset : doit rester memorise *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'cause disparue mais PAS de Reset -> Error reste memorise (latche, std S9)');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'ErrorId latche conserve le bit3');

    (* Reset alors que la cause est deja partie : acquitte *)
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset avec cause disparue -> acquitte');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId retombe a 0 apres Reset');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'plus rien a acquitter');
END_TEST

TEST 'TC-P03-006 Reset ne doit PAS acquitter tant que la cause fault reste presente (interlock sur la cause brute)'
    errTexts[5] := 'Fault bit5';
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0020, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : fault actif');

    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 16#0020, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'Reset avec cause toujours presente -> ne doit PAS acquitter');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0020, 'bit5 toujours leve, interlock sur la cause brute jamais sur l acquittement');
END_TEST

TEST 'TC-P03-008 Cumul multi-bits latches : un second fault apparait pendant que le premier reste latche (non acquitte)'
    errTexts[3] := 'Fault bit3';
    errTexts[5] := 'Fault bit5';

    (* scan 1 : bit3 seul actif *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0008, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'scan 1 : bit3 seul actif');

    (* scan 2 : bit3 disparait, aucun Reset -> reste latche *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0008, 'scan 2 : bit3 toujours memorise (cause partie, pas de Reset)');

    (* scan 3 : bit5 apparait (bit3 absent de la cause courante) -> doit se CUMULER avec le latch existant *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0020, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0028, 'scan 3 : bit3 latche + bit5 nouvellement actif = cumul (0x08 OR 0x20 = 0x28), pas remplacement');

    (* scan 4 : bit5 disparait aussi, toujours aucun Reset -> LES DEUX restent latches ensemble *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0028, 'scan 4 : les 2 causes ont disparu mais aucun Reset -> les 2 bits restent memorises ensemble');

    (* scan 5 : Reset acquitte le cumul complet en un seul front *)
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'scan 5 : Reset acquitte le cumul complet (bit3 + bit5) en un seul front');
END_TEST

TEST 'TC-P03-009 Fault et Warning actifs simultanement : le texte affiche est celui du bit le PLUS BAS, pas forcement le plus critique'
    (* ErrorIdTxt puise TOUJOURS dans ErrorTexts (jamais WarningTexts), meme pour un bit classe
       warning -- donc le texte du bit1 (warning) doit etre configure ICI, pas dans warnTexts. *)
    errTexts[1] := 'Warning bit1 (mineur, texte source = ErrorTexts)';
    errTexts[3] := 'Fault bit3 (critique)';
    warnTexts[1] := 'Warning bit1 (texte WarningIdTxt, source distincte)';

    (* bit1=warning (mineur) ET bit3=fault (critique) actifs EN MEME TEMPS *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#000A, WARNINGMASK := 16#0002,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'fault + warning actifs simultanement -> Error=TRUE (union)');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#000A, 'ErrorId = union fault(bit3=0x08) + warning(bit1=0x02) = 0x0A');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Warning bit1 (mineur, texte source = ErrorTexts)',
              'ATTENTION comportement actuel documente (audit 2026-08-22, T147) : le texte du bit le PLUS BAS est affiche (ici le warning bit1 mineur), PAS le fault bit3 plus critique -- priorite fault>warning a challenger cote spec si ce cas se produit reellement en prod');
    ASSERT_EQ(fb.STATUS.WARNINGIDTXT, 'Warning bit1 (texte WarningIdTxt, source distincte)', 'texte warning correct, coherent avec WarningId=bit1 seul');
END_TEST

TEST 'TC-P03-010 Bornes du bitfield WORD (16 bits) : bit0 et bit15 correctement geres, pas d off-by-one'
    errTexts[0] := 'Fault bit0';

    (* borne basse *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0001, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0001, 'bit0 (borne basse) correctement leve');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault bit0', 'texte bit0 correctement selectionne (indexation ARRAY[0..15] cote bas)');

    (* acquitte avant de passer a la borne haute *)
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);

    (* borne haute *)
    errTexts[15] := 'Fault bit15';
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#8000, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_EQ(fb.STATUS.ERRORID, 16#8000, 'bit15 (borne haute) correctement leve');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, 'Fault bit15', 'texte bit15 correctement selectionne (pas de depassement ARRAY[0..15] cote haut)');
END_TEST

TEST 'TC-P03-011 Reset a vide (aucun defaut n a jamais existe) : aucun effet parasite'
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.ERROR, 'Reset sans historique de defaut : aucun effet, pas d erreur fantome');
    ASSERT_EQ(fb.STATUS.ERRORID, 0, 'ErrorId reste a 0');
    ASSERT_FALSE(fb.STATUS.RESETREQUESTED, 'rien a acquitter');

    (* Reset relache ensuite : etat toujours propre *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.ERROR, 'apres relachement du Reset a vide : toujours propre');
END_TEST

TEST 'TC-P03-012 Reset MAINTENU plusieurs scans avec la cause active : jamais d acquittement tant que la cause persiste (pas seulement au 1er scan)'
    errTexts[7] := 'Fault bit7 persistant';
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0080, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'precondition : fault actif');

    (* Reset maintenu a TRUE sur 3 scans consecutifs, cause TOUJOURS presente *)
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 16#0080, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 1 de Reset maintenu, cause presente : ne doit pas acquitter');
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 16#0080, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 2 de Reset maintenu, cause presente : toujours pas acquitte (pas de fuite sur niveau haut)');
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 16#0080, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'scan 3 de Reset maintenu, cause presente : toujours pas acquitte');
    ASSERT_EQ(fb.STATUS.ERRORID, 16#0080, 'bit7 toujours leve apres 3 scans de Reset maintenu, cause jamais partie');

    (* ⚠️ FAILLE REELLE DECOUVERTE PAR CE TEST (2026-08-22, a remonter/tracer separement de T147) :
       le front Reset au scan 1 a deja remis ErrorIdLatched a 0 (ligne "IF ResetEdge.Q THEN
       ErrorIdLatched:=0"), MEME SI la cause etait encore presente a ce moment-la. Error restait
       TRUE ensuite (scans 1-3) uniquement grace a l union sur la cause BRUTE (FaultCause), pas
       grace au latch (qui est deja vide). Donc des que la cause brute disparait -- MEME SANS
       aucun nouveau front Reset -- Error retombe silencieusement a FALSE ici. C'est un
       acquittement de fait sans geste conscient renouvele au moment ou la cause disparait
       reellement : Reset simplement MAINTENU pendant qu un defaut se resout tout seul efface le
       defaut sans qu on l ait "re-confirme". Comportement actuel prouve ci-dessous, PAS un
       comportement souhaite -- a trancher avec la meme decision de spec que T147. *)
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.ERROR, 'FAILLE (voir commentaire ci-dessus) : Reset simplement MAINTENU (pas de nouveau front) + cause qui disparait entre-temps = acquittement silencieux, sans confirmation au moment reel de la disparition');

    (* Reset redescend puis nouveau front montant : acquitte enfin *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    fb(ENABLE := TRUE, RESET := TRUE, ERRORIDCAUSE := 0, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_FALSE(fb.STATUS.ERROR, 'nouveau front Reset (redescendu puis remonte) avec cause disparue : acquitte enfin');
END_TEST

TEST 'TC-P03-013 Texte IHM vide si le bit actif n a pas de texte configure (pas de plantage, pas de fuite d un autre bit)'
    (* bit9 actif mais errTexts[9] jamais rempli dans ce TEST *)
    fb(ENABLE := TRUE, RESET := FALSE, ERRORIDCAUSE := 16#0200, WARNINGMASK := 0,
       ERRORTEXTS := errTexts, WARNINGTEXTS := warnTexts);
    ASSERT_TRUE(fb.STATUS.ERROR, 'bit9 actif -> Error=TRUE meme sans texte configure');
    ASSERT_EQ(fb.STATUS.ERRORIDTXT, '', 'aucun texte configure pour bit9 -> chaine vide, pas de plantage ni de texte residuel d un autre bit');
END_TEST

(* =======================================================================
   🧪 test_fb_faultcore.st — Socle FB_FaultCore (TC-P03-008..013)
   ───────────────────────────────────────────────────────────────
   Lot : T174 (P0 — test_fb_fbstatus.st vise un FB supprimé au commit
   51fccce6 ; CE fichier le remplace contre FB_FaultCore.st actuel.
   Fiche : DOC/AF/AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md §2.
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG ; hex décrit en décimal (bit 0 = 1, bit 15 = 32768).
   ======================================================================= *)

SETUP
VAR
    fb : FB_FAULTCORE;
END_VAR
END_SETUP

(* ── Remise à zéro commune : pulse Enable+Reset, puis Reset retombé ── *)

TEST 'TC-P03-011 Reset sans historique de defaut : aucun effet parasite'
    (* Remise à zéro avec un front Reset sur un FB vierge *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ADVANCE_TIME(10000000);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Reset sans historique : LatchedId reste 0');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'Reset sans historique : Latched reste FALSE');
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'Aucune cause active : ErrorId = 0');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Aucune cause active : Error = FALSE');
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE');
END_TEST

TEST 'TC-P03-008 Cumul de 2 causes latchees apparues a des instants differents, un seul Reset les acquitte ensemble'
    (* Remise a zero *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);

    (* Cause 2 latchee apparait -> bit 2 (4) latche ; causes inactives entre scans *)
    fb.CAUSES[2].ACTIVE := TRUE;
    fb.CAUSES[2].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 4, 'Cause 2 latchee -> LatchedId = bit 2 (4)');
    ASSERT_TRUE(fb.FAULT.LATCHED, 'Latch arme');

    (* La cause 2 disparait -> le bit latche reste (defaut non acquitte) *)
    fb.CAUSES[2].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 4, 'Cause disparue, bit 2 latche conserve');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Cause 2 inactive : vue LIVE retombee');

    (* Cause 5 latchee apparait a un autre instant -> cumul bits 2 + 5 (4 + 32 = 36) *)
    fb.CAUSES[5].ACTIVE := TRUE;
    fb.CAUSES[5].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 36, 'Cumul bit 2 (4) + bit 5 (32) = 36');
    ASSERT_TRUE(fb.FAULT.ERROR, 'Cause 5 active -> vue LIVE en erreur');

    (* Les 2 causes se relâchent SANS Reset (ré-armement fail-safe : le bit reste tant
       que la cause est active — il faut désactiver AVANT d'asserter le clear) *)
    fb.CAUSES[5].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 36, 'Causes relâchées sans Reset : les 2 latches (36) restent');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Vue LIVE retombée (aucune cause active)');

    (* Un seul front Reset les acquitte ensemble *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Un seul front Reset acquitte les 2 latches ensemble');
    ASSERT_FALSE(fb.FAULT.LATCHED, 'Plus aucun latch apres Reset');

    (* Nettoyage causes pour la suite *)
    fb.CAUSES[2].ACTIVE := FALSE;
    fb.CAUSES[2].LATCHING := FALSE;
    fb.CAUSES[5].ACTIVE := FALSE;
    fb.CAUSES[5].LATCHING := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE);
END_TEST

TEST 'TC-P03-009 Cause live + cause latchee simultanees : live retombe seule, latchee reste jusqu au Reset'
    (* Remise a zero *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);

    (* Cause 1 live + cause 3 latchee simultanees (aligne sur la fiche TC-P03-009) *)
    fb.CAUSES[1].ACTIVE := TRUE;
    fb.CAUSES[1].LATCHING := FALSE;
    fb.CAUSES[3].ACTIVE := TRUE;
    fb.CAUSES[3].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.ERRORID, 10, 'ErrorId LIVE = bit 1 (2) + bit 3 (8) = 10');
    ASSERT_TRUE(fb.FAULT.ERROR, 'Deux causes actives -> Error=TRUE');
    ASSERT_EQ(fb.FAULT.LATCHEDID, 8, 'LatchedId = bit 3 (8) seul (cause 1 non latchee)');

    (* La cause live retombe seule : elle quitte ErrorId (bit 3 reste : cause 3 ENCORE active) *)
    fb.CAUSES[1].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.ERRORID, 8, 'Cause 1 inactive -> ErrorId = bit 3 seul (cause 3 encore active)');
    ASSERT_TRUE(fb.FAULT.ERROR, 'Cause 3 toujours active -> Error=TRUE');
    ASSERT_EQ(fb.FAULT.LATCHEDID, 8, 'Latche conservee apres retombee de la live');

    (* La latchee se relache elle aussi SANS Reset : latches conservees (fail-safe),
       MAIS ErrorId retombe (plus aucune cause active) *)
    fb.CAUSES[3].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'Cause 3 inactive -> ErrorId = 0 sans Reset');
    ASSERT_EQ(fb.FAULT.LATCHEDID, 8, 'Latche conservee apres disparition de la cause');

    (* Front Reset : la latchee est acquitte *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Reset front efface la latchee');

    (* Nettoyage *)
    fb.CAUSES[1].ACTIVE := FALSE;
    fb.CAUSES[1].LATCHING := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE);
END_TEST

TEST 'TC-P03-010 Bornes de la liste Causes : bit 0 et bit 15 correctement mappes (pas d off-by-one)'
    (* Remise a zero *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);

    (* Causes[0] et Causes[15] latchees et actives *)
    fb.CAUSES[0].ACTIVE := TRUE;
    fb.CAUSES[0].LATCHING := TRUE;
    fb.CAUSES[15].ACTIVE := TRUE;
    fb.CAUSES[15].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 32769, 'Bit 0 (1) + bit 15 (32768) = 32769, pas d off-by-one');
    ASSERT_EQ(fb.FAULT.ERRORID, 32769, 'Vue LIVE identique : SHL(1, i) aux bornes');

    (* Les 2 causes se relachent SANS Reset : les latches (32769) restent (fail-safe) *)
    fb.CAUSES[0].ACTIVE := FALSE;
    fb.CAUSES[15].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 32769, 'Causes relachees sans Reset : latches conservees');
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'Vue LIVE retombee : ErrorId = 0 sans Reset');

    (* Front Reset *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Reset aux bornes : rien ne persiste');

    (* Nettoyage *)
    fb.CAUSES[0].ACTIVE := FALSE;
    fb.CAUSES[0].LATCHING := FALSE;
    fb.CAUSES[15].ACTIVE := FALSE;
    fb.CAUSES[15].LATCHING := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE);
END_TEST

TEST 'TC-P03-012 Reset maintenu niveau haut : pas d acquittement silencieux, cause reaparue re-arme (faille T148 non applicable)'
    (* Remise a zero *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);

    (* Cause 0 latchee -> LatchedId = 1 *)
    fb.CAUSES[0].ACTIVE := TRUE;
    fb.CAUSES[0].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 1, 'Cause latchee -> bit 0');

    (* Reset passe TRUE (nouveau front) pendant que la cause est inactive : clear legitime *)
    fb.CAUSES[0].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Front Reset (cause inactive) : latches effaces');

    (* Reset MAINTENU (T#TRUE, aucun nouveau front) : la cause reapparait -> re-armement fail-safe *)
    fb.CAUSES[0].ACTIVE := TRUE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 1, 'Cause reapparue Active AND Latching sous Reset maintenu : re-arme (pas d acquittement silencieux)');

    (* Cause redisparait, Reset TOUJOURS maintenu : aucun nouveau front -> le bit re-arme n est PAS efface *)
    fb.CAUSES[0].ACTIVE := FALSE;
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 1, 'R_TRIG sans nouveau front : le clear ne s applique pas (faille T148 non applicable)');

    (* Reset relache puis re-pulse : acquittement effectif *)
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Nouveau front Reset apres relachement : acquittement effectif');

    (* Nettoyage *)
    fb.CAUSES[0].ACTIVE := FALSE;
    fb.CAUSES[0].LATCHING := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE);
END_TEST

TEST 'TC-P03-013 Enable=FALSE : vue LIVE masquee mais vue LATCHEE reste publiee (pas d effacement silencieux OFF->ON)'
    (* Remise a zero *)
    fb(ENABLE := TRUE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);

    (* Cause latchee apparait et latche *)
    fb.CAUSES[1].ACTIVE := TRUE;
    fb.CAUSES[1].LATCHING := TRUE;
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 2, 'Cause 1 latchee -> bit 1 (2)');

    (* Enable=FALSE : LIVE masquee, LATCHED conserve *)
    fb(ENABLE := FALSE, RESET := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := FALSE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.ERRORID, 0, 'Enable=FALSE : vue LIVE non evaluee -> ErrorId=0');
    ASSERT_FALSE(fb.FAULT.ERROR, 'Enable=FALSE : Error=FALSE');
    ASSERT_EQ(fb.FAULT.LATCHEDID, 2, 'Enable=FALSE : LatchedId CONSERVE (pas d effacement silencieux)');
    ASSERT_TRUE(fb.FAULT.LATCHED, 'Latche toujours publiee meme FB desactive');

    (* Retour Enable=TRUE SANS Reset : le latch reste (bascule OFF->ON n efface rien) *)
    fb(ENABLE := TRUE, RESET := FALSE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := TRUE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 2, 'Re-Enable sans Reset : latch conserve (bascule OFF->ON n efface rien)');

    (* Reset aussi effectif avec Enable=FALSE (std §9 : jamais conditionne) *)
    fb(ENABLE := FALSE, RESET := TRUE);
    ADVANCE_TIME(10000000);
    fb(ENABLE := FALSE, RESET := FALSE);
    ASSERT_EQ(fb.FAULT.LATCHEDID, 0, 'Reset front agit meme Enable=FALSE');

    (* Nettoyage *)
    fb.CAUSES[1].ACTIVE := FALSE;
    fb.CAUSES[1].LATCHING := FALSE;
    fb(ENABLE := TRUE, RESET := FALSE);
END_TEST
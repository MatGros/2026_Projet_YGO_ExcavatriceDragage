(* =======================================================================
   🧪 test_fb_winchoutputinterlock.st — FB_WinchOutputInterlock (TC-P10-012, 013, 020, 021, 022, 039.1)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_WinchOutputInterlock_v1.0.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG ; hex décrit en décimal (bit 0 = 1).
   Watchdog frein = 500ms ; RestartDelay = 1500ms ; DeadTimeSameDir/OppositeDir = 1s (défaut).
   ======================================================================= *)

SETUP
VAR
    fb : FB_WinchOutputInterlock;
END_VAR
END_SETUP

(* ── Remise à zéro commune : Enable=TRUE, frein serré, pause 1500ms pour purger RestartRequired/DeadTime ── *)

TEST 'TC-P10-012 Watchdog frein : BrakeCmd sans confirmation 500ms -> bit0, RestartInhibit, FAULT ; pas de faux defaut au RestartRequired'
    (* Scan 1 : regime nominal, frein serre (BrakeFeedback=FALSE), pause pour purger *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ASSERT_TRUE(fb.Ready, 'Regime nominal -> Ready=TRUE');

    (* Scan 2 : demande mouvement, frein NON confirme ouvert (BrakeFeedback=FALSE) -> watchdog arme *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.RelayFwd, 'Demande montee -> RelayFwd');
    ASSERT_TRUE(fb.BrakeCmd, 'Demande montee -> BrakeCmd');
    ASSERT_EQ(fb.State, E_WinchFinalInterlockState#WAIT_BRAKE_COMMAND_CONFIRMATION, 'Etat WAIT_BRAKE_COMMAND_CONFIRMATION (2)');

    (* Scan 3 : apres 500ms sans confirmation -> defaut frein *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.Error, 'Timeout frein 500ms -> Error');
    ASSERT_EQ(fb.ErrorId, 1, 'Timeout frein -> bit0 (1)');
    ASSERT_TRUE(fb.RestartInhibit, 'Timeout frein -> RestartInhibit=TRUE');
    ASSERT_EQ(fb.Reason, E_WinchFinalInterlockReason#BRAKE_COMMAND_NOT_CONFIRMED, 'Reason=BRAKE_COMMAND_NOT_CONFIRMED (1)');
    ASSERT_EQ(fb.State, E_WinchFinalInterlockState#FAULT, 'Etat FAULT (5)');
END_TEST

TEST 'TC-P10-012bis Pas de faux defaut au RestartRequired : BrakeCmd retenu ne doit pas armer le watchdog'
    (* Scan 1 : regime nominal, pause pour purger *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);

    (* Scan 2 : demande mouvement, frein confirme (BrakeFeedback=TRUE) -> mouvement autorise *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.RelayFwd, 'Mouvement autorise -> RelayFwd');

    (* Scan 3 : arret -> RestartRequired=TRUE *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);

    (* Scan 4 : nouvelle demande IMMEDIATE (RestartRequired=TRUE) -> BrakeCmd retenu, watchdog NON arme *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_FALSE(fb.RelayFwd, 'RestartRequired -> RelayFwd retenu');
    ASSERT_FALSE(fb.BrakeCmd, 'RestartRequired -> BrakeCmd retenu (FALSE)');
    ASSERT_EQ(fb.State, E_WinchFinalInterlockState#WAIT_RESTART_DELAY, 'Etat WAIT_RESTART_DELAY (4)');

    (* Scan 5 : apres 500ms, BrakeCmd=FALSE -> PAS de faux defaut *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_FALSE(fb.Error, 'BrakeCmd retenu par RestartRequired -> PAS de faux defaut frein');
    ASSERT_FALSE(fb.RestartInhibit, 'Pas de RestartInhibit sur faux defaut');
END_TEST

TEST 'TC-P10-013 Defaut frein : latches preserves hors Enable, reautorisation complete'
    (* Scan 1 : regime nominal, pause pour purger *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);

    (* Scan 2 : demande mouvement, frein non confirme -> watchdog arme *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.Error, 'Precondition : defaut frein');
    ASSERT_TRUE(fb.RestartInhibit, 'Precondition : RestartInhibit');

    (* Scan 3 : Enable=FALSE -> sorties FALSE MAIS latches preserves *)
    ADVANCE_TIME(10000000);
    fb(Enable := FALSE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_FALSE(fb.RelayFwd, 'Enable=FALSE -> RelayFwd=FALSE');
    ASSERT_FALSE(fb.BrakeCmd, 'Enable=FALSE -> BrakeCmd=FALSE');
    ASSERT_TRUE(fb.RestartInhibit, 'Enable=FALSE -> RestartInhibit PRESERVE');
    ASSERT_EQ(fb.ErrorId, 1, 'Enable=FALSE -> ErrorId bit0 PRESERVE');

    (* Scan 4 : re-Enable, cause disparue (BrakeFeedback=TRUE) + front Reset -> ResetRequired leve *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := TRUE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ASSERT_FALSE(fb.Error, 'Cause disparue + Reset -> Error=FALSE');

    (* Scan 5 : demande neutre observee (MotorRequest=FALSE) -> NeutralRequestSeen *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);

    (* Scan 6 : nouvelle demande distincte -> RestartInhibit leve *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_FALSE(fb.RestartInhibit, 'Reautorisation complete -> RestartInhibit=FALSE');
    ASSERT_TRUE(fb.RelayFwd, 'Reautorisation -> mouvement autorise');
END_TEST

TEST 'TC-P10-020 Watchdog frein reel terrain : temps/contacteur/bobine'
    (* (essai site — stub) : le watchdog frein reel (temps de reponse contacteur/bobine, usure)
       est une verification terrain sur l automate reel, jamais automatisable en boite noire.
       On verifie ici la brique logicielle : le watchdog 500ms se declenche sur BrakeCmd sans
       confirmation, condition necessaire du diagnostic terrain. *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.Error, 'Watchdog frein logiciel 500ms -> Error (brique du diagnostic terrain)');
    ASSERT_EQ(fb.Reason, E_WinchFinalInterlockReason#BRAKE_COMMAND_NOT_CONFIRMED, 'Reason=BRAKE_COMMAND_NOT_CONFIRMED');
END_TEST

TEST 'TC-P10-021 Temps mort meme sens : 1s apres arret -> nouvelle demande (DeadTimeSameDir)'
    (* DeadTimeSameDir=2s force pour rendre le temps mort observable (par defaut 1s, masque
       par RestartDelay 1500ms). La demande meme sens est retenue tant que DeadTimeSameDir
       n est pas ecoule. *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);

    (* Scan 2 : demande montee, frein confirme -> mouvement *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);
    ASSERT_TRUE(fb.RelayFwd, 'Mouvement autorise -> RelayFwd');

    (* Scan 3 : arret -> DeadTimePending=TRUE *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);

    (* Scan 4 : apres 1500ms (RestartRequired leve), DeadTimeSameDir=2s pas encore ecoule -> retenu *)
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);
    ASSERT_FALSE(fb.RelayFwd, 'DeadTimeSameDir pas ecoule -> demande meme sens retenue');
    ASSERT_EQ(fb.State, E_WinchFinalInterlockState#WAIT_RESTART_DELAY, 'Etat WAIT_RESTART_DELAY (4)');

    (* Scan 5 : apres 2s (DeadTimeSameDir ecoule) -> demande meme sens acceptee *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#2s, DeadTimeOppositeDir := T#2s);
    ASSERT_TRUE(fb.RelayFwd, 'DeadTimeSameDir ecoule -> demande meme sens acceptee');
END_TEST

TEST 'TC-P10-022 Temps mort inversion : 1s apres arret + inversion sens (DeadTimeOppositeDir)'
    (* DeadTimeOppositeDir=2s force pour rendre le temps mort d inversion observable.
       L inversion est retenue tant que DeadTimeOppositeDir n est pas ecoule. *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);

    (* Scan 2 : demande montee, frein confirme -> mouvement *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);
    ASSERT_TRUE(fb.RelayFwd, 'Mouvement montee -> RelayFwd');

    (* Scan 3 : arret -> DeadTimePending=TRUE *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);

    (* Scan 4 : apres 1500ms, inversion (descente) -> DeadTimeOppositeDir=2s pas ecoule -> retenu *)
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := TRUE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);
    ASSERT_FALSE(fb.RelayRev, 'DeadTimeOppositeDir pas ecoule -> inversion retenue');
    ASSERT_EQ(fb.State, E_WinchFinalInterlockState#WAIT_RESTART_DELAY, 'Etat WAIT_RESTART_DELAY (4)');

    (* Scan 5 : apres 2s (DeadTimeOppositeDir ecoule) -> inversion acceptee *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := TRUE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1, DeadTimeSameDir := T#1s, DeadTimeOppositeDir := T#2s);
    ASSERT_TRUE(fb.RelayRev, 'DeadTimeOppositeDir ecoule -> inversion acceptee');
END_TEST

TEST 'TC-P10-039.1 Frein couple direct : BrakeCmd = RelayFwd OR RelayRev dans tous les etats'
    (* Scan 1 : regime nominal, pause pour purger *)
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ADVANCE_TIME(1500000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ASSERT_FALSE(fb.BrakeCmd, 'Repos : BrakeCmd=FALSE (RelayFwd/Rev=FALSE)');

    (* Scan 2 : mouvement montee -> BrakeCmd=TRUE (RelayFwd=TRUE) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := TRUE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := TRUE, RequestedRelayRev := FALSE,
       RequestedContactor1 := TRUE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 1);
    ASSERT_TRUE(fb.RelayFwd, 'Mouvement -> RelayFwd=TRUE');
    ASSERT_TRUE(fb.BrakeCmd, 'Mouvement -> BrakeCmd=TRUE (couple direct)');

    (* Scan 3 : arret -> BrakeCmd=FALSE *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
       BrakeFeedback := FALSE, FwdRevSpeedFeedbackOff := TRUE,
       RequestedRelayFwd := FALSE, RequestedRelayRev := FALSE,
       RequestedContactor1 := FALSE, RequestedContactor2 := FALSE,
       RequestedContactor3 := FALSE, RequestedContactor4 := FALSE,
       RequestedStep := 0);
    ASSERT_FALSE(fb.RelayFwd, 'Arret -> RelayFwd=FALSE');
    ASSERT_FALSE(fb.BrakeCmd, 'Arret -> BrakeCmd=FALSE (jamais de divergence frein/mouvement)');
END_TEST

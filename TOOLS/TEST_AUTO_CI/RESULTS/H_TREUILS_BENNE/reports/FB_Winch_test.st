(* =======================================================================
   🧪 test_fb_winch.st — FB_Winch (TC-P10-011, 017, 018, 019, 042.1, 052.1)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Winch_v1.0.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG ; hex décrit en décimal (bit 0 = 1, bit 15 = 32768).
   Table valide : seuils croissants [10,30,50,70,90], P2..P5 au moins 1 contacteur TRUE.
   ======================================================================= *)

SETUP
VAR
    FB_W : FB_Winch;
    Table : ST_SpeedStepTable;
END_VAR
END_SETUP

(* ── Table valide commune ── *)

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    FB_W(Enable := FALSE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Ready, 'Enable=TRUE etabli -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette et re-neutralisation *)
    FB_W(Enable := FALSE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P10-011 Inversion Fwd<->Rev : neutre->sens immediat, inversion exige delai + rampe a 0'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    (* Scan 1 : regime nominal *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Ready, 'Treuil pret');

    (* Scan 2 : neutre -> montee = IMMEDIAT (pas de DirectionChangePending) *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 20.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.CommandedDirection, 1, 'Neutre->montee : CommandedDirection=1 immediat');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Neutre->montee : pas de pending');
    ASSERT_TRUE(FB_W.RelayFwd, 'Montee -> RelayFwd');

    (* Scan 3 : arret -> StepNumber=0, CommandedDirection=0 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.StepNumber, 0, 'Arret -> StepNumber=0');

    (* Scan 4 : inversion directe montee->descente (StepNumber=0) -> pending + rampe a 0 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := -1, SpeedTgt_Pct := 20.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.DirectionChangePending, 'Inversion -> DirectionChangePending=TRUE');
    ASSERT_EQ(FB_W.StepNumber, 0, 'Inversion : rampe forcee a 0 pendant attente');

    (* Scan 5 : apres DirectionInterlockDelayDescent=400ms -> CommandedDirection=-1 *)
    ADVANCE_TIME(400000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := -1, SpeedTgt_Pct := 20.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.CommandedDirection, -1, 'Apres 400ms -> CommandedDirection=-1');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Apres delai -> pending leve');
END_TEST

TEST 'TC-P10-017 Config palier invalide : palier 0, sorties sures'
    (* Table invalide : seuils non croissants (tous a 0) *)
    Table.StepThreshold_Pct[1] := 0.0;
    Table.StepThreshold_Pct[2] := 0.0;
    Table.StepThreshold_Pct[3] := 0.0;
    Table.StepThreshold_Pct[4] := 0.0;
    Table.StepThreshold_Pct[5] := 0.0;

    (* Scan 1 : Enable=TRUE, config invalide -> ConfigError latche *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Fault.Error, 'Config invalide -> Error');
    ASSERT_EQ(FB_W.StepNumber, 0, 'Config invalide -> palier 0');
    ASSERT_FALSE(FB_W.RelayFwd, 'Config invalide -> RelayFwd=FALSE (sortie sure)');
    ASSERT_FALSE(FB_W.RelayRev, 'Config invalide -> RelayRev=FALSE');
    ASSERT_FALSE(FB_W.Contactor1, 'Config invalide -> Contactor1=FALSE');
END_TEST

TEST 'TC-P10-018 StuckClosed : contacteurs off non confirmes 500ms -> bit1 ErrorId'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    (* Scan 1 : regime nominal *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Fault.Error, 'Nominal : pas d erreur');

    (* Scan 2 : arret commande mais contacteurs NON retombes (FwdRevSpeedFeedbackOff=FALSE) *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := FALSE,
         SpeedStepTable := Table);
    ASSERT_FALSE(FB_W.Fault.Error, 'Avant 500ms : pas encore de defaut');

    (* Scan 3 : apres ContactorFeedbackTimeout=500ms -> StuckClosed -> bit1 *)
    ADVANCE_TIME(500000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := FALSE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.Fault.Error, 'Contacteurs colles 500ms -> Error');
    ASSERT_EQ(FB_W.Fault.ErrorId, 2, 'StuckClosed -> bit1 (2)');
END_TEST

TEST 'TC-P10-019 Ordre MainTask : Safety -> WinchControl -> PRG_06_Outputs'
    (* (essai site — stub) : l ordre d execution MainTask (Safety -> WinchControl -> PRG_06)
       est une propriete de la tache CODESYS, non automatisable en boite noire FB. On verifie
       ici la brique amont : FB_Winch produit bien sa demande sortie (RelayFwd) qui sera
       consommee par la barriere finale PRG_06. *)
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 20.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.RelayFwd, 'Demande montee produite (consommee par PRG_06)');
    ASSERT_TRUE(FB_W.Contactor1, 'Palier 1 demande');
END_TEST

TEST 'TC-P10-042.1 Plafonds dynamiques palier : descente max 3, montee max 5, approche capteur haut=1'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    (* Scan 1 : regime nominal *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);

    (* Descente : SpeedTgt_Pct=90 -> RequestedStep cape a CfgMaxStepDescente=3 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := -1, SpeedTgt_Pct := 90.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.RequestedStep, 3, 'Descente : palier cape a 3 (CfgMaxStepDescente)');

    (* Reset + montee : SpeedTgt_Pct=90 -> RequestedStep=5 (MaxStepAscent) *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := TRUE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 90.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.RequestedStep, 5, 'Montee : palier 5 (MaxStepAscent)');

    (* Approche capteur haut : HomingApproachActive=TRUE -> palier 1 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := TRUE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 90.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         HomingApproachActive := TRUE, SpeedStepTable := Table);
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Approche capteur haut : palier 1');

    (* Zone ralentissement haut : CablePosM >= TopLimitM - CfgSlowdownDistanceM -> palier 1 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := TRUE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 90.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         CablePosM := 8.0, TopLimitM := 8.5, CfgSlowdownDistanceM := 1.0,
         SpeedStepTable := Table);
    ASSERT_TRUE(FB_W.InTopSlowdownZone, 'Zone ralentissement haut active');
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Zone ralentissement haut : palier 1');
END_TEST

TEST 'TC-P10-052.1 Garde-fou vitesse : vitesse non-stable -> palier 1 (activation par defaut : T177 en attente)'
    (* (activation par defaut : T177 en attente) — SpeedGuardEnable est FALSE par defaut dans le
       code (T177 non execute). On force le parametre TRUE dans le setup pour tester le garde-fou. *)
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;

    (* Scan 1 : regime nominal *)
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := FALSE, Direction := 0, SpeedTgt_Pct := 0.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedStepTable := Table);

    (* Scan 2 : SpeedGuardEnable=TRUE, SpeedGuardReady=FALSE (vitesse non stable) -> palier 1 *)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, StartStop := TRUE, Direction := 1, SpeedTgt_Pct := 90.0,
         PowerContactorEngaged := TRUE, Homed := TRUE, FwdRevSpeedFeedbackOff := TRUE,
         SpeedGuardEnable := TRUE, SpeedGuardReady := FALSE,
         SpeedStepTable := Table);
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Vitesse non stable -> palier 1 (garde-fou)');
    ASSERT_EQ(FB_W.StepNumber, 1, 'Vitesse non stable -> StepNumber=1');
END_TEST

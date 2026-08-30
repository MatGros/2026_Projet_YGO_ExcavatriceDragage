(* =======================================================================
   🧪 test_fb_winch.st — FB_Winch (TC-P10-011, 017, 019, 042.1, 052.1)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Winch_v1.0.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG ; hex décrit en décimal (bit 0 = 1, bit 15 = 32768).
   Table valide : seuils croissants [10,30,50,70,90], P2..P5 au moins 1 contacteur TRUE.
   Interface structs : DriveRequest / Sensors / Config passés en variables
   (le harnais STruCpp ne supporte pas les littéraux de struct en appel FB).
   ======================================================================= *)

SETUP
VAR
    FB_W : FB_Winch;
    Table : ST_SpeedStepTable;
    DriveReq : ST_fbWinch_DriveRequest;
    Sens : ST_fbWinch_Sensors;
    Cfg : ST_fbWinch_Cfg;
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
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_FALSE(FB_W.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.Ready, 'Enable=TRUE etabli -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette et re-neutralisation *)
    FB_W(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
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
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    (* Scan 1 : regime nominal *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.Ready, 'Treuil pret');

    (* Scan 2 : neutre -> montee = IMMEDIAT (pas de DirectionChangePending) *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, 1, 'Neutre->montee : CommandedDirection=1 immediat');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Neutre->montee : pas de pending');
    ASSERT_TRUE(FB_W.RelayFwd, 'Montee -> RelayFwd');

    (* Scan 3 : arret reel via neutre (StartStop=FALSE, Direction=0) -> StepNumber=0,
       CommandedDirection=0 (relais/diagnostic neutres) ; le dernier sens non nul est
       memorise en interne (LastDirection) pour l'interlock de reprise opposee *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.StepNumber, 0, 'Arret -> StepNumber=0');
    ASSERT_EQ(FB_W.CommandedDirection, 0, 'Arret via neutre : CommandedDirection=0 (relais/diagnostic neutres)');

    (* Scan 4 : inversion montee->descente apres neutre (StepNumber=0) -> pending + rampe a 0 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.DirectionChangePending, 'Inversion apres neutre -> DirectionChangePending=TRUE');
    ASSERT_EQ(FB_W.StepNumber, 0, 'Inversion : rampe forcee a 0 pendant attente');

    (* Scan 5 : apres DirectionInterlockDelayDescent=400ms -> CommandedDirection=-1 *)
    ADVANCE_TIME(400000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, -1, 'Apres 400ms -> CommandedDirection=-1');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Apres delai -> pending leve');
END_TEST

TEST 'TC-P10-011b Inversion via neutre : montee reelle -> relache neutre -> reprise descente -> temps mort + zero relais'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    (* Scan 1 : regime nominal *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.Ready, 'Treuil pret');

    (* Scan 2 : montee reelle etablie *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 90.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, 1, 'Montee reelle : CommandedDirection=1');
    ASSERT_TRUE(FB_W.RelayFwd, 'Montee reelle -> RelayFwd');

    (* Scan 3 : relachement neutre (Direction=0) -> StepNumber=0, CommandedDirection=0,
       relais coupes immediatement *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.StepNumber, 0, 'Neutre -> StepNumber=0');
    ASSERT_EQ(FB_W.CommandedDirection, 0, 'Neutre -> CommandedDirection=0 (relais/diagnostic neutres)');
    ASSERT_FALSE(FB_W.RelayFwd, 'Neutre -> RelayFwd coupe immediatement');
    ASSERT_FALSE(FB_W.RelayRev, 'Neutre -> RelayRev reste FALSE');

    (* Scan 4 : reprise descente (Direction=-1) -> pending + zero relais jusqu au delai *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.DirectionChangePending, 'Reprise opposee apres neutre -> pending');
    ASSERT_EQ(FB_W.StepNumber, 0, 'Reprise opposee -> StepNumber=0 (rampe a 0)');
    ASSERT_FALSE(FB_W.RelayRev, 'Reprise opposee -> RelayRev retenu jusqu au delai');

    (* Scan 5 : apres DirectionInterlockDelayDescent=400ms -> CommandedDirection=-1, RelayRev *)
    ADVANCE_TIME(400000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, -1, 'Apres delai -> CommandedDirection=-1');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Apres delai -> pending leve');
    ASSERT_TRUE(FB_W.RelayRev, 'Apres delai -> RelayRev commande');
END_TEST

TEST 'TC-P10-011c Reprise du MEME sens apres neutre : depart immediat (pas de pending)'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    (* Scan 1 : regime nominal *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.Ready, 'Treuil pret');

    (* Scan 2 : montee reelle etablie *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, 1, 'Montee reelle : CommandedDirection=1');
    ASSERT_TRUE(FB_W.RelayFwd, 'Montee reelle -> RelayFwd');

    (* Scan 3 : relachement neutre -> CommandedDirection=0 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, 0, 'Neutre -> CommandedDirection=0');

    (* Scan 4 : reprise du MEME sens (montee) -> depart immediat, pas de pending *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.CommandedDirection, 1, 'Reprise meme sens -> CommandedDirection=1 immediat');
    ASSERT_FALSE(FB_W.DirectionChangePending, 'Reprise meme sens -> pas de pending');
    ASSERT_TRUE(FB_W.RelayFwd, 'Reprise meme sens -> RelayFwd immediat');
END_TEST

TEST 'TC-P10-017 Config palier invalide : palier 0, sorties sures'
    (* Table invalide : seuils non croissants (tous a 0) *)
    Table.StepThreshold_Pct[1] := 0.0;
    Table.StepThreshold_Pct[2] := 0.0;
    Table.StepThreshold_Pct[3] := 0.0;
    Table.StepThreshold_Pct[4] := 0.0;
    Table.StepThreshold_Pct[5] := 0.0;
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    (* Scan 1 : Enable=TRUE, config invalide -> ConfigError latche *)
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 50.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.Fault.Error, 'Config invalide -> Error');
    ASSERT_EQ(FB_W.StepNumber, 0, 'Config invalide -> palier 0');
    ASSERT_FALSE(FB_W.RelayFwd, 'Config invalide -> RelayFwd=FALSE (sortie sure)');
    ASSERT_FALSE(FB_W.RelayRev, 'Config invalide -> RelayRev=FALSE');
    ASSERT_FALSE(FB_W.Contactor1, 'Config invalide -> Contactor1=FALSE');
END_TEST

(* TC-P10-018 (StuckClosed) deplace/adapte dans test_fb_safety_winch.st (T181-02/03 AC5) :
   FB_Winch ne produit plus la detection contacteur colle — proprietaire unique FB_Safety_Winch. *)

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
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
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
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;
    DriveReq.HomingApproachActive := FALSE;
    Sens.CablePosM := 0.0;
    Cfg.SlowdownDistance_M := 1.0;

    (* Scan 1 : regime nominal *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);

    (* Descente : SpeedTgt_Pct=90 -> RequestedStep cape a CfgMaxStepDescente=3 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedTgt_Pct := 90.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.RequestedStep, 3, 'Descente : palier cape a 3 (CfgMaxStepDescente)');

    (* Reset + montee : SpeedTgt_Pct=90 -> RequestedStep=5 (MaxStepAscent) *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 90.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.RequestedStep, 5, 'Montee : palier 5 (MaxStepAscent)');

    (* Approche capteur haut : HomingApproachActive=TRUE -> palier 1 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 90.0;
    DriveReq.HomingApproachActive := TRUE;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Approche capteur haut : palier 1');

    (* Zone ralentissement haut : CablePosM >= TopLimitM - CfgSlowdownDistanceM -> palier 1 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    DriveReq.HomingApproachActive := FALSE;
    FB_W(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 90.0;
    DriveReq.TopLimitM := 8.5;
    Sens.CablePosM := 8.0;
    Cfg.SlowdownDistance_M := 1.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_TRUE(FB_W.InTopSlowdownZone, 'Zone ralentissement haut active');
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Zone ralentissement haut : palier 1');
END_TEST

TEST 'TC-P10-052.1 Garde-fou vitesse : vitesse non-stable -> palier 1 (activation par defaut)'
    (* (activation par defaut : T177) — SpeedGuardEnable est TRUE par defaut dans le code.
       On ne le force pas : le test verifie que le garde-fou est actif sans activation manuelle. *)
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;
    DriveReq.HomingApproachActive := FALSE;
    Sens.CablePosM := 0.0;
    Cfg.SlowdownDistance_M := 1.0;

    (* Scan 1 : regime nominal *)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedTgt_Pct := 0.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);

    (* Scan 2 : SpeedGuardEnable=TRUE (defaut), SpeedGuardReady=FALSE (vitesse non stable) -> palier 1 *)
    ADVANCE_TIME(10000000);
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := 1;
    DriveReq.SpeedTgt_Pct := 90.0;
    Sens.SpeedGuardReady := FALSE;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg);
    ASSERT_EQ(FB_W.RequestedStep, 1, 'Vitesse non stable -> palier 1 (garde-fou)');
    ASSERT_EQ(FB_W.StepNumber, 1, 'Vitesse non stable -> StepNumber=1');
END_TEST

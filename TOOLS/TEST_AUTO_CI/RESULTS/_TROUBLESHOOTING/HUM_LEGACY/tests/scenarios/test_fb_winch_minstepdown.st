(* =======================================================================
   🧪 test ad hoc troubleshooting — FB_Winch / plancher MinStepDown
   Sujet : TROUBLESHOOTING_TreuilM2_LimiteDescente_20260901
   Symptôme : DescendPermit=FALSE (limite basse atteinte) mais descente
   continue au palier 1 jusqu'à -20 m. Reproduit le snapshot 01:48 :
   Direction=-1, StartStop=TRUE, MinStepDown=1 (CommonMinStepDown=MAX(1,·)).
   Question tranchée : le plancher MinStepDown relève-t-il RequestedStep
   à >= 1 APRÈS que EffectiveSafeStop (permis descente refusé) a mis la
   cible à 0 ? ATTENDU CORRECT : StepNumber=0, RelayRev=FALSE.
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

TEST 'TROUBLESHOOT-01 Descente permise : MinStepDown=1 -> palier 1 maintenu (comportement nominal plongee)'
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

    // Scan 0 : regime nominal au NEUTRE (arme l interlock direction)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 1;
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);

    // Neutre -> descente : IMMEDIAT (pas d inversion)
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ASSERT_EQ(FB_W.CommandedDirection, -1, 'Neutre->descente : direction -1 immediat');

    // Regime etabli (cadence descente 500ms)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    ASSERT_TRUE(FB_W.RelayRev, 'Permis OK + MinStepDown=1 -> descente energisee (nominal)');
    ASSERT_EQ(FB_W.StepNumber, 1, 'Plancher MinStepDown=1 -> palier 1 (nominal plongee)');
END_TEST

TEST 'TROUBLESHOOT-02 BUG ? DescendPermit=FALSE + MinStepDown=1 : la descente doit S ARRETER (limite basse atteinte)'
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

    // Phase 0 : neutre (arme l interlock)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 1;
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);

    // Phase 1 : descente normale (permis OK) pour etablir la direction + palier
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    ASSERT_TRUE(FB_W.RelayRev, 'Pre-condition : descente etablie (permis OK)');

    // Phase 2 : LE PERMIS DESCENTE TOMBE (limite basse atteinte) — l operateur maintient
    // la demande (StartStop=TRUE, Dir=-1, MinStepDown=1 : exactement le snapshot 01:48)
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);

    // VERDICT : si ces assertions echouent, le bug plancher est CONFIRME mechaniquement
    ASSERT_EQ(FB_W.StepNumber, 0, 'Permis descente FALSE -> StepNumber doit retomber a 0');
    ASSERT_FALSE(FB_W.RelayRev, 'Permis descente FALSE -> RelayRev doit retomber (arret descente)');
END_TEST

TEST 'TROUBLESHOOT-03 Controle : DescendPermit=FALSE SANS plancher (MinStepDown=0) -> arret immediat'
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

    // Phase 0 : neutre
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 0;  // AUCUN plancher
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);

    // Phase 1 : descente etablie (permis OK)
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    ASSERT_TRUE(FB_W.RelayRev, 'Pre-condition : descente etablie');

    // Phase 2 : permis tombe, SANS plancher -> arret attendu immediat
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);

    ASSERT_EQ(FB_W.StepNumber, 0, 'Sans plancher : permis FALSE -> StepNumber=0 (verrou effectif)');
    ASSERT_FALSE(FB_W.RelayRev, 'Sans plancher : permis FALSE -> RelayRev=FALSE');
END_TEST

TEST 'T216-AC4-1 Regression : DescendPermit=FALSE + MinStepDown=1 -> StepNumber=0 et sorties=0'
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

    // Neutre (arme interlock direction)
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 1;
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    // Descente demandee mais permis DESCENTE FALSE (limite basse)
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);

    ASSERT_EQ(FB_W.StepNumber, 0, 'Permis FALSE + MinStepDown : StepNumber=0 (descente interdite)');
    ASSERT_FALSE(FB_W.RelayRev, 'Permis FALSE + MinStepDown : RelayRev=FALSE');
    ASSERT_FALSE(FB_W.Contactor1, 'Permis FALSE + MinStepDown : contacteur descente OFF');
END_TEST

TEST 'T216-AC4-2 Non-regression plongee Kobold : DescendPermit=TRUE + MinStepDown=3 -> plancher applique'
    Table.StepThreshold_Pct[1] := 10.0;
    Table.StepThreshold_Pct[2] := 30.0;
    Table.StepThreshold_Pct[3] := 50.0;
    Table.StepThreshold_Pct[4] := 70.0;
    Table.StepThreshold_Pct[5] := 90.0;
    Table.P2R1 := TRUE;
    Table.P3R1 := TRUE;
    Table.P4R1 := TRUE;
    Table.P5R1 := TRUE;
    Table.P3R2 := TRUE;
    Table.P3R4 := TRUE;
    Cfg.SpeedStepTable := Table;
    Sens.Homed := TRUE;
    Sens.ContactorsAllOff := TRUE;
    Sens.SpeedGuardReady := TRUE;

    // Neutre
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 3;
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    // Descente avec permis OK, cible basse mais plancher MinStepDown=3
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    ASSERT_EQ(FB_W.RequestedStep, 3, 'Plancher MinStepDown=3 releve RequestedStep (permis OK)');
    ASSERT_TRUE(FB_W.StepNumber > 0, 'Plancher MinStepDown=3 -> StepNumber>0 (plongee maintenue)');
    ASSERT_TRUE(FB_W.RelayRev, 'Plancher MinStepDown=3 -> RelayRev commande (plongee Kobold)');
END_TEST

TEST 'T216-AC4-3 Perte du permis en mouvement : StepNumber retombe a 0 sans reprise de plancher'
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

    // Neutre
    DriveReq.StartStop := FALSE;
    DriveReq.Direction := 0;
    DriveReq.SpeedStepReq := 0;
    DriveReq.MinStepDown := 1;
    DriveReq.MaxStepDown := 3;
    DriveReq.BottomLimitM := -20.0;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);

    // Etablir la descente (permis OK)
    DriveReq.StartStop := TRUE;
    DriveReq.Direction := -1;
    DriveReq.SpeedStepReq := 1;
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := TRUE, AscentPermit := TRUE);
    ASSERT_TRUE(FB_W.RelayRev, 'Pre-condition : descente etablie (permis OK)');

    // Le permis tombe EN MOUVEMENT (operateur tient la demande)
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);
    ADVANCE_TIME(10000000);
    FB_W(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
         DriveRequest := DriveReq, Sensors := Sens, Config := Cfg,
         SafeStop := FALSE, DescendPermit := FALSE, AscentPermit := TRUE);

    ASSERT_EQ(FB_W.StepNumber, 0, 'Permis perdu en mouvement -> StepNumber retombe a 0 (sans reprise)');
    ASSERT_FALSE(FB_W.RelayRev, 'Permis perdu en mouvement -> RelayRev=FALSE (pas de re-atterrissage)');
END_TEST

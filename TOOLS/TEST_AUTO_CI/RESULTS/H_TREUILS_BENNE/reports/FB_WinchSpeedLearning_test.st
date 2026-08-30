(* =======================================================================
   🧪 test_fb_winch_speed_learning.st — FB_WinchSpeedLearning (T181-15)
   ───────────────────────────────────────────────────────────────
   Collecteur STRICTEMENT PASSIF des vitesses reelles par palier (RETAIN).
   Contrat : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-15_SPEED_LEARNING.yaml
   Conventions : 1 appel fb() = 1 scan ; Table est VAR_IN_OUT.
   ⚠️ Harnais (README.md:120-125) : une VAR_IN_OUT n'est JAMAIS re-copiee
   vers la variable de test apres fb() (s.FB.X = s.NX; sans retour s.NX =
   s.FB.X;). On ne peut donc PAS asserter sur Table.Cell[...] apres l'appel.
   Strategie : pre-remplir la variable de test Table AVANT fb(), puis
   asserter uniquement sur les SORTIES FB (CellsFilled/TableComplete/
   CellsTotal/Ready/Learning/LampLearn). La valeur SpeedMps moyenne n'est
   pas lisible via ce harnais (signale a l'orchestrateur).
   Passivite (AC1/AC7) : verifiee par grep de l'interface FB (aucune sortie
   actionneur Relay* / Contactor* / Brake* / SpeedCmd ni Overspeed* / SpeedGuard* ).
   ======================================================================= *)

SETUP
VAR
    fb : FB_WinchSpeedLearning;
    Table : ST_fbWinchSpeedLearning_Table;
    Cfg : ST_fbWinchSpeedLearning_Cfg;
END_VAR
END_SETUP

(* ── Config commune : enveloppes par palier + MinSamples=3 ── *)

TEST 'TC-T181-15a LearnStart=FALSE : aucune collecte, table inchangee (AC3)'
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 3;

    (* Pre-remplissage : 1 cellule valide [1,1,1,1] *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;

    (* LearnStart=FALSE, toutes les autres conditions de collecte valides *)
    fb(Enable := TRUE, LearnStart := FALSE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);

    ASSERT_FALSE(fb.Learning, 'LearnStart=FALSE : pas de collecte (Learning=FALSE)');
    ASSERT_FALSE(fb.LampLearn, 'LearnStart=FALSE : pas de voyant apprentissage');
    ASSERT_EQ(fb.CellsFilled, 1, 'LearnStart=FALSE : aucune nouvelle cellule (CellsFilled=1)');
END_TEST

TEST 'TC-T181-15b Conditions de collecte manquantes une a une : aucune ecriture (AC4)'
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 3;

    (* Mesure non valide : collecte bloquee -> aucune nouvelle cellule (CellsFilled reste 1) *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 2, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := FALSE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Learning, 'Mesure non valide : pas de collecte');
    ASSERT_EQ(fb.CellsFilled, 1, 'Mesure non valide : aucune nouvelle cellule');

    (* Conditions instables : collecte bloquee -> aucune nouvelle cellule *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 3, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := FALSE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Learning, 'Conditions instables : pas de collecte');
    ASSERT_EQ(fb.CellsFilled, 1, 'Conditions instables : aucune nouvelle cellule');

    (* Sens nul : collecte bloquee -> aucune nouvelle cellule *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 0,
       StepNumber := 4, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Learning, 'Sens nul : pas de collecte');
    ASSERT_EQ(fb.CellsFilled, 1, 'Sens nul : aucune nouvelle cellule');

    (* Palier hors 1..5 : collecte bloquee -> aucune nouvelle cellule *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 0, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Learning, 'Palier hors 1..5 : pas de collecte');
    ASSERT_EQ(fb.CellsFilled, 1, 'Palier hors 1..5 : aucune nouvelle cellule');

    (* Axe hors 1..2 : collecte bloquee -> aucune nouvelle cellule *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 0, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Learning, 'Axe hors 1..2 : pas de collecte');
    ASSERT_EQ(fb.CellsFilled, 1, 'Axe hors 1..2 : aucune nouvelle cellule');
END_TEST

TEST 'TC-T181-15c Valid seulement a MinSamples : frontiere via CellsFilled (AC2/AC5)'
VAR
    i : INT;
    j : INT;
    k : INT;
    l : INT;
END_VAR
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 3;

    (* Part 1 : SampleCount=1 (MinSamples-2) -> apres 1 scan, encore < MinSamples -> non valide *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[1][1][1][1].Valid := FALSE;
    Table.Cell[1][1][1][1].SampleCount := 1;
    Table.Cell[1][1][1][1].SpeedMps := 1.0;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 39, 'SampleCount 1->2 (<MinSamples) : cellule pas encore valide (39)');

    (* Part 2 : SampleCount=2 (MinSamples-1) -> apres 1 scan, MinSamples atteint -> valide *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[1][1][1][1].Valid := FALSE;
    Table.Cell[1][1][1][1].SampleCount := 2;
    Table.Cell[1][1][1][1].SpeedMps := 1.0;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 40, 'SampleCount 2->3 (=MinSamples) : cellule validee (40)');
    ASSERT_TRUE(fb.TableComplete, 'MinSamples atteint sur la derniere cellule : TableComplete=TRUE');
END_TEST

TEST 'TC-T181-15d Hors enveloppe : cellule invalidee (Valid=FALSE, SampleCount=0, SpeedMps=0) (AC5)'
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 3;

    (* Cellule validee [1,1,1,1] puis injection hors enveloppe haute (5.0 > Max[1]=2.0) *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 5.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 0, 'Hors enveloppe haute : cellule invalidee (CellsFilled=0)');

    (* Injection sous la borne basse (0.4 < Min[1]=0.5) -> invalidation aussi *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 0.4, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 0, 'Sous borne basse : cellule invalidee (CellsFilled=0)');

    (* Borne exacte ==Max (2.0, inclusive) -> cellule conservee validee *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 2.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 1, 'Borne ==Max (2.0) inclusive : cellule conservee validee (1)');

    (* Borne exacte ==Min (0.5, inclusive) -> cellule conservee validee *)
    Table.Cell[1][1][1][1].Valid := TRUE;
    Table.Cell[1][1][1][1].SpeedMps := 1.5;
    Table.Cell[1][1][1][1].SampleCount := 3;
    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 0.5, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 1, 'Borne ==Min (0.5) inclusive : cellule conservee validee (1)');
END_TEST

TEST 'TC-T181-15e TableComplete : FALSE si une cellule manque, TRUE avec 40 cellules valides (AC6)'
VAR
    i : INT;
    j : INT;
    k : INT;
    l : INT;
END_VAR
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 1;

    (* Table partielle : 39 cellules valides, [2,2,2,5] manquante -> FALSE *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[2][2][2][5].Valid := FALSE;

    fb(Enable := TRUE, LearnStart := FALSE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.TableComplete, 'Table partielle (39/40) : TableComplete=FALSE');
    ASSERT_EQ(fb.CellsFilled, 39, 'Table partielle : CellsFilled=39');
    ASSERT_EQ(fb.CellsTotal, 40, 'CellsTotal=40 (2x2x2x5)');

    (* Table complete : 40 cellules valides -> TRUE *)
    Table.Cell[2][2][2][5].Valid := TRUE;
    fb(Enable := TRUE, LearnStart := FALSE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_TRUE(fb.TableComplete, 'Table complete (40/40) : TableComplete=TRUE');
    ASSERT_EQ(fb.CellsFilled, 40, 'Table complete : CellsFilled=40');
END_TEST

TEST 'TC-T181-15f Passivite : sorties limitees au statut/diagnostic, aucune commande moteur (AC1/AC7)'
    (* La passivite (aucune sortie actionneur Relay* / Contactor* / Brake* / SpeedCmd ni
       Overspeed* / SpeedGuard* ) est verifiee par grep de l interface FB (AC1/AC7).
       Ce test confirme le comportement observable : pendant la collecte, seules les
       sorties de statut/diagnostic evoluent (Ready/Learning/LampLearn) + la Table. *)
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 3;

    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_TRUE(fb.Ready, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_TRUE(fb.Learning, 'Collecte active -> Learning=TRUE');
    ASSERT_TRUE(fb.LampLearn, 'Collecte active -> LampLearn=TRUE');
    ASSERT_EQ(fb.CellsTotal, 40, 'CellsTotal=40 (diagnostic)');

    (* Relache : Enable=FALSE -> Ready=FALSE, plus de collecte *)
    fb(Enable := FALSE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_FALSE(fb.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_FALSE(fb.Learning, 'Enable=FALSE -> Learning=FALSE');
END_TEST

TEST 'TC-T181-15g Sens descente : cellule descente [1,2,1,1] ecrite, montee inchangee (AC2)'
VAR
    i : INT;
    j : INT;
    k : INT;
    l : INT;
END_VAR
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 1;

    (* 39 cellules valides, descente [1,2,1,1] vide. Direction=-1 -> SensIdx=2 *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[1][2][1][1].Valid := FALSE;

    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := -1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 40, 'Descente : cellule descente [1,2,1,1] ecrite et validee (40)');
    ASSERT_TRUE(fb.TableComplete, 'Descente : table complete apres ecriture descente');
END_TEST

TEST 'TC-T181-15h Charge presente : cellule charge [1,1,2,1] ecrite, vide inchangee (AC2)'
VAR
    i : INT;
    j : INT;
    k : INT;
    l : INT;
END_VAR
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 1;

    (* 39 cellules valides, charge [1,1,2,1] vide. LoadPresent=TRUE -> ChargeIdx=2 *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[1][1][2][1].Valid := FALSE;

    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 1, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := TRUE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 40, 'Charge : cellule charge [1,1,2,1] ecrite et validee (40)');
    ASSERT_TRUE(fb.TableComplete, 'Charge : table complete apres ecriture charge');
END_TEST

TEST 'TC-T181-15i Axe M2 (WinchId=2) : cellule [2,1,1,1] ecrite, M1 inchangee (AC2)'
VAR
    i : INT;
    j : INT;
    k : INT;
    l : INT;
END_VAR
    Cfg.MinSpeedMps[1] := 0.5; Cfg.MaxSpeedMps[1] := 2.0;
    Cfg.MinSpeedMps[2] := 1.0; Cfg.MaxSpeedMps[2] := 3.0;
    Cfg.MinSpeedMps[3] := 1.5; Cfg.MaxSpeedMps[3] := 4.0;
    Cfg.MinSpeedMps[4] := 2.0; Cfg.MaxSpeedMps[4] := 5.0;
    Cfg.MinSpeedMps[5] := 2.5; Cfg.MaxSpeedMps[5] := 6.0;
    Cfg.MinSamples := 1;

    (* 39 cellules valides, M2 [2,1,1,1] vide. WinchId=2 -> AxeIdx=2 *)
    FOR i := 1 TO 2 DO
        FOR j := 1 TO 2 DO
            FOR k := 1 TO 2 DO
                FOR l := 1 TO 5 DO
                    Table.Cell[i][j][k][l].Valid := TRUE;
                END_FOR;
            END_FOR;
        END_FOR;
    END_FOR;
    Table.Cell[2][1][1][1].Valid := FALSE;

    fb(Enable := TRUE, LearnStart := TRUE, WinchId := 2, Direction := 1,
       StepNumber := 1, MeasuredSpeedMps := 1.0, MeasuredSpeedValid := TRUE,
       LoadPresent := FALSE, StableForLearn := TRUE, Config := Cfg, Table := Table);
    ASSERT_EQ(fb.CellsFilled, 40, 'M2 : cellule [2,1,1,1] ecrite et validee (40)');
    ASSERT_TRUE(fb.TableComplete, 'M2 : table complete apres ecriture M2');
END_TEST

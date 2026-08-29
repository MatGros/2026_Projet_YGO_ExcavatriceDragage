SETUP
VAR
    fb : FB_CYCLETIME;
END_VAR
END_SETUP

TEST 'Premier cycle retourne la valeur de secours (pas de dt mesurable)'
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.004, 0.0001, 'premier appel : aucun dt reel disponible, DefaultValueS renvoye tel quel');
END_TEST

TEST 'Cycle suivant calcule le dt reel ecoule (ms->s)'
    fb(DEFAULTVALUES := 0.004);
    ADVANCE_TIME(10000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.01, 0.0001, '10ms ecoulees entre les 2 appels -> 0.01s calcule (pas la valeur de secours)');

    ADVANCE_TIME(25000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.025, 0.0001, 'dt variable d un cycle a l autre correctement mesure (25ms)');

    ADVANCE_TIME(1000000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 1.0, 0.0001, 'borne haute INCLUSE : dt = 1000ms = CST_MaxCycleDeltaMs -> dt reel publie (pas secours)');
END_TEST

TEST 'Delta nul (deux appels sans avance horloge) : borne basse -> valeur de secours'
    fb(DEFAULTVALUES := 0.004);
    ADVANCE_TIME(10000000);
    fb(DEFAULTVALUES := 0.004);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.004, 0.0001, 'dt = 0 : anti-zero conserve, DefaultValueS publie');
END_TEST

TEST 'Delta aberrant > plafond (5s, simule rebouclage TIME() / reprise) : borne haute -> secours, non latche'
    fb(DEFAULTVALUES := 0.004);
    ADVANCE_TIME(5000000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.004, 0.0001, 'dt > CST_MaxCycleDeltaMs : artefact non propage, DefaultValueS publie');

    ADVANCE_TIME(1001000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.004, 0.0001, 'borne haute EXCLUE : dt = 1001ms (juste au-dessus du plafond) -> DefaultValueS');

    ADVANCE_TIME(10000000);
    fb(DEFAULTVALUES := 0.004);
    ASSERT_NEAR(fb.CYCLETIMES, 0.01, 0.0001, 'scan suivant a dt nominal : le dt reel est de nouveau publie (secours non latche)');
END_TEST

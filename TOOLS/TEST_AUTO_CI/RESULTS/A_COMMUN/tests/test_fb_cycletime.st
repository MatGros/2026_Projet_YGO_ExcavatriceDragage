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
END_TEST

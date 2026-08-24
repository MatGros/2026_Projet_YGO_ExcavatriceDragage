SETUP
VAR
    fb : FB_FILTER;
END_VAR
END_SETUP

TEST 'Pass-through si TimeConst=0 (pas de lissage)'
    fb(VALUEIN := 10.0, TIMECONST := T#0MS, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.VALUEOUT, 10.0, 0.001, 'TimeConst=0 -> recopie directe de ValueIn');
END_TEST

TEST 'Pass-through si CycleTimeS=0 (temps de cycle invalide)'
    fb(VALUEIN := 10.0, TIMECONST := T#200MS, CYCLETIMES := 0.0);
    ASSERT_NEAR(fb.VALUEOUT, 10.0, 0.001, 'CycleTimeS=0 -> recopie directe de ValueIn (garde-fou division par zero)');
END_TEST

TEST 'Reponse PT1 : convergence progressive vers un echelon, pas instantanee'
    (* TimeConst=100ms, CycleTimeS=100ms -> Alpha = 0.1/(0.1+0.1) = 0.5 *)
    fb(VALUEIN := 10.0, TIMECONST := T#100MS, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.VALUEOUT, 5.0, 0.001, 'scan 1 : ValueOut = 0.5*10 + 0.5*0 = 5.0 (pas de saut brutal a 10)');

    fb(VALUEIN := 10.0, TIMECONST := T#100MS, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.VALUEOUT, 7.5, 0.001, 'scan 2 : ValueOut = 0.5*10 + 0.5*5 = 7.5 (memoire du scan precedent)');

    fb(VALUEIN := 10.0, TIMECONST := T#100MS, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.VALUEOUT, 8.75, 0.001, 'scan 3 : ValueOut = 0.5*10 + 0.5*7.5 = 8.75 (convergence exponentielle vers 10)');
END_TEST

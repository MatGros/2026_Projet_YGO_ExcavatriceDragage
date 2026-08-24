SETUP
VAR
    fb : FB_RAMP;
END_VAR
END_SETUP

TEST 'Accel : consigne progresse par pas de AccelRate*CycleTimeS vers la cible'
    fb(TARGET := 100.0, ACCELRATE := 50.0, DECELRATE := 200.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 5.0, 0.001, 'pas 1 : 0 -> 5.0 (50%/s * 0.1s), s eloigne de zero donc AccelRate');

    fb(TARGET := 100.0, ACCELRATE := 50.0, DECELRATE := 200.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 10.0, 0.001, 'pas 2 : 5.0 -> 10.0, meme taux tant que la cible n est pas atteinte');
END_TEST

TEST 'Decel : retour vers zero utilise DecelRate (taux different d Accel)'
    (* monte a 40% avec Accel *)
    fb(TARGET := 40.0, ACCELRATE := 50.0, DECELRATE := 10.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 5.0, 0.001, 'montee : AccelRate (50%/s)');
    fb(TARGET := 40.0, ACCELRATE := 50.0, DECELRATE := 10.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 10.0, 0.001, 'montee : toujours AccelRate, cible pas encore atteinte');

    (* cible ramenee a 0 : retour vers zero -> DecelRate, taux bien plus faible ici *)
    fb(TARGET := 0.0, ACCELRATE := 50.0, DECELRATE := 10.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 9.0, 0.001, 'retour vers zero : DecelRate (10%/s), pas de 1.0 seulement -- pas AccelRate');
END_TEST

TEST 'Atteinte de la cible : la rampe s arrete pile dessus, pas de depassement'
    fb(TARGET := 3.0, ACCELRATE := 50.0, DECELRATE := 200.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 3.0, 0.001, 'le pas (5.0) depasserait la cible (3.0) : clampe exactement dessus, pas de depassement');

    fb(TARGET := 3.0, ACCELRATE := 50.0, DECELRATE := 200.0, CYCLETIMES := 0.1);
    ASSERT_NEAR(fb.CURRENT, 3.0, 0.001, 'cible deja atteinte : reste stable, aucune oscillation autour de la cible');
END_TEST

TEST 'Garde-fou : une valeur Current deja hors plage (etat corrompu) reste bornee a +/-100'
    (* Simule un etat interne deja corrompu au-dela de la plage normalisee -- le FB doit se
       proteger lui-meme, pas seulement empecher d y entrer *)
    fb(TARGET := 500.0, ACCELRATE := 1000.0, DECELRATE := 1000.0, CYCLETIMES := 1.0);
    ASSERT_NEAR(fb.CURRENT, 100.0, 0.001, 'Target hors plage (500) et grand pas (1000%/s) : Current ne depasse jamais +100');
END_TEST

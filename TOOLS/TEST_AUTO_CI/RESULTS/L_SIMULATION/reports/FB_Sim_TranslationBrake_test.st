TEST 'TC-T300-BRK-010 Bobine mecanique et contact restent distincts'
VAR
    fb : FB_Sim_TranslationBrake;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReleaseCmd := TRUE;
    fb.OpenDelay_S := 0.10;
    fb.ContactDelay_S := 0.01;
    fb.CycleTime_S := 0.01;
    FOR i := 1 TO 9 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.CoilEnergized, 'Bobine immediate');
    ASSERT_FALSE(fb.MechanicallyOpen, 'Effet mecanique pas avant delai');
    fb();
    fb();
    ASSERT_TRUE(fb.MechanicallyOpen, 'Ouverture mecanique apres 100 ms');
    fb();
    ASSERT_TRUE(fb.ContactOpen, 'Contact apres effet mecanique');
END_TEST

TEST 'TC-T300-BRK-020 Serrage attend vitesse nulle'
VAR
    fb : FB_Sim_TranslationBrake;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReleaseCmd := TRUE;
    fb.OpenDelay_S := 0.0;
    fb.CycleTime_S := 0.01;
    fb();
    fb.ReleaseCmd := FALSE;
    fb.ActualFrequency_Hz := 2.0;
    FOR i := 1 TO 20 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.MechanicallyOpen, 'Frein reste ouvert tant que vitesse non nulle');
    fb.ActualFrequency_Hz := 0.0;
    FOR i := 1 TO 10 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.MechanicallyOpen, 'Frein serre apres 90 ms a vitesse nulle');
END_TEST

(* T300 P-A / C4 — rejeu EXACT du defaut terrain du 2026-09-04 (trace M3, 26,437 s) :
   contact frein ferme alors que le variateur retourne encore 10,00 Hz (State.ErrorId=64).
   La branche de FAUTE est explicite et le defaut de l'entree est FALSE : le chemin nominal
   reste celui de TC-T300-BRK-020, dont la garde 0,5 Hz est validee par la MEME trace
   (frein ouvert a 0,60 Hz a 16,04 s, ferme a 0,00 Hz a 16,16 s). *)
TEST 'TC-T300-BRK-040 Faute explicite : frein M3 se ferme a 10 Hz (rejeu trace 26,437 s)'
VAR
    fb : FB_Sim_TranslationBrake;
    i : INT;
END_VAR
    fb.Enable := TRUE;
    fb.ReleaseCmd := TRUE;
    fb.OpenDelay_S := 0.0;
    fb.CloseDelay_S := 0.09;
    fb.ContactDelay_S := 0.01;
    fb.CycleTime_S := 0.01;
    fb();
    ASSERT_TRUE(fb.MechanicallyOpen, 'Frein ouvert par la commande de desserrage');
    ASSERT_FALSE(fb.FaultCloseActive, 'Faute inactive par defaut');

    (* Scenario terrain : commande retiree ET variateur retournant encore 10,00 Hz. *)
    fb.ReleaseCmd := FALSE;
    fb.ActualFrequency_Hz := 10.0;
    FOR i := 1 TO 20 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.FaultCloseActive, 'Aucune faute injectee');
    ASSERT_TRUE(fb.MechanicallyOpen, 'NOMINAL conserve : frein OUVERT a 10,00 Hz (garde 0,5 Hz)');
    ASSERT_TRUE(fb.ContactOpen, 'NOMINAL conserve : contact toujours ouvert a 10,00 Hz');

    (* Injection explicite : fermeture hors vitesse nulle, APRES le delai de faute.
       Oracle discriminateur : si le delai de faute etait ignore, la faute serait appliquee
       des le 1er scan et l'assertion ci-dessous echouerait. *)
    fb.FaultCloseWhileRunning := TRUE;
    fb.FaultCloseDelay_S := 0.5;
    FOR i := 1 TO 4 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.FaultCloseActive, 'Faute NON appliquee avant FaultCloseDelay_S');
    ASSERT_TRUE(fb.MechanicallyOpen, 'Frein encore ouvert pendant le delai de faute');
    FOR i := 1 TO 60 DO
        fb();
    END_FOR;
    ASSERT_TRUE(fb.FaultCloseActive, 'Branche de faute appliquee apres le delai');
    ASSERT_FALSE(fb.CoilEnergized, 'Faute : bobine retombee (etat electrique coherent)');
    ASSERT_FALSE(fb.MechanicallyOpen, 'Faute : frein MECANIQUEMENT serre a 10,00 Hz');
    ASSERT_FALSE(fb.ContactOpen, 'Faute : contact frein ferme publie a 10,00 Hz');

    (* Retrait du stimulus : retour au chemin nominal, sans etat residuel. *)
    fb.FaultCloseWhileRunning := FALSE;
    fb();
    ASSERT_FALSE(fb.FaultCloseActive, 'Retrait du stimulus : faute retombee');
END_TEST

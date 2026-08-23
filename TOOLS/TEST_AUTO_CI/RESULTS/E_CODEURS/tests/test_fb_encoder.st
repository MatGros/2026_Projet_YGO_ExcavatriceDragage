(* Smoke test FB_Encoder -- PAS encore le catalogue AF-09 complet.
   Objectif unique pour l'instant : verifier que la chaine de compilation +
   le rapport HTML peuplent correctement les IN/OUT (structs ST_EncoderHw /
   ST_Encoder_Calib / ST_EncoderMeasurement, VAR_IN_OUT Calib) avant d'ecrire
   les vrais TC-P09. Ne pas ajouter de TC-P09 ici sans l'accord explicite --
   ce fichier sera remplace par le catalogue reel. *)

SETUP
VAR
    fb    : FB_Encoder;
    calib : ST_Encoder_Calib;
END_VAR
END_SETUP

TEST 'Smoke : Enable=FALSE neutralise (population rapport, pas un TC-P09)'
    fb(Enable := FALSE, Calib := calib);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_TRUE(fb.ENCODERFAULT, 'Enable=FALSE -> EncoderFault=TRUE (gate neutralisation)');
END_TEST

TEST 'Smoke : Enable=TRUE sans capteur (population rapport, pas un TC-P09)'
    fb(Enable := TRUE, Calib := calib);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE');
END_TEST

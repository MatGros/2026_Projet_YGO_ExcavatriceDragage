(* =======================================================================
   Automated Unit Test - FB_Translation_PositionDecoder
   ======================================================================= *)
TEST 'TC-P11-DEC-001 Decodage extremite Tremie (mot 11111) et Maintenance (00000)'
VAR
    fb : FB_Translation_PositionDecoder;
END_VAR
    (* Extremite Tremie : tous capteurs ON *)
    fb.SensorTremie := TRUE;
    fb.SensorPV := TRUE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    fb();
    ASSERT_TRUE(fb.LimitSwitchTremie, '11111 -> LimitSwitchTremie TRUE');
    ASSERT_FALSE(fb.LimitSwitchMaintenance, '11111 -> LimitSwitchMaintenance FALSE');
    ASSERT_FALSE(fb.Incoherent, '11111 -> Mot coherent');

    (* Extremite Maintenance : tous capteurs OFF *)
    fb.SensorTremie := FALSE;
    fb.SensorPV := FALSE;
    fb.SensorP2 := FALSE;
    fb.SensorP1 := FALSE;
    fb.SensorMaintenance := FALSE;
    fb();
    ASSERT_FALSE(fb.LimitSwitchTremie, '00000 -> LimitSwitchTremie FALSE');
    ASSERT_TRUE(fb.LimitSwitchMaintenance, '00000 -> LimitSwitchMaintenance TRUE');
    ASSERT_FALSE(fb.Incoherent, '00000 -> Mot coherent');
END_TEST

TEST 'TC-P11-DEC-002 Detection mot incoherente (came defectueuse / capteur colle)'
VAR
    fb : FB_Translation_PositionDecoder;
END_VAR
    (* Mot incoherent : Tremie ON mais PV OFF et P2 ON (came trouee) *)
    fb.SensorTremie := TRUE;
    fb.SensorPV := FALSE;
    fb.SensorP2 := TRUE;
    fb.SensorP1 := FALSE;
    fb.SensorMaintenance := FALSE;
    fb();
    ASSERT_TRUE(fb.Incoherent, 'Mot 10100 -> Incoherent TRUE');
END_TEST

TEST 'TC-P11-DEC-003 Mots de progression monotone intermediaires'
VAR
    fb : FB_Translation_PositionDecoder;
END_VAR
    (* Position P1 : 00011 *)
    fb.SensorTremie := FALSE;
    fb.SensorPV := FALSE;
    fb.SensorP2 := FALSE;
    fb.SensorP1 := TRUE;
    fb.SensorMaintenance := TRUE;
    fb();
    ASSERT_FALSE(fb.Incoherent, '00011 -> Coherent');
    ASSERT_TRUE(fb.TranslationPosP1, '00011 -> TranslationPosP1 TRUE');
    ASSERT_FALSE(fb.LimitSwitchTremie, '00011 -> Pas extremite');
    ASSERT_FALSE(fb.LimitSwitchMaintenance, '00011 -> Pas extremite');
END_TEST

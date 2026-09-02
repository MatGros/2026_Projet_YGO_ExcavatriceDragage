SETUP
VAR
    fb : FB_SyncContactor;
END_VAR
END_SETUP

TEST 'TC-P10-SYNC-01 Discordance Niveau 1 SafeStop'
    (* Etape 0 : Regime symetrique P2 monte *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_FALSE(fb.ContactorMismatch, 'Regime symetrique -> pas de discordance');
    ASSERT_EQ(fb.Diag.MismatchLevel, 0, 'MismatchLevel = 0');

    (* Etape 1 : Apparition discordance M1 passe P3 (K2) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := TRUE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_TRUE(fb.Diag.Step2Mismatch, 'Step2Mismatch detecte');

    (* Etape 2 : Filtrage debounce avant 500ms *)
    ADVANCE_TIME(250000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := TRUE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_FALSE(fb.ContactorMismatch, 'Pas de SafeStop avant debounce 500ms');

    (* Etape 3 : Declenchement SafeStop apres 500ms *)
    ADVANCE_TIME(260000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := TRUE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_TRUE(fb.ContactorMismatch, 'ContactorMismatch=TRUE apres 500ms');
    ASSERT_FALSE(fb.ContactorMismatchEscalated, 'Pas encore escalade');
    ASSERT_EQ(fb.Diag.MismatchLevel, 1, 'MismatchLevel = 1 (SafeStop)');
END_TEST

TEST 'TC-P10-SYNC-02 Escalade Niveau 2 PowerCutOff'
    (* Etablissement Niveau 1 *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ADVANCE_TIME(550000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_TRUE(fb.ContactorMismatch, 'Niveau 1 etabli');

    (* Persistance pendant 3s supplementaires -> Escalade *)
    ADVANCE_TIME(3050000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_TRUE(fb.ContactorMismatchEscalated, 'ContactorMismatchEscalated=TRUE apres 3s');
    ASSERT_EQ(fb.Diag.MismatchLevel, 2, 'MismatchLevel = 2 (PowerCutOff)');
END_TEST

TEST 'TC-P10-SYNC-03 Jog unitaire Inhibition'
    (* Jog M1 seul : M2 non commande et SyncEnable=FALSE *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ADVANCE_TIME(1000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE,
       BypassGlobal := FALSE);
    ASSERT_FALSE(fb.ContactorMismatch, 'Jog unitaire M1 -> Surveillance neutralisee');
    ASSERT_EQ(fb.Diag.MismatchLevel, 0, 'MismatchLevel = 0');
END_TEST

TEST 'TC-P10-SYNC-04 Bypass Global'
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := TRUE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := TRUE, Contactor2_M2 := FALSE,
       Contactor3_M1 := TRUE, Contactor3_M2 := FALSE,
       Contactor4_M1 := TRUE, Contactor4_M2 := FALSE,
       BypassGlobal := TRUE);
    ADVANCE_TIME(5000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := TRUE,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := TRUE,
       Contactor1_M1 := TRUE, Contactor1_M2 := FALSE,
       Contactor2_M1 := TRUE, Contactor2_M2 := FALSE,
       Contactor3_M1 := TRUE, Contactor3_M2 := FALSE,
       Contactor4_M1 := TRUE, Contactor4_M2 := FALSE,
       BypassGlobal := TRUE);
    ASSERT_FALSE(fb.ContactorMismatch, 'BypassGlobal -> Pas de mismatch');
    ASSERT_FALSE(fb.ContactorMismatchEscalated, 'BypassGlobal -> Pas d escalade');
    ASSERT_EQ(fb.Diag.MismatchLevel, 0, 'MismatchLevel = 0');
END_TEST

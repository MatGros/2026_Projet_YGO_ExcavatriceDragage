(* =======================================================================
   🧪 test_fb_winchsync.st — FB_WinchSync (TC-P10-014, 015, 016)
   ───────────────────────────────────────────────────────────────
   Fiche : DOC/AF/AF_Partie-10_Fonction_Winch/FB_WinchSync_v1.1.md
   Conventions : 1 appel fb() = 1 scan ; ADVANCE_TIME(10000000) entre les
   scans pour les fronts R_TRIG.
   Seuils (v1.1) : Warn = CfgSyncToleranceM=0.8m (instantané + latch, sans timer) ;
   Fault = CfgSyncCriticalToleranceM=0.50m (filtre 800ms) ; incohérence commande = 500ms.
   ======================================================================= *)

SETUP
VAR
    fb : FB_WinchSync;
END_VAR
END_SETUP

(* ── Remise à zéro commune : Enable=TRUE, Mode MAINT_N1 (SyncActive imposé), positions alignées ── *)

TEST 'TC-P10-014 Ecart M1/M2 > seuil Warn (0.8m) : SyncWarn instantane + latch, sans timer, pas de coupure'
    (* Scan 1 : regime nominal, positions alignees *)
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncActive, 'Mode MAINT_N1 -> SyncActive=TRUE');
    ASSERT_FALSE(fb.SyncDeviationWarn, 'Positions alignees -> pas de Warn');

    (* Scan 2 : ecart M1/M2 = 1.0m > 0.8m -> Warn instantane (sans timer) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 1.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncDeviationWarn, 'Ecart >0.8m -> SyncDeviationWarn instantane');
    ASSERT_TRUE(fb.SyncWarn, 'Ecart >0.8m -> SyncWarn IHM');
    ASSERT_TRUE(fb.Fault.Error, 'Ecart >0.8m -> Error');

    (* Scan 3 : cause disparue -> Warn LATCHE (reste actif sans timer) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncDeviationWarn, 'Cause disparue -> Warn latche conserve');

    (* Scan 4 : front Reset -> Warn leve *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := TRUE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_FALSE(fb.SyncDeviationWarn, 'Reset -> Warn leve');
    ASSERT_FALSE(fb.SyncWarn, 'Reset -> SyncWarn leve');
END_TEST

TEST 'TC-P10-014bis Ecart > seuil Fault (0.50m) : SyncDeviationFault filtre 800ms'
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);

    (* Scan 2 : ecart = 1.0m > 0.50m -> Fault filtre 800ms (pas immediat) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 1.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_FALSE(fb.SyncDeviationFault, 'Avant 800ms : pas de Fault (filtre transitoire)');

    (* Scan 3 : apres 800ms -> SyncDeviationFault *)
    ADVANCE_TIME(800000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 1.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncDeviationFault, 'Ecart >0.50m 800ms -> SyncDeviationFault');
    ASSERT_TRUE(fb.SyncWarn, 'Fault -> SyncWarn');
END_TEST

TEST 'TC-P10-015 Incoherence commande (bit1) : discordance contacteurs 500ms -> SyncWarn'
    (* Scan 1 : regime nominal, commandes identiques *)
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE);
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0,
       RelayFwdM1 := TRUE, RelayFwdM2 := TRUE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE);
    ASSERT_FALSE(fb.SyncWarn, 'Commandes identiques -> pas de Warn');

    (* Scan 2 : discordance RelayFwdM1=TRUE vs RelayFwdM2=FALSE -> filtre 500ms *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE);
    ASSERT_FALSE(fb.SyncWarn, 'Avant 500ms : pas encore de Warn (filtre)');

    (* Scan 3 : apres 500ms -> ContactorMismatch -> SyncWarn *)
    ADVANCE_TIME(500000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0,
       RelayFwdM1 := TRUE, RelayFwdM2 := FALSE,
       RelayRevM1 := FALSE, RelayRevM2 := FALSE,
       Contactor1_M1 := TRUE, Contactor1_M2 := TRUE,
       Contactor2_M1 := FALSE, Contactor2_M2 := FALSE,
       Contactor3_M1 := FALSE, Contactor3_M2 := FALSE,
       Contactor4_M1 := FALSE, Contactor4_M2 := FALSE);
    ASSERT_TRUE(fb.SyncWarn, 'Discordance contacteurs 500ms -> SyncWarn');
    ASSERT_TRUE(fb.Fault.Error, 'Discordance -> Error');
END_TEST

TEST 'TC-P10-016 Couplage croise : SyncActive=TRUE conditionne la coupure M2 au meme scan'
    (* (essai site — stub) : la coupure croisee reelle (SafeStopM2_Active := SafeStopM2_Raw OR
       (SyncActive AND SafeStopM1_Raw)) est cablee dans PRG_04_Treuils_Benne.st, pas dans ce FB.
       On verifie ici la brique amont : SyncActive=TRUE (condition du couplage) selon le mode. *)
    (* Mode MAINT_N1 -> SyncActive impose TRUE *)
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N1, SyncEnable := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncActive, 'MAINT_N1 -> SyncActive=TRUE (couplage actif)');

    (* Mode MAINT_N2 -> SyncActive = SyncEnable (pilotable) *)
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, SyncEnable := FALSE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_FALSE(fb.SyncActive, 'MAINT_N2 + SyncEnable=FALSE -> SyncActive=FALSE');
    ADVANCE_TIME(10000000);
    fb(Enable := TRUE, Reset := FALSE, Mode := E_Mode.MAINT_N2, SyncEnable := TRUE,
       CablePosM1 := 0.0, CablePosM2 := 0.0,
       HomedAndReliableM1 := TRUE, HomedAndReliableM2 := TRUE,
       CfgSyncToleranceM := 0.8, CfgSyncCriticalToleranceM := 0.50, ActiveOffsetM := 0.0);
    ASSERT_TRUE(fb.SyncActive, 'MAINT_N2 + SyncEnable=TRUE -> SyncActive=TRUE');
END_TEST

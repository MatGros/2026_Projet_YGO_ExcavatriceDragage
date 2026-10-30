(* T417 — scénario d'intégration M3 isolé du test M2 historique.
   Il rejoue la chronologie de commande établie dans le code source :
   arrêt de demande avec frein maintenu desserré, puis demande de serrage.
   Pente nulle : ce test ne calibre ni ne reproduit un déplacement terrain. *)
SETUP
VAR
    FB_Bench : FB_SimBench;
    RawPosM1 : UDINT := 0;
    RawPosM2 : UDINT := 0;
END_VAR
END_SETUP

TEST 'T417-INT-010 M3 : rampe puis frein mecanique suivant la chronologie AX14-AX15'
VAR
    i : INT;
    PositionAfterStop_M : REAL;
END_VAR
    (* Repli deterministe P1, puis marche M3 : la DI frein ne doit pas anticiper. *)
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    FOR i := 1 TO 30 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := TRUE, M3_ReqMaintenance := FALSE,
                 M3_SpeedCmd_Pct := 20.0, M3_BrakeCmd := TRUE,
                 SimM3SpeedFactor := 1.0, SimM3Slope_Mps2 := 0.0,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    END_FOR;
    ASSERT_TRUE(FB_Bench.Translation.M3_BrakeIsOpen_DI,
                'Commande de desserrage maintenue : le contact frein finit ouvert');
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0087,
              'La frequence active publie le status de marche');

    (* AX14 annule la demande ; avant AX15, la commande frein reste desserree. *)
    FOR i := 1 TO 80 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
                 M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := TRUE,
                 SimM3SpeedFactor := 1.0, SimM3Slope_Mps2 := 0.0,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    END_FOR;
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0080,
              'La rampe a atteint l arret avant la fermeture mecanique');
    ASSERT_TRUE(FB_Bench.Translation.M3_BrakeIsOpen_DI,
                'Le frein reste ouvert tant que l automate le commande desserre');
    PositionAfterStop_M := FB_Bench.M3ObsPositionTrue_M;

    (* AX15 retire le desserrage : le contact ne peut pas retomber au premier scan. *)
    FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
             M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
             SimM3SpeedFactor := 1.0, SimM3Slope_Mps2 := 0.0,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Translation.M3_BrakeIsOpen_DI,
                'Le delai mecanique interdit une fermeture du contact au premier scan');
    FOR i := 1 TO 20 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
                 M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
                 SimM3SpeedFactor := 1.0, SimM3Slope_Mps2 := 0.0,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    END_FOR;
    ASSERT_FALSE(FB_Bench.Translation.M3_BrakeIsOpen_DI,
                 'Apres le delai mecanique, le contact frein publie ferme');
    ASSERT_EQ(FB_Bench.M3ObsPositionTrue_M, PositionAfterStop_M,
              'Pente nulle : aucune derive inventee apres l arret variateur');
END_TEST

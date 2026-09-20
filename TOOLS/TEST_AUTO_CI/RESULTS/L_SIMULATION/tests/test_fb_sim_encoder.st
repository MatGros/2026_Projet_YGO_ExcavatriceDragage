(* =======================================================================
   Automated Unit Test - FB_Sim_Encoder
   ======================================================================= *)
TEST 'TC-P13-ENC-001 Enable FALSE conserve la valeur passee par VAR_IN_OUT'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
END_VAR
    fb.Enable := FALSE;
    fb.StepNumber := 3;
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 1000, 'Enable FALSE -> RawPosOut conserve la valeur persistee');
END_TEST

TEST 'TC-P13-ENC-002 Simulation incrementation comptage en montee'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
    i      : INT;
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE; (* Sens montee *)
    fb.RelayRev := FALSE;
    fb.StepNumber := 3;
    
    FOR i := 1 TO 10 DO
        fb(RawPos := rawPos);
    END_FOR;
    
    ASSERT_TRUE(fb.RawPosOut > 1000, 'RelayFwd TRUE -> RawPosOut augmente');
END_TEST

TEST 'TC-P13-034 SpeedReportTauS=0.0 conserve le saut instantane historique (non-regression)'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
    i      : INT;
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE;
    fb.StepNumber := 5;
    fb.SpeedReportTauS := 0.0;
    FOR i := 1 TO 5 DO
        fb(RawPos := rawPos);
    END_FOR;
    fb.RelayFwd := FALSE;
    fb.CoastDistanceM := 0.0;
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawSpdOut, 0, 'Tau=0.0, coupure sans roulis -> vitesse rapportee tombe a 0 des le meme scan');
END_TEST

TEST 'TC-P13-035 SpeedReportTauS>0 fait decroitre RawSpdOut sur plusieurs scans (fidelite AX10, T316)'
VAR
    fb        : FB_Sim_Encoder;
    rawPos    : UDINT := 1000;
    i         : INT;
    spdAtCut  : DINT;
    spdNext   : DINT;
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE;
    fb.StepNumber := 5;
    fb.SpeedReportTauS := 0.15; (* mirror tau M3 identifie sur trace, SYNTHETIQUE treuil *)
    fb.CoastDistanceM := 0.0;
    FOR i := 1 TO 20 DO
        fb(RawPos := rawPos); (* stabilise ReportedSpeedMps a la vitesse palier 5 *)
    END_FOR;
    fb.RelayFwd := FALSE;
    fb(RawPos := rawPos);
    spdAtCut := fb.RawSpdOut;
    fb(RawPos := rawPos);
    spdNext := fb.RawSpdOut;
    ASSERT_TRUE(spdAtCut > 0, 'Coupure relais : vitesse rapportee encore non nulle au 1er scan (pas de saut instantane)');
    ASSERT_TRUE(spdNext < spdAtCut, 'Vitesse rapportee decroit scan apres scan (rampe continue, pas un escalier)');
    ASSERT_TRUE(spdNext > 0, 'Decroissance progressive : pas encore a zero au 2e scan');
END_TEST

TEST 'TC-P13-031 PresetCmd applique PresetValue apres PresetLatencyCycles, mouvement gele pendant la latence'
VAR
    fb     : FB_Sim_Encoder;
    rawPos : UDINT := 1000;
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE; (* commande de mouvement maintenue pendant le preset *)
    fb.StepNumber := 3;
    fb.PresetLatencyCycles := 2;
    fb.PresetValue := 500000;
    fb.PresetCmd := TRUE;
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 1000, 'Pendant la latence : position brute conservee, mouvement gele');
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 1000, 'Latence non ecoulee : position encore conservee');
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 500000, 'Latence ecoulee : PresetValue charge (priorite sur Fwd/Rev)');
END_TEST

TEST 'TC-P13-032 Le comptage descend de facon continue et franchit 0 sans se figer (butee silencieuse supprimee)'
VAR
    fb        : FB_Sim_Encoder;
    rawPos    : UDINT := 41; (* 41 pts : exactement un pas de descente au palier 1 -> atteint 0 au 1er scan *)
    wrapAt41  : UDINT := 4294967255; (* 2^32 - 41 : -41 pts en representation signee 32 bits *)
    wrapAt82  : UDINT := 4294967214; (* 2^32 - 82 : -82 pts *)
END_VAR
    fb.Enable := TRUE;
    fb.RelayRev := TRUE;
    fb.StepNumber := 1; (* 1,0 m/s -> 1,0 x 4096 x 0,010 = 40,96 pts/scan, arrondi a 41 *)
    fb(RawPos := rawPos);
    rawPos := fb.RawPosOut; (* le caller conserve la memoire persistante du codeur *)
    ASSERT_EQ(fb.RawPosOut, 0, 'Un pas de descente amene le comptage exactement a 0 (point de passage)');
    fb(RawPos := rawPos);
    rawPos := fb.RawPosOut;
    ASSERT_TRUE(fb.RawPosOut <> 0, 'Scan suivant : le comptage franchit 0 au lieu de s y figer');
    ASSERT_EQ(fb.RawPosOut, wrapAt41, 'Comptage = -41 pts (aucune borne a 0)');
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, wrapAt82, 'Le comptage continue de decroitre : -82 pts');
END_TEST

TEST 'TC-P13-036 Comptage a 0 sous commande de descente : le scan suivant ne maintient pas 0'
VAR
    fb       : FB_Sim_Encoder;
    rawPos   : UDINT := 0; (* etat exact du blocage M2 du 2026-09-20 *)
    wrapAt41 : UDINT := 4294967255; (* 2^32 - 41 : -41 pts *)
END_VAR
    fb.Enable := TRUE;
    fb.RelayRev := TRUE;
    fb.StepNumber := 1;
    fb(RawPos := rawPos);
    rawPos := fb.RawPosOut;
    ASSERT_EQ(fb.RawPosOut, wrapAt41, 'Comptage a 0 + descente : passe a -41 pts, ne reste pas bloque a 0');
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 4294967214, 'Le comptage poursuit sa descente au scan suivant (-82 pts)');
END_TEST

TEST 'TC-P13-037 Garde de plage : saturation signalee, comptage borne, aucune vitesse publiee'
VAR
    fb         : FB_Sim_Encoder;
    posLimit   : UDINT := 1073741824; (* +2^30 pts : limite de plage du modele *)
    negLimit   : UDINT := 3221225472; (* 2^32 - 2^30 : -2^30 pts en signe *)
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE;
    fb.StepNumber := 5; (* palier 5 : 82 pts/scan *)
    fb(RawPos := posLimit);
    ASSERT_TRUE(fb.CountSaturated, 'Comptage hors plage haute : CountSaturated TRUE (saturation signalee)');
    ASSERT_EQ(fb.RawPosOut, posLimit, 'Comptage borne a la limite de plage (aucun rebouclage UDINT)');
    ASSERT_EQ(fb.RawSpdOut, 0, 'Position bornee : aucune vitesse de mouvement publiee (coherence)');
    fb.RelayFwd := FALSE;
    fb.RelayRev := TRUE;
    fb(RawPos := negLimit);
    ASSERT_TRUE(fb.CountSaturated, 'Comptage hors plage basse : CountSaturated TRUE');
    ASSERT_EQ(fb.RawPosOut, negLimit, 'Comptage borne a la limite basse (aucun rebouclage UDINT)');
    ASSERT_EQ(fb.RawSpdOut, 0, 'Saturation basse : vitesse de mouvement purge');
END_TEST

TEST 'TC-P13-038 Comptage negatif : la montee ramene vers 0 puis au-dela (continuite bidirectionnelle)'
VAR
    fb      : FB_Sim_Encoder;
    rawPos  : UDINT := 4294967255; (* 2^32 - 41 : -41 pts *)
END_VAR
    fb.Enable := TRUE;
    fb.RelayFwd := TRUE;
    fb.RelayRev := FALSE;
    fb.StepNumber := 1;
    fb(RawPos := rawPos);
    rawPos := fb.RawPosOut;
    ASSERT_EQ(fb.RawPosOut, 0, 'Depuis -41 pts : un pas de montee ramene exactement a 0');
    fb(RawPos := rawPos);
    ASSERT_EQ(fb.RawPosOut, 41, 'Le scan suivant poursuit au-dela de 0 (aucune butee dans les deux sens)');
END_TEST


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

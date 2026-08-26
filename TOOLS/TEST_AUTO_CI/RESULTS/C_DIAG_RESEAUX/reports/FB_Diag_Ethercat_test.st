SETUP
VAR
    FB : FB_Diag_Ethercat;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Diagnostic desactive *)
    FB(Enable := FALSE, MasterStateRaw := 8, VariateurStateRaw := 8,
       EncoderM1StateRaw := 8, EncoderM2StateRaw := 8);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State=DISABLED');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Diagnostic actif *)
    FB(Enable := TRUE, MasterStateRaw := 8, VariateurStateRaw := 8,
       EncoderM1StateRaw := 8, EncoderM2StateRaw := 8,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE');
    ASSERT_EQ(FB.State, E_Diag_State.READY, 'State=READY');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, MasterStateRaw := 8, VariateurStateRaw := 8,
       EncoderM1StateRaw := 8, EncoderM2StateRaw := 8);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.State, E_Diag_State.DISABLED, 'State retombe a DISABLED');
END_TEST

TEST 'TC-P12-010 EtherCAT : surveillance maitre et esclaves'
    FB(Enable := TRUE, MasterStateRaw := 8, VariateurStateRaw := 8,
       EncoderM1StateRaw := 8, EncoderM2StateRaw := 8,
       SimBypassActive := FALSE, NetworkBypassActive := FALSE);
    ASSERT_TRUE(FB.Ready, 'EtherCAT pret');
    ASSERT_FALSE(FB.Error, 'Pas d erreur');
END_TEST

SETUP
VAR
    FB : FB_Modes;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1);
    ASSERT_FALSE(FB.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'Enable=FALSE -> Mode force DISABLE');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode selectionne MAINT_N1');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB(Enable := FALSE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1);
    ASSERT_FALSE(FB.Ready, 'Coupure -> Ready retombe a FALSE');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'Coupure -> Mode retombe a DISABLE');
END_TEST

TEST 'TC-P05-010 Modes : selection et autorisation mode Maintenance N1'
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'FB Modes pret');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode MAINT_N1 valide');
END_TEST

(* =========================================================================
   AF-05 — Modes & Maintenance : TC-P05-001..006 (catalogue AF_Partie-05 §1)
   ========================================================================= *)

TEST 'TC-P05-001 Modes machine restreints : DISABLE, MAINT_N1, MAINT_N2, SEMI_AUTO'
    (* DISABLE *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.DISABLE,
       EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'SelMode DISABLE -> Auth.Mode DISABLE');

    (* MAINT_N1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'SelMode MAINT_N1 -> Auth.Mode MAINT_N1');

    (* MAINT_N2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N2, 'SelMode MAINT_N2 -> Auth.Mode MAINT_N2');

    (* SEMI_AUTO *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SelMode SEMI_AUTO -> Auth.Mode SEMI_AUTO');
END_TEST

TEST 'TC-P05-002 Mode nominal : joystick pilote M1+M2 conjointement (select force 0 hors MAINT_N2)'
    (* En SEMI_AUTO, meme si JoystickWinchSelectRequest=1, le select arbitre reste 0 (couple M1+M2) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       JoystickWinchSelectRequest := 1, EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 0, 'SEMI_AUTO -> select joystick force 0 (M1+M2 couples)');

    (* En MAINT_N1, le select est transmis tel quel *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       JoystickWinchSelectRequest := 1, EncoderFaultPresent := FALSE);
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 1, 'MAINT_N1 -> select joystick transmis (1=M1)');
END_TEST

TEST 'TC-P05-003 Mode MAINT_N2 M1 seul : M2 bloque, frein serre'
    (* Selection M1 seul en MAINT_N2 : inhibition M1 active, M2 non inhibe, select = 1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := TRUE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Auth.InhibitM1, 'MAINT_N2 + InhibitM1 -> InhibitM1=TRUE');
    ASSERT_FALSE(FB.Auth.InhibitM2, 'MAINT_N2 + InhibitM1 -> InhibitM2=FALSE');
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 1, 'MAINT_N2 -> select joystick = 1 (M1 seul)');
END_TEST

TEST 'TC-P05-004 Refus mode SEMI_AUTO si codeurs invalides'
    (* SEMI_AUTO + defaut codeur -> bascule MAINT_N1 (refus) + defaut latche *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'SEMI_AUTO + defaut codeur -> bascule MAINT_N1 (refus)');
    ASSERT_TRUE(FB.Fault.Latched, 'Refus semi-auto -> defaut latche');
    ASSERT_FALSE(FB.Ready, 'Defaut latche -> Ready=FALSE');
END_TEST

TEST 'TC-P05-005 Limite legale = blocage exploitation, pas safety (aucune sortie PowerCutOff)'
    (* FB_Modes ne produit aucune sortie de coupure puissance : le bus Auth ne porte ni
       PowerCutOff ni SafeStop (structural). En SEMI_AUTO nominal, Ready=TRUE sans blocage safety. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Ready, 'SEMI_AUTO nominal -> Ready=TRUE (aucun blocage safety)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'Mode SEMI_AUTO arbitre');
    (* (essai d architecture - validation partielle boite noire) : l interface VAR_OUTPUT de
       FB_Modes = Ready, Fault, Auth uniquement -- aucune sortie PowerCutOff/SafeStop. *)
END_TEST

TEST 'TC-P05-006 Pas de redemarrage automatique apres defaut : Reset + nouvel ordre requis'
    (* Defaut semi-auto *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := TRUE);
    ASSERT_TRUE(FB.Fault.Latched, 'Defaut latche');
    ASSERT_FALSE(FB.Ready, 'Ready=FALSE sous defaut');

    (* La cause disparait mais le defaut reste latche (pas de redemarrage auto) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE);
    ASSERT_TRUE(FB.Fault.Latched, 'Cause disparue sans Reset -> defaut reste latche');
    ASSERT_FALSE(FB.Ready, 'Pas de redemarrage auto : Ready reste FALSE');

    (* Reset front acquitte *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE);
    ASSERT_FALSE(FB.Fault.Latched, 'Reset front -> defaut acquitte');
    ASSERT_TRUE(FB.Ready, 'Apres Reset -> Ready=TRUE');
END_TEST

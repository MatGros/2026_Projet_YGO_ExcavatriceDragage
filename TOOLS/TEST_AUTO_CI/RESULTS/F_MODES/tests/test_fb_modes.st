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
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
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
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_TRUE(FB.Ready, 'FB Modes pret');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'Mode MAINT_N1 valide');
END_TEST

(* =========================================================================
   AF-05 — Modes & Maintenance : TC-P05-001..006 (catalogue AF_Partie-05 §1)
   ========================================================================= *)

TEST 'TC-P05-001 Modes machine restreints : DISABLE, MAINT_N1, MAINT_N2, SEMI_AUTO'
    (* DISABLE *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.DISABLE,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.DISABLE, 'SelMode DISABLE -> Auth.Mode DISABLE');

    (* MAINT_N1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'SelMode MAINT_N1 -> Auth.Mode MAINT_N1');

    (* MAINT_N2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N2, 'SelMode MAINT_N2 -> Auth.Mode MAINT_N2');

    (* SEMI_AUTO *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SelMode SEMI_AUTO -> Auth.Mode SEMI_AUTO');
END_TEST

TEST 'TC-P05-002 Mode nominal : joystick pilote M1+M2 conjointement (select force 0 hors MAINT_N2)'
    (* En SEMI_AUTO, meme si JoystickWinchSelectRequest=1, le select arbitre reste 0 (couple M1+M2) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       JoystickWinchSelectRequest := 1, EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 0, 'SEMI_AUTO -> select joystick force 0 (M1+M2 couples)');

    (* En MAINT_N1, le select est transmis tel quel *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N1,
       JoystickWinchSelectRequest := 1, EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 1, 'MAINT_N1 -> select joystick transmis (1=M1)');
END_TEST

TEST 'TC-P05-003 Mode MAINT_N2 M1 seul : M2 bloque, frein serre'
    (* Selection M1 seul en MAINT_N2 : inhibition M1 active, M2 non inhibe, select = 1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := TRUE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_TRUE(FB.Auth.InhibitM1, 'MAINT_N2 + InhibitM1 -> InhibitM1=TRUE');
    ASSERT_FALSE(FB.Auth.InhibitM2, 'MAINT_N2 + InhibitM1 -> InhibitM2=FALSE');
    ASSERT_EQ(FB.Auth.JoystickWinchSelectArbitrated, 1, 'MAINT_N2 -> select joystick = 1 (M1 seul)');
END_TEST

TEST 'TC-P05-003bis Toggle inhibition : re-appui du meme bouton leve l inhibition'
    (* Front M1 -> inhibe M1, leve M2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := TRUE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_TRUE(FB.Auth.InhibitM1, 'Front M1 -> InhibitM1=TRUE');
    ASSERT_FALSE(FB.Auth.InhibitM2, 'Front M1 -> InhibitM2=FALSE');

    (* Relache M1 : l inhibition reste (latch) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := FALSE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_TRUE(FB.Auth.InhibitM1, 'Relache M1 -> InhibitM1 reste TRUE (latch)');

    (* Re-appui M1 -> toggle off : retour etat normal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := TRUE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_FALSE(FB.Auth.InhibitM1, 'Re-appui M1 -> InhibitM1=FALSE (toggle off)');
    ASSERT_FALSE(FB.Auth.InhibitM2, 'Re-appui M1 -> InhibitM2=FALSE');
END_TEST

TEST 'TC-P05-003ter Toggle inhibition : bascule M1 -> M2 par appui M2, puis re-appui M2 leve'
    (* Front M1 -> inhibe M1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := TRUE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_TRUE(FB.Auth.InhibitM1, 'Front M1 -> InhibitM1=TRUE');

    (* Relache M1 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := FALSE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);

    (* Front M2 -> leve M1, inhibe M2 (bascule) *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := FALSE, InhibitM2Request := TRUE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_FALSE(FB.Auth.InhibitM1, 'Front M2 -> InhibitM1=FALSE (bascule)');
    ASSERT_TRUE(FB.Auth.InhibitM2, 'Front M2 -> InhibitM2=TRUE');

    (* Relache M2 *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := FALSE, InhibitM2Request := FALSE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);

    (* Re-appui M2 -> toggle off : retour etat normal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.MAINT_N2,
       InhibitM1Request := FALSE, InhibitM2Request := TRUE, JoystickWinchSelectRequest := 1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_FALSE(FB.Auth.InhibitM2, 'Re-appui M2 -> InhibitM2=FALSE (toggle off)');
    ASSERT_FALSE(FB.Auth.InhibitM1, 'Re-appui M2 -> InhibitM1=FALSE');
END_TEST

TEST 'TC-P05-004 SEMI_AUTO selectionnable sous defaut codeur (cycle non pret, non-bloquant)'
    (* T207 : le defaut codeur ne refuse plus la SELECTION SEMI_AUTO ; le mode reste
       selectionne, le cycle ne tourne pas (coupure en aval FB_Safety_Winch). *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := TRUE, MachineHomed := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SEMI_AUTO + defaut codeur -> mode reste SEMI_AUTO (T207)');
    ASSERT_TRUE(FB.Fault.Error, 'Defaut codeur -> diagnostic live visible');
    ASSERT_FALSE(FB.Fault.Latched, 'Diagnostic non-bloquant -> pas de latch');
    ASSERT_TRUE(FB.Ready, 'Pas de latch -> Ready reste TRUE');
END_TEST

TEST 'TC-P05-004bis SEMI_AUTO selectionnable sans reference machine (cycle non pret)'
    (* T207 : l absence de reference machine ne refuse plus la SELECTION SEMI_AUTO. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := FALSE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SEMI_AUTO sans reference -> mode reste SEMI_AUTO (T207)');
    ASSERT_TRUE(FB.Fault.Error, 'Reference incomplete -> diagnostic live visible');
    ASSERT_TRUE(FB.Ready, 'Diagnostic non-bloquant -> Ready reste TRUE');
END_TEST

TEST 'TC-P05-005 Limite legale = blocage exploitation, pas safety (aucune sortie PowerCutOff)'
    (* FB_Modes ne produit aucune sortie de coupure puissance : le bus Auth ne porte ni
       PowerCutOff ni SafeStop (structural). En SEMI_AUTO nominal, Ready=TRUE sans blocage safety. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_TRUE(FB.Ready, 'SEMI_AUTO nominal -> Ready=TRUE (aucun blocage safety)');
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'Mode SEMI_AUTO arbitre');
    (* (essai d architecture - validation partielle boite noire) : l interface VAR_OUTPUT de
       FB_Modes = Ready, Fault, Auth uniquement -- aucune sortie PowerCutOff/SafeStop. *)
END_TEST

TEST 'TC-P05-006 SEMI_AUTO selectionnable sous AU (PowerContactorEngaged=FALSE)'
    (* T207 : la selection SEMI_AUTO n est plus repliee vers MAINT_N1 sous AU. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SEMI_AUTO sous AU -> mode reste SEMI_AUTO (T207)');
    ASSERT_TRUE(FB.Ready, 'Selection sous AU -> Ready reste TRUE (mouvement coupe en aval)');
END_TEST

TEST 'TC-P05-007 Modes N1/N2/SEMI_AUTO selectionnables sous AU (aucun repli)'
    (* T207 : les trois modes restent selectionnables sous AU, sans repli automatique.
       Sous AU, les treuils sont a l arret mecanique confirme (contacteurs retombes,
       freins serres) -> la bascule N1/N2/SEMI_AUTO est autorisee. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'MAINT_N1 sous AU -> mode reste MAINT_N1');

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.MAINT_N2,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N2, 'MAINT_N2 sous AU -> mode reste MAINT_N2');

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'SEMI_AUTO sous AU -> mode reste SEMI_AUTO');
END_TEST

TEST 'TC-P05-008 Bascule de mode sous AU (treuils a l arret mecanique)'
    (* T207 : on peut changer de mode sous AU si les treuils sont a l arret mecanique confirme. *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.MAINT_N1,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.MAINT_N1, 'MAINT_N1 sous AU');

    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE, SelMode := E_Mode.SEMI_AUTO,
       EncoderFaultPresent := FALSE, MachineHomed := TRUE,
       M1ContactorsReleased := TRUE, M2ContactorsReleased := TRUE);
    ASSERT_EQ(FB.Auth.Mode, E_Mode.SEMI_AUTO, 'Bascule MAINT_N1 -> SEMI_AUTO sous AU (treuils arretes)');
END_TEST

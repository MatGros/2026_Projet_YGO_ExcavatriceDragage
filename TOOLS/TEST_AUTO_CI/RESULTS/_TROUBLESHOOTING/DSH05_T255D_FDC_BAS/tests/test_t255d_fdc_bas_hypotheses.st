(* =======================================================================
   T255-D — Reproduction exploratoire : mecanisme (A) du brief CC01
   -----------------------------------------------------------------------
   HORS CI OFFICIEL (dossier _TROUBLESHOOTING jetable, skill troubleshooting
   section 4ter). Cas FB_Hmi_BannerFormatter avec registre ephemere : les 13
   sources absentes du dossier 5_ASSISTANCE_DRAGAGE sont retirees et
   E_CycleDepthStopMode.st est ajoutee (entree officielle cassee, decision D4).

   Question mesuree : un defaut LATCHE et BLOQUANT, actif, disparait-il du
   carrousel quand un flag de validite materielle passe a FALSE (mecanisme A) ?

   MecaB (bit8 = 16#0100, Latching := TRUE — FB_Safety_Winch.st:339-350) est un
   defaut bloquant : il entre dans CausesSafeStop et CausesPowerCutOff.
   Son entree carrousel est gardee par EncM1Valid (FB_Hmi_BannerFormatter.st:829).

   A1 : materiel sain            -> la cause doit etre visible
   A2 : meme cause + codeur M1 perdu -> la cause disparait, remplacee par le parent ECAT
   ======================================================================= *)

SETUP
VAR
    FB_Banner : FB_Hmi_BannerFormatter;
    WinchM1Safety : ST_SafetyWinch;
    WinchM2Safety : ST_SafetyWinch;
    TranslationSafety : ST_SafetyTranslation;
    NetDiag : ST_NetworkDiagHMI;
END_VAR

NetDiag.InputModules.LocalDigitalIoOk := TRUE;
NetDiag.InputModules.Vh0800EndOk := TRUE;
NetDiag.InputModules.Vh0808EtpOk := TRUE;
NetDiag.InputModules.Vh0008ErOk := TRUE;
NetDiag.InputModules.Vh0008Er1Ok := TRUE;
NetDiag.BusCanOpen.Operational := TRUE;
NetDiag.Joystick.Operational := TRUE;
NetDiag.BusEthercat.Operational := TRUE;
NetDiag.EncoderM1.Operational := TRUE;
NetDiag.EncoderM2.Operational := TRUE;
NetDiag.VariateurM3.Operational := TRUE;
END_SETUP

TEST 'T255D-HYP-A1 MecaB latche et bloquant, materiel sain : la cause est visible'
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);

    WinchM1Safety.Error := TRUE;
    WinchM1Safety.ErrorId := 16#0100;      (* bit8 = MecaB *)
    WinchM1Safety.LatchedId := 16#0100;
    WinchM1Safety.ErrorMecaB := TRUE;

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm,
                '[T255D-HYP-A1] materiel sain : le defaut bloquant MecaB doit etre au carrousel');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text,
              '1/1 [M1] ErrorID:09 - MecaB - arret non confirme apres stop',
              '[T255D-HYP-A1] libelle attendu du defaut MecaB');
END_TEST

TEST 'T255D-HYP-A2 meme defaut + codeur M1 perdu : cause BLOQUANTE masquee par le parent ECAT'
    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);
    ADVANCE_TIME(5000000000);

    WinchM1Safety.Error := TRUE;
    WinchM1Safety.ErrorId := 16#0100;      (* bit8 = MecaB, toujours ACTIF *)
    WinchM1Safety.LatchedId := 16#0100;
    WinchM1Safety.ErrorMecaB := TRUE;
    NetDiag.EncoderM1.Operational := FALSE; (* EncM1Valid passe a FALSE *)

    FB_Banner(Enable := TRUE, CurrentMode := E_Mode.MAINT_N1,
              EmergencyChainClosed := TRUE, PowerContactorEngaged := TRUE,
              WinchM1Safety := WinchM1Safety, WinchM2Safety := WinchM2Safety,
              Network := NetDiag);

    ASSERT_TRUE(FB_Banner.Banner.AlarmBanner.HasAlarm,
                '[T255D-HYP-A2] le parent materiel reste affiche : le bandeau nest pas vide');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Count, 1,
              '[T255D-HYP-A2] une seule alarme : le parent ECAT seulement');
    ASSERT_EQ(FB_Banner.Banner.AlarmBanner.Text,
              '1/1 [M1] Codeur absolu COD1 non detecte (ECAT)',
              '[T255D-HYP-A2] la cause BLOQUANTE MecaB est absente : masquee par EncM1Valid');
END_TEST

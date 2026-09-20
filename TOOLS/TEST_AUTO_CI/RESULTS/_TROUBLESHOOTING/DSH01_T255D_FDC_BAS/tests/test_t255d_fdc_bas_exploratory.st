(* =======================================================================
   T255-D — Reproduction exploratoire : AnyFault allume, bandeau muet
   -----------------------------------------------------------------------
   HORS CI OFFICIEL (dossier _TROUBLESHOOTING jetable, skill troubleshooting
   section 4ter). But : reproduire par EXECUTION le symptome terrain MES avant
   tout correctif. Un TEST par preuve (le harnais consigne un seul echec par test).

   Canal : harnais d'integration officiel FB_TestHarness_PRG_07 (PRG_07_Supervision),
   qui execute le formateur de bandeau avec les bus d'entree PRG_02/03/04/05.
   La cause est injectee par WinchData.WinchM1Safety / WinchM2Safety, exactement
   comme PRG_04 la publie.

   Fait de code vise :
     FB_Safety_Winch.st:318-325   instCauses[6] (bit6 = 16#0040), cause LIVE
                                  'Limite basse cable atteinte'
     FB_FaultCore.st:49-57        Error := (ErrorId <> 0)  -> vue LIVE
     FB_WinchStateProjection.st:236-237
                                  Safety.Error agrege les deux FBs,
                                  Safety.ErrorId = securite uniquement
     PRG_07_Supervision.st:537-547  AnyFaultActive agrege Safety.Error
     FB_Hmi_BannerFormatter.st:812-849   carrousel : bit6 NON decode
     FB_Hmi_BannerFormatter.st:648-658   seul libelle, sous commande descente

   Preuves attendues sur le code du 2026-09-20 (aucun correctif) :
     -A1  ROUGE : aucun canal du bandeau n'expose la cause (carrousel vide,
                  SpecialCondition vide) alors que la cause allume AnyFaultActive
     -A2  ROUGE : le texte daction reste le rappel joystick generique
   Apres correctif : les 4 tests doivent etre VERTS.
   ======================================================================= *)

SETUP
VAR
    PRG07 : FB_TestHarness_PRG_07;
    AcqData : ST_AcquisitionInterPrg;
    ModesAuth : ST_Modes_Autorisations;
    WinchData : ST_WinchInterPrg;
    TranslationData : ST_TranslationInterPrg;
END_VAR

// Pas de boot long : au dela de 1,5 s les filtres anti-bagotement invalideraient le
// reseau (le harnais ne cable pas Network), ce qui masquerait la cause visee par une
// alarme parente de module E/S. TonBootInhibit (4 s) protege les 4 tests.
ModesAuth.Mode := E_Mode.MAINT_N1;
ModesAuth.JoystickWinchSelectArbitrated := 0;   // treuils couples -> CurrentDirection = WinchBothMotionDirection = 0
AcqData.Joystick.DeadmanArmed := FALSE;         // situation terrain : joystick relache
AcqData.Joystick.AtNeutralXY := TRUE;
END_SETUP

TEST 'T255D-REPRO-M1-A1 butte basse cable M1 : aucun canal du bandeau nexpose la cause active'
    WinchData.WinchM1Safety.Error := TRUE;           (* vu par AnyFaultActive *)
    WinchData.WinchM1Safety.ErrorId := 16#0040;      (* bit6 = limite basse cable, vue LIVE *)
    WinchData.WinchM1Safety.CableLimitDescent := TRUE;
    WinchData.WinchM1Safety.DescendPermit := FALSE;  (* interlock : descente interdite *)
    WinchData.WinchM1Safety.AscentPermit := TRUE;    (* remontee autorisee *)
    WinchData.WinchM2Safety.AscentPermit := TRUE;

    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);
    ADVANCE_TIME(600000000);
    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);

    ASSERT_TRUE(PRG07.Banner.AlarmBanner.HasAlarm OR PRG07.Banner.SpecialConditionText <> '',
                '[T255D-A1] cause limite basse cable M1 active : aucun canal du bandeau ne lexpose');
END_TEST

TEST 'T255D-REPRO-M1-A2 butte basse cable M1 : le texte daction ne nomme pas la cause'
    WinchData.WinchM1Safety.Error := TRUE;
    WinchData.WinchM1Safety.ErrorId := 16#0040;
    WinchData.WinchM1Safety.CableLimitDescent := TRUE;
    WinchData.WinchM1Safety.DescendPermit := FALSE;
    WinchData.WinchM1Safety.AscentPermit := TRUE;
    WinchData.WinchM2Safety.AscentPermit := TRUE;

    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);
    ADVANCE_TIME(600000000);
    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);

    ASSERT_NEQ(PRG07.Banner.OperatorActionText, '[JOYSTICK] Appuyer homme-mort au neutre',
               '[T255D-A2] la cause limite basse cable M1 doit etre nommee dans laction');
END_TEST

TEST 'T255D-REPRO-M2-A1 butte basse cable M2 : aucun canal du bandeau nexpose la cause active'
    WinchData.WinchM2Safety.Error := TRUE;
    WinchData.WinchM2Safety.ErrorId := 16#0040;
    WinchData.WinchM2Safety.CableLimitDescent := TRUE;
    WinchData.WinchM2Safety.DescendPermit := FALSE;
    WinchData.WinchM2Safety.AscentPermit := TRUE;
    WinchData.WinchM1Safety.AscentPermit := TRUE;

    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);
    ADVANCE_TIME(600000000);
    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);

    ASSERT_TRUE(PRG07.Banner.AlarmBanner.HasAlarm OR PRG07.Banner.SpecialConditionText <> '',
                '[T255D-A1] cause limite basse cable M2 active : aucun canal du bandeau ne lexpose');
END_TEST

TEST 'T255D-REPRO-M2-A2 butte basse cable M2 : le texte daction ne nomme pas la cause'
    WinchData.WinchM2Safety.Error := TRUE;
    WinchData.WinchM2Safety.ErrorId := 16#0040;
    WinchData.WinchM2Safety.CableLimitDescent := TRUE;
    WinchData.WinchM2Safety.DescendPermit := FALSE;
    WinchData.WinchM2Safety.AscentPermit := TRUE;
    WinchData.WinchM1Safety.AscentPermit := TRUE;

    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);
    ADVANCE_TIME(600000000);
    PRG07(AcqData := AcqData, ModesAuth := ModesAuth, WinchData := WinchData,
          TranslationData := TranslationData, EmergencyChainClosed := TRUE,
          PowerContactorEngaged := TRUE, PowerCutOffActive := FALSE, BtnResetMachine := FALSE);

    ASSERT_NEQ(PRG07.Banner.OperatorActionText, '[JOYSTICK] Appuyer homme-mort au neutre',
               '[T255D-A2] la cause limite basse cable M2 doit etre nommee dans laction');
END_TEST

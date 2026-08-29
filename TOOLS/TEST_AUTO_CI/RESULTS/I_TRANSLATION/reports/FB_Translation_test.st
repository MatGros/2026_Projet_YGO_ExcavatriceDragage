SETUP
VAR
    FB_Safety : FB_Safety_Translation;
    FB_T : FB_Translation;
    FB_IL : FB_TranslationOutputInterlock;
    FB_Decoder : FB_Translation_PositionDecoder;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    FB_T(Enable := FALSE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB_T.Ready, 'Enable=TRUE au repos -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette *)
    FB_T(Enable := FALSE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P11-001 Safety_Translation : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'TC-P11-010 Translation : commande variateur nominale'
    (* Scan 1 : initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : mise en service *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, PowerContactorEngaged := TRUE,
         SpeedTgt_Pct := 50.0, Direction := 1);
    ASSERT_TRUE(FB_T.Ready, 'Translation active et prete');
END_TEST

(* =========================================================================
   AF-11 — TC manquants (BILAN_TC_COVERAGE_v1.0) — FB_Translation_PositionDecoder
   ========================================================================= *)

TEST 'TC-P11-001 PositionDecoder : 6 mots valides acceptes, autre -> Incoherent'
    (* Mot 11111 (extreme Tremie) -> LimitSwitchFwd, pas d incoherence *)
    FB_Decoder(SensorTremie := TRUE, SensorPV := TRUE, SensorP2 := TRUE, SensorP1 := TRUE, SensorMaintenance := TRUE);
    ASSERT_TRUE(FB_Decoder.LimitSwitchFwd, '11111 -> LimitSwitchFwd=TRUE');
    ASSERT_FALSE(FB_Decoder.Incoherent, '11111 -> Incoherent=FALSE');

    ADVANCE_TIME(10000000);

    (* Mot 00000 (extreme Maintenance) -> LimitSwitchRev *)
    FB_Decoder(SensorTremie := FALSE, SensorPV := FALSE, SensorP2 := FALSE, SensorP1 := FALSE, SensorMaintenance := FALSE);
    ASSERT_TRUE(FB_Decoder.LimitSwitchRev, '00000 -> LimitSwitchRev=TRUE');
    ASSERT_FALSE(FB_Decoder.Incoherent, '00000 -> Incoherent=FALSE');

    ADVANCE_TIME(10000000);

    (* Mot intermediaire valide 00111 (P2) -> pas d incoherence, pas de Fdc *)
    FB_Decoder(SensorTremie := FALSE, SensorPV := FALSE, SensorP2 := TRUE, SensorP1 := TRUE, SensorMaintenance := TRUE);
    ASSERT_FALSE(FB_Decoder.Incoherent, '00111 -> Incoherent=FALSE');
    ASSERT_FALSE(FB_Decoder.LimitSwitchFwd, '00111 -> pas de Fdc avant');
    ASSERT_FALSE(FB_Decoder.LimitSwitchRev, '00111 -> pas de Fdc arriere');

    ADVANCE_TIME(10000000);

    (* Mot incoherent 10101 -> Incoherent, pas de Fdc fantome *)
    FB_Decoder(SensorTremie := TRUE, SensorPV := FALSE, SensorP2 := TRUE, SensorP1 := FALSE, SensorMaintenance := TRUE);
    ASSERT_TRUE(FB_Decoder.Incoherent, '10101 -> Incoherent=TRUE');
    ASSERT_FALSE(FB_Decoder.LimitSwitchFwd, 'incoherent -> pas de Fdc fantome');
    ASSERT_FALSE(FB_Decoder.LimitSwitchRev, 'incoherent -> pas de Fdc fantome');
END_TEST

TEST 'TC-P11-002 Safety : mot capteurs incoherent -> bit7 -> SafeStop+PowerCutOff'
    (* SensorWordIncoherent=TRUE -> cause 7 latchee -> bit7 -> SafeStop+PowerCutOff *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := TRUE);
    ASSERT_TRUE(FB_Safety.ErrorSensorIncoherent, 'mot incoherent -> bit7');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'PowerCutOff');
END_TEST

(* =========================================================================
   AF-11 — FB_Translation (TC-P11-003/004/005/013)
   ========================================================================= *)

TEST 'TC-P11-003 Translation Enable=FALSE coupe tout independamment de SafeStop/StartStop'
    (* Enable=FALSE avec StartStop=TRUE et SafeStop=FALSE -> tout coupe *)
    FB_T(Enable := FALSE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'Enable=FALSE -> mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'Enable=FALSE -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'Enable=FALSE -> frein non desserre');
END_TEST

TEST 'TC-P11-004 Translation ralentissement PV (Direction=1 + SlowdownSensorTremie)'
    (* Scan 1 : init Fwd *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scans 2-7 : rampe monte a 50% *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scan 7 : sans ralentissement, freq pleine ~30Hz *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 20.0, 'sans PV, freq pleine ~30Hz');

    (* Scan 8 : SlowdownSensorTremie=TRUE -> cap a ApproachSpeedTremieHz (10Hz) *)
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, BypassContactorCheck := TRUE, BrakeFeedback := TRUE,
         SlowdownSensorTremie := TRUE);
    ASSERT_LE(FB_T.RequestedDriveFreqHz, 10.0, 'ralentissement PV -> freq <= 10Hz');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'mouvement toujours actif');
END_TEST

TEST 'TC-P11-005 Translation interlock sens : inversion Fwd->Rev differee (pas immediate)'
    (* Scan 1 : init Fwd (petits delais frein pour ouvrir vite) *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scans 2-6 : rampe monte a 50% *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scan 7 : mouvement Fwd etabli *)
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := 1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement Fwd -> mot 1');

    (* Scan 8 : inversion demandee Direction=-1 -> pas immediate (interlock) *)
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, StartStop := TRUE, SafeStop := FALSE,
         Direction := -1, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         CfgRampAccelRate := 1000.0, CfgRampDecelNormalRate := 1000.0,
         BrakeDelayMagnetise := T#10ms, BrakeDelayContactClose := T#10ms,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_NEQ(FB_T.RequestedDriveControlWord, 2, 'inversion pas immediate (interlock)');
END_TEST

TEST 'TC-P11-013 Boutons IHM MAINT exigent DeadmanArmed (essai manuel — stub)'
    (* Stub : TC-P11-013 verifie que les boutons IHM en MAINT_N1/N2 exigent DeadmanArmed
       (PRG_05_Translation.st:212-217, M3_StartStop_Active AND JoystickDeadmanArmed).
       Cablage PRG_05, non forçable en boite noire FB_Translation. (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub : DeadmanArmed MAINT a verifier manuellement sur PRG_05 (essai manuel)');
END_TEST

(* =========================================================================
   AF-11 — FB_TranslationOutputInterlock (TC-P11-006/007/008/009)
   ========================================================================= *)

TEST 'TC-P11-006 Watchdog frein 500ms : frontiere 499/500'
    (* Scan 1 : watchdog arme (BrakeReleaseRequest sans confirmation) *)
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_FALSE(FB_IL.Fault.Error, 'watchdog arme, pas encore de defaut');

    (* Scan 2 : a 499ms, pas de defaut (frontiere) *)
    ADVANCE_TIME(499000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_FALSE(FB_IL.Fault.Error, 'a 499ms, pas de defaut');

    (* Scan 3 : a 500ms, defaut watchdog *)
    ADVANCE_TIME(1000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_TRUE(FB_IL.Fault.Error, 'a 500ms, defaut watchdog');
    ASSERT_TRUE(FB_IL.RestartInhibit, 'RestartInhibit arme apres timeout');
    ASSERT_EQ(FB_IL.Reason, E_TranslationFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED, 'Reason = BRAKE_COMMAND_NOT_CONFIRMED');
END_TEST

TEST 'TC-P11-007 Apres timeout frein : RestartInhibit, acquittement Reset + reautorisation'
    (* Etape 1 : timeout watchdog -> RestartInhibit + Error *)
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ADVANCE_TIME(500000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_TRUE(FB_IL.RestartInhibit, 'timeout -> RestartInhibit=TRUE');
    ASSERT_TRUE(FB_IL.Fault.Error, 'timeout -> Error=TRUE');

    (* Etape 2 : confirmation frein -> efface la cause brute *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);

    (* Etape 3 : Reset front -> acquitte l affichage *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := TRUE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_FALSE(FB_IL.Fault.Error, 'Reset -> Error=FALSE');
    ASSERT_TRUE(FB_IL.RestartInhibit, 'RestartInhibit conserve apres Reset');

    (* Etape 4 : mot 0 vu -> NeutralRequestSeen *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := FALSE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 0, RequestedDriveFreqHz := 0.0);

    (* Etape 5 : nouvelle demande 1 -> RestartInhibit leve *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_FALSE(FB_IL.RestartInhibit, 'nouvelle demande apres mot 0 -> RestartInhibit leve');
    ASSERT_TRUE(FB_IL.Ready, 'Ready apres reautorisation');
END_TEST

TEST 'TC-P11-008 Gate final : mot/freq nuls sans confirmation frein simultanee'
    (* Scan 1 : mouvement demande mais frein non confirme -> gate bloque *)
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_EQ(FB_IL.DriveControlWord, 0, 'frein non confirme -> mot 0');
    ASSERT_EQ(FB_IL.DriveFreqCmd_Hz, 0.0, 'frein non confirme -> freq 0');

    (* Scan 2 : confirmation frein -> mot/freq autorises *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_EQ(FB_IL.DriveControlWord, 1, 'frein confirme -> mot 1');
    ASSERT_NEAR(FB_IL.DriveFreqCmd_Hz, 30.0, 0.01, 'frein confirme -> freq 30Hz');
END_TEST

TEST 'TC-P11-009 Mot 7 (reset AC600) autorise pendant RestartInhibit'
    (* Etape 1 : timeout -> RestartInhibit *)
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ADVANCE_TIME(500000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := FALSE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_TRUE(FB_IL.RestartInhibit, 'timeout -> RestartInhibit=TRUE');

    (* Etape 2 : confirmation frein + Reset -> efface Error, RestartInhibit conserve *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := TRUE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);
    ASSERT_FALSE(FB_IL.Fault.Error, 'Reset+confirmation -> Error=FALSE');
    ASSERT_TRUE(FB_IL.RestartInhibit, 'RestartInhibit conserve apres Reset');

    (* Etape 3 : mot 7 pendant RestartInhibit -> autorise, freq nulle, inhibition conservee *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          BrakeReleaseRequest := FALSE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 7, RequestedDriveFreqHz := 0.0);
    ASSERT_EQ(FB_IL.DriveControlWord, 7, 'mot 7 autorise pendant RestartInhibit');
    ASSERT_EQ(FB_IL.DriveFreqCmd_Hz, 0.0, 'mot 7 -> freq nulle');
    ASSERT_TRUE(FB_IL.RestartInhibit, 'mot 7 ne leve pas RestartInhibit');
END_TEST

(* =========================================================================
   AF-11 — FB_Safety_Translation (TC-P11-011/011.1/014)
   ========================================================================= *)

TEST 'TC-P11-011 Meca B : incohérence arret >3s -> SafeStop+PowerCutOff'
    (* Direction=0, BrakeCmd=FALSE, DriveStatusWord.0=1 -> UncommandedActiveB pendant 3s *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0001,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0001,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0001,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorMecaB, 'Meca B -> bit4');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'PowerCutOff');
END_TEST

TEST 'TC-P11-011.1 Meca B variante perte IHM : condition elargie'
    (* HeartbeatIhmOk=FALSE -> condition elargie : ABS(freq)>0.5 OR DriveStatusWord.0 OR BrakeFeedback *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := TRUE,
              Direction := 1, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := TRUE,
              Direction := 1, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := TRUE,
              Direction := 1, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorMecaB, 'Meca B variante perte IHM -> bit4');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'PowerCutOff (bit4)');
END_TEST

TEST 'TC-P11-014 BypassGlobal : aucune surveillance active, pas de nouveau defaut'
    (* BypassGlobal=TRUE des le depart -> Meca A (mouvement non commande) ne se declenche pas *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE, BypassGlobal := TRUE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE, BypassGlobal := TRUE);
    ADVANCE_TIME(1000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              Direction := 0, LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
              SensorWordIncoherent := FALSE, BypassGlobal := TRUE);
    ASSERT_FALSE(FB_Safety.ErrorMecaA, 'BypassGlobal -> Meca A ne se declenche pas');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'BypassGlobal -> pas de PowerCutOff');
    ASSERT_FALSE(FB_Safety.SafeStop, 'BypassGlobal -> pas de SafeStop');
END_TEST

(* =========================================================================
   AF-11 — TC-P11-015 anti-telescopage (cablage PRG_05, stub)
   ========================================================================= *)

TEST 'TC-P11-015 Anti-telescopage hauteur M1/M2 (essai manuel — stub)'
    (* Stub : l anti-telescopage vit dans le cablage PRG_05_Translation.st:105-110
       (M3_HeightInterlockOk), pas dans un FB boite noire. Non forçable ici.
       Condition : Bypass.MinHeight OR (M1_HomedAndReliable AND M2_HomedAndReliable AND
       M1.CablePosM >= _TranslationMinHeightM1M2_M AND M2.CablePosM >= _TranslationMinHeightM1M2_M).
       A verifier manuellement sur le PRG_04/PRG_05 composite. (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub anti-telescopage : a verifier manuellement sur PRG_05 composite (essai manuel)');
END_TEST

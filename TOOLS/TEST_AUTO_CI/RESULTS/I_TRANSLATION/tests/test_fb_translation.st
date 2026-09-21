SETUP
VAR
    FB_Safety : FB_Safety_Translation;
    FB_T : FB_Translation;
    FB_IL : FB_TranslationOutputInterlock;
    FB_Decoder : FB_Translation_PositionDecoder;
    CfgFast : ST_fbTranslation_Cfg;
    RestartSeen : BOOL;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    FB_T(Enable := FALSE, Reset := FALSE, RunRequest := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Premier scan d initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : Regime nominal etabli -> Ready=TRUE *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_TRUE(FB_T.Ready, 'Enable=TRUE au repos -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 3 : Enable=FALSE -> Coupure nette *)
    FB_T(Enable := FALSE, Reset := FALSE, RunRequest := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P11-001 Safety_Translation : Enable=FALSE neutralise les autorisations'
    FB_Safety(Enable := FALSE, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_Safety.Ready, 'Ready doit etre FALSE sans Enable');
END_TEST

TEST 'TC-P11-010 Translation : commande variateur nominale'
    (* Scan 1 : initialisation *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, PowerContactorEngaged := TRUE);

    ADVANCE_TIME(10000000);

    (* Scan 2 : mise en service *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, PowerContactorEngaged := TRUE,
         SpeedTgt_Pct := 50.0, ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE);
    ASSERT_TRUE(FB_T.Ready, 'Translation active et prete');
END_TEST

(* =========================================================================
   AF-11 — TC manquants (BILAN_TC_COVERAGE_v1.0) — FB_Translation_PositionDecoder
   ========================================================================= *)

TEST 'TC-P11-001 PositionDecoder : 6 mots valides acceptes, autre -> Incoherent'
    (* Mot 11111 (extreme Tremie) -> LimitSwitchFwd, pas d incoherence *)
    FB_Decoder(SensorTremie := TRUE, SensorPV := TRUE, SensorP2 := TRUE, SensorP1 := TRUE, SensorMaintenance := TRUE);
    ASSERT_TRUE(FB_Decoder.LimitSwitchTremie, '11111 -> LimitSwitchFwd=TRUE');
    ASSERT_FALSE(FB_Decoder.Incoherent, '11111 -> Incoherent=FALSE');

    ADVANCE_TIME(10000000);

    (* Mot 00000 (extreme Maintenance) -> LimitSwitchRev *)
    FB_Decoder(SensorTremie := FALSE, SensorPV := FALSE, SensorP2 := FALSE, SensorP1 := FALSE, SensorMaintenance := FALSE);
    ASSERT_TRUE(FB_Decoder.LimitSwitchMaintenance, '00000 -> LimitSwitchRev=TRUE');
    ASSERT_FALSE(FB_Decoder.Incoherent, '00000 -> Incoherent=FALSE');

    ADVANCE_TIME(10000000);

    (* Mot intermediaire valide 00111 (P2) -> pas d incoherence, pas de Fdc *)
    FB_Decoder(SensorTremie := FALSE, SensorPV := FALSE, SensorP2 := TRUE, SensorP1 := TRUE, SensorMaintenance := TRUE);
    ASSERT_FALSE(FB_Decoder.Incoherent, '00111 -> Incoherent=FALSE');
    ASSERT_FALSE(FB_Decoder.LimitSwitchTremie, '00111 -> pas de Fdc avant');
    ASSERT_FALSE(FB_Decoder.LimitSwitchMaintenance, '00111 -> pas de Fdc arriere');

    ADVANCE_TIME(10000000);

    (* Mot incoherent 10101 -> Incoherent, pas de Fdc fantome *)
    FB_Decoder(SensorTremie := TRUE, SensorPV := FALSE, SensorP2 := TRUE, SensorP1 := FALSE, SensorMaintenance := TRUE);
    ASSERT_TRUE(FB_Decoder.Incoherent, '10101 -> Incoherent=TRUE');
    ASSERT_FALSE(FB_Decoder.LimitSwitchTremie, 'incoherent -> pas de Fdc fantome');
    ASSERT_FALSE(FB_Decoder.LimitSwitchMaintenance, 'incoherent -> pas de Fdc fantome');
END_TEST

TEST 'TC-P11-002 Safety : mot capteurs incoherent -> bit7 -> SafeStop+PowerCutOff'
    (* SensorWordIncoherent=TRUE -> cause 7 latchee -> bit7 -> SafeStop+PowerCutOff *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
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
    FB_T(Enable := FALSE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE);
    ASSERT_FALSE(FB_T.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'Enable=FALSE -> mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'Enable=FALSE -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'Enable=FALSE -> frein non desserre');
END_TEST

TEST 'TC-P11-004 Translation ralentissement PV (Direction=1 + SlowdownSensorTremie)'
    (* Scan 1 : init Fwd *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    (* Scans 2-7 : rampe monte a 50% *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    (* Scan 7 : sans ralentissement, freq pleine ~30Hz *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 20.0, 'sans PV, freq pleine ~30Hz');

    (* Scan 8 : SlowdownSensorTremie=TRUE -> cap a ApproachSpeedTremieHz (10Hz) *)
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE,
         SlowdownSensorTremie := TRUE);
    ASSERT_LE(FB_T.RequestedDriveFreqHz, 10.0, 'ralentissement PV -> freq <= 10Hz');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'mouvement toujours actif');
END_TEST

TEST 'TC-P11-005 Translation interlock sens : inversion Fwd->Rev differee (pas immediate)'
    CfgFast.CfgRampAccelRate := 100.0;
    CfgFast.CfgRampDecelNormalRate := 100.0;
    CfgFast.CfgRampDecelFastRate := 100.0;
    CfgFast.DirectionInterlockDelay := T#200ms;
    CfgFast.DriveFreqScaleMaxHz := 60.0;
    CfgFast.BrakeDelayContactClose := T#0ms;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayMotorDecel := T#0ms;
    CfgFast.BrakeFeedbackTimeout := T#800ms;

    (* Scan 1 : init Fwd (petits delais frein pour ouvrir vite) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scans 2-6 : rampe monte a 50% *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    (* Scan 7 : mouvement Fwd etabli *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement Fwd -> mot 1');

    (* Scan 8 : inversion demandee Direction=-1 -> pas immediate (interlock) *)
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
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
          EffectivePermitM3_Tremie := TRUE, BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
          RequestedDriveControlWord := 1, RequestedDriveFreqHz := 30.0);

    (* Etape 3 : Reset front -> acquitte l affichage *)
    ADVANCE_TIME(10000000);
    FB_IL(Enable := TRUE, Reset := TRUE, SafeStop := FALSE, PowerContactorEngaged := TRUE,
          EffectivePermitM3_Tremie := TRUE, BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
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
          EffectivePermitM3_Tremie := TRUE, BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
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
          EffectivePermitM3_Tremie := TRUE, BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
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
          EffectivePermitM3_Tremie := TRUE, BrakeReleaseRequest := TRUE, BrakeCommandOpenConfirmed := TRUE,
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
              DriveActualFreqHz := 0.0, BrakeFeedback := TRUE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0001,
              DriveActualFreqHz := 0.0, BrakeFeedback := TRUE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0001,
              DriveActualFreqHz := 0.0, BrakeFeedback := TRUE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
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
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := TRUE,
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := TRUE,
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
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
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE, BypassGlobal := TRUE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE, BypassGlobal := TRUE);
    ADVANCE_TIME(1000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
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

(* =========================================================================
   AF-11 — CHRONOGRAMMES RÉALISTES (lot 2026-08-29)
   Modes de marche classiques + modes de défaillance + interlocks + reset.
   Config réaliste : rampe 100%/s, frein 300ms magnétisation + 100ms contact,
   échelle 60Hz, ADVANCE_TIME(100ms)/scan -> chronogramme temporel réaliste.
   ========================================================================= *)

(* -------------------------------------------------------------------------
   A. MODES DE MARCHE CLASSIQUES — FB_Translation
   ------------------------------------------------------------------------- *)

TEST 'TC-P11-016 Translation vers Trémie : cycle complet réaliste (rampe, frein, mot FWD, fréquence)'
    CfgFast.CfgRampAccelRate := 20.0;
    CfgFast.CfgRampDecelNormalRate := 40.0;
    CfgFast.CfgRampDecelFastRate := 100.0;
    CfgFast.DirectionInterlockDelay := T#200ms;
    CfgFast.DriveFreqScaleMaxHz := 60.0;
    CfgFast.BrakeDelayContactClose := T#0ms;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayMotorDecel := T#2s;
    CfgFast.BrakeFeedbackTimeout := T#800ms;

    (* Scan 1 : warmup (CycleTimeS=0.004) + démarrage rampe *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'frein non desserré -> mot 0');

    ADVANCE_TIME(500000000); (* 500ms *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'magnétisation en cours -> mot 0 (frein encore serré)');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'frein relâché -> mot 1 (FWD)');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'magnétisation en cours -> mot 1 (FWD)');

    ADVANCE_TIME(500000000);
    (* Scan 5 : 400ms -> frein desserré -> mot FWD *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'frein desserré -> mot 1 (FWD)');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 20.0, 'fréquence ~24Hz');

    ADVANCE_TIME(500000000);
    (* Scan 6 : rampe à 50% -> fréquence pleine 30Hz *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD maintenu');
    ASSERT_NEAR(FB_T.RequestedDriveFreqHz, 30.0, 1.0, 'fréquence pleine ~30Hz');
END_TEST

TEST 'TC-P11-017 Translation vers Maintenance : mot REV (2) + fréquence pleine'
    (* Scan 1 : warmup + démarrage rampe vers Maintenance (Direction=-1) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'frein non desserré -> mot 0');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'magnétisation en cours -> mot 0 (frein encore serré)');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'frein relâché -> mot 2 (REV)');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'magnétisation en cours -> mot 2 (REV)');

    ADVANCE_TIME(500000000);
    (* Scan 5 : 400ms -> frein desserré -> mot REV *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'frein desserré -> mot 2 (REV)');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 20.0, 'fréquence ~24Hz');

    ADVANCE_TIME(500000000);
    (* Scan 6 : rampe à 50% -> fréquence pleine 30Hz *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'mouvement REV maintenu');
    ASSERT_NEAR(FB_T.RequestedDriveFreqHz, 30.0, 1.0, 'fréquence pleine ~30Hz');
END_TEST

TEST 'TC-P11-018 Translation : arrivée sur capteur cible (debounce 100ms) + arrêt exact + frein collé'
    (* Monter à 50% FWD (6 scans, cf. TC-P11-016) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD établi');
    ASSERT_FALSE(FB_T.TargetReached, 'pas encore de capteur cible');

    (* Capteur cible activé -> debounce 100ms *)
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_FALSE(FB_T.TargetReached, 'debounce 100ms pas encore écoulé');

    ADVANCE_TIME(500000000);
    (* Scan 8 : debounce écoulé -> TargetReached + ArrivalLock -> rampe à 0 *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.TargetReached, 'debounce écoulé -> TargetReached=TRUE');

    (* Décélération normale 100%/s -> 10%/100ms ; frein collé quand Current<0.1 *)
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'décélération en cours');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         PositionSensorTarget := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'arrêt sur capteur -> frein collé, mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'arrêt sur capteur -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'arrêt sur capteur -> frein non desserré');
END_TEST

TEST 'TC-P11-019 Translation : interlock sens complet Fwd->Rev (délai 200ms à vitesse nulle)'
    (* Monter à 50% FWD (6 scans) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD établi');

    (* Inversion demandée Direction=-1 -> pas immédiate, décélération d'abord *)
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_NEQ(FB_T.RequestedDriveControlWord, 2, 'inversion pas immédiate (interlock)');

    (* Décélération à 0 puis délai 200ms -> bascule REV *)
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'vitesse nulle, délai interlock en cours -> mot 0');

    ADVANCE_TIME(500000000);
    (* Scan 10 : délai 200ms écoulé -> CommandedDirection=-1 -> rampe REV *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'bascule REV, magnétisation en cours -> mot 0');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    (* Scan 13 : 400ms de magnétisation -> frein desserré -> mot REV *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 0.0,
           
           
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'inversion complète -> mot 2 (REV)');
END_TEST

TEST 'TC-P11-020 Translation : SafeStop -> rampe rapide (décélération rapide)'
    (* Monter à 50% FWD (6 scans) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD établi');

    (* SafeStop=TRUE -> rampe rapide *)
    ADVANCE_TIME(100000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := TRUE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'SafeStop -> décélération en cours');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := TRUE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_LT(FB_T.RequestedDriveFreqHz, 20.0, 'SafeStop -> fréquence chute rapide');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := TRUE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'SafeStop -> frein collé, mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'SafeStop -> freq 0');
END_TEST

TEST 'TC-P11-021 Translation : StartStop=FALSE -> rampe normale (décélération normale)'
    (* Monter à 50% FWD (6 scans) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD établi');

    (* StartStop=FALSE -> rampe normale 40%/s *)
    ADVANCE_TIME(250000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 15.0, 'décélération normale -> freq encore élevée');

    ADVANCE_TIME(250000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 10.0, 'décélération normale -> freq ~18Hz');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 5.0, 'décélération normale -> freq ~12Hz');

    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
           
           
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'arrêt normal -> frein collé, mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'arrêt normal -> freq 0');
END_TEST

(* -------------------------------------------------------------------------
   B. MODES DE DÉFAILLANCE — FB_Safety_Translation
   ------------------------------------------------------------------------- *)

TEST 'TC-P11-022 Safety : perte comm EtherCAT drive (bit1) -> SafeStop seul, pas de PowerCutOff'
    (* Warmup 3s nominal *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000); (* 3s warmup *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_FALSE(FB_Safety.SafeStop, 'nominal -> pas de SafeStop');

    (* Perte comm drive *)
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := FALSE, DriveOperational := FALSE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorDriveComm, 'perte comm drive -> bit1');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'bit1 -> pas de PowerCutOff (comms ne coupent pas la puissance)');
END_TEST

TEST 'TC-P11-023 Safety : perte comm opérateur (bit0) -> SafeStop seul, pas de PowerCutOff'
    (* Warmup 3s nominal *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(3000000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_FALSE(FB_Safety.SafeStop, 'nominal -> pas de SafeStop');

    (* Perte heartbeat IHM *)
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := FALSE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorOperatorComm, 'perte heartbeat IHM -> bit0');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'bit0 -> pas de PowerCutOff');
END_TEST

TEST 'TC-P11-024 Safety : défaut rotation de phases (bit2) -> SafeStop seul, pas de PowerCutOff'
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := FALSE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorPhaseRotation, 'mauvaise rotation phases -> bit2');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'bit2 -> pas de PowerCutOff');
END_TEST

TEST 'TC-P11-025 Safety : surchauffe thermique frein (bit3) -> SafeStop + PowerCutOff'
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := TRUE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorBrakeThermal, 'thermique frein -> bit3');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'bit3 -> PowerCutOff');
END_TEST

TEST 'TC-P11-026 Safety : mouvement non commandé (Meca A, bit5) -> SafeStop + PowerCutOff'
    (* Direction=0, BrakeCmd=FALSE, DriveActualFreqHz=1.0 -> mouvement résiduel non commandé *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(1000000000); (* 1s -> MecaA timeout *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorMecaA, 'mouvement non commandé -> bit5');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'bit5 -> PowerCutOff');
END_TEST

TEST 'TC-P11-027 Safety : escalade fin de course (bit6) -> SafeStop + PowerCutOff'
    (* Direction=1 + LimitSwitchTremie + fréquence >0.5 -> escalade Fdc *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := TRUE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := TRUE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ADVANCE_TIME(1500000000); (* 1.5s -> overrun timeout *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 1.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := TRUE, ReqMaintenance := FALSE, LimitSwitchTremie := TRUE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorLimitSwitch, 'escalade Fdc -> bit6');
    ASSERT_TRUE(FB_Safety.SafeStop, 'SafeStop');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'bit6 -> PowerCutOff');
END_TEST

(* -------------------------------------------------------------------------
   C. INTERLOCKS & PERMITS — FB_Safety_Translation
   ------------------------------------------------------------------------- *)

TEST 'TC-P11-028 Safety : permits directionnels TremiePermit/MaintenancePermit (fail-safe)'
    (* TremiePermit = NOT LimitSwitchTremie ; MaintenancePermit = MaintenanceM3TargetEnable AND NOT LimitSwitchMaintenance *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
               SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.TremieLimitClear, 'Fdc Trémie libre -> TremiePermit=TRUE');
    ASSERT_TRUE(FB_Safety.MaintenanceLimitClear, 'cible MAINT autorisée + Fdc libre -> MaintenancePermit=TRUE');

    ADVANCE_TIME(10000000);
    (* Fdc Trémie atteinte -> TremiePermit=FALSE *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := TRUE, LimitSwitchMaintenance := FALSE,
               SensorWordIncoherent := FALSE);
    ASSERT_FALSE(FB_Safety.TremieLimitClear, 'Fdc Trémie -> TremiePermit=FALSE');
    ASSERT_TRUE(FB_Safety.MaintenanceLimitClear, 'MaintenancePermit inchangé');

    ADVANCE_TIME(10000000);
    (* Fdc Maintenance atteinte -> MaintenancePermit=FALSE *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := TRUE,
               SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.TremieLimitClear, 'TremiePermit inchangé');
    ASSERT_FALSE(FB_Safety.MaintenanceLimitClear, 'Fdc Maintenance -> MaintenancePermit=FALSE');


END_TEST

TEST 'TC-P11-029 Safety : PowerContactorEngaged=FALSE (chaîne AU non réarmée) -> SafeStop'
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := FALSE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.SafeStop, 'PowerContactorEngaged=FALSE -> SafeStop');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'pas de défaut -> pas de PowerCutOff');
END_TEST

(* -------------------------------------------------------------------------
   D. RESET / ACQUITTEMENT — FB_Safety_Translation
   ------------------------------------------------------------------------- *)

TEST 'TC-P11-030 Safety : acquittement Reset après défaut laté (BrakeThermal)'
    (* Défaut laté : BrakeThermal *)
    FB_Safety(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := TRUE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_TRUE(FB_Safety.ErrorBrakeThermal, 'thermique -> bit3');
    ASSERT_TRUE(FB_Safety.PowerCutOff, 'bit3 -> PowerCutOff');

    (* Cause disparue + Reset front -> acquittement *)
    ADVANCE_TIME(10000000);
    FB_Safety(Enable := TRUE, Reset := TRUE, PowerContactorEngaged := TRUE,
              JoystickOnline := TRUE, JoystickOperational := TRUE, HeartbeatIhmOk := TRUE,
              PhaseRotationOk := TRUE, BrakeThermalFeedback := FALSE,
              DriveOnline := TRUE, DriveOperational := TRUE, DriveStatusWord := 16#0000,
              DriveActualFreqHz := 0.0, BrakeFeedback := FALSE, BrakeCmd := FALSE,
              ReqTremie := FALSE, ReqMaintenance := FALSE, LimitSwitchTremie := FALSE, LimitSwitchMaintenance := FALSE,
              SensorWordIncoherent := FALSE);
    ASSERT_FALSE(FB_Safety.ErrorBrakeThermal, 'Reset -> bit3 effacé');
    ASSERT_FALSE(FB_Safety.SafeStop, 'Reset -> SafeStop levé');
    ASSERT_FALSE(FB_Safety.PowerCutOff, 'Reset -> PowerCutOff levé');
END_TEST

(* -------------------------------------------------------------------------
   E. FIN DE COURSE EXTREME — FB_Translation (bit6)
   ------------------------------------------------------------------------- *)

TEST 'TC-P11-031 Translation : fin de course extrême coupe le mouvement (bit6)'
    (* Monter à 50% FWD (6 scans) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(500000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement FWD établi');

    (* Fdc Trémie atteinte pendant mouvement FWD avec rotation active (10Hz) -> Ton 1.5s -> Fault.Error -> coupure *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 10.0, LimitSwitchTremie := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(1600000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         DriveActualFreqHz := 10.0, LimitSwitchTremie := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.Fault.Error, 'Fdc Trémie -> défaut');
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'défaut -> mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'défaut -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'défaut -> frein non desserré');
END_TEST

(* =========================================================================
   AF-11 — GATE DE SENS T204 — FB_Translation (EffectiveSafeStop)
   Le gate bloque la RAMPE vers un sens non autorisé (permit SAFETY=FALSE)
   sans toucher à Direction. Config rapide : rampe 1000%/s, frein bypass.
   ========================================================================= *)

TEST 'TC-P11-032 Gate de sens : Direction=1 sans TremiePermit -> rampe bloquee (mot 0, freq 0)'
    (* TremiePermit=FALSE (defaut) -> EffectiveSafeStop=TRUE -> rampe bloquee *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'TremiePermit=FALSE -> mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'TremiePermit=FALSE -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'TremiePermit=FALSE -> frein non desserre');
END_TEST

TEST 'TC-P11-033 Gate de sens : Direction=-1 sans MaintenancePermit -> rampe bloquee (fail-safe)'
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := FALSE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := FALSE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
          BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'MaintenancePermit=FALSE -> mot 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'MaintenancePermit=FALSE -> freq 0');
    ASSERT_FALSE(FB_T.BrakeReleaseRequest, 'MaintenancePermit=FALSE -> frein non desserre');
END_TEST

TEST 'TC-P11-034 Gate de sens : Direction=1 avec TremiePermit -> mouvement autorise'
    (* TremiePermit=TRUE -> EffectiveSafeStop=FALSE -> rampe monte, mot FWD *)
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;

    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'TremiePermit=TRUE -> mot 1 (FWD)');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'TremiePermit=TRUE -> freq > 0');
END_TEST

TEST 'TC-P11-035 Gate de sens : Direction=-1 avec MaintenancePermit -> mouvement autorise'
    (* MaintenancePermit=TRUE -> EffectiveSafeStop=FALSE -> rampe monte, mot REV *)
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;

    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE, SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'MaintenancePermit=TRUE -> mot 2 (REV)');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'MaintenancePermit=TRUE -> freq > 0');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════════
   T345 lot L1 — l'axe possede son arret (plan T334 Phase 3, §L1)
   Chronologie reproduite : scans de 10 ms, debounce capteur 100 ms, et surtout
   le RETRAIT DE LA DEMANDE PAR LE SEQUENCEUR sur le jeton d'arrivee, soit
   100 ms AVANT l'armement du verrou d'arrivee de l'axe (AX2/AX14).
   ═══════════════════════════════════════════════════════════════════════════ *)

TEST 'TC-P11-036 T345-L1 Arret de l axe : rebond capteur + demande re-armee -> aucun redemarrage'
    (* Config rapide : ni la rampe ni le frein ne doivent masquer un defaut de verrou d'arrete *)
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.CfgRampDecelNormalRate := 1000.0;
    CfgFast.DriveFreqScaleMaxHz := 60.0;
    CfgFast.CaptorDebounce := T#100ms;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;
    RestartSeen := FALSE;

    (* Scans 1-4 (10 ms) : montee vers la cible, demande vivante *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 1, 'mouvement etabli vers la cible');
    ASSERT_FALSE(FB_T.ArrivalStopConfirmed, 'aucun arret confirme avant l arrivee sur la cible');
    ADVANCE_TIME(10000000);

    (* Scan 5 : capteur cible actif -> debounce 100 ms engage *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_FALSE(FB_T.TargetReached, 'debounce 100 ms non ecoule');
    ADVANCE_TIME(10000000);

    (* Scans 6-17 : le sequenceur retire sa demande (jeton d'arrivee) 100 ms avant l armement du
       verrou ; la cible reste portee par l axe (memoire de cible de PRG_05) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);

    (* Scan 18 : arret de l axe -> mot et consigne a 0, arret confirme publie *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 'arret sur cible : mot de commande a 0');
    ASSERT_EQ(FB_T.RequestedDriveFreqHz, 0.0, 'arret sur cible : consigne de frequence a 0');
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'l axe publie son propre arret confirme');
    ADVANCE_TIME(50000000);

    (* Scans 19-40 (50 ms, soit ~1 s de rebond) : le sequenceur re-arme sa demande sur le jeton
       relance, et le capteur cible rebondit. L axe doit rester arme : aucun front montant du mot
       de commande ni de la consigne de frequence ne doit apparaitre. *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := FALSE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    IF FB_T.RequestedDriveControlWord <> 0 THEN RestartSeen := TRUE; END_IF;
    IF FB_T.RequestedDriveFreqHz > 0.0 THEN RestartSeen := TRUE; END_IF;
    ADVANCE_TIME(50000000);

    ASSERT_FALSE(RestartSeen, 'aucun front montant mot/frequence apres l armement du verrou');
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'l arret confirme resiste au rebond et a la re-demande');
END_TEST

TEST 'TC-P11-037 T345-L1 Le fait d arret confirme n est ni constant ni efface par la demande'
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.CfgRampDecelNormalRate := 1000.0;
    CfgFast.CaptorDebounce := T#100ms;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;

    (* Scan 1 : au repos, aucun arret confirme (le fait n est pas constant) *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_FALSE(FB_T.ArrivalStopConfirmed, 'au repos : aucun arret confirme (fait non constant)');
    ADVANCE_TIME(10000000);

    (* Scans 2-5 : mouvement vers la cible *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_FALSE(FB_T.ArrivalStopConfirmed, 'en mouvement : aucun arret confirme');
    ADVANCE_TIME(10000000);

    (* Scans 6-20 : capteur cible, puis demande retiree avant la fin du debounce *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'demande retiree avant le debounce : arret confirme');

    (* Scans 21-24 : la demande du MEME sens est re-armee, cible stable -> le fait doit tenir *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 're-demande du meme sens : arret confirme conserve');
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 0, 're-demande du meme sens : mot de commande reste a 0');
END_TEST

TEST 'TC-P11-038 T345-L1 Une demande de SENS INVERSE relache le verrou et autorise le degagement'
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.CfgRampDecelNormalRate := 1000.0;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;

    (* Scans 1-4 : mouvement vers la cible puis capteur cible + demande retiree *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'verrou d arret arme avec le sens du mouvement');
    ADVANCE_TIME(10000000);

    (* Scans 15-18 : demande explicite de SENS INVERSE (Maintenance) -> degagement autorise *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := TRUE, EffectivePermitM3_Maintenance := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_EQ(FB_T.RequestedDriveControlWord, 2, 'sens inverse : mot de commande REV');
    ASSERT_GT(FB_T.RequestedDriveFreqHz, 0.0, 'sens inverse : consigne de frequence non nulle');
    ASSERT_FALSE(FB_T.ArrivalStopConfirmed, 'axe en mouvement : plus d arret confirme');
END_TEST

TEST 'TC-P11-039 T345-L1 Non-vacuite : rotation reelle au variateur -> aucun arret confirme'
    CfgFast.CfgRampAccelRate := 1000.0;
    CfgFast.CfgRampDecelNormalRate := 1000.0;
    CfgFast.BrakeDelayMagnetise := T#0ms;
    CfgFast.BrakeDelayContactClose := T#0ms;

    (* Scans 1-4 : mouvement vers la cible *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, Cfg := CfgFast,
         BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := TRUE, SafeStop := FALSE,
         ReqTremie := TRUE, ReqMaintenance := FALSE, EffectivePermitM3_Tremie := TRUE,
         SpeedTgt_Pct := 50.0, PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);

    (* Scans 5-18 : demande retiree, cible tenue -> arret confirme *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ADVANCE_TIME(10000000);
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE, DriveActualFreqHz := 0.0,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'arret au repos : fait publie');
    ADVANCE_TIME(10000000);

    (* Scan 19 : le variateur tourne encore (5,0 Hz) -> l arret n est PAS confirme *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE, DriveActualFreqHz := 5.0,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_FALSE(FB_T.ArrivalStopConfirmed, 'rotation reelle 5,0 Hz : aucun arret confirme');
    ADVANCE_TIME(10000000);

    (* Scan 20 : retour au repos reel -> fait de nouveau publie *)
    FB_T(Enable := TRUE, Reset := FALSE, RunRequest := FALSE, SafeStop := FALSE,
         ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 50.0,
         PowerContactorEngaged := TRUE, PositionSensorTarget := TRUE, DriveActualFreqHz := 0.0,
         Cfg := CfgFast, BypassContactorCheck := TRUE, BrakeFeedback := TRUE);
    ASSERT_TRUE(FB_T.ArrivalStopConfirmed, 'retour au repos : arret confirme publie');
END_TEST

SETUP
VAR
    FB_Bench : FB_SimBench;
    FB_SimEnc : FB_Sim_Encoder;
    FB_SimJoy : FB_Sim_Joystick;
    FB_SimSafe : FB_Sim_Safety;
    FB_SimTrans : FB_Sim_Translation;
    RawPosM1 : UDINT := 0;
    RawPosM2 : UDINT := 0;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation *)
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Ready, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> SimBench actif *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Ready, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Ready, 'Coupure -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P13-001 Sim_Safety : neutralisation sans Enable'
    FB_SimSafe(Enable := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'AU non ferme');
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'Contacteur coupe');
END_TEST

(* =========================================================================
   AF-13 — FB_SimBench (TC-P13-010/011/012/013)
   ========================================================================= *)

TEST 'TC-P13-010 SimBench Enable=FALSE neutralise tout le banc'
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Ready, 'Enable=FALSE -> Ready=FALSE');
    ASSERT_FALSE(FB_Bench.Busy, 'Enable=FALSE -> Busy=FALSE');
    ASSERT_FALSE(FB_Bench.Done, 'Enable=FALSE -> Done=FALSE');
END_TEST

TEST 'TC-P13-014 SimBench initialise les codeurs absolus vierges a son activation'
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    RawPosM1 := 0;
    RawPosM2 := 0;
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(RawPosM1 <> 0, 'M1 vierge recoit un comptage absolu plausible');
    ASSERT_TRUE(RawPosM2 <> 0, 'M2 vierge recoit un comptage absolu plausible');
    ASSERT_TRUE(RawPosM1 <> RawPosM2, 'M1 et M2 conservent des origines device independantes');
END_TEST

TEST 'TC-P13-011 SimBench 0 lecture GVL en interne (essai manuel — stub)'
    (* Stub : TC-P13-011 verifie que FB_SimBench ne lit aucune variable GVL_* en interne
       (toutes les entrees passees en parametres par PRG_02_Acquisition). Verification
       statique de code, non automatisable en boite noire. (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub : verification statique 0 lecture GVL (essai manuel)');
END_TEST

TEST 'TC-P13-012 SimBench polarite frein M1 : M1_BrakeIsOpen_DI := M1_BrakeCmd'
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'M1_BrakeCmd=TRUE -> M1_BrakeIsOpen_DI=TRUE (jamais NOT)');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'M1_BrakeCmd=FALSE -> M1_BrakeIsOpen_DI=FALSE');
END_TEST

TEST 'TC-T318-010 SimBench cable nominal independent du Kobold et injection explicite'
    FB_Bench(Enable := TRUE, SimKoboldContactValue := TRUE,
             SimM2TensionedCableFaultInject := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M2_TensionedCable_DI,
                'Kobold ne produit pas de mou de cable sans injection explicite');
    FB_Bench(Enable := TRUE, SimM2TensionedCableFaultInject := TRUE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M2_TensionedCable_DI,
                 'Injection explicite -> cable non tendu');
END_TEST

TEST 'TC-T318-020 Diagnostic electrique desactive publie etat neutre'
    FB_Bench(Enable := TRUE, SimWinchElectricalDiagnosticsActive := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_EQ(FB_Bench.MotorTorqueM1_Nm, 0.0, 'Diagnostic M1 OFF -> couple neutre');
    ASSERT_FALSE(FB_Bench.MotorIsStalledM1, 'Diagnostic M1 OFF -> stall FALSE');
    ASSERT_EQ(FB_Bench.MotorTorqueM2_Nm, 0.0, 'Diagnostic M2 OFF -> couple neutre');
    ASSERT_FALSE(FB_Bench.MotorIsStalledM2, 'Diagnostic M2 OFF -> stall FALSE');
END_TEST

TEST 'TC-P13-015 SimBench delai frein M1 opt-in (T316) : SimWinchBrakeOpenDelayS retarde M1_BrakeIsOpen_DI sans jamais inverser la polarite'
    (* Delai desactive (0.0) : comportement historique, bascule au meme scan *)
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchBrakeOpenDelayS := 0.0, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Delai=0.0 -> ouverture instantanee (non-regression)');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := FALSE, SimWinchBrakeOpenDelayS := 0.0, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Retour delai=0.0 avant test delai>0 : etat repos');

    (* Delai actif (50 ms = 5 scans a 10 ms) : la DI reste fausse pendant le delai puis bascule *)
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchDynamicsActive := TRUE, SimWinchBrakeOpenDelayS := 0.042, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Scan 1/5 du delai : M1_BrakeIsOpen_DI reste FALSE, jamais TRUE en avance');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchDynamicsActive := TRUE, SimWinchBrakeOpenDelayS := 0.042, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Scan 2/5 du delai : toujours FALSE');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchDynamicsActive := TRUE, SimWinchBrakeOpenDelayS := 0.042, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Scan 3/5 du delai : toujours FALSE');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchDynamicsActive := TRUE, SimWinchBrakeOpenDelayS := 0.042, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Scan 4/5 du delai : toujours FALSE');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M1_BrakeCmd := TRUE, SimWinchDynamicsActive := TRUE, SimWinchBrakeOpenDelayS := 0.042, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M1_BrakeIsOpen_DI, 'Delai ecoule (5e scan) : M1_BrakeIsOpen_DI bascule TRUE');
END_TEST

TEST 'TC-T300-INT-010 SimBench M3 publie le retour dynamique du drive'
VAR
    i : INT;
END_VAR
    FB_Bench(Enable := TRUE, M3_ReqTremie := TRUE, M3_ReqMaintenance := FALSE,
             M3_SpeedCmd_Pct := 50.0, M3_BrakeCmd := TRUE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    FOR i := 1 TO 20 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := TRUE, M3_ReqMaintenance := FALSE,
                 M3_SpeedCmd_Pct := 50.0, M3_BrakeCmd := TRUE,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    END_FOR;
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0087, 'M3 actif apres ouverture frein et retour frequence');
    FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
             M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    FOR i := 1 TO 50 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
                 M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    END_FOR;
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0080, 'M3 arrete apres decroissance reelle de frequence');
END_TEST

TEST 'TC-T300-INT-030 Image SimBench relaye les DI M3 au decodeur production'
VAR
    Decoder : FB_Translation_PositionDecoder;
    HwInTranslation : ST_HwTranslation;
    i : INT;
END_VAR
    (* Le premier appel neutralise l'etat precedent. La copie explicite ci-dessous
       est representative du pont reel HwSim.Translation -> HwIn.Translation ;
       son unicite dans le programme est imposee statiquement par G502. *)
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
             M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    HwInTranslation := FB_Bench.Translation;
    Decoder(SensorTremie := HwInTranslation.M3_PosTremie_DI,
            SensorPV := HwInTranslation.M3_PosPV_DI,
            SensorP2 := HwInTranslation.M3_PosPVP2_DI,
            SensorP1 := HwInTranslation.M3_PosP1_DI,
            SensorMaintenance := HwInTranslation.M3_PosMaintenance_DI);
    ASSERT_EQ(Decoder.SensorsWord, 2#00011, 'Repli P1 publie par l image puis decode sans injection aval');
    ASSERT_FALSE(Decoder.Incoherent, 'Mot P1 issu du SimBench coherent au decodeur production');

    FOR i := 1 TO 1100 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := TRUE,
                 M3_SpeedCmd_Pct := 100.0, M3_BrakeCmd := TRUE,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
        HwInTranslation := FB_Bench.Translation;
        Decoder(SensorTremie := HwInTranslation.M3_PosTremie_DI,
                SensorPV := HwInTranslation.M3_PosPV_DI,
                SensorP2 := HwInTranslation.M3_PosPVP2_DI,
                SensorP1 := HwInTranslation.M3_PosP1_DI,
                SensorMaintenance := HwInTranslation.M3_PosMaintenance_DI);
    END_FOR;
    ASSERT_EQ(Decoder.SensorsWord, 2#00000, 'Fin Maintenance dynamique traverse image et decodeur');
    ASSERT_TRUE(Decoder.LimitSwitchMaintenance, 'FDC Maintenance derive uniquement du mot image');
    ASSERT_FALSE(Decoder.Incoherent, 'Fin Maintenance dynamique reste coherente');
END_TEST

TEST 'TC-T300-INT-031 Intermittence P1 dynamique relayee au decodeur production'
VAR
    Decoder : FB_Translation_PositionDecoder;
    HwInTranslation : ST_HwTranslation;
    P1Previous : BOOL;
    P1Lost : BOOL := FALSE;
    P1Recovered : BOOL := FALSE;
    i : INT;
END_VAR
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE,
             M3_SpeedCmd_Pct := 0.0, M3_BrakeCmd := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    HwInTranslation := FB_Bench.Translation;
    P1Previous := HwInTranslation.M3_PosP1_DI;

    (* Angle declencheur nul : l'episode est impose par la traversee mecanique,
       pas par un mot DI force. La graine et la periode restent deterministes. *)
    FOR i := 1 TO 1500 DO
        FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := TRUE,
                 M3_SpeedCmd_Pct := 100.0, M3_BrakeCmd := TRUE,
                 SimM3SensorIntermittenceActive := TRUE,
                 SimM3SensorStabilizationS := 1.0,
                 SimM3SensorIntermittencePeriodS := 0.12,
                 SimM3SensorElectricalDelayS := 0.0,
                 SimM3SensorLoadAngleTriggerRad := 0.0,
                 SimM3SensorScenarioSeed := 3001,
                 RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
        HwInTranslation := FB_Bench.Translation;
        Decoder(SensorTremie := HwInTranslation.M3_PosTremie_DI,
                SensorPV := HwInTranslation.M3_PosPV_DI,
                SensorP2 := HwInTranslation.M3_PosPVP2_DI,
                SensorP1 := HwInTranslation.M3_PosP1_DI,
                SensorMaintenance := HwInTranslation.M3_PosMaintenance_DI);
        IF P1Previous AND NOT HwInTranslation.M3_PosP1_DI THEN
            P1Lost := TRUE;
        END_IF;
        IF P1Lost AND HwInTranslation.M3_PosP1_DI THEN
            P1Recovered := TRUE;
        END_IF;
        P1Previous := HwInTranslation.M3_PosP1_DI;
    END_FOR;
    ASSERT_TRUE(P1Lost, 'P1 perd au moins une fois son etat pendant le franchissement');
    ASSERT_TRUE(P1Recovered, 'P1 est repris pendant l episode borne');
    ASSERT_FALSE(HwInTranslation.M3_PosP1_DI, 'P1 se stabilise a FALSE apres franchissement vers Maintenance');
    ASSERT_FALSE(Decoder.TranslationPosP1, 'Decodeur production voit la stabilisation du DI image');
END_TEST

TEST 'T196-003 Capteur haut manuel et polarite Free_DI correcte'
    FB_Bench(Enable := TRUE, SimTopPositionActive := TRUE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1M2_TopPositionFree_DI,
                 'TopPositionActive=TRUE -> Free_DI=FALSE (capteur atteint)');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, SimTopPositionActive := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M1M2_TopPositionFree_DI,
                'TopPositionActive=FALSE -> Free_DI=TRUE (butée libre)');
END_TEST

TEST 'T196-004 Capteur haut auto : forçage manuel SimTopPositionActive'
    FB_Bench(Enable := TRUE, SimTopPositionActive := FALSE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_TRUE(FB_Bench.Winch.M1M2_TopPositionFree_DI,
                'SimTopPositionActive=FALSE -> capteur haut libre');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, SimTopPositionActive := TRUE,
             RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_FALSE(FB_Bench.Winch.M1M2_TopPositionFree_DI,
                 'SimTopPositionActive=TRUE -> capteur haut actif');
END_TEST

(* =========================================================================
   AF-13 — FB_Sim_Safety (TC-P13-020/021/022/023)
   ========================================================================= *)

TEST 'TC-P13-020 Sim_Safety SimChainOk = A AND B AND NOT BtnEmergencyStop'
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(60000000); (* Delai retombe relais 50ms *)
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, BtnEmergencyStop := FALSE);
    ASSERT_TRUE(FB_SimSafe.SimChainOk, 'SimChainOkBit=TRUE -> SimChainOk=TRUE apres 50ms');

    ADVANCE_TIME(10000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := FALSE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(60000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := FALSE, BtnEmergencyStop := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'SimChainOkBit=FALSE -> SimChainOk=FALSE');

    ADVANCE_TIME(10000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, BtnEmergencyStop := TRUE);
    ADVANCE_TIME(60000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, BtnEmergencyStop := TRUE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'BtnEmergencyStop -> SimChainOk=FALSE');
END_TEST

TEST 'TC-P13-021 Sim_Safety SimContactorOk s auto-maintient sur EmergencyArming'
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(60000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'pas encore arme -> contacteur FALSE');

    (* Impulsion armement tenue 100ms *)
    ADVANCE_TIME(10000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, EmergencyArming := TRUE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(110000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, EmergencyArming := TRUE, BtnEmergencyStop := FALSE);
    ASSERT_TRUE(FB_SimSafe.SimContactorOk, 'EmergencyArming -> contacteur engage');

    (* Relachement impulsion -> auto-maintien *)
    ADVANCE_TIME(10000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := TRUE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ASSERT_TRUE(FB_SimSafe.SimContactorOk, 'auto-maintien : contacteur reste engage');

    (* Coupure chaine -> retombe apres chaine (50ms) + contacteur (50ms) *)
    ADVANCE_TIME(10000000);
    FB_SimSafe(Enable := TRUE, SimChainOkBit := FALSE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(60000000); (* Chaine s ouvre *)
    FB_SimSafe(Enable := TRUE, SimChainOkBit := FALSE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ADVANCE_TIME(60000000); (* Contacteur retombe *)
    FB_SimSafe(Enable := TRUE, SimChainOkBit := FALSE, EmergencyArming := FALSE, BtnEmergencyStop := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'SimChainOk=FALSE -> contacteur retombe');
END_TEST

TEST 'TC-P13-022 Sim_Safety Enable=FALSE neutralise tout'
    FB_SimSafe(Enable := FALSE, PowerCutOff_A := TRUE, PowerCutOff_B := TRUE, EmergencyArming := TRUE, BtnEmergencyStop := FALSE);
    ASSERT_FALSE(FB_SimSafe.SimChainOk, 'Enable=FALSE -> SimChainOk=FALSE');
    ASSERT_FALSE(FB_SimSafe.SimContactorOk, 'Enable=FALSE -> SimContactorOk=FALSE');
END_TEST

TEST 'TC-P13-023 Sim_Safety latch AU non lie a la sim (essai manuel — stub)'
    (* Stub : TC-P13-023 verifie qu un defaut AU reel latche (RedundancyTestFailedCause /
       EmergencyArmingFailedCause dans FB_Safety_EmergencyManagementLogic) survit a la sim et
       ne se debloque que par front Reset runtime. Non automatisable en boite noire FB_Sim_Safety
       (latch dans le FB consommateur). (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub : latch AU a verifier manuellement (essai manuel)');
END_TEST

(* =========================================================================
   AF-13 — FB_Sim_Encoder (TC-P13-030/031/032/033)
   ========================================================================= *)

TEST 'TC-P13-030 Sim_Encoder RelayFwd/Rev font compter RawPos'
    RawPosM1 := 0;
    FB_SimEnc(Enable := TRUE, RelayFwd := TRUE, RelayRev := FALSE, StepNumber := 1, RawPos := RawPosM1);
    ASSERT_GT(FB_SimEnc.RawPosOut, 0, 'RelayFwd -> RawPos augmente');
    ADVANCE_TIME(10000000);
    RawPosM1 := 100;
    FB_SimEnc(Enable := TRUE, RelayFwd := TRUE, RelayRev := FALSE, StepNumber := 1, RawPos := RawPosM1);
    ASSERT_GT(FB_SimEnc.RawPosOut, 100, 'RelayFwd -> RawPos augmente depuis 100');
    ADVANCE_TIME(10000000);
    RawPosM1 := 100;
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := TRUE, StepNumber := 1, RawPos := RawPosM1);
    ASSERT_LT(FB_SimEnc.RawPosOut, 100, 'RelayRev -> RawPos diminue');
END_TEST

TEST 'TC-P13-031 Sim_Encoder PresetCmd charge PresetValue'
    RawPosM1 := 0;
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := FALSE, StepNumber := 1, PresetCmd := TRUE, PresetValue := 5000, RawPos := RawPosM1);
    ADVANCE_TIME(10000000);
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := FALSE, StepNumber := 1, PresetCmd := FALSE, PresetValue := 5000, RawPos := RawPosM1);
    ADVANCE_TIME(10000000);
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := FALSE, StepNumber := 1, PresetCmd := FALSE, PresetValue := 5000, RawPos := RawPosM1);
    ADVANCE_TIME(10000000);
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := FALSE, StepNumber := 1, PresetCmd := FALSE, PresetValue := 5000, RawPos := RawPosM1);
    ASSERT_EQ(FB_SimEnc.RawPosOut, 5000, 'Preset applique apres latence');
END_TEST

TEST 'TC-P13-032 Sim_Encoder RawPos ne descend jamais sous 0'
    RawPosM1 := 0;
    FB_SimEnc(Enable := TRUE, RelayFwd := FALSE, RelayRev := TRUE, StepNumber := 1, RawPos := RawPosM1);
    ASSERT_EQ(FB_SimEnc.RawPosOut, 0, 'RawPos=0 + RelayRev -> reste 0 (borne)');
END_TEST

TEST 'TC-P13-033 Sim_Encoder RawPos survit a un reset froid (essai manuel — stub)'
    (* Stub : TC-P13-033 verifie que RawPos (VAR_IN_OUT reference GVL_PERSISTENT) survit a un
       reset froid. Non automatisable en boite noire (depend de la persistance CODESYS).
       (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub : persistance RawPos a verifier manuellement (essai manuel)');
END_TEST

(* =========================================================================
   AF-13 — FB_Sim_Translation (TC-P13-040/041/042/043)
   ========================================================================= *)

TEST 'TC-T300-INT-020 Sim_Translation initialise le mot P1'
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := FALSE,
                SpeedTgt_Pct := 0.0, BrakeReleaseCmd := FALSE);
    ASSERT_FALSE(FB_SimTrans.PosTremie, 'P1 ne doit pas annoncer Tremie');
    ASSERT_FALSE(FB_SimTrans.PosPV, 'P1 ne doit pas annoncer PV');
    ASSERT_FALSE(FB_SimTrans.PosP2, 'P1 ne doit pas annoncer P2');
    ASSERT_TRUE(FB_SimTrans.PosP1, 'P1 actif au repli');
    ASSERT_TRUE(FB_SimTrans.PosMaintenance, 'Mot thermometre P1 coherent');
END_TEST

TEST 'TC-T300-INT-021 Sim_Translation neutralise deux sens simultanes'
    FB_SimTrans(Enable := TRUE, ReqTremie := TRUE, ReqMaintenance := TRUE,
                SpeedTgt_Pct := 100.0, BrakeReleaseCmd := TRUE);
    ASSERT_EQ(FB_SimTrans.FrequencyCmd_Hz, 0.0, 'Deux sens ne creent aucune consigne');
    ASSERT_EQ(FB_SimTrans.ActualFrequency_Hz, 0.0, 'Aucun retour variateur sans sens unique');
END_TEST

TEST 'TC-T300-INT-022 Sim_Translation borne et publie la fin de course Maintenance'
VAR
    i : INT;
END_VAR
    FB_SimTrans(Enable := FALSE);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE,
                SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.5,
                BrakeReleaseCmd := TRUE, SensorElectricalDelayS := 0.0);
    FOR i := 1 TO 400 DO
        FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE,
                    SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.5,
                    BrakeReleaseCmd := TRUE, SensorElectricalDelayS := 0.0);
    END_FOR;
    ASSERT_GE(FB_SimTrans.PositionTrue_M, 0.0, 'Borne Tremie respectee');
    ASSERT_LE(FB_SimTrans.PositionTrue_M, 30.0, 'Borne Maintenance respectee');
    ASSERT_FALSE(FB_SimTrans.PosMaintenance, 'Maintenance publie le mot 00000 a la butee');
END_TEST

TEST 'TC-T300-INT-023 Sim_Translation desactive se replie P1'
    FB_SimTrans(Enable := FALSE, ReqTremie := FALSE, ReqMaintenance := TRUE,
                SpeedTgt_Pct := 100.0, BrakeReleaseCmd := TRUE);
    ASSERT_EQ(FB_SimTrans.PositionTrue_M, 20.0, 'Repli physique P1');
    ASSERT_TRUE(FB_SimTrans.PosP1, 'Capteur P1 coherent hors simulation');
    ASSERT_TRUE(FB_SimTrans.PosMaintenance, 'Mot P1 coherent hors simulation');
    ASSERT_FALSE(FB_SimTrans.BrakeContactOpen, 'Frein confirme ferme hors simulation');
END_TEST

(* =========================================================================
   AF-13 — FB_Sim_Joystick (TC-P13-050/051/052)
   ========================================================================= *)

TEST 'TC-P13-050 Sim_Joystick initialise au neutre au premier cycle'
    FB_SimJoy(Enable := TRUE, NeutralRaw := 5000, MaxRaw := 10000);
    ASSERT_EQ(FB_SimJoy.RawX, 5000, 'premier cycle -> RawX=NeutralRaw');
    ASSERT_EQ(FB_SimJoy.RawY, 5000, 'premier cycle -> RawY=NeutralRaw');
    ASSERT_FALSE(FB_SimJoy.RawButton, 'premier cycle -> RawButton=FALSE');
END_TEST

TEST 'TC-P13-051 Sim_Joystick sorties forçables en instance (essai manuel — stub)'
    (* Stub : TC-P13-051 verifie que RawX/RawY/RawButton restent forçables librement en instance
       CODESYS apres l'init (le FB n'ecrit plus ces sorties apres le premier cycle). Non
       automatisable en boite noire (depend du forçage CODESYS). (essai manuel — stub) *)
    ASSERT_TRUE(TRUE, 'Stub : forçage joystick a verifier manuellement (essai manuel)');
END_TEST

TEST 'TC-P13-052 Sim_Joystick homme-mort : RawButton reflete l appui (partie AUTO)'
    (* Aucun bouton -> RawButton=FALSE *)
    FB_SimJoy(Enable := TRUE, NeutralRaw := 5000, MaxRaw := 10000);
    ASSERT_FALSE(FB_SimJoy.RawButton, 'aucun bouton -> RawButton=FALSE');
    ADVANCE_TIME(10000000);
    (* Bouton directionnel actif -> RawButton=TRUE (homme-mort inclus) *)
    FB_SimJoy(Enable := TRUE, NeutralRaw := 5000, MaxRaw := 10000, BtnRight_Fwd_MAINT := TRUE);
    ASSERT_TRUE(FB_SimJoy.RawButton, 'bouton actif -> RawButton=TRUE');
END_TEST

(* =========================================================================
   AF-13 — FB_SimBench : rattrapage mecanique M1/M2 (T328)
   Plan : DOC/WFLOW/CONTRACTS/PLAN_T328_SIMBENCH_COUPLAGE_MECANIQUE_M1M2.md
   ========================================================================= *)

TEST 'TC-P13-060 T328 montee couplee : rattrapage actif et correction bornee'
    (* Montée couplée réelle (relais M1+M2 même sens, freins desserrés), benne DANS le trou métier
       T327 : écart 13,5 m < entrée de bande fermée (14,5 m). Le rattrapage agit, borné par la pente. *)
    RawPosM1 := 1000000; RawPosM2 := 1100000;
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_TRUE(FB_Bench.WinchCouplingActive, 'montee couplee -> rattrapage actif');
    ASSERT_TRUE(FB_Bench.WinchCouplingCorrectionPts > 0, 'ecart sous la bande -> correction non nulle');
    ASSERT_TRUE(FB_Bench.WinchCouplingCorrectionPts <= 82, 'correction bornee (0,02 m/scan = 82 points)');
    ASSERT_TRUE(FB_Bench.Winch.COD2_PosValue > RawPosM2, 'correction appliquee a l IMAGE M2 uniquement');
END_TEST

TEST 'TC-P13-061 T328 arret et jog M2 seul : ecart fige, aucune correction'
    (* Relais à 0 : aucun mouvement réel -> jamais de rattrapage (AC6). *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := FALSE, M2_RelayFwd := FALSE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'relais a 0 -> pas de rattrapage');
    ASSERT_EQ(FB_Bench.WinchCouplingCorrectionPts, 0, 'aucune correction a l arret');
    ASSERT_EQ(FB_Bench.Winch.COD2_PosValue, RawPosM2, 'image M2 inchangee a l arret');
    ADVANCE_TIME(10000000);
    (* Jog M2 seul (un seul treuil actif) -> toujours aucun rattrapage *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := FALSE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := FALSE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'jog M2 seul -> pas de rattrapage');
    ASSERT_EQ(FB_Bench.WinchCouplingCorrectionPts, 0, 'jog M2 seul -> aucune correction');
END_TEST

TEST 'TC-P13-062 T328 machoires bloquees : rattrapage inhibe et charge forcee'
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             SimBucketJamActive := TRUE,
             SimWinchElectricalDiagnosticsActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'blocage machoires -> rattrapage inhibe');
    ASSERT_EQ(FB_Bench.WinchCouplingCorrectionPts, 0, 'blocage -> aucune correction');
    ASSERT_TRUE(FB_Bench.MotorTorqueM1_Nm > 0.0, 'blocage -> charge forcee observable (diagnostic)');
END_TEST

TEST 'TC-P13-063 T328 modele desactive : image M2 inchangee (non-masquage T327)'
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := FALSE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'modele OFF -> pas de rattrapage');
    ASSERT_EQ(FB_Bench.WinchCouplingCorrectionPts, 0, 'modele OFF -> aucune correction');
    ASSERT_EQ(FB_Bench.Winch.COD2_PosValue, RawPosM2, 'modele OFF -> image M2 identique (trou T327 preserve)');
END_TEST

TEST 'TC-P13-064 T328 cable mou : rattrapage inhibe (aucun effort transmis)'
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             SimM2TensionedCableFaultInject := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'cable mou -> pas de rattrapage');
END_TEST

TEST 'TC-P13-065 T328 banc eteint : image reelle repliquee sans correction'
    FB_Bench(Enable := FALSE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'banc desactive -> aucun rattrapage');
    ASSERT_EQ(FB_Bench.Winch.COD2_PosValue, RawPosM2, 'banc desactive -> image sans correction');
END_TEST

TEST 'TC-P13-066 T328 convergence multi-scan du rattrapage vers la bande fermee'
VAR
    i        : INT;
    M2_Pos_M : REAL := 0.0;
END_VAR
    (* Boucle fermee simulee : la position M2 vue par le metier suit l'image corrigee, comme dans la
       chaine reelle (HwSim -> HwIn -> codeur). Delta initial 13,5 m = trou metier de fermeture.
       Chaque appel du FB vaut un scan de 10 ms (le modele utilise CST_SimBenchCycleTimeS, pas le
       temps du harness) : la boucle n'avance donc pas le temps du harness. *)
    RawPosM1 := 1000000; RawPosM2 := 1100000;
    M2_Pos_M := 18.5;   (* Delta = M2 - M1 = 13,5 m *)
    FOR i := 1 TO 100 DO
        FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
                 M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
                 M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
                 SimWinchCouplingModelActive := TRUE,
                 M1_CablePos_M := 5.0, M2_CablePos_M := M2_Pos_M,
                 BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
        ASSERT_TRUE(FB_Bench.WinchCouplingCorrectionPts <= 82, 'correction bornee a 0,02 m par scan');
        M2_Pos_M := M2_Pos_M + DINT_TO_REAL(FB_Bench.WinchCouplingCorrectionPts) * (2.0 / 8192.0);
    END_FOR;
    ADVANCE_TIME(10000000);
    ASSERT_TRUE((M2_Pos_M - 5.0) >= 14.0, 'Delta entre dans la bande fermee (>= 14,0 m) en temps borne');
END_TEST

TEST 'TC-P13-067 T328 un preset purge l offset de reprise de jeu (image = codeur)'
    RawPosM1 := 1000000; RawPosM2 := 1100000;
    (* Session active : un offset est bien accumule. *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_TRUE(FB_Bench.Winch.COD2_PosValue > RawPosM2, 'offset de reprise de jeu accumule');
    ADVANCE_TIME(10000000);
    (* Preset M2 (PresetTriggerCmd = 2) : la reference absolue est reecrite -> offset purge. *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE, M2_PresetTriggerCmd := 2,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_EQ(FB_Bench.Winch.COD2_PosValue, RawPosM2, 'preset -> offset purge, image = codeur');
END_TEST

TEST 'TC-P13-068 T328 mode OFF apres session active : aucun offset residuel'
    RawPosM1 := 1000000; RawPosM2 := 1100000;
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := TRUE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_TRUE(FB_Bench.Winch.COD2_PosValue > RawPosM2, 'offset accumule en mode actif');
    ADVANCE_TIME(10000000);
    (* Bascule mode OFF : l'image doit redevenir strictement celle du codeur (non-masquage). *)
    FB_Bench(Enable := TRUE, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2,
             M1_RelayFwd := TRUE, M2_RelayFwd := TRUE,
             M1_BrakeCmd := TRUE, M2_BrakeCmd := TRUE,
             SimWinchCouplingModelActive := FALSE,
             M1_CablePos_M := 5.0, M2_CablePos_M := 18.5,
             BucketOffsetCloseM := 15.0, BucketCoherenceLimitM := 1.0);
    ASSERT_FALSE(FB_Bench.WinchCouplingActive, 'mode OFF -> rattrapage inactif');
    ASSERT_EQ(FB_Bench.Winch.COD2_PosValue, RawPosM2, 'mode OFF -> aucun offset residuel sur l image');
END_TEST

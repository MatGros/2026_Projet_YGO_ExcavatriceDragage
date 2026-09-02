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

TEST 'TC-P13-013 SimBench M3_StatusWordSim bit0 retombe a l arret'
    FB_Bench(Enable := TRUE, M3_ReqTremie := TRUE, M3_ReqMaintenance := FALSE, M3_SpeedCmd_Pct := 50.0, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0087, 'M3 en mouvement -> StatusWord 0x0087');
    ADVANCE_TIME(10000000);
    FB_Bench(Enable := TRUE, M3_ReqTremie := FALSE, M3_ReqMaintenance := FALSE, M3_SpeedCmd_Pct := 0.0, RawPosM1 := RawPosM1, RawPosM2 := RawPosM2);
    ASSERT_EQ(FB_Bench.Translation.M3_StatusWord, 16#0080, 'M3 a l arret -> StatusWord 0x0080 (bit0 retombe)');
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

TEST 'TC-P13-040 Sim_Translation progression publie des mots thermometre valides'
    (* Direction=0 : reste sur Tremie (11111) *)
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosTremie, 'init Tremie -> PosTremie=TRUE');
    ASSERT_TRUE(FB_SimTrans.PosMaintenance, 'init Tremie -> PosMaintenance=TRUE');
    ADVANCE_TIME(10000000);
    (* Direction=-1 : progresse vers Maintenance *)
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosTremie, 'pos 6m -> PosTremie=FALSE');
    ASSERT_TRUE(FB_SimTrans.PosP2, 'pos 6m -> PosP2=TRUE');
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosP2, 'pos 18m -> PosP2=FALSE');
    ASSERT_TRUE(FB_SimTrans.PosP1, 'pos 18m -> PosP1=TRUE');
END_TEST

TEST 'TC-P13-041 Sim_Translation Direction +1/-1/0'
    (* Direction=0 : maintient la position (Tremie) *)
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosTremie, 'Direction=0 -> reste sur Tremie');
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosTremie, 'Direction=0 -> position maintenue');
    (* Direction=-1 : progresse vers Maintenance *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosTremie, 'Direction=-1 -> quitte Tremie');
    (* Direction=+1 : revient vers Tremie *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := TRUE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := TRUE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosTremie, 'Direction=+1 -> retour vers Tremie');
END_TEST

TEST 'TC-P13-042 Sim_Translation position bornee [Tremie, Maintenance]'
    (* Direction=-1 longtemps -> atteint Maintenance et s y bloque (00000) *)
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosMaintenance, 'a Maintenance -> PosMaintenance=FALSE (00000)');
    (* Encore des scans -> reste a Maintenance, pas de depassement *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosMaintenance, 'reste a Maintenance, pas de depassement');
    (* Direction=+1 : revient vers Tremie *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := TRUE, ReqMaintenance := FALSE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosMaintenance, 'retour vers Tremie -> PosMaintenance=TRUE');
END_TEST

TEST 'TC-P13-043 Sim_Translation Enable=FALSE reinitialise sur Tremie'
    (* Progresse vers Maintenance *)
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosTremie, 'a P2 -> PosTremie=FALSE');
    (* Enable=FALSE -> reinit interne sur Tremie, sorties neutralisees *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := FALSE, ReqTremie := FALSE, ReqMaintenance := TRUE, SpeedTgt_Pct := 100.0, FullTravelTimeS := 0.1);
    ASSERT_FALSE(FB_SimTrans.PosTremie, 'Enable=FALSE -> sorties neutralisees');
    (* Re-Enable -> demarre proprement sur Tremie (11111) *)
    ADVANCE_TIME(10000000);
    FB_SimTrans(Enable := TRUE, ReqTremie := FALSE, ReqMaintenance := FALSE, SpeedTgt_Pct := 0.0, FullTravelTimeS := 0.1);
    ASSERT_TRUE(FB_SimTrans.PosTremie, 're-Enable -> reinit sur Tremie (PosTremie=TRUE)');
    ASSERT_TRUE(FB_SimTrans.PosMaintenance, 're-Enable -> reinit sur Tremie (PosMaintenance=TRUE)');
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

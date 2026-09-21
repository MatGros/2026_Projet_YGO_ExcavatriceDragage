SETUP
VAR
    harness         : FB_TestHarness_PRG_07;
    acqData         : ST_AcquisitionInterPrg;
    modesAuth       : ST_Modes_Autorisations;
    winchData       : ST_WinchInterPrg;
    translationData : ST_TranslationInterPrg;
    emergencyState  : ST_Safety_Emergency_State;
    faultCore       : FB_FaultCore;
END_VAR
END_SETUP

TEST 'PRG_07_Supervision : Formatage Bandeau IHM Mode Manuel Sans Defaut'
    // 1. Contexte : Mode Manuel N1
    modesAuth.Mode := E_Mode.MAINT_N1;
    modesAuth.JoystickWinchSelectArbitrated := 0; // Couplé
    
    // 2. Stimulus : Machine saine, puissance engagée
    acqData.Joystick.DeadmanArmed := TRUE;
    acqData.Joystick.AtNeutralXY := TRUE;
    winchData.WinchM1Safety.DescendPermit := TRUE;
    winchData.WinchM1Safety.AscentPermit := TRUE;
    winchData.WinchM2Safety.DescendPermit := TRUE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    
    // 3. Exécution PRG_07
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE,
        EmergencyChainClosed := TRUE,
        PowerCutOffActive := FALSE
    );
    
    // 4. Vérification de la présence d'un bandeau IHM cohérent
    ASSERT_TRUE(harness.Banner.GlobalContextText <> '', 'Contexte global IHM renseigne');
END_TEST

TEST 'PRG_07_Supervision : Remontee Alarme Bandeau sur SafeStop Treuil'
    // Stimulus : SafeStop actif sur Treuil M1 avec défaut codeur
    winchData.WinchM1Safety.SafeStop := TRUE;
    winchData.WinchM1Safety.Error := TRUE;
    winchData.WinchM1Safety.ErrorEncoder := TRUE;
    winchData.WinchM1Safety.ErrorId := 16#0002; // Perte codeur

    
    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE
    );
    
    // Vérification de la notification d'alarme dans le bandeau
    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'Alarme active visible sur le bandeau IHM');
END_TEST

TEST 'PRG_07_Supervision : Coupure de Puissance AU (PowerCutOff) visible sur le bandeau'
    // Stimulus : coupure brutale de puissance propagee (PRG_06 -> barriere AU)
    winchData.WinchM1Safety.PowerCutOff := TRUE;
    winchData.WinchM2Safety.PowerCutOff := TRUE;

    harness(
        AcqData := acqData,
        ModesAuth := modesAuth,
        WinchData := winchData,
        TranslationData := translationData,
        PowerContactorEngaged := TRUE,
        PowerCutOffActive := TRUE
    );

    // Coupure de puissance = action operateur PRIORITAIRE sur le bandeau
    // (PowerCutOff alimente OperatorActionText, pas AlarmBanner.HasAlarm qui ne
    //  reflete que les Error* decodes).
    ASSERT_TRUE(harness.Banner.OperatorActionText <> '', 'Action operateur renseignee en coupure puissance');
    ASSERT_TRUE(harness.Banner.GlobalContextText <> '', 'Contexte IHM reste renseigne meme en coupure');
END_TEST

TEST 'PRG_07_Supervision : T255-D limite basse cable M1 visible (alarme + action autorisee)'
    // Etat explicite et complet des entrees dont depend l'assertion. (Le harnais regenere
    // un setup par cas : ce n'est pas une precaution contre une fuite d'etat, mais la
    // garantie que le scenario teste est entierement pose.)
    winchData.WinchM1Safety.Error := TRUE;            // vu par AnyFaultActive (Safety.Error)
    winchData.WinchM1Safety.ErrorId := 16#0040;       // bit6 = limite basse cable (vue LIVE)
    winchData.WinchM1Safety.CableLimitDescent := TRUE;
    winchData.WinchM1Safety.DescendPermit := FALSE;   // interlock : descente interdite
    winchData.WinchM1Safety.AscentPermit := TRUE;     // remontee = action autorisee
    winchData.WinchM1Safety.SafeStop := FALSE;
    winchData.WinchM1Safety.PowerCutOff := FALSE;
    winchData.WinchM1Safety.ErrorEncoder := FALSE;
    winchData.WinchM2Safety.CableLimitDescent := FALSE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    acqData.Joystick.DeadmanArmed := TRUE;            // operateur arme, n agit pas
    acqData.Joystick.AtNeutralXY := TRUE;
    modesAuth.Mode := E_Mode.MAINT_N1;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);
    ADVANCE_TIME(600000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);

    // AC2 : au meme scan, la cause est nommee ET l'action autorisee est indiquee
    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'T255-D : la cause active doit etre au carrousel');
    ASSERT_EQ(harness.Banner.AlarmBanner.Count, 1, 'T255-D : une seule alarme attendue');
    ASSERT_EQ(harness.Banner.AlarmBanner.Text, '1/1 [M1] Limite basse cable atteinte',
              'T255-D : libelle alarme citant le treuil et la limite');
    ASSERT_EQ(harness.Banner.OperatorActionText, '[TREUIL] Limite basse cable M1 - remonter',
              'T255-D : action autorisee (remontee) indiquee sans commande de descente');
END_TEST

TEST 'PRG_07_Supervision : T255-D limite basse cable M2 visible (alarme + action autorisee)'
    winchData.WinchM2Safety.Error := TRUE;
    winchData.WinchM2Safety.ErrorId := 16#0040;
    winchData.WinchM2Safety.CableLimitDescent := TRUE;
    winchData.WinchM2Safety.DescendPermit := FALSE;
    winchData.WinchM2Safety.AscentPermit := TRUE;
    winchData.WinchM2Safety.SafeStop := FALSE;
    winchData.WinchM2Safety.PowerCutOff := FALSE;
    winchData.WinchM1Safety.CableLimitDescent := FALSE;
    winchData.WinchM1Safety.AscentPermit := TRUE;
    // Le harnais regenere un setup par cas : chaque entree utilisee est reposee ici.
    acqData.Joystick.DeadmanArmed := TRUE;            // operateur arme, n agit pas
    acqData.Joystick.AtNeutralXY := TRUE;
    modesAuth.Mode := E_Mode.MAINT_N1;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);
    ADVANCE_TIME(600000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, PowerContactorEngaged := TRUE,
            EmergencyChainClosed := TRUE, PowerCutOffActive := FALSE);

    ASSERT_TRUE(harness.Banner.AlarmBanner.HasAlarm, 'T255-D : la cause active doit etre au carrousel');
    ASSERT_EQ(harness.Banner.AlarmBanner.Count, 1, 'T255-D : une seule alarme attendue');
    ASSERT_EQ(harness.Banner.AlarmBanner.Text, '1/1 [M2] Limite basse cable atteinte',
              'T255-D : libelle alarme citant le treuil M2 et la limite');
    ASSERT_EQ(harness.Banner.OperatorActionText, '[TREUIL] Limite basse cable M2 - remonter',
              'T255-D : action autorisee indiquee pour M2');
END_TEST

(* ═══════════════════════════════════════════════════════════════════════
   ACQUITTEMENT AUTOMATIQUE BORNE — demarrage a froid et rearmement AU
   ───────────────────────────────────────────────────────────────────────
   Conventions de balayage (les assertions restent hors de toute boucle) :
   1) 1 appel harness(...) = 1 scan. Le temps n'avance que par ADVANCE_TIME.
   2) La tempo d'intervalle entre impulsions est une tempo qui s'auto-rearme :
      son entree doit retomber puis remonter pour repartir. Un pas de temps de
      1 s, suivi de 2 appels sans avance de temps, emule donc les 100 scans
      reels separant deux impulsions, et separe chaque impulsion par au moins
      un scan ou le signal est retombe.
   3) Le comptage porte sur les FRONTS de FaultMachineReset_IHM : la porte
      unique d'acquittement (sources operateur + 2 campagnes bornees).
   ═══════════════════════════════════════════════════════════════════════ *)

TEST 'TC-T367-101 Demarrage a froid : campagne automatique une fois le transitoire E/S termine'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    (* Transitoire de boot : au moins un module E/S n'est pas RUNNING. *)
    acqData.InputModules.Fault := TRUE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    (* Scan 1 : transitoire en cours -> aucune impulsion. *)
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Scan 2 : transitoire toujours en cours -> aucune impulsion. *)
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Transitoire E/S en cours : aucune impulsion automatique');

    (* Scan 3 : transitoire E/S termine -> tempo de stabilisation arme. *)
    acqData.InputModules.Fault := FALSE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Tempo de stabilisation non ecoulee : aucune impulsion');

    (* Scan 4 : tempo ecoulee -> la campagne s'ouvre et emet sa 1re impulsion. *)
    ADVANCE_TIME(3000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Scan 5 : retombee du signal d'impulsion. *)
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Scans 6 a 8 : 1 s plus tard, 2e impulsion (puis retombee et rearmement). *)
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Scans 9 a 11 : 1 s plus tard, 3e impulsion (puis retombee et rearmement). *)
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* AC1 : campagne de 3 impulsions, puis arret definitif. *)
    ASSERT_TRUE(pulseCount >= 1, 'Transitoire termine : campagne de boot emise');
    ASSERT_TRUE(pulseCount <= 3, 'Campagne de boot bornee a 3 impulsions au plus');
    ASSERT_EQ(pulseCount, 3, 'Campagne de boot : 3 impulsions espacees d environ 1 s');
    ASSERT_TRUE(harness.BootAckFinished, 'Campagne de boot terminee apres ses impulsions');
END_TEST

TEST 'TC-T367-102 Campagne bornee : aucune quatrieme impulsion, arret definitif'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(3000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 3, 'Campagne de boot : exactement 3 impulsions');
    ASSERT_TRUE(harness.BootAckFinished, 'Campagne de boot terminee');

    (* Le temps continue de s'ecouler : aucune impulsion supplementaire ne doit sortir. *)
    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(10000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(20000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 3, 'Aucune 4e impulsion : campagne arretee definitivement');
END_TEST

TEST 'TC-T367-103 SECURITE : une cause encore Active reste latchee apres la campagne'
VAR
    pulseCount        : INT;
    resetPrev         : BOOL;
    powerContactor    : BOOL;
    operatorReset     : BOOL;
    faultLatchedAfter : BOOL;
    faultClearedAfter : BOOL;
END_VAR
    (* Cause de defaut a acquitter, encore presente pendant toute la campagne. *)
    faultCore.Causes[0].Active   := TRUE;
    faultCore.Causes[0].Latching := TRUE;
    faultCore.Causes[0].Texte    := 'Cause persistante';

    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(3000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* AC5 : la campagne a bien eu lieu, et pourtant le latch est toujours arme —
       la cause encore Active le re-arme dans le scan meme de l'impulsion. *)
    ASSERT_EQ(pulseCount, 3, 'Campagne de boot jouee avec une cause encore active');
    faultLatchedAfter := faultCore.Fault.Latched;
    ASSERT_TRUE(faultLatchedAfter, 'Cause encore Active : le latch reste arme (aucun masquage)');
    ASSERT_TRUE(faultCore.Fault.Error, 'Cause encore Active : la vue LIVE reste publiee');
    ASSERT_EQ(faultCore.Fault.LatchedId, 1, 'Bit de la cause persistante toujours latche');

    (* Complement de non-vacuite : une fois la cause disparue, l'acquittement efface bien
       le latch (l'impulsion n'est pas inerte : elle n'efface que les artefacts sans cause). *)
    faultCore.Causes[0].Active := FALSE;
    operatorReset := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    faultCore(Enable := TRUE, Reset := harness.FaultMachineReset_IHM);
    faultClearedAfter := faultCore.Fault.Latched;
    ASSERT_FALSE(faultClearedAfter, 'Cause disparue : l acquittement efface le latch');
END_TEST

TEST 'TC-T367-104 Fonctionnement etabli : aucune impulsion automatique'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    (* Prologue : fenetre de demarrage a froid refermee, machine etablie. *)
    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Scan suivant : la fenetre de demarrage a froid est echue. *)
    ADVANCE_TIME(31000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_TRUE(harness.BootAckFinished, 'Fenetre de demarrage echue : campagne terminee');
    ASSERT_EQ(pulseCount, 0, 'Aucune impulsion automatique en fonctionnement etabli');

    (* Le contacteur s'engage sans geste operateur : aucune impulsion automatique. *)
    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Balayage de scans supplementaires, sans aucune action operateur. *)
    ADVANCE_TIME(10000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(10000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Aucune impulsion automatique hors des deux campagnes');

    (* AC6/AC7 : seule une action operateur produit alors une impulsion. *)
    operatorReset := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 1, 'Action operateur : impulsion emise (source existante intacte)');
END_TEST

TEST 'TC-T367-105 Transitoire E/S non termine : aucune impulsion'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    (* Au moins un module E/S reste KO sur toute la fenetre. *)
    acqData.InputModules.Fault := TRUE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(10000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Au-dela de la borne de temps : la campagne se termine SANS aucune impulsion. *)
    ADVANCE_TIME(20000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_TRUE(harness.BootAckFinished, 'Campagne terminee malgre un module E/S KO');

    (* Le module revient RUNNING apres la fenetre : toujours aucune impulsion, sinon un
       acquittement automatique sortirait en fonctionnement etabli. *)
    acqData.InputModules.Fault := FALSE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 0, 'Transitoire E/S non termine : aucune impulsion automatique');
END_TEST

TEST 'TC-T367-106 Rearmement AU : sequence observee puis front contacteur => campagne'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
    sawRearmPulse  : BOOL;
    sawBootPulse   : BOOL;
END_VAR
    (* Prologue : fenetre de demarrage a froid refermee, aucune campagne en cours. *)
    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    sawRearmPulse  := FALSE;
    sawBootPulse   := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(31000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Aucune impulsion avant le geste operateur');

    (* Geste operateur : une sequence d'armement demarre (front sur Step). *)
    emergencyState.Step := 1;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Sequence seule : aucune impulsion avant la confirmation contacteur');

    (* Confirmation par le contacteur de puissance : front montant -> campagne. *)
    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Fin de la sequence d'armement, contacteur toujours engage. *)
    emergencyState.Step := 0;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    sawBootPulse  := sawBootPulse OR harness.BootAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* AC3 : campagne bornee, emise par la voie REARMEMENT (et non par celle du boot). *)
    ASSERT_EQ(pulseCount, 3, 'Rearmement confirme : campagne de 3 impulsions');
    ASSERT_TRUE(sawRearmPulse, 'Impulsion emise par la campagne de rearmement AU');
    ASSERT_FALSE(sawBootPulse, 'Aucune impulsion de la campagne de demarrage a froid');
END_TEST

TEST 'TC-T367-107 SECURITE : front du contacteur SANS sequence operateur => aucune impulsion'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    (* Prologue : fenetre de demarrage a froid refermee. *)
    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(31000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;
    ASSERT_EQ(pulseCount, 0, 'Aucune impulsion avant tout front contacteur');

    (* Le contacteur s'engage SANS aucun geste operateur (Step reste a 0) : relachement
       d'un AU avec maintien repris, demarrage a chaine fermee, bypass de mise en service. *)
    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Le contacteur retombe puis se reengage encore sans geste operateur. *)
    powerContactor := FALSE;
    emergencyState.ContactorOk := FALSE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 0, 'Front contacteur sans sequence operateur : aucune impulsion');
END_TEST

TEST 'TC-T367-108 Apres une campagne, une nouvelle campagne exige un nouveau geste operateur'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
    sawRearmPulse  : BOOL;
END_VAR
    (* Prologue : fenetre de demarrage a froid refermee. *)
    acqData.InputModules.Fault := FALSE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    sawRearmPulse  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(31000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Premiere campagne : geste operateur (sequence) puis confirmation du contacteur. *)
    emergencyState.Step := 1;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* La sequence d'armement se poursuit : Step reste NON NUL pendant et apres la campagne —
       c'est la situation ou un simple ETAT de sequence ne prouve plus aucun geste nouveau. *)
    emergencyState.Step := 4;
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(1000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    sawRearmPulse := sawRearmPulse OR harness.RearmAckPulse;
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_TRUE(sawRearmPulse, 'Premiere campagne emise par la voie rearmement');
    ASSERT_EQ(pulseCount, 3, 'Premiere campagne : 3 impulsions puis arret');
    ASSERT_TRUE(emergencyState.Step <> 0, 'Scenario : la sequence d armement est encore en cours');

    (* Le contacteur retombe puis se reengage SANS nouveau geste operateur : le geste
       precedent a ete consomme, aucune nouvelle campagne ne doit sortir. *)
    powerContactor := FALSE;
    emergencyState.ContactorOk := FALSE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 3, 'Nouvelle campagne refusee sans nouveau geste operateur');

    (* Variante discriminante : la sequence d'armement est TOUJOURS en cours (Step non nul),
       mais aucun NOUVEAU demarrage de sequence n'a eu lieu -> le front du contacteur reste
       sans effet. Un simple etat de sequence (Step <> 0) ne suffit donc jamais a lui seul. *)
    emergencyState.Step := 5;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 3, 'Sequence en cours sans nouveau demarrage : aucune impulsion');
END_TEST

TEST 'TC-T367-109 SECURITE : geste perime apres un armement echoue => aucune impulsion sur un front machine tardif'
VAR
    pulseCount     : INT;
    resetPrev      : BOOL;
    powerContactor : BOOL;
    operatorReset  : BOOL;
END_VAR
    (* Prologue : le transitoire d'E/S n'est JAMAIS termine -> la campagne de boot ne peut emettre
       aucune impulsion (AC2) ; sa fenetre se referme quand meme et la campagne de boot est close. *)
    acqData.InputModules.Fault := TRUE;
    emergencyState.Step        := 0;
    emergencyState.ContactorOk := FALSE;
    powerContactor := FALSE;
    operatorReset  := FALSE;
    pulseCount     := 0;
    resetPrev      := FALSE;

    ADVANCE_TIME(31000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 0, 'Aucune impulsion tant qu aucun geste operateur n a eu lieu');

    (* Geste operateur : une sequence d'armement DEMARRE... *)
    emergencyState.Step := 1;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* ... et ECHOUE : le contacteur ne confirme JAMAIS, la sequence retombe au repos. *)
    emergencyState.Step := 0;
    ADVANCE_TIME(2000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Plus de 10 s plus tard : un front du contacteur PUREMENT MACHINE (relachement d'un AU avec
       maintien repris). Le geste perime ne doit PAS etre consomme -> AUCUN acquittement. *)
    ADVANCE_TIME(12000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    powerContactor := TRUE;
    emergencyState.ContactorOk := TRUE;
    ADVANCE_TIME(10000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    (* Laisse tourner une campagne si elle se declenchait a tort (3 impulsions espacees de 1 s). *)
    ADVANCE_TIME(5000000000);
    harness(AcqData := acqData, ModesAuth := modesAuth, WinchData := winchData,
            TranslationData := translationData, EmergencyState := emergencyState,
            PowerContactorEngaged := powerContactor, EmergencyChainClosed := TRUE,
            PowerCutOffActive := FALSE, BtnResetMachine := operatorReset);
    IF harness.FaultMachineReset_IHM AND NOT resetPrev THEN pulseCount := pulseCount + 1; END_IF;
    resetPrev := harness.FaultMachineReset_IHM;

    ASSERT_EQ(pulseCount, 0, 'Geste perime : aucune impulsion sur un front machine tardif');
END_TEST

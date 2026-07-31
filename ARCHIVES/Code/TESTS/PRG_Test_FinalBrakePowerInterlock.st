(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_Test_FinalBrakePowerInterlock — Tests PLC préparés Lot 3A
   ───────────────────────────────────────────────────────────────
   ⚠️ Non exécuté : appeler uniquement dans un projet de test CODESYS.
   ⏱️ Les temporisations sont celles réelles des FB. Les résultats restent
      des preuves préparées, pas une exécution CODESYS déclarée.
   🏗️ Précondition statique : les instances production sont exclusivement dans
      PRG_10_Outputs_LD ; ce test unitaire compose les FB directement.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_Test_FinalBrakePowerInterlock
VAR
    InterlockM1 : FB_WinchOutputInterlock_LD;
    InterlockM2 : FB_WinchOutputInterlock_LD;
    InterlockM3 : FB_TranslationOutputInterlock_LD;
    ScenarioStep : INT;
    ResetRequest : BOOL;
    EnableRequest : BOOL := TRUE;
    PowerContactorEngagedRequest : BOOL := TRUE;
    SafeStopRequest : BOOL;
    BrakeConfirmed : BOOL;
    ContactorsReleased : BOOL;
    RequestedStepM1 : INT;
    RequestedStepM2 : INT;
    RequestedContactorM1_1 : BOOL;
    RequestedContactorM1_2 : BOOL;
    RequestedContactorM1_3 : BOOL;
    RequestedContactorM1_4 : BOOL;
    RequestedContactorM2_1 : BOOL;
    RequestedContactorM2_2 : BOOL;
    RequestedContactorM2_3 : BOOL;
    RequestedContactorM2_4 : BOOL;
    M2TableMappingPreservedOk : BOOL;
    RequestedDriveControlWord : WORD := 0;
    ScenarioDone : BOOL;
    ScenarioFailed : BOOL;

    M1BrakeTimeoutOk : BOOL;
    M1EnableLatchHeldOk : BOOL;
    M1EmergencyStopLatchHeldOk : BOOL;
    M1EnableRecoveryOk : BOOL;
    M1EmergencyStopRecoveryOk : BOOL;
    M1ResetOk : BOOL;
    M1StepProgressionOk : BOOL := TRUE;
    M1TransitionViolation : BOOL;
    M1PreviousAuthorizedStep : INT;

    M2BrakeTimeoutOk : BOOL;
    M2EnableLatchHeldOk : BOOL;
    M2EmergencyStopLatchHeldOk : BOOL;
    M2FeedbackOffWaitOk : BOOL;
    M2RestartDelayOk : BOOL;
    StopGateOk : BOOL := TRUE;

    M3BrakeGateOk : BOOL;
    M3BrakeTimeoutOk : BOOL;
    M3EnableLatchHeldOk : BOOL;
    M3EmergencyStopLatchHeldOk : BOOL;
    M3ResetWordOk : BOOL;
    M3PostResetHeldOk : BOOL;
    M3RestartAfterNewRequestOk : BOOL;
    M3EnableGateOk : BOOL;
    M3EmergencyStopGateOk : BOOL;
    M3SafeStopRampOk : BOOL;

    // Test end-to-end FB_Winch : la temporisation métier T#1s500ms reste
    // distincte du filet final T#1s250ms de FB_WinchOutputInterlock_LD.
    WinchBusiness : FB_Winch;
    WinchBusinessTable : ST_SpeedStepTable;
    WinchBusinessPreviousStep : INT;
    WinchBusinessTransitionViolation : BOOL;
    WinchBusinessDelayObserved : BOOL;
    WinchBusinessTestPassed : BOOL;

    // Chaîne réelle M3 : FB_Translation produit la rampe, puis l'interlock _LD
    // applique la frontière finale. Ce scénario n'injecte jamais une fréquence.
    TranslationIntegration : FB_Translation;
    TranslationIntegrationInterlock : FB_TranslationOutputInterlock_LD;
    TranslationIntegrationSafeStop : BOOL;
    TranslationIntegrationInitialFreqHz : REAL;
    TranslationIntegrationRampObservedOk : BOOL;
    TranslationIntegrationFinalFollowOk : BOOL;
END_VAR

// ── FB_Winch : temporisation métier réelle T#1s500ms ───────────────────
// Table cumulative minimale valide pour faire atteindre le palier 5 en test.
WinchBusinessTable.P1R1 := FALSE; WinchBusinessTable.P1R2 := FALSE;
WinchBusinessTable.P1R3 := FALSE; WinchBusinessTable.P1R4 := FALSE;
WinchBusinessTable.P2R1 := TRUE;  WinchBusinessTable.P2R2 := FALSE;
WinchBusinessTable.P2R3 := FALSE; WinchBusinessTable.P2R4 := FALSE;
WinchBusinessTable.P3R1 := TRUE;  WinchBusinessTable.P3R2 := TRUE;
WinchBusinessTable.P3R3 := FALSE; WinchBusinessTable.P3R4 := FALSE;
WinchBusinessTable.P4R1 := TRUE;  WinchBusinessTable.P4R2 := TRUE;
WinchBusinessTable.P4R3 := TRUE;  WinchBusinessTable.P4R4 := FALSE;
WinchBusinessTable.P5R1 := TRUE;  WinchBusinessTable.P5R2 := TRUE;
WinchBusinessTable.P5R3 := TRUE;  WinchBusinessTable.P5R4 := TRUE;
WinchBusinessTable.StepThreshold_Pct := [10.0, 20.0, 30.0, 40.0, 100.0];
WinchBusiness(
    Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
    StartStop := TRUE, SafeStop := FALSE, ForbidDescent := FALSE, ForbidAscent := FALSE,
    Direction := 1, SpeedRefPct := 100.0, SpeedStepTable := WinchBusinessTable,
    FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
    BypassContactorCheck := TRUE, BypassGlobal := FALSE,
    Homed := TRUE, HomingSuspect := FALSE, CablePosM := 0.0
);
IF WinchBusiness.StepNumber <> WinchBusinessPreviousStep THEN
    IF (WinchBusiness.StepNumber <> (WinchBusinessPreviousStep + 1))
       OR (WinchBusiness.BusinessStepDelayElapsed < T#1s500ms) THEN
        WinchBusinessTransitionViolation := TRUE;
    END_IF;
    WinchBusinessPreviousStep := WinchBusiness.StepNumber;
END_IF;
IF (WinchBusiness.RequestedStep > WinchBusiness.StepNumber)
   AND (WinchBusiness.BusinessStepDelayElapsed >= T#1s500ms) THEN
    WinchBusinessDelayObserved := TRUE;
END_IF;
WinchBusinessTestPassed := (WinchBusiness.StepNumber = 5)
                           AND WinchBusinessDelayObserved
                           AND NOT WinchBusinessTransitionViolation;

// Les trois interlocks sont appelés chaque cycle. La machine de scénario
// modifie uniquement les entrées pour rendre les transitions observables.
InterlockM1(
    Enable := EnableRequest,
    Reset := ResetRequest,
    PowerContactorEngaged := PowerContactorEngagedRequest,
    SafeStop := SafeStopRequest,
    BrakeReleaseRequest := (RequestedStepM1 > 0),
    BrakeCommandOpenConfirmed := BrakeConfirmed,
    FwdRevSpeedFeedbackOff := ContactorsReleased,
    RequestedRelayFwd := TRUE,
    RequestedRelayRev := FALSE,
    RequestedContactor1 := RequestedContactorM1_1,
    RequestedContactor2 := RequestedContactorM1_2,
    RequestedContactor3 := RequestedContactorM1_3,
    RequestedContactor4 := RequestedContactorM1_4,
    RequestedStep := RequestedStepM1
);
InterlockM2(
    Enable := EnableRequest,
    Reset := ResetRequest,
    PowerContactorEngaged := PowerContactorEngagedRequest,
    SafeStop := SafeStopRequest,
    BrakeReleaseRequest := (RequestedStepM2 > 0),
    BrakeCommandOpenConfirmed := BrakeConfirmed,
    FwdRevSpeedFeedbackOff := ContactorsReleased,
    RequestedRelayFwd := TRUE,
    RequestedRelayRev := FALSE,
    RequestedContactor1 := RequestedContactorM2_1,
    RequestedContactor2 := RequestedContactorM2_2,
    RequestedContactor3 := RequestedContactorM2_3,
    RequestedContactor4 := RequestedContactorM2_4,
    RequestedStep := RequestedStepM2
);
// Le mapping contacteurs reste celui produit par FB_Winch. Cas volontairement
// non cumulatif M2 : seul R4 est demandé au palier 2 (ex. table Benne dynamique).
// L'interlock doit le transmettre à l'identique dès que le palier est autorisé.

InterlockM3(
    Enable := EnableRequest,
    Reset := ResetRequest,
    PowerContactorEngaged := PowerContactorEngagedRequest,
    SafeStop := SafeStopRequest,
    BrakeReleaseRequest := (RequestedDriveControlWord = 1) OR (RequestedDriveControlWord = 2),
    BrakeCommandOpenConfirmed := BrakeConfirmed,
    // IEC SEL(G, IN0, IN1) : G=FALSE → demande normale (1), G=TRUE → reset AC600 (7).
    RequestedDriveControlWord := SEL((ScenarioStep = 95) OR (ScenarioStep = 96), RequestedDriveControlWord, 7),
    RequestedDriveFreqHz := 20.0
);

// Intégration réelle M3 : production par FB_Translation, puis filtre final _LD.
TranslationIntegration(
    Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, Mode := E_Mode.MAINT_N1,
    StartStop := (ScenarioStep >= 110) AND (ScenarioStep < 130),
    SafeStop := TranslationIntegrationSafeStop, Direction := 1, SpeedRefPct := 50.0,
    PositionSensorTarget := FALSE, SlowdownSensor := FALSE,
    LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
    DriveStatusWord := 16#0000, DriveActualFreqHz := 0.0,
    BypassContactorCheck := TRUE, BypassLimitSwitch := FALSE, BrakeFeedback := FALSE,
    CfgRampAccelRate := 100.0, CfgRampDecelNormalRate := 100.0, CfgRampDecelFastRate := 1000.0,
    DriveFreqScaleMaxHz := 60.0
);
TranslationIntegrationInterlock(
    Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE,
    SafeStop := TranslationIntegrationSafeStop,
    BrakeReleaseRequest := TranslationIntegration.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := TranslationIntegration.BrakeReleaseRequest,
    RequestedDriveControlWord := TranslationIntegration.RequestedDriveControlWord,
    RequestedDriveFreqHz := TranslationIntegration.RequestedDriveFreqHz
);

// Chaque hausse M1 doit être adjacente et ne peut apparaître qu'après T#1s250ms.
// StepDelayElapsed est capturé par l'interlock au scan exact de la transition.
IF (RequestedStepM1 = 5) AND (InterlockM1.AuthorizedStep <> M1PreviousAuthorizedStep) THEN
    IF (InterlockM1.AuthorizedStep <> (M1PreviousAuthorizedStep + 1))
       OR (InterlockM1.StepDelayElapsed < T#1s250ms) THEN
        M1TransitionViolation := TRUE;
    END_IF;
    M1PreviousAuthorizedStep := InterlockM1.AuthorizedStep;
END_IF;

ResetRequest := FALSE;
CASE ScenarioStep OF
    0: // Initialisation : frein serré, retours contacteurs retombés.
        BrakeConfirmed := FALSE;
        ContactorsReleased := TRUE;
        RequestedStepM1 := 0;
        RequestedStepM2 := 0;
        RequestedContactorM1_1 := FALSE; RequestedContactorM1_2 := FALSE;
        RequestedContactorM1_3 := FALSE; RequestedContactorM1_4 := FALSE;
        RequestedContactorM2_1 := FALSE; RequestedContactorM2_2 := FALSE;
        RequestedContactorM2_3 := FALSE; RequestedContactorM2_4 := FALSE;
        RequestedDriveControlWord := 0;
        ScenarioStep := 10;

    10: // M1/M2 : absence confirmation >500ms → défauts mémorisés, puissance nulle.
        RequestedStepM1 := 1;
        RequestedStepM2 := 1;
        RequestedContactorM1_1 := FALSE; // Palier 1 sans contacteur : table métier valide.
        RequestedContactorM2_1 := FALSE; RequestedContactorM2_2 := FALSE;
        RequestedContactorM2_3 := FALSE; RequestedContactorM2_4 := FALSE;
        IF InterlockM1.Error AND InterlockM2.Error THEN
            M1BrakeTimeoutOk := NOT InterlockM1.BrakeCmd AND (InterlockM1.AuthorizedStep = 0);
            M2BrakeTimeoutOk := NOT InterlockM2.BrakeCmd AND (InterlockM2.AuthorizedStep = 0);
            // Cas 1 : Enable retombe PENDANT les deux latch timeout.
            EnableRequest := FALSE;
            ScenarioStep := 11;
        END_IF;

    11: // Les deux latch timeout survivent à Enable=FALSE ; sorties strictement nulles.
        M1EnableLatchHeldOk := InterlockM1.Error AND InterlockM1.RestartInhibit
                               AND NOT InterlockM1.BrakeCmd AND (InterlockM1.AuthorizedStep = 0);
        M2EnableLatchHeldOk := InterlockM2.Error AND InterlockM2.RestartInhibit
                               AND NOT InterlockM2.BrakeCmd AND (InterlockM2.AuthorizedStep = 0);
        EnableRequest := TRUE;
        PowerContactorEngagedRequest := FALSE;
        ScenarioStep := 12;

    12: // Cas 2 séparé : les deux latch timeout survivent à PowerContactorEngaged=FALSE.
        M1EmergencyStopLatchHeldOk := InterlockM1.Error AND InterlockM1.RestartInhibit
                                      AND NOT InterlockM1.BrakeCmd AND (InterlockM1.AuthorizedStep = 0);
        M2EmergencyStopLatchHeldOk := InterlockM2.Error AND InterlockM2.RestartInhibit
                                      AND NOT InterlockM2.BrakeCmd AND (InterlockM2.AuthorizedStep = 0);
        PowerContactorEngagedRequest := TRUE;
        BrakeConfirmed := TRUE; // Cause disparue seulement après les deux gates.
        RequestedStepM1 := 0;
        RequestedStepM2 := 0;
        ScenarioStep := 20;

    20: // Front Reset conscient M1 après disparition de cause.
        ResetRequest := TRUE;
        ScenarioStep := 21;
    21: // Demande zéro obligatoire après Reset, puis vérification interlock toujours inhibé.
        M1ResetOk := NOT InterlockM1.Error;
        RequestedStepM1 := 0;
        M1EnableRecoveryOk := InterlockM1.RestartInhibit AND NOT InterlockM1.BrakeCmd;
        M1PreviousAuthorizedStep := InterlockM1.AuthorizedStep;
        ScenarioStep := 22;
    22: // Nouvelle demande distincte : Enable rétabli, retombée + T#900ms recommencent.
        RequestedStepM1 := 5;
        M1EmergencyStopRecoveryOk := InterlockM1.RestartInhibit OR (InterlockM1.AuthorizedStep = 0);
        ScenarioStep := 30;

    30: // M1 : capture chaque transition 0→1→2→3→4→5.
        IF InterlockM1.AuthorizedStep = 5 THEN
            M1StepProgressionOk := NOT M1TransitionViolation;
            RequestedStepM1 := 0;
            ContactorsReleased := FALSE;
            ScenarioStep := 40;
        END_IF;

    40: // M2 : retour NON retombé → attente explicite, aucun redémarrage.
        RequestedStepM2 := 2;
        // Cas table spécifique M2 : P2 = R4 seul, non cumulatif.
        RequestedContactorM2_1 := FALSE; RequestedContactorM2_2 := FALSE;
        RequestedContactorM2_3 := FALSE; RequestedContactorM2_4 := TRUE;
        M2FeedbackOffWaitOk := (InterlockM2.AuthorizedStep = 0)
                                AND NOT ContactorsReleased;
        ContactorsReleased := TRUE;
        ScenarioStep := 50;

    50: // M2 : après retour retombé, l'autorisation ne vient qu'après T#900ms.
        IF InterlockM2.AuthorizedStep = 2 THEN
            M2RestartDelayOk := M2FeedbackOffWaitOk
                                 AND (InterlockM2.RestartDelayElapsed >= T#900ms);
            M2TableMappingPreservedOk := NOT InterlockM2.Contactor1
                                         AND NOT InterlockM2.Contactor2
                                         AND NOT InterlockM2.Contactor3
                                         AND InterlockM2.Contactor4;
            RequestedStepM2 := 0;
            RequestedContactorM2_4 := FALSE;
            ScenarioStep := 60;
        END_IF;

    60: // Enable coupe immédiatement puissance/frein.
        EnableRequest := FALSE;
        ScenarioStep := 61;
    61:
        StopGateOk := StopGateOk AND NOT InterlockM1.BrakeCmd AND NOT InterlockM2.BrakeCmd
                      AND (InterlockM1.AuthorizedStep = 0) AND (InterlockM2.AuthorizedStep = 0);
        EnableRequest := TRUE;
        PowerContactorEngagedRequest := FALSE;
        ScenarioStep := 62;
    62: // PowerContactorEngaged coupe immédiatement puissance/frein.
        StopGateOk := StopGateOk AND NOT InterlockM1.BrakeCmd AND NOT InterlockM2.BrakeCmd
                      AND (InterlockM1.AuthorizedStep = 0) AND (InterlockM2.AuthorizedStep = 0);
        PowerContactorEngagedRequest := TRUE;
        SafeStopRequest := TRUE;
        ScenarioStep := 63;
    63: // SafeStop ne coupe pas l'interlock : la rampe rapide reste métier.
        // Ici la demande est déjà nulle : les sorties restent donc nulles sans exception _LD.
        StopGateOk := StopGateOk AND (InterlockM1.AuthorizedStep = 0) AND (InterlockM2.AuthorizedStep = 0);
        SafeStopRequest := FALSE;
        BrakeConfirmed := FALSE;
        RequestedDriveControlWord := 1; // Demande normale de marche M3.
        ScenarioStep := 90;

    90: // M3 : aucune fréquence/couple après pré-magnétisation sans confirmation.
        M3BrakeGateOk := (InterlockM3.DriveControlWord = 0) AND (InterlockM3.DriveFreqRefHz = 0.0);
        IF InterlockM3.Error THEN
            M3BrakeTimeoutOk := NOT InterlockM3.BrakeCmd AND InterlockM3.RestartInhibit;
            // Timeout M3 : les deux gates durs suivants ne doivent jamais masquer Error.
            EnableRequest := FALSE;
            ScenarioStep := 91;
        END_IF;

    91: // Timeout M3 persiste pendant Enable=FALSE, sorties sûres.
        M3EnableLatchHeldOk := InterlockM3.Error AND InterlockM3.RestartInhibit
                               AND (InterlockM3.DriveControlWord = 0)
                               AND (InterlockM3.DriveFreqRefHz = 0.0) AND NOT InterlockM3.BrakeCmd;
        EnableRequest := TRUE;
        PowerContactorEngagedRequest := FALSE;
        ScenarioStep := 92;

    92: // Timeout M3 persiste pendant PowerContactorEngaged=FALSE, sorties sûres.
        M3EmergencyStopLatchHeldOk := InterlockM3.Error AND InterlockM3.RestartInhibit
                                      AND (InterlockM3.DriveControlWord = 0)
                                      AND (InterlockM3.DriveFreqRefHz = 0.0) AND NOT InterlockM3.BrakeCmd;
        PowerContactorEngagedRequest := TRUE;
        BrakeConfirmed := TRUE; // Cause disparue après les deux gates.
        ScenarioStep := 95;

    95: // Reset variateur : SEL force word 7, fréquence toujours nulle.
        ResetRequest := TRUE;
        ScenarioStep := 96;
    96:
        M3ResetWordOk := (InterlockM3.DriveControlWord = 7) AND (InterlockM3.DriveFreqRefHz = 0.0);
        RequestedDriveControlWord := 1; // Demande maintenue : doit rester inhibée.
        ScenarioStep := 97;
    97:
        M3PostResetHeldOk := InterlockM3.RestartInhibit
                              AND (InterlockM3.DriveControlWord = 0)
                              AND (InterlockM3.DriveFreqRefHz = 0.0);
        RequestedDriveControlWord := 0; // Neutre explicite obligatoire.
        ScenarioStep := 98;
    98:
        RequestedDriveControlWord := 1; // Nouvelle demande après neutre.
        ScenarioStep := 99;
    99:
        M3RestartAfterNewRequestOk := NOT InterlockM3.RestartInhibit
                                      AND (InterlockM3.DriveControlWord = 1)
                                      AND (InterlockM3.DriveFreqRefHz > 0.0);
        EnableRequest := FALSE;
        ScenarioStep := 100;
    100: // M3 Enable=FALSE : mot, fréquence et frein en position sûre.
        M3EnableGateOk := (InterlockM3.DriveControlWord = 0)
                           AND (InterlockM3.DriveFreqRefHz = 0.0)
                           AND NOT InterlockM3.BrakeCmd;
        EnableRequest := TRUE;
        PowerContactorEngagedRequest := FALSE;
        ScenarioStep := 101;
    101: // M3 PowerContactorEngaged=FALSE : mot, fréquence et frein en position sûre.
        M3EmergencyStopGateOk := (InterlockM3.DriveControlWord = 0)
                                  AND (InterlockM3.DriveFreqRefHz = 0.0)
                                  AND NOT InterlockM3.BrakeCmd;
        PowerContactorEngagedRequest := TRUE;
        ScenarioStep := 110;

    110: // FB_Translation réel : attendre une fréquence amont et finale non nulles.
        IF TranslationIntegrationInterlock.DriveFreqRefHz > 0.0 THEN
            TranslationIntegrationInitialFreqHz := TranslationIntegrationInterlock.DriveFreqRefHz;
            TranslationIntegrationSafeStop := TRUE;
            ScenarioStep := 111;
        END_IF;
    111: // SafeStop : la rampe rapide est produite amont, la frontière _LD la suit.
        IF (TranslationIntegration.RequestedDriveFreqHz > 0.0)
           AND (TranslationIntegration.RequestedDriveFreqHz < TranslationIntegrationInitialFreqHz)
           AND (TranslationIntegrationInterlock.DriveFreqRefHz = TranslationIntegration.RequestedDriveFreqHz)
           AND ((TranslationIntegrationInterlock.DriveControlWord = 1)
                OR (TranslationIntegrationInterlock.DriveControlWord = 0)) THEN
            TranslationIntegrationRampObservedOk := TRUE;
        END_IF;
        IF TranslationIntegration.RequestedDriveFreqHz = 0.0 THEN
            TranslationIntegrationFinalFollowOk := (TranslationIntegrationInterlock.DriveControlWord = 0)
                                                   AND (TranslationIntegrationInterlock.DriveFreqRefHz = 0.0);
            TranslationIntegrationSafeStop := FALSE;
            ScenarioStep := 120;
        END_IF;
    120: // La durée du test métier dépend des TON réels : attendre le palier 5.
        IF WinchBusinessTestPassed THEN
            ScenarioDone := M1BrakeTimeoutOk AND M1ResetOk AND M1StepProgressionOk
                            AND M1EnableLatchHeldOk AND M1EmergencyStopLatchHeldOk
                            AND M1EnableRecoveryOk AND M1EmergencyStopRecoveryOk
                            AND M2BrakeTimeoutOk AND M2EnableLatchHeldOk AND M2EmergencyStopLatchHeldOk
                            AND M2FeedbackOffWaitOk AND M2RestartDelayOk AND M2TableMappingPreservedOk AND StopGateOk
                            AND M3BrakeGateOk AND M3BrakeTimeoutOk
                            AND M3EnableLatchHeldOk AND M3EmergencyStopLatchHeldOk AND M3ResetWordOk
                            AND M3PostResetHeldOk AND M3RestartAfterNewRequestOk
                            AND M3EnableGateOk AND M3EmergencyStopGateOk
                            AND TranslationIntegrationRampObservedOk AND TranslationIntegrationFinalFollowOk
                            AND WinchBusinessTestPassed;
            ScenarioFailed := NOT ScenarioDone;
        END_IF;
ELSE
    ScenarioFailed := TRUE;
END_CASE

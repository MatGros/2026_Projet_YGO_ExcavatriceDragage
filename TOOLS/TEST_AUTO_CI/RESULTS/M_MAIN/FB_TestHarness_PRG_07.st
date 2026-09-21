(* =======================================================================
   🧱 FB_TestHarness_PRG_07 : Banc d'essai unitaire pour PRG_07_Supervision
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_07_Supervision, consomme les bus de données
             de PRG_02 (Joystick/E-S), PRG_03 (Modes/Cycle), PRG_04 (Treuils/Benne)
             et PRG_05 (Translation), exécute le formateur de bandeau
             FB_Hmi_BannerFormatter et publie le bandeau IHM ST_HmiBanner.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_07
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_02 (Acquisition) ===
    AcqData                 : ST_AcquisitionInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_03 (Modes & Cycle) ===
    ModesAuth               : ST_Modes_Autorisations;
    
    // === 📥 Bus d'Entrée issus de PRG_04 (Treuils & Benne) ===
    WinchData               : ST_WinchInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_05 (Translation M3) ===
    TranslationData         : ST_TranslationInterPrg;
    
    // === 🛡️ État public de la chaîne AU (miroir de PRG_06_Outputs.EmergencyState) ===
    // Step : 0 = IDLE ; ContactorOk : contacteur de puissance confirmé engagé.
    EmergencyState          : ST_Safety_Emergency_State;

    // === 🛡️ Hardware & Sécurité Machine ===
    EmergencyChainClosed    : BOOL := TRUE;
    PowerContactorEngaged   : BOOL := TRUE;
    PowerCutOffActive       : BOOL := FALSE;
    BtnResetMachine         : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🖥️ Bandeau IHM Produit ===
    Banner                  : ST_HmiBanner;
    FaultMachineReset_IHM   : BOOL;

    // === 🚨 Campagnes d'acquittement automatique borné (miroir PRG_07 §1c-1) ===
    BootAckPulse            : BOOL; // Impulsion émise par la campagne de démarrage à froid
    RearmAckPulse           : BOOL; // Impulsion émise par la campagne de réarmement AU
    BootAckFinished         : BOOL; // Campagne de démarrage à froid terminée (arrêt définitif)
END_VAR

VAR
    instHmiBannerFormatter  : FB_Hmi_BannerFormatter;

    // === 🚨 Campagnes d'acquittement automatique borné (miroir PRG_07_Supervision §1c-1) ===
    // États LOCAUX NON RETAIN, comme dans le PROGRAM : une campagne de démarrage à froid
    // ne peut pas se relancer sans un nouveau démarrage à froid.
    BootInputTransientDone : BOOL;   // Transitoire d'E/S terminé (5 modules RUNNING)
    BootWindowTimer        : TON;    // Fenêtre de démarrage à froid (borne la campagne)
    BootSettleTimer        : TON;    // Tempo de stabilisation après le transitoire d'E/S
    BootAckWindowOpen      : BOOL;   // Fenêtre de démarrage à froid encore ouverte
    BootAckStart           : BOOL;   // Campagne de démarrage à froid à démarrer
    BootCampaignLastPulse  : BOOL;   // Dernière impulsion de la campagne de démarrage à froid
    BootCampaignEnded      : BOOL;   // Campagne de démarrage à froid close
    RearmSeqRunning        : BOOL;   // Une séquence d'armement AU est en cours (Step <> 0)
    RearmSeqStartEdge      : R_TRIG; // Front de démarrage d'une séquence d'armement
    RearmSeqSeen           : BOOL;   // Une séquence d'armement a démarré (geste opérateur)
    RearmGestureTimer      : TON;    // Durée de vie du geste d'armement (anti-mémoire périmée)
    ContactorOkEdge        : R_TRIG; // Front montant du contacteur de puissance
    RearmAckStart          : BOOL;   // Campagne de réarmement AU à démarrer
    RearmCampaignLastPulse : BOOL;   // Dernière impulsion de la campagne de réarmement
    AckCampaignActive      : BOOL;   // Une campagne d'acquittement automatique est en cours
    AckCampaignIsBoot      : BOOL;   // La campagne en cours est celle du démarrage à froid
    AckPulseSpacing        : TON;    // Intervalle entre deux impulsions d'une campagne
    AckPulseCount          : USINT;  // Impulsions déjà émises par la campagne en cours
    AckPulseRoom           : BOOL;   // La campagne en cours a encore le droit d'impulsion
    AckPulseDue            : BOOL;   // Échéance d'impulsion atteinte
    AckCampaignPulsing     : BOOL;   // La campagne en cours a le droit d'émettre maintenant
    AckPulseAllowed        : BOOL;   // Acquittement autorisé (fin du transitoire d'E/S en boot)
    AckPulse               : BOOL;   // Impulsion d'acquittement de la campagne en cours
END_VAR

VAR CONSTANT
    // === 🚨 ACQUITTEMENT AUTOMATIQUE — BORNES DE CAMPAGNE (mêmes valeurs que PRG_07) ===
    CST_AckBootWindow   : TIME  := T#30s;
    CST_AckBootSettle   : TIME  := T#3s;
    CST_AckPulseSpacing : TIME  := T#1s;
    CST_AckPulseMax     : USINT := 3;
    CST_RearmGestureTtl : TIME  := T#10s;  // Durée de vie d'un geste non confirmé (identique à PRG_07)
END_VAR

{region "Corps d'exécution PRG_07 encapsulé"}
// 1. Gestion Reset Machine
// §1c-1. Campagnes d'acquittement AUTOMATIQUE BORNE — miroir strict de PRG_07_Supervision.
// (a) DÉMARRAGE À FROID : aucune impulsion tant que le transitoire d'E/S n'est pas terminé,
//     puis temps de stabilisation ; la fenêtre de démarrage borne la campagne.
// (b) RÉARMEMENT AU : une séquence d'armement doit avoir réellement démarré (front de Step)
//     avant le front du contacteur de puissance — le seul front du contacteur ne suffit jamais.
BootInputTransientDone := NOT AcqData.InputModules.Fault;
BootWindowTimer(IN := TRUE, PT := CST_AckBootWindow);
BootAckWindowOpen := NOT BootWindowTimer.Q;
BootSettleTimer(IN := BootInputTransientDone AND NOT BootAckFinished, PT := CST_AckBootSettle);
BootAckStart := BootSettleTimer.Q AND NOT BootAckFinished AND BootAckWindowOpen;

RearmSeqRunning := (EmergencyState.Step <> 0);
RearmSeqStartEdge(CLK := RearmSeqRunning);
IF RearmSeqStartEdge.Q THEN
    RearmSeqSeen := TRUE;
END_IF;
ContactorOkEdge(CLK := EmergencyState.ContactorOk);
RearmAckStart := ContactorOkEdge.Q AND RearmSeqSeen;
IF RearmAckStart THEN
    RearmSeqSeen := FALSE; // geste consommé : une nouvelle campagne exige un nouveau geste
END_IF;
// Durée de vie du geste : un armement ÉCHOUÉ ne doit pas laisser une mémoire consommable plus tard
// par un front du contacteur purement machine (relâchement d'un AU, maintien repris).
RearmGestureTimer(IN := RearmSeqSeen AND NOT ContactorOkEdge.Q, PT := CST_RearmGestureTtl);
IF RearmGestureTimer.Q THEN RearmSeqSeen := FALSE; END_IF; // geste périmé : nouveau geste requis

IF (BootAckStart OR RearmAckStart) AND NOT AckCampaignActive THEN
    AckCampaignActive := TRUE;
    AckCampaignIsBoot := BootAckStart;
    AckPulseCount     := 0;
END_IF;

AckPulseSpacing(IN := AckCampaignActive AND NOT AckPulseSpacing.Q, PT := CST_AckPulseSpacing);
AckPulseAllowed := TRUE;
IF AckCampaignIsBoot THEN
    AckPulseAllowed := BootInputTransientDone;
END_IF;
AckPulseRoom       := AckPulseCount < CST_AckPulseMax;
AckPulseDue        := (AckPulseCount = 0) OR AckPulseSpacing.Q;
AckCampaignPulsing := AckCampaignActive AND AckPulseAllowed AND AckPulseRoom;
AckPulse           := AckCampaignPulsing AND AckPulseDue;
IF AckPulse THEN
    AckPulseCount := AckPulseCount + 1;
END_IF;
BootAckPulse  := AckPulse AND AckCampaignIsBoot;
RearmAckPulse := AckPulse AND NOT AckCampaignIsBoot;

BootCampaignLastPulse := AckCampaignActive AND AckCampaignIsBoot AND (AckPulseCount >= CST_AckPulseMax);
BootCampaignEnded     := (NOT BootAckWindowOpen) OR BootCampaignLastPulse;
IF NOT BootAckFinished AND BootCampaignEnded THEN
    BootAckFinished := TRUE;
    IF AckCampaignIsBoot THEN
        AckCampaignActive := FALSE;
    END_IF;
END_IF;

RearmCampaignLastPulse := AckCampaignActive AND (NOT AckCampaignIsBoot) AND (AckPulseCount >= CST_AckPulseMax);
IF RearmCampaignLastPulse THEN
    AckCampaignActive := FALSE;
END_IF;

// §1c-2. Porte unique d'acquittement machine
FaultMachineReset_IHM := BtnResetMachine OR BootAckPulse OR RearmAckPulse;

// 2. Formatage Bandeau IHM
instHmiBannerFormatter(
    Enable                := TRUE,
    SimulationModeActive  := FALSE,
    CurrentMode           := ModesAuth.Mode,
    BothAxesCoupled       := (ModesAuth.JoystickWinchSelectArbitrated = 0),
    WinchSelected         := ModesAuth.JoystickWinchSelectArbitrated,
    CycleStep             := E_AutoCycleStep.AX0_REPOS,
    CycleStateStr         := 'X0_PREPARATION',
    CycleErrorId          := 16#0000,
    CycleStepAtError      := E_AutoCycleStep.AX0_REPOS,
    MachineHomingStep     := 0,
    MachineHomingInstruction := '',

    
    BypassGlobalActive    := FALSE,
    BypassWinchM1Active   := FALSE,
    BypassWinchM2Active   := FALSE,
    BypassTranslation     := FALSE,
    BypassSyncActive      := FALSE,
    SyncDegradedActive    := FALSE,
    LegalLimitReached     := FALSE,
    EmergencyChainClosed  := EmergencyChainClosed,
    PowerContactorEngaged := PowerContactorEngaged,
    PowerCutOffActiveAny  := PowerCutOffActive,
    SafeStopActive        := WinchData.WinchM1Safety.SafeStop OR WinchData.WinchM2Safety.SafeStop,
    DescendPermit         := WinchData.WinchM1Safety.DescendPermit AND WinchData.WinchM2Safety.DescendPermit,
    AscentPermit          := WinchData.WinchM1Safety.AscentPermit AND WinchData.WinchM2Safety.AscentPermit,
    BucketIsOpen          := WinchData.BucketState.MechState.IsOpen,
    BucketIsClosed        := WinchData.BucketState.MechState.IsClosed,
    DiveActive            := FALSE,
    TopLimitReached       := FALSE,
    WinchBothMotionDirection := 0,
    M1LogicRequestDirection     := 0,
    M2LogicRequestDirection     := 0,
    CycleRequestDirection       := 0,
    DeadmanArmed          := AcqData.Joystick.DeadmanArmed,
    JoystickAtNeutral     := AcqData.Joystick.AtNeutralXY,
    CycleAutoBusy         := FALSE,
    WinchM1Safety         := WinchData.WinchM1Safety,
    WinchM2Safety         := WinchData.WinchM2Safety,
    TranslationSafety     := TranslationData.TranslationSafety,
    BucketErrorId         := 16#0000,
    SyncErrorId           := 16#0000,
    DiveErrorId           := 16#0000,
    ExtractionErrorId     := 16#0000,
    EmergencyErrorId      := 16#0000,
    RedundancyTestFailed  := FALSE,
    EmergencyArmingFailed := FALSE,
    AlarmHoldTime         := T#1s
);

Banner := instHmiBannerFormatter.Banner;
{endregion}
END_FUNCTION_BLOCK

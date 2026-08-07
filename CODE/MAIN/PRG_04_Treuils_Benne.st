(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_04_Treuils_Benne — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4 (après PRG_03_Modes_Cycle).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF_Partie-10_Fonction_Winch_v2.0.md ; DOC/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Treuils_Benne

VAR_OUTPUT
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    KoboldContactorCmdArbitrated : BOOL;
    WinchM1StateHMI : ST_WinchState;
    WinchM2StateHMI : ST_WinchState;
    WinchM1SafetyHMI : ST_SafetyWinch;
    WinchM2SafetyHMI : ST_SafetyWinch;
    SyncStateHMI : ST_SyncState;
    BucketStateHMI : ST_BucketHMIState;
END_VAR

VAR
    StubMachineEnableN1 : BOOL := TRUE;

    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instSafetyWinchM1 : FB_Safety_Winch;   // 🆕 2026-08-05 : audit sécurité M3 — M1/M2 avaient 0 mécanisme actif
    instSafetyWinchM2 : FB_Safety_Winch;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;
    instDiveSearch : FB_DiveSearch;
    instExtractionSequence : FB_ExtractionSequence;

    MaintenanceMotionRequestActive : BOOL;
    MaintenanceMotionDirection     : INT;
    MaintenanceMotionSpeed_Pct     : REAL;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;
    // 🆕 2026-08-07 : mode "vidage à la trémie" — verrouille descente treuils (P1/Maintenance
    // uniquement) et pilote l'ouverture benne quand on demande DOWN à la trémie (MAINT_N1/N2
    // uniquement, même périmètre que instDiveSearch/instExtractionSequence).
    DumpAtTremieActive             : BOOL;
    DumpAtTremieAssistActive       : BOOL; // Sous-condition Mode MAINT_N1/N2 (assist réellement active)
    DumpAtTremieBucketOpenArmed    : BOOL; // CmdOpen_IHM déclenché par ce mode (diagnostic)

    // 🆕 2026-08-07 (Fiche 01, demande client) : séquencement automatique benne en pilotage
    // couplé (both) normal — descente uniquement benne ouverte, montée uniquement benne
    // fermée. Distinct de DumpAtTremie/DiveSearch/ExtractionSequence (fonctionnement normal,
    // pas une assistance MAINT_N1/N2 dédiée). Réutilise MaintenanceMotionRequestActive/
    // MaintenanceMotionDirection (§1 ci-dessus) : déjà exactement "mouvement couplé (both)
    // demandé" dans les 2 modes (joystick Select=0, ou BtnWinchBothUp/Down) — mêmes variables
    // déjà utilisées par instBucket/instDiveSearch/instExtractionSequence, aucune nouvelle
    // détection à inventer.
    CoupledDiveBucketOpenArmed     : BOOL;  // CmdOpen_IHM déclenché par ce mécanisme (diagnostic IHM)
    CoupledMotionBlockedByBucket   : BOOL;  // 🔴 2026-08-07 : garde-fou direct -- voir REX ci-dessous §3
    CoupledAscentBucketCloseArmed  : BOOL;  // CmdClose_IHM déclenché par ce mécanisme (diagnostic IHM)
    BucketBusyRiseEdge             : R_TRIG; // Détecte le début d'une action benne (Busy monté)
    BucketBusyFallEdge             : F_TRIG; // Détecte la fin d'une action benne (Busy retombé)
    ControlAscentArmedForThisClose : BOOL;   // Mémorise si LA fermeture en cours a été armée par ce mécanisme
    ControlAscentActive            : BOOL;   // Phase vitesse contrôlée en cours (diagnostic IHM)
    ControlAscentStartM1PosM       : REAL;
    ControlAscentStartM2PosM       : REAL;

    M1_StartStop_Active     : BOOL;
    M1_Direction_Active     : INT;
    M1_SpeedRef_Active      : REAL;

    M2_StartStop_Active     : BOOL;
    M2_Direction_Active     : INT;
    M2_SpeedRef_Active      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    SpeedGuardEnableM1 : BOOL := FALSE;
    SpeedGuardEnableM2 : BOOL := FALSE;

    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;

    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    ForbidDescentM1_Raw     : BOOL;
    ForbidDescentM2_Raw     : BOOL;
    ForbidAscentM1_Raw      : BOOL;
    ForbidAscentM2_Raw      : BOOL;
    ForbidAscentM1_Active   : BOOL;
    ForbidAscentM2_Active   : BOOL;

    BenneBusyFallEdge     : F_TRIG;

    // 🆕 2026-08-07 : FICHE 05 — Arrêt auto descente sur détection fond Kobold (pilotage normal)
    KoboldAutoStopRiseEdge  : R_TRIG;
    KoboldAutoStopFallEdge  : F_TRIG;
    KoboldImmersionConfirmed: BOOL;
    KoboldBottomTouchLatched: BOOL;
    ForbidDescentDiveBucketClosed : BOOL; // 🆕 2026-08-07 (10) : mode Dive actif + benne pas ouverte -- interdit descente
    ForbidAscentExtractionBottomNotConfirmed : BOOL; // 🆕 2026-08-07 (11) : mode Extraction actif + fond pas confirmé -- interdit montée

    // 🆕 2026-08-07 (9) : bypass simplifié séquence FB_DiveSearch (demande client) -- front montant
    // Kobold pendant une descente couplée confirme directement le fond, sans passer par les
    // préconditions strictes de FB_DiveSearch (benne ouverte, DiveStartMin_M, fenêtre immersion).
    // FB_DiveSearch continue de tourner en parallèle, inchangée (KoboldMeasureEnable toujours câblé
    // dessus) -- ce bypass est un chemin ADDITIONNEL, pas un remplacement.
    BypassKoboldRiseEdge       : R_TRIG;
    BypassKoboldBottomTouched  : BOOL;

    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M2_LimitShift                : REAL;

    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescente  : INT;
END_VAR

// === 🪨 §1 INTENTION MAINTENANCE & ASSISTANTS ===

IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    // 🔴🔧 REX 2026-08-07 (audit, bug preexistant trouve avant Fiche benne) : ancienne version
    // affectait HwIn.Operator.JoyYRaw_ANA2 (valeur analogique BRUTE 0..10000, meme signal que
    // RawY sur instJoystick) directement a MaintenanceMotionDirection, alors que
    // FB_Bucket/FB_DiveSearch/FB_ExtractionSequence testent MotionDirection = 1/-1 EXACTEMENT.
    // Consequence : en mode TglJoystickMaster, la benne/les sequenceurs assistes ne pouvaient
    // JAMAIS demarrer via le joystick (seul le mode Boutons IHM, qui affecte bien 1/-1,
    // fonctionnait). Corrige : direction deja mise a l'echelle (-1/0/+1) par instJoystick.
    MaintenanceMotionDirection := PRG_02_Acquisition.instJoystick.AxisCmdY.Direction;
    MaintenanceMotionRequestActive := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw
                                     AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0);
    MaintenanceMotionSpeed_Pct := 100.0;
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        MaintenanceMotionDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        MaintenanceMotionDirection := -1;
    ELSE
        MaintenanceMotionDirection := 0;
    END_IF;
    MaintenanceMotionRequestActive := (MaintenanceMotionDirection <> 0);
    MaintenanceMotionSpeed_Pct := 100.0;
END_IF;

// 🆕 2026-08-07 : mode "vidage à la trémie" (verrouillage, demande client). Périmètre identique
// à instDiveSearch/instExtractionSequence : MAINT_N1/MAINT_N2 uniquement.
DumpAtTremieActive := GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie;
DumpAtTremieAssistActive := DumpAtTremieActive
    AND (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2);
GVL_IHM.DredgingAssist.State.DumpAtTremieArmed        := DumpAtTremieActive;
GVL_IHM.DredgingAssist.State.DumpAtTremieAssistActive := DumpAtTremieAssistActive;
GVL_IHM.DredgingAssist.State.DumpAtTremieAtTremie     := PRG_05_Translation.M3_AtTremieStable;

// 🔴🔧 REX 2026-08-07 (15) — retour terrain, BUG CONFIRMÉ : "OR _BucketState.IsOpen" annulait le
// forçage à CHAQUE scan, alors que confirmer "fond touché" se fait précisément PENDANT que la
// benne est encore ouverte (avant que l'extraction ne la ferme) -- condition backwards, rendait
// tout forçage manuel de TglBucketAtBottomConfirmed impossible en pratique. Retiré.
IF NOT (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1)) THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
    BypassKoboldBottomTouched := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

// 🆕 2026-08-07 (9) : bypass séquence DiveSearch -- front montant Kobold pendant une descente
// couplée = fond touché, directement (voir bandeau §1). Mêmes conditions de garde que la
// confirmation manuelle ci-dessus (MAINT_N1/N2, sous tension, pas de défaut, benne fermée --
// réutilise le bloc de clear commun juste au-dessus).
BypassKoboldRiseEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldContactFond_DI);
IF GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
   AND MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1)
   AND BypassKoboldRiseEdge.Q THEN
    BypassKoboldBottomTouched := TRUE;
END_IF;
GVL_IHM.DredgingAssist.State.BypassDiveActive          := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
GVL_IHM.DredgingAssist.State.BypassKoboldBottomTouched := BypassKoboldBottomTouched;

instDiveSearch(
    Enable := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BucketIsOpen := _BucketState.IsOpen,
    KoboldImmersed := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldContactFond_DI,
    M1Position_M := PRG_02_Acquisition.CablePosM1,
    M2Position_M := PRG_02_Acquisition.CablePosM2,
    PositionsValid := PRG_02_Acquisition.instEncoderAbsM1.EncoderAvailable AND NOT PRG_02_Acquisition.M1_EncoderIncoherent
                       AND PRG_02_Acquisition.instEncoderAbsM2.EncoderAvailable AND NOT PRG_02_Acquisition.M2_EncoderIncoherent,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M,
    // 🆕 2026-08-07 (14) : même toggle que le bypass bottom-confirmation -- réglages seuils pas
    // encore calibrés, saute WAIT_PRECONDITIONS entièrement le temps des essais.
    BypassPreconditions := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
);

// 🆕 2026-08-07 : publication IHM (était orpheline -- déclarée mais jamais écrite, voir
// GVL_IHM.DredgingAssist.State) — consommée ensuite par FB_TroubleshootingView (debug).
GVL_IHM.DredgingAssist.State.DiveReady            := instDiveSearch.Ready;
GVL_IHM.DredgingAssist.State.DiveBusy             := instDiveSearch.Busy;
GVL_IHM.DredgingAssist.State.DiveDone             := instDiveSearch.Done;
GVL_IHM.DredgingAssist.State.DiveError            := instDiveSearch.Error;
GVL_IHM.DredgingAssist.State.DiveErrorId          := instDiveSearch.ErrorId;
GVL_IHM.DredgingAssist.State.DiveState            := instDiveSearch.DiveState;
// 🔴🔧 REX 2026-08-07 (7) — retour terrain : affichage IHM ne reflétait que la détection Kobold
// (instDiveSearch), pas la confirmation manuelle (TglBucketAtBottomConfirmed) ni le bypass --
// alors que BottomPositionConfirmed (consommée par instExtractionSequence ci-dessous) fait bien
// le OR des trois. L'opérateur voyait "non confirmé" à l'IHM alors que le séquenceur considérait
// le fond confirmé -- affichage seul en cause, la logique de commande était correcte.
BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed OR BypassKoboldBottomTouched;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed := BottomPositionConfirmed;

instExtractionSequence(
    Enable := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := _BucketState.IsClosed,
    BucketBusy := instBucket.Busy,
    BucketError := instBucket.Error,
    WinchSyncError := instWinchSync.Error,
    M1Position_M := PRG_02_Acquisition.CablePosM1,
    M2Position_M := PRG_02_Acquisition.CablePosM2,
    M1MeasuredSpeedValid := PRG_02_Acquisition.M1_SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Acquisition.M2_SpeedValid,
    PositionsValid := PRG_02_Acquisition.instEncoderAbsM1.EncoderAvailable AND NOT PRG_02_Acquisition.M1_EncoderIncoherent
                       AND PRG_02_Acquisition.instEncoderAbsM2.EncoderAvailable AND NOT PRG_02_Acquisition.M2_EncoderIncoherent,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);
IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

// 🆕 2026-08-07 : publication IHM (voir DiveSearch ci-dessus, même correctif).
GVL_IHM.DredgingAssist.State.ExtractionReady   := instExtractionSequence.Ready;
GVL_IHM.DredgingAssist.State.ExtractionBusy    := instExtractionSequence.Busy;
GVL_IHM.DredgingAssist.State.ExtractionDone    := instExtractionSequence.Done;
GVL_IHM.DredgingAssist.State.ExtractionError   := instExtractionSequence.Error;
GVL_IHM.DredgingAssist.State.ExtractionErrorId := instExtractionSequence.ErrorId;
GVL_IHM.DredgingAssist.State.ExtractionState   := instExtractionSequence.ExtractionState;

// 🆕 2026-08-07 : une seule consigne opérateur conduite à la fois (doc §OperatorActionId) —
// aucun PRG_09 n'existe (jamais câblé), arbitrage fait ici : DiveSearch prioritaire si Busy,
// sinon ExtractionSequence si Busy, sinon la dernière connue reste affichée à titre informatif.
IF instDiveSearch.Busy THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := instDiveSearch.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction   := instDiveSearch.OperatorAction;
ELSIF instExtractionSequence.Busy THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := instExtractionSequence.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction   := instExtractionSequence.OperatorAction;
ELSE
    GVL_IHM.DredgingAssist.State.OperatorActionId := 0;
    GVL_IHM.DredgingAssist.State.OperatorAction   := '';
END_IF;

// 🆕 2026-08-07 (Fiche 01, demande client) : règle absolue en pilotage couplé (both) normal --
// descente autorisée UNIQUEMENT benne ouverte, montée UNIQUEMENT benne fermée. Réutilise
// MaintenanceMotionRequestActive/MaintenanceMotionDirection (§1) : déjà "mouvement couplé
// demandé" dans les 2 modes (joystick Select=0 exclut le pilotage unitaire M1/M2 seul,
// BtnWinchBothUp/Down exclut les boutons IHM individuels M1/M2). Jamais actif en SEMI_AUTO
// (mêmes conditions que le reste de ce §).
// 🔴🔧 REX 2026-08-07 (4) — coupe-circuit d'urgence (retour terrain, machine bloquée en butée
// M2_LimitShift). GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing (défaut FALSE) : si FALSE,
// ces 2 flags restent FALSE en permanence -- CmdOpen_IHM/CmdClose_IHM ne sont plus jamais armés
// par le mouvement couplé joystick, instBucket.Busy ne peut plus être déclenché QUE par action
// manuelle benne/DumpAtTremie/ExtractionSequence (comportement strictement identique à avant
// Fiche 01).
CoupledDiveBucketOpenArmed := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
    AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.SEMI_AUTO)
    AND MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1)
    AND NOT _BucketState.IsOpen;
CoupledAscentBucketCloseArmed := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
    AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.SEMI_AUTO)
    AND MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = 1)
    AND NOT _BucketState.IsClosed;

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    CmdBucketCloseArbitrated := FALSE;
ELSIF instExtractionSequence.BucketCloseRequest THEN
    CmdBucketCloseArbitrated := TRUE;
ELSIF CoupledAscentBucketCloseArmed THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
END_IF;

// 🔴🔧 REX 2026-08-07 (13) — retour terrain, urgence : instDiveSearch.KoboldMeasureEnable
// n'est TRUE que dans SEARCHING_IMMERSION/SEARCHING_BOTTOM, atteignables uniquement après
// WAIT_PRECONDITIONS (DiveStartMin_M/ImmersionUpper_M/ImmersionLower_M -- réglages pas encore
// calibrés). Avec le bypass (TglBypassDiveSearchSequence), le contacteur doit être piloté
// INDÉPENDAMMENT de ces préconditions dès qu'on descend réellement.
IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    KoboldContactorCmdArbitrated := FALSE;
ELSE
    KoboldContactorCmdArbitrated := instDiveSearch.KoboldMeasureEnable
        OR (GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
            AND MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1));
END_IF;


// === 🏗️ §2 COMMANDE DU BENNE (FB_Bucket) ===

// 🆕 2026-08-07 : en mode "vidage à la trémie" (MAINT_N1/N2, bit armé), une demande DOWN à
// la trémie arme l'ouverture benne au lieu de faire descendre M2 — le mouvement réel reste
// gouverné par MotionRequestActive/MotionDirection ci-dessous (rien ne bouge tant que
// l'opérateur ne pousse pas réellement DOWN) ; instBucket.Busy prend alors la main sur
// l'arbitrage M2 normal (mécanisme déjà existant, voir §3bis plus bas).
DumpAtTremieBucketOpenArmed := DumpAtTremieAssistActive AND PRG_05_Translation.M3_AtTremieStable;
GVL_IHM.DredgingAssist.State.DumpAtTremieBucketOpenArmed := DumpAtTremieBucketOpenArmed;

instBucket(
    Enable              := NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    CmdOpen_IHM         := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen OR DumpAtTremieBucketOpenArmed OR CoupledDiveBucketOpenArmed,
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection     := MaintenanceMotionDirection,
    CablePosM1          := PRG_02_Acquisition.CablePosM1,
    CablePosM2          := PRG_02_Acquisition.CablePosM2,
    HomedM1             := PRG_02_Acquisition.instHomingM1.Homed,
    HomedM2             := PRG_02_Acquisition.instHomingM2.Homed,
    M1_Busy             := instWinchM1.Busy,
    M2_Busy             := instWinchM2.Busy,
    ConfirmOpenPosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
    ConfirmClosePosition:= GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
    Config              := _BucketCfgPersist.Config,
    CfgTimeoutDuration     := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_03_Modes_Cycle.Auth.InhibitM1,
    InhibitM2           := PRG_03_Modes_Cycle.Auth.InhibitM2,
    BypassGlobal        := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global
);

// 🔴🔧 REX 2026-08-07 (retour terrain, TROU DE SÉCURITÉ RÉEL CONFIRMÉ SUR MACHINE) : la Fiche 01
// bloquait M1 UNIQUEMENT via "NOT instBucket.Busy" (voir M1_StartStop_Active/M2_StartStop_Active
// plus bas) -- en pariant que instBucket passerait bien en BUSY dès que CmdOpen_IHM/CmdClose_IHM
// est armé. Si instBucket a un DÉFAUT ACTIF (Error/SevereError, ex. timeout d'une tentative
// précédente), FB_Bucket refuse d'armer CloseReq/OpenReq (`AND NOT SevereError`) -- Busy reste
// FALSE en PERMANENCE, et plus RIEN ne bloque M1 ni M2 : confirmé en test réel, la benne restée
// ouverte n'empêchait plus la montée des 2 treuils après un 2e appui. Corrigé : blocage DIRECT,
// INDÉPENDANT de FB_Bucket -- si l'auto-séquencement a été armé (Coupled*Armed) mais que
// instBucket n'est PAS effectivement occupé à l'exécuter (Busy=FALSE, quelle qu'en soit la
// raison : défaut, précondition non remplie, timing), le mouvement couplé reste bloqué. Défense
// en profondeur : la règle tient même si FB_Bucket est en défaut, jamais uniquement "pariée" sur
// son bon fonctionnement.
CoupledMotionBlockedByBucket := (CoupledDiveBucketOpenArmed OR CoupledAscentBucketCloseArmed) AND NOT instBucket.Busy;

SyncMinorDeviation := (instWinchSync.ErrorId AND 16#0001) <> 16#0000;
SyncMinorDeviationBlocksUp   := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0);
SyncMinorDeviationBlocksDown := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0);

IF _CommunCfgPersist.WinchMaxStepAscent <= 0 THEN
    EffectiveMaxStepAscent := 5;
ELSE
    EffectiveMaxStepAscent := _CommunCfgPersist.WinchMaxStepAscent;
END_IF;

IF _CommunCfgPersist.WinchMaxStepDescente <= 0 THEN
    EffectiveMaxStepDescente := 3;
ELSE
    EffectiveMaxStepDescente := _CommunCfgPersist.WinchMaxStepDescente;
END_IF;


// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    M1_Direction_Active := 0;
    M1_StartStop_Active := FALSE;
    M1_SpeedRef_Active  := 0.0;
ELSE
    IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        // Mode Boutons IHM
        IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M1TreuilRetenue.Cmd.BtnUp THEN
            M1_Direction_Active := 1;
            M1_SpeedRef_Active  := 100.0;
        ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M1TreuilRetenue.Cmd.BtnDown THEN
            M1_Direction_Active := -1;
            M1_SpeedRef_Active  := 100.0;
        ELSE
            M1_Direction_Active := 0;
            M1_SpeedRef_Active  := 0.0;
        END_IF;
    ELSE
        // Mode Joystick Maître
        IF (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 1) THEN
            M1_Direction_Active := PRG_02_Acquisition.instJoystick.AxisCmdY.Direction;
            M1_SpeedRef_Active  := ABS(PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedRef);
        ELSE
            M1_Direction_Active := 0;
            M1_SpeedRef_Active  := 0.0;
        END_IF;
    END_IF;

    M1_StartStop_Active := (M1_Direction_Active <> 0) AND NOT instBucket.Busy
                            AND NOT CoupledMotionBlockedByBucket
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)))
                            AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.JoystickDeadmanArmed);
END_IF;

// 🔧 2026-08-07 (Fiche 01, demande client "jamais arrêter M2") : condition renforcée
// "instBucket.Busy AND instBucket.M2_StartStop" au lieu de "instBucket.Busy" seul. Sans le 2e
// terme, le scan où le benne atteint sa cible (M2_StartStop benne retombé à FALSE ce même
// scan, AVANT que Busy ne retombe le scan SUIVANT) forçait un arrêt M2 d'1 scan avant que
// l'arbitrage normal ne prenne le relais -- fenêtre de coupure dépendante du timing exact de
// la bascule Busy, pas garantie structurellement. Avec le 2e terme, ce scan tombe directement
// dans la branche ELSE (arbitrage normal) : si le mouvement couplé est toujours demandé, M2
// reçoit sa commande de continuité le MÊME scan, sans dépendre d'un timing de bascule.
IF instBucket.Busy AND instBucket.M2_StartStop THEN
    M2_StartStop_Active := instBucket.M2_StartStop;
    M2_Direction_Active := instBucket.M2_Direction;
    M2_SpeedRef_Active  := 15.0;
ELSE
    IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
        M2_Direction_Active := 0;
        M2_StartStop_Active := FALSE;
        M2_SpeedRef_Active  := 0.0;
    ELSE
        IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
            // Mode Boutons IHM
            IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M2TreuilBenne.Cmd.BtnUp THEN
                M2_Direction_Active := 1;
                M2_SpeedRef_Active  := 100.0;
            ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M2TreuilBenne.Cmd.BtnDown THEN
                M2_Direction_Active := -1;
                M2_SpeedRef_Active  := 100.0;
            ELSE
                M2_Direction_Active := 0;
                M2_SpeedRef_Active  := 0.0;
            END_IF;
        ELSE
            // Mode Joystick Maître
            IF (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2) THEN
                M2_Direction_Active := PRG_02_Acquisition.instJoystick.AxisCmdY.Direction;
                M2_SpeedRef_Active  := ABS(PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedRef);
            ELSE
                M2_Direction_Active := 0;
                M2_SpeedRef_Active  := 0.0;
            END_IF;
        END_IF;

        M2_StartStop_Active := (M2_Direction_Active <> 0)
                                AND NOT CoupledMotionBlockedByBucket
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)))
                                AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.JoystickDeadmanArmed);
    END_IF;
END_IF;

// 🔧 2026-08-07 (Fiche 01, demande client "jamais arrêter M2") : 2e mécanisme de coupure trouvé
// en plus de celui déjà corrigé §3 ci-dessus -- celui-ci forçait un arrêt INCONDITIONNEL de M1
// ET M2 à CHAQUE fin d'action benne (Busy retombé), y compris pendant un enchaînement
// ouverture/fermeture-puis-mouvement-couplé où le mouvement doit continuer sans coupure
// (affecte aussi ExtractionSequence.CLOSING_BUCKET->CONTROL_ASCENT, pas seulement la Fiche 01).
// Corrigé : ne force plus l'arrêt si un mouvement couplé est toujours activement demandé
// (MaintenanceMotionRequestActive), auquel cas l'arbitrage normal (§3, déjà corrigé) prend le
// relais sans interruption. Comportement inchangé pour toute fin d'action benne SANS mouvement
// couplé en cours (ouverture/fermeture manuelle isolée, bouton IHM) : l'arrêt reste forcé.
BenneBusyFallEdge(CLK := instBucket.Busy);
IF BenneBusyFallEdge.Q AND NOT (MaintenanceMotionRequestActive AND (MaintenanceMotionDirection <> 0)) THEN
    M1_StartStop_Active := FALSE;
    M2_StartStop_Active := FALSE;
END_IF;

// 🆕 2026-08-07 (Fiche 01, demande client) : après une fermeture benne armée PAR CE mécanisme
// (pas ExtractionSequence, qui a déjà sa propre phase CONTROL_ASCENT), la montée couplée qui
// enchaîne démarre en vitesse contrôlée (palier 1) sur ExtractionControlDistance_M (paramètre
// existant, réutilisé -- pas de nouveau réglage) avant de repasser en paliers normaux.
BucketBusyRiseEdge(CLK := instBucket.Busy);
IF BucketBusyRiseEdge.Q THEN
    ControlAscentArmedForThisClose := CoupledAscentBucketCloseArmed;
END_IF;
IF BucketBusyFallEdge.Q AND ControlAscentArmedForThisClose THEN
    ControlAscentActive := TRUE;
    ControlAscentStartM1PosM := PRG_02_Acquisition.CablePosM1;
    ControlAscentStartM2PosM := PRG_02_Acquisition.CablePosM2;
END_IF;
IF ControlAscentActive THEN
    IF (ABS(PRG_02_Acquisition.CablePosM1 - ControlAscentStartM1PosM) >= GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M)
       AND (ABS(PRG_02_Acquisition.CablePosM2 - ControlAscentStartM2PosM) >= GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M) THEN
        ControlAscentActive := FALSE;             // Distance de contrôle parcourue : paliers normaux
    ELSIF NOT (MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = 1)) THEN
        ControlAscentActive := FALSE;             // Montée relâchée/interrompue : annule la phase
    END_IF;
END_IF;


// === 🔄 §4 SYNCHRONISATION M1 / M2 ===

instWinchSync(
    Enable          := PRG_03_Modes_Cycle.Auth.SyncEnable AND NOT instBucket.Busy
                        AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1 AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset           := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode            := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM1      := PRG_02_Acquisition.CablePosM1,
    CablePosM2      := PRG_02_Acquisition.CablePosM2,
    HomedM1         := PRG_02_Acquisition.instHomingM1.Homed,
    HomedM2         := PRG_02_Acquisition.instHomingM2.Homed,
    SyncEnable      := PRG_03_Modes_Cycle.Auth.SyncEnable,
    CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
    ActiveOffsetM   := instBucket.ActiveOffsetM,
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4,
    BypassGlobal    := GVL_IHM.M1M2Sync.Bypass.Global
);

IF instBucket.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P1R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P1R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P1R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P2R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P2R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P2R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P2R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P3R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P3R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P3R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P3R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P4R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P4R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P4R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P4R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P5R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P5R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P5R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P5R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.StepThreshold_Pct := _WinchSpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := _WinchSpeedStepTable;
END_IF;


// === 🛑 §5 COUPLAGE CROISÉ & SÉCURITÉS ===

// 🆕 2026-08-07 (demande client) : la limite légale (profondeur min. autorisée) doit elle aussi
// bénéficier du ralentissement progressif avant arrêt (comme la limite câble physique), pas juste
// un arrêt sec (ForbidDescent, ajouté au lot précédent). Comme les 2 limites bornent la même
// direction (descente), on alimente FB_Winch.BottomLimitM avec la PLUS RESTRICTIVE des deux
// (MAX de 2 valeurs négatives = celle la moins profonde = atteinte en premier) : le ralentissement
// (FB_Winch §"RALENTISSEMENT AUTOMATIQUE SUR BORDURES") s'enclenche alors sur la bonne limite,
// légale ou câble, sans dupliquer le mécanisme.
IF _CommunCfgPersist.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(_WinchM1CfgPersist.CfgCableLimitDescent_M, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
    BottomLimitM2_Active := MAX(_WinchM2CfgPersist.CfgCableLimitDescent_M, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
ELSE
    BottomLimitM1_Active := _WinchM1CfgPersist.CfgCableLimitDescent_M;
    BottomLimitM2_Active := _WinchM2CfgPersist.CfgCableLimitDescent_M;
END_IF;

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/contacteurs/fin de course des DEUX treuils (VH_0800END,
// Local_Digital_IO) — pas de granularité par treuil possible, donc SafeStop des DEUX.
SafeStopM1_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000) OR instBucket.M1SlipDetected OR PRG_02_Acquisition.InputModuleFault;
SafeStopM2_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000) OR PRG_02_Acquisition.InputModuleFault;

// 🆕 2026-08-07 : FICHE 05 — Surveillance Kobold descente normale (hors FB_DiveSearch)
// 🔧 2026-08-07 (compil CODESYS, retour terrain) : "HwIn.Winch.M1M2_KoboldImmersed_DI" n'existe
// pas (ST_HwWinch n'a pas ce membre) -- corrigé vers le meme signal deja utilise par
// instDiveSearch ci-dessus (§1, ligne KoboldImmersed), HwIn.Machine.M1_M2_KoboldContactFond_DI.
KoboldAutoStopRiseEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldContactFond_DI);
KoboldAutoStopFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldContactFond_DI);

// Levée du verrou au neutre du joystick/boutons ou si toggle désactivé
IF PRG_02_Acquisition.instJoystick.AtNeutral OR NOT GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent THEN
    KoboldImmersionConfirmed := FALSE;
    KoboldBottomTouchLatched := FALSE;
END_IF;

// 🔧 2026-08-07 (revue Fiche 05) : MaintenanceMotionRequestActive ajouté -- sans lui, cette
// surveillance pouvait s'armer aussi en pilotage UNITAIRE M1 (Select=1), où MaintenanceMotionDirection
// reflète quand même l'axe joystick brut (seul MaintenanceMotionRequestActive exige Select=0).
// Hors scope de la fiche ("pendant une descente COUPLÉE normale") -- corrigé.
// Qualification immersion : front montant Kobold dans la fenêtre [ImmersionLower_M..ImmersionUpper_M]
IF GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent
   AND MaintenanceMotionRequestActive
   AND (MaintenanceMotionDirection = -1)
   AND _BucketState.IsOpen
   AND KoboldAutoStopRiseEdge.Q THEN
    IF (PRG_02_Acquisition.CablePosM1 <= _DredgingAssistCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.CablePosM1 >= _DredgingAssistCfgPersist.ImmersionLower_M)
       AND (PRG_02_Acquisition.CablePosM2 <= _DredgingAssistCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.CablePosM2 >= _DredgingAssistCfgPersist.ImmersionLower_M) THEN
        KoboldImmersionConfirmed := TRUE;
    END_IF;
END_IF;

// Détection fond : front descendant Kobold APRÈS immersion confirmée
IF KoboldAutoStopFallEdge.Q AND KoboldImmersionConfirmed THEN
    KoboldBottomTouchLatched := TRUE;
    KoboldImmersionConfirmed := FALSE;
END_IF;

// 🔴🔧 REX 2026-08-07 (10) — retour terrain, GAP RÉEL CONFIRMÉ : instDiveSearch.DescendPermit
// était calculé (FB_DiveSearch.st) mais JAMAIS consommé nulle part dans PRG_04/PRG_06 -- en
// mode Dive actif, rien n'empêchait réellement de descendre benne fermée, malgré la précondition
// FB_DiveSearch (BucketIsOpen requis pour READY_TO_DESCEND). Ajouté : interdiction directe et
// explicite, gardée par instDiveSearch.Enable (mode Dive réellement actif) -- indépendante du
// timing interne DescendPermit. Bloque uniquement si benne PAS confirmée ouverte.
ForbidDescentDiveBucketClosed := instDiveSearch.Enable AND MaintenanceMotionRequestActive
    AND (MaintenanceMotionDirection = -1) AND NOT _BucketState.IsOpen;

ForbidDescentM1_Raw := KoboldBottomTouchLatched OR ForbidDescentDiveBucketClosed;
ForbidDescentM2_Raw := KoboldBottomTouchLatched OR ForbidDescentDiveBucketClosed;

M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq OR (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2),
                      0.0,
                      (PRG_02_Acquisition.CablePosM1 + _BucketCfgPersist.Config.OffsetCloseM + 0.5)
                      - _WinchM2CfgPersist.CfgCableLimitAscent_M);

// 🆕 2026-08-05 (audit sécurité M3) : FB_Safety_Winch M1/M2 — 0 mécanisme actif avant ce lot.
// Instancié avant instWinchM1/M2 : MovementCommanded lit RelayFwd/RelayRev du scan précédent
// (même lag 1 scan accepté que M4/Translation, jamais sur Reset/SafeStop/PowerCutOff/sortie finale).
instSafetyWinchM1(
    Enable                 := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Auth.SyncEnable,
    JoystickOnline         := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational    := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.instEncoderAbsM1.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.instHomingM1.Busy,
    CablePosM              := PRG_02_Acquisition.CablePosM1,
    CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    Direction              := M1_Direction_Active,
    MovementCommanded      := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    Homed                  := PRG_02_Acquisition.instHomingM1.Homed,
    HomingSuspect          := PRG_02_Acquisition.instHomingM1.HomingSuspect,
    TopLimitM              := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.JoystickYNeutral,
    BenneHoldStillActive   := instBucket.Busy,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.CablePosM2 - instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Auth.InhibitM2,
    MeasuredSpeedMps       := PRG_02_Acquisition.M1_Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.M1_SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.M1_SpeedValid,
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := GVL_IHM.M1TreuilRetenue.Bypass.Process,
    // 🆕 2026-08-07 (demande client) : OR avec le bypass commun (Commun.Bypass) -- leve la
    // protection sur les 2 treuils simultanement pour le pilotage "both", sans retirer le
    // bypass individuel pour le pilotage a l'unite.
    BypassTopLimitSwitch   := GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch OR GVL_IHM.Commun.Bypass.TopLimitSwitch,
    BypassTopLimitSoftware := GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware OR GVL_IHM.Commun.Bypass.TopLimitSoftware,
    BypassCableLimitSwitch := GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch OR GVL_IHM.Commun.Bypass.CableLimitSwitch,
    BypassLimitLegal       := GVL_IHM.M1TreuilRetenue.Bypass.LimitLegal OR GVL_IHM.Commun.Bypass.LimitLegal,
    BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal,
    BypassMotorThermal     := GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal,
    BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M1TreuilRetenue.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.MecaE
);

instSafetyWinchM2(
    Enable                 := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Auth.SyncEnable,
    JoystickOnline         := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational    := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.instEncoderAbsM2.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.instHomingM2.Busy,
    CablePosM              := PRG_02_Acquisition.CablePosM2,
    CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    Direction              := M2_Direction_Active,
    MovementCommanded      := instWinchM2.RelayFwd OR instWinchM2.RelayRev,
    Homed                  := PRG_02_Acquisition.instHomingM2.Homed,
    HomingSuspect          := PRG_02_Acquisition.instHomingM2.HomingSuspect,
    TopLimitM              := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.JoystickYNeutral,
    BenneHoldStillActive   := FALSE,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.CablePosM1 + instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Auth.InhibitM1,
    MeasuredSpeedMps       := PRG_02_Acquisition.M2_Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.M2_SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.M2_SpeedValid,
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassSafety           := GVL_IHM.M2TreuilBenne.Bypass.Safety,
    BypassProcess          := GVL_IHM.M2TreuilBenne.Bypass.Process,
    // 🆕 2026-08-07 : OR avec le bypass commun (Commun.Bypass) -- voir M1 ci-dessus
    BypassTopLimitSwitch   := GVL_IHM.M2TreuilBenne.Bypass.TopLimitSwitch OR GVL_IHM.Commun.Bypass.TopLimitSwitch,
    BypassTopLimitSoftware := GVL_IHM.M2TreuilBenne.Bypass.TopLimitSoftware OR GVL_IHM.Commun.Bypass.TopLimitSoftware,
    BypassCableLimitSwitch := GVL_IHM.M2TreuilBenne.Bypass.CableLimitSwitch OR GVL_IHM.Commun.Bypass.CableLimitSwitch,
    BypassLimitLegal       := GVL_IHM.M2TreuilBenne.Bypass.LimitLegal OR GVL_IHM.Commun.Bypass.LimitLegal,
    BypassOperatorComm     := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M2TreuilBenne.Bypass.BrakeThermal,
    BypassMotorThermal     := GVL_IHM.M2TreuilBenne.Bypass.MotorThermal,
    BypassMecaA            := GVL_IHM.M2TreuilBenne.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M2TreuilBenne.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M2TreuilBenne.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M2TreuilBenne.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M2TreuilBenne.Bypass.MecaE
);

SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;
SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;
ForbidDescentM1_Raw := ForbidDescentM1_Raw OR instSafetyWinchM1.ForbidDescent;
ForbidDescentM2_Raw := ForbidDescentM2_Raw OR instSafetyWinchM2.ForbidDescent;

// 🆕 2026-08-07 (mode "vidage à la trémie", demande client) : descente M1 ET M2 interdite tant
// que M3 n'est pas à P1 (travail) ou en position Maintenance -- verrouille la séquence
// descente-treuil / translation pour se rapprocher d'un enchaînement automatique sûr.
GVL_IHM.DredgingAssist.State.DumpAtTremieDescentLocked :=
    DumpAtTremieAssistActive AND NOT (PRG_05_Translation.M3_AtP1Stable OR PRG_05_Translation.M3_AtMaintenanceStable);
IF GVL_IHM.DredgingAssist.State.DumpAtTremieDescentLocked THEN
    ForbidDescentM1_Raw := TRUE;
    ForbidDescentM2_Raw := TRUE;
END_IF;
// 🔴🔧 REX 2026-08-07 (11) — MÊME CLASSE DE BUG QUE (10) : instExtractionSequence.AscentPermit
// calculé (FB_ExtractionSequence.st) mais jamais consommé -- rien n'empêchait réellement de monter
// sans fond confirmé quand le mode Extraction est actif (Enable=TRUE) mais encore en
// WAIT_BOTTOM_CONFIRMATION. Restreint volontairement à CET état précis (pas READY_TO_CLOSE, où le
// fond est déjà confirmé par construction, ni CLOSING_BUCKET, où M1 est déjà bloqué par
// instBucket.Busy et M2 doit continuer sans coupure).
ForbidAscentExtractionBottomNotConfirmed := instExtractionSequence.Enable
    AND MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = 1)
    AND (instExtractionSequence.ExtractionState = E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION);

ForbidAscentM1_Raw  := instSafetyWinchM1.ForbidAscent OR ForbidAscentExtractionBottomNotConfirmed;
ForbidAscentM2_Raw  := instSafetyWinchM2.ForbidAscent OR ForbidAscentExtractionBottomNotConfirmed;

SafeStopM1_Active      := SafeStopM1_Raw      OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active      := SafeStopM2_Raw      OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
ForbidDescentM1_Active := ForbidDescentM1_Raw OR (instWinchSync.SyncActive AND ForbidDescentM2_Raw);
ForbidDescentM2_Active := ForbidDescentM2_Raw OR (instWinchSync.SyncActive AND ForbidDescentM1_Raw);
ForbidAscentM1_Active  := ForbidAscentM1_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM2_Raw);
ForbidAscentM2_Active  := ForbidAscentM2_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM1_Raw);


// === ⚙️ §6 EXÉCUTION FB_Winch (M1 & M2) ===

instWinchM1(
    Enable                  := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M1_StartStop_Active,
    SafeStop                := SafeStopM1_Active,
    ForbidDescent           := ForbidDescentM1_Active,
    ForbidAscent            := ForbidAscentM1_Active,
    Direction               := M1_Direction_Active,
    SpeedRefPct             := M1_SpeedRef_Active,
    SpeedStepTable          := _WinchSpeedStepTable,
    CfgMaxStepDescente      := EffectiveMaxStepDescente,
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep OR ControlAscentActive, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := NOT instWinchSync.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback,
    Homed                   := PRG_02_Acquisition.instHomingM1.Homed,
    HomingSuspect           := PRG_02_Acquisition.instHomingM1.HomingSuspect,
    CablePosM               := PRG_02_Acquisition.CablePosM1,
    TopLimitM               := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowdownMaxStep      := _CommunCfgPersist.WinchSlowdownMaxStep,
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

instWinchM2(
    Enable                  := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M2_StartStop_Active,
    SafeStop                := SafeStopM2_Active,
    ForbidDescent           := ForbidDescentM2_Active,
    ForbidAscent            := ForbidAscentM2_Active,
    Direction               := M2_Direction_Active,
    SpeedRefPct             := M2_SpeedRef_Active,
    SpeedStepTable          := M2_SpeedStepTableActive,
    // 🔴🔧 REX 2026-08-07 (16) — retour terrain, GAP CONFIRMÉ : instBucket.M2_ForceSlowSpeed
    // ("Bloque les contacteurs de vitesse de M2", commentaire FB_Bucket.st) n'était consommé que
    // pour substituer M2_SpeedStepTableActive -- ne plafonnait PAS réellement le palier autorisé
    // pendant CLOSING_BUCKET/ouverture benne. MaxStepAscent forçait déjà palier 1 pour
    // CONTROL_ASCENT (ForceMinSpeedStep) mais pas pendant le mouvement benne lui-même ;
    // CfgMaxStepDescente n'avait AUCUN plafond, jamais. Corrigé : les deux suivent maintenant
    // instBucket.M2_ForceSlowSpeed en plus des conditions existantes.
    CfgMaxStepDescente      := SEL(instBucket.M2_ForceSlowSpeed, EffectiveMaxStepDescente, 1),
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep OR ControlAscentActive OR instBucket.M2_ForceSlowSpeed, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := NOT instWinchSync.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback,
    Homed                   := PRG_02_Acquisition.instHomingM2.Homed,
    HomingSuspect           := PRG_02_Acquisition.instHomingM2.HomingSuspect,
    CablePosM               := PRG_02_Acquisition.CablePosM2,
    TopLimitM               := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowdownMaxStep      := _CommunCfgPersist.WinchSlowdownMaxStep,
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
);


// === 📤 §7 PUBLICATION DEMANDES BRUTES (WinchM1/M2FinalInterlockRequest) ===

WinchM1FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM1FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
// 🆕 2026-08-06 (retrait FB_Brake, demande client) : plus de BrakeReleaseRequest/
// BrakeCommandOpenConfirmed calcules par FB_Winch — la barriere finale
// (FB_WinchOutputInterlock_LD) recoit desormais le retour PHYSIQUE brut directement,
// et calcule elle-meme BrakeCmd := RelayFwd OR RelayRev (voir bandeau de ce FB).
WinchM1FinalInterlockRequest.BrakeFeedback := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI;
WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI;
WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd;
WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev;
WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;
WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;

WinchM2FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM2FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM2FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM2FinalInterlockRequest.SafeStop := SafeStopM2_Active;
WinchM2FinalInterlockRequest.BrakeFeedback := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI;
WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI;
WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;
WinchM2FinalInterlockRequest.RequestedRelayRev := instWinchM2.RelayRev;
WinchM2FinalInterlockRequest.RequestedContactor1 := instWinchM2.Contactor1;
WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;
WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;

// === 📤 §8 PUBLICATION ÉTATS IHM (faits publics, lecture seule) ===
WinchM1StateHMI.Position_M := PRG_02_Acquisition.CablePosM1;
WinchM1StateHMI.SpeedRef_Pct := M1_SpeedRef_Active;
WinchM1StateHMI.StepNumber := instWinchM1.StepNumber;
WinchM1StateHMI.FBState := instWinchM1.State;
WinchM1StateHMI.Ready := instWinchM1.Ready;
WinchM1StateHMI.Busy := instWinchM1.Busy;
WinchM1StateHMI.Done := instWinchM1.Done;
WinchM1StateHMI.Error := instWinchM1.Error;
WinchM1StateHMI.ErrorId := instWinchM1.ErrorId;
WinchM1StateHMI.RelayFwd := instWinchM1.RelayFwd;
WinchM1StateHMI.RelayRev := instWinchM1.RelayRev;
WinchM1StateHMI.Contactor1 := instWinchM1.Contactor1;
WinchM1StateHMI.Contactor2 := instWinchM1.Contactor2;
WinchM1StateHMI.Contactor3 := instWinchM1.Contactor3;
WinchM1StateHMI.Contactor4 := instWinchM1.Contactor4;
WinchM1StateHMI.BrakeCmd := PRG_06_Outputs_LD.instWinchOutputInterlockM1.BrakeCmd;
WinchM1StateHMI.BrakeCommandOpenConfirmed := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI;
WinchM1StateHMI.FinalAuthorizedStep := instWinchM1.RequestedStep;
WinchM1StateHMI.ContactorsCheck := instWinchM1.ContactorsCheck;
WinchM1StateHMI.FinalInterlockState := PRG_06_Outputs_LD.instWinchOutputInterlockM1.State;
WinchM1StateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instWinchOutputInterlockM1.Reason;
WinchM1StateHMI.FinalInterlockError := PRG_06_Outputs_LD.instWinchOutputInterlockM1.Error;
WinchM1StateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instWinchOutputInterlockM1.ErrorId;
WinchM1StateHMI.FinalRestartInhibit := PRG_06_Outputs_LD.instWinchOutputInterlockM1.RestartInhibit;
WinchM1StateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.BrakeTimeoutElapsed;
WinchM1StateHMI.FinalRestartDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.RestartDelayElapsed;
WinchM1StateHMI.FinalStepDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.StepDelayElapsed;
WinchM1StateHMI.Encoder.RawPos := PRG_02_Acquisition.instEncoderAbsM1.RawPos;
WinchM1StateHMI.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD1_Alarms;
WinchM1StateHMI.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD1_Warnings;
WinchM1StateHMI.Encoder.SlaveOperational := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM1.Operational;
WinchM1StateHMI.Encoder.PresetTriggerCmd := PRG_02_Acquisition.instEncoderAbsM1.PresetTriggerCmd;
WinchM1StateHMI.Encoder.PresetValueOut := PRG_02_Acquisition.instEncoderAbsM1.PresetValueOut;
WinchM1StateHMI.Encoder.Error := PRG_02_Acquisition.instEncoderAbsM1.Error;
WinchM1StateHMI.Encoder.ErrorId := PRG_02_Acquisition.instEncoderAbsM1.ErrorId;
WinchM1StateHMI.Encoder.Homed := PRG_02_Acquisition.instHomingM1.Homed;
WinchM1StateHMI.Encoder.HomingBusy := PRG_02_Acquisition.instHomingM1.Busy;
WinchM1StateHMI.Encoder.HomingDone := PRG_02_Acquisition.instHomingM1.Done;
WinchM1StateHMI.Encoder.HomingError := PRG_02_Acquisition.instHomingM1.Error;
WinchM1StateHMI.Encoder.HomingErrorId := PRG_02_Acquisition.instHomingM1.ErrorId;
WinchM1StateHMI.Encoder.HomingState := PRG_02_Acquisition.instHomingM1.State;
WinchM1StateHMI.Encoder.HomingStateAtError := PRG_02_Acquisition.instHomingM1.StateAtError;
WinchM1StateHMI.Encoder.HomingSuspect := PRG_02_Acquisition.instHomingM1.HomingSuspect;
WinchM1StateHMI.Encoder.HomingRefRaw := PRG_02_Acquisition.instHomingM1.HomingRefRaw;
WinchM1StateHMI.InhibitActive := PRG_03_Modes_Cycle.Auth.InhibitM1;
WinchM1StateHMI.BottomLimitActiveM := BottomLimitM1_Active;
WinchM1StateHMI.InTopSlowdownZone := instWinchM1.InTopSlowdownZone;
WinchM1StateHMI.InBottomSlowdownZone := instWinchM1.InBottomSlowdownZone;
WinchM1StateHMI.CommandedDirection := instWinchM1.CommandedDirection;
WinchM1StateHMI.DirectionChangeDelayElapsed := instWinchM1.DirectionChangeDelayElapsed;
WinchM1StateHMI.DirectionChangePending := instWinchM1.DirectionChangePending;

WinchM2StateHMI.Position_M := PRG_02_Acquisition.CablePosM2;
WinchM2StateHMI.SpeedRef_Pct := M2_SpeedRef_Active;
WinchM2StateHMI.StepNumber := instWinchM2.StepNumber;
WinchM2StateHMI.FBState := instWinchM2.State;
WinchM2StateHMI.Ready := instWinchM2.Ready;
WinchM2StateHMI.Busy := instWinchM2.Busy;
WinchM2StateHMI.Done := instWinchM2.Done;
WinchM2StateHMI.Error := instWinchM2.Error;
WinchM2StateHMI.ErrorId := instWinchM2.ErrorId;
WinchM2StateHMI.RelayFwd := instWinchM2.RelayFwd;
WinchM2StateHMI.RelayRev := instWinchM2.RelayRev;
WinchM2StateHMI.Contactor1 := instWinchM2.Contactor1;
WinchM2StateHMI.Contactor2 := instWinchM2.Contactor2;
WinchM2StateHMI.Contactor3 := instWinchM2.Contactor3;
WinchM2StateHMI.Contactor4 := instWinchM2.Contactor4;
WinchM2StateHMI.BrakeCmd := PRG_06_Outputs_LD.instWinchOutputInterlockM2.BrakeCmd;
WinchM2StateHMI.BrakeCommandOpenConfirmed := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI;
WinchM2StateHMI.FinalAuthorizedStep := instWinchM2.RequestedStep;
WinchM2StateHMI.ContactorsCheck := instWinchM2.ContactorsCheck;
WinchM2StateHMI.FinalInterlockState := PRG_06_Outputs_LD.instWinchOutputInterlockM2.State;
WinchM2StateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instWinchOutputInterlockM2.Reason;
WinchM2StateHMI.FinalInterlockError := PRG_06_Outputs_LD.instWinchOutputInterlockM2.Error;
WinchM2StateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instWinchOutputInterlockM2.ErrorId;
WinchM2StateHMI.FinalRestartInhibit := PRG_06_Outputs_LD.instWinchOutputInterlockM2.RestartInhibit;
WinchM2StateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.BrakeTimeoutElapsed;
WinchM2StateHMI.FinalRestartDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.RestartDelayElapsed;
WinchM2StateHMI.FinalStepDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.StepDelayElapsed;
WinchM2StateHMI.Encoder.RawPos := PRG_02_Acquisition.instEncoderAbsM2.RawPos;
WinchM2StateHMI.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD2_Alarms;
WinchM2StateHMI.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD2_Warnings;
WinchM2StateHMI.Encoder.SlaveOperational := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM2.Operational;
WinchM2StateHMI.Encoder.PresetTriggerCmd := PRG_02_Acquisition.instEncoderAbsM2.PresetTriggerCmd;
WinchM2StateHMI.Encoder.PresetValueOut := PRG_02_Acquisition.instEncoderAbsM2.PresetValueOut;
WinchM2StateHMI.Encoder.Error := PRG_02_Acquisition.instEncoderAbsM2.Error;
WinchM2StateHMI.Encoder.ErrorId := PRG_02_Acquisition.instEncoderAbsM2.ErrorId;
WinchM2StateHMI.Encoder.Homed := PRG_02_Acquisition.instHomingM2.Homed;
WinchM2StateHMI.Encoder.HomingBusy := PRG_02_Acquisition.instHomingM2.Busy;
WinchM2StateHMI.Encoder.HomingDone := PRG_02_Acquisition.instHomingM2.Done;
WinchM2StateHMI.Encoder.HomingError := PRG_02_Acquisition.instHomingM2.Error;
WinchM2StateHMI.Encoder.HomingErrorId := PRG_02_Acquisition.instHomingM2.ErrorId;
WinchM2StateHMI.Encoder.HomingState := PRG_02_Acquisition.instHomingM2.State;
WinchM2StateHMI.Encoder.HomingStateAtError := PRG_02_Acquisition.instHomingM2.StateAtError;
WinchM2StateHMI.Encoder.HomingSuspect := PRG_02_Acquisition.instHomingM2.HomingSuspect;
WinchM2StateHMI.Encoder.HomingRefRaw := PRG_02_Acquisition.instHomingM2.HomingRefRaw;
WinchM2StateHMI.InhibitActive := PRG_03_Modes_Cycle.Auth.InhibitM2;
WinchM2StateHMI.BottomLimitActiveM := BottomLimitM2_Active;
WinchM2StateHMI.InTopSlowdownZone := instWinchM2.InTopSlowdownZone;
WinchM2StateHMI.InBottomSlowdownZone := instWinchM2.InBottomSlowdownZone;
WinchM2StateHMI.CommandedDirection := instWinchM2.CommandedDirection;
WinchM2StateHMI.DirectionChangeDelayElapsed := instWinchM2.DirectionChangeDelayElapsed;
WinchM2StateHMI.DirectionChangePending := instWinchM2.DirectionChangePending;

WinchM1SafetyHMI.SafeStop := SafeStopM1_Active;
WinchM1SafetyHMI.ForbidAscent := ForbidAscentM1_Active;
WinchM1SafetyHMI.ForbidDescent := ForbidDescentM1_Active;
WinchM1SafetyHMI.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI;
WinchM1SafetyHMI.PowerCutOff := instSafetyWinchM1.PowerCutOff;
WinchM1SafetyHMI.BrakeTimeoutFault := (PRG_06_Outputs_LD.instWinchOutputInterlockM1.ErrorId AND 16#0001) <> 0;
WinchM1SafetyHMI.CableOutOfBoundsFault := (PRG_02_Acquisition.instEncoderSafetyM1.ErrorId AND 16#0001) <> 0;
WinchM1SafetyHMI.Error := instWinchM1.Error OR instSafetyWinchM1.Error;
WinchM1SafetyHMI.ErrorId := instWinchM1.ErrorId;

WinchM2SafetyHMI.SafeStop := SafeStopM2_Active;
WinchM2SafetyHMI.ForbidAscent := ForbidAscentM2_Active;
WinchM2SafetyHMI.ForbidDescent := ForbidDescentM2_Active;
WinchM2SafetyHMI.SlackCable := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI;
WinchM2SafetyHMI.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI;
WinchM2SafetyHMI.PowerCutOff := instSafetyWinchM2.PowerCutOff;
WinchM2SafetyHMI.BrakeTimeoutFault := (PRG_06_Outputs_LD.instWinchOutputInterlockM2.ErrorId AND 16#0001) <> 0;
WinchM2SafetyHMI.CableOutOfBoundsFault := (PRG_02_Acquisition.instEncoderSafetyM2.ErrorId AND 16#0001) <> 0;
WinchM2SafetyHMI.Error := instWinchM2.Error OR instSafetyWinchM2.Error;
WinchM2SafetyHMI.ErrorId := instWinchM2.ErrorId;

SyncStateHMI.DeltaPos_M := instWinchSync.SignedDeltaPosM;
SyncStateHMI.SyncActive := instWinchSync.SyncActive;
SyncStateHMI.SyncWarn := instWinchSync.SyncWarn;
SyncStateHMI.Ready := instWinchSync.Ready;
SyncStateHMI.Error := instWinchSync.Error;
SyncStateHMI.ErrorId := instWinchSync.ErrorId;
SyncStateHMI.FBState := instWinchSync.State;

BucketStateHMI.MechState := _BucketState;
BucketStateHMI.FBState := instBucket.State;
BucketStateHMI.ActiveOffset_M := instBucket.ActiveOffsetM;
BucketStateHMI.M2StartStop := instBucket.M2_StartStop;
BucketStateHMI.M2Direction := instBucket.M2_Direction;
BucketStateHMI.M2ForceSlowSpeed := instBucket.M2_ForceSlowSpeed;
BucketStateHMI.M2PositionCorrected := PRG_02_Acquisition.CablePosM2 - instBucket.ActiveOffsetM;
BucketStateHMI.Ready := instBucket.Ready;
BucketStateHMI.Busy := instBucket.Busy;
BucketStateHMI.Done := instBucket.Done;
BucketStateHMI.Error := instBucket.Error;
BucketStateHMI.ErrorId := instBucket.ErrorId;
BucketStateHMI.RemainingTravel_M := instBucket.RemainingTravelM;
BucketStateHMI.CloseActive := instBucket.CloseReq;
BucketStateHMI.OpenActive := instBucket.OpenReq;
// 🔧 2026-08-07 : corrigé -- pointait sur DumpAtTremieBucketOpenArmed (mauvais signal, deviné
// par l'agent Fiche 02 avant que la Fiche 01 ne soit committée). Reflète maintenant le vrai
// séquencement auto Fiche 01 : occupé sur une ouverture/fermeture qu'IL a armée, ou en phase
// vitesse contrôlée post-fermeture.
BucketStateHMI.AutoBucketSeqActive := (instBucket.Busy AND (CoupledDiveBucketOpenArmed OR CoupledAscentBucketCloseArmed)) OR ControlAscentActive;
BucketStateHMI.CoupledDiveOpenArmed := CoupledDiveBucketOpenArmed;
BucketStateHMI.CoupledAscentCloseArmed := CoupledAscentBucketCloseArmed;
BucketStateHMI.ControlAscentActive := ControlAscentActive;
BucketStateHMI.CoupledMotionBlockedByBucket := CoupledMotionBlockedByBucket;
GVL_IHM.Commun.KoboldImmersionConfirmed := KoboldImmersionConfirmed;
GVL_IHM.Commun.KoboldBottomTouchLatched := KoboldBottomTouchLatched;

END_PROGRAM

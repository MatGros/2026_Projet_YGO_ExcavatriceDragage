(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_04_Treuils_Benne — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4 (après PRG_03_Modes_Cycle).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md ; DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Treuils_Benne

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA PRG_02 & PRG_03) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data : ST_WinchInterPrg; // <-- [BUS] Demandes finales, états, sécurités, synchro, benne
END_VAR

VAR
    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instSafetyWinchM1 : FB_Safety_Winch;   // Sécurité treuil M1 (SafeStop / permits / PowerCutOff)
    instSafetyWinchM2 : FB_Safety_Winch;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;
    instDiveSearch : FB_DiveSearch;
    instExtractionSequence : FB_ExtractionSequence;

    // === 📊 STRUCTS INTERNES (publiés via Data) ===
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest; // . [LOC] Demande finale et interlocks treuil M1
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest; // . [LOC] Demande finale et interlocks treuil M2
    KoboldContactorCmdArbitrated : BOOL;                         // . [LOC] Ordre contacteur capteur fond Kobold
    WinchM1State                 : ST_WinchState;                // . [LOC] Etat public treuil Retenue M1
    WinchM2State                 : ST_WinchState;                // . [LOC] Etat public treuil Benne M2
    WinchM1Safety                : ST_SafetyWinch;               // . [LOC] Diagnostic et securites treuil M1
    WinchM2Safety                : ST_SafetyWinch;               // . [LOC] Diagnostic et securites treuil M2
    SyncState                    : ST_SyncState;                 // . [LOC] Etat synchronisation treuils M1/M2
    BucketState                  : ST_BucketHMIState;            // . [LOC] Etat de fonctionnement benne
    Benne_IsRoughlyClosed        : BOOL;                         // . [LOC] Benne consideree fermee

    CoupledUserRequestActive : BOOL;
    CoupledUserRequestDirection     : INT;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;
    // mode "vidage à la trémie" — verrouille descente treuils (P1/Maintenance
    // uniquement) et pilote l'ouverture benne quand on demande DOWN à la trémie (MAINT_N1/N2
    // uniquement, même périmètre que instDiveSearch/instExtractionSequence).
    DumpAtTremieActive             : BOOL;
    DumpAtTremieAssistActive       : BOOL; // Sous-condition Mode MAINT_N1/N2 (assist réellement active)
    DumpAtTremieBucketOpenArmed    : BOOL; // CmdOpen_IHM déclenché par ce mode (diagnostic)

    // Séquencement automatique benne en pilotage couplé (both) normal --
    // descente uniquement benne ouverte, montée uniquement benne
    // fermée. Distinct de DumpAtTremie/DiveSearch/ExtractionSequence (fonctionnement normal,
    // pas une assistance MAINT_N1/N2 dédiée). Réutilise CoupledUserRequestActive/
    // CoupledUserRequestDirection (§1 ci-dessus) : déjà exactement "mouvement couplé (both)
    // demandé" dans les 2 modes (joystick Select=0, ou BtnWinchBothUp/Down) — mêmes variables
    // déjà utilisées par instBucket/instDiveSearch/instExtractionSequence.
    CoupledDiveBucketOpenArmed     : BOOL;  // CmdOpen_IHM déclenché par ce mécanisme (diagnostic IHM)
    CoupledMotionBlockedByBucket   : BOOL;  // Garde-fou direct -- voir §3
    CoupledAscentBucketCloseArmed  : BOOL;  // CmdClose_IHM déclenché par ce mécanisme (diagnostic IHM)
    BucketBusyRiseEdge             : R_TRIG; // Détecte le début d'une action benne (Busy monté)
    BucketBusyFallEdge             : F_TRIG; // Détecte la fin d'une action benne (Busy retombé)
    ControlAscentArmedForThisClose : BOOL;   // Mémorise si LA fermeture en cours a été armée par ce mécanisme
    ControlAscentActive            : BOOL;   // Phase vitesse contrôlée en cours (diagnostic IHM)
    ControlAscentStartM1PosM       : REAL;
    ControlAscentStartM2PosM       : REAL;

    M1LogicRequestStartStop     : BOOL;
    M1LogicRequestDirection     : INT;
    M1LogicRequestSpeedCmd_Pct      : REAL;

    M2LogicRequestStartStop     : BOOL;
    M2LogicRequestDirection     : INT;
    M2LogicRequestSpeedCmd_Pct      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    SpeedGuardEnableM1 : BOOL := FALSE;
    SpeedGuardEnableM2 : BOOL := FALSE;

    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;

    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    // Taxonomie permit (D-P1 à D-P11) : SafetyPermit (safety pure), ProcessPermit (process pur),
    // ProcessAndSafetyPermit (= Safety AND Process), EffectivePermit (= couplage synchro).
    SafetyPermitM1_Descend   : BOOL;
    SafetyPermitM2_Descend   : BOOL;
    SafetyPermitM1_Ascent    : BOOL;
    SafetyPermitM2_Ascent    : BOOL;
    ProcessPermitM1_Descend  : BOOL;
    ProcessPermitM2_Descend  : BOOL;
    ProcessPermitM1_Ascent   : BOOL;
    ProcessPermitM2_Ascent   : BOOL;
    ProcessAndSafetyPermitM1_Descend : BOOL;
    ProcessAndSafetyPermitM2_Descend : BOOL;
    ProcessAndSafetyPermitM1_Ascent  : BOOL;
    ProcessAndSafetyPermitM2_Ascent  : BOOL;
    EffectivePermitM1_Descend : BOOL;
    EffectivePermitM2_Descend : BOOL;
    EffectivePermitM1_Ascent  : BOOL;
    EffectivePermitM2_Ascent  : BOOL;

    BenneBusyFallEdge     : F_TRIG;

    // Arrêt auto descente sur détection fond Kobold (pilotage normal)
    KoboldAutoStopRiseEdge  : R_TRIG;
    KoboldAutoStopFallEdge  : F_TRIG;
    KoboldImmersionConfirmed: BOOL;
    KoboldBottomTouchLatched: BOOL;
    DescendPermitDiveBucketOpen : BOOL; // mode Dive actif + benne ouverte = descente permise
    // pilotage unitaire M2 "sécurisé" -- bornes ouvert/fermé + palier 1
    ManualBucketLimitsActive : BOOL;
    SlackCableAscentStep1    : BOOL; // mou de câble en récupération -- bride la montée au Palier 1
    BucketNotClosedAscentStep1 : BOOL; // benne non fermée à 100% à la montée -- bride la montée au Palier 1

    // Bypass simplifié séquence FB_DiveSearch -- front montant
    // Kobold pendant une descente couplée confirme directement le fond, sans passer par les
    // préconditions strictes de FB_DiveSearch (benne ouverte, DiveStartMin_M, fenêtre immersion).
    // FB_DiveSearch continue de tourner en parallèle (KoboldMeasureEnable toujours câblé
    // dessus) -- ce bypass est un chemin ADDITIONNEL, pas un remplacement.
    BypassKoboldFallEdge       : F_TRIG; // front descendant Kobold
    BypassKoboldBottomTouched  : BOOL;

    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M2_LimitShift                : REAL;

    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescente  : INT;

    // Mémoire scan précédent pour SpeedDelta_Mps (IHM)
    M1_PrevSpeed_Mps : REAL;
    M2_PrevSpeed_Mps : REAL;
END_VAR

{region "§1 Intention maintenance et assistants"}
// === 🪨 §1 INTENTION MAINTENANCE & ASSISTANTS ===

IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    // Direction déjà mise à l'échelle (-1/0/+1) par le joystick (miroir DirectionY,
    // dérivé des bits DirectionPositive/Negative du struct ST_fbJoystick_AxisCmd).
    CoupledUserRequestDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
    CoupledUserRequestActive := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw
                                     AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 0);

ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        CoupledUserRequestDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        CoupledUserRequestDirection := -1;
    ELSE
        CoupledUserRequestDirection := 0;
    END_IF;
    CoupledUserRequestActive := (CoupledUserRequestDirection <> 0);

END_IF;

// mode "vidage à la trémie" (verrouillage). Périmètre identique
// à instDiveSearch/instExtractionSequence : MAINT_N1/MAINT_N2 uniquement.
DumpAtTremieActive := GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie;
DumpAtTremieAssistActive := DumpAtTremieActive
    AND (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2);
GVL_IHM.DredgingAssist.State.DumpAtTremieArmed        := DumpAtTremieActive;
GVL_IHM.DredgingAssist.State.DumpAtTremieAssistActive := DumpAtTremieAssistActive;
GVL_IHM.DredgingAssist.State.DumpAtTremieAtTremie     := PRG_05_Translation.M3_AtTremieStable;

// Confirmation manuelle "fond touché" effacée hors conditions de garde (MAINT_N1/N2,
// sous tension, pas de défaut, pas de descente couplée) — la confirmation se fait
// précisément PENDANT que la benne est encore ouverte (avant que l'extraction ne la ferme).
IF NOT (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)) THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
    BypassKoboldBottomTouched := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

// Front DESCENDANT Kobold pendant une descente couplée = fond touché, directement (voir bandeau §1).
// Mêmes conditions de garde que la confirmation manuelle ci-dessus (MAINT_N1/N2, sous tension,
// pas de défaut, benne fermée -- réutilise le bloc de clear commun juste au-dessus).
BypassKoboldFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
IF GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
   AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)
   AND BypassKoboldFallEdge.Q THEN
    BypassKoboldBottomTouched := TRUE;
END_IF;
GVL_IHM.DredgingAssist.State.BypassDiveActive          := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
GVL_IHM.DredgingAssist.State.BypassKoboldBottomTouched := BypassKoboldBottomTouched;

instDiveSearch(
    Enable := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Data.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BucketIsOpen := _BucketState.IsOpen,
    KoboldImmersed := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M,
    // Même toggle que le bypass bottom-confirmation -- saute WAIT_PRECONDITIONS entièrement.
    BypassPreconditions := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
);

// Publication IHM — consommée ensuite par FB_TroubleshootingView (debug).
GVL_IHM.DredgingAssist.State.DiveReady            := instDiveSearch.Ready;
GVL_IHM.DredgingAssist.State.DiveBusy             := instDiveSearch.Lifecycle.Busy;
GVL_IHM.DredgingAssist.State.DiveDone             := instDiveSearch.Lifecycle.Done;
GVL_IHM.DredgingAssist.State.DiveError            := instDiveSearch.Fault.Error;
GVL_IHM.DredgingAssist.State.DiveErrorId          := instDiveSearch.Fault.ErrorId;
GVL_IHM.DredgingAssist.State.DiveState            := instDiveSearch.DiveState;
// BottomPositionConfirmed = OR des trois : détection Kobold
// (instDiveSearch), confirmation manuelle (TglBucketAtBottomConfirmed) et bypass.
BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed OR BypassKoboldBottomTouched;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed := BottomPositionConfirmed;

instExtractionSequence(
    Enable := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Data.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := _BucketState.IsClosed,
    BucketBusy := instBucket.Lifecycle.Busy,
    BucketError := instBucket.Fault.Error,
    WinchSyncError := instWinchSync.Fault.Error,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    M1MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M1.SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M2.SpeedValid,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);
IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

// Publication IHM (voir DiveSearch ci-dessus).
GVL_IHM.DredgingAssist.State.ExtractionReady   := instExtractionSequence.Ready;
GVL_IHM.DredgingAssist.State.ExtractionBusy    := instExtractionSequence.Lifecycle.Busy;
GVL_IHM.DredgingAssist.State.ExtractionDone    := instExtractionSequence.Lifecycle.Done;
GVL_IHM.DredgingAssist.State.ExtractionError   := instExtractionSequence.Fault.Error;
GVL_IHM.DredgingAssist.State.ExtractionErrorId := instExtractionSequence.Fault.ErrorId;
GVL_IHM.DredgingAssist.State.ExtractionState   := instExtractionSequence.ExtractionState;

// une seule consigne opérateur conduite à la fois (doc §OperatorActionId) —
// arbitrage fait ici : DiveSearch prioritaire si Busy, sinon ExtractionSequence si Busy,
// sinon la dernière connue reste affichée à titre informatif.
IF instDiveSearch.Lifecycle.Busy THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := instDiveSearch.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction   := instDiveSearch.OperatorAction;
ELSIF instExtractionSequence.Lifecycle.Busy THEN
    GVL_IHM.DredgingAssist.State.OperatorActionId := instExtractionSequence.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction   := instExtractionSequence.OperatorAction;
ELSE
    GVL_IHM.DredgingAssist.State.OperatorActionId := 0;
    GVL_IHM.DredgingAssist.State.OperatorAction   := '';
END_IF;

// Règle absolue en pilotage couplé (both) normal --
// descente autorisée UNIQUEMENT benne ouverte, montée UNIQUEMENT benne fermée. Réutilise
// CoupledUserRequestActive/CoupledUserRequestDirection (§1) : déjà "mouvement couplé
// demandé" dans les 2 modes (joystick Select=0 exclut le pilotage unitaire M1/M2 seul,
// BtnWinchBothUp/Down exclut les boutons IHM individuels M1/M2). Jamais actif en SEMI_AUTO
// (mêmes conditions que le reste de ce §).
// coupe-circuit d'urgence (machine bloquée en butée
// M2_LimitShift). GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing (défaut FALSE) : si FALSE,
// ces 2 flags restent FALSE en permanence -- CmdOpen_IHM/CmdClose_IHM ne sont plus jamais armés
// par le mouvement couplé joystick, instBucket.Busy ne peut plus être déclenché QUE par action
// manuelle benne/DumpAtTremie/ExtractionSequence.
CoupledDiveBucketOpenArmed := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
    AND (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.SEMI_AUTO)
    AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)
    AND NOT _BucketState.IsOpen;
CoupledAscentBucketCloseArmed := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing
    AND (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.SEMI_AUTO)
    AND CoupledUserRequestActive AND (CoupledUserRequestDirection = 1)
    AND NOT _BucketState.IsClosed;

IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Pont SEMI_AUTO : fermeture benne pilotée par le séquenceur de cycle.
    CmdBucketCloseArbitrated := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose;
ELSIF instExtractionSequence.BucketCloseRequest THEN
    CmdBucketCloseArbitrated := TRUE;
ELSIF CoupledAscentBucketCloseArmed THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
END_IF;

// urgence : instDiveSearch.KoboldMeasureEnable
// n'est TRUE que dans SEARCHING_IMMERSION/SEARCHING_BOTTOM, atteignables uniquement après
// WAIT_PRECONDITIONS (DiveStartMin_M/ImmersionUpper_M/ImmersionLower_M). Avec le bypass
// (TglBypassDiveSearchSequence), le contacteur doit être piloté
// INDÉPENDAMMENT de ces préconditions dès qu'on descend réellement.
IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Pont SEMI_AUTO : contacteur Kobold piloté par le séquenceur de cycle.
    KoboldContactorCmdArbitrated := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable;
ELSE
    KoboldContactorCmdArbitrated := instDiveSearch.KoboldMeasureEnable
        OR (GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
            AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1));
END_IF;


{endregion}

{region "§2 Commande benne"}
// === 🏗️ §2 COMMANDE DU BENNE (FB_Bucket) ===

// en mode "vidage à la trémie" (MAINT_N1/N2, bit armé), une demande DOWN à
// la trémie arme l'ouverture benne au lieu de faire descendre M2 — le mouvement réel reste
// gouverné par MotionRequestActive/MotionDirection ci-dessous (rien ne bouge tant que
// l'opérateur ne pousse pas réellement DOWN) ; instBucket.Busy prend alors la main sur
// l'arbitrage M2 normal (voir §3bis plus bas).
DumpAtTremieBucketOpenArmed := DumpAtTremieAssistActive AND PRG_05_Translation.M3_AtTremieStable;
GVL_IHM.DredgingAssist.State.DumpAtTremieBucketOpenArmed := DumpAtTremieBucketOpenArmed;

instBucket(
    Enable              := NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Data.Auth.Mode,
    CmdOpen_IHM         := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen OR DumpAtTremieBucketOpenArmed OR CoupledDiveBucketOpenArmed
                           OR (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO AND PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen),
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection     := CoupledUserRequestDirection,
    CablePosM1          := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    CablePosM2          := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    HomedM1             := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2             := PRG_02_Acquisition.Data.EncoderM2.Homed,
    M1_Busy             := (instWinchM1.StepNumber > 0),
    M2_Busy             := (instWinchM2.StepNumber > 0),
    ConfirmOpenPosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
    ConfirmClosePosition:= GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
    Config              := _BucketCfgPersist.Config,
    CfgTimeoutDuration     := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    InhibitM2           := PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    BypassGlobal        := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global
);

// Auto-séquencement benne & Dégradation Palier 1
// Si la benne est en cours de fermeture/ouverture (instBucket.Busy), le mouvement couplé attend.
// Si la benne n'est pas fermée (NOT IsClosed) et que instBucket n'est plus occupé (Busy=FALSE),
// toute demande de montée est automatiquement dégradée au Palier 1 (Vitesse lente, voir instWinchM1/M2),
// protégeant ainsi la mécanique même en pilotage unitaire ou si l'auto-séquencement est désactivé.
// 📌 Note d'architecture (lag 1 scan) : M1/M2LogicRequestDirection est consommé ici avant son calcul arbitré
// en §3 (lag d'un cycle automate nominal, toléré et homogène avec les arbitrages Translation/Modes).
CoupledMotionBlockedByBucket := CoupledDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;
BucketNotClosedAscentStep1 := (M1LogicRequestDirection = 1 OR M2LogicRequestDirection = 1) AND NOT instBucket.Lifecycle.Busy AND NOT _BucketState.IsClosed;

// En mode récupération (SyncEnable=FALSE), si un mou de câble est détecté (bit3 ErrorId),
// la montée/enroulement est autorisée mais bridée au Palier 1 pour retendre le tambour en sécurité.
// 📌 Note d'architecture (lag 1 scan) : instSafetyWinchM1/M2.ErrorId est consommé ici avant l'exécution du FB
// au §5bis (lag d'un cycle automate nominal, sécurisé en amont par la lecture directe de M2_TensionedCable_DI).
SlackCableAscentStep1 := NOT PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND (
    ((instSafetyWinchM1.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    ((instSafetyWinchM2.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    (NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI)
);

SyncMinorDeviation := (instWinchSync.Fault.ErrorId AND 16#0001) <> 16#0000;
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


{endregion}

{region "§3 Arbitrage consignes M1/M2"}
// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 ===

IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Pont SEMI_AUTO : consomme les demandes du séquenceur de cycle.
    // FB_Cycle produit déjà StartStop conditionné par CycleMotionPermit (homme-mort 3s, D2).
    M1LogicRequestDirection := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDirection;
    M1LogicRequestStartStop := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqStartStop;
    M1LogicRequestSpeedCmd_Pct  := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.SpeedTgtPct;
ELSE
    IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        // Mode Boutons IHM
        IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M1TreuilRetenue.Cmd.BtnUp THEN
            M1LogicRequestDirection := 1;
            M1LogicRequestSpeedCmd_Pct  := 100.0;
        ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M1TreuilRetenue.Cmd.BtnDown THEN
            M1LogicRequestDirection := -1;
            M1LogicRequestSpeedCmd_Pct  := 100.0;
        ELSE
            M1LogicRequestDirection := 0;
            M1LogicRequestSpeedCmd_Pct  := 0.0;
        END_IF;
    ELSE
        // Mode Joystick Maître
        IF (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 1) THEN
            M1LogicRequestDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
            M1LogicRequestSpeedCmd_Pct  := ABS(PRG_02_Acquisition.Data.Joystick.AxisY.SpeedTgt);
        ELSE
            M1LogicRequestDirection := 0;
            M1LogicRequestSpeedCmd_Pct  := 0.0;
        END_IF;
    END_IF;

    M1LogicRequestStartStop := (M1LogicRequestDirection <> 0) AND NOT instBucket.Lifecycle.Busy
                            AND NOT CoupledMotionBlockedByBucket
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1LogicRequestDirection = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1LogicRequestDirection = -1)))
                            AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.Data.JoystickDeadmanArmed);
END_IF;

// Condition renforcée "instBucket.Busy AND instBucket.M2_StartStop" au lieu de
// "instBucket.Busy" seul : si le mouvement couplé est toujours demandé, M2
// reçoit sa commande de continuité le MÊME scan, sans dépendre d'un timing de bascule.
IF instBucket.Lifecycle.Busy AND instBucket.M2_StartStop THEN
    M2LogicRequestStartStop := instBucket.M2_StartStop;
    M2LogicRequestDirection := instBucket.M2_Direction;
    M2LogicRequestSpeedCmd_Pct  := 15.0;
ELSE
    IF PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO THEN
        // Pont SEMI_AUTO : consomme les demandes du séquenceur de cycle.
        M2LogicRequestDirection := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.ReqDirection;
        M2LogicRequestStartStop := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.ReqStartStop;
        M2LogicRequestSpeedCmd_Pct  := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.SpeedTgtPct;
    ELSE
        IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
            // Mode Boutons IHM
            IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M2TreuilBenne.Cmd.BtnUp THEN
                M2LogicRequestDirection := 1;
                M2LogicRequestSpeedCmd_Pct  := 100.0;
            ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M2TreuilBenne.Cmd.BtnDown THEN
                M2LogicRequestDirection := -1;
                M2LogicRequestSpeedCmd_Pct  := 100.0;
            ELSE
                M2LogicRequestDirection := 0;
                M2LogicRequestSpeedCmd_Pct  := 0.0;
            END_IF;
        ELSE
            // Mode Joystick Maître
            IF (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2) THEN
                M2LogicRequestDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
                M2LogicRequestSpeedCmd_Pct  := ABS(PRG_02_Acquisition.Data.Joystick.AxisY.SpeedTgt);
            ELSE
                M2LogicRequestDirection := 0;
                M2LogicRequestSpeedCmd_Pct  := 0.0;
            END_IF;
        END_IF;

        M2LogicRequestStartStop := (M2LogicRequestDirection <> 0)
                                AND NOT CoupledMotionBlockedByBucket
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2LogicRequestDirection = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2LogicRequestDirection = 1)))
                                AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.Data.JoystickDeadmanArmed);
    END_IF;
END_IF;

// Ne force plus l'arrêt si un mouvement couplé est toujours activement demandé
// (CoupledUserRequestActive), auquel cas l'arbitrage normal (§3) prend le
// relais sans interruption. Comportement inchangé pour toute fin d'action benne SANS mouvement
// couplé en cours (ouverture/fermeture manuelle isolée, bouton IHM) : l'arrêt reste forcé.
BenneBusyFallEdge(CLK := instBucket.Lifecycle.Busy);
IF BenneBusyFallEdge.Q AND NOT (CoupledUserRequestActive AND (CoupledUserRequestDirection <> 0)) THEN
    M1LogicRequestStartStop := FALSE;
    M2LogicRequestStartStop := FALSE;
END_IF;

// Après une fermeture benne armée PAR CE mécanisme
// (pas ExtractionSequence, qui a déjà sa propre phase CONTROL_ASCENT), la montée couplée qui
// enchaîne démarre en vitesse contrôlée (palier 1) sur ExtractionControlDistance_M avant de
// repasser en paliers normaux.
BucketBusyRiseEdge(CLK := instBucket.Lifecycle.Busy);
IF BucketBusyRiseEdge.Q THEN
    ControlAscentArmedForThisClose := CoupledAscentBucketCloseArmed;
END_IF;
IF BucketBusyFallEdge.Q AND ControlAscentArmedForThisClose THEN
    ControlAscentActive := TRUE;
    ControlAscentStartM1PosM := PRG_02_Acquisition.Data.Encoders.M1.CablePosM;
    ControlAscentStartM2PosM := PRG_02_Acquisition.Data.Encoders.M2.CablePosM;
END_IF;
IF ControlAscentActive THEN
    IF (ABS(PRG_02_Acquisition.Data.Encoders.M1.CablePosM - ControlAscentStartM1PosM) >= GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M)
       AND (ABS(PRG_02_Acquisition.Data.Encoders.M2.CablePosM - ControlAscentStartM2PosM) >= GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M) THEN
        ControlAscentActive := FALSE;             // Distance de contrôle parcourue : paliers normaux
    ELSIF NOT (CoupledUserRequestActive AND (CoupledUserRequestDirection = 1)) THEN
        ControlAscentActive := FALSE;             // Montée relâchée/interrompue : annule la phase
    END_IF;
END_IF;


{endregion}

{region "§4 Synchronisation M1/M2"}
// === 🔄 §4 SYNCHRONISATION M1 / M2 ===

instWinchSync(
    Enable          := PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND NOT instBucket.Lifecycle.Busy
                        AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1 AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset           := PRG_07_Supervision.FaultMachineReset_IHM,
    Mode            := PRG_03_Modes_Cycle.Data.Auth.Mode,
    CablePosM1      := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    CablePosM2      := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    HomedAndReliableM1 := PRG_02_Acquisition.Data.M1_HomedAndReliable,
    HomedAndReliableM2 := PRG_02_Acquisition.Data.M2_HomedAndReliable,
    SyncEnable      := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
    CfgSyncCriticalToleranceM := _SyncCfgPersist.CfgSyncCriticalTolerance_M,
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


{endregion}

{region "§5 Couplage croise et securites"}
// === 🛑 §5 COUPLAGE CROISÉ & SÉCURITÉS ===

// La limite légale (profondeur min. autorisée) doit elle aussi
// bénéficier du ralentissement progressif avant arrêt (comme la limite câble physique), pas juste
// un arrêt sec (DescendPermit). Comme les 2 limites bornent la même
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
SafeStopM1_Raw      := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000) OR instBucket.M1SlipDetected OR PRG_02_Acquisition.Data.InputModuleFault;
SafeStopM2_Raw      := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000) OR PRG_02_Acquisition.Data.InputModuleFault;

// Surveillance Kobold descente normale (hors FB_DiveSearch)
// : signal HwIn.Machine.M1_M2_KoboldBottomTouch_DI (même que instDiveSearch §1).
KoboldAutoStopRiseEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
KoboldAutoStopFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);

// Levée du verrou au neutre du joystick/boutons ou si toggle désactivé
IF PRG_02_Acquisition.Data.Joystick.AtNeutralXY OR NOT GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent THEN
    KoboldImmersionConfirmed := FALSE;
    KoboldBottomTouchLatched := FALSE;
END_IF;

// CoupledUserRequestActive requis : cette surveillance ne s'arme qu'en pilotage
// COUPLÉ (Select=0), pas en pilotage unitaire M1 (où CoupledUserRequestDirection reflète
// quand même l'axe joystick brut).
// Qualification immersion : front montant Kobold dans la fenêtre [ImmersionLower_M..ImmersionUpper_M]
IF GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent
   AND CoupledUserRequestActive
   AND (CoupledUserRequestDirection = -1)
   AND _BucketState.IsOpen
   AND KoboldAutoStopRiseEdge.Q THEN
    IF (PRG_02_Acquisition.Data.Encoders.M1.CablePosM <= _DredgingAssistCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.Data.Encoders.M1.CablePosM >= _DredgingAssistCfgPersist.ImmersionLower_M)
       AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM <= _DredgingAssistCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM >= _DredgingAssistCfgPersist.ImmersionLower_M) THEN
        KoboldImmersionConfirmed := TRUE;
    END_IF;
END_IF;

// Détection fond : front descendant Kobold APRÈS immersion confirmée
IF KoboldAutoStopFallEdge.Q AND KoboldImmersionConfirmed THEN
    KoboldBottomTouchLatched := TRUE;
    KoboldImmersionConfirmed := FALSE;
END_IF;

// Autorisation directe et explicite, gardée par instDiveSearch.Enable (mode Dive réellement actif)
// -- indépendante du timing interne DescendPermit. Bloque uniquement si benne PAS confirmée ouverte.
DescendPermitDiveBucketOpen := NOT (instDiveSearch.Enable AND CoupledUserRequestActive
    AND (CoupledUserRequestDirection = -1) AND NOT _BucketState.IsOpen);

// Le bypass arrête aussi la descente instantanément, même doctrine que le mécanisme
// KoboldBottomTouchLatched.
// Mode "pilotage unitaire M2 sécurisé"
// (SelJoystickWinch=2 + toggle IHM). Ne passe PAS par instBucket (pas de CloseReq/OpenReq
// mémorisé, jogging libre) -- bornes directes ouvert/fermé (mêmes offsets que FB_Bucket,
// relatifs à la position réelle de M1) + palier 1 (voir instWinchM2 §6 plus bas).
ManualBucketLimitsActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits
    AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2);

ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
// Ce chemin (pilotage
// unitaire M2, hors instBucket) applique l'anticipation d'inertie OpenAnticipationM/CloseAnticipationM
// (mêmes que FB_Bucket) pour couvrir aussi le jog unitaire.
ProcessPermitM2_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen
    AND NOT (ManualBucketLimitsActive AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM <= (PRG_02_Acquisition.Data.Encoders.M1.CablePosM + _BucketCfgPersist.Config.OffsetOpenM + _BucketCfgPersist.Config.OpenAnticipationM)));

M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq OR (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2),
                      0.0,
                      (PRG_02_Acquisition.Data.Encoders.M1.CablePosM + _BucketCfgPersist.Config.OffsetCloseM + 0.5)
                      - _CommunCfgPersist.CfgCableLimitAscent_M);

// FB_Safety_Winch M1/M2.
// Instancié avant instWinchM1/M2 : MovementCommanded lit RelayFwd/RelayRev du scan précédent
// (même lag 1 scan accepté que M4/Translation, jamais sur Reset/SafeStop/PowerCutOff/sortie finale).
instSafetyWinchM1(
    Enable                 := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
    JoystickOperational    := PRG_02_Acquisition.Data.Network.Joystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy,
    CablePosM              := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    Direction              := M1LogicRequestDirection,
    MovementCommanded      := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    Homed                  := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomingSuspect          := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect,
    TopLimitM              := _CommunCfgPersist.CfgCableLimitAscent_M,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.Data.JoystickYNeutral,
    BenneHoldStillActive   := instBucket.Lifecycle.Busy,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.Data.Encoders.M2.CablePosM - instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    MeasuredSpeedMps       := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.Data.Encoders.M1.SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.Data.Encoders.M1.SpeedValid,
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := GVL_IHM.M1TreuilRetenue.Bypass.Process,
    // OR avec le bypass commun (Commun.Bypass) -- leve la
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
    Enable                 := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
    JoystickOperational    := PRG_02_Acquisition.Data.Network.Joystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.Data.EncoderM2.Measurement.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy,
    CablePosM              := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    Direction              := M2LogicRequestDirection,
    MovementCommanded      := instWinchM2.RelayFwd OR instWinchM2.RelayRev,
    Homed                  := PRG_02_Acquisition.Data.EncoderM2.Homed,
    HomingSuspect          := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect,
    TopLimitM              := _CommunCfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.Data.JoystickYNeutral,
    BenneHoldStillActive   := FALSE,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.Data.Encoders.M1.CablePosM + instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    MeasuredSpeedMps       := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.Data.Encoders.M2.SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.Data.Encoders.M2.SpeedValid,
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassSafety           := GVL_IHM.M2TreuilBenne.Bypass.Safety,
    BypassProcess          := GVL_IHM.M2TreuilBenne.Bypass.Process,
    // OR avec le bypass commun (Commun.Bypass) -- voir M1 ci-dessus
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
// SafetyPermit = sorties FB_Safety_Winch (safety pure)
SafetyPermitM1_Descend := instSafetyWinchM1.DescendPermit;
SafetyPermitM2_Descend := instSafetyWinchM2.DescendPermit;
SafetyPermitM1_Ascent  := instSafetyWinchM1.AscentPermit;
SafetyPermitM2_Ascent  := instSafetyWinchM2.AscentPermit;
// ProcessAndSafetyPermit = Safety AND Process (ex _Raw)
ProcessAndSafetyPermitM1_Descend := ProcessPermitM1_Descend AND SafetyPermitM1_Descend;
ProcessAndSafetyPermitM2_Descend := ProcessPermitM2_Descend AND SafetyPermitM2_Descend;

// Mode "vidage à la trémie" : descente M1 ET M2 interdite tant
// que M3 n'est pas à P1 (travail) ou en position Maintenance -- verrouille la séquence
// descente-treuil / translation pour se rapprocher d'un enchaînement automatique sûr.
GVL_IHM.DredgingAssist.State.DumpAtTremieDescentLocked :=
    DumpAtTremieAssistActive AND NOT (PRG_05_Translation.M3_AtP1Stable OR PRG_05_Translation.M3_AtMaintenanceStable);
IF GVL_IHM.DredgingAssist.State.DumpAtTremieDescentLocked THEN
    ProcessAndSafetyPermitM1_Descend := FALSE;
    ProcessAndSafetyPermitM2_Descend := FALSE;
END_IF;
ProcessAndSafetyPermitM1_Ascent := SafetyPermitM1_Ascent;
ProcessAndSafetyPermitM2_Ascent := SafetyPermitM2_Ascent
    // Même anticipation que ProcessPermitM2_Descend ci-dessus.
    AND NOT (ManualBucketLimitsActive AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM >= (PRG_02_Acquisition.Data.Encoders.M1.CablePosM + _BucketCfgPersist.Config.OffsetCloseM - _BucketCfgPersist.Config.CloseAnticipationM)));

SafeStopM1_Active := SafeStopM1_Raw OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active := SafeStopM2_Raw OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
// EffectivePermit = ProcessAndSafetyPermit combine au couplage synchro (anti-télescopage)
EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM2_Descend);
EffectivePermitM2_Descend := ProcessAndSafetyPermitM2_Descend AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM1_Descend);
EffectivePermitM1_Ascent  := ProcessAndSafetyPermitM1_Ascent  AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM2_Ascent);
EffectivePermitM2_Ascent  := ProcessAndSafetyPermitM2_Ascent  AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM1_Ascent);


{endregion}

{region "§6 Execution treuils M1/M2"}
// === ⚙️ §6 EXÉCUTION FB_Winch (M1 & M2) ===

instWinchM1(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    StartStop               := M1LogicRequestStartStop,
    SafeStop                := SafeStopM1_Active,
    DescendPermit           := EffectivePermitM1_Descend,
    AscentPermit            := EffectivePermitM1_Ascent,
    Direction               := M1LogicRequestDirection,
    SpeedTgt_Pct            := M1LogicRequestSpeedCmd_Pct,
    SpeedStepTable          := _WinchSpeedStepTable,
    CfgMaxStepDescente      := SEL(instWinchSync.SyncDeviationWarn, EffectiveMaxStepDescente, 1),
    // Plafonnement au Palier 1 pour mou de câble, synchro dégradée et benne non fermée
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep OR ControlAscentActive OR instWinchSync.SyncDeviationWarn OR BucketNotClosedAscentStep1 OR SlackCableAscentStep1, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := NOT instWinchSync.Fault.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback,
    Homed                   := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomingSuspect           := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect,
    CablePosM               := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    TopLimitM               := _CommunCfgPersist.CfgCableLimitAscent_M,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowdownMaxStep      := _CommunCfgPersist.WinchSlowdownMaxStep,
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

instWinchM2(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    StartStop               := M2LogicRequestStartStop,
    SafeStop                := SafeStopM2_Active,
    DescendPermit           := EffectivePermitM2_Descend,
    AscentPermit            := EffectivePermitM2_Ascent,
    Direction               := M2LogicRequestDirection,
    SpeedTgt_Pct            := M2LogicRequestSpeedCmd_Pct,
    SpeedStepTable          := M2_SpeedStepTableActive,
    // instBucket.M2_ForceSlowSpeed
    // ("Bloque les contacteurs de vitesse de M2", commentaire FB_Bucket.st) plafonne le palier
    // autorisé pendant CLOSING_BUCKET/ouverture benne : MaxStepAscent et CfgMaxStepDescente
    // suivent instBucket.M2_ForceSlowSpeed en plus des conditions existantes.
    // instWinchSync.SyncDeviationWarn dégrade M2 au Palier 1 sur écart modéré.
    // BucketNotClosedAscentStep1 et SlackCableAscentStep1 dégradent la montée au Palier 1.
    CfgMaxStepDescente      := SEL(instBucket.M2_ForceSlowSpeed OR ManualBucketLimitsActive OR instWinchSync.SyncDeviationWarn, EffectiveMaxStepDescente, 1),
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep OR ControlAscentActive OR instBucket.M2_ForceSlowSpeed OR ManualBucketLimitsActive OR instWinchSync.SyncDeviationWarn OR BucketNotClosedAscentStep1 OR SlackCableAscentStep1, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := NOT instWinchSync.Fault.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback,
    Homed                   := PRG_02_Acquisition.Data.EncoderM2.Homed,
    HomingSuspect           := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect,
    CablePosM               := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    TopLimitM               := _CommunCfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowdownMaxStep      := _CommunCfgPersist.WinchSlowdownMaxStep,
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
);


{endregion}

{region "§7 Publication demandes brutes"}
// === 📤 §7 PUBLICATION DEMANDES BRUTES (WinchM1/M2FinalInterlockRequest) ===

WinchM1FinalInterlockRequest.Enable := TRUE;
WinchM1FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
// Plus de BrakeReleaseRequest/
// BrakeCommandOpenConfirmed calcules par FB_Winch — la barriere finale
// (FB_WinchOutputInterlock) recoit le retour PHYSIQUE brut directement,
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

WinchM2FinalInterlockRequest.Enable := TRUE;
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

{endregion}

{region "§8 Publication etats IHM"}
// === 📤 §8 PUBLICATION ÉTATS IHM (faits publics, lecture seule) ===
// SpeedDelta_Mps = variation de vitesse ENTRE DEUX SCANS (ST_WinchState.st),
// pas un écart M1/M2 (qui existe via SyncStateHMI.DeltaPos_M/instWinchSync).
// Delta temporel via mémoire scan précédent.
WinchM1State.MeasuredSpeed_Mps := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps;
WinchM1State.SpeedDelta_Mps    := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps - M1_PrevSpeed_Mps;
M1_PrevSpeed_Mps := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps;

WinchM1State.Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM;
WinchM1State.SpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct;
WinchM1State.StepNumber := instWinchM1.StepNumber;
WinchM1State.FBState := E_State.READY;
WinchM1State.Ready := instWinchM1.Ready;
WinchM1State.Busy := (instWinchM1.StepNumber > 0);
WinchM1State.Done := FALSE;
WinchM1State.Error := instWinchM1.Fault.Error;
WinchM1State.ErrorId := instWinchM1.Fault.ErrorId;
WinchM1State.RelayFwd := instWinchM1.RelayFwd;
WinchM1State.RelayRev := instWinchM1.RelayRev;
WinchM1State.Contactor1 := instWinchM1.Contactor1;
WinchM1State.Contactor2 := instWinchM1.Contactor2;
WinchM1State.Contactor3 := instWinchM1.Contactor3;
WinchM1State.Contactor4 := instWinchM1.Contactor4;
WinchM1State.BrakeCmd := PRG_06_Outputs.instWinchOutputInterlockM1.BrakeCmd;
WinchM1State.BrakeCommandOpenConfirmed := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI;
WinchM1State.FinalAuthorizedStep := instWinchM1.RequestedStep;
WinchM1State.ContactorsCheck := instWinchM1.ContactorsCheck;
WinchM1State.FinalInterlockState := PRG_06_Outputs.instWinchOutputInterlockM1.State;
WinchM1State.FinalInterlockReason := PRG_06_Outputs.instWinchOutputInterlockM1.Reason;
WinchM1State.FinalInterlockError := PRG_06_Outputs.instWinchOutputInterlockM1.Error;
WinchM1State.FinalInterlockErrorId := PRG_06_Outputs.instWinchOutputInterlockM1.ErrorId;
WinchM1State.FinalRestartInhibit := PRG_06_Outputs.instWinchOutputInterlockM1.RestartInhibit;
WinchM1State.FinalBrakeTimeoutElapsed := PRG_06_Outputs.instWinchOutputInterlockM1.BrakeTimeoutElapsed;
WinchM1State.FinalRestartDelayElapsed := PRG_06_Outputs.instWinchOutputInterlockM1.RestartDelayElapsed;
WinchM1State.FinalStepDelayElapsed := PRG_06_Outputs.instWinchOutputInterlockM1.StepDelayElapsed;
WinchM1State.Encoder.RawPos := PRG_02_Acquisition.Data.EncoderM1.Measurement.RawPos;
WinchM1State.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD1_Alarms;
WinchM1State.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD1_Warnings;
WinchM1State.Encoder.SlaveOperational := PRG_02_Acquisition.Data.Network.EncoderM1.Operational;
WinchM1State.Encoder.PresetTriggerCmd := PRG_02_Acquisition.Data.EncoderM1.HwOut.PresetTriggerCmd;
WinchM1State.Encoder.PresetValueOut := PRG_02_Acquisition.Data.EncoderM1.HwOut.PresetValueOut;
WinchM1State.Encoder.Error := PRG_02_Acquisition.Data.EncoderM1.Measurement.AbsFault.Error;
WinchM1State.Encoder.ErrorId := PRG_02_Acquisition.Data.EncoderM1.Measurement.AbsFault.ErrorId;
WinchM1State.Encoder.Homed := PRG_02_Acquisition.Data.EncoderM1.Homed;
WinchM1State.Encoder.HomingBusy := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy;
WinchM1State.Encoder.HomingDone := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Done;
WinchM1State.Encoder.HomingError := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingFault.Error;
WinchM1State.Encoder.HomingErrorId := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingFault.ErrorId;
WinchM1State.Encoder.HomingState := E_State.READY;
WinchM1State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM1State.Encoder.HomingSuspect := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect;
WinchM1State.Encoder.HomingRefRaw := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingRefRaw;
WinchM1State.InhibitActive := PRG_03_Modes_Cycle.Data.Auth.InhibitM1;
WinchM1State.BottomLimitActiveM := BottomLimitM1_Active;
WinchM1State.InTopSlowdownZone := instWinchM1.InTopSlowdownZone;
WinchM1State.InBottomSlowdownZone := instWinchM1.InBottomSlowdownZone;
WinchM1State.CommandedDirection := instWinchM1.CommandedDirection;
WinchM1State.DirectionChangeDelayElapsed := instWinchM1.DirectionChangeDelayElapsed;
WinchM1State.DirectionChangePending := instWinchM1.DirectionChangePending;

// Voir bandeau M1 ci-dessus.
WinchM2State.MeasuredSpeed_Mps := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps;
WinchM2State.SpeedDelta_Mps    := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps - M2_PrevSpeed_Mps;
M2_PrevSpeed_Mps := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps;

WinchM2State.Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM;
WinchM2State.SpeedCmd_Pct := M2LogicRequestSpeedCmd_Pct;
WinchM2State.StepNumber := instWinchM2.StepNumber;
WinchM2State.FBState := E_State.READY;
WinchM2State.Ready := instWinchM2.Ready;
WinchM2State.Busy := (instWinchM2.StepNumber > 0);
WinchM2State.Done := FALSE;
WinchM2State.Error := instWinchM2.Fault.Error;
WinchM2State.ErrorId := instWinchM2.Fault.ErrorId;
WinchM2State.RelayFwd := instWinchM2.RelayFwd;
WinchM2State.RelayRev := instWinchM2.RelayRev;
WinchM2State.Contactor1 := instWinchM2.Contactor1;
WinchM2State.Contactor2 := instWinchM2.Contactor2;
WinchM2State.Contactor3 := instWinchM2.Contactor3;
WinchM2State.Contactor4 := instWinchM2.Contactor4;
WinchM2State.BrakeCmd := PRG_06_Outputs.instWinchOutputInterlockM2.BrakeCmd;
WinchM2State.BrakeCommandOpenConfirmed := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI;
WinchM2State.FinalAuthorizedStep := instWinchM2.RequestedStep;
WinchM2State.ContactorsCheck := instWinchM2.ContactorsCheck;
WinchM2State.FinalInterlockState := PRG_06_Outputs.instWinchOutputInterlockM2.State;
WinchM2State.FinalInterlockReason := PRG_06_Outputs.instWinchOutputInterlockM2.Reason;
WinchM2State.FinalInterlockError := PRG_06_Outputs.instWinchOutputInterlockM2.Error;
WinchM2State.FinalInterlockErrorId := PRG_06_Outputs.instWinchOutputInterlockM2.ErrorId;
WinchM2State.FinalRestartInhibit := PRG_06_Outputs.instWinchOutputInterlockM2.RestartInhibit;
WinchM2State.FinalBrakeTimeoutElapsed := PRG_06_Outputs.instWinchOutputInterlockM2.BrakeTimeoutElapsed;
WinchM2State.FinalRestartDelayElapsed := PRG_06_Outputs.instWinchOutputInterlockM2.RestartDelayElapsed;
WinchM2State.FinalStepDelayElapsed := PRG_06_Outputs.instWinchOutputInterlockM2.StepDelayElapsed;
WinchM2State.Encoder.RawPos := PRG_02_Acquisition.Data.EncoderM2.Measurement.RawPos;
WinchM2State.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD2_Alarms;
WinchM2State.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD2_Warnings;
WinchM2State.Encoder.SlaveOperational := PRG_02_Acquisition.Data.Network.EncoderM2.Operational;
WinchM2State.Encoder.PresetTriggerCmd := PRG_02_Acquisition.Data.EncoderM2.HwOut.PresetTriggerCmd;
WinchM2State.Encoder.PresetValueOut := PRG_02_Acquisition.Data.EncoderM2.HwOut.PresetValueOut;
WinchM2State.Encoder.Error := PRG_02_Acquisition.Data.EncoderM2.Measurement.AbsFault.Error;
WinchM2State.Encoder.ErrorId := PRG_02_Acquisition.Data.EncoderM2.Measurement.AbsFault.ErrorId;
WinchM2State.Encoder.Homed := PRG_02_Acquisition.Data.EncoderM2.Homed;
WinchM2State.Encoder.HomingBusy := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy;
WinchM2State.Encoder.HomingDone := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Done;
WinchM2State.Encoder.HomingError := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingFault.Error;
WinchM2State.Encoder.HomingErrorId := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingFault.ErrorId;
WinchM2State.Encoder.HomingState := E_State.READY;
WinchM2State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM2State.Encoder.HomingSuspect := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect;
WinchM2State.Encoder.HomingRefRaw := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingRefRaw;
WinchM2State.InhibitActive := PRG_03_Modes_Cycle.Data.Auth.InhibitM2;
WinchM2State.BottomLimitActiveM := BottomLimitM2_Active;
WinchM2State.InTopSlowdownZone := instWinchM2.InTopSlowdownZone;
WinchM2State.InBottomSlowdownZone := instWinchM2.InBottomSlowdownZone;
WinchM2State.CommandedDirection := instWinchM2.CommandedDirection;
WinchM2State.DirectionChangeDelayElapsed := instWinchM2.DirectionChangeDelayElapsed;
WinchM2State.DirectionChangePending := instWinchM2.DirectionChangePending;

// ⛔️ Limite haute atteinte (fait public) — miroir de la butée logicielle de AscentPermit
// (Homed, hors homing, non suspect, position >= limite). Fait pur "Reached", sans bypass.
CableLimitAscentM1Reached := PRG_02_Acquisition.Data.EncoderM1.Homed
    AND NOT PRG_02_Acquisition.Data.EncoderM1.HomingSuspect
    AND NOT PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy
    AND (PRG_02_Acquisition.Data.Encoders.M1.CablePosM >= _CommunCfgPersist.CfgCableLimitAscent_M);
CableLimitAscentM2Reached := PRG_02_Acquisition.Data.EncoderM2.Homed
    AND NOT PRG_02_Acquisition.Data.EncoderM2.HomingSuspect
    AND NOT PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy
    AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM >= (_CommunCfgPersist.CfgCableLimitAscent_M + M2_LimitShift));

WinchM1Safety.CableLimitAscent := CableLimitAscentM1Reached;
WinchM1Safety.CableLimitDescent := (PRG_02_Acquisition.Data.Encoders.M1.CablePosM <= _WinchM1CfgPersist.CfgCableLimitDescent_M);
WinchM1Safety.SafeStop := SafeStopM1_Active;
WinchM1Safety.AscentPermit := EffectivePermitM1_Ascent;
WinchM1Safety.DescendPermit := EffectivePermitM1_Descend;
WinchM1Safety.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI;
WinchM1Safety.PowerCutOff := instSafetyWinchM1.PowerCutOff;
WinchM1Safety.Error := instWinchM1.Fault.Error OR instSafetyWinchM1.Fault.Error;
WinchM1Safety.ErrorId := instSafetyWinchM1.Fault.ErrorId;
WinchM1Safety.ErrorOperatorComm  := (instSafetyWinchM1.Fault.ErrorId AND 16#0001) <> 0;
WinchM1Safety.ErrorEncoder       := (instSafetyWinchM1.Fault.ErrorId AND 16#0002) <> 0;
WinchM1Safety.ErrorPhaseRotation := (instSafetyWinchM1.Fault.ErrorId AND 16#0010) <> 0;
WinchM1Safety.ErrorBrakeThermal  := (instSafetyWinchM1.Fault.ErrorId AND 16#0400) <> 0;
WinchM1Safety.ErrorMecaA         := (instSafetyWinchM1.Fault.ErrorId AND 16#0080) <> 0;
WinchM1Safety.ErrorMecaB         := (instSafetyWinchM1.Fault.ErrorId AND 16#0100) <> 0;
WinchM1Safety.ErrorMecaC         := (instSafetyWinchM1.Fault.ErrorId AND 16#0200) <> 0;
WinchM1Safety.ErrorMecaD         := (instSafetyWinchM1.Fault.ErrorId AND 16#0800) <> 0;
WinchM1Safety.ErrorMecaE         := (instSafetyWinchM1.Fault.ErrorId AND 16#3000) <> 0;
WinchM1Safety.ErrorOppositeDir   := (instSafetyWinchM1.Fault.ErrorId AND 16#4000) <> 0;
WinchM1Safety.ErrorNoMovement    := (instSafetyWinchM1.Fault.ErrorId AND 16#8000) <> 0;
WinchM1Safety.PowerCutOffSafety  := PRG_06_Outputs.M1PowerCutOffSafetyInfo;
WinchM1Safety.SafeStopSafety     := PRG_06_Outputs.M1SafeStopSafetyInfo;
WinchM1Safety.BlockedBySafety    := PRG_06_Outputs.M1BlockedBySafetyInfo;

WinchM2Safety.CableLimitAscent := CableLimitAscentM2Reached;
WinchM2Safety.CableLimitDescent := (PRG_02_Acquisition.Data.Encoders.M2.CablePosM <= _WinchM2CfgPersist.CfgCableLimitDescent_M);
WinchM2Safety.SafeStop := SafeStopM2_Active;
WinchM2Safety.AscentPermit := EffectivePermitM2_Ascent;
WinchM2Safety.DescendPermit := EffectivePermitM2_Descend;
WinchM2Safety.SlackCable := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI;
WinchM2Safety.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI;
WinchM2Safety.PowerCutOff := instSafetyWinchM2.PowerCutOff;
WinchM2Safety.Error := instWinchM2.Fault.Error OR instSafetyWinchM2.Fault.Error;
WinchM2Safety.ErrorId := instSafetyWinchM2.Fault.ErrorId;
WinchM2Safety.ErrorOperatorComm  := (instSafetyWinchM2.Fault.ErrorId AND 16#0001) <> 0;
WinchM2Safety.ErrorEncoder       := (instSafetyWinchM2.Fault.ErrorId AND 16#0002) <> 0;
WinchM2Safety.ErrorPhaseRotation := (instSafetyWinchM2.Fault.ErrorId AND 16#0010) <> 0;
WinchM2Safety.ErrorBrakeThermal  := (instSafetyWinchM2.Fault.ErrorId AND 16#0400) <> 0;
WinchM2Safety.ErrorMecaA         := (instSafetyWinchM2.Fault.ErrorId AND 16#0080) <> 0;
WinchM2Safety.ErrorMecaB         := (instSafetyWinchM2.Fault.ErrorId AND 16#0100) <> 0;
WinchM2Safety.ErrorMecaC         := (instSafetyWinchM2.Fault.ErrorId AND 16#0200) <> 0;
WinchM2Safety.ErrorMecaD         := (instSafetyWinchM2.Fault.ErrorId AND 16#0800) <> 0;
WinchM2Safety.ErrorMecaE         := (instSafetyWinchM2.Fault.ErrorId AND 16#3000) <> 0;
WinchM2Safety.ErrorOppositeDir   := (instSafetyWinchM2.Fault.ErrorId AND 16#4000) <> 0;
WinchM2Safety.ErrorNoMovement    := (instSafetyWinchM2.Fault.ErrorId AND 16#8000) <> 0;
WinchM2Safety.PowerCutOffSafety  := PRG_06_Outputs.M2PowerCutOffSafetyInfo;
WinchM2Safety.SafeStopSafety     := PRG_06_Outputs.M2SafeStopSafetyInfo;
WinchM2Safety.BlockedBySafety    := PRG_06_Outputs.M2BlockedBySafetyInfo;

SyncState.DeltaPos_M := instWinchSync.SignedDeltaPosM;
SyncState.SyncActive := instWinchSync.SyncActive;
SyncState.SyncWarn := instWinchSync.SyncWarn;
SyncState.SyncDeviationWarn := instWinchSync.SyncDeviationWarn;
SyncState.Ready := instWinchSync.Ready;
SyncState.Error := instWinchSync.Fault.Error;
SyncState.ErrorId := instWinchSync.Fault.ErrorId;
SyncState.FBState := E_State.READY;

BucketState.MechState := _BucketState;
BucketState.MechState.ActiveOffsetValid := instBucket.ActiveOffsetValid;
BucketState.FBState := E_State.READY;
BucketState.ActiveOffset_M := instBucket.ActiveOffsetM;
BucketState.M2StartStop := instBucket.M2_StartStop;
BucketState.M2Direction := instBucket.M2_Direction;
BucketState.M2ForceSlowSpeed := instBucket.M2_ForceSlowSpeed;
BucketState.M2PositionCorrected := PRG_02_Acquisition.Data.Encoders.M2.CablePosM - instBucket.ActiveOffsetM;
BucketState.Ready := instBucket.Ready;
BucketState.Busy := instBucket.Lifecycle.Busy;
BucketState.Done := instBucket.Lifecycle.Done;
BucketState.Error := instBucket.Fault.Error;
BucketState.ErrorId := instBucket.Fault.ErrorId;
BucketState.RemainingTravel_M := instBucket.RemainingTravelM;
BucketState.DeltaPosition_M := instBucket.DeltaPosition_M;
BucketState.CloseActive := instBucket.CloseReq;
BucketState.OpenActive := instBucket.OpenReq;
// Reflète le séquencement auto : occupé sur une ouverture/fermeture qu'IL a armée, ou en phase
// vitesse contrôlée post-fermeture.
BucketState.AutoBucketSeqActive := (instBucket.Lifecycle.Busy AND (CoupledDiveBucketOpenArmed OR CoupledAscentBucketCloseArmed)) OR ControlAscentActive;
BucketState.CoupledDiveOpenArmed := CoupledDiveBucketOpenArmed;
BucketState.CoupledAscentCloseArmed := CoupledAscentBucketCloseArmed;
BucketState.ControlAscentActive := ControlAscentActive;
BucketState.CoupledMotionBlockedByBucket := CoupledMotionBlockedByBucket;
GVL_IHM.Commun.KoboldImmersionConfirmed := KoboldImmersionConfirmed;
GVL_IHM.Commun.KoboldBottomTouchLatched := KoboldBottomTouchLatched;

// Tolérance matière benne : « à peu près fermée » = fermée OU
// intermédiaire proche de l'offset fermé (tolérance 2 m). Évite le blocage au fond sur
// matière dense (galets) qui ne ferme jamais à 100% de la consigne fine.
Benne_IsRoughlyClosed := _BucketState.IsClosed
    OR (_BucketState.IsIntermediate
        AND (instBucket.DeltaPosition_M >= (_BucketCfgPersist.Config.OffsetCloseM - 2.0)));

// === 🔌 PUBLICATION BUS INTER-PRG (Data : ST_WinchInterPrg) ===
// Copie des structs internes vers le bus de sortie (producteur unique).
Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;
Data.WinchM2FinalInterlockRequest := WinchM2FinalInterlockRequest;
Data.M1LogicRequestSpeedCmd_Pct   := M1LogicRequestSpeedCmd_Pct;
Data.M2LogicRequestSpeedCmd_Pct   := M2LogicRequestSpeedCmd_Pct;
Data.KoboldContactorCmdArbitrated := KoboldContactorCmdArbitrated;
Data.WinchM1State                 := WinchM1State;
Data.WinchM2State                 := WinchM2State;
Data.WinchM1Safety                := WinchM1Safety;
Data.WinchM2Safety                := WinchM2Safety;
Data.SyncState                    := SyncState;
Data.BucketState                  := BucketState;
Data.Benne_IsRoughlyClosed        := Benne_IsRoughlyClosed;

{endregion}
END_PROGRAM

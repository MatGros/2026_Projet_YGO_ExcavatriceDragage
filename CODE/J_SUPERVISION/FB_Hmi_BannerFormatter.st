(* ═══════════════════════════════════════════════════════════════
   🧠 FB_Hmi_BannerFormatter — Formateur du bandeau d'information IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md §5, §6
   🎯 Responsabilité : assemble les 4 textes du bandeau + le carrousel
      d'alarmes, expose la cause observable du blocage courant, sans
      piloter la machine.
   🛡️ Sécurité : priorité AU/puissance, SafeStop, puis interlocks métier.
      L'anti-clignotement est délégué à FB_AntiFlickerText (AF-07 §5.3).
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Hmi_BannerFormatter
VAR_INPUT
    Enable               : BOOL := TRUE;   // --> [CMD] Active le formateur
    SimulationModeActive : BOOL;   // --> [TST] Mode simulation actif
    CurrentMode          : E_Mode;   // --> [CMD] Mode courant
    BothAxesCoupled      : BOOL;   // --> [HW] Treuils M1/M2 couplés
    WinchSelected        : INT; // --> [CMD] 1 = M1, 2 = M2

    // 🔄 Cycle & sous-cycles
    CycleStep            : E_AutoCycleStep;   // --> [HW] Étape cycle
    CycleStateStr        : STRING(80);   // --> [HW] Libellé détaillé de l'étape cycle (FB_CycleSemiAuto.CycleStateStr)
    CycleErrorId         : WORD;   // --> [DIAG] Code défaut cycle (FB_CycleSemiAuto.ErrorId) — notifié à AX_STAB
    CycleStepAtError     : E_AutoCycleStep;   // --> [DIAG] Dernière étape avant le défaut (FB_CycleSemiAuto.CycleStepAtError)
    DiveState            : E_DiveSearchState;   // --> [HW] État plongée
    ExtractionState      : E_ExtractionAssistState;   // --> [HW] État extraction
    MachineHomingStep        : INT;   // --> [HW] Étape guide homing machine (E_MachineHomingStep : 0..70, 60 = valide)
    MachineHomingInstruction : STRING(120);   // --> [HW] Consigne opérateur en clair produite par FB_MachineHomingCycle

    // 🛡️ Dérogations & particularités
    BypassGlobalActive   : BOOL;   // --> [TST] Bypass global
    BypassWinchM1Active  : BOOL;   // --> [TST] Bypass treuil M1
    BypassWinchM2Active  : BOOL;   // --> [TST] Bypass treuil M2
    BypassTranslation    : BOOL;   // --> [TST] Bypass translation
    BypassSyncActive     : BOOL;   // --> [TST] Bypass synchro
    SyncDegradedActive   : BOOL;   // --> [TST] Synchro bridée
    LegalLimitReached    : BOOL;   // --> [SAFE] Limite légale atteinte
    ModeChangePendingBlocked : BOOL;   // --> [DIAG] Bascule de mode refusée (treuils non à l'arrêt)
    ModeChangeBlockReason    : STRING(40); // --> [DIAG] Motif du blocage de bascule (ex. "Chgt mode refuse : contacteur M1")

    // 🎮 Sécurité, causes et intention de direction
    EmergencyChainClosed : BOOL;   // --> [SAFE] Chaîne AU fermée
    PowerContactorEngaged: BOOL;   // --> [SAFE] Contacteur puissance
    PowerCutOffActiveAny : BOOL;   // --> [SAFE] Coupure puissance active
    SafeStopActive       : BOOL; // --> [SAFE] Agrégat M1/M2 par OR — tout SafeStop affiché (bandeau conservateur)
    DescendPermit        : BOOL; // --> [SAFE] Agrégat M1/M2 par AND
    AscentPermit         : BOOL; // --> [SAFE] Agrégat M1/M2 par AND
    BucketIsOpen         : BOOL;   // --> [HW] Benne ouverte
    BucketIsClosed       : BOOL;   // --> [HW] Benne fermee (montee non bridée)
    DiveActive           : BOOL;   // --> [HW] Plongée active
    TopLimitReached      : BOOL; // --> [SAFE] Agrégat M1/M2 par OR — toute limite haute affichée
    WinchBothMotionDirection : INT;   // --> [CMD] Direction demandée couplée
    M1LogicRequestDirection     : INT;   // --> [CMD] Direction logique M1
    M2LogicRequestDirection     : INT;   // --> [CMD] Direction logique M2
    CycleRequestDirection      : INT;   // --> [CMD] Direction cycle
    DeadmanArmed         : BOOL;   // --> [SAFE] Homme-mort armé
    JoystickAtNeutral    : BOOL;   // --> [HW] Joystick au neutre
    CycleAutoBusy        : BOOL;   // --> [HW] Cycle auto actif
    M3AtP1               : BOOL;   // --> [STAT] M3 positionné stable au Point 1

    // 🚨 Bandeau d'alarme défilant (§5) — diagnostics safety et ErrorId machine entière
    WinchM1Safety        : ST_SafetyWinch;       // --> [SAFE] Diagnostic sécurité treuil M1
    WinchM2Safety        : ST_SafetyWinch;       // --> [SAFE] Diagnostic sécurité treuil M2
    TranslationSafety    : ST_SafetyTranslation; // --> [SAFE] Diagnostic sécurité translation M3
    BucketErrorId        : WORD;   // --> [DIAG] Code défaut benne (FB_Bucket.ErrorId)
    SyncErrorId          : WORD;   // --> [DIAG] Code défaut synchro M1/M2 (FB_WinchSync.ErrorId)
    SyncContactorDiag    : ST_SyncContactorDiag;   // --> [DIAG] Discordance contacteurs M1/M2 décodée (FB_SyncContactor PRG_06 §2quinquies)
    DiveErrorId          : WORD;   // --> [DIAG] Code défaut plongée (FB_DiveSearch.ErrorId)
    ExtractionErrorId    : WORD;   // --> [DIAG] Code défaut extraction (FB_ExtractionAssist.ErrorId)
    EmergencyErrorId     : WORD;   // --> [DIAG] Code défaut chaîne AU (FB_Safety_EmergencyManagement.Diag.ErrorId)
    RedundancyTestFailed : BOOL;   // --> [DIAG] Defaut redondance contacteurs AU (lisee -> message explicite)
    EmergencyArmingFailed: BOOL;   // --> [DIAG] Echec rearmement contacteur AU (lisee -> message explicite)
    ArmingSeqStep        : INT;    // --> [DIAG] Etape sequence rearmement AU (0=IDLE..6=Confirm) — front descendant = abandon
    LastAbortCause       : WORD;   // --> [DIAG] Cause du dernier abandon de sequence AU (message explicite cause+action)
    Reset                : BOOL;   // --> [CMD] Front acquittement defauts (FaultMachineReset_IHM) — efface le message d'abandon verrouillé
    AlarmHoldTime        : TIME := T#1s; // --> [CFG] Durée d'affichage par message du carrousel
    Network              : ST_NetworkDiagHMI; // --> [DIAG] Diagnostic réseau, bus et modules E/S
END_VAR
VAR_OUTPUT
    Banner               : ST_HmiBanner;   // <-- [STAT] Bandeau IHM assemblé
END_VAR
VAR
    PrefixContext        : STRING(20);   // . [LOC] Préfixe RÉEL/SIMU
    ModeStr              : STRING(30);   // . [LOC] Libellé mode
    CouplingStr          : STRING(30);   // . [LOC] Libellé couplage
    CurrentDirection     : INT;   // . [LOC] Direction courante
    DirectionBlocked     : BOOL; // . [LOC] Interlock métier : mouvement demandé mais permit absent
    AnyBypassActive      : BOOL;   // . [LOC] Au moins un bypass actif
    PowerOrChainFault    : BOOL; // . [LOC] Défaut chaîne AU ou contacteur puissance absent
    HardwareModuleOrBusFault : BOOL; // . [LOC] Défaut matériel module E/S ou bus actif
    CriticalActionActive : BOOL; // . [LOC] Défaut/interlock critique : affiché immédiatement (sans maintien)
    SpecialConditionCandidate : STRING(120);   // . [LOC] Texte condition spéciale
    OperatorActionCandidate   : STRING(120);   // . [LOC] Texte action opérateur
    StepAtErrorStr            : STRING(40);   // . [LOC] Libellé de l'étape d'origine du défaut
    AntiFlickSpecial     : FB_AntiFlickerText; // * [INST] §3 Condition spéciale (warning → maintenu)
    AntiFlickOperator    : FB_AntiFlickerText; // * [INST] §4 Action opérateur (critique → direct, warning → maintenu)
    LastAbortEdge        : F_TRIG; // . [LOC] Front descendant ArmingSeqStep (abandon de sequence AU)
    ArmingInProgress     : BOOL; // . [LOC] Sequence AU en cours (ArmingSeqStep <> 0)
    ResetEdge            : R_TRIG; // . [LOC] Front montant Reset (acquittement defauts)
    ArmStartEdge         : R_TRIG; // . [LOC] Front montant ArmingInProgress (nouvelle sequence AU)
    TonAbortHold         : TON; // . [LOC] Maintien du message d'abandon AU (causes non latched)
    AbortMsgActive       : BOOL; // . [LOC] Message d'abandon AU affiché (fenêtre de maintien)
    AbortMsgLatched      : BOOL; // . [LOC] Message d'abandon verrouillé jusqu'à Reset (causes sans latch)
    AbortMsgText         : STRING(120); // . [LOC] Texte cause+action du dernier abandon AU
    SeqReachedConfirm    : BOOL; // . [LOC] La sequence AU a atteint l'etape 6 (confirmation) -> distingue SUCCES d'un ABANDON
    TonAlarmBanner       : TON; // . [LOC] §5 Tempo de maintien par message du carrousel
    AlarmArray           : ARRAY[0..49] OF STRING(120); // . [LOC] §5 Messages actifs collectés ce scan
    AlarmCount           : INT; // . [LOC] §5 Nombre de messages actifs
    BannerSyncContactorWhich : STRING(80); // . [LOC] §5 Libellé du contacteur M1/M2 en discordance
    AlarmIndex           : INT; // . [LOC] §5 Index courant du carrousel (0-based)
    i                    : INT; // . [LOC] Index de boucle
    TonBootInhibit       : TON; // . [LOC] Garde au démarrage (inhibition fausses alarmes réseau 4s)
    TofFaultLocalIo      : TOF; // . [LOC] Anti-bagotement Local_Digital_IO (1.5s)
    TofFaultVh0800       : TOF; // . [LOC] Anti-bagotement VH_0800END (1.5s)
    TofFaultVh0808       : TOF; // . [LOC] Anti-bagotement VH_0808ETP (1.5s)
    TofFaultVh0008Er     : TOF; // . [LOC] Anti-bagotement VH_0008ER (1.5s)
    TofFaultVh0008Er1    : TOF; // . [LOC] Anti-bagotement VH_0008ER_1 (1.5s)
    TofFaultCanBus       : TOF; // . [LOC] Anti-bagotement bus CANopen (1.5s)
    TofFaultJoy1         : TOF; // . [LOC] Anti-bagotement Joystick JOY1 (1.5s)
    TofFaultEcatBus      : TOF; // . [LOC] Anti-bagotement bus EtherCAT (1.5s)
    TofFaultEncM1        : TOF; // . [LOC] Anti-bagotement EtherCAT Encoder M1 (1.5s)
    TofFaultEncM2        : TOF; // . [LOC] Anti-bagotement EtherCAT Encoder M2 (1.5s)
    TofFaultVarM3        : TOF; // . [LOC] Anti-bagotement EtherCAT Variateur M3 (1.5s)
    LocalIoValid         : BOOL; // . [LOC] Validité filtrée Local_Digital_IO (DI8/DO8)
    Vh0800Valid          : BOOL; // . [LOC] Validité filtrée VH_0800END (DI8)
    Vh0808Valid          : BOOL; // . [LOC] Validité filtrée VH_0808ETP (DI8/DO8)
    Vh0008ErValid        : BOOL; // . [LOC] Validité filtrée VH_0008ER (DO8 Relais Freins/Kobold)
    Vh0008Er1Valid       : BOOL; // . [LOC] Validité filtrée VH_0008ER_1 (DO8 Relais AU/PowerKeepAlive)
    CanBusValid          : BOOL; // . [LOC] Validité filtrée Bus CANopen
    Joy1Valid            : BOOL; // . [LOC] Validité filtrée Joystick JOY1
    EcatBusValid         : BOOL; // . [LOC] Validité filtrée Bus EtherCAT
    EncM1Valid           : BOOL; // . [LOC] Validité filtrée Encoder M1
    EncM2Valid           : BOOL; // . [LOC] Validité filtrée Encoder M2
    VarM3Valid           : BOOL; // . [LOC] Validité filtrée Variateur M3
    HistoM1              : WORD; // . [LOC] §5 [HISTO] M1 : LatchedId AND NOT ErrorId (défauts latched passés)
    HistoM2              : WORD; // . [LOC] §5 [HISTO] M2 : LatchedId AND NOT ErrorId (défauts latched passés)
    HistoM3              : WORD; // . [LOC] §5 [HISTO] M3 : LatchedId AND NOT ErrorId (défauts latched passés)
END_VAR
VAR CONSTANT
    CST_BannerHoldTime   : TIME := T#500ms; // . [LOC] Anti-clignotement warnings/états (AF-07 §5.3)
    CST_AbortHoldTime    : TIME := T#5s; // . [LOC] Maintien message d'abandon AU
    CST_NbMaxAlarmes     : INT := 50; // . [LOC] Taille du carrousel d'alarmes (AF-07 §6)
END_VAR

IF NOT Enable THEN
    Banner.GlobalContextText     := '';
    Banner.SequenceProgressText  := '';
    Banner.SpecialConditionText  := '';
    Banner.OperatorActionText    := '';
    Banner.PositionM3Text        := '';
    Banner.AlarmBanner.HasAlarm  := FALSE;
    Banner.AlarmBanner.Text      := '';
    Banner.AlarmBanner.Index     := 0;
    Banner.AlarmBanner.Count     := 0;
    FOR i := 0 TO 49 DO
        Banner.AlarmBanner.AlarmArray[i] := '';
    END_FOR;
    TonAlarmBanner(IN := FALSE);
    TonBootInhibit(IN := FALSE);
    TofFaultLocalIo(IN := FALSE);
    TofFaultVh0800(IN := FALSE);
    TofFaultVh0808(IN := FALSE);
    TofFaultVh0008Er(IN := FALSE);
    TofFaultVh0008Er1(IN := FALSE);
    TofFaultCanBus(IN := FALSE);
    TofFaultJoy1(IN := FALSE);
    TofFaultEcatBus(IN := FALSE);
    TofFaultEncM1(IN := FALSE);
    TofFaultEncM2(IN := FALSE);
    TofFaultVarM3(IN := FALSE);
    RETURN;
END_IF;

// ⏱️ Garde au démarrage (inhibition 4s pendant init des bus et équipements)
TonBootInhibit(IN := Enable, PT := T#4s);

// 🌊 Filtrage anti-bagotement (TOF 1.5s sur perte de validité)
TofFaultLocalIo(IN := (NOT Network.InputModules.LocalDigitalIoOk) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultVh0800(IN := (NOT Network.InputModules.Vh0800EndOk) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultVh0808(IN := (NOT Network.InputModules.Vh0808EtpOk) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultVh0008Er(IN := (NOT Network.InputModules.Vh0008ErOk) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultVh0008Er1(IN := (NOT Network.InputModules.Vh0008Er1Ok) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultCanBus(IN := (NOT Network.BusCanOpen.Operational) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultJoy1(IN := (NOT Network.Joystick.Operational) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultEcatBus(IN := (NOT Network.BusEthercat.Operational) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultEncM1(IN := (NOT Network.EncoderM1.Operational) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultEncM2(IN := (NOT Network.EncoderM2.Operational) AND TonBootInhibit.Q, PT := T#1.5s);
TofFaultVarM3(IN := (NOT Network.VariateurM3.Operational) AND TonBootInhibit.Q, PT := T#1.5s);

LocalIoValid   := NOT TofFaultLocalIo.Q;
Vh0800Valid    := NOT TofFaultVh0800.Q;
Vh0808Valid    := NOT TofFaultVh0808.Q;
Vh0008ErValid  := NOT TofFaultVh0008Er.Q;
Vh0008Er1Valid := NOT TofFaultVh0008Er1.Q;
CanBusValid    := NOT TofFaultCanBus.Q;
Joy1Valid      := NOT TofFaultJoy1.Q;
EcatBusValid   := NOT TofFaultEcatBus.Q;
EncM1Valid     := NOT TofFaultEncM1.Q;
EncM2Valid     := NOT TofFaultEncM2.Q;
VarM3Valid     := NOT TofFaultVarM3.Q;

{region "§1 Contexte global"}
// ═══════════════════════════════════════════════════════════════
// 1. CONTEXTE GLOBAL — aucun numéro d'étape ici
// Format (AF-07 §5.1) : [RÉEL/SIMU] [MODE] [COUPLAGE]
// ═══════════════════════════════════════════════════════════════
IF SimulationModeActive THEN
    PrefixContext := '[SIMULATION] ';
ELSE
    PrefixContext := '[RÉEL] ';
END_IF;

CASE CurrentMode OF
    E_Mode.DISABLE:  ModeStr := '[DÉSACTIVÉ]';
    E_Mode.MAINT_N1: ModeStr := '[MAINT_N1]';
    E_Mode.MAINT_N2: ModeStr := '[MAINT_N2]';
    E_Mode.SEMI_AUTO: ModeStr := '[SEMI-AUTO]';
ELSE
    ModeStr := '[MODE INCONNU]';
END_CASE;

IF CurrentMode = E_Mode.SEMI_AUTO THEN
    CouplingStr := ' [CYCLE AUTO]';
ELSIF BothAxesCoupled THEN
    CouplingStr := ' [M1+M2 COUPLÉS]';
ELSIF WinchSelected = 1 THEN
    CouplingStr := ' [M1 SEUL]';
ELSIF WinchSelected = 2 THEN
    CouplingStr := ' [M2 SEUL]';
ELSE
    CouplingStr := ' [AUCUN AXE]';
END_IF;
Banner.GlobalContextText := CONCAT(CONCAT(PrefixContext, ModeStr), CouplingStr);
{endregion}

{region "§2 Progression"}
// ═══════════════════════════════════════════════════════════════
// 2. PROGRESSION — le numéro et l'étape restent exclusivement ici
// Format (AF-07 §5.1) : Macro: <Cycle> > Sous-cycle: <Étape>
// ═══════════════════════════════════════════════════════════════
// Guide homing machine : source unique = FB_MachineHomingCycle (1 texte par étape).
// Prioritaire tant que non valide (SEMI_AUTO est de toute façon interdit sans MachineHomed).
IF (MachineHomingStep > 0) AND (MachineHomingStep <> 60) THEN
    Banner.SequenceProgressText := CONCAT('Homing: ', MachineHomingInstruction);
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    // Détail de l'étape (FB_CycleSemiAuto.CycleStateStr) prioritaire ; label court en fallback.
    IF CycleStateStr <> '' THEN
        Banner.SequenceProgressText := CONCAT('Cycle: ', CycleStateStr);
    ELSE
        CASE CycleStep OF
            E_AutoCycleStep.AX0_REPOS: Banner.SequenceProgressText := 'Cycle: PRÉPARATION';
            E_AutoCycleStep.AX1_INIT: Banner.SequenceProgressText := 'Cycle: CONDITIONS INITIALES';
            E_AutoCycleStep.AX2_TRANSLATE_P1: Banner.SequenceProgressText := 'Cycle: TRANSLATION P1';
            E_AutoCycleStep.AX3_OPEN_BUCKET: Banner.SequenceProgressText := 'Cycle: OUVERTURE BENNE';
            E_AutoCycleStep.AX4_DESCEND_DIVING: Banner.SequenceProgressText := 'Cycle: PLONGÉE PALIER 4';
            E_AutoCycleStep.AX5_KOBOLD_INIT: Banner.SequenceProgressText := 'Cycle: INIT KOBOLD';
            E_AutoCycleStep.AX6_SEARCH_IMMERSION: Banner.SequenceProgressText := 'Cycle: RECHERCHE IMMERSION';
            E_AutoCycleStep.AX7_SEARCH_BOTTOM: Banner.SequenceProgressText := 'Cycle: RECHERCHE FOND';
            E_AutoCycleStep.AX8_BOTTOM_CONFIRMED: Banner.SequenceProgressText := 'Cycle: FOND CONFIRMÉ';
            E_AutoCycleStep.AX_DIVING_RETRY: Banner.SequenceProgressText := 'Cycle: REPRISE PLONGÉE';
            E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM: Banner.SequenceProgressText := 'Cycle: RETENTE CÂBLES';
            E_AutoCycleStep.AX10_CLOSE_BUCKET: Banner.SequenceProgressText := 'Cycle: FERMETURE BENNE';
            E_AutoCycleStep.AX11_CTRL_ASCENT: Banner.SequenceProgressText := 'Cycle: MONTÉE CONTRÔLE';
            E_AutoCycleStep.AX12_LOADED_ASCENT: Banner.SequenceProgressText := 'Cycle: REMONTÉE CHARGÉE';
            E_AutoCycleStep.AX13_DRAIN_PAUSE: Banner.SequenceProgressText := 'Cycle: ÉGOUTTAGE';
            E_AutoCycleStep.AX14_TRANSLATE_DUMP: Banner.SequenceProgressText := 'Cycle: TRANSLATION TRÉMIE';
            E_AutoCycleStep.AX15A_DUMP_ARRIVE, E_AutoCycleStep.AX15B_DUMP_OPEN, E_AutoCycleStep.AX15C_DUMP_REPOSITION: Banner.SequenceProgressText := 'Cycle: VIDAGE BENNE';
            E_AutoCycleStep.AX18_DONE_SYNC: Banner.SequenceProgressText := 'Cycle: TERMINÉ - ALLER P1';
            E_AutoCycleStep.AX_STAB: Banner.SequenceProgressText := 'Cycle: STABILISATION';
        ELSE
            Banner.SequenceProgressText := 'Cycle: ÉTAPE EN COURS';
        END_CASE;
    END_IF;
ELSIF CurrentMode = E_Mode.MAINT_N1 OR CurrentMode = E_Mode.MAINT_N2 THEN
    Banner.SequenceProgressText := 'Manuel: PILOTAGE DIRECT';
ELSE
    Banner.SequenceProgressText := 'Machine: ARRÊTÉE';
END_IF;
{endregion}

{region "§2bis Position M3"}
// État indépendant : ne participe pas aux arbitrages des quatre champs historiques
// ni au carrousel des défauts. M3AtP1 est publié par PRG_05 puis projeté par PRG_07.
IF M3AtP1 THEN
    Banner.PositionM3Text := 'Position M3 : P1';
ELSE
    Banner.PositionM3Text := '';
END_IF;
{endregion}

{region "§3 Condition spéciale"}
// ═══════════════════════════════════════════════════════════════
// 3. CONDITION SPÉCIALE — un seul indicateur bypass/dérogation
// Format (AF-07 §5.1) : ATTENTION: <Dérogation / Bridage / Alerte>
// 🧊 Warning → maintenu min (anti-clignotement), jamais critique.
// ⚠️ La simulation n'est PAS un bypass : elle n'apparaît que dans le
//    contexte global (champ 1), jamais ici.
// ═══════════════════════════════════════════════════════════════
AnyBypassActive := BypassGlobalActive
                OR BypassWinchM1Active
                OR BypassWinchM2Active
                OR BypassTranslation
                OR BypassSyncActive;
IF ModeChangePendingBlocked AND ModeChangeBlockReason <> '' THEN
    // Bascule de mode refusée : motif prioritaire (info opérateur, ex. "Chgt mode refuse : contacteur M1").
    SpecialConditionCandidate := ModeChangeBlockReason;
ELSIF AnyBypassActive THEN
    SpecialConditionCandidate := 'ATTENTION: Bypass actif';
ELSIF SyncDegradedActive THEN
    SpecialConditionCandidate := 'ATTENTION: Synchro bridée';
ELSIF LegalLimitReached THEN
    SpecialConditionCandidate := 'ATTENTION: Limite légale';
ELSE
    SpecialConditionCandidate := '';
END_IF;

AntiFlickSpecial(NewText := SpecialConditionCandidate, ForceInstant := FALSE, HoldTime := CST_BannerHoldTime);
Banner.SpecialConditionText := AntiFlickSpecial.Text;
{endregion}

{region "§4 Action opérateur"}
// ═══════════════════════════════════════════════════════════════
// 4. ACTION — cause fixe, sécurité d'abord, sans rotation
// Format (AF-07 §5.1) : [ORGANE] <Action physique> > <Fin>
// 🧊 Défauts (AU/puissance/SafeStop) + interlock DirectionBlocked
//    → affichés immédiatement (ForceInstant=TRUE) ; les autres états
//    → maintenus min (anti-clignotement).
// ═══════════════════════════════════════════════════════════════
IF CurrentMode = E_Mode.SEMI_AUTO THEN
    CurrentDirection := CycleRequestDirection;
ELSIF BothAxesCoupled THEN
    CurrentDirection := WinchBothMotionDirection;
ELSIF WinchSelected = 1 THEN
    CurrentDirection := M1LogicRequestDirection;
ELSIF WinchSelected = 2 THEN
    CurrentDirection := M2LogicRequestDirection;
ELSE
    CurrentDirection := 0;
END_IF;

DirectionBlocked := (CurrentDirection < 0 AND NOT DescendPermit)
                OR (CurrentDirection > 0 AND NOT AscentPermit);

// 🩹 Signaler la cause du dernier abandon de séquence AU (message cause+action),
// sans modifier le comportement de l'AU. Front descendant ArmingSeqStep (sequence en
// cours -> 0) = fin de sequence.
// 🐛 BUG A corrigé : l'ancien gating `NOT PowerContactorEngaged` supprimait le message
// d'abandon à l'étape 5 (PowerCutOff) car le contacteur venait d'être pulsé
// (PowerContactorEngaged=TRUE). On déclenche désormais sur la CAUSE (LastAbortCause <> 0),
// en excluant uniquement le SUCCÈS réel (séquence ayant atteint l'étape 6 de confirmation
// ET contacteur engagé au retour à IDLE) — un succès ne produit AUCUN message (AC4).
// Verrouillage : les causes SANS latch (CST_ABORT_POWER_CUTOFF, CST_ABORT_TIMEOUT_RESTORE_A/B)
// restauration) restent affichées jusqu'à Reset (ou nouvelle séquence) pour que
// l'opérateur voie l'échec. Les causes déjà latched (CST_ABORT_CHAIN_DROP/REDUNDANCY_A/B/
// TIMEOUT_CONTACTOR) et la coupe volontaire (CST_ABORT_CUT_IHM) ne sont pas verrouillées.
ArmingInProgress := (ArmingSeqStep <> 0);
LastAbortEdge(CLK := ArmingInProgress);
ResetEdge(CLK := Reset);
ArmStartEdge(CLK := ArmingInProgress);

// 🩹 Détection d'un SUCCÈS de séquence : la séquence a atteint l'étape 6 (confirmation).
// Ce drapeau est consommé par le test de LastAbortEdge ci-dessous AVANT d'être remis à
// zéro hors séquence (fin de bloc), pour distinguer un succès d'un abandon à l'étape 5.
IF ArmingSeqStep = 6 THEN
    SeqReachedConfirm := TRUE;
END_IF;

IF LastAbortEdge.Q AND (LastAbortCause <> 0) AND NOT (SeqReachedConfirm AND PowerContactorEngaged) THEN
    AbortMsgActive := TRUE;
    AbortMsgLatched := (LastAbortCause = INT_TO_WORD(CST_ABORT_POWER_CUTOFF)) OR (LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_A)) OR (LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_B));
    TonAbortHold(IN := FALSE);
END_IF;

// Effacement : Reset OU nouvelle séquence (évite le message périmé après réarmement réussi)
IF ResetEdge.Q OR ArmStartEdge.Q THEN
    AbortMsgActive := FALSE;
    AbortMsgLatched := FALSE;
    TonAbortHold(IN := FALSE);
END_IF;

// Remise à zéro du drapeau de confirmation hors séquence (après le test de LastAbortEdge
// ci-dessus, qui consomme sa valeur du scan précédent pour distinguer succès/abandon).
IF NOT ArmingInProgress THEN
    SeqReachedConfirm := FALSE;
END_IF;

// Maintien transitoire 5s UNIQUEMENT pour les causes non latched
IF AbortMsgActive AND NOT AbortMsgLatched THEN
    TonAbortHold(IN := TRUE, PT := CST_AbortHoldTime);
    IF TonAbortHold.Q THEN
        AbortMsgActive := FALSE;
        TonAbortHold(IN := FALSE);
    END_IF;
END_IF;
IF AbortMsgActive THEN
    IF LastAbortCause = INT_TO_WORD(CST_ABORT_CUT_IHM) THEN
        AbortMsgText := '[AU] Coupure volontaire IHM - relacher le bouton puis rearmer';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_CHAIN_DROP) THEN
        AbortMsgText := '[AU] Chute boucle urgence pendant test - relacher coup-de-poing puis rearmer';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_A) THEN
        AbortMsgText := '[AU] Chaine non remontee apres test A (200ms) - verifier boucle puis rearmer';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_B) THEN
        AbortMsgText := '[AU] Chaine non remontee apres test B (200ms) - verifier boucle puis rearmer';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_POWER_CUTOFF) THEN
        // 🩹 Décodage de la cause CST_ABORT_POWER_CUTOFF (PowerCutOff métier) en cause explicite
        // M1/M2/M3 + bit MecaA/MecaB/thermique, à partir des DUT Safety déjà en entrée.
        // Priorité : M3 (translation) puis M1 puis M2 ; MecaA > MecaB > thermique.
        IF TranslationSafety.ErrorMecaA THEN
            AbortMsgText := '[M3] MecaA (mouvement non commandé) - Reset puis réarmer';
        ELSIF TranslationSafety.ErrorMecaB THEN
            AbortMsgText := '[M3] MecaB (arrêt non confirmé) - Reset puis réarmer';
        ELSIF TranslationSafety.ErrorBrakeThermal THEN
            AbortMsgText := '[M3] Surchauffe frein - Reset puis réarmer';
        ELSIF WinchM1Safety.ErrorMecaA THEN
            AbortMsgText := '[M1] MecaA (mouvement non commandé) - Reset puis réarmer';
        ELSIF WinchM1Safety.ErrorMecaB THEN
            AbortMsgText := '[M1] MecaB (arrêt non confirmé) - Reset puis réarmer';
        ELSIF WinchM1Safety.ThermalFault THEN
            AbortMsgText := '[M1] Surchauffe moteur - Reset puis réarmer';
        ELSIF WinchM1Safety.ErrorBrakeThermal THEN
            AbortMsgText := '[M1] Surchauffe frein - Reset puis réarmer';
        ELSIF WinchM2Safety.ErrorMecaA THEN
            AbortMsgText := '[M2] MecaA (mouvement non commandé) - Reset puis réarmer';
        ELSIF WinchM2Safety.ErrorMecaB THEN
            AbortMsgText := '[M2] MecaB (arrêt non confirmé) - Reset puis réarmer';
        ELSIF WinchM2Safety.ThermalFault THEN
            AbortMsgText := '[M2] Surchauffe moteur - Reset puis réarmer';
        ELSIF WinchM2Safety.ErrorBrakeThermal THEN
            AbortMsgText := '[M2] Surchauffe frein - Reset puis réarmer';
        ELSE
            AbortMsgText := '[AU] Coupure securite metier active - lever la cause puis rearmer';
        END_IF;
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_REDUNDANCY_A) THEN
        AbortMsgText := '[AU] Defaut redondance canal A - verifier contacteur puis Reset';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_REDUNDANCY_B) THEN
        AbortMsgText := '[AU] Defaut redondance canal B - verifier contacteur puis Reset';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_CONTACTOR) THEN
        AbortMsgText := '[AU] Contacteur non engage sous 2s - verifier puis rearmer';
    ELSE
        AbortMsgText := '[AU] Rearmement interrompu - verifier et rearmer';
    END_IF;
END_IF;

IF NOT EmergencyChainClosed THEN
    OperatorActionCandidate := '[PUPITRE] Boucle urgence ouverte - réarmer';
ELSIF NOT LocalIoValid OR NOT Vh0800Valid OR NOT Vh0808Valid OR NOT Vh0008ErValid OR NOT Vh0008Er1Valid THEN
    OperatorActionCandidate := '[IO] Défaut module E/S - vérifier alimentation/coupleur';
ELSIF NOT CanBusValid THEN
    OperatorActionCandidate := '[CAN] Défaut bus CANopen - vérifier câblage';
ELSIF NOT Joy1Valid THEN
    OperatorActionCandidate := '[CAN] Joystick non détecté - vérifier liaison';
ELSIF NOT EcatBusValid THEN
    OperatorActionCandidate := '[ECAT] Défaut bus EtherCAT - vérifier liaison';
ELSIF NOT EncM1Valid OR NOT EncM2Valid THEN
    OperatorActionCandidate := '[ECAT] Codeurs non détectés - vérifier liaison';
ELSIF NOT VarM3Valid THEN
    OperatorActionCandidate := '[ECAT] Variateur non détecté - vérifier liaison';
ELSIF AbortMsgActive THEN
    // 🩹 Cause du dernier abandon de séquence AU (message explicite cause+action).
    // 🐛 BUG B corrigé : placé AVANT PowerCutOffActiveAny pour que la cause racine
    // (dont CST_ABORT_POWER_CUTOFF décodée en M1/M2/M3 + MecaA/MecaB/thermique) prime sur
    // le message générique de coupure puissance. Placé aussi avant
    // RedundancyTestFailed/EmergencyArmingFailed/SafeStop pour que chaque cause montre
    // son message spécifique — le message d'abandon est la CAUSE RACINE (plus pertinente
    // que le SafeStop qui en est une conséquence) — il prime sur SafeStop/DirectionBlocked.
    OperatorActionCandidate := AbortMsgText;
ELSIF PowerCutOffActiveAny THEN
    OperatorActionCandidate := '[SÉCURITÉ] Coupure puissance active - acquitter défaut treuil/pont';
ELSIF RedundancyTestFailed THEN
    OperatorActionCandidate := '[AU] Défaut redondance contacteurs - réarmer (Reset)';
ELSIF EmergencyArmingFailed THEN
    OperatorActionCandidate := '[AU] Échec réarmement contacteur - réarmer';
ELSIF NOT PowerContactorEngaged THEN
    OperatorActionCandidate := '[PUPITRE] Réarmer AU et puissance';
ELSIF SafeStopActive THEN
    OperatorActionCandidate := '[PUPITRE] Acquitter SafeStop';
ELSIF DirectionBlocked THEN
    IF CurrentDirection < 0 THEN
        OperatorActionCandidate := '[TREUIL] Descente interdite';
    ELSIF TopLimitReached THEN
        // 🛡️ Montée bloquée par butée logicielle haute (agrégat M1/M2) — cause exposée par le safety.
        OperatorActionCandidate := '[TREUIL] Montée interdite - limite haute';
    ELSIF WinchM1Safety.ErrorMecaD OR WinchM2Safety.ErrorMecaD THEN
        // 🛡️ Montée bloquée par capteur haut (non-arrêt au capteur haut, MecaD) — cause exposée par le safety.
        OperatorActionCandidate := '[TREUIL] Montée interdite - capteur haut';
    ELSIF WinchM1Safety.AscentPermit AND NOT WinchM2Safety.AscentPermit THEN
        // 🛡️ Montée bloquée par treuil M2 (M1 autorise, M2 non) — cause exposée par le safety.
        OperatorActionCandidate := '[TREUIL] Montée interdite - treuil M2';
    ELSE
        OperatorActionCandidate := '[TREUIL] Montée interdite';
    END_IF;
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    // Guidance par étape du cycle (AF-07 §5.1) — ne masque jamais un défaut
    // (priorités AU/puissance/SafeStop/DirectionBlocked ci-dessus dominent).
    CASE CycleStep OF
        E_AutoCycleStep.AX0_REPOS:
            OperatorActionCandidate := '[IHM/JOYSTICK] Démarrer le cycle (bouton Start ou homme-mort)';
        E_AutoCycleStep.AX1_INIT:
            OperatorActionCandidate := '[IHM] Vérifier conditions initiales (référencement, treuils FDC haut)';
        E_AutoCycleStep.AX2_TRANSLATE_P1:
            OperatorActionCandidate := '[JOYSTICK] Pousser vers la droite : translation vers P1';
        E_AutoCycleStep.AX3_OPEN_BUCKET:
            OperatorActionCandidate := '[IHM] Ouverture benne en cours';
        E_AutoCycleStep.AX4_DESCEND_DIVING:
            OperatorActionCandidate := '[JOYSTICK] Descendre palier 4 jusqu a l altimetrie de lancement';
        E_AutoCycleStep.AX5_KOBOLD_INIT:
            OperatorActionCandidate := '[JOYSTICK] Maintenir descente : init Kobold en cours';
        E_AutoCycleStep.AX6_SEARCH_IMMERSION:
            OperatorActionCandidate := '[JOYSTICK] Maintenir descente : entree dans l eau attendue';
        E_AutoCycleStep.AX7_SEARCH_BOTTOM:
            OperatorActionCandidate := '[JOYSTICK] Maintenir descente : detection du fond';
        E_AutoCycleStep.AX8_BOTTOM_CONFIRMED:
            OperatorActionCandidate := '[IHM] Fond touche';
        E_AutoCycleStep.AX_DIVING_RETRY:
            OperatorActionCandidate := '[JOYSTICK] Reprise plongee : remonter au FDC haut';
        E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM:
            OperatorActionCandidate := '[JOYSTICK] Retente des cables (palier 1)';
        E_AutoCycleStep.AX10_CLOSE_BUCKET:
            OperatorActionCandidate := '[IHM] Fermeture benne en cours';
        E_AutoCycleStep.AX11_CTRL_ASCENT:
            OperatorActionCandidate := '[JOYSTICK] Remontee de controle';
        E_AutoCycleStep.AX12_LOADED_ASCENT:
            OperatorActionCandidate := '[IHM] Remontee en charge';
        E_AutoCycleStep.AX13_DRAIN_PAUSE:
            OperatorActionCandidate := '[IHM] Attendre egouttage (ou bypass IHM)';
        E_AutoCycleStep.AX14_TRANSLATE_DUMP:
            OperatorActionCandidate := '[JOYSTICK] Deplacer vers tremie';
        E_AutoCycleStep.AX15A_DUMP_ARRIVE, E_AutoCycleStep.AX15B_DUMP_OPEN, E_AutoCycleStep.AX15C_DUMP_REPOSITION:
            OperatorActionCandidate := '[IHM] Vidage benne';
        E_AutoCycleStep.AX18_DONE_SYNC:
            OperatorActionCandidate := '[JOYSTICK] Cycle termine : aller en P1 pour recommencer';
        E_AutoCycleStep.AX_STAB:
            // Libellé de l'étape d'origine du défaut (CycleStepAtError).
            CASE CycleStepAtError OF
                E_AutoCycleStep.AX0_REPOS: StepAtErrorStr := 'X0 (préparation)';
                E_AutoCycleStep.AX1_INIT: StepAtErrorStr := 'X1 (référencement)';
                E_AutoCycleStep.AX2_TRANSLATE_P1: StepAtErrorStr := 'X2 (sélection position)';
                E_AutoCycleStep.AX3_OPEN_BUCKET: StepAtErrorStr := 'X3 (ouverture benne)';
                E_AutoCycleStep.AX4_DESCEND_DIVING: StepAtErrorStr := 'AX4 (plongee palier 4)';
                E_AutoCycleStep.AX5_KOBOLD_INIT: StepAtErrorStr := 'AX5 (init Kobold)';
                E_AutoCycleStep.AX6_SEARCH_IMMERSION: StepAtErrorStr := 'AX6 (recherche immersion)';
                E_AutoCycleStep.AX7_SEARCH_BOTTOM: StepAtErrorStr := 'AX7 (recherche fond)';
                E_AutoCycleStep.AX8_BOTTOM_CONFIRMED: StepAtErrorStr := 'AX8 (fond confirme)';
                E_AutoCycleStep.AX_DIVING_RETRY: StepAtErrorStr := 'AX_DIVING_RETRY (reprise plongee)';
                E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM: StepAtErrorStr := 'AX9 (retente cables)';
                E_AutoCycleStep.AX10_CLOSE_BUCKET: StepAtErrorStr := 'AX10 (fermeture benne)';
                E_AutoCycleStep.AX11_CTRL_ASCENT: StepAtErrorStr := 'AX11 (remontee controle)';
                E_AutoCycleStep.AX12_LOADED_ASCENT: StepAtErrorStr := 'AX12 (remontee chargee)';
                E_AutoCycleStep.AX13_DRAIN_PAUSE: StepAtErrorStr := 'AX13 (egouttage)';
                E_AutoCycleStep.AX14_TRANSLATE_DUMP: StepAtErrorStr := 'AX14 (translation tremie)';
                E_AutoCycleStep.AX15A_DUMP_ARRIVE: StepAtErrorStr := 'AX15a (arrivee tremie)';
                E_AutoCycleStep.AX15B_DUMP_OPEN: StepAtErrorStr := 'AX15b (vidage benne)';
                E_AutoCycleStep.AX15C_DUMP_REPOSITION: StepAtErrorStr := 'AX15c (repositionnement)';
                E_AutoCycleStep.AX18_DONE_SYNC: StepAtErrorStr := 'AX18 (cycle termine)';
                E_AutoCycleStep.AX_STAB: StepAtErrorStr := 'AX_STAB (stabilisation)';
                ELSE
                    StepAtErrorStr := '?';
            END_CASE;
            // Message compact : ID défaut (ErrorId) + étape d'origine + acquitter.
            // Le détail de la cause est consultable dans le dépannage (GVL_Troubleshooting).
            OperatorActionCandidate := CONCAT('[PUPITRE] Défaut #', CONCAT(WORD_TO_STRING(CycleErrorId), CONCAT(' (étape ', CONCAT(StepAtErrorStr, ') - acquitter'))));
        ELSE
            OperatorActionCandidate := '[IHM] Cycle en cours...';
    END_CASE;
ELSIF DiveActive AND CurrentDirection < 0 THEN
    OperatorActionCandidate := '[TREUIL] Attendre fin du Dive';
ELSIF NOT BucketIsOpen AND CurrentDirection < 0 THEN
    OperatorActionCandidate := '[BENNE] Ouvrir la benne';
ELSIF TopLimitReached AND CurrentDirection > 0 THEN
    OperatorActionCandidate := '[TREUIL] Limite haute';
ELSIF NOT BucketIsClosed AND CurrentDirection > 0 THEN
    // Sécurité : benne mal fermée (branche/caillou) → montee bridee palier 1 pour eviter un choc
    // si la benne se refermait d'un coup en montant vite.
    OperatorActionCandidate := '[BENNE] Benne non fermee - montee bridee palier 1 (securite)';
ELSIF NOT DeadmanArmed THEN
    OperatorActionCandidate := '[JOYSTICK] Appuyer homme-mort au neutre';
ELSIF CurrentMode = E_Mode.DISABLE THEN
    OperatorActionCandidate := '[IHM] Sélectionner un mode';
ELSIF JoystickAtNeutral THEN
    OperatorActionCandidate := '[JOYSTICK] Armé - actionner axe';
ELSE
    OperatorActionCandidate := '[JOYSTICK] Déplacement en cours';
END_IF;

// Interlock = mouvement demandé mais permit absent : c'est une cause
// sécurité (blocage de mouvement) → affichage IMMÉDIAT, comme un défaut.
PowerOrChainFault := (NOT EmergencyChainClosed OR NOT PowerContactorEngaged OR PowerCutOffActiveAny);
HardwareModuleOrBusFault := (NOT LocalIoValid OR NOT Vh0800Valid OR NOT Vh0808Valid OR NOT Vh0008ErValid OR NOT Vh0008Er1Valid OR NOT CanBusValid OR NOT Joy1Valid OR NOT EcatBusValid OR NOT EncM1Valid OR NOT EncM2Valid OR NOT VarM3Valid);
CriticalActionActive := (PowerOrChainFault OR HardwareModuleOrBusFault OR SafeStopActive OR DirectionBlocked);

AntiFlickOperator(NewText := OperatorActionCandidate, ForceInstant := CriticalActionActive, HoldTime := CST_BannerHoldTime);
Banner.OperatorActionText := AntiFlickOperator.Text;
{endregion}

{region "§5 Bandeau alarme"}
// ═══════════════════════════════════════════════════════════════
// 5. BANDEAU D'ALARME — carrousel des défauts actifs (index n/N)
// Format (AF-07 §6) : [ORGANE] raison_brève. Un défaut à la fois,
// rotation 1→2→…→N→1, maintien AlarmHoldTime par message.
// 🧊 Distinct des 4 champs ci-dessus (AF-07 §5.2) : ce carrousel est
//    le SEUL endroit du bandeau qui publie Error/ErrorId (alarmes).
// ═══════════════════════════════════════════════════════════════
AlarmCount := 0;

// 5.0 Collecte — Défauts matériels parents (priorité absolue carrousel)
IF NOT LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[IO] Defaut module Local IO (DI8/DO8)'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[IO] Defaut module VH0800END (DI8)'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT Vh0808Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[IO] Defaut module VH0808ETP (DI8/DO8)'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT Vh0008ErValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[IO] Defaut module VH0008ER (DO8 Relais)'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT Vh0008Er1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[IO] Defaut module VH0008ER_1 (DO8 Relais)'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT CanBusValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CAN] Defaut bus CANopen'; AlarmCount := AlarmCount + 1;
END_IF;
IF CanBusValid AND NOT Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CAN] Joystick JOY1 non detecte'; AlarmCount := AlarmCount + 1;
END_IF;
IF NOT EcatBusValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[ECAT] Defaut bus EtherCAT'; AlarmCount := AlarmCount + 1;
END_IF;
IF EcatBusValid AND NOT EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] Codeur absolu COD1 non detecte (ECAT)'; AlarmCount := AlarmCount + 1;
END_IF;
IF EcatBusValid AND NOT EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] Codeur absolu COD2 non detecte (ECAT)'; AlarmCount := AlarmCount + 1;
END_IF;
IF EcatBusValid AND NOT VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] Variateur AC600 non detecte (ECAT)'; AlarmCount := AlarmCount + 1;
END_IF;

// 5a. Collecte — treuil M1 (ST_SafetyWinch, bits ErrorId décodés)
// 🧊 Tri bloquant/warning (AF-07 §6, décision 2026-09-01) : seuls les défauts
//    BLOQUANTS (SafeStop/PowerCutOff/interlock) sont publiés. Les warnings non
//    bloquants (mou de câble, surchauffe moteur/frein, limites basse/haute) sont
//    EXCLUS du carrousel — ils restent visibles via OperatorActionText/SpecialCondition.
IF WinchM1Safety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorEncoder AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:02 - perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:05 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaA AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:08 - MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaB AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:09 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaC AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:10 - MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaD AND LocalIoValid AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:12 - MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaE AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:13 - MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorOppositeDir AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:15 - sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorNoMovement AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] ErrorID:16 - absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// 5b. Collecte — treuil M2 (mêmes bits que M1, tri bloquant/warning identique)
IF WinchM2Safety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorEncoder AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:02 - perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:05 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaA AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:08 - MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaB AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:09 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaC AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:10 - MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaD AND LocalIoValid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:12 - MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaE AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:13 - MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorOppositeDir AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:15 - sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorNoMovement AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] ErrorID:16 - absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// 5c. Collecte — translation M3 (ST_SafetyTranslation, tri bloquant/warning identique)
IF TranslationSafety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorDriveComm AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:02 - perte EtherCAT'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:03 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorMecaB AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:05 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorMecaA AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:06 - MecaA - deplacement sans commande'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorLimitSwitch AND Vh0808Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:07 - butee extreme'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorSensorIncoherent AND Vh0808Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] ErrorID:08 - capteurs incoherents'; AlarmCount := AlarmCount + 1;
END_IF;

// 5d. Collecte — benne (FB_Bucket.ErrorId, bits décodés)
//    Mapping = index cause FB_Bucket (FB_FaultCore : bit i = cause i) :
//    bit0 config géométrie · bit1 écart max · bit2 timeout · bit3 glissement M1 · bit4 codeurs non référencés
IF ((BucketErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ErrorID:01 - configuration geometrie invalide'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ErrorID:02 - depassement ecart max autorise'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0004) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ErrorID:03 - timeout commande deplacement'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ErrorID:04 - glissement treuil M1'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0010) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ErrorID:05 - codeurs treuils non references'; AlarmCount := AlarmCount + 1;
END_IF;

// 5e. Collecte — synchro M1/M2 (FB_WinchSync.ErrorId)
IF ((SyncErrorId AND 16#0001) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[SYNC] ErrorID:01 - ecart M1/M2'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((SyncErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[SYNC] ErrorID:02 - incoherence commande'; AlarmCount := AlarmCount + 1;
END_IF;
// Discordance contacteurs M1/M2 decodee (FB_SyncContactor PRG_06 §2quinquies) : quel contacteur + niveau.
IF (SyncContactorDiag.MismatchLevel >= 1) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    IF    SyncContactorDiag.RelayFwdMismatch THEN BannerSyncContactorWhich := 'relais montee';
    ELSIF SyncContactorDiag.RelayRevMismatch THEN BannerSyncContactorWhich := 'relais descente';
    ELSIF SyncContactorDiag.Step1Mismatch   THEN BannerSyncContactorWhich := 'palier 1';
    ELSIF SyncContactorDiag.Step2Mismatch   THEN BannerSyncContactorWhich := 'palier 2';
    ELSIF SyncContactorDiag.Step3Mismatch   THEN BannerSyncContactorWhich := 'palier 3';
    ELSIF SyncContactorDiag.Step4Mismatch   THEN BannerSyncContactorWhich := 'palier 4';
    ELSE  BannerSyncContactorWhich := '';
    END_IF;
    IF SyncContactorDiag.MismatchLevel >= 2 THEN
        AlarmArray[AlarmCount] := CONCAT('[SYNC] discordance M1/M2 persistante -> coupure : ', BannerSyncContactorWhich);
    ELSE
        AlarmArray[AlarmCount] := CONCAT('[SYNC] discordance contacteurs M1/M2 -> arret : ', BannerSyncContactorWhich);
    END_IF;
    AlarmCount := AlarmCount + 1;
END_IF;

// 5f. Collecte — plongée / extraction (FB_DiveSearch / FB_ExtractionAssist)
IF ((DiveErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:01 - timeout immersion'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:02 - timeout fond'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0004) <> 16#0000) AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:03 - limite basse atteinte'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:04 - contact fond perdu'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0010) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:05 - perte tension cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0020) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:06 - anomalie vitesse'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0040) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] ErrorID:07 - config invalide'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0001) <> 16#0000) AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] ErrorID:01 - fond'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] ErrorID:02 - fermeture'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0004) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] ErrorID:03 - controle'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] ErrorID:04 - config'; AlarmCount := AlarmCount + 1;
END_IF;

// 5g. Collecte — AU / armement (FB_Safety_EmergencyManagement.Diag.ErrorId)
IF ((EmergencyErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] ErrorID:01 - redondance contacteurs'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((EmergencyErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] ErrorID:02 - echec confirmation armement'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((EmergencyErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] ErrorID:04 - echec autotest demarrage'; AlarmCount := AlarmCount + 1;
END_IF;

// 5h. Collecte — cycle semi-auto (FB_CycleSemiAuto.ErrorId)
IF ((CycleErrorId AND 16#0001) <> 16#0000) AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:01 - limite legale atteinte'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0002) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:02 - defaut synchro treuils'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0008) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:04 - ecart codeurs remontee'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0010) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:05 - ecart vitesse confirme'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0020) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:06 - perte communication IHM'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0040) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:07 - timeout etape'; AlarmCount := AlarmCount + 1;
END_IF;

// 5i. Collecte [HISTO] — défauts latched passés (LatchedId AND NOT ErrorId)
// 🕘 Marqueur [HISTO] (AF-07 §6, décision 2026-09-01) : un défaut laté dont la cause a
//    disparu (bit LatchedId=1 ET bit ErrorId=0) reste affiché préfixé [HISTO] tant qu'il
//    n'est pas acquitté (Reset). M1/M2/M3 uniquement (vue latched exposée dans les DUT
//    safety). Les warnings (mou de câble, surchauffe) sont inclus ici : ce sont des défauts
//    passés à acquitter, distincts du carrousel actif (bloquants seuls).
HistoM1 := WinchM1Safety.LatchedId AND (NOT WinchM1Safety.ErrorId);
HistoM2 := WinchM2Safety.LatchedId AND (NOT WinchM2Safety.ErrorId);
HistoM3 := TranslationSafety.LatchedId AND (NOT TranslationSafety.ErrorId);

// ── M1 [HISTO] ──
IF (HistoM1 AND 16#0001) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0002) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:02 - perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0004) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:03 - surchauffe moteur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0008) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:04 - mou de cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0010) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:05 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0080) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:08 - MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0100) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:09 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0200) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:10 - MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0400) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:11 - surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#0800) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:12 - MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#1000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:13 - MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#4000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:15 - sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM1 AND 16#8000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M1] ErrorID:16 - absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// ── M2 [HISTO] ──
IF (HistoM2 AND 16#0001) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0002) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:02 - perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0004) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:03 - surchauffe moteur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0008) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:04 - mou de cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0010) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:05 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0080) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:08 - MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0100) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:09 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0200) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:10 - MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0400) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:11 - surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#0800) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:12 - MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#1000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:13 - MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#4000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:15 - sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM2 AND 16#8000) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M2] ErrorID:16 - absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// ── M3 [HISTO] ──
IF (HistoM3 AND 16#0001) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:01 - perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0002) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:02 - perte EtherCAT'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0004) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:03 - rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0008) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:04 - surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0010) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:05 - MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0020) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:06 - MecaA - deplacement sans commande'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0040) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:07 - butee extreme'; AlarmCount := AlarmCount + 1;
END_IF;
IF (HistoM3 AND 16#0080) <> 16#0000 AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[HISTO] [M3] ErrorID:08 - capteurs incoherents'; AlarmCount := AlarmCount + 1;
END_IF;

// 5j. Rotation carrousel — un message à la fois, maintien AlarmHoldTime
// Publication du tableau complet instantane dans le DUT IHM
FOR i := AlarmCount TO (CST_NbMaxAlarmes - 1) DO
    AlarmArray[i] := '';
END_FOR;
Banner.AlarmBanner.AlarmArray := AlarmArray;

IF AlarmCount = 0 THEN
    AlarmIndex := 0;
    Banner.AlarmBanner.HasAlarm := FALSE;
    Banner.AlarmBanner.Text  := '';
    Banner.AlarmBanner.Index := 0;
    Banner.AlarmBanner.Count := 0;
    TonAlarmBanner(IN := FALSE);
ELSE
    // Index reborné si le nombre de messages a diminué depuis le dernier scan.
    IF AlarmIndex >= AlarmCount THEN
        AlarmIndex := 0;
    END_IF;
    Banner.AlarmBanner.HasAlarm := TRUE;
    TonAlarmBanner(IN := TRUE, PT := AlarmHoldTime);
    IF TonAlarmBanner.Q THEN
        AlarmIndex := (AlarmIndex + 1) MOD AlarmCount;
        TonAlarmBanner(IN := FALSE);
    END_IF;
    // Index n/N prefixe directement dans le texte (ex. '1/2 [M1] perte codeur'),
    // en plus des champs Index/Count numeriques pour un usage IHM programmatique.
    Banner.AlarmBanner.Text := CONCAT(INT_TO_STRING(AlarmIndex + 1),
                                CONCAT('/',
                                CONCAT(INT_TO_STRING(AlarmCount),
                                CONCAT(' ', AlarmArray[AlarmIndex]))));
    Banner.AlarmBanner.Index := AlarmIndex + 1;
    Banner.AlarmBanner.Count := AlarmCount;
END_IF;
{endregion}

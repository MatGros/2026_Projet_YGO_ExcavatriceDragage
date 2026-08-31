(* ═══════════════════════════════════════════════════════════════
   🧠 FB_Hmi_BannerFormatter — Formateur du bandeau d'information IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.2.md §5, §6
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
    CycleStep            : E_CycleStep;   // --> [HW] Étape cycle
    CycleStateStr        : STRING(80);   // --> [HW] Libellé détaillé de l'étape cycle (FB_Cycle.CycleStateStr)
    CycleErrorId         : WORD;   // --> [DIAG] Code défaut cycle (FB_Cycle.ErrorId) — notifié à STABILIZING
    CycleStepAtError     : E_CycleStep;   // --> [DIAG] Dernière étape avant le défaut (FB_Cycle.CycleStepAtError)
    DiveState            : E_DiveSearchState;   // --> [HW] État plongée
    ExtractionState      : E_ExtractionAssistState;   // --> [HW] État extraction
    HomingActive         : BOOL;   // --> [HW] Référencement en cours
    HomingStepM1         : INT;   // --> [HW] Étape homing M1
    HomingStepM2         : INT;   // --> [HW] Étape homing M2

    // 🛡️ Dérogations & particularités
    BypassGlobalActive   : BOOL;   // --> [TST] Bypass global
    BypassWinchM1Active  : BOOL;   // --> [TST] Bypass treuil M1
    BypassWinchM2Active  : BOOL;   // --> [TST] Bypass treuil M2
    BypassTranslation    : BOOL;   // --> [TST] Bypass translation
    BypassSyncActive     : BOOL;   // --> [TST] Bypass synchro
    SyncDegradedActive   : BOOL;   // --> [TST] Synchro bridée
    LegalLimitReached    : BOOL;   // --> [SAFE] Limite légale atteinte

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

    // 🚨 Bandeau d'alarme défilant (§5) — diagnostics safety et ErrorId machine entière
    WinchM1Safety        : ST_SafetyWinch;       // --> [SAFE] Diagnostic sécurité treuil M1
    WinchM2Safety        : ST_SafetyWinch;       // --> [SAFE] Diagnostic sécurité treuil M2
    TranslationSafety    : ST_SafetyTranslation; // --> [SAFE] Diagnostic sécurité translation M3
    BucketErrorId        : WORD;   // --> [DIAG] Code défaut benne (FB_Bucket.ErrorId)
    SyncErrorId          : WORD;   // --> [DIAG] Code défaut synchro M1/M2 (FB_WinchSync.ErrorId)
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
    TonAlarmBanner       : TON; // . [LOC] §5 Tempo de maintien par message du carrousel
    AlarmArray           : ARRAY[0..49] OF STRING(120); // . [LOC] §5 Messages actifs collectés ce scan
    AlarmCount           : INT; // . [LOC] §5 Nombre de messages actifs
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
IF HomingActive THEN
    IF HomingStepM1 > 0 THEN
        Banner.SequenceProgressText := 'Homing: INDEX HAUT M1';
    ELSIF HomingStepM2 > 0 THEN
        Banner.SequenceProgressText := 'Homing: INDEX HAUT M2';
    ELSE
        Banner.SequenceProgressText := 'Homing: ATTENTE CAPTEUR HAUT';
    END_IF;
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    // Détail de l'étape (FB_Cycle.CycleStateStr) prioritaire ; label court en fallback.
    IF CycleStateStr <> '' THEN
        Banner.SequenceProgressText := CONCAT('Cycle: ', CycleStateStr);
    ELSE
        CASE CycleStep OF
            E_CycleStep.X0_PREPARATION: Banner.SequenceProgressText := 'Cycle: PRÉPARATION';
            E_CycleStep.X1_HOMING: Banner.SequenceProgressText := 'Cycle: RÉFÉRENCEMENT';
            E_CycleStep.X2_WORK_POS_SELECT: Banner.SequenceProgressText := 'Cycle: POSITION TRAVAIL';
            E_CycleStep.X3_OPEN_BUCKET: Banner.SequenceProgressText := 'Cycle: OUVERTURE BENNE';
            E_CycleStep.X4_DESCEND_OPEN:
                IF DiveState = E_DiveSearchState.SEARCHING_IMMERSION THEN
                    Banner.SequenceProgressText := 'Cycle: DESCENTE > IMMERSION';
                ELSIF DiveState = E_DiveSearchState.SEARCHING_BOTTOM THEN
                    Banner.SequenceProgressText := 'Cycle: DESCENTE > RECHERCHE FOND';
                ELSIF DiveState = E_DiveSearchState.BOTTOM_CONFIRMED THEN
                    Banner.SequenceProgressText := 'Cycle: DESCENTE > FOND CONFIRMÉ';
                ELSE
                    Banner.SequenceProgressText := 'Cycle: DESCENTE BENNE OUVERTE';
                END_IF;
            E_CycleStep.X5_BOTTOM_CONFIRMED: Banner.SequenceProgressText := 'Cycle: FOND CONFIRMÉ';
            E_CycleStep.X6_CLOSE_BUCKET: Banner.SequenceProgressText := 'Cycle: FERMETURE BENNE';
            E_CycleStep.X7_CTRL_ASCENT: Banner.SequenceProgressText := 'Cycle: ARRACHAGE / MONTÉE LENTE';
            E_CycleStep.X8_ASCENT_LOADED: Banner.SequenceProgressText := 'Cycle: REMONTÉE CHARGÉE';
            E_CycleStep.X9_DRAIN_PAUSE: Banner.SequenceProgressText := 'Cycle: ÉGOUTTAGE';
            E_CycleStep.X10_TRANSLATE_DUMP: Banner.SequenceProgressText := 'Cycle: TRANSLATION TRÉMIE';
            E_CycleStep.X11_OPEN_DUMP: Banner.SequenceProgressText := 'Cycle: VIDAGE BENNE';
            E_CycleStep.X13_DONE_SYNC: Banner.SequenceProgressText := 'Cycle: TERMINÉ';
            E_CycleStep.STABILIZING: Banner.SequenceProgressText := 'Cycle: STABILISATION';
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
IF AnyBypassActive THEN
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
// cours -> 0) = fin de sequence. Gating sur NOT PowerContactorEngaged : un SUCCES
// (step 6 -> 0 avec contacteur engage) ne produit AUCUN message (AC4) ; seul un
// ABANDON (step -> 0 sans contacteur engage) affiche la cause.
// Verrouillage : les causes SANS latch (16#0010 PowerCutOff, 16#0004/0008 timeout
// restauration) restent affichées jusqu'à Reset (ou nouvelle séquence) pour que
// l'opérateur voie l'échec. Les causes déjà latched (16#0002/0020/0040/0080) et la
// coupe volontaire (16#0001) ne sont pas verrouillées.
ArmingInProgress := (ArmingSeqStep <> 0);
LastAbortEdge(CLK := ArmingInProgress);
ResetEdge(CLK := Reset);
ArmStartEdge(CLK := ArmingInProgress);

IF LastAbortEdge.Q AND NOT PowerContactorEngaged THEN
    AbortMsgActive := TRUE;
    AbortMsgLatched := (LastAbortCause = 16#0010) OR (LastAbortCause = 16#0004) OR (LastAbortCause = 16#0008);
    TonAbortHold(IN := FALSE);
END_IF;

// Effacement : Reset OU nouvelle séquence (évite le message périmé après réarmement réussi)
IF ResetEdge.Q OR ArmStartEdge.Q THEN
    AbortMsgActive := FALSE;
    AbortMsgLatched := FALSE;
    TonAbortHold(IN := FALSE);
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
    CASE LastAbortCause OF
        16#0001: AbortMsgText := '[AU] Coupure volontaire IHM - relacher le bouton puis rearmer';
        16#0002: AbortMsgText := '[AU] Chute boucle urgence pendant test - relacher coup-de-poing puis rearmer';
        16#0004: AbortMsgText := '[AU] Chaine non remontee apres test A (200ms) - verifier boucle puis rearmer';
        16#0008: AbortMsgText := '[AU] Chaine non remontee apres test B (200ms) - verifier boucle puis rearmer';
        16#0010: AbortMsgText := '[AU] Coupure securite metier active - lever la cause puis rearmer';
        16#0020: AbortMsgText := '[AU] Defaut redondance canal A - verifier contacteur puis Reset';
        16#0040: AbortMsgText := '[AU] Defaut redondance canal B - verifier contacteur puis Reset';
        16#0080: AbortMsgText := '[AU] Contacteur non engage sous 2s - verifier puis rearmer';
    ELSE
        AbortMsgText := '[AU] Rearmement interrompu - verifier et rearmer';
    END_CASE;
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
ELSIF PowerCutOffActiveAny THEN
    OperatorActionCandidate := '[SÉCURITÉ] Coupure puissance active - acquitter défaut treuil/pont';
ELSIF AbortMsgActive AND NOT SafeStopActive AND NOT DirectionBlocked THEN
    // 🩹 Cause du dernier abandon de séquence AU (message explicite cause+action)
    // Placé avant RedundancyTestFailed/EmergencyArmingFailed pour que chaque cause
    // (dont chute chaîne, PowerCutOff, timeout contacteur, redondance) montre son message spécifique.
    // Gating NOT SafeStopActive AND NOT DirectionBlocked : le message verrouillé ne masque
    // jamais une condition de sécurité courante (SafeStop/DirectionBlocked).
    OperatorActionCandidate := AbortMsgText;
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
    ELSE
        OperatorActionCandidate := '[TREUIL] Montée interdite';
    END_IF;
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    // Guidance par étape du cycle (AF-07 §5.1) — ne masque jamais un défaut
    // (priorités AU/puissance/SafeStop/DirectionBlocked ci-dessus dominent).
    CASE CycleStep OF
        E_CycleStep.X0_PREPARATION:
            OperatorActionCandidate := '[IHM/JOYSTICK] Démarrer le cycle (bouton Start ou homme-mort)';
        E_CycleStep.X1_HOMING:
            OperatorActionCandidate := '[IHM] Attendre référencement codeurs';
        E_CycleStep.X2_WORK_POS_SELECT:
            OperatorActionCandidate := '[IHM] Sélectionner position travail';
        E_CycleStep.X3_OPEN_BUCKET:
            OperatorActionCandidate := '[IHM] Ouverture benne en cours';
        E_CycleStep.X4_DESCEND_OPEN:
            OperatorActionCandidate := '[JOYSTICK] Descendre benne ouverte > Attendre contact fond';
        E_CycleStep.X5_BOTTOM_CONFIRMED:
            OperatorActionCandidate := '[IHM] Fond confirmé - remontée';
        E_CycleStep.X6_CLOSE_BUCKET:
            OperatorActionCandidate := '[IHM] Fermeture benne en cours';
        E_CycleStep.X7_CTRL_ASCENT:
            OperatorActionCandidate := '[JOYSTICK] Remontée lente de contrôle';
        E_CycleStep.X8_ASCENT_LOADED:
            OperatorActionCandidate := '[IHM] Remontée en charge';
        E_CycleStep.X9_DRAIN_PAUSE:
            OperatorActionCandidate := '[IHM] Attendre égouttage';
        E_CycleStep.X10_TRANSLATE_DUMP:
            OperatorActionCandidate := '[JOYSTICK] Déplacer vers trémie';
        E_CycleStep.X11_OPEN_DUMP:
            OperatorActionCandidate := '[IHM] Vidage benne';
        E_CycleStep.X13_DONE_SYNC:
            OperatorActionCandidate := '[IHM] Cycle terminé';
        E_CycleStep.STABILIZING:
            // Libellé de l'étape d'origine du défaut (CycleStepAtError).
            CASE CycleStepAtError OF
                E_CycleStep.X0_PREPARATION: StepAtErrorStr := 'X0 (préparation)';
                E_CycleStep.X1_HOMING: StepAtErrorStr := 'X1 (référencement)';
                E_CycleStep.X2_WORK_POS_SELECT: StepAtErrorStr := 'X2 (sélection position)';
                E_CycleStep.X3_OPEN_BUCKET: StepAtErrorStr := 'X3 (ouverture benne)';
                E_CycleStep.X4_DESCEND_OPEN: StepAtErrorStr := 'X4 (descente)';
                E_CycleStep.X5_BOTTOM_CONFIRMED: StepAtErrorStr := 'X5 (fond confirmé)';
                E_CycleStep.X6_CLOSE_BUCKET: StepAtErrorStr := 'X6 (fermeture benne)';
                E_CycleStep.X7_CTRL_ASCENT: StepAtErrorStr := 'X7 (remontée contrôle)';
                E_CycleStep.X8_ASCENT_LOADED: StepAtErrorStr := 'X8 (remontée chargée)';
                E_CycleStep.X9_DRAIN_PAUSE: StepAtErrorStr := 'X9 (égouttage)';
                E_CycleStep.X10_TRANSLATE_DUMP: StepAtErrorStr := 'X10 (translation trémie)';
                E_CycleStep.X11_OPEN_DUMP: StepAtErrorStr := 'X11 (vidage benne)';
                E_CycleStep.X13_DONE_SYNC: StepAtErrorStr := 'X13 (cycle terminé)';
                E_CycleStep.STABILIZING: StepAtErrorStr := 'X14 (stabilisation)';
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
IF WinchM1Safety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorEncoder AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ThermalFault AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] surchauffe moteur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.SlackCable AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] mou de cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.CableLimitDescent AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] limite basse cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.CableLimitAscent AND LocalIoValid AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] butee haute'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorBrakeThermal AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaA AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaB AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaC AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaD AND LocalIoValid AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorMecaE AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorOppositeDir AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM1Safety.ErrorNoMovement AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M1] absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// 5b. Collecte — treuil M2 (mêmes bits que M1)
IF WinchM2Safety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorEncoder AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] perte codeur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ThermalFault AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] surchauffe moteur'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.SlackCable AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] mou de cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.CableLimitDescent AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] limite basse cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.CableLimitAscent AND LocalIoValid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] butee haute'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorBrakeThermal AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaA AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] MecaA - deplacement sans commande (vitesse/derive)'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaB AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaC AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] MecaC - glissement pendant benne figee'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaD AND LocalIoValid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] MecaD - non-arret au capteur haut'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorMecaE AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] MecaE - ecart synchro M1/M2 critique'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorOppositeDir AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] sens oppose'; AlarmCount := AlarmCount + 1;
END_IF;
IF WinchM2Safety.ErrorNoMovement AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M2] absence mouvement'; AlarmCount := AlarmCount + 1;
END_IF;

// 5c. Collecte — translation M3 (ST_SafetyTranslation)
IF TranslationSafety.ErrorOperatorComm AND Joy1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] perte com operateur'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorDriveComm AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] perte EtherCAT'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorPhaseRotation AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] rotation phases'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorBrakeThermal AND Vh0800Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] surchauffe frein'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorMecaB AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] MecaB - arret non confirme apres stop'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorMecaA AND VarM3Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] MecaA - deplacement sans commande'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorLimitSwitch AND Vh0808Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] butee extreme'; AlarmCount := AlarmCount + 1;
END_IF;
IF TranslationSafety.ErrorSensorIncoherent AND Vh0808Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[M3] capteurs incoherents'; AlarmCount := AlarmCount + 1;
END_IF;

// 5d. Collecte — benne (FB_Bucket.ErrorId, bits décodés)
IF ((BucketErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] timeout mouvement'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] inversion commandes'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0004) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] ecart position M1/M2'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] defaut configuration'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0010) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] capteur fond defectueux'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((BucketErrorId AND 16#0020) <> 16#0000) AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[BENNE] derive cable M2 pendant maintien'; AlarmCount := AlarmCount + 1;
END_IF;

// 5e. Collecte — synchro M1/M2 (FB_WinchSync.ErrorId)
IF ((SyncErrorId AND 16#0001) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[SYNC] ecart M1/M2'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((SyncErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[SYNC] incoherence commande'; AlarmCount := AlarmCount + 1;
END_IF;

// 5f. Collecte — plongée / extraction (FB_DiveSearch / FB_ExtractionAssist)
IF ((DiveErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] timeout immersion'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] timeout fond'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0004) <> 16#0000) AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] limite basse atteinte'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] contact fond perdu'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0010) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] perte tension cable'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0020) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] anomalie vitesse'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((DiveErrorId AND 16#0040) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[DIVE] config invalide'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0001) <> 16#0000) AND LocalIoValid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] fond'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] fermeture'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0004) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] controle'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((ExtractionErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[EXTRACTION] config'; AlarmCount := AlarmCount + 1;
END_IF;

// 5g. Collecte — AU / armement (FB_Safety_EmergencyManagement.Diag.ErrorId)
IF ((EmergencyErrorId AND 16#0001) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] redondance contacteurs'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((EmergencyErrorId AND 16#0002) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] echec confirmation armement'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((EmergencyErrorId AND 16#0008) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[AU] echec autotest demarrage'; AlarmCount := AlarmCount + 1;
END_IF;

// 5h. Collecte — cycle semi-auto (FB_Cycle.ErrorId)
IF ((CycleErrorId AND 16#0001) <> 16#0000) AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] limite legale atteinte'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0002) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] defaut synchro treuils'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0008) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ecart codeurs remontee'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0010) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ecart vitesse confirme'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0020) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] perte communication IHM'; AlarmCount := AlarmCount + 1;
END_IF;
IF ((CycleErrorId AND 16#0040) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] timeout etape'; AlarmCount := AlarmCount + 1;
END_IF;

// 5i. Rotation carrousel — un message à la fois, maintien AlarmHoldTime
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

(* ═══════════════════════════════════════════════════════════════
   🧠 FB_Hmi_BannerFormatter — Formateur du bandeau d'information IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md §4
   🎯 Responsabilité : assemble les 4 textes du bandeau et expose
      la cause observable du blocage courant, sans piloter la machine.
   🛡️ Sécurité : priorité AU/puissance, SafeStop, puis interlocks métier.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Hmi_BannerFormatter
VAR_INPUT
    Enable               : BOOL := TRUE;
    SimulationModeActive : BOOL;
    CurrentMode          : E_Mode;
    BothAxesCoupled      : BOOL;
    WinchSelected        : INT; // 1 = M1, 2 = M2

    // 🔄 Cycle & sous-cycles
    CycleStep            : E_CycleStep;
    DiveState            : E_DiveSearchState;
    ExtractionState      : E_ExtractionSequenceState;
    HomingActive         : BOOL;
    HomingStepM1         : INT;
    HomingStepM2         : INT;

    // 🛡️ Dérogations & particularités
    BypassGlobalActive   : BOOL;
    BypassWinchM1Active  : BOOL;
    BypassWinchM2Active  : BOOL;
    BypassTranslation    : BOOL;
    BypassSyncActive     : BOOL;
    SyncDegradedActive   : BOOL;
    LegalLimitReached    : BOOL;

    // 🎮 Sécurité, causes et intention de direction
    EmergencyChainClosed : BOOL;
    PowerContactorEngaged: BOOL;
    PowerCutOffActiveAny : BOOL;
    SafeStopActive       : BOOL; // Agrégat M1/M2 par AND, bandeau conservateur
    DescendPermit        : BOOL; // Agrégat M1/M2 par AND
    AscentPermit         : BOOL; // Agrégat M1/M2 par AND
    BucketIsOpen         : BOOL;
    DiveActive           : BOOL;
    TopLimitReached      : BOOL; // Agrégat M1/M2 par AND
    CoupledUserRequestDirection : INT;
    M1LogicRequestDirection     : INT;
    M2LogicRequestDirection     : INT;
    CycleRequestDirection      : INT;
    DeadmanArmed         : BOOL;
    JoystickAtNeutral    : BOOL;
    CycleAutoBusy        : BOOL;
END_VAR
VAR_OUTPUT
    Banner               : ST_HmiBanner;
END_VAR
VAR
    PrefixContext        : STRING(20);
    ModeStr              : STRING(30);
    CouplingStr          : STRING(30);
    CurrentDirection     : INT;
    DirectionBlocked     : BOOL;
    AnyBypassActive      : BOOL;
    CriticalActionActive : BOOL;
    SpecialConditionCandidate : STRING(120);
    OperatorActionCandidate   : STRING(120);
    TonSpecialCondition  : TON;
    TonOperatorAction    : TON;
END_VAR
VAR CONSTANT
    CST_BannerHoldTime   : TIME := T#500ms; // 🧊 Anti-clignotement warnings/états (AF-07 §4.3)
END_VAR

IF NOT Enable THEN
    Banner.GlobalContextText     := '';
    Banner.SequenceProgressText  := '';
    Banner.SpecialConditionText  := '';
    Banner.OperatorActionText    := '';
    RETURN;
END_IF;

// ═══════════════════════════════════════════════════════════════
// 1. CONTEXTE GLOBAL — aucun numéro d'étape ici
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

// ═══════════════════════════════════════════════════════════════
// 2. PROGRESSION — le numéro et l'étape restent exclusivement ici
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
ELSIF CurrentMode = E_Mode.MAINT_N1 OR CurrentMode = E_Mode.MAINT_N2 THEN
    Banner.SequenceProgressText := 'Manuel: PILOTAGE DIRECT';
ELSE
    Banner.SequenceProgressText := 'Machine: ARRÊTÉE';
END_IF;

// ═══════════════════════════════════════════════════════════════
// 3. CONDITION SPÉCIALE — un seul indicateur bypass/simulation
// ═══════════════════════════════════════════════════════════════
AnyBypassActive := SimulationModeActive
                OR BypassGlobalActive
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
// 🧊 Anti-clignotement (AF-07 §4.3) : maintien min avant changement
TonSpecialCondition(IN := (SpecialConditionCandidate <> Banner.SpecialConditionText), PT := CST_BannerHoldTime);
IF TonSpecialCondition.Q THEN
    Banner.SpecialConditionText := SpecialConditionCandidate;
END_IF;

// ═══════════════════════════════════════════════════════════════
// 4. ACTION — cause fixe, sécurité d'abord, sans rotation
// ═══════════════════════════════════════════════════════════════
IF CurrentMode = E_Mode.SEMI_AUTO THEN
    CurrentDirection := CycleRequestDirection;
ELSIF BothAxesCoupled THEN
    CurrentDirection := CoupledUserRequestDirection;
ELSIF WinchSelected = 1 THEN
    CurrentDirection := M1LogicRequestDirection;
ELSIF WinchSelected = 2 THEN
    CurrentDirection := M2LogicRequestDirection;
ELSE
    CurrentDirection := 0;
END_IF;

DirectionBlocked := (CurrentDirection < 0 AND NOT DescendPermit)
                OR (CurrentDirection > 0 AND NOT AscentPermit);

IF NOT EmergencyChainClosed OR NOT PowerContactorEngaged OR PowerCutOffActiveAny THEN
    OperatorActionCandidate := '[PUPITRE] Réarmer AU et puissance';
ELSIF SafeStopActive THEN
    OperatorActionCandidate := '[PUPITRE] Acquitter SafeStop';
ELSIF DirectionBlocked THEN
    IF CurrentDirection < 0 THEN
        OperatorActionCandidate := '[TREUIL] Descente interdite';
    ELSE
        OperatorActionCandidate := '[TREUIL] Montée interdite';
    END_IF;
ELSIF DiveActive AND CurrentDirection < 0 THEN
    OperatorActionCandidate := '[TREUIL] Attendre fin du Dive';
ELSIF NOT BucketIsOpen AND CurrentDirection < 0 THEN
    OperatorActionCandidate := '[BENNE] Ouvrir la benne';
ELSIF TopLimitReached AND CurrentDirection > 0 THEN
    OperatorActionCandidate := '[TREUIL] Limite haute';
ELSIF NOT DeadmanArmed THEN
    OperatorActionCandidate := '[JOYSTICK] Appuyer homme-mort au neutre';
ELSIF CurrentMode = E_Mode.DISABLE THEN
    OperatorActionCandidate := '[IHM] Sélectionner un mode';
ELSIF CurrentMode = E_Mode.SEMI_AUTO AND CycleStep = E_CycleStep.X0_PREPARATION THEN
    OperatorActionCandidate := '[IHM] Démarrer le cycle';
ELSIF JoystickAtNeutral THEN
    OperatorActionCandidate := '[JOYSTICK] Armé - actionner l''axe';
ELSE
    OperatorActionCandidate := '[JOYSTICK] Déplacement en cours';
END_IF;

// 🧊 Anti-clignotement (AF-07 §4.3) : défauts (AU/SafeStop) en direct, warnings/états maintenus
CriticalActionActive := (NOT EmergencyChainClosed OR NOT PowerContactorEngaged OR PowerCutOffActiveAny OR SafeStopActive);
IF CriticalActionActive THEN
    Banner.OperatorActionText := OperatorActionCandidate;
    TonOperatorAction(IN := FALSE);
ELSE
    TonOperatorAction(IN := (OperatorActionCandidate <> Banner.OperatorActionText), PT := CST_BannerHoldTime);
    IF TonOperatorAction.Q THEN
        Banner.OperatorActionText := OperatorActionCandidate;
    END_IF;
END_IF;

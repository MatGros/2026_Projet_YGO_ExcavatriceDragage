(* ═══════════════════════════════════════════════════════════════
   🧠 FB_Hmi_BannerFormatter — Formateur du bandeau d'information IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md §4
   🎯 Responsabilité : assemble les 4 textes du bandeau et expose
      la cause observable du blocage courant, sans piloter la machine.
   🛡️ Sécurité : priorité AU/puissance, SafeStop, puis interlocks métier.
      L'anti-clignotement est délégué à FB_AntiFlickerText (AF-07 §4.3).
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
    ExtractionState      : E_ExtractionSequenceState;   // --> [HW] État extraction
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
    DiveActive           : BOOL;   // --> [HW] Plongée active
    TopLimitReached      : BOOL; // --> [SAFE] Agrégat M1/M2 par OR — toute limite haute affichée
    CoupledUserRequestDirection : INT;   // --> [CMD] Direction demandée couplée
    M1LogicRequestDirection     : INT;   // --> [CMD] Direction logique M1
    M2LogicRequestDirection     : INT;   // --> [CMD] Direction logique M2
    CycleRequestDirection      : INT;   // --> [CMD] Direction cycle
    DeadmanArmed         : BOOL;   // --> [SAFE] Homme-mort armé
    JoystickAtNeutral    : BOOL;   // --> [HW] Joystick au neutre
    CycleAutoBusy        : BOOL;   // --> [HW] Cycle auto actif
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
    CriticalActionActive : BOOL; // . [LOC] Défaut/interlock critique : affiché immédiatement (sans maintien)
    SpecialConditionCandidate : STRING(120);   // . [LOC] Texte condition spéciale
    OperatorActionCandidate   : STRING(120);   // . [LOC] Texte action opérateur
    StepAtErrorStr            : STRING(40);   // . [LOC] Libellé de l'étape d'origine du défaut
    AntiFlickSpecial     : FB_AntiFlickerText; // * [INST] §3 Condition spéciale (warning → maintenu)
    AntiFlickOperator    : FB_AntiFlickerText; // * [INST] §4 Action opérateur (critique → direct, warning → maintenu)
END_VAR
VAR CONSTANT
    CST_BannerHoldTime   : TIME := T#500ms; // . [LOC] Anti-clignotement warnings/états (AF-07 §4.3)
END_VAR

IF NOT Enable THEN
    Banner.GlobalContextText     := '';
    Banner.SequenceProgressText  := '';
    Banner.SpecialConditionText  := '';
    Banner.OperatorActionText    := '';
    RETURN;
END_IF;

{region "§1 Contexte global"}
// ═══════════════════════════════════════════════════════════════
// 1. CONTEXTE GLOBAL — aucun numéro d'étape ici
// Format (AF-07 §4.1) : [RÉEL/SIMU] [MODE] [COUPLAGE]
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
// Format (AF-07 §4.1) : Macro: <Cycle> > Sous-cycle: <Étape>
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
// Format (AF-07 §4.1) : ATTENTION: <Dérogation / Bridage / Alerte>
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
// Format (AF-07 §4.1) : [ORGANE] <Action physique> > <Fin>
// 🧊 Défauts (AU/puissance/SafeStop) + interlock DirectionBlocked
//    → affichés immédiatement (ForceInstant=TRUE) ; les autres états
//    → maintenus min (anti-clignotement).
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
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    // Guidance par étape du cycle (AF-07 §4.1) — ne masque jamais un défaut
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
CriticalActionActive := (NOT EmergencyChainClosed OR NOT PowerContactorEngaged
                     OR PowerCutOffActiveAny OR SafeStopActive OR DirectionBlocked);

AntiFlickOperator(NewText := OperatorActionCandidate, ForceInstant := CriticalActionActive, HoldTime := CST_BannerHoldTime);
Banner.OperatorActionText := AntiFlickOperator.Text;
{endregion}

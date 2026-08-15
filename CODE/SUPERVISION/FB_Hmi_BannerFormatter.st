(* ═══════════════════════════════════════════════════════════════
   🧠 FB_Hmi_BannerFormatter — Formateur du bandeau d'information IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md §4
   🎯 Responsabilité : assemble et arbitre les 4 champs de texte
      normalisés du bandeau supérieur à partir des états typés des procédés.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Hmi_BannerFormatter
VAR_INPUT
    Enable               : BOOL := TRUE;
    SimulationModeActive : BOOL;
    CurrentMode          : E_Mode;
    BothAxesCoupled      : BOOL;
    WinchSelected        : INT; // 1 = M1, 2 = M2

    // 🔄 Cycle & Sous-cycles
    CycleStep            : E_CycleStep;
    DiveState            : E_DiveSearchState;
    ExtractionState      : E_ExtractionSequenceState;
    HomingActive         : BOOL;
    HomingStepM1         : INT;
    HomingStepM2         : INT;

    // 🛡️ Dérogations & Particularités
    BypassGlobalActive   : BOOL;
    BypassWinchM1Active  : BOOL;
    BypassWinchM2Active  : BOOL;
    BypassTranslation    : BOOL;
    BypassSyncActive     : BOOL;
    SyncDegradedActive   : BOOL;
    LegalLimitReached    : BOOL;

    // 🎮 Sécurité & Consignes
    EmergencyChainClosed : BOOL;
    PowerContactorEngaged: BOOL;
    SafeStopActiveAny    : BOOL;
    PowerCutOffActiveAny : BOOL;
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
END_VAR

IF NOT Enable THEN
    Banner.GlobalContextText    := '';
    Banner.SequenceProgressText := '';
    Banner.SpecialConditionText := '';
    Banner.OperatorActionText   := '';
    RETURN;
END_IF;

// ═══════════════════════════════════════════════════════════════
// 1. GLOBAL CONTEXT TEXT [RÉEL/SIMU] [MODE] [COUPLAGE]
// ═══════════════════════════════════════════════════════════════
IF SimulationModeActive THEN
    PrefixContext := '[SIMULATION] ';
ELSE
    PrefixContext := '[RÉEL] ';
END_IF;

CASE CurrentMode OF
    E_Mode.DISABLE:
        ModeStr := '[DÉSACTIVÉ]';
    E_Mode.MAINT_N1:
        ModeStr := '[MAINT_N1]';
    E_Mode.MAINT_N2:
        ModeStr := '[MAINT_N2]';
    E_Mode.SEMI_AUTO:
        ModeStr := '[SEMI-AUTO]';
ELSE
    ModeStr := '[MODE INCONNU]';
END_CASE;

IF CurrentMode = E_Mode.SEMI_AUTO THEN
    CouplingStr := ' [CYCLE AUTO]';
ELSIF BothAxesCoupled THEN
    CouplingStr := ' [M1+M2 COUPLÉS]';
ELSIF WinchSelected = 1 THEN
    CouplingStr := ' [M1 RETENUE SEUL]';
ELSIF WinchSelected = 2 THEN
    CouplingStr := ' [M2 BENNE SEULE]';
ELSE
    CouplingStr := ' [AUCUN AXE]';
END_IF;

Banner.GlobalContextText := CONCAT(CONCAT(PrefixContext, ModeStr), CouplingStr);

// ═══════════════════════════════════════════════════════════════
// 2. SEQUENCE PROGRESS TEXT (Micro / Progression)
// ═══════════════════════════════════════════════════════════════
IF HomingActive THEN
    IF HomingStepM1 > 0 THEN
        Banner.SequenceProgressText := 'Homing: RECHERCHE INDEX M1 EN COURS';
    ELSIF HomingStepM2 > 0 THEN
        Banner.SequenceProgressText := 'Homing: RECHERCHE INDEX M2 EN COURS';
    ELSE
        Banner.SequenceProgressText := 'Homing: ATTENTE DECLENCHEMENT CAPTEUR HAUT';
    END_IF;
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    CASE CycleStep OF
        E_CycleStep.X0_PREPARATION:
            Banner.SequenceProgressText := 'Cycle: PREPARATION (ATTENTE START)';
        E_CycleStep.X1_HOMING:
            Banner.SequenceProgressText := 'Cycle: REFERENCEMENT CODEURS';
        E_CycleStep.X2_WORK_POS_SELECT:
            Banner.SequenceProgressText := 'Cycle: SELECTION POSITION TRAVAIL';
        E_CycleStep.X3_OPEN_BUCKET:
            Banner.SequenceProgressText := 'Cycle: OUVERTURE BENNE';
        E_CycleStep.X4_DESCEND_OPEN:
            IF DiveState = E_DiveSearchState.SEARCHING_IMMERSION THEN
                Banner.SequenceProgressText := 'Cycle: DESCENTE > Kobold: 02_RECHERCHE_IMMERSION';
            ELSIF DiveState = E_DiveSearchState.SEARCHING_BOTTOM THEN
                Banner.SequenceProgressText := 'Cycle: DESCENTE > Kobold: 03_PLONGEE_RECHERCHE_FOND';
            ELSIF DiveState = E_DiveSearchState.BOTTOM_CONFIRMED THEN
                Banner.SequenceProgressText := 'Cycle: DESCENTE > Kobold: 04_FOND_TOUCHE_CONFIRME';
            ELSE
                Banner.SequenceProgressText := 'Cycle: 01_DESCENTE_BENNE_OUVERTE';
            END_IF;
        E_CycleStep.X5_BOTTOM_CONFIRMED:
            Banner.SequenceProgressText := 'Cycle: 02_ATTENTE_FOND_TOUCHE';
        E_CycleStep.X6_CLOSE_BUCKET:
            Banner.SequenceProgressText := 'Cycle: 03_FERMETURE_BENNE_AU_FOND';
        E_CycleStep.X7_CTRL_ASCENT:
            Banner.SequenceProgressText := 'Cycle: 04_ARRACHAGE_ET_REMONTEE_LENTE_PALIER_1';
        E_CycleStep.X8_ASCENT_LOADED:
            Banner.SequenceProgressText := 'Cycle: 05_REMONTEE_NOMINALE_CHARGE';
        E_CycleStep.X9_DRAIN_PAUSE:
            Banner.SequenceProgressText := 'Cycle: 06_EGOUTTAGE_TEMPORISE';
        E_CycleStep.X10_TRANSLATE_DUMP:
            Banner.SequenceProgressText := 'Cycle: 07_DEPLACEMENT_TRANSLATION_VERS_TREMIE';
        E_CycleStep.X11_OPEN_DUMP:
            Banner.SequenceProgressText := 'Cycle: 08_DESCENTE_ET_OUVERTURE_BENNE_TREMIE';
        E_CycleStep.X13_DONE_SYNC:
            Banner.SequenceProgressText := 'Cycle: 10_CYCLE_TERMINE_PRET';
        E_CycleStep.STABILIZING:
            Banner.SequenceProgressText := 'Cycle: EN ATTENTE / STABILISATION';
    ELSE
        Banner.SequenceProgressText := 'Cycle: ETAPE EN COURS';
    END_CASE;
ELSE
    IF CurrentMode = E_Mode.MAINT_N1 OR CurrentMode = E_Mode.MAINT_N2 THEN
        Banner.SequenceProgressText := 'Manuel: PILOTAGE DIRECT JOYSTICK / PUPITRE';
    ELSE
        Banner.SequenceProgressText := 'Machine: ARRETEE / NEUTRALISEE';
    END_IF;
END_IF;

// ═══════════════════════════════════════════════════════════════
// 3. SPECIAL CONDITION TEXT (Dérogations & Avertissements)
// ═══════════════════════════════════════════════════════════════
IF BypassGlobalActive THEN
    Banner.SpecialConditionText := '[DEROGATION] : Bypass global securite actif';
ELSIF BypassWinchM1Active OR BypassWinchM2Active THEN
    Banner.SpecialConditionText := '[DEROGATION] : Bypass treuil actif (surveillance inhibee)';
ELSIF BypassTranslation THEN
    Banner.SpecialConditionText := '[DEROGATION] : Bypass translation actif';
ELSIF SyncDegradedActive THEN
    Banner.SpecialConditionText := '[BRIDAGE] : Vitesse limitee Palier 1 (Ecart synchro M1/M2)';
ELSIF LegalLimitReached THEN
    Banner.SpecialConditionText := '[LIMITE] : Profondeur legale de dragage atteinte';
ELSE
    Banner.SpecialConditionText := 'Nominal : Aucune derogation active';
END_IF;

// ═══════════════════════════════════════════════════════════════
// 4. OPERATOR ACTION TEXT (Consigne d'action requise)
// ═══════════════════════════════════════════════════════════════
IF NOT EmergencyChainClosed OR NOT PowerContactorEngaged OR PowerCutOffActiveAny THEN
    Banner.OperatorActionText := '[PUPITRE] Réarmer la chaîne AU physique et enclencher la puissance';
ELSIF SafeStopActiveAny THEN
    Banner.OperatorActionText := '[PUPITRE] Acquitter le défaut (Reset) et ramener le joystick au neutre';
ELSIF CurrentMode = E_Mode.DISABLE THEN
    Banner.OperatorActionText := '[IHM] Sélectionner un mode de marche actif (MAINT_N1, MAINT_N2 ou AUTO)';
ELSIF NOT DeadmanArmed THEN
    Banner.OperatorActionText := '[JOYSTICK] Maintenir la gâchette homme-mort au neutre pour armer';
ELSIF CurrentMode = E_Mode.SEMI_AUTO THEN
    IF CycleStep = E_CycleStep.X0_PREPARATION THEN
        Banner.OperatorActionText := '[IHM] Appuyer sur Start Cycle pour lancer la séquence';
    ELSIF CycleStep = E_CycleStep.STABILIZING THEN
        Banner.OperatorActionText := '[JOYSTICK] Réarmer homme-mort puis réengager déflexion pour reprise';
    ELSE
        Banner.OperatorActionText := '[JOYSTICK] Maintenir déflexion active pour déroulement du cycle';
    END_IF;
ELSIF CurrentMode = E_Mode.MAINT_N1 OR CurrentMode = E_Mode.MAINT_N2 THEN
    Banner.OperatorActionText := '[JOYSTICK] Actionner l axe souhaité avec homme-mort maintenu';
ELSE
    Banner.OperatorActionText := '[AUCUNE ACTION ATTENDUE]';
END_IF;

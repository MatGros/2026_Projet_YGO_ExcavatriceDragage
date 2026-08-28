(* =======================================================================
   ⚙️ FB_DiveSearch — Assistance plongée et recherche du fond Kobold
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Qualification du capteur Kobold et autorisation de descente
   🛡️ Sécurité : Verrouillage si séquence d'immersion 0->1->0 invalide
   🔌 Interface : Intention de descente et mesures vers permis de descente
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)
FUNCTION_BLOCK FB_DiveSearch
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                  : BOOL;         // --> [CMD] Activation generale du FB (TRUE=Autorise)
    Reset                   : BOOL;         // --> [CMD] Acquittement defaut (front)
    PowerContactorEngaged   : BOOL;         // --> [SAFE] Chaine de securite OK
    Mode                    : E_Mode;       // --> [CMD] Mode de fonctionnement arbitre
    MotionRequestActive     : BOOL;         // --> [CMD] Intention de mouvement active
    MotionDirection         : INT;          // --> [CMD] Sens de mouvement (-1 = descente)

    // === CAPTEURS & ETATS BENNE ===
    BucketIsOpen            : BOOL;         // --> [HW] Benne ouverte confirmee
    KoboldImmersed          : BOOL;         // --> [HW] Capteur Kobold immerge (FALSE=hors eau, TRUE=immerge)
    M1Position_M            : REAL;         // --> [HW] Position codeur treuil M1 (m)
    M2Position_M            : REAL;         // --> [HW] Position codeur treuil M2 (m)
    PositionsValid          : BOOL;         // --> [HW] Validite des mesures de position
    CurrentSpeedStep        : INT;          // --> [HW] Palier de vitesse actuel (1..5)

    // === CONFIGURATION & SEUILS ===
    DiveStartMin_M          : REAL;         // --> [CFG] Seuil position min pour debut plongee (m)
    ImmersionUpper_M        : REAL;         // --> [CFG] Borne haute fenetre d'immersion (m)
    ImmersionLower_M        : REAL;         // --> [CFG] Borne basse fenetre d'immersion (m)
    CableLimitAscent_M      : REAL := 7.5;  // --> [CFG] Limite haute d'exploitation (m), plafond de course immersion
    LimitLegalDepthMin_M    : REAL := -35.0;// --> [CFG] Limite legale basse autorisee (m)
    CycleTime               : TIME := T#10ms;// --> [CFG] Base de temps d'integration (periode MainTask)
    BypassPreconditions     : BOOL := FALSE;// --> [TST] Bypass preconditions et seuils (mode test)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                   : BOOL;         // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault + ST_Lifecycle)
    Fault                   : ST_Fault;
    Lifecycle               : ST_Lifecycle;
    DiveState               : E_DiveSearchState; // <-- [STAT] Phase interne de recherche fond
    StepAtFault             : E_DiveSearchState; // <-- [DIAG] Etape active mémorisée lors du défaut

    // === PERMIS & AUTORISATIONS ===
    DescendPermit           : BOOL;         // <-- [ACT] Autorisation de descente assistee
    KoboldMeasureEnable     : BOOL;         // <-- [ACT] Activation mesure/acquisition Kobold
    KoboldContactorCmd      : BOOL;         // <-- [ACT] Commande alimentation contacteur Kobold (anti-chauffe)
    BottomTouchConfirmed    : BOOL;         // <-- [STAT] Contact fond valide et confirme

    // === DIAGNOSTIC IHM ===
    OperatorActionId        : WORD;         // <-- [DIAG] ID action operateur requise
    OperatorAction          : STRING(120);  // <-- [DIAG] Message explicatif operateur
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge               : R_TRIG;       // . [LOC] Detecteur front montant Reset
    ErrorEdge               : R_TRIG;       // . [LOC] Detecteur front montant apparition defaut
    KoboldRiseEdge          : R_TRIG;       // . [LOC] Detecteur front entrant eau (0->1)
    KoboldFallEdge          : F_TRIG;       // . [LOC] Detecteur front sortie eau / fond (1->0)

    // === CALCUL DYNAMIQUE RUNTIME DES TIMEOUTS ===
    ImmersionCourse_M          : REAL;      // . [LOC] Course credible max recherche immersion (m)
    BottomCourse_M             : REAL;      // . [LOC] Course credible max recherche fond (m)
    CalculatedImmersionTimeout : TIME;      // . [LOC] Plafond anti-blocage immersion calcule au runtime
    CalculatedBottomTimeout    : TIME;      // . [LOC] Plafond anti-blocage fond calcule au runtime

    // === ACCUMULATEURS DE TEMPS ANTI-POMPAGE ===
    ImmersionTimerAcc       : TIME := T#0ms;// . [LOC] Temps cumule recherche immersion sous mouvement
    BottomTimerAcc          : TIME := T#0ms;// . [LOC] Temps cumule recherche fond sous mouvement
    PrevState               : E_DiveSearchState; // . [LOC] Etape au scan precedent (maintien survivant au gate)

    // === VARIABLES LOCALES INTERNES ===
    ImmersionConfirmed      : BOOL;         // . [LOC] Immersion dans la fenetre d'eau validee
    ErrorCausePresent       : BOOL;         // . [LOC] Presence d'une cause de defaut parametrage
    SeqErrorFault           : BOOL;         // . [LOC] Latch erreur séquence immersion
    Palier5ForbiddenFault   : BOOL;         // . [LOC] Latch tentative descente en Palier 5 sous Kobold
    TimeoutImmersionFault   : BOOL;         // . [LOC] Latch timeout recherche immersion
    TimeoutBottomFault      : BOOL;         // . [LOC] Latch timeout recherche fond

    // === SOCLE DEFAUT ===
    instFault               : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées
END_VAR
VAR CONSTANT
    // === CONSTANTES DERIVATION TIMEOUT ANTI-BLOCAGE ===
    CST_DiveSpeedMin_Mps    : REAL := 0.15;   // Vitesse Palier 1 mini sous charge/mou (m/s)
    CST_TimeoutMarginFactor : REAL := 1.5;    // Facteur de marge de securite sur la course theorique
    CST_TimeoutMinCourse_M  : REAL := 1.0;    // Plancher de course pour le calcul (evite timeout degenere)
    CST_SecToMs             : REAL := 1000.0; // Conversion secondes -> millisecondes
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS
ResetEdge(CLK := Reset);
KoboldRiseEdge(CLK := KoboldImmersed);
KoboldFallEdge(CLK := KoboldImmersed);

ErrorCausePresent := NOT BypassPreconditions AND ((DiveStartMin_M < ImmersionUpper_M)
                  OR (ImmersionUpper_M <= ImmersionLower_M)
                  OR (ImmersionLower_M <= LimitLegalDepthMin_M)
                  OR (CableLimitAscent_M <= ImmersionLower_M));

// ⏱️ Plafonds anti-blocage calcules au runtime : course credible max / vitesse Palier 1 mini x marge.
// Course immersion = du plafond haut d'exploitation a la borne basse d'immersion (depart de plongee
// possible n'importe ou entre DiveStartMin_M et CableLimitAscent_M -> on prend la borne la plus large).
ImmersionCourse_M   := MAX(CST_TimeoutMinCourse_M, CableLimitAscent_M - ImmersionLower_M);
BottomCourse_M      := MAX(CST_TimeoutMinCourse_M, ImmersionLower_M - LimitLegalDepthMin_M);
CalculatedImmersionTimeout := UDINT_TO_TIME(REAL_TO_UDINT(
    ImmersionCourse_M / CST_DiveSpeedMin_Mps * CST_TimeoutMarginFactor * CST_SecToMs));
CalculatedBottomTimeout    := UDINT_TO_TIME(REAL_TO_UDINT(
    BottomCourse_M / CST_DiveSpeedMin_Mps * CST_TimeoutMarginFactor * CST_SecToMs));

// ⏱️ Intégrateurs de temps de mouvement effectif (D1 anti-pompage)
IF (DiveState = E_DiveSearchState.SEARCHING_IMMERSION) AND MotionRequestActive AND (MotionDirection = -1) THEN
    ImmersionTimerAcc := ImmersionTimerAcc + CycleTime;
    IF ImmersionTimerAcc >= CalculatedImmersionTimeout THEN
        TimeoutImmersionFault := TRUE;
    END_IF;
END_IF;

IF (DiveState = E_DiveSearchState.SEARCHING_BOTTOM) AND MotionRequestActive AND (MotionDirection = -1) THEN
    BottomTimerAcc := BottomTimerAcc + CycleTime;
    IF BottomTimerAcc >= CalculatedBottomTimeout THEN
        TimeoutBottomFault := TRUE;
    END_IF;
END_IF;

IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT KoboldImmersed AND NOT MotionRequestActive THEN
    SeqErrorFault         := FALSE;
    Palier5ForbiddenFault := FALSE;
    TimeoutImmersionFault := FALSE;
    TimeoutBottomFault    := FALSE;
    ImmersionTimerAcc     := T#0ms;
    BottomTimerAcc        := T#0ms;
    ImmersionConfirmed    := FALSE;
    BottomTouchConfirmed  := FALSE;
    DiveState             := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;

instCauses[0].Active   := SeqErrorFault;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Incoherence sequence immersion Kobold';

instCauses[2].Active   := ErrorCausePresent;
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Parametrage invalide des seuils de plongee';

instCauses[3].Active   := Palier5ForbiddenFault;
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Mesure Kobold impossible : vitesse trop elevee (Palier 5 interdit)';

instCauses[4].Active   := TimeoutImmersionFault;
instCauses[4].Latching := TRUE;
instCauses[4].Texte    := 'Depassement tempo recherche immersion Kobold';

instCauses[5].Active   := TimeoutBottomFault;
instCauses[5].Latching := TRUE;
instCauses[5].Texte    := 'Depassement tempo recherche fond Kobold';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

// 📸 Capture ordonnée de StepAtFault sur front montant de défaut (D2)
ErrorEdge(CLK := Fault.Error);
IF ErrorEdge.Q THEN
    StepAtFault := PrevState;
ELSIF ResetEdge.Q THEN
    StepAtFault := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    DescendPermit := FALSE;
    KoboldMeasureEnable := FALSE;
    KoboldContactorCmd := FALSE;
    BottomTouchConfirmed := FALSE;
    DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
    StepAtFault := E_DiveSearchState.WAIT_PRECONDITIONS;
    OperatorActionId := 0;
    OperatorAction := '';
    ImmersionConfirmed := FALSE;
    ImmersionTimerAcc := T#0ms;
    BottomTimerAcc := T#0ms;
    PrevState := E_DiveSearchState.WAIT_PRECONDITIONS;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Machine etat plongee recherche fond"}
DescendPermit := FALSE;
KoboldMeasureEnable := FALSE;
KoboldContactorCmd := FALSE;
Lifecycle.Busy := FALSE;
Lifecycle.Done := FALSE;

IF Fault.Error THEN
    DiveState := E_DiveSearchState.ERROR_HOLD;
    KoboldContactorCmd := FALSE;
    OperatorActionId := 16#0180;
    OperatorAction := 'Vérifier les conditions puis réarmer avant une nouvelle plongée.';
ELSE
    CASE DiveState OF
        E_DiveSearchState.WAIT_PRECONDITIONS:
            KoboldContactorCmd := FALSE;
            IF NOT BypassPreconditions
               AND (NOT BucketIsOpen OR NOT PositionsValid OR KoboldImmersed
                    OR (M1Position_M < DiveStartMin_M) OR (M2Position_M < DiveStartMin_M)) THEN
                OperatorActionId := 16#0100;
                OperatorAction := 'Vérifier les conditions initiales de plongée.';
            ELSE
                DiveState := E_DiveSearchState.READY_TO_DESCEND;
            END_IF;

        E_DiveSearchState.READY_TO_DESCEND:
            Ready := TRUE;
            KoboldContactorCmd := FALSE;
            OperatorActionId := 16#0101;
            OperatorAction := 'Demander une descente pour rechercher le fond.';
            IF MotionRequestActive AND (MotionDirection = -1) THEN
                ImmersionTimerAcc := T#0ms; // ⏱️ RAZ à l'entrée exacte de SEARCHING_IMMERSION
                DiveState := E_DiveSearchState.SEARCHING_IMMERSION;
            END_IF;

        E_DiveSearchState.SEARCHING_IMMERSION:
            Lifecycle.Busy := TRUE;
            DescendPermit := MotionRequestActive AND (MotionDirection = -1);
            KoboldMeasureEnable := TRUE;
            KoboldContactorCmd := TRUE; // Alimentation contacteur Kobold activée à la volée
            OperatorActionId := 16#0102;
            OperatorAction := 'Maintenir la descente : recherche immersion Kobold.';

            // 🛑 Interdiction du Palier 5 pendant la détection Kobold
            IF CurrentSpeedStep > 4 THEN
                Palier5ForbiddenFault := TRUE;
            END_IF;

            IF KoboldRiseEdge.Q THEN
                IF (M1Position_M <= ImmersionUpper_M) AND (M1Position_M >= ImmersionLower_M)
                   AND (M2Position_M <= ImmersionUpper_M) AND (M2Position_M >= ImmersionLower_M) THEN
                    ImmersionConfirmed := TRUE;
                    BottomTimerAcc := T#0ms; // ⏱️ RAZ à l'entrée exacte de SEARCHING_BOTTOM
                    DiveState := E_DiveSearchState.SEARCHING_BOTTOM;
                ELSE
                    SeqErrorFault := TRUE;
                END_IF;
            ELSIF (M1Position_M < ImmersionLower_M) OR (M2Position_M < ImmersionLower_M) THEN
                SeqErrorFault := TRUE;
            END_IF;

        E_DiveSearchState.SEARCHING_BOTTOM:
            Lifecycle.Busy := TRUE;
            DescendPermit := MotionRequestActive AND (MotionDirection = -1);
            KoboldMeasureEnable := TRUE;
            KoboldContactorCmd := TRUE; // Alimentation maintenue pendant la descente
            OperatorActionId := 16#0103;
            OperatorAction := 'Maintenir la descente : immersion validée, recherche du fond.';

            // 🛑 Interdiction du Palier 5 pendant la détection Kobold
            IF CurrentSpeedStep > 4 THEN
                Palier5ForbiddenFault := TRUE;
            END_IF;

            IF KoboldFallEdge.Q AND ImmersionConfirmed THEN
                BottomTouchConfirmed := TRUE;
                ImmersionConfirmed := FALSE;
                KoboldContactorCmd := FALSE; // Coupure immédiate à la détection pour éviter surchauffe
                DiveState := E_DiveSearchState.BOTTOM_CONFIRMED;
            END_IF;

        E_DiveSearchState.BOTTOM_CONFIRMED:
            Lifecycle.Done := TRUE;
            KoboldContactorCmd := FALSE; // Coupure anti-chauffe
            OperatorActionId := 16#0104;
            OperatorAction := 'Fond détecté : demander la fermeture ou l extraction.';

        E_DiveSearchState.ERROR_HOLD:
            KoboldContactorCmd := FALSE;
    END_CASE;
END_IF;

// 💾 Mémorisation de l'étape précédente en toute fin de scan
PrevState := DiveState;
{endregion}

END_FUNCTION_BLOCK

(* ═══════════════════════════════════════════════════════════════
   🌊 FB_DiveSearch — Assistance plongée et recherche du fond Kobold
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md §3ter
   🛡️ Sécurité : T81/T82. Jamais de descente assistée sans séquence 0→1→0 valide.
   🧩 Responsabilité : qualifie le Kobold et autorise uniquement la descente cohérente.
   🔌 Interface : intention de descente + mesures → autorisation + fond validé.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_DiveSearch
VAR_INPUT
    Enable                 : BOOL;
    Reset                  : BOOL;
    PowerContactorEngaged        : BOOL;
    Mode                   : E_Mode;
    MotionRequestActive    : BOOL; (* Intention déjà arbitrée en amont *)
    MotionDirection        : INT;  (* -1 = descente *)
    BucketIsOpen           : BOOL;
    KoboldImmersed         : BOOL; (* FALSE hors eau/fond ; TRUE immergé *)
    M1Position_M           : REAL;
    M2Position_M           : REAL;
    PositionsValid         : BOOL;
    DiveStartMin_M         : REAL;
    ImmersionUpper_M       : REAL;
    ImmersionLower_M       : REAL;
    // 🆕 2026-08-07 (14) — retour terrain, demande explicite : réglages DiveStartMin_M/
    // ImmersionUpper_M/ImmersionLower_M pas encore calibrés sur site, bloquaient WAIT_PRECONDITIONS
    // (bit2 config) sans aucun moyen de progresser dans la séquence pendant les essais. Si TRUE,
    // saute entièrement ErrorCausePresent (bit2) ET le test WAIT_PRECONDITIONS -- transition directe
    // vers READY_TO_DESCEND. Défaut FALSE : comportement standard inchangé.
    BypassPreconditions    : BOOL := FALSE;
END_VAR
VAR_OUTPUT
    Ready                  : BOOL;
    Busy                   : BOOL;
    Done                   : BOOL;
    Error                  : BOOL;
    ErrorId                : WORD; (* bit0: préconditions, bit1: séquence Kobold invalide, bit2: configuration seuils invalide *)
    State                  : E_State;
    StateAtError           : E_State;
    DiveState              : E_DiveSearchState;
    DescendPermit          : BOOL; (* Autorise uniquement la demande de descente active *)
    KoboldMeasureEnable    : BOOL;
    BottomTouchConfirmed   : BOOL;
    OperatorActionId       : WORD;
    OperatorAction         : STRING(120);
END_VAR
VAR
    ResetEdge              : R_TRIG;
    KoboldRiseEdge         : R_TRIG;
    KoboldFallEdge         : F_TRIG;
    ImmersionConfirmed     : BOOL;
    ErrorCausePresent      : BOOL;
END_VAR

IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    DescendPermit := FALSE; KoboldMeasureEnable := FALSE;
    BottomTouchConfirmed := FALSE;
    State := E_State.DISABLED;
    StateAtError := E_State.DISABLED;
    DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
    OperatorActionId := 0; OperatorAction := '';
    ImmersionConfirmed := FALSE;
    RETURN;
END_IF;

ResetEdge(CLK := Reset);
KoboldRiseEdge(CLK := KoboldImmersed);
KoboldFallEdge(CLK := KoboldImmersed);

ErrorCausePresent := NOT BypassPreconditions AND ((DiveStartMin_M < ImmersionUpper_M)
                  OR (ImmersionUpper_M <= ImmersionLower_M));
IF ErrorCausePresent THEN
    ErrorId := ErrorId OR 16#0004;
END_IF;

(* Reset = front + causes disparues ; aucun redémarrage automatique. *)
IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT KoboldImmersed AND NOT MotionRequestActive THEN
    ErrorId := 16#0000;
    ImmersionConfirmed := FALSE;
    BottomTouchConfirmed := FALSE;
    StateAtError := E_State.DISABLED;
    DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;

DescendPermit := FALSE; KoboldMeasureEnable := FALSE;
Ready := FALSE; Busy := FALSE; Done := FALSE;
OperatorActionId := 0; OperatorAction := '';

IF ErrorId <> 16#0000 THEN
    State := E_State.READY;
    DiveState := E_DiveSearchState.ERROR_HOLD;
    OperatorActionId := 16#0180;
    OperatorAction := 'Vérifier les conditions puis réarmer avant une nouvelle plongée.';
ELSE
    CASE DiveState OF
        E_DiveSearchState.WAIT_PRECONDITIONS:
            State := E_State.INIT;
            IF NOT BypassPreconditions
               AND (NOT BucketIsOpen OR NOT PositionsValid OR KoboldImmersed
                    OR (M1Position_M < DiveStartMin_M) OR (M2Position_M < DiveStartMin_M)) THEN
                OperatorActionId := 16#0100;
                OperatorAction := 'Vérifier les conditions initiales de plongée.';
            ELSE
                DiveState := E_DiveSearchState.READY_TO_DESCEND;
            END_IF;

        E_DiveSearchState.READY_TO_DESCEND:
            State := E_State.READY;
            Ready := TRUE;
            OperatorActionId := 16#0101;
            OperatorAction := 'Demander une descente pour rechercher le fond.';
            IF MotionRequestActive AND (MotionDirection = -1) THEN
                DiveState := E_DiveSearchState.SEARCHING_IMMERSION;
            END_IF;

        E_DiveSearchState.SEARCHING_IMMERSION:
            State := E_State.BUSY;
            Busy := TRUE;
            DescendPermit := MotionRequestActive AND (MotionDirection = -1);
            KoboldMeasureEnable := TRUE;
            OperatorActionId := 16#0102;
            OperatorAction := 'Maintenir la descente : recherche immersion Kobold.';
            IF KoboldRiseEdge.Q THEN
                IF (M1Position_M <= ImmersionUpper_M) AND (M1Position_M >= ImmersionLower_M)
                   AND (M2Position_M <= ImmersionUpper_M) AND (M2Position_M >= ImmersionLower_M) THEN
                    ImmersionConfirmed := TRUE;
                    DiveState := E_DiveSearchState.SEARCHING_BOTTOM;
                ELSE
                    ErrorId := ErrorId OR 16#0002;
                    StateAtError := State;
                END_IF;
            ELSIF (M1Position_M < ImmersionLower_M) OR (M2Position_M < ImmersionLower_M) THEN
                ErrorId := ErrorId OR 16#0002;
                StateAtError := State;
            END_IF;

        E_DiveSearchState.SEARCHING_BOTTOM:
            State := E_State.BUSY;
            Busy := TRUE;
            DescendPermit := MotionRequestActive AND (MotionDirection = -1);
            KoboldMeasureEnable := TRUE;
            OperatorActionId := 16#0103;
            OperatorAction := 'Maintenir la descente : immersion validée, recherche du fond.';
            IF KoboldFallEdge.Q AND ImmersionConfirmed THEN
                BottomTouchConfirmed := TRUE;
                ImmersionConfirmed := FALSE;
                DiveState := E_DiveSearchState.BOTTOM_CONFIRMED;
            END_IF;

        E_DiveSearchState.BOTTOM_CONFIRMED:
            State := E_State.DONE;
            Done := TRUE;
            OperatorActionId := 16#0104;
            OperatorAction := 'Fond détecté : demander la fermeture ou l extraction.';

        E_DiveSearchState.ERROR_HOLD:
            State := E_State.READY;
    END_CASE;
END_IF;

Error := (ErrorId <> 16#0000);

(* ═══════════════════════════════════════════════════════════════
   ⛏️ FB_ExtractionSequence — Fermeture benne et remontée assistée
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md §3ter
   🛡️ Sécurité : aucune remontée assistée sans fond confirmé ; palier 1 au contrôle.
   🧩 Responsabilité : séquence métier, jamais commande directe de contacteur.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_ExtractionSequence
VAR_INPUT
    Enable                     : BOOL;
    Reset                      : BOOL;
    PowerContactorEngaged            : BOOL;
    Mode                       : E_Mode;
    MotionRequestActive        : BOOL;
    MotionDirection            : INT; (* +1 = montée *)
    BottomPositionConfirmed    : BOOL;
    BucketIsClosed             : BOOL;
    BucketBusy                 : BOOL;
    BucketError                : BOOL;
    WinchSyncError             : BOOL;
    M1Position_M               : REAL;
    M2Position_M               : REAL;
    M1MeasuredSpeedValid       : BOOL;
    M2MeasuredSpeedValid       : BOOL;
    PositionsValid             : BOOL;
    ControlAscentDistance_M    : REAL;
END_VAR
VAR_OUTPUT
    Ready                      : BOOL;
    Busy                       : BOOL;
    Done                       : BOOL;
    Error                      : BOOL;
    ErrorId                    : WORD; (* bit0: fond absent, bit1: fermeture, bit2: contrôle remontée, bit3: configuration *)
    State                      : E_State;
    StateAtError               : E_State;
    ExtractionState            : E_ExtractionSequenceState;
    BucketCloseRequest         : BOOL;
    AscentPermit               : BOOL;
    ForceMinSpeedStep          : BOOL;
    BottomConfirmationConsumed : BOOL;
    OperatorActionId           : WORD;
    OperatorAction             : STRING(120);
END_VAR
VAR
    ResetEdge                  : R_TRIG;
    ControlStartM1Position_M   : REAL;
    ControlStartM2Position_M   : REAL;
    ErrorCausePresent          : BOOL;
END_VAR

IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    BucketCloseRequest := FALSE; AscentPermit := FALSE; ForceMinSpeedStep := FALSE;
    BottomConfirmationConsumed := FALSE;
    State := E_State.DISABLED;
    StateAtError := E_State.DISABLED;
    ExtractionState := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;
    OperatorActionId := 0; OperatorAction := '';
    RETURN;
END_IF;

ResetEdge(CLK := Reset);
ErrorCausePresent := (ControlAscentDistance_M <= 0.0);
IF ErrorCausePresent THEN
    ErrorId := ErrorId OR 16#0008;
END_IF;
IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT MotionRequestActive THEN
    ErrorId := 16#0000;
    StateAtError := E_State.DISABLED;
    ExtractionState := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;
END_IF;

Ready := FALSE; Busy := FALSE; Done := FALSE;
BucketCloseRequest := FALSE; AscentPermit := FALSE; ForceMinSpeedStep := FALSE;
BottomConfirmationConsumed := FALSE;
OperatorActionId := 0; OperatorAction := '';

IF ErrorId <> 16#0000 THEN
    State := E_State.READY;
    ExtractionState := E_ExtractionSequenceState.ERROR_HOLD;
    OperatorActionId := 16#0280;
    OperatorAction := 'Vérifier la benne et les treuils puis réarmer avant de reprendre.';
ELSE
    CASE ExtractionState OF
        E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION:
            State := E_State.INIT;
            IF BottomPositionConfirmed THEN
                ExtractionState := E_ExtractionSequenceState.READY_TO_CLOSE;
            ELSE
                OperatorActionId := 16#0200;
                OperatorAction := 'Confirmer que la benne est posée au fond avant extraction.';
            END_IF;

        E_ExtractionSequenceState.READY_TO_CLOSE:
            State := E_State.READY;
            Ready := TRUE;
            OperatorActionId := 16#0201;
            OperatorAction := 'Demander la montée pour fermer la benne.';
            IF MotionRequestActive AND (MotionDirection = 1) THEN
                BottomConfirmationConsumed := TRUE;
                ExtractionState := E_ExtractionSequenceState.CLOSING_BUCKET;
            END_IF;

        E_ExtractionSequenceState.CLOSING_BUCKET:
            State := E_State.BUSY;
            Busy := TRUE;
            BucketCloseRequest := MotionRequestActive AND (MotionDirection = 1);
            OperatorActionId := 16#0202;
            OperatorAction := 'Maintenir la montée : fermeture de la benne en cours.';
            IF BucketError THEN
                ErrorId := ErrorId OR 16#0002;
                StateAtError := State;
            ELSIF BucketIsClosed AND NOT BucketBusy THEN
                ControlStartM1Position_M := M1Position_M;
                ControlStartM2Position_M := M2Position_M;
                ExtractionState := E_ExtractionSequenceState.CONTROL_ASCENT;
            END_IF;

        E_ExtractionSequenceState.CONTROL_ASCENT:
            State := E_State.BUSY;
            Busy := TRUE;
            AscentPermit := MotionRequestActive AND (MotionDirection = 1);
            ForceMinSpeedStep := TRUE;
            OperatorActionId := 16#0203;
            OperatorAction := 'Maintenir la montée : contrôle charge au palier minimal.';
            IF WinchSyncError OR NOT PositionsValid OR NOT M1MeasuredSpeedValid OR NOT M2MeasuredSpeedValid THEN
                ErrorId := ErrorId OR 16#0004;
                StateAtError := State;
            ELSIF (M1Position_M >= (ControlStartM1Position_M + ControlAscentDistance_M))
               AND (M2Position_M >= (ControlStartM2Position_M + ControlAscentDistance_M)) THEN
                ExtractionState := E_ExtractionSequenceState.NOMINAL_ASCENT;
            END_IF;

        E_ExtractionSequenceState.NOMINAL_ASCENT:
            State := E_State.BUSY;
            Busy := TRUE;
            AscentPermit := MotionRequestActive AND (MotionDirection = 1);
            OperatorActionId := 16#0204;
            OperatorAction := 'Maintenir la montée : extraction en cours.';
            IF WinchSyncError OR NOT PositionsValid THEN
                ErrorId := ErrorId OR 16#0004;
                StateAtError := State;
            END_IF;

        E_ExtractionSequenceState.ERROR_HOLD:
            State := E_State.READY;
    END_CASE;
END_IF;

Error := (ErrorId <> 16#0000);

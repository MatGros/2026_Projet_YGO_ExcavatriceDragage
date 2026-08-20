(* =======================================================================
   ⚙️ FB_ExtractionSequence — Fermeture benne et remontée assistée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Séquence d'extraction (fermeture benne, remontée de contrôle, remontée nominale)
   🛡️ Sécurité : Aucune remontée assistée sans fond confirmé, contrôle palier 1
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md
   ======================================================================= *)
FUNCTION_BLOCK FB_ExtractionSequence
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                      : BOOL;     // --> [CMD] Activation generale du FB (TRUE=Autorise)
    Reset                       : BOOL;     // --> [CMD] Acquittement defaut (front)
    PowerContactorEngaged       : BOOL;     // --> [SAFE] Chaine de securite OK
    Mode                        : E_Mode;   // --> [CMD] Mode de fonctionnement arbitre
    MotionRequestActive         : BOOL;     // --> [CMD] Intention de mouvement active
    MotionDirection             : INT;      // --> [CMD] Sens de mouvement (+1 = montee)
    BottomPositionConfirmed     : BOOL;     // --> [SAFE] Attestation fond confirme (Kobold ou op)

    // === CAPTEURS & ETATS MATERIELS ===
    BucketIsClosed              : BOOL;     // --> [HW] Benne fermee confirmee
    BucketBusy                  : BOOL;     // --> [HW] Mouvement benne en cours
    BucketError                 : BOOL;     // --> [SAFE] Defaut sur sous-systeme benne
    WinchSyncError              : BOOL;     // --> [SAFE] Defaut de desynchronisme treuils M1/M2
    M1Position_M                : REAL;     // --> [HW] Position codeur treuil M1 (m)
    M2Position_M                : REAL;     // --> [HW] Position codeur treuil M2 (m)
    M1MeasuredSpeedValid        : BOOL;     // --> [HW] Validite mesure vitesse M1
    M2MeasuredSpeedValid        : BOOL;     // --> [HW] Validite mesure vitesse M2
    PositionsValid              : BOOL;     // --> [HW] Validite des mesures de position

    // === CONFIGURATION & REGLAGES ===
    ControlAscentDistance_M     : REAL;     // --> [CFG] Distance palier 1 de controle remontee (m)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                       : BOOL;     // <-- [STAT] FB pret a fonctionner (sortie libre, hors ST_FbStatus)
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0:fond ; bit1:ferme ; bit2:ctrl ; bit3:cfg.
    Status                      : ST_FbStatus; // <-- [STAT] Etat global FB (Busy/Done/Error/ErrorId/State/StateAtError)
    ExtractionState             : E_ExtractionSequenceState; // <-- [STAT] Phase interne extraction

    // === ORDRES & AUTORISATIONS ===
    BucketCloseRequest          : BOOL;     // <-- [ACT] Demande de fermeture benne
    AscentPermit                : BOOL;     // <-- [ACT] Autorisation de remontee assistee
    ForceMinSpeedStep           : BOOL;     // <-- [ACT] Forcage vitesse minimale (palier de controle)
    BottomConfirmationConsumed  : BOOL;     // <-- [STAT] Signal confirmation fond consomme

    // === DIAGNOSTIC IHM ===
    OperatorActionId            : WORD;     // <-- [DIAG] ID action operateur requise
    OperatorAction              : STRING(120); // <-- [DIAG] Message explicatif operateur
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge                   : R_TRIG;   // . [LOC] Detecteur front montant Reset

    // === MEMORISATIONS & POSITIONS INTERNES ===
    ControlStartM1Position_M    : REAL;     // . [LOC] Position M1 au debut du palier de controle (m)
    ControlStartM2Position_M    : REAL;     // . [LOC] Position M2 au debut du palier de controle (m)

    // === VARIABLES LOCALES INTERNES ===
    ErrorCausePresent           : BOOL;     // . [LOC] Presence d'une cause de defaut parametrage
END_VAR

{region "§1 Gate desactivation"}
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    BucketCloseRequest := FALSE; AscentPermit := FALSE; ForceMinSpeedStep := FALSE;
    BottomConfirmationConsumed := FALSE;
    Status.State := E_State.DISABLED;
    Status.StateAtError := E_State.DISABLED;
    ExtractionState := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;
    OperatorActionId := 0; OperatorAction := '';
    RETURN;
END_IF;

{endregion}

{region "§2 Preconditions reset et initialisation sorties"}
ResetEdge(CLK := Reset);
ErrorCausePresent := (ControlAscentDistance_M <= 0.0);
IF ErrorCausePresent THEN
    Status.ErrorId := Status.ErrorId OR 16#0008;
END_IF;
IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT MotionRequestActive THEN
    Status.ErrorId := 16#0000;
    Status.StateAtError := E_State.DISABLED;
    ExtractionState := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;
END_IF;

Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
BucketCloseRequest := FALSE; AscentPermit := FALSE; ForceMinSpeedStep := FALSE;
BottomConfirmationConsumed := FALSE;
OperatorActionId := 0; OperatorAction := '';

{endregion}

{region "§3 Machine etat fermeture remontee"}
IF Status.ErrorId <> 16#0000 THEN
    Status.State := E_State.READY;
    ExtractionState := E_ExtractionSequenceState.ERROR_HOLD;
    OperatorActionId := 16#0280;
    OperatorAction := 'Vérifier la benne et les treuils puis réarmer avant de reprendre.';
ELSE
    CASE ExtractionState OF
        E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION:
            Status.State := E_State.INIT;
            IF BottomPositionConfirmed THEN
                ExtractionState := E_ExtractionSequenceState.READY_TO_CLOSE;
            ELSE
                OperatorActionId := 16#0200;
                OperatorAction := 'Confirmer que la benne est posée au fond avant extraction.';
            END_IF;

        E_ExtractionSequenceState.READY_TO_CLOSE:
            Status.State := E_State.READY;
            Ready := TRUE;
            OperatorActionId := 16#0201;
            OperatorAction := 'Demander la montée pour fermer la benne.';
            IF MotionRequestActive AND (MotionDirection = 1) THEN
                BottomConfirmationConsumed := TRUE;
                ExtractionState := E_ExtractionSequenceState.CLOSING_BUCKET;
            END_IF;

        E_ExtractionSequenceState.CLOSING_BUCKET:
            Status.State := E_State.BUSY;
            Status.Busy := TRUE;
            BucketCloseRequest := MotionRequestActive AND (MotionDirection = 1);
            OperatorActionId := 16#0202;
            OperatorAction := 'Maintenir la montée : fermeture de la benne en cours.';
            IF BucketError THEN
                Status.ErrorId := Status.ErrorId OR 16#0002;
                Status.StateAtError := Status.State;
            ELSIF BucketIsClosed AND NOT BucketBusy THEN
                ControlStartM1Position_M := M1Position_M;
                ControlStartM2Position_M := M2Position_M;
                ExtractionState := E_ExtractionSequenceState.CONTROL_ASCENT;
            END_IF;

        E_ExtractionSequenceState.CONTROL_ASCENT:
            Status.State := E_State.BUSY;
            Status.Busy := TRUE;
            AscentPermit := MotionRequestActive AND (MotionDirection = 1);
            ForceMinSpeedStep := TRUE;
            OperatorActionId := 16#0203;
            OperatorAction := 'Maintenir la montée : contrôle charge au palier minimal.';
            IF WinchSyncError OR NOT PositionsValid OR NOT M1MeasuredSpeedValid OR NOT M2MeasuredSpeedValid THEN
                Status.ErrorId := Status.ErrorId OR 16#0004;
                Status.StateAtError := Status.State;
            ELSIF (M1Position_M >= (ControlStartM1Position_M + ControlAscentDistance_M))
               AND (M2Position_M >= (ControlStartM2Position_M + ControlAscentDistance_M)) THEN
                ExtractionState := E_ExtractionSequenceState.NOMINAL_ASCENT;
            END_IF;

        E_ExtractionSequenceState.NOMINAL_ASCENT:
            Status.State := E_State.BUSY;
            Status.Busy := TRUE;
            AscentPermit := MotionRequestActive AND (MotionDirection = 1);
            OperatorActionId := 16#0204;
            OperatorAction := 'Maintenir la montée : extraction en cours.';
            IF WinchSyncError OR NOT PositionsValid THEN
                Status.ErrorId := Status.ErrorId OR 16#0004;
                Status.StateAtError := Status.State;
            END_IF;

        E_ExtractionSequenceState.ERROR_HOLD:
            Status.State := E_State.READY;
    END_CASE;
END_IF;

Status.Error := (Status.ErrorId <> 16#0000);

{endregion}

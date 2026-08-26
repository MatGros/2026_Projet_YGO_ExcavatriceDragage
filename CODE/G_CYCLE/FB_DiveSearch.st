(* =======================================================================
   ⚙️ FB_DiveSearch — Assistance plongée et recherche du fond Kobold
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Qualification du capteur Kobold et autorisation de descente
   🛡️ Sécurité : Verrouillage si séquence d'immersion 0->1->0 invalide
   🔌 Interface : Intention de descente et mesures vers permis de descente
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.2.md
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

    // === CONFIGURATION & SEUILS ===
    DiveStartMin_M          : REAL;         // --> [CFG] Seuil position min pour debut plongee (m)
    ImmersionUpper_M        : REAL;         // --> [CFG] Borne haute fenetre d'immersion (m)
    ImmersionLower_M        : REAL;         // --> [CFG] Borne basse fenetre d'immersion (m)
    BypassPreconditions     : BOOL := FALSE;// --> [TST] Bypass preconditions et seuils (mode test)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                   : BOOL;         // <-- [STAT] FB pret a fonctionner
    // Status.ErrorId : bit0 precond, bit1 seq, bit2 cfg
    Status                  : ST_FbStatus;  // <-- [STAT] Etat global FB (Busy/Done/Error/ErrorId/State/StateAtError)
    DiveState               : E_DiveSearchState; // <-- [STAT] Phase interne de recherche fond

    // === PERMIS & AUTORISATIONS ===
    DescendPermit           : BOOL;         // <-- [ACT] Autorisation de descente assistee
    KoboldMeasureEnable     : BOOL;         // <-- [ACT] Activation mesure/acquisition Kobold
    BottomTouchConfirmed    : BOOL;         // <-- [STAT] Contact fond valide et confirme

    // === DIAGNOSTIC IHM ===
    OperatorActionId        : WORD;         // <-- [DIAG] ID action operateur requise
    OperatorAction          : STRING(120);  // <-- [DIAG] Message explicatif operateur
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge               : R_TRIG;       // . [LOC] Detecteur front montant Reset
    KoboldRiseEdge          : R_TRIG;       // . [LOC] Detecteur front entrant eau (0->1)
    KoboldFallEdge          : F_TRIG;       // . [LOC] Detecteur front sortie eau / fond (1->0)

    // === VARIABLES LOCALES INTERNES ===
    ImmersionConfirmed      : BOOL;         // . [LOC] Immersion dans la fenetre d'eau validee
    ErrorCausePresent       : BOOL;         // . [LOC] Presence d'une cause de defaut parametrage
END_VAR

{region "§1 Gate desactivation"}
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    DescendPermit := FALSE; KoboldMeasureEnable := FALSE;
    BottomTouchConfirmed := FALSE;
    Status.State := E_State.DISABLED;
    Status.StateAtError := E_State.DISABLED;
    DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
    OperatorActionId := 0; OperatorAction := '';
    ImmersionConfirmed := FALSE;
    RETURN;
END_IF;

{endregion}

{region "§2 Preconditions fronts et rearmement"}
ResetEdge(CLK := Reset);
KoboldRiseEdge(CLK := KoboldImmersed);
KoboldFallEdge(CLK := KoboldImmersed);

ErrorCausePresent := NOT BypassPreconditions AND ((DiveStartMin_M < ImmersionUpper_M)
                  OR (ImmersionUpper_M <= ImmersionLower_M));
IF ErrorCausePresent THEN
    Status.ErrorId := Status.ErrorId OR 16#0004;
END_IF;

(* Reset = front + causes disparues ; aucun redémarrage automatique. *)
IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT KoboldImmersed AND NOT MotionRequestActive THEN
    Status.ErrorId := 16#0000;
    ImmersionConfirmed := FALSE;
    BottomTouchConfirmed := FALSE;
    Status.StateAtError := E_State.DISABLED;
    DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
END_IF;

DescendPermit := FALSE; KoboldMeasureEnable := FALSE;
Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
OperatorActionId := 0; OperatorAction := '';

{endregion}

{region "§3 Machine etat plongee recherche fond"}
IF Status.ErrorId <> 16#0000 THEN
    Status.State := E_State.READY;
    DiveState := E_DiveSearchState.ERROR_HOLD;
    OperatorActionId := 16#0180;
    OperatorAction := 'Vérifier les conditions puis réarmer avant une nouvelle plongée.';
ELSE
    CASE DiveState OF
        E_DiveSearchState.WAIT_PRECONDITIONS:
            Status.State := E_State.INIT;
            IF NOT BypassPreconditions
               AND (NOT BucketIsOpen OR NOT PositionsValid OR KoboldImmersed
                    OR (M1Position_M < DiveStartMin_M) OR (M2Position_M < DiveStartMin_M)) THEN
                OperatorActionId := 16#0100;
                OperatorAction := 'Vérifier les conditions initiales de plongée.';
            ELSE
                DiveState := E_DiveSearchState.READY_TO_DESCEND;
            END_IF;

        E_DiveSearchState.READY_TO_DESCEND:
            Status.State := E_State.READY;
            Ready := TRUE;
            OperatorActionId := 16#0101;
            OperatorAction := 'Demander une descente pour rechercher le fond.';
            IF MotionRequestActive AND (MotionDirection = -1) THEN
                DiveState := E_DiveSearchState.SEARCHING_IMMERSION;
            END_IF;

        E_DiveSearchState.SEARCHING_IMMERSION:
            Status.State := E_State.BUSY;
            Status.Busy := TRUE;
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
                    Status.ErrorId := Status.ErrorId OR 16#0002;
                    Status.StateAtError := Status.State;
                END_IF;
            ELSIF (M1Position_M < ImmersionLower_M) OR (M2Position_M < ImmersionLower_M) THEN
                Status.ErrorId := Status.ErrorId OR 16#0002;
                Status.StateAtError := Status.State;
            END_IF;

        E_DiveSearchState.SEARCHING_BOTTOM:
            Status.State := E_State.BUSY;
            Status.Busy := TRUE;
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
            Status.State := E_State.DONE;
            Status.Done := TRUE;
            OperatorActionId := 16#0104;
            OperatorAction := 'Fond détecté : demander la fermeture ou l extraction.';

        E_DiveSearchState.ERROR_HOLD:
            Status.State := E_State.READY;
    END_CASE;
END_IF;

Status.Error := (Status.ErrorId <> 16#0000);

{endregion}

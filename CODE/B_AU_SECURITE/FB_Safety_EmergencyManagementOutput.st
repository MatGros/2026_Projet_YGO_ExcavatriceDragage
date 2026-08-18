(* =======================================================================
   🔒 FB_Safety_EmergencyManagementOutput — Projection Physique Fail-Safe
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Enable gate + copie consignes logiques vers sorties physiques
   🔒 Polarité : MaintainA/B_RQ en maintien (TRUE = voie saine)
   🔌 Architecture : Projection physique fail-safe
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementOutput
VAR_INPUT
    // === CONSIGNES & COMMANDES LOGIQUES ===
    Enable                  : BOOL; // --> [CMD]  Active le pilote (FALSE = toutes sorties a FALSE)
    Cmd                     : ST_Safety_Emergency_InternalCmd; // --> [CMD] Ordres logiques recus du bloc logique

    // === RETOURS D'ETAT & DIAGNOSTICS (MIROIRS) ===
    ChainOk                 : BOOL; // --> [HW]   Miroir EmergencyChainClosed (pour bus State)
    ContactorOk             : BOOL; // --> [HW]   Miroir PowerContactorEngaged (pour bus State)
    ArmingStep              : INT;  // --> [STAT] Miroir ArmingSeqStep (pour bus State)
    Armable                 : BOOL; // --> [STAT] Calcule par Logic (pour bus State)
    ArmingBusy              : BOOL; // --> [STAT] Calcule par Logic (pour bus State)
    Error                   : BOOL; // --> [DIAG] Miroir Error (pour bus Diag)
    ErrorId                 : WORD; // --> [DIAG] Miroir ErrorId (pour bus Diag)
    RedundancyTestFailed    : BOOL; // --> [DIAG] Miroir RedundancyTestFailed (pour bus Diag)
    ArmFailed               : BOOL; // --> [DIAG] Miroir ArmFailed (pour bus Diag)
    LockoutActive           : BOOL; // --> [DIAG] Miroir LockoutActive (pour bus Diag)
END_VAR
VAR_OUTPUT
    // === SORTIES PHYSIQUES TERMINALES ===
    MaintainA_RQ            : BOOL; // <-- [ACT]  Vers relais maintien canal A (TRUE = voie maintenue)
    MaintainB_RQ            : BOOL; // <-- [ACT]  Vers relais maintien canal B (TRUE = voie maintenue)
    ArmPulse_RQ             : BOOL; // <-- [ACT]  Vers contacteur impulsion rearmement (TRUE = pulse actif)

    // === BUS D'ETAT & DIAGNOSTIC PUBLICS ===
    State                   : ST_Safety_Emergency_State; // <-- [STAT] Bus d'etat public
    Diag                    : ST_Safety_Emergency_Diag;  // <-- [DIAG] Bus diagnostic public
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    MaintainA_RQ   := FALSE;
    MaintainB_RQ   := FALSE;
    ArmPulse_RQ    := FALSE;

    State.ChainOk        := FALSE;
    State.ContactorOk    := FALSE;
    State.Step           := 0;
    State.Armable        := FALSE;
    State.ArmingBusy     := FALSE;

    Diag.Error                := FALSE;
    Diag.ErrorId              := 16#0000;
    Diag.RedundancyTestFailed := FALSE;
    Diag.ArmFailed            := FALSE;
    Diag.LockoutActive        := FALSE;
    RETURN;
END_IF;

// ⚡ Sorties physiques — écriture directe des ordres logiques
MaintainA_RQ := Cmd.MaintainA_Cmd;
MaintainB_RQ := Cmd.MaintainB_Cmd;
ArmPulse_RQ  := Cmd.ArmPulse_Cmd;

// 🚦 Bus d'état public
State.ChainOk        := ChainOk;
State.ContactorOk    := ContactorOk;
State.Step           := ArmingStep;
State.Armable        := Armable;
State.ArmingBusy     := ArmingBusy;

// 🛡️ Bus diagnostic public
Diag.Error                := Error;
Diag.ErrorId              := ErrorId;
Diag.RedundancyTestFailed := RedundancyTestFailed;
Diag.ArmFailed            := ArmFailed;
Diag.LockoutActive        := LockoutActive;

(* ═══════════════════════════════════════════════════════════════
   📤 FB_Safety_EmergencyManagementOutput — Pilote physique + bus état/diag
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Transmet les ordres de sécurité logiques vers les
      sorties physiques ET produit les bus d'état et diagnostic
      publics (ST_Safety_Emergency_State / ST_Safety_Emergency_Diag).
   🧩 Instance privée du composite FB_Safety_EmergencyManagement
      — jamais appelée hors du composite.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-03_Contrats_Composants_v2.1.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementOutput
VAR_INPUT
    Enable              : BOOL;                // Active le pilote (FALSE = toutes sorties à FALSE)
    Cmd                 : ST_Safety_Emergency_InternalCmd; // Ordres logiques reçus du bloc logique
    ChainOk             : BOOL;                // Miroir EmergencyChainClosed (pour bus State)
    ContactorOk         : BOOL;                // Miroir PowerContactorEngaged (pour bus State)
    ArmingStep          : INT;                 // Miroir ArmingSeqStep (pour bus State)
    Armable             : BOOL;                // Calculé par Logic (pour bus State)
    ArmingBusy          : BOOL;                // Calculé par Logic (pour bus State)
    Error               : BOOL;                // Miroir Error (pour bus Diag)
    ErrorId             : WORD;                // Miroir ErrorId (pour bus Diag)
    RedundancyTestFailed : BOOL;               // Miroir (pour bus Diag)
    ArmFailed           : BOOL;                // Miroir (pour bus Diag)
    LockoutActive       : BOOL;                // Miroir (pour bus Diag)
END_VAR
VAR_OUTPUT
    // ⚡ Sorties physiques terminales
    MaintainA_RQ        : BOOL; // Vers relais maintien canal A — TRUE = voie maintenue, FALSE = coupure
    MaintainB_RQ        : BOOL; // Vers relais maintien canal B — TRUE = voie maintenue, FALSE = coupure
    ArmPulse_RQ         : BOOL; // Vers contacteur impulsion réarmement — TRUE = pulse actif

    // 🚦 Bus d'état public
    State               : ST_Safety_Emergency_State;
    Diag                : ST_Safety_Emergency_Diag;
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

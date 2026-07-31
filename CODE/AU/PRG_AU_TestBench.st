(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_AU_TestBench — Programme principal de test chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Ordonnance les étages Acquisition → Outputs dans l'ordre
      correct (même flux que MainTask réelle).
   🎮 Pilotage via Watch CODESYS :
      GVL_IHM_AU.Cmd.BtnEmergencyArming  = TRUE  → lance réarmement
      GVL_IHM_AU.Cmd.BtnFaultReset       = TRUE  → acquitte défauts
      GVL_IHM_AU.Cmd.BtnEmergencyCutOff  = TRUE  → coupure IHM
      GVL_Simulation_AU.SimContactorEngaged = TRUE → simule retour contacteur
      GVL_Simulation_AU.SimPowerCutOffReq   = TRUE → simule coupure métier
   👁️ Observation :
      PRG_AU_Outputs_LD.State.Step      → étape séquence (0..6)
      PRG_AU_Outputs_LD.PowerKeepAlive_A_RQ → état maintien A
      PRG_AU_Outputs_LD.EmergencyArming_RQ  → pulse réarmement
      PRG_AU_Outputs_LD.Diag            → erreurs/locks
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

PROGRAM PRG_AU_TestBench
VAR_OUTPUT
    // 🩺 Synthèse lisible pour Watch
    StepLabel           : STRING;
    MaintainA           : BOOL;
    MaintainB           : BOOL;
    ArmPulse            : BOOL;
    Step                : INT;
    ErrorId             : WORD;
    RedundancyFailed    : BOOL;
    ArmFailed           : BOOL;
    Lockout             : BOOL;
    ChainOk             : BOOL;
    ContactorOk         : BOOL;
    Armable             : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 🔄 1. Acquisition des entrées (simulées)
PRG_AU_Acquisition();

// 📤 2. Traitement et sorties (composite + Q)
PRG_AU_Outputs_LD();

// 🩺 Synthèse Watch — lecture des bus structurés
MaintainA        := PRG_AU_Outputs_LD.PowerKeepAlive_A_RQ;
MaintainB        := PRG_AU_Outputs_LD.PowerKeepAlive_B_RQ;
ArmPulse         := PRG_AU_Outputs_LD.EmergencyArming_RQ;
Step             := PRG_AU_Outputs_LD.State.Step;
ErrorId          := PRG_AU_Outputs_LD.Diag.ErrorId;
RedundancyFailed := PRG_AU_Outputs_LD.Diag.RedundancyTestFailed;
ArmFailed        := PRG_AU_Outputs_LD.Diag.ArmFailed;
Lockout          := PRG_AU_Outputs_LD.Diag.LockoutActive;
ChainOk          := PRG_AU_Outputs_LD.State.ChainOk;
ContactorOk      := PRG_AU_Outputs_LD.State.ContactorOk;
Armable          := PRG_AU_Outputs_LD.State.Armable;

// 📤 Publication IHM — l'opérateur voit ces retours sur son écran
// [IHM] Publication dans la structure d'etat IHM (lue par la visu operateur)
GVL_IHM_AU.State.ChainOk              := PRG_AU_Outputs_LD.State.ChainOk;
GVL_IHM_AU.State.ContactorOk          := PRG_AU_Outputs_LD.State.ContactorOk;
GVL_IHM_AU.State.Armable              := PRG_AU_Outputs_LD.State.Armable;
GVL_IHM_AU.State.ArmingBusy           := PRG_AU_Outputs_LD.State.ArmingBusy;
GVL_IHM_AU.State.RedundancyTestFailed := PRG_AU_Outputs_LD.Diag.RedundancyTestFailed;
GVL_IHM_AU.State.ArmingFailed         := PRG_AU_Outputs_LD.Diag.ArmFailed;
GVL_IHM_AU.State.LockoutActive        := PRG_AU_Outputs_LD.Diag.LockoutActive;
GVL_IHM_AU.State.Step                 := PRG_AU_Outputs_LD.State.Step;
GVL_IHM_AU.State.Error                := PRG_AU_Outputs_LD.Diag.Error;
GVL_IHM_AU.State.ErrorId              := PRG_AU_Outputs_LD.Diag.ErrorId;
GVL_IHM_AU.State.PowerCutOffActive    := GVL_Simulation_AU.SimPowerCutOffReq;

CASE Step OF
    0: StepLabel := 'IDLE (attente armement)';
    1: StepLabel := 'TestA (coupe A)';
    2: StepLabel := 'RestoreA (rétablit A)';
    3: StepLabel := 'TestB (coupe B)';
    4: StepLabel := 'RestoreB (rétablit B)';
    5: StepLabel := 'Pulse (armement 1s)';
    6: StepLabel := 'Confirm (attente contacteur)';
ELSE
    StepLabel := 'ERREUR';
END_CASE;

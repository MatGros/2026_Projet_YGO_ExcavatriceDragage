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
      PRG_AU_Outputs_LD.ArmingSeqStep    → étape séquence (0..6)
      PRG_AU_Outputs_LD.PowerKeepAlive_A_RQ → état maintien A
      PRG_AU_Outputs_LD.EmergencyArming_RQ  → pulse réarmement
      PRG_AU_Outputs_LD.ErrorId          → erreurs/locks
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

// 🩺 Synthèse Watch — lecture des sorties scalaires (pattern PRG_10_Outputs_LD)
MaintainA        := PRG_AU_Outputs_LD.PowerKeepAlive_A_RQ;
MaintainB        := PRG_AU_Outputs_LD.PowerKeepAlive_B_RQ;
ArmPulse         := PRG_AU_Outputs_LD.EmergencyArming_RQ;
Step             := PRG_AU_Outputs_LD.ArmingSeqStep;
ErrorId          := PRG_AU_Outputs_LD.ErrorId;
RedundancyFailed := PRG_AU_Outputs_LD.RedundancyTestFailed;
ArmFailed        := PRG_AU_Outputs_LD.EmergencyArmingFailed;
Lockout          := PRG_AU_Outputs_LD.EmergencyArmingLockoutActive;
ChainOk          := PRG_AU_Outputs_LD.ChainOk;
ContactorOk      := PRG_AU_Outputs_LD.ContactorOk;
Armable          := PRG_AU_Outputs_LD.Armable;

// 📤 Publication IHM — l'opérateur voit ces retours sur son écran
// [IHM] Publication dans la structure d'etat IHM (lue par la visu operateur)
GVL_IHM_AU.State.ChainOk              := ChainOk;
GVL_IHM_AU.State.ContactorOk          := ContactorOk;
GVL_IHM_AU.State.Armable              := Armable;
GVL_IHM_AU.State.ArmingBusy           := PRG_AU_Outputs_LD.ArmingBusy;
GVL_IHM_AU.State.RedundancyTestFailed := RedundancyFailed;
GVL_IHM_AU.State.ArmingFailed         := ArmFailed;
GVL_IHM_AU.State.LockoutActive        := Lockout;
GVL_IHM_AU.State.Step                 := Step;
GVL_IHM_AU.State.Error                := PRG_AU_Outputs_LD.Error;
GVL_IHM_AU.State.ErrorId              := ErrorId;
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

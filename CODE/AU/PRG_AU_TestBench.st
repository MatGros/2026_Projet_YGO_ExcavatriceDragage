(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_AU_TestBench — Banc de test minimal pour FB_Safety_EmergencyManagement
   ───────────────────────────────────────────────────────────────
   📄 Programme minimal autonome pour simuler et tester la chaîne AU :
      • Toutes les entrées du composite sont exposées en VAR_INPUT
      • Toutes les sorties en VAR_OUTPUT pour observation Watch/IHM
      • Un cycle de simulation basique avec front armement intégré
   🎯 Objectif : vérifier la séquence d'auto-test A/B, le pulse,
      la confirmation, le lockout, sans matériel réel.
   ⚙️ Usage : instancier dans une tâche CODESYS à 50 ms, piloter
      les inputs depuis une table Watch ou un visu de test.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_FB_Safety_EmergencyManagement_v1.0.md
*)

PROGRAM PRG_AU_TestBench
VAR_INPUT
    // 🎮 Commandes testeur
    SimEnable              : BOOL := TRUE;
    SimReset               : BOOL := FALSE;
    SimArmRequest          : BOOL := FALSE;    // Front demandé à l'utilisateur
    SimChainClosed         : BOOL := TRUE;     // Boucle AU fermée
    SimContactorEngaged    : BOOL := FALSE;    // Retour contacteur
    SimPowerCutOffReq      : BOOL := FALSE;    // Demande coupure safety métier
    SimBtnCutOff           : BOOL := FALSE;    // Coupure IHM maintenue
END_VAR
VAR_OUTPUT
    // 🚦 États observables
    Ready                  : BOOL;
    Busy                   : BOOL;
    Done                   : BOOL;
    Error                  : BOOL;
    ErrorId                : WORD;
    MaintainA_RQ           : BOOL;
    MaintainB_RQ           : BOOL;
    ArmPulse_RQ            : BOOL;

    // 🚦 Bus structurés
    State                  : ST_State_Emergency;
    Diag                   : ST_Diag_Emergency;

    // 🩺 Diagnostics scalaires
    ArmingSeqStep          : INT;
    RedundancyTestFailed   : BOOL;
    ArmFailed              : BOOL;
    LockoutActive          : BOOL;

    // 🔄 Indicateurs de simulation
    CycleCount             : UDINT;
    StateLabel             : STRING[40];
END_VAR
VAR
    // Instance du composite testé
    instEmergency          : FB_Safety_EmergencyManagement;

    // Gestion fronts
    ArmReqTrig             : R_TRIG;
    ResetTrig              : R_TRIG;
END_VAR

// === IMPLEMENTATION ===

// 🔄 Fronts
ArmReqTrig(CLK := SimArmRequest);
ResetTrig(CLK := SimReset);

// 🛡️ Appel du composite
instEmergency(
    Enable := SimEnable,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,  // ou SimReset si test isolé
    ArmRequest := SimArmRequest,
    EmergencyChainClosed := SimChainClosed,
    PowerContactorEngaged := SimContactorEngaged,
    PowerCutOffRequest := SimPowerCutOffReq,
    BtnEmergencyCutOff := SimBtnCutOff
);

// 📤 Sorties observables
Ready        := instEmergency.Ready;
Busy         := instEmergency.Busy;
Done         := instEmergency.Done;
Error        := instEmergency.Error;
ErrorId      := instEmergency.ErrorId;
MaintainA_RQ := instEmergency.MaintainA_RQ;
MaintainB_RQ := instEmergency.MaintainB_RQ;
ArmPulse_RQ  := instEmergency.ArmPulse_RQ;
State        := instEmergency.State;
Diag         := instEmergency.Diag;
ArmingSeqStep       := instEmergency.State.Step;
RedundancyTestFailed := instEmergency.Diag.RedundancyTestFailed;
ArmFailed           := instEmergency.Diag.ArmFailed;
LockoutActive       := instEmergency.Diag.LockoutActive;

// 🔄 Label lisible de l'étape
CASE instEmergency.State.Step OF
    0: StateLabel := 'IDLE (attente réarmement)';
    1: StateLabel := 'TestA (coupe canal A)';
    2: StateLabel := 'RestoreA (rétablit A)';
    3: StateLabel := 'TestB (coupe canal B)';
    4: StateLabel := 'RestoreB (rétablit B)';
    5: StateLabel := 'Pulse (impulsion 1s)';
    6: StateLabel := 'Confirm (attente contacteur)';
ELSE
    StateLabel := 'INCONNU';
END_CASE;

// 🔄 Compteur de cycle
CycleCount := CycleCount + 1;

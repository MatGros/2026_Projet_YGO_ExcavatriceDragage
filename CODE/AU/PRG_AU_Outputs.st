(* ═══════════════════════════════════════════════════════════════
   📤 PRG_AU_Outputs — Écriture des sorties AU (dernière couche)
   ───────────────────────────────────────────────────────────────
   📄 Appelle FB_Safety_EmergencyManagement et écrit les variables
      Q physiques (PowerKeepAlive_A/B_RQ, EmergencyArming_RQ).
   🧩 Remplit le rôle de PRG_10_Outputs_LD pour le domaine AU.
   🎯 Ordre d'appel obligatoire : PRG_AU_Acquisition → PRG_AU_Outputs
      (même cycle, même tâche).
   🚦 Produit les bus ST_State_Emergency et ST_Diag_Emergency
      observables en Watch pour vérification de la séquence.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

PROGRAM PRG_AU_Outputs
VAR_OUTPUT
    // ⚡ Sorties physiques terminales (mêmes noms que le projet réel)
    PowerKeepAlive_A_RQ : BOOL;   // Relais maintien canal A (TRUE = voie maintenue)
    PowerKeepAlive_B_RQ : BOOL;   // Relais maintien canal B (TRUE = voie maintenue)
    EmergencyArming_RQ  : BOOL;   // Impulsion réarmement contacteur (1s)

    // 🚦 Bus d'état et diagnostic pour observation Watch
    State               : ST_State_Emergency;
    Diag                : ST_Diag_Emergency;
END_VAR
VAR
    // Instance unique du composite AU
    instEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === IMPLEMENTATION ===

// 🛡️ Appel du composite — entrées depuis Acquisition + IHM
instEmergencyManagement(
    Enable := TRUE,
    Reset := GVL_IHM_AU.Cmd.BtnFaultReset,
    ArmRequest := GVL_IHM_AU.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_AU_Acquisition.EmergencyChainClosed,
    PowerContactorEngaged := PRG_AU_Acquisition.PowerContactorEngaged,
    PowerCutOffRequest := PRG_AU_Acquisition.PowerCutOffRequest,
    BtnEmergencyCutOff := GVL_IHM_AU.Cmd.BtnEmergencyCutOff
);

// ⚡ Sorties physiques
PowerKeepAlive_A_RQ := instEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ  := instEmergencyManagement.ArmPulse_RQ;

// 🚦 Observation structurée
State := instEmergencyManagement.State;
Diag  := instEmergencyManagement.Diag;

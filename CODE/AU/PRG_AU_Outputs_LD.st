(* ═══════════════════════════════════════════════════════════════
   📤 PRG_AU_Outputs_LD — Écriture des sorties AU (dernière couche, LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Appelle FB_Safety_EmergencyManagement et écrit les variables
      Q physiques (PowerKeepAlive_A/B_RQ, EmergencyArming_RQ).
   🧩 Structure identique à PRG_10_Outputs_LD (projet réel) pour le
      domaine AU isolé : converti automatiquement en Ladder Diagram
      (<LD>) dans CODESYS, comme la frontière finale réelle.
   🎯 Ordre d'appel obligatoire : PRG_AU_Acquisition → PRG_AU_Outputs_LD
      (même cycle, même tâche).
   🚦 Produit les bus ST_State_Emergency et ST_Diag_Emergency
      observables en Watch pour vérification de la séquence.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-02_Architecture_Programme_v3.0.md §2 (PRG_OUTPUTS_LD)
*)

PROGRAM PRG_AU_Outputs_LD
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
    // Instance unique du composite AU — barrière finale, seul écrivain des Q AU
    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === IMPLEMENTATION ===

// 🛡️ Gestionnaire d'arrêt d'urgence et de réarmement
instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := GVL_IHM_AU.Cmd.BtnFaultReset,
    ArmRequest := GVL_IHM_AU.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_AU_Acquisition.EmergencyChainClosed,
    PowerContactorEngaged := PRG_AU_Acquisition.PowerContactorEngaged,
    PowerCutOffRequest := PRG_AU_Acquisition.PowerCutOffRequest,
    BtnEmergencyCutOff := GVL_IHM_AU.Cmd.BtnEmergencyCutOff
);

// ⚡ Affectation des sorties de réarmement et maintien puissance
PowerKeepAlive_A_RQ := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ  := instSafetyEmergencyManagement.ArmPulse_RQ;

// 🚦 Observation structurée
State := instSafetyEmergencyManagement.State;
Diag  := instSafetyEmergencyManagement.Diag;

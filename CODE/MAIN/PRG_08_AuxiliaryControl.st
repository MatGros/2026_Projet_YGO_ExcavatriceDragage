(* ═══════════════════════════════════════════════════════════════
   ⚡ PRG_08_AuxiliaryControl — Diagnostic Auxiliaires (Centrale Hydraulique)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 8.
   🔧 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 "Rôle de chaque
      programme" §PRG_08) — le PLC ne commande plus casque, grille ni
      centrale hydraulique (retiré, ex-§8 PRG_10_Outputs + ex-champs
      GridOpenCmd/GridCloseCmd/HelmetOpenCmd/HelmetCloseCmd de ST_IHM_MANU).
      Seul le retour thermique centrale hydraulique est conservé, remonté
      en diagnostic IHM (aucune commande, aucun auto-démarrage).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_08_AuxiliaryControl
VAR_OUTPUT
    HydraulicFaultOk : BOOL;   // 🌡️ Diagnostic thermique centrale hydraulique (NC) : TRUE=sain ✅ | FALSE=surchauffe/coupure 🔴 → IHM
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_08_AuxiliaryControl) ===

// 🌡️ Retour thermique brut (NC) — entrée physique ThermHydraulique_DI ;
// tant que non câblé, ce point lira FALSE côté image process réelle si absent, d'où l'OR simulation.
HydraulicFaultOk := ThermHydraulique_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.HydraulicThermal_IsReal);

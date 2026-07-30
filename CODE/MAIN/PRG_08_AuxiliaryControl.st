(* ═══════════════════════════════════════════════════════════════
   ⚡ PRG_08_AuxiliaryControl — Diagnostic Auxiliaires (Centrale Hydraulique)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 8.
   🔧 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 "Rôle de chaque
      programme" §PRG_08) — le PLC ne commande plus casque, grille ni
      centrale hydraulique. Seul le retour thermique centrale hydraulique
      est conservé, remonté en diagnostic IHM.
   📄 Lot L5 : Lecture depuis PRG_00_Inputs.HwIn.Machine.HydraulicThermalOk_DI
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-05_Modes_Maintenance_v2.0.md
*)

PROGRAM PRG_08_AuxiliaryControl
VAR_OUTPUT
    HydraulicFaultOk : BOOL;   // 🌡️ Diagnostic thermique centrale hydraulique (NC) : TRUE=sain ✅ | FALSE=surchauffe/coupure 🔴 → IHM
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_08_AuxiliaryControl) ===

HydraulicFaultOk := PRG_00_Inputs.HwIn.Machine.HydraulicThermalOk_DI;

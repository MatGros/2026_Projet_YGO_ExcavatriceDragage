(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_KlossTorque — Couple electromagnetique, formule de Kloss
   ───────────────────────────────────────────────────────────────
   🎯 Role : Calcul factorise du couple moteur asynchrone (Kloss), reutilise
   par le regime etabli et le test de decrochage a glissement bloque.
   📄 Doc metier : DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md
   🧩 Dependances : aucune (calcul pur)
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Sim_KlossTorque
VAR_INPUT
    // === CONTRAT LIGHT ===
    Enable                 : BOOL; // --> [CMD] Autorisation generale FB

    // === CALCUL ===
    MaxTorque_Nm           : REAL; // --> [CFG] Cmax decrochage
    Slip_Ratio              : REAL; // --> [CMD] Glissement (jamais 0.0 -- protege par l'appelant)
    SlipAtMaxTorque_Ratio   : REAL; // --> [CFG] gmax au point de fonctionnement courant
    VoltageRatio2           : REAL := 1.0; // --> [CMD] (U_act/U_nom)^2
END_VAR
VAR_OUTPUT
    Ready                  : BOOL; // <-- [STAT] FB pret
    Torque_Nm              : REAL; // <-- [DIAG] Couple electromagnetique resultant
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    Torque_Nm := 0.0;
    RETURN;
END_IF;

Torque_Nm := 2.0 * MaxTorque_Nm
    / (Slip_Ratio / SlipAtMaxTorque_Ratio + SlipAtMaxTorque_Ratio / Slip_Ratio)
    * VoltageRatio2;

Ready := TRUE;

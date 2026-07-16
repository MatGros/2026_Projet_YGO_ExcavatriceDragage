(* ═══════════════════════════════════════════════════════════════
   🧪 FB_PLC_Tests_Management — Gestion Globale des Tests de Validation Automatisés
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe, configure et orchestre toutes les instances
      de tests de validation automate (banc de test global).
      Met à jour directement GVL_Simulation pour affichage unifié.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_PLC_Tests_Management
VAR
    // 🧱 Instances de tests individuels hébergées
    instSafetyValidation       : FB_SafetyValidation;
    
    // Flag de déclenchement interne
    TriggerSafetyTests         : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 1. Détection du bit de déclenchement global dans GVL_Simulation
IF GVL_Simulation.CmdRunTests THEN
    GVL_Simulation.CmdRunTests := FALSE;
    TriggerSafetyTests := TRUE;
ELSE
    TriggerSafetyTests := FALSE;
END_IF;

// 2. Appel de l'instance de test pour la sécurité d'urgence
instSafetyValidation(StartTests := TriggerSafetyTests);

// 3. Centralisation directe des résultats dans GVL_Simulation
GVL_Simulation.TestInProgress          := instSafetyValidation.TestInProgress;
GVL_Simulation.AllTestsPassed          := instSafetyValidation.AllTestsPassed;
GVL_Simulation.TestFailed              := instSafetyValidation.TestFailed;
GVL_Simulation.TC01_NominalArming_Ok   := instSafetyValidation.TC01_NominalArming_Ok;
GVL_Simulation.TC02_RedundancyFault_Ok := instSafetyValidation.TC02_RedundancyFault_Ok;
GVL_Simulation.TC03_Lockout_Ok         := instSafetyValidation.TC03_Lockout_Ok;
GVL_Simulation.FailedTestCase          := instSafetyValidation.FailedTestCase;

// 4. Centralisation directe des surcharges de simulation (overrides)
GVL_Simulation.OverrideChainTrue       := instSafetyValidation.OverrideChainTrue;
GVL_Simulation.OverrideChainFalse      := instSafetyValidation.OverrideChainFalse;
GVL_Simulation.OverrideContactorFalse  := instSafetyValidation.OverrideContactorFalse;

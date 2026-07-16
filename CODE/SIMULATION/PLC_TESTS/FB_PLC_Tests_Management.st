(* ═══════════════════════════════════════════════════════════════
   🧪 FB_PLC_Tests_Management — Gestion Globale des Tests de Validation Automatisés
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe, configure et orchestre toutes les instances
      de tests de validation automate (banc de test global).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_PLC_Tests_Management
VAR_OUTPUT
    // Statuts de synthèse globaux
    TestInProgress             : BOOL;
    AllTestsPassed             : BOOL;
    TestFailed                 : BOOL;
    
    // Accès aux résultats détaillés pour la supervision
    TC01_NominalArming_Ok      : BOOL;
    TC02_RedundancyFault_Ok    : BOOL;
    TC03_Lockout_Ok            : BOOL;
    FailedTestCase             : INT;
END_VAR
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

// 3. Propagation de la synthèse de statut et des résultats détaillés
TestInProgress          := instSafetyValidation.TestInProgress;
AllTestsPassed          := instSafetyValidation.AllTestsPassed;
TestFailed              := instSafetyValidation.TestFailed;
TC01_NominalArming_Ok   := instSafetyValidation.TC01_NominalArming_Ok;
TC02_RedundancyFault_Ok := instSafetyValidation.TC02_RedundancyFault_Ok;
TC03_Lockout_Ok         := instSafetyValidation.TC03_Lockout_Ok;
FailedTestCase          := instSafetyValidation.FailedTestCase;

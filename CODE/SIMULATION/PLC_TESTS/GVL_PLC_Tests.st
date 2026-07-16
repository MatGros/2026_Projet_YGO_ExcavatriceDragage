(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests — Variables globales du banc de validation
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de données pour l'IHM et rapports de tests
      conformément à la spécification v1.2 de l'AF Partie 14.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    Hmi                        : ST_PlcTestsHMI;      // 🖥️ Page IHM banc de test
    SafetyValidation           : ST_TestSuiteReport;  // Rapport de la suite Safety
    
    // ⚡ Surcharges (overrides) physiques lues par PRG_00_Inputs
    OverrideChainTrue          : BOOL;                // Force la boucle AU à TRUE
    OverrideChainFalse         : BOOL;                // Force la boucle AU à FALSE
    OverrideContactorFalse     : BOOL;                // Force le retour contacteur à FALSE
END_VAR

(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests — Variables globales du banc de validation
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe toutes les commandes et retours d'états
      du banc de tests automatique in-PLC.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    CmdRunTests                : BOOL := FALSE; // 🔑 Lancement des tests de validation (bouton IHM/Simu)
    TestInProgress             : BOOL;          // Test en cours d'exécution
    AllTestsPassed             : BOOL;          // Succès global : tous les scénarios validés 🟢
    TestFailed                 : BOOL;          // Échec détecté 🔴
    TC01_NominalArming_Ok      : BOOL;          // Statut TC-01 (Armement nominal & AU)
    TC02_RedundancyFault_Ok    : BOOL;          // Statut TC-02 (Contacteur collé)
    TC03_Lockout_Ok            : BOOL;          // Statut TC-03 (Lockout 5s)
    FailedTestCase             : INT;           // Index du scénario en échec
    
    // Signaux de surcharge internes (pilotés par le validateur de test)
    OverrideChainTrue          : BOOL;          // Force la boucle AU à TRUE
    OverrideChainFalse         : BOOL;          // Force la boucle AU à FALSE
    OverrideContactorFalse     : BOOL;          // Force le retour contacteur à FALSE
END_VAR

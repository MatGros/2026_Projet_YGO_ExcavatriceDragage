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
    TC01_NominalArming_Ok      : BOOL;          // ✅ TC-01 : auto-test canaux A/B OK → armement → coupure AU instantanée → latch maintenu tant que non réarmé (AF_Partie-14 §4)
    TC02_RedundancyFault_Ok    : BOOL;          // ✅ TC-02 : contact A resté fermé pendant l'auto-test (soudé/collé) → détection < 200ms + sorties puissance maintenues coupées
    TC03_Lockout_Ok            : BOOL;          // ✅ TC-03 : contacteur sans retour (2s) → lockout 5s strict (réarmements ignorés) → réarmement OK après expiration
    FailedTestCase             : INT;           // Index du scénario en échec
    
    // Signaux de surcharge internes (pilotés par le validateur de test)
    OverrideChainTrue          : BOOL;          // Force la boucle AU à TRUE
    OverrideChainFalse         : BOOL;          // Force la boucle AU à FALSE
    OverrideContactorFalse     : BOOL;          // Force le retour contacteur à FALSE
END_VAR

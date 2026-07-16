(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_PLC_Tests — Programme d'exécution de la suite de tests
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Programme d'accueil unique destiné à être appelé dans le
      gestionnaire de tâches CODESYS. Instancie et appelle le bloc suite.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_PLC_Tests
VAR
    // 🧱 L'instance globale hébergeant la suite de tests
    instTestsSuite : FB_PLC_Tests_Suite;
END_VAR

// === IMPLEMENTATION ===

// Appel unique de la suite de tests
instTestsSuite();

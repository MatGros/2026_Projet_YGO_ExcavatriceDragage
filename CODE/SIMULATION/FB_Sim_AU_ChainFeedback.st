(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_AU_ChainFeedback — Simulation physique boucle AU (banc de test)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v2.0.md
   🧩 Brique réduite (Partie3 §1bis) : outil de banc, pas du métier machine.
   🎯 Rôle : modélise le comportement physique — quand le PLC force
      MaintainA/B à FALSE (auto-test A/B), la boucle AU s'ouvre réellement
      → la sortie ChainClosedRaw repasse à FALSE le cycle suivant (1 cycle
      de retard = fidèle au comportement réel d'un contacteur/relais).
   🔴 Sortie brute (non filtrée) : le conditionnement anti-rebond 20 ms
      est appliqué en aval par FB_Input, pas ici — cette brique ne fait
      QUE la simulation physique, jamais du conditionnement de signal.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_AU_ChainFeedback) ===

FUNCTION_BLOCK PUBLIC FB_Sim_AU_ChainFeedback
VAR_INPUT
    SimulationModeActive : BOOL;   // Bit maître simulation
    SimChainClosed        : BOOL;   // Consigne opérateur banc (Watch)
    MaintainA              : BOOL;   // Sortie physique canal A du scan précédent
    MaintainB              : BOOL;   // Sortie physique canal B du scan précédent
END_VAR
VAR_OUTPUT
    ChainClosedRaw : BOOL;   // Entrée brute simulée, à qualifier par FB_Input en aval
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_AU_ChainFeedback) ===

IF SimulationModeActive AND (NOT MaintainA OR NOT MaintainB) THEN
    // Au moins un canal forcé à FALSE (auto-test) -> la chaîne AU physique s'ouvre
    ChainClosedRaw := FALSE;
ELSE
    // Les deux canaux maintenus -> la chaîne AU suit la consigne opérateur banc
    ChainClosedRaw := SimChainClosed;
END_IF;

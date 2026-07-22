(* ═══════════════════════════════════════════════════════════════
   🧪 ST_TestTranslation — Commandes de test pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné uniquement aux stimulations sur banc de test/simulation.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TestTranslation :
STRUCT
    SensorsWordActive   : BOOL; (* 🔌 Simulation active du mot capteurs *)
    SensorsWord         : BYTE; (* 🔌 Simulation du mot capteurs *)
    AtTremie            : BOOL; (* 🔌 Simulation capteur Trémie *)
    BrakeStuckOpen      : BOOL; (* 🔌 Simulation frein bloqué ouvert *)
    PhantomFreq         : BOOL; (* 🔌 Simulation fréquence fantôme *)
END_STRUCT
END_TYPE

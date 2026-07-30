(* ═══════════════════════════════════════════════════════════════
   📥 PRG_AU_Acquisition — Acquisition et qualification des entrées AU
   ───────────────────────────────────────────────────────────────
   📄 Lit les signaux simulés (GVL_Simulation_AU) ou réels (à connecter
      sur site) et les qualifie avant de les transmettre au composite.
   🧩 Remplit le rôle de PRG_00_Inputs pour le domaine AU uniquement,
      avec les mêmes structures ST_HwMachine (partielle).
   🎯 Pattern : frontière unique HwIn (lot L5 du projet réel).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md
*)

PROGRAM PRG_AU_Acquisition
VAR_OUTPUT
    // 🔌 Signaux qualifiés vers le reste du programme
    EmergencyChainClosed      : BOOL;   // Boucle AU fermée (qualifié)
    PowerContactorEngaged     : BOOL;   // Contacteur puissance engagé (qualifié)
    PowerCutOffRequest        : BOOL;   // Demande coupure safety métier (agrégé)

    // 🚦 État simulation (pour diagnostic)
    SimActive                 : BOOL;
END_VAR
VAR
    // Anti-rebond logiciel (20 ms, comme PRG_00_Inputs)
    TonChainFilter     : TON;
    TonContactorFilter : TON;
END_VAR

// === IMPLEMENTATION ===

// 🔬 Source : simulé ou réel ?
// En test, on lit depuis GVL_Simulation_AU (SimulationModeActive = TRUE par défaut)
SimActive := GVL_Simulation_AU.SimulationModeActive;

// 🎯 Qualification de la boucle AU (anti-rebond 20 ms)
TonChainFilter(IN := GVL_Simulation_AU.SimChainClosed, PT := T#20ms);
EmergencyChainClosed := TonChainFilter.Q;

// 🎯 Qualification retour contacteur (anti-rebond 20 ms)
TonContactorFilter(IN := GVL_Simulation_AU.SimContactorEngaged, PT := T#20ms);
PowerContactorEngaged := TonContactorFilter.Q;

// 🎯 Agrégation coupure métier (simulée ici, proviendrait de PRG_03_Safety en réel)
PowerCutOffRequest := GVL_Simulation_AU.SimPowerCutOffReq;

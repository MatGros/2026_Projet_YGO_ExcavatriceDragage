(* ═══════════════════════════════════════════════════════════════
   📥 PRG_AU_Acquisition — Acquisition et qualification des entrées AU
   ───────────────────────────────────────────────────────────────
   📄 Lit les signaux simulés (GVL_Simulation_AU) ou réels (à connecter
      sur site) et les qualifie avant de les transmettre au composite.
   🧩 Remplit le rôle de PRG_00_Inputs pour le domaine AU uniquement,
      avec les mêmes structures ST_HwMachine (partielle).
   🎯 Pattern : frontière unique HwIn (lot L5 du projet réel).
   🔄 Feedback simulation : modélise le comportement physique —
      quand le PLC force MaintainA/B_RQ à FALSE (auto-test A/B),
      la boucle AU s'ouvre réellement → EmergencyChainClosed repasse
      à FALSE le cycle suivant (1 cycle de retard = acceptable).
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

    // 🔄 Feedback : sorties physiques du scan PRÉCÉDENT
    // (PRG_AU_Acquisition est appelé AVANT PRG_AU_Outputs dans PRG_AU_TestBench,
    //  donc PRG_AU_Outputs.PowerKeepAlive_A/B_RQ sont les valeurs du cycle N-1)
    PrevMaintainA      : BOOL;
    PrevMaintainB      : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 🔬 Source : simulé ou réel ?
SimActive := GVL_Simulation_AU.SimulationModeActive;

// 🎯 Qualification de la boucle AU (anti-rebond 20 ms)
// Si la simulation est active ET que le PLC vient de forcer l'ouverture d'un canal
// (auto-test A/B), la chaîne "physique" s'ouvre → SimChainClosed est ignoré
// et la boucle repasse à FALSE (1 cycle de retard, fidèle au réel).
IF SimActive AND (NOT PrevMaintainA OR NOT PrevMaintainB) THEN
    // Au moins un canal forcé à FALSE → la chaîne AU est ouverte
    TonChainFilter(IN := FALSE, PT := T#20ms);
ELSE
    // Les deux canaux maintenus → la chaîne AU suit SimChainClosed
    TonChainFilter(IN := GVL_Simulation_AU.SimChainClosed, PT := T#20ms);
END_IF;
EmergencyChainClosed := TonChainFilter.Q;

// 🎯 Qualification retour contacteur (anti-rebond 20 ms)
TonContactorFilter(IN := GVL_Simulation_AU.SimContactorEngaged, PT := T#20ms);
PowerContactorEngaged := TonContactorFilter.Q;

// 🎯 Agrégation coupure métier (simulée ici, proviendrait de PRG_03_Safety en réel)
PowerCutOffRequest := GVL_Simulation_AU.SimPowerCutOffReq;

// 📝 Mémorisation pour le prochain cycle (feedback 1 cycle)
PrevMaintainA := PRG_AU_Outputs.PowerKeepAlive_A_RQ;
PrevMaintainB := PRG_AU_Outputs.PowerKeepAlive_B_RQ;

(* ═══════════════════════════════════════════════════════════════
   📥 PRG_AU_Acquisition — Acquisition et qualification des entrées AU
   ───────────────────────────────────────────────────────────────
   📄 Lit les signaux simulés (GVL_Simulation_AU) et les qualifie via
      FB_Input (brique standard §1bis, même composant que PRG_00_Inputs)
      avant de les transmettre au composite.
   🧩 Structure proche cible PRG_ACQUISITION_CFC (AF02 §2) : conditionnement
      2 briques FB_Input + agrégation coupure métier — pas de logique
      métier (règle TC-P02-002, une page CFC ne contient pas d'arbitrage).
   🔄 Feedback simulation : modélise le comportement physique —
      quand le PLC force MaintainA/B_RQ à FALSE (auto-test A/B),
      la boucle AU s'ouvre réellement → EmergencyChainClosed repasse
      à FALSE le cycle suivant (1 cycle de retard = acceptable).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-02_Architecture_Programme_v3.0.md §2
              DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md
*)

PROGRAM PRG_AU_Acquisition
VAR_OUTPUT
    // 🔌 Signaux qualifiés vers le reste du programme
    EmergencyChainClosed      : BOOL;   // Boucle AU fermée (qualifié FB_Input, 20 ms)
    PowerContactorEngaged     : BOOL;   // Contacteur puissance engagé (qualifié FB_Input, 20 ms)
    PowerCutOffRequest        : BOOL;   // Demande coupure safety métier (agrégé)

    // 🚦 État simulation (pour diagnostic)
    SimActive                 : BOOL;
END_VAR
VAR
    // 🔩 Briques standard de conditionnement (mêmes composants que PRG_00_Inputs)
    instEmergencyChainClosed  : FB_Input;
    instPowerContactorEngaged : FB_Input;

    // 🔄 Feedback : sorties physiques du scan PRÉCÉDENT
    // (PRG_AU_Acquisition est appelé AVANT PRG_AU_Outputs_LD dans PRG_AU_TestBench,
    //  donc PRG_AU_Outputs_LD.PowerKeepAlive_A/B_RQ sont les valeurs du cycle N-1)
    PrevMaintainA      : BOOL;
    PrevMaintainB      : BOOL;

    // 🎭 Entrée brute simulée de la boucle AU (avant conditionnement FB_Input)
    RawChainClosed     : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 🔬 Source : simulé (banc de test isolé, toujours simulé ici)
SimActive := GVL_Simulation_AU.SimulationModeActive;

// 🎯 Entrée brute boucle AU : si la simulation vient de forcer l'ouverture d'un
// canal (auto-test A/B, cycle précédent), la chaîne "physique" retombe → 1 cycle
// de retard fidèle au comportement réel d'un contacteur/relais.
IF SimActive AND (NOT PrevMaintainA OR NOT PrevMaintainB) THEN
    RawChainClosed := FALSE;
ELSE
    RawChainClosed := GVL_Simulation_AU.SimChainClosed;
END_IF;

// 🎯 Qualification boucle AU (brique standard, anti-rebond 20 ms)
instEmergencyChainClosed(InputRaw := RawChainClosed, FilterTime := T#20ms);
EmergencyChainClosed := instEmergencyChainClosed.State;

// 🎯 Qualification retour contacteur (brique standard, anti-rebond 20 ms)
instPowerContactorEngaged(InputRaw := GVL_Simulation_AU.SimContactorEngaged, FilterTime := T#20ms);
PowerContactorEngaged := instPowerContactorEngaged.State;

// 🎯 Agrégation coupure métier (simulée ici, proviendrait de PRG_03_Safety en réel)
PowerCutOffRequest := GVL_Simulation_AU.SimPowerCutOffReq;

// 📝 Mémorisation pour le prochain cycle (feedback 1 cycle)
PrevMaintainA := PRG_AU_Outputs_LD.PowerKeepAlive_A_RQ;
PrevMaintainB := PRG_AU_Outputs_LD.PowerKeepAlive_B_RQ;

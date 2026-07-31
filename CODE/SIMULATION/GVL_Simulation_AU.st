(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation_AU — Simulation hardware pour test chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Remplace les signaux physiques réels (DI/Q) pour le test
      en isolation de FB_Safety_EmergencyManagement.
   🎯 Pattern identique à GVL_Simulation (projet réel) :
      domaine SimMachineActive = simulation AU.
      Polarité : TRUE = simulé, FALSE = réel.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-13_Fonction_Simulation_v2.0.md
*)

{attribute 'qualified_only'}
VAR_GLOBAL
    // 🔑 Bit maître — rien n'est simulé si FALSE
    SimulationModeActive : BOOL := TRUE;

    // 🛡️ Simulation du matériel AU
    SimChainClosed       : BOOL := TRUE;   // Simule EmergencyChainClosed_DI fermée
    SimContactorEngaged  : BOOL := FALSE;  // Simule retour contacteur puissance

    // ⚡ Simulation coupure métier (remplace OR des 3 safety domaines)
    SimPowerCutOffReq    : BOOL := FALSE;  // TRUE = une safety demande la coupure
END_VAR

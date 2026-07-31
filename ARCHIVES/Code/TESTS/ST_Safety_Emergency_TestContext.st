(* ═══════════════════════════════════════════════════════════════
   🧪 ST_Safety_Emergency_TestContext — Stimuli de test pour chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Regroupe toutes les commandes de simulation du test bench
      dans une structure typée, conforme au pattern projet
      (ST_ModesCmd, ST_WinchCmd, etc.).
   🎮 Usage : instancié dans PRG_AU_TestBench, piloté depuis
      une table Watch CODESYS ou un visu de test.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-03_Contrats_Composants_v2.0.md
*)

TYPE ST_Safety_Emergency_TestContext :
STRUCT
    // 🎮 Commandes opérateur simulées (miroir de ST_ModesCmd)
    CmdArmRequest     : BOOL;   // Front demande réarmement (comme BtnEmergencyArming IHM)
    CmdReset          : BOOL;   // Front acquittement défauts (comme BtnFaultReset IHM)
    CmdCutOff         : BOOL;   // Coupure IHM maintenue (comme BtnEmergencyCutOff IHM)

    // 🔌 Simulation matériel (remplace les DI physiques)
    SimChainClosed    : BOOL := TRUE;    // Boucle AU fermée (comme EmergencyChainClosed_DI)
    SimContactorEngaged : BOOL;          // Retour contacteur (comme PowerContactorEngaged_DI)
    SimPowerCutOffReq : BOOL;            // Demande coupure safety métier (OR des 3 domaines)
END_STRUCT
END_TYPE

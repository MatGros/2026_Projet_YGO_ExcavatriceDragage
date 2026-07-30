(* ═══════════════════════════════════════════════════════════════
   🖥️ GVL_IHM_AU — Structure IHM pour test chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Réplique les champs de ST_ModesCmd/ST_ModesState nécessaires
      au pilotage de FB_Safety_EmergencyManagement, sans les
      dépendances aux autres domaines (treuils, translation...).
   🎯 Pattern identique à GVL_IHM.Modes.Cmd (projet réel).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-07_Interface_IHM_v2.0.md
*)

{attribute 'qualified_only'}
VAR_GLOBAL
    // 🎮 Commandes IHM (miroir de ST_ModesCmd)
    BtnEmergencyArming   : BOOL;   // Front demande réarmement contacteur
    BtnEmergencyCutOff   : BOOL;   // Niveau coupure IHM maintenue
    BtnFaultReset        : BOOL;   // Front acquittement défauts
END_VAR

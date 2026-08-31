(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_EmergencyHMI — Données d'échange IHM de la chaîne AU / sécurité
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure dédiée `GVL_IHM.Emergency`. Regroupe les
      champs emergency/safety sortis de `Modes`, en réutilisant les DUT
      du refactor AU :
        • Cmd   : ST_EmergencyCmd              (boutons opérateur IHM)
        • State : ST_Safety_Emergency_State    (état public AU)
        • Diag  : ST_Safety_Emergency_Diag     (diagnostic public AU)
      Point de vue IHM : `Cmd` = les boutons. Les commandes physiques
      fail-safe (MaintainA/B_Cmd, ArmPulse_Cmd) sont des sorties du FB
      AU, internes à PRG_06 — PAS des commandes IHM.
   🔌 Interface : Produit par PRG_07_Supervision (State/Diag) et
      l'IHM (Cmd), consommé par PRG_02 / PRG_06 / FB_TroubleshootingView.
   📄 Doc : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md §5
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EmergencyHMI :
STRUCT
    Cmd   : ST_EmergencyCmd;            // 🎮 Boutons opérateur IHM (réarmement / coupure)
    State : ST_Safety_Emergency_State;  // 📊 État public AU (refactor AU)
    Diag  : ST_Safety_Emergency_Diag;   // 🧨 Diagnostic public AU (refactor AU)
END_STRUCT
END_TYPE

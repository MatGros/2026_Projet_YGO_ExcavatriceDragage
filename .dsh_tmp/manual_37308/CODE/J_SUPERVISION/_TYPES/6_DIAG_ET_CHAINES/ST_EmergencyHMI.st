(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_EmergencyHMI — Données d'échange IHM de la chaîne AU / sécurité
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure dédiée `GVL_IHM.Emergency`. Regroupe les
      champs emergency/safety sortis de `Modes`, selon le standard IHM
      projet (Cmd + State [+ Cfg]) :
        • Cmd   : ST_EmergencyCmd              (boutons opérateur IHM)
        • State : ST_EmergencyState            (état AU + cmd FB AU + Diag interne)
      Point de vue IHM : `Cmd` = les boutons. Les commandes physiques
      fail-safe (MaintainA/B_Cmd, ArmPulse_Cmd) sont des sorties du FB
      AU, exposées dans `State` comme states/info. Le diagnostic vit
      dans `State.Diag` (PAS de dossier `Diag` au top).
   🔌 Interface : Produit par PRG_07_Supervision (State) et
      l'IHM (Cmd), consommé par PRG_02 / PRG_06 / FB_TroubleshootingView.
   📄 Doc : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md §5
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EmergencyHMI :
STRUCT
    Cmd   : ST_EmergencyCmd;   // 🎮 Boutons opérateur IHM (réarmement / coupure)
    State : ST_EmergencyState; // 📊 État AU + cmd FB AU + Diag interne
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🎮 ST_EmergencyCmd — Commandes IHM de la chaîne AU / sécurité
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Commandes opérateur (boutons IHM) de la chaîne d'arrêt
      d'urgence, sorties de `Modes.Cmd`. Point de vue IHM : `Cmd` =
      les boutons. Distinctes des commandes physiques fail-safe
      `ST_Safety_Emergency_Cmd` (MaintainA/B_Cmd, ArmPulse_Cmd) qui
      sont des sorties du FB AU, internes à PRG_06 — PAS des commandes
      IHM.
   🔌 Interface : Produit par l'IHM, consommé par PRG_02 / PRG_06 /
      FB_TroubleshootingView.
   📄 Doc : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md §5
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EmergencyCmd :
STRUCT
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)
END_STRUCT
END_TYPE

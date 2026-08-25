(* =======================================================================
   ⚙️ E_Mode — Modes de marche de la machine
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des modes d'exploitation et maintenance
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
   ======================================================================= *)
TYPE E_Mode :
ENUM
    DISABLE     := 0,   (* Mode Désactivé / Veille de sécurité (sorties bloquées) *)
    MAINT_N1    := 1,   (* Manuel Niveau 1 : Pilotage unitaire avec toutes sécurités actives *)
    MAINT_N2    := 2,   (* Manuel Niveau 2 : Pilotage dégradé (droits étendus + bypasses autorisés) *)
    SEMI_AUTO   := 3    (* Mode Semi-Automatique (séquenceur automatique) *)
END_ENUM
END_TYPE

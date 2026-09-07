(* ═══════════════════════════════════════════════════════════════
   🛠️ ST_MaintenanceN2State — État et qualification du forçage MAINT_N2
   ───────────────────────────────────────────────────────────────
   📄 Retours d'état de l'accès et des forçages N2 vers l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_MaintenanceN2State :
STRUCT
    Authorized           : BOOL; (* 🟢 Mode MAINT_N2 actif et mot de passe N2 déverrouillé *)
    ActiveForcing        : BOOL; (* ⚡ Au moins une commande manuelle N2 est active ce cycle *)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🔧 ST_CommunCfg — Configuration des paramètres communs machine
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunCfg :
STRUCT
    LimitLegalDepthMinAllowed_M : REAL; (* 📐 Cote min de dragage autorisée (m, négatif) *)
    LimitLegalEnabled           : BOOL; (* 🟢 Activation de la limite légale *)
    SelHomingApproachEnable     : BOOL; (* 🔌 Case IHM : autorise le dépassement butée haute pour homing (si MAINT_N2) *)
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

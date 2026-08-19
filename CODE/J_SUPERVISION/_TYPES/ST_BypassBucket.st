(* ═══════════════════════════════════════════════════════════════
   ST_BypassBucket — Bypass de la surveillance benne (M2)
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassBucket :
STRUCT
    (* 🛡️ 1. Hiérarchie & Restauration *)
    Global      : BOOL; (* 🌐 Bypass Global : ignore toute surveillance du mécanisme benne *)
    // Flag restauration boot dédié (défaut FALSE non ambigu, contrairement à une valeur métier)
    Initialized : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
END_STRUCT
END_TYPE

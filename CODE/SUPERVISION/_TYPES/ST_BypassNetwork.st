(* ═══════════════════════════════════════════════════════════════
   🌐 ST_BypassNetwork — Bypass général du diagnostic réseau
   ───────────────────────────────────────────────────────────────
   🔒 Permet de forcer les devices réseau (CAN, EtherCAT) à "online"
      pour le diagnostic, sans devoir toucher à chaque bit individuel.
      Jamais actif en production.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassNetwork :
STRUCT
    Global : BOOL; (* 🌐 Force TOUS les devices réseau à Online (TRUE = bypass total) *)
END_STRUCT
END_TYPE

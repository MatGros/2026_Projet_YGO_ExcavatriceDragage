(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassSync — Bypass de la surveillance synchronisation M1/M2
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassSync :
STRUCT
    Global      : BOOL := FALSE; (* 🌐 Bypass GLOBAL synchro : ignore toute erreur de synchronisation *)
    Initialized : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

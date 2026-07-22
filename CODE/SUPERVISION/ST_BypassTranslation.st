(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassTranslation — Bypass maintenance dédiés à Translation M3
   ───────────────────────────────────────────────────────────────
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassTranslation :
STRUCT
    ContactorFeedback : BOOL; (* 🔌 Activation du bypass des retours contacteurs (sens + frein) *)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassCommun — Bypass maintenance de capteurs COMMUNS (partagés)
   ───────────────────────────────────────────────────────────────
   🎨 Regroupe les bypass de capteurs physiquement UNIQUES, partagés
      entre plusieurs axes (ex: mou de câble et position haute = 1 seul
      capteur physique commun M1/M2) — jamais dupliqués par axe.
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassCommun :
STRUCT
    SlackCable        : BOOL; (* ⚠️ Bypass capteur mou de câble (banc de test) — capteur unique M1/M2 *)
    TopPositionSensor : BOOL; (* 📐 Bypass capteur position haute (banc de test) — capteur unique M1/M2 *)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🔧 ST_BypassWinch — Bypass maintenance dédiés à UN treuil (M1 ou M2)
   ───────────────────────────────────────────────────────────────
   🎨 Regroupe les bypass "dégradé assumé" propres à un axe (codeur,
      contacteurs) — chaque treuil a son propre matériel, donc son
      propre struct (imbriqué M1TreuilRetenue.Bypass / M2TreuilBucket.Bypass).
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md).
   ⚠️ Les bypass de capteurs COMMUNS (SlackCable, TopPositionSensor — capteur
      physique unique partagé M1/M2) sont dans ST_CommunHMI.Bypass, PAS ici.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassWinch :
STRUCT
    EncoderFault      : BOOL; (* 🔧 Autorisation maintenue de manœuvre sans codeur, effective uniquement MAINT_N2 *)
    ContactorFeedback : BOOL; (* 🔌 Bypass retours contacteurs (banc de test) *)
END_STRUCT
END_TYPE

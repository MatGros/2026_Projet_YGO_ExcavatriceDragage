(* ═══════════════════════════════════════════════════════════════
   🪣 ST_BucketCmdDemand — Demande de commande benne (depuis cycle/sequenceur)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md (Benne incluse)
   🎯 Demande de mouvement pour benne (depuis FB_Cycle / FB_ExtractionSequence).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketCmdDemand :
STRUCT
    Open               : BOOL;  // Demande ouverture
    Close              : BOOL;  // Demande fermeture
    KoboldContactorCmd : BOOL;  // Commande contacteur puissance Kobold (recherche fond)
END_STRUCT
END_TYPE
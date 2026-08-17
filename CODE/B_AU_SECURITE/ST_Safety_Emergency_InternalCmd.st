(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_Safety_Emergency_InternalCmd — Structure de commande interne
   ───────────────────────────────────────────────────────────────
   📄 Transporte les ordres logiques entre le bloc de décision
      et le bloc de sortie de la boucle d'urgence.
   🔒 Polarité maintien : TRUE = voie maintenue saine, FALSE = coupure demandée
      (conforme règle C1 — polarité explicite).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

TYPE ST_Safety_Emergency_InternalCmd :
STRUCT
    MaintainA_Cmd    : BOOL; // Ordre maintien canal A (TRUE = voie maintenue, FALSE = coupure demandée)
    MaintainB_Cmd    : BOOL; // Ordre maintien canal B (TRUE = voie maintenue, FALSE = coupure demandée)
    ArmPulse_Cmd     : BOOL; // Ordre impulsion de réarmement (TRUE = bobine réarmement activée)
END_STRUCT
END_TYPE

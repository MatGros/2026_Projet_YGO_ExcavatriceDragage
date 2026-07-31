(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_EmergencyChainCmd — Structure de communication interne
   ───────────────────────────────────────────────────────────────
   📄 Transporte les ordres logiques entre le bloc de décision
      et le bloc de commande de la boucle d'urgence.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

TYPE ST_Safety_Emergency_InternalCmd :
STRUCT
    PowerCutOff_A_Cmd   : BOOL; // Ordre logique coupure canal A (TRUE = OK/Maintien, FALSE = Coupure)
    PowerCutOff_B_Cmd   : BOOL; // Ordre logique coupure canal B (TRUE = OK/Maintien, FALSE = Coupure)
    EmergencyArming_Cmd : BOOL; // Ordre logique d'impulsion de réarmement
END_STRUCT
END_TYPE

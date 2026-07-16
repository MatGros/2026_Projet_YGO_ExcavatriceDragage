(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_EmergencyChainCmd — Structure de communication interne
   ───────────────────────────────────────────────────────────────
   📄 Transporte les ordres logiques entre le bloc de décision
      et le bloc de commande de la boucle d'urgence.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_EmergencyManagementCmd :
STRUCT
    PowerCutOff_A_Cmd   : BOOL; // Ordre logique coupure canal A (TRUE = OK/Maintien, FALSE = Coupure)
    PowerCutOff_B_Cmd   : BOOL; // Ordre logique coupure canal B (TRUE = OK/Maintien, FALSE = Coupure)
    EmergencyArming_Cmd : BOOL; // Ordre logique d'impulsion de réarmement
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_EmergencyManagementCmd — Structure de commande interne
   ───────────────────────────────────────────────────────────────
   📄 Transporte les ordres logiques entre le bloc de décision
      et le bloc de sortie de la boucle d'urgence.
   🏷️ Renommé PowerCutOff_X_Cmd → MaintainA/B_Cmd (polarité maintien :
      TRUE = voie maintenue saine, FALSE = coupure demandée — la règle C1
      interdit un nom portant « coupure » quand le sens est « maintien »).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

TYPE ST_EmergencyManagementCmd :
STRUCT
    MaintainA_Cmd    : BOOL; // Ordre maintien canal A (TRUE = voie maintenue, FALSE = coupure demandée)
    MaintainB_Cmd    : BOOL; // Ordre maintien canal B (TRUE = voie maintenue, FALSE = coupure demandée)
    ArmPulse_Cmd     : BOOL; // Ordre impulsion de réarmement (TRUE = bobine réarmement activée)
END_STRUCT
END_TYPE

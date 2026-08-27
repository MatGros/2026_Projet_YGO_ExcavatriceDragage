(* =======================================================================
   ⚙️ ST_Safety_Emergency_InternalCmd — Structure de commande interne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Transporte les ordres logiques entre le bloc de décision et de sortie AU
   🔒 Polarité : MaintainA/B_Cmd en maintien (TRUE = voie saine)
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_InternalCmd :
STRUCT
    MaintainA_Cmd    : BOOL; // Ordre maintien canal A (TRUE = voie maintenue, FALSE = coupure demandee)
    MaintainB_Cmd    : BOOL; // Ordre maintien canal B (TRUE = voie maintenue, FALSE = coupure demandee)
    ArmPulse_Cmd     : BOOL; // Ordre impulsion de rearmement (TRUE = bobine rearmement activee)
END_STRUCT
END_TYPE

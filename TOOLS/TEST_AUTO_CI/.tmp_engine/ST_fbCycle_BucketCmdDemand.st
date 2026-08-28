(* =======================================================================
   🪣 ST_fbCycle_BucketCmdDemand — Demande de commande benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de consigne de mouvement benne (Ouverture, Fermeture, Kobold)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbCycle_BucketCmdDemand :
STRUCT
    Open               : BOOL;                                        // Demande ouverture benne
    Close              : BOOL;                                        // Demande fermeture benne
    KoboldContactorCmd : BOOL;                                        // Commande contacteur puissance Kobold (recherche fond)
END_STRUCT
END_TYPE
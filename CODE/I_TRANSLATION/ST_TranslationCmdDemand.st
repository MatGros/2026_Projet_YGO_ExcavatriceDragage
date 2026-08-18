(* =======================================================================
   🎯 ST_TranslationCmdDemand — Demande de commande translation M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupement des consignes de mouvement translation M3
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
   ======================================================================= *)
TYPE ST_TranslationCmdDemand :
STRUCT
    Start   : BOOL;  // --> [CMD] Demande de demarrage du mouvement
    Target  : INT;   // --> [CMD] Cible de position (1=Tremie, 2=P2, 3=P1, 4=Maintenance)
END_STRUCT
END_TYPE

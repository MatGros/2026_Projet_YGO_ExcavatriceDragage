(* =======================================================================
   🔌 ST_fbCycle_WinchCmdDemand — Structure de demande de commande treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupement des consignes de mouvement treuil (StartStop, Direction, Vitesse)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbCycle_WinchCmdDemand :
STRUCT
    StartStop : BOOL;                                                 // Ordre marche/arret mouvement (TRUE=Marche)
    Direction : INT;                                                  // Sens de marche (-1: Descente, 0: Stop, 1: Montee)
    SpeedPct  : REAL;                                                 // Consigne vitesse (0.0 a 100.0 %)
END_STRUCT
END_TYPE
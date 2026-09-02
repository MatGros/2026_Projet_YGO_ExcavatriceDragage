(* =======================================================================
   💾 ST_fbWinchSpeedLearning_Cell — Cellule de vitesse apprise
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Cellule unitaire de la table d'apprentissage vitesse par palier
   📄 Doc metier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbWinchSpeedLearning_Cell :
STRUCT
    Valid       : BOOL;    // Cellule validee (vitesse apprise exploitable)
    SpeedMps    : REAL;    // Vitesse apprise (m/s)
    SampleCount : UDINT;   // Compteur d'echantillons collectes
END_STRUCT
END_TYPE

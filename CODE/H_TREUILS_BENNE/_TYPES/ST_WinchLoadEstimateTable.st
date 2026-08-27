(* =======================================================================
   📊 ST_WinchLoadEstimateTable — Table empirique de charge estimée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Matrice 5x5 d'estimation de charge (palier commandé x bande vitesse)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_WinchLoadEstimateTable :
STRUCT
    IsConfigured              : BOOL;                                 // Validation explicite de la table
    LoadPctByStepAndSpeedBand : ARRAY[1..5] OF ARRAY[1..5] OF REAL;  // Matrice [palier][bande_vitesse] charge (%)
END_STRUCT
END_TYPE

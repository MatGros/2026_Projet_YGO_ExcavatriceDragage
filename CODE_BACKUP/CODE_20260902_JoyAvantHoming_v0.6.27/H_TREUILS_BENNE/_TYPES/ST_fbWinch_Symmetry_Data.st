(* =======================================================================
   📊 ST_fbWinch_Symmetry_Data — Données mesurées de symétrie M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure des résultats de mesures et d'écarts du diagnostic symétrie
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbWinch_Symmetry_Data :
STRUCT
    DeltaStartDelay_Ms       : UDINT;                                 // Ecart mesure au demarrage (ms)
    DeltaBrakeReleaseTime_Ms : UDINT;                                 // Ecart mesure temps desserrage frein (ms)
    DeltaBrakeApplyTime_Ms   : UDINT;                                 // Ecart mesure temps serrage frein (ms)
    DeltaStopDistance_Mm     : UDINT;                                 // Ecart mesure distance d'arret (mm)
    DeltaStopTime_Ms         : UDINT;                                 // Ecart mesure temps d'arret (ms)
    MaxSyncDeviation_M       : REAL;                                  // Ecart maximal de synchronisme enregistre (m)
END_STRUCT
END_TYPE

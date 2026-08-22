(* =======================================================================
   ⚖️ ST_Winch_SymmetryCfg — Configuration des seuils de symétrie M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Seuils de tolérance pour le diagnostic passif de symétrie treuils
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   ======================================================================= *)
TYPE ST_Winch_SymmetryCfg :
STRUCT
    DeltaStartDelay_Ms       : UDINT := 100;                          // Ecart max tolere au demarrage (ms)
    DeltaBrakeReleaseTime_Ms : UDINT := 100;                          // Ecart max temps desserrage frein (ms)
    DeltaBrakeApplyTime_Ms   : UDINT := 100;                          // Ecart max temps serrage frein (ms)
    DeltaStopDistance_Mm     : UDINT := 100;                          // Ecart max distance d'arret (mm)
    DeltaStopTime_Ms         : UDINT := 200;                          // Ecart max temps d'arret (ms)
    MinimumCommandTime_Ms    : UDINT := 1000;                         // Duree minimale de commande pour qualification (ms)
    MinimumSpeed_Mps         : REAL  := 0.05;                         // Vitesse minimale pour qualification (m/s)
END_STRUCT
END_TYPE

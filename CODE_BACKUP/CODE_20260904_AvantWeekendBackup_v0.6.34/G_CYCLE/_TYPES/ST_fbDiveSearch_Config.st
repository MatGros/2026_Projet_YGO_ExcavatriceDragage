(* =======================================================================
   ST_fbDiveSearch_Config - Reglages du cycle de recherche du fond
   ======================================================================= *)
TYPE ST_fbDiveSearch_Config :
STRUCT
    DiveSpeedMin_Mps       : REAL := 0.15;   // Vitesse minimale de calcul du timeout (m/s)
    TimeoutMarginFactor    : REAL := 1.5;    // Marge appliquee au temps theorique
    TimeoutMinCourse_M     : REAL := 1.0;    // Course minimale prise en compte (m)
    TimeoutMaxCourse_M     : REAL := 200.0;  // Course maximale prise en compte (m)
    SecToMs                : REAL := 1000.0; // Conversion secondes vers millisecondes
END_STRUCT
END_TYPE

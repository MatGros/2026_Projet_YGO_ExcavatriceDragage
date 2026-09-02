(* =======================================================================
   ⚙️ ST_fbWinchSpeedLearning_Cfg — Enveloppes de plausibilite par palier
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Bornes min/max de vitesse apprise par palier + seuil d'echantillons
   📄 Doc metier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbWinchSpeedLearning_Cfg :
STRUCT
    MinSpeedMps : ARRAY[1..5] OF REAL;   // Borne min vitesse apprise par palier (m/s)
    MaxSpeedMps : ARRAY[1..5] OF REAL;   // Borne max vitesse apprise par palier (m/s)
    MinSamples  : UDINT;                 // Nb min d'echantillons pour valider une cellule
END_STRUCT
END_TYPE

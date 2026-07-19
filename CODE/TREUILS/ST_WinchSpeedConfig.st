(* ═══════════════════════════════════════════════════════════════════════════════
   🪜 ST_WinchSpeedConfig — Plages de vitesse linéaire mesurée des 5 paliers
   ═══════════════════════════════════════════════════════════════════════════════
   🎯 Configuration de caractérisation, séparée de ST_SpeedStepTable :
      - ST_SpeedStepTable = contacteurs commandés par palier (% vitesse)
      - ST_WinchSpeedConfig = vitesse câble réellement mesurée (m/s)
   ⚠️ Valeurs initiales provisoires : vitesse maximale terrain encore à confirmer.
      Aucun garde-fou ni calcul de charge ne consomme cette structure dans T45.
   ═══════════════════════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-09_Fonction_Winch_v1.11.md
*)

TYPE ST_WinchSpeedConfig :
STRUCT
    MaxMeasuredSpeedMps      : REAL;                    // Vitesse maximale mesurée de référence
    SpeedBandMaxMps          : ARRAY[1..5] OF REAL;    // Plafond vitesse mesurée de chaque palier
    SpeedBandHysteresisMps   : REAL;                    // Hystérésis de classement (m/s)
END_STRUCT
END_TYPE

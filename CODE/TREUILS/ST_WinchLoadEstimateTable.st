(* ═══════════════════════════════════════════════════════════════════════════════
   📊 ST_WinchLoadEstimateTable — Table empirique charge estimée
   ═══════════════════════════════════════════════════════════════════════════════
   ⚠️ Valeur informative uniquement : ce tableau ne remplace pas une mesure de
      charge certifiée et ne participe à aucune fonction de sécurité.
   🧭 Index 1 : palier contacteurs commandé (1..5)
   🧭 Index 2 : bande de vitesse câble mesurée (1..5)
   📐 Valeur : estimation charge en pourcentage (0..100 %), réglée sur site.
   ═══════════════════════════════════════════════════════════════════════════════ *)

TYPE ST_WinchLoadEstimateTable :
STRUCT
    IsConfigured                  : BOOL;
    LoadPctByStepAndSpeedBand     : ARRAY[1..5, 1..5] OF REAL;
END_STRUCT
END_TYPE

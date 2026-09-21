(* =======================================================================
   ⚙️ ST_fbMachineHomingCycle_Cfg — Réglages de FB_CycleMachineHoming
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : Réglages géométriques du référencement machine (cible haute
             M2/benne + écarts benne) + temporisations de garde du GRAFCET
             de homing (montée, homing axes).
   🔒 Ownership : produit par PRG_02_Acquisition depuis _WinchM2CfgPersist
             (cible haute) et _BucketCfgPersist (écarts, GVL_PERSISTENT).
             Initialized : drapeau de restauration boot (pont persistant).
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE ST_fbMachineHomingCycle_Cfg :
STRUCT
    CfgTopHomingTarget_M : REAL;           // Position capteur haut M2/benne (m) — sert UNIQUEMENT a la cible dynamique M2 du cycle (HX3)
    CfgOffsetOpen_M      : REAL;           // Ecart géométrique benne ouverte (m)
    CfgOffsetClose_M     : REAL;           // Ecart géométrique benne fermée (m)
    // Garde de montee : budget d'une MONTER CONTINUE (un temporisateur remet son temps ecoule a
    // zero des que la commande retombe : une pause operateur ou un arret d'urgence ne consomme
    // donc rien). Derivation : course maximale de cable = CfgTopSensorPos_M - CfgCableLimitDescent_M
    // (8,5 m - (-50 m) = 58,5 m) ; borne haute de vitesse du palier 1 = 0,4 m/s
    // (GVL_PERSISTENT._WinchSpeedConfig.SpeedBandMaxMps[1], valeur de banc A MESURER sur site)
    // => 58,5 / 0,4 = 146,3 s ; marge x2 = 292,5 s ; valeur retenue 300 s (arrondie au-dessus).
    // A revoir si la course ou la vitesse du palier 1 changent (gate G511).
    CfgTimeoutClimb      : TIME := T#300s; // Garde de montee au capteur haut (0 = pas de garde)
    // Garde de descente HX3 : meme regle (budget de DESCENTE CONTINUE).
    CfgTimeoutHomeAxes   : TIME := T#60s;  // Garde de descente jusqu'au front descendant capteur (0 = pas de garde)
    CfgStabilizationMinM : REAL := 7.50;   // Seuil bas d'inertie stabilisée après référence (m) - HX4 (constante volontaire, valeur a risque, pas d'IHM)
    CfgStabilizationMaxM : REAL := 9.50;   // Seuil haut d'inertie stabilisée après référence (m) - HX4 (constante volontaire, valeur a risque, pas d'IHM)
    Initialized          : BOOL := FALSE;  // Drapeau de restauration config au boot (pont persistant)
END_STRUCT
END_TYPE

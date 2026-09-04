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
    CfgTimeoutClimb      : TIME := T#120s; // Garde HX2 : montée au capteur haut (0 = pas de garde)
    CfgTimeoutHomeAxes   : TIME := T#60s;  // Garde HX3 : descente jusqu'au front descendant capteur (0 = pas de garde)
    Initialized          : BOOL := FALSE;  // Drapeau de restauration config au boot (pont persistant)
END_STRUCT
END_TYPE

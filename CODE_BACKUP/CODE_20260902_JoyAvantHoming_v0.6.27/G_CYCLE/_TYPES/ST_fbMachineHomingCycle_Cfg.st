(* =======================================================================
   ⚙️ ST_fbMachineHomingCycle_Cfg — Réglages de FB_MachineHomingCycle
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les réglages géométriques du référencement machine
             (cible haute M1 + écarts benne ouverte/fermée).
   🔒 Ownership : produit par le call-site PRG_02_Acquisition depuis
             _WinchM1CfgPersist et _BucketCfgPersist (GVL_PERSISTENT).
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE ST_fbMachineHomingCycle_Cfg :
STRUCT
    CfgTopHomingTarget_M : REAL;   // Cible haute configurée M1 (m)
    CfgOffsetOpen_M      : REAL;   // Ecart géométrique benne ouverte (m)
    CfgOffsetClose_M     : REAL;   // Ecart géométrique benne fermée (m)
END_STRUCT
END_TYPE

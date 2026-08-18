(* ═══════════════════════════════════════════════════════════════
   ST_CycleCfg — Configuration du cycle semi-automatique
   T66 : SetDepth_M/SetOffset_M protégés par persistance GVL_PERSISTENT (voir PRG_SUPERVISION_CFC.st §2/§3)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M  : REAL := -12.5; (* 📐 Profondeur de dragage cible (m, négative) *)
    SetOffset_M : REAL := 1.5;   (* 📐 Décalage cible de fermeture de la benne (m) *)
    Initialized : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

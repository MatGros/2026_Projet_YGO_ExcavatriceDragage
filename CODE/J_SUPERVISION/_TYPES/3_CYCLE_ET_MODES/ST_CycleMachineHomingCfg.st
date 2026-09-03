(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_CycleMachineHomingCfg — Réglages IHM du cycle de référencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Mise en service. Les réglages géométriques (positions capteur, offsets benne)
      restent portés par GVL_PERSISTENT (_WinchM1CfgPersist / _BucketCfgPersist).
   💾 Ponté vers persist (_CycleMachineHomingCfgPersist) via FB_CfgPersistBridge_CycleMachineHomingCfg.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleMachineHomingCfg :
STRUCT
    ForceStepTarget : INT  := 0;     (* 🔧 Step GRAFCET cible du forçage (0=HX0 .. 9=HXF), borné côté FB *)
    Initialized     : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

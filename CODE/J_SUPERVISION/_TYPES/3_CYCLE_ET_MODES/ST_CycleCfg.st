(* ═══════════════════════════════════════════════════════════════
   ST_CycleCfg — Configuration du cycle semi-automatique
   SetDepth_M et DepthStopMode protégés par persistance GVL_PERSISTENT
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M         : REAL := -20.0; (* 📐 Profondeur de dragage cible (m, négative) *)
    DepthStopMode      : E_CycleDepthStopMode := E_CycleDepthStopMode.KOBOLD_OR_SETPOINT; (* 🧭 Source arrêt AX7 *)
    DrainTime          : TIME := T#5s;  (* ⏱️ Durée d'égouttage du godet en AX13 (configurable IHM) *)
    RaiseOffBottom_M   : REAL := 0.0;   (* 📐 0 = compensation interne par défaut pour le décollement AX8 *)
    CtrlAscentMaxStep  : INT  := 2;     (* 🚀 Palier max montée contrôle AX11, borné [1..2] côté FB (GEL Q16) *)
    ForceStepTarget    : INT  := 0;     (* 🔧 Step GRAFCET cible du forçage (0=AX0 .. 20=AX_DIVING_RETRY), borné côté FB *)
    DiveStartMin_M     : REAL := 4.0;   (* 📐 Altimétrie lancement Kobold (AT4, PRG_03) *)
    ImmersionUpper_M   : REAL := 0.5;   (* 📐 Altimétrie Kobold haute confirmation immersion (AT4, PRG_04) *)
    ImmersionLower_M   : REAL := -0.5;  (* 📐 Altimétrie Kobold basse confirmation immersion (AT4, PRG_04) *)
    ExtractionControlDistance_M : REAL := 0.0; (* 📐 0 = bypass AX11, enchaînement direct AX10→AX12 *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

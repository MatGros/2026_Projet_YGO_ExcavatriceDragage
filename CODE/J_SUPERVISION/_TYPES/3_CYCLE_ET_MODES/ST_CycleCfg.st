(* ═══════════════════════════════════════════════════════════════
   ST_CycleCfg — Configuration du cycle semi-automatique
   SetDepth_M/SetOffset_M protégés par persistance GVL_PERSISTENT
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M         : REAL := -12.5; (* 📐 Profondeur de dragage cible (m, négative) *)
    SetOffset_M        : REAL := 1.5;   (* 📐 Décalage cible de fermeture de la benne (m) *)
    DrainTime          : TIME := T#5s;  (* ⏱️ Durée d'égouttage du godet en AX13 (configurable IHM) *)
    RaiseOffBottom_M   : REAL := 0.5;   (* 📐 Décollement du fond en AX8 : RaiseTarget = TouchPosition + ce champ (réglable essais, GEL Q16) *)
    CtrlAscentMaxStep  : INT  := 1;     (* 🚀 Palier max montée contrôle AX11, borné [1..2] côté FB (GEL Q16) *)
    ForceStepTarget    : INT  := 0;     (* 🔧 Step GRAFCET cible du forçage (0=AX0 .. 20=AX_DIVING_RETRY), borné côté FB *)
    DiveStartMin_M     : REAL := 1.0;   (* 📐 Altimétrie lancement Kobold (AT4, PRG_03) *)
    ImmersionUpper_M   : REAL := 0.5;   (* 📐 Altimétrie Kobold haute confirmation immersion (AT4, PRG_04) *)
    ImmersionLower_M   : REAL := -0.5;  (* 📐 Altimétrie Kobold basse confirmation immersion (AT4, PRG_04) *)
    ExtractionControlDistance_M : REAL := 2.0; (* 📐 Distance palier contrôle montée assistée (PRG_04) *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

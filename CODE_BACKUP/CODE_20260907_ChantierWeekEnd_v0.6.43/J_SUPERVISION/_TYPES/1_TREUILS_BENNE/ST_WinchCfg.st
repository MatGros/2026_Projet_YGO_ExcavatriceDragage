(* ═══════════════════════════════════════════════════════════════
   ST_WinchCfg — Configurations et paramètres réglables pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au paramétrage et calibration depuis l'IHM (RETAIN).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;      (* 📐 Position cible du capteur haut (m) *)
    CfgHomingTarget_M       : REAL := 0.0;      (* Cible libre Homing unitaire MAINT_N2 [-99..+99 m] *)
    CfgRampAccelRate        : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    CfgRampDecelNormalRate  : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    CfgRampDecelFastRate    : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CfgCableLimitDescent_M  : REAL := -50.0;    (* 📐 Limite basse physique de descente (m, négatif) *)

    (* 🚦 Flag restauration boot — défaut FALSE non ambigu *)
    Initialized              : BOOL := FALSE;    (* 🚦 TRUE = config restaurée depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE

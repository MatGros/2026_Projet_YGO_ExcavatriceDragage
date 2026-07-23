(* ═══════════════════════════════════════════════════════════════
   🔧 ST_WinchCfg — Configurations et paramètres réglables pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au paramétrage et calibration depuis l'IHM (RETAIN).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;      (* 📐 Position cible du capteur haut (m) *)
    CfgHomingTarget_M       : REAL := 0.0;      (* 🔧 Cible libre Homing unitaire MAINT_N2 [-99..+99 m] *)
    CfgMaxStepDescente      : INT := 3;         (* 🛑 Limitation palier vitesse en descente (1..5) *)
    CfgMaxStepAscent        : INT := 5;         (* 🚀 Limitation palier vitesse en montée (1..5) *)
    CfgRampAccelRate        : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    CfgRampDecelNormalRate  : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    CfgRampDecelFastRate    : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CfgCableLimitDescent_M  : REAL := -20.0;    (* 📐 Limite basse physique de descente (m, négatif) *)
    CfgCableLimitAscent_M   : REAL := 8.0;      (* 📐 Limite haute d'exploitation NORMALE (m) *)
    CfgSlowdownDistance_M   : REAL := 1.0;      (* 📏 Distance avant limite pour enclencher le ralentissement (m) *)
    CfgSlowSpeed_Pct         : REAL := 15.0;     (* 📉 Vitesse de consigne lente dans la zone de ralentissement (%) *)

    (* 🐛 FIX 2026-07-23 : flag restauration boot (défaut FALSE non ambigu, contrairement à un champ
       métier dont le défaut peut valoir n'importe quoi) — PRG_09_Supervision.st §2/§3 *)
    Initialized              : BOOL := FALSE;    (* 🚦 TRUE = config restaurée depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🔧 ST_WinchCfg — Configurations et paramètres réglables pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au paramétrage et calibration depuis l'IHM (RETAIN).
   📄 2026-07-24 : CfgMaxStepDescente/CfgMaxStepAscent/CfgSlowdownDistance_M/CfgSlowSpeed_Pct
   déplacés vers GVL_IHM.Commun.Cfg (WinchMaxStepDescente/etc.) — étaient partagés M1/M2 via
   réconciliation ad-hoc, une seule instance dans Commun élimine le besoin de réconciliation.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCfg :
STRUCT
    CfgTopSensorPos_M       : REAL := 8.5;      (* 📐 Position cible du capteur haut (m) *)
    CfgHomingTarget_M       : REAL := 0.0;      (* 🔧 Cible libre Homing unitaire MAINT_N2 [-99..+99 m] *)
    CfgRampAccelRate        : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    CfgRampDecelNormalRate  : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    CfgRampDecelFastRate    : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CfgCableLimitDescent_M  : REAL := -20.0;    (* 📐 Limite basse physique de descente (m, négatif) *)
    CfgCableLimitAscent_M   : REAL := 6.75;      (* 📐 Limite haute d'exploitation NORMALE (m) -- REX 2026-08-07 (25), aligné sur GVL_PERSISTENT *)

    (* 🐛 FIX 2026-07-23 : flag restauration boot (défaut FALSE non ambigu, contrairement à un champ
       métier dont le défaut peut valoir n'importe quoi) — PRG_SUPERVISION_CFC.st §2/§3 *)
    Initialized              : BOOL := FALSE;    (* 🚦 TRUE = config restaurée depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE

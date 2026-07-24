(* ═══════════════════════════════════════════════════════════════
   🔧 ST_CommunCfg — Configuration des paramètres communs machine
   📄 2026-07-24 : WinchMaxStepDescente/WinchMaxStepAscent/WinchSlowdownDistance_M/
   WinchSlowSpeed_Pct rapatriés depuis ST_WinchCfg (étaient partagés M1/M2 par réconciliation
   ad-hoc dans PRG_09_Supervision.st, une seule instance ici l'élimine).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunCfg :
STRUCT
    LimitLegalDepthMinAllowed_M : REAL; (* 📐 Cote min de dragage autorisée (m, négatif) *)
    LimitLegalEnabled           : BOOL; (* 🟢 Activation de la limite légale *)
    SelHomingApproachEnable     : BOOL; (* 🔌 Case IHM : autorise le dépassement butée haute pour homing (si MAINT_N2) *)
    WinchMaxStepDescente        : INT := 3;     (* 🛑 Limitation palier vitesse en descente (1..5), commun M1/M2 *)
    WinchMaxStepAscent          : INT := 5;     (* 🚀 Limitation palier vitesse en montée (1..5), commun M1/M2 *)
    WinchSlowdownDistance_M     : REAL := 1.0;  (* 📏 Distance avant limite pour enclencher le ralentissement (m), commun M1/M2 *)
    WinchSlowSpeed_Pct          : REAL := 15.0; (* 📉 Vitesse de consigne lente dans la zone de ralentissement (%), commun M1/M2 *)
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE

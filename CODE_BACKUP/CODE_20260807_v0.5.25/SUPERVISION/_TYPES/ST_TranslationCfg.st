(* ═══════════════════════════════════════════════════════════════
   🔧 ST_TranslationCfg — Configurations et paramètres réglables pour Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au paramétrage depuis l'IHM (RETAIN) — même patron que ST_WinchCfg.
   📄 2026-08-06 : créé suite constat terrain — Translation n'avait pas de slot Cfg
   (contrairement à ST_WinchHMI), les 3 vitesses de ralentissement d'approche
   n'étaient donc réglables qu'en dur dans GVL_PERSISTENT (recompilation requise).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCfg :
STRUCT
    CfgApproachSpeedTremie_Hz      : REAL := 10.0; (* 🐢 Vitesse réduite d'approche Trémie (Hz), déclenchée par capteur PV, Direction=1 *)
    CfgApproachSpeedMaintenance_Hz : REAL := 10.0; (* 🐢 Vitesse réduite d'approche Maintenance (Hz), déclenchée par capteur P1, Direction=-1 *)
    CfgApproachSpeedP1_Hz          : REAL := 10.0; (* 🐢 Vitesse réduite d'approche P1 (Hz), déclenchée par capteur P2, Direction=-1 *)

    (* 🐛 Flag restauration boot (défaut FALSE non ambigu) — même patron que ST_WinchCfg *)
    Initialized                    : BOOL := FALSE; (* 🚦 TRUE = config restaurée depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE

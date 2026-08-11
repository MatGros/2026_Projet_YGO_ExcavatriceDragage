(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleCmd — Commandes IHM pour le cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCmd :
STRUCT
    BtnStart : BOOL; (* ▶️ Lancement cycle automatique *)
    BtnPause : BOOL; (* ⏸️ Pause cycle automatique *)
    BtnAbort : BOOL; (* ⏹️ Abandon / arrêt cycle automatique *)
    BtnReset : BOOL; (* 🔁 Reset dédié FB_Cycle, jamais mélangé au reset défauts général (REX 2026-07-07) *)
END_STRUCT
END_TYPE

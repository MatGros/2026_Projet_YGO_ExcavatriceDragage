(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleCmd — Commandes IHM pour le cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCmd :
STRUCT
    BtnStart : BOOL; (* ▶️ Lancement cycle automatique *)
    BtnPause : BOOL; (* ⏸️ Pause cycle automatique *)
    BtnAbort : BOOL; (* ⏹️ Abandon / arrêt cycle automatique *)
    BtnReset : BOOL; (* 🔁 Reset dédié FB_Cycle, jamais mélangé au reset défauts général () *)
    BtnSkipDrain : BOOL; (* ⏭️ Passer l'étape d'égouttage X9 (front) *)
    BtnReposition : BOOL; (* ⬇️ Option maintenue : repositionnement couplé M1+M2 pendant le vidage trémie (X11b <-> X11c) *)
END_STRUCT
END_TYPE

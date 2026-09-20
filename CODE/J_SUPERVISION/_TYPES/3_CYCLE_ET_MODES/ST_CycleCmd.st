(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleCmd — Commandes IHM pour le cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCmd :
STRUCT
    BtnStart          : BOOL; (* ▶️ Lancement cycle automatique *)
    BtnPause          : BOOL; (* ⏸️ Pause cycle automatique *)
    BtnAbort          : BOOL; (* ⏹️ Abandon / arrêt cycle automatique *)
    BtnResumeAfterFault : BOOL; (* Reprise consciente depuis AX_STAB vers l'etape d'origine *)
    BtnReset          : BOOL; (* 🔁 Reset dédié FB_Cycle, jamais mélangé au reset défauts général () *)
    BtnSkipDrain      : BOOL; (* ⏭️ Passer l'étape d'égouttage X9 (front) *)
    BtnReposition     : BOOL; (* ⬇️ Option maintenue : repositionnement couplé M1+M2 pendant le vidage trémie (X11b <-> X11c) *)
    TglCommissioning  : BOOL := FALSE; (* 🔧 Case mise en service : déverrouille le forçage de step (front/impulsion). NON persisté. *)
    TglCycleChecksInhibit : BOOL := FALSE; (* 🧪 Mode essai : inhibe uniquement les controles procede autorises. NON persiste. *)
    TglAutoDiveM2Step5Trial : BOOL := FALSE; (* Essai T291-A : en SEMI_AUTO AX4..AX7, M1 reste palier 4 et M2 peut monter au palier 5. NON persiste. *)
    BtnForceStepApply : BOOL; (* 🔧 Applique le forçage de step (front) — impulsion ; cible = ST_CycleCfg.ForceStepTarget *)
    BtnResetSampleCount : BOOL; (* 🔢 RAZ consciente du compteur JOURNALIER de prélèvements (front) — n'agit JAMAIS sur le totalisateur, qui n'a aucune commande *)
END_STRUCT
END_TYPE

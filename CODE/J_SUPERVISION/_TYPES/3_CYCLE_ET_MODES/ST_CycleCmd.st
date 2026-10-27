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
    TglAutoDiveM2Step5Trial : BOOL := TRUE; (* Profil nominal : en SEMI_AUTO AX4..AX7, M1 reste palier 4 et M2 peut monter au palier 5. Debrayable IHM, non persiste. *)
    BtnResetSampleCount : BOOL; (* 🔢 RAZ consciente du compteur JOURNALIER de prélèvements (front) — n'agit JAMAIS sur le totalisateur, qui n'a aucune commande *)
    // ⚠️ AJOUT EN FIN DE STRUCT (mapping positionnel : jamais d'insertion au milieu).
    // 🔧 T358 : consigne de forcage de step — VALEUR écrite par l'opérateur, lue ET
    //    acquittee par FB_CycleSemiAuto (retour à la sentinelle -1). Remplace le couple
    //    BtnForceStepApply + ST_CycleCfg.ForceStepTarget : plus de bouton, plus de
    //    confirmation, plus de cible persistée (donc aucun saut d'étape au démarrage).
    //    Zone Cmd = NON persistée : la consigne ne survit jamais à une coupure.
    //    -1 = aucune demande ; 0..22 = étape cible (plage E_AutoCycleStep).
    SetForceStepTgt : INT := -1; (* 🔧 Étape cible du forçage immédiat du cycle ; -1 = aucune demande *)
END_STRUCT
END_TYPE

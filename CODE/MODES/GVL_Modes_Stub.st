(* ═══════════════════════════════════════════════════════════════
   🎚️ GVL_Modes_Stub — Variables IHM pour FB_Modes
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-05_Modes_Maintenance_v1.6.md §1/§2
   🎯 Sélecteur de mode machine forceable : un seul endroit à consulter/forcer
      en mise en service pour piloter le mode.
   🔧 REX 2026-07-07 (1) : GVL_Encoder_Stub (même principe, codeurs) a été fusionné
      dans GVL_IHM.M1TreuilRetenue/M2 (BtnHome/BtnConfirmCoherence) — plus de référence utile.
   🔧 REX 2026-07-07 (2) : PasswordOk_IHM retiré — accès MAINT_N2 filtré uniquement côté
      IHM (visibilité des actions selon niveau utilisateur), plus de garde-fou FB_Modes.
   🔴 TOUJOURS STUB (pas de vrai sélecteur/lecteur de badge IHM câblé) : forcer
      directement en vue instance CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Modes_Stub) ===

VAR_GLOBAL
    // 🎚️ Sélecteur mode machine — forcer directement pour tester MANUEL/MAINT_N1/MAINT_N2/SEMI_AUTO
    ModeRequest_IHM         : E_Mode := E_Mode.MAINT_N1;

    // ☑️ REX 2026-07-08 : logique inversée (positive) — coché = synchro M1/M2 ACTIVE (FB_WinchSync).
    // Effectif uniquement en MAINT_N1/N2 (arbitré par FB_Modes.SyncEnable, voir Partie5 §2).
    SyncEnableRequest_IHM   : BOOL := TRUE;
END_VAR

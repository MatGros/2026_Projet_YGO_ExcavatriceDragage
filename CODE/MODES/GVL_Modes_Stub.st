(* ═══════════════════════════════════════════════════════════════
   🎚️ GVL_Modes_Stub — Variables IHM pour FB_Modes
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.2.md §1/§2
   🎯 Sélecteur de mode machine forceable : un seul endroit à consulter/forcer
      en mise en service pour piloter le mode.
   🔧 REX 2026-07-07 (1) : GVL_Encoder_Stub (même principe, codeurs) a été fusionné
      dans GVL_IHM.WinchM1/M2 (CmdHome/ConfirmCoherence) — plus de référence utile.
   🔧 REX 2026-07-07 (2) : PasswordOk_IHM retiré — accès MAINT_N2 filtré uniquement côté
      IHM (visibilité des actions selon niveau utilisateur), plus de garde-fou FB_Modes.
   🔴 TOUJOURS STUB (pas de vrai sélecteur/lecteur de badge IHM câblé) : forcer
      directement en vue instance CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Modes_Stub) ===

VAR_GLOBAL
    // 🎚️ Sélecteur mode machine — forcer directement pour tester MANUEL/MAINT_N1/MAINT_N2/SEMI_AUTO
    ModeRequest_IHM         : E_Mode := E_Mode.MAINT_N1;

    // ☑️ Case à cocher opérateur — désactive la synchro M1/M2 (FB_WinchSync), UNIQUEMENT actif
    // si Mode=MAINT_N2 (arbitré par FB_Modes.OverrideSync, voir Partie5 §2 "Logique d'override")
    OverrideSyncRequest_IHM : BOOL := FALSE;
END_VAR

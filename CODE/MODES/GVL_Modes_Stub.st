(* ═══════════════════════════════════════════════════════════════
   🎚️ GVL_Modes_Stub — Variables IHM pour FB_Modes
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.2.md §1/§2
   🎯 Sélecteur de mode machine forceable (même principe que GVL_Encoder_Stub) :
      un seul endroit à consulter/forcer en mise en service pour piloter le mode.
   🔴 TOUJOURS STUB (pas de vrai sélecteur/lecteur de badge IHM câblé) : forcer
      directement en vue instance CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Modes_Stub) ===

VAR_GLOBAL
    // 🎚️ Sélecteur mode machine — forcer directement pour tester MANUEL/MAINT_N1/MAINT_N2/SEMI_AUTO
    ModeRequest_IHM         : E_Mode := E_Mode.MAINT_N1;

    // 🔑 Authentification MAINT_N2 (stub — pas de vrai mot de passe/droits câblés ce lot)
    PasswordOk_IHM          : BOOL := FALSE;

    // ☑️ Case à cocher opérateur — désactive la synchro M1/M2 (FB_WinchSync), UNIQUEMENT actif
    // si Mode=MAINT_N2 (arbitré par FB_Modes.OverrideSync, voir Partie5 §2 "Logique d'override")
    OverrideSyncRequest_IHM : BOOL := FALSE;
END_VAR

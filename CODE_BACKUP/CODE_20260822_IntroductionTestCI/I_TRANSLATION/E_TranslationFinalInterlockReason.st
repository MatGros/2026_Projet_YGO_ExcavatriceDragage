(* =======================================================================
   🛡️ E_TranslationFinalInterlockReason — Raisons d'interlock M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des raisons de blocage de la barrière finale M3
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
   ======================================================================= *)
{attribute 'qualified_only'}
TYPE E_TranslationFinalInterlockReason :
(
    NONE := 0,
    BRAKE_COMMAND_NOT_CONFIRMED := 1,
    RESTART_INHIBITED := 2
);
END_TYPE

(* =======================================================================
   🔒 E_WinchFinalInterlockReason — Raisons de blocage barrière finale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des causes de neutralisation/interlock final treuil
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   ======================================================================= *)
{attribute 'qualified_only'}
TYPE E_WinchFinalInterlockReason :
(
    NONE                        := 0,                                 // Aucun blocage actif
    BRAKE_COMMAND_NOT_CONFIRMED := 1,                                 // Absence confirmation ouverture frein > 500ms
    RESTART_INHIBITED           := 2                                  // Inhibition redemarrage actif
);
END_TYPE

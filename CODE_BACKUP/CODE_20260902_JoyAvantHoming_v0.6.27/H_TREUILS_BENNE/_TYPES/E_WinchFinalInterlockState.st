(* =======================================================================
   ⚙️ E_WinchFinalInterlockState — États machine barrière finale treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des états opérationnels de l'interlock final
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
{attribute 'qualified_only'}
TYPE E_WinchFinalInterlockState :
(
    DISABLED                        := 0,                             // Desactive / Hors service
    READY                           := 1,                             // Pret / Etat nominal
    WAIT_BRAKE_COMMAND_CONFIRMATION := 2,                             // Attente confirmation feedback frein
    WAIT_STEP_DELAY                 := 3,                             // Temporisation changement de palier
    WAIT_RESTART_DELAY              := 4,                             // Temporisation anti-court-cycle redemarrage
    FAULT                           := 5,                             // Etat de defaut
    WAIT_SENSE_DROP_CONFIRM         := 6                              // Maintien §3bis du contacteur de sens (AC6/AC7)
);
END_TYPE

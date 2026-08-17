(* 🛡️ États de la barrière finale frein/puissance treuil. *)
{attribute 'qualified_only'}
TYPE E_WinchFinalInterlockState :
(
    DISABLED := 0,
    READY := 1,
    WAIT_BRAKE_COMMAND_CONFIRMATION := 2,
    WAIT_STEP_DELAY := 3,
    WAIT_RESTART_DELAY := 4,
    FAULT := 5
);
END_TYPE

(* 🛡️ Raisons mémorisées de la barrière finale frein/puissance treuil. *)
{attribute 'qualified_only'}
TYPE E_WinchFinalInterlockReason :
(
    NONE := 0,
    BRAKE_COMMAND_NOT_CONFIRMED := 1,
    RESTART_INHIBITED := 2
);
END_TYPE

(* Mode d'arret de la recherche fond AX7. *)
TYPE E_CycleDepthStopMode :
(
    KOBOLD_ONLY       := 0, // Comportement historique : fond valide par DI Kobold
    SETPOINT_ONLY     := 1, // Arret sur consigne de profondeur valide
    KOBOLD_OR_SETPOINT:= 2  // Premier evenement valide des deux
);
END_TYPE

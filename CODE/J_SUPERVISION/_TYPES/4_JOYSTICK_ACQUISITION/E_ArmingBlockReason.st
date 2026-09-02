(* =======================================================================
   🚦 E_ArmingBlockReason — Motif de blocage de l'armement joystick
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : dire EN CLAIR pourquoi ArmingPermit est FALSE, pour l'IHM et
      le troubleshooting (« pourquoi je ne peux pas armer »).
   📄 Doc : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md §7
   ======================================================================= *)
TYPE E_ArmingBlockReason :
(
    NONE            := 0,   // Armement possible (au moins un axe x sens dispo)
    MODE_DISABLE    := 1,   // Mode DISABLE
    POWER_CUTOFF    := 2,   // Coupure puissance amont (M1/M2/M3)
    CONTACTOR_OFF   := 3,   // Chaîne AU non réarmée (PowerContactorEngaged FALSE)
    BUCKET_BUSY     := 4,   // Action benne en cours (+ 1 scan de fin d'action)
    ALL_AXES_BLOCKED := 5   // Base OK mais aucun axe x sens sélectionné n'est disponible
) INT;
END_TYPE

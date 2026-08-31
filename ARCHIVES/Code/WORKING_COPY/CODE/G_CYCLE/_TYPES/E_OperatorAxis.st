(* =======================================================================
   ⚙️ E_OperatorAxis — Axe ou organe de pilotage attendu par le cycle
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération de l'organe joystick/bouton attendu pour le mouvement
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)

TYPE E_OperatorAxis :
(
    NONE        := 0, (* Aucun axe attendu (étape automatique ou arrêt) *)
    JOYSTICK_X  := 1, (* Axe X translation attendu *)
    JOYSTICK_Y  := 2, (* Axe Y treuils / plongée attendu *)
    BUTTON      := 3  (* Action bouton attendue (ex: validation, homing) *)
);
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HwMachine — Image matérielle brute des entrées communes Machine
   ───────────────────────────────────────────────────────────────
   🎨 Regroupe les signaux physiques d'entrée bruts communs à la machine.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HwMachine :
STRUCT
    PowerContactorEngaged_DI       : BOOL; (* Confirm. contacteur puissance engagé *)
    EmergencyChainClosed_DI        : BOOL; (* Boucle AU fermée (coup-de-poing + contact PLC) *)
    PhaseRotationOk_DI             : BOOL; (* Contrôle rotation phases élec. OK *)
    M1_M2_M3_BrakeThermalOk_DI     : BOOL; (* Thermique frein M1/M2/M3 commun OK *)
    M1_M2_KoboldBottomTouch_DI     : BOOL; (* Retour détecteur fond Kobold *)
    HydraulicThermalOk_DI          : BOOL; (* Thermique centrale hydraulique OK *)
    ConveyorInfeedReady_DI         : BOOL; (* Autorisation démarrage crible (dépôt gravats) *)
    HopperFull_OR_GateRaised_DI    : BOOL; (* : Trémie pleine OU grille levée — pas encore câblé électriquement,
                                               déclaré en avance (Device_IO_20260812). Aucun consommateur pour l'instant :
                                               l'interdiction translation M3→Trémie est une tâche à part, voir PLAN_TASK.md. *)
END_STRUCT
END_TYPE

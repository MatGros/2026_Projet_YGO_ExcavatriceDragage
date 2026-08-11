(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HwMachine — Image matérielle brute des entrées communes Machine
   ───────────────────────────────────────────────────────────────
   📄 Lot L5 (Frontière unique HwIn)
   🎨 Regroupe les signaux physiques d'entrée bruts communs à la machine.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HwMachine :
STRUCT
    PowerContactorEngaged_DI   : BOOL; (* Confirm. contacteur puissance engagé *)
    EmergencyChainClosed_DI    : BOOL; (* Boucle AU fermée (coup-de-poing + contact PLC) *)
    PhaseRotationOk_DI         : BOOL; (* Contrôle rotation phases élec. OK *)
    BrakeThermalOk_DI          : BOOL; (* Thermique frein M1/M2/M3 commun OK *)
    M1_M2_KoboldContactFond_DI : BOOL; (* Retour détecteur fond Kobold *)
    HydraulicThermalOk_DI      : BOOL; (* Thermique centrale hydraulique OK *)
    ConveyorInfeedReady_DI     : BOOL; (* Autorisation démarrage crible (dépôt gravats) *)
END_STRUCT
END_TYPE

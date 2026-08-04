(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_InputsQualifiedMachine — TOR réelles qualifiées domaine Machine
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 (PRG_01_Inputs_LD → ST_InputsQualified)
   🎨 Champs qualifiés (polarité normalisée, filtre FB_Input appliqué).
   🔗 Producteur : PRG_01_Inputs_LD · Lecteur : PRG_02_Acquisition_CFC
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_InputsQualifiedMachine :
STRUCT
    PowerContactorEngaged_DI   : BOOL; (* TRUE = contacteur de puissance engagé *)
    EmergencyChainClosed_DI    : BOOL; (* TRUE = boucle AU fermée (saine) *)
    PhaseRotationOk_DI         : BOOL; (* TRUE = rotation des phases correcte *)
    BrakeThermalOk_DI          : BOOL; (* TRUE = thermique freins M1/M2/M3 commun OK *)
    M1_M2_KoboldContactFond_DI : BOOL; (* TRUE = contact fond Kobold détecté *)
    HydraulicThermalOk_DI      : BOOL; (* TRUE = thermique moteur hydraulique OK *)
    ConveyorInfeedReady_DI     : BOOL; (* TRUE = autorisation démarrage crible *)
END_STRUCT
END_TYPE

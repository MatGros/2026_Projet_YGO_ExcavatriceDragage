(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_InputsQualifiedTranslation — TOR réelles qualifiées domaine Translation
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 (PRG_01_Inputs_LD → ST_InputsQualified)
   🎨 Champs qualifiés (polarité normalisée, filtre FB_Input appliqué).
   🔗 Producteur : PRG_01_Inputs_LD · Lecteur : PRG_02_Acquisition_CFC
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_InputsQualifiedTranslation :
STRUCT
    M3_BrakeIsOpen_DI        : BOOL; (* TRUE = frein M3 OUVERT (desserré) — REX 08-03 *)
    M3_ThermalFeedback_DI    : BOOL; (* TRUE = thermique M3 OK *)
    M3_PosTremie_DI          : BOOL; (* TRUE = chariot en position Trémie *)
    M3_PosPV_DI              : BOOL; (* TRUE = chariot en zone pré-ralentissement PV *)
    M3_PosP2_DI              : BOOL; (* TRUE = chariot en position P2 *)
    M3_PosP1_DI              : BOOL; (* TRUE = chariot en position P1 *)
    M3_PosMaintenance_DI     : BOOL; (* TRUE = chariot en position Maintenance *)
END_STRUCT
END_TYPE

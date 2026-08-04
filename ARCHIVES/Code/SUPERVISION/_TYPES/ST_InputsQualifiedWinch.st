(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_InputsQualifiedWinch — TOR réelles qualifiées domaine Treuils
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 (PRG_01_Inputs_LD → ST_InputsQualified)
   🎨 Champs qualifiés (polarité normalisée, filtre FB_Input appliqué).
   🔗 Producteur : PRG_01_Inputs_LD · Lecteur : PRG_02_Acquisition_CFC
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_InputsQualifiedWinch :
STRUCT
    M1_ContactorsReleased_DI : BOOL; (* TRUE = contacteurs M1 retombés (sain) *)
    M1_ThermalOk_DI          : BOOL; (* TRUE = thermique M1 OK *)
    M1_BrakeIsOpen_DI        : BOOL; (* TRUE = frein M1 OUVERT (desserré) — REX 08-03 *)
    M2_ContactorsReleased_DI : BOOL; (* TRUE = contacteurs M2 retombés (sain) *)
    M2_ThermalOk_DI          : BOOL; (* TRUE = thermique M2 OK *)
    M2_BrakeIsOpen_DI        : BOOL; (* TRUE = frein M2 OUVERT (desserré) — REX 08-03 *)
    M1M2_TopPositionFree_DI  : BOOL; (* TRUE = fin de course haut libre *)
    M2_TensionedCable_DI     : BOOL; (* TRUE = câble M2 tendu (mou non déclenché) *)
END_STRUCT
END_TYPE

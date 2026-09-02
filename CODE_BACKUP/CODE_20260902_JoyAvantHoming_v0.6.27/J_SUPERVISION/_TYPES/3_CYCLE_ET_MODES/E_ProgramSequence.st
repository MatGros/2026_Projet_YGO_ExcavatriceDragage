(* =======================================================================
   🔄 E_ProgramSequence — Énumération des séquences de programme automatiques
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Identifie la séquence active arbitree dans PRG_03
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE E_ProgramSequence :
(
    NONE        := 0, // Aucune séquence active
    MAIN_CYCLE  := 1, // Cycle semi-automatique principal (FB_Cycle)
    DIVE_SEARCH := 2, // Recherche de fond Kobold (réservé future migration)
    EXTRACTION  := 3  // Séquence d'extraction (réservé future migration)
);
END_TYPE

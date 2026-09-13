(* =======================================================================
   🎯 ST_ProgramTranslationRequest — Demande de mouvement translation par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de translation M3 formulées par le séquenceur
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramTranslationRequest :
STRUCT
    ReqStart    : BOOL; // Demande de démarrage mouvement translation
    PositionTgt : INT;  // Cible de position demandée (1=Trémie, 2=P2, 3=P1, 4=Maintenance)
END_STRUCT
END_TYPE

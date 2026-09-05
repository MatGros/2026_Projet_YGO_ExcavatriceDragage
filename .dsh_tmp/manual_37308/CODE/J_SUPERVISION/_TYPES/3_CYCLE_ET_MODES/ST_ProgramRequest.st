(* =======================================================================
   📋 ST_ProgramRequest — Ensemble des demandes de mouvements du programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes formulées vers PRG_04 (Treuils/Benne) et PRG_05 (Translation)
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramRequest :
STRUCT
    ReqWinchM1            : ST_ProgramWinchRequest;       // Demande programme treuil M1
    ReqWinchM2            : ST_ProgramWinchRequest;       // Demande programme treuil M2
    ReqTranslation        : ST_ProgramTranslationRequest; // Demande programme translation M3
    ReqBucket             : ST_ProgramBucketRequest;      // Demande programme benne
END_STRUCT
END_TYPE

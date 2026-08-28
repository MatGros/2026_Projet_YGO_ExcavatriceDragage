(* =======================================================================
   🪣 ST_ProgramBucketRequest — Demande de mouvement benne par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de manœuvre benne et mesure Kobold
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramBucketRequest :
STRUCT
    ReqOpen                : BOOL; // Demande ouverture benne
    ReqClose               : BOOL; // Demande fermeture benne
    ReqKoboldMeasureEnable : BOOL; // Demande activation mesure/contacteur Kobold
END_STRUCT
END_TYPE

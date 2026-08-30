(* =======================================================================
   🪣 ST_ProgramBucketRequest — Demande de mouvement benne par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de manœuvre benne et mesure Kobold
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramBucketRequest :
STRUCT
    ReqOpen                     : BOOL; // Demande ouverture benne
    ReqClose                    : BOOL; // Demande fermeture benne
    ReqKoboldMeasureEnable      : BOOL; // Demande activation mesure/contacteur Kobold
    DescendPermitDiveBucketOpen : BOOL; // Autorisation de descente conditionnée benne ouverte (DiveSearch)
    ExtractionControlActive     : BOOL; // Plafond palier 1 pendant la montée contrôlée
    AscentPermit                : BOOL; // Autorisation de remontée assistée (ExtractionAssist)
    MinStepDown                 : INT;  // Palier plancher de descente imposé pendant la plongée (FB_DiveSearch, 0 = aucun)
END_STRUCT
END_TYPE

(* =======================================================================
   🔌 ST_ProgramWinchRequest — Demande de mouvement treuil par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de treuil formulées par le séquenceur
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramWinchRequest :
STRUCT
    RunRequest   : BOOL; // Ordre marche demandé par le programme
    ReqAscent    : BOOL; // Demande montée
    ReqDescend   : BOOL; // Demande descente
    StepTgt      : INT;  // Palier de vitesse cible demandé (1 à 5, 0 = arrêt)
END_STRUCT
END_TYPE

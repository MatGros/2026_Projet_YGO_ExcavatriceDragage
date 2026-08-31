(* =======================================================================
   🔌 ST_ProgramWinchRequest — Demande de mouvement treuil par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de treuil formulées par le séquenceur
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramWinchRequest :
STRUCT
    ReqStartStop : BOOL; // Ordre marche/arrêt demandé par le programme (TRUE=Marche)
    ReqDirection : INT;  // Sens demandé (-1: Descending, 0: Stop, 1: Ascending)
    StepTgt      : INT;  // Palier de vitesse cible demandé (1 à 5, 0 = arrêt)
END_STRUCT
END_TYPE

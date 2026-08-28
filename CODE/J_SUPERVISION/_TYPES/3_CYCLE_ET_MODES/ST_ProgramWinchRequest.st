(* =======================================================================
   🔌 ST_ProgramWinchRequest — Demande de mouvement treuil par le programme
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les demandes logiques de treuil formulées par le séquenceur
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_ProgramWinchRequest :
STRUCT
    ReqStartStop : BOOL; // Ordre marche/arrêt demandé par le programme (TRUE=Marche)
    ReqDirection : INT;  // Sens demandé (-1: Descente, 0: Stop, 1: Montée)
    SpeedTgtPct  : REAL; // Consigne de vitesse cible demandée (0.0 à 100.0 %)
END_STRUCT
END_TYPE

(* =======================================================================
   ⚙️ E_MachineHomingTxState — Steps du GRAFCET de referencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Role : Machine a etats sequentielle (GRAFCET) du cycle de homing
             machine M1/M2/benne pilote par FB_CycleMachineHoming (§8).
             Refonte T364 selon specification exploitant du 2026-09-21.
   📄 Doc : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_REFONTE_SEQUENCE_HOMING.yaml
            + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE E_MachineHomingTxState :
(
    HX0_REPOS               := 0,   (* Etape initiale pure : repos, aucune action *)
    HX1_BUCKET_PREPARE      := 1,   (* Fermeture benne palier 1 sous FDC off, timer 8s, bouton IHM dedie *)
    HX1A_COUPLING_INTERLOCK := 2,   (* Bascule WinchSel=0, FDC benne reactive, interlock couplage bloquant *)
    HX2_CLIMB_COUPLED       := 3,   (* Montee couplee M1+M2 palier 1 MAX vers capteur haut *)
    HX3_FLYING_REFERENCE    := 4,   (* Prise de reference a la volee M1+M2 sur position de config persistante (8.5m) *)
    HX4_STABILIZATION_CHECK := 5,   (* Arret mecanique, controle inertie [8.50..8.80m], max 3 retries *)
    HX5_RELEASE_CLEARANCE   := 6,   (* Degagement zone haute, verification neutre joystick *)
    HX6_HOMED_SUCCESS       := 7,   (* Machine qualifiee : MachineHomed := TRUE, commit atomique benne *)
    HX7_FAILED              := 8    (* Echec sequence unifie : Reset conscient requis en MAINT_N2 *)
);
END_TYPE

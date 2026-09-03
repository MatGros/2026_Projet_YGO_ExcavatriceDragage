(* =======================================================================
   ⚙️ E_MachineHomingTxState — Steps du GRAFCET de referencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Role : Machine a etats sequentielle (GRAFCET) du cycle de homing
             machine M1/M2/benne pilote par FB_MachineHomingCycle (§4).
             Distincte de E_MachineHomingStep (echelle de priorite du
             guide operateur, libelles de diagnostic - §6).
   📄 Doc : DOC/WFLOW/CONTRACTS/GEL_GRAFCET_HOMING_CYCLE_20260903.md
            + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)

TYPE E_MachineHomingTxState :
(
    HX0_REPOS         := 0,   (* Etape initiale pure : aucune action, aucune affectation *)
    HX1_CHOICE        := 1,   (* Annonce + choix operateur : aucun mouvement *)
    HX2_CLIMB         := 2,   (* Chemin A : montee couplee M1+M2 palier 1 jusqu au capteur haut *)
    HX2N_NEUTRAL      := 3,   (* Arret + inversion de sens (tire -> pousse) : mouvement nul obligatoire *)
    HX3_HOME_AXES     := 4,   (* Homing axes M1+M2 au vol sur front descendant capteur, puis descente couplee *)
    HX3N_PAUSE        := 5,   (* Arret avant benne : mouvement nul, retour joystick au neutre *)
    HX4_BUCKET_ADJUST := 6,   (* Ajustement benne palier 1 sans FDC soft, 2 sens autorises *)
    HX5_BUCKET_COMMIT := 7,   (* Commit atomique etat benne fermee (CommitClose) *)
    HX6_HOMED         := 8,   (* Machine referencee : MachineHomed := TRUE (fugace) *)
    HXF_FAILED        := 9    (* Referencement incomplet : rester en N2 et recommencer *)
);
END_TYPE

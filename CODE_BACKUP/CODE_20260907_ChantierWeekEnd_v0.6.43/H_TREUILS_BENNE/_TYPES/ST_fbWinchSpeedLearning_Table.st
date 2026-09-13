(* =======================================================================
   💾 ST_fbWinchSpeedLearning_Table — Table RETAIN apprentissage vitesse
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Matrice {axe x sens x charge/vide x palier} de vitesses apprises
   📄 Doc metier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbWinchSpeedLearning_Table :
STRUCT
    // [axe][sens][charge][palier]
    //   axe    : 1=M1, 2=M2
    //   sens   : 1=montee, 2=descente
    //   charge : 1=vide, 2=charge
    //   palier : 1..5
    Cell : ARRAY[1..2, 1..2, 1..2, 1..5] OF ST_fbWinchSpeedLearning_Cell;
END_STRUCT
END_TYPE

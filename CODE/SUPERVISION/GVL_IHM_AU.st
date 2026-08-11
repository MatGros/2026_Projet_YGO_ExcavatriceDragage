(* ==============================================================
   [IHM] GVL_IHM_AU -- Interface IHM pour le test de la chaine AU
   --------------------------------------------------------------
   Role : point d'echange unique entre l'IHM (Watch/visu) et
          le programme de test de la chaine d'arret d'urgence.
   Pattern : identique a GVL_IHM.Modes (Cmd + State) dans le
          projet reel.
   Usage :
     GVL_IHM_AU.Cmd.BtnEmergencyArming   -> ecrit par l'IHM
     GVL_IHM_AU.State.ContactorOk         -> lu par l'IHM
   ==============================================================
    Docs : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
           DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md
*)

{attribute 'qualified_only'}
VAR_GLOBAL
    Cmd   : ST_Safety_Emergency_HmiCmd;    // [IHM] Commandes operateur (Write)
    State : ST_Safety_Emergency_HmiState;  // [IHM] Retours d'etat (Read)
END_VAR

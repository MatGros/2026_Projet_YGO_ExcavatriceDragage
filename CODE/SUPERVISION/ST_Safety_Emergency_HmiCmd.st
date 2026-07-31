(* ==============================================================
   [IHM] ST_Safety_Emergency_HmiCmd -- Commandes IHM pour la chaine AU
   --------------------------------------------------------------
   Role : structure d'echange pour les commandes operateur
          de la chaine d'arret d'urgence (miroir ST_ModesCmd).
   Pattern : identique a GVL_IHM.Modes.Cmd dans le projet reel.
          L'IHM ecrit ces champs, le programme les consomme.
   ==============================================================
    Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
           DOC/AF_Partie-07_Interface_IHM_v2.0.md
*)

TYPE ST_Safety_Emergency_HmiCmd :
STRUCT
    BtnEmergencyArming   : BOOL;   // Front demande rearmement contacteur
    BtnEmergencyCutOff   : BOOL;   // Niveau coupure IHM maintenue
    BtnFaultReset        : BOOL;   // Front acquittement defauts
END_STRUCT
END_TYPE

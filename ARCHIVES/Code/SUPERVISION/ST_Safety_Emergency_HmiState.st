(* ==============================================================
   [IHM] ST_Safety_Emergency_HmiState -- Retours d'etat IHM pour chaine AU
   --------------------------------------------------------------
   Role : structure d'echange pour les retours d'etat de la
          chaine d'arret d'urgence (miroir ST_ModesState).
   Pattern : identique a GVL_IHM.Modes.State dans le projet reel.
          Le programme ecrit ces champs, l'IHM les lit.
   ==============================================================
    Docs : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
           DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md
*)

TYPE ST_Safety_Emergency_HmiState :
STRUCT
    // [OK] Etats generaux
    ChainOk              : BOOL;   // Boucle AU fermee (saine)
    ContactorOk          : BOOL;   // Contacteur puissance engage
    PowerCutOffActive    : BOOL;   // Coupure puissance demandee par une safety metier

    // [AU] Sequence de rearmement
    Armable              : BOOL;   // Pret au rearmement (chain OK + pas de lockout + pas de defaut)
    ArmingBusy           : BOOL;   // Sequence armement en cours
    Step                 : INT;    // Etape sequence (0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm)

    // [KO] Diagnostics
    Error                : BOOL;   // Synthese defaut
    ErrorId              : WORD;   // bit0=RedundancyTestFailed, bit1=ArmingFailed
    RedundancyTestFailed : BOOL;   // Auto-test A/B a echoue (canal colle/shunte)
    ArmingFailed         : BOOL;   // Rearmement echoue (timeout confirmation)
    LockoutActive        : BOOL;   // Verrouillage 5s entre tentatives
END_STRUCT
END_TYPE

(* =======================================================================
   📊 ST_Safety_Emergency_State — État public de la chaîne d'arrêt d'urgence
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Bus d'état public de la chaîne d'arrêt d'urgence
   🔌 Interface : Produit par FB_Safety_EmergencyManagement, consommé par Supervision/Troubleshooting
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_State :
STRUCT
    ChainOk     : BOOL; // Boucle AU fermee (EmergencyChainClosed = TRUE)
    ContactorOk : BOOL; // Contacteur puissance confirme engage (PowerContactorEngaged = TRUE)
    Step        : INT;  // Etape sequence armement : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    Armable     : BOOL; // Rearmement possible maintenant : chain OK, step=0, pas de lockout, pas de defaut redondance
    ArmingBusy  : BOOL; // Sequence armement OU lockout en cours (nouvelle demande ignoree)
END_STRUCT
END_TYPE

(* =======================================================================
   ST_Modes_Autorisations - Bus public d'autorisations du mode machine
   -----------------------------------------------------------------------
   Doc metier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
                DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md #2
   NC-110 : le prefixe ST_fb* est reserve aux DUT propriete d'un seul FB.
      Ce DUT est un BUS multi-consommateurs (>=6 domaines : Cycle, Safety,
      Treuils, Translation, Supervision, Acquisition) -> renomme
      ST_Modes_Autorisations (bus de domaine public, sans le prefixe FB).
   Produit par FB_Modes (via PRG_03_Modes_Cycle)
      Consomme par : Cycle, Safety, Treuils, Translation, Supervision, Acquisition
   Producteur unique : FB_Modes (via PRG_03_Modes_Cycle)
   ======================================================================= *)

TYPE ST_Modes_Autorisations :
STRUCT
    Mode                        : E_Mode;     // Mode arbitre (DISABLE/N1/N2/SEMI_AUTO)
    SyncEnable                  : BOOL;       // Synchro M1/M2 (logique positive)
    InhibitM1                   : BOOL;       // Inhibition M1 (MAINT_N2 only)
    InhibitM2                   : BOOL;       // Inhibition M2 (MAINT_N2 only)
    JoystickWinchSelectArbitrated : INT;      // 0=M1+M2 couples nominal, 1=M1, 2=M2 (unitaires MAINT_N2)
    HomingApproachEnable        : BOOL;       // Depassement butee haut (N2)
    MaintenanceM3TargetEnable   : BOOL;       // Cible Translation Maintenance (N2 only)

    // AF-05 #4bis - matrice de maintenance
    // Ces trois champs sont des FAITS/DIAGS publies, pas des autorisations : ils
    // restent vrais meme quand le FB est neutralise par Enable=FALSE (etat persistant).
    ModeChangePendingBlocked    : BOOL;       // Demande de changement de mode REFUSEE : les treuils
                                              //   ne sont pas a l'arret mecanique confirme (contacteurs
                                              //   retombes ET frein serre ET |v| < seuil). Mode courant maintenu.
    HomingRequiredM1            : BOOL;       // M1 : re-homing obligatoire avant tout retour SEMI_AUTO
    HomingRequiredM2            : BOOL;       // M2 : idem
END_STRUCT
END_TYPE

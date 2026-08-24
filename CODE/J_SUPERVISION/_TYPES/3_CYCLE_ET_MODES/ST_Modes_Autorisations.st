(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_Modes_Autorisations — Bus d'autorisations du mode machine
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.0.md
                   DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md §2
   🎯 Produit par FB_Modes (via PRG_03_Modes_Cycle)
      Consommé par : Cycle, Safety, Treuils, Translation, Supervision, Acquisition
   🎯 Producteur unique : FB_Modes (via PRG_03_Modes_Cycle)
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_Modes_Autorisations :
STRUCT
    Mode                        : E_Mode;     // Mode arbitré (DISABLE/N1/N2/SEMI_AUTO)
    SyncEnable                  : BOOL;       // Synchro M1/M2 (logique positive)
    InhibitM1                   : BOOL;       // Inhibition M1 (MAINT_N2 only)
    InhibitM2                   : BOOL;       // Inhibition M2 (MAINT_N2 only)
    JoystickWinchSelectArbitrated : INT;      // 0=M1+M2 couplés nominal, 1=M1, 2=M2 (unitaires MAINT_N2)
    HomingApproachEnable        : BOOL;       // Dépassement butée haut (N2)
    MaintenanceM3TargetEnable   : BOOL;       // Cible Translation Maintenance (N2 only)
END_STRUCT
END_TYPE
(* ═══════════════════════════════════════════════════════════════
   🚌 ST_Modes_Autorisations — Bus public d'autorisations du mode machine
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
                   DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md §2
   📐 NC-110 : le préfixe ST_fb* est réservé aux DUT propriété d'un seul FB.
      Ce DUT est un BUS multi-consommateurs (≥6 domaines : Cycle, Safety,
      Treuils, Translation, Supervision, Acquisition) → renommé ST_Modes_Autorisations
      (bus de domaine public, sans préfixe ST_fb*).
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

    // AF-05 §4bis — matrice de maintenance
    // ⚠️ Ces trois champs sont des FAITS/DIAGS publiés, pas des autorisations : ils restent
    // vrais même quand le FB est neutralisé par Enable=FALSE (état persistant à remonter à l'IHM).
    ModeChangePendingBlocked    : BOOL;       // 🚦 Demande de changement de mode REFUSÉE : les treuils
                                              //    ne sont pas à l'arrêt mécanique confirmé
                                              //    (contacteurs retombés ET frein serré ET |v| < seuil).
                                              //    Le mode courant est maintenu. IHM : « arrêter les
                                              //    treuils avant de changer de mode ».
    HomingRequiredM1            : BOOL;       // 🧭 M1 : re-homing obligatoire avant tout retour SEMI_AUTO
                                              //    (usage effectif d'un override/bypass position en maintenance)
    HomingRequiredM2            : BOOL;       // 🧭 M2 : idem
END_STRUCT
END_TYPE
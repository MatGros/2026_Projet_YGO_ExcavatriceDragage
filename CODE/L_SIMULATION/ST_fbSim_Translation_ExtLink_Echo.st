(* ═══════════════════════════════════════════════════════════════
   🧪 ST_fbSim_Translation_ExtLink_Echo — État décisionnel M3 renvoyé au simulateur externe
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Copie en lecture seule de l'état PLC M3 (mode, autorisations, verrous,
      position décodée) transmise à la passerelle FMU pour diagnostic et affichage.
   🔒 Aucune commande : le simulateur l'affiche et la journalise, il n'agit jamais dessus.
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_fbSim_Translation_ExtLink_Echo :
STRUCT
    Mode                    : E_Mode;                          (* Mode arbitré PRG_03 *)
    FBState                 : E_State;                         (* État FB_Translation *)
    AxisBlockReason         : E_TranslationTraceBlockReason;   (* Cause prioritaire de blocage M3 *)
    MaintenanceTargetEnable : BOOL;                            (* Accès zone Maintenance accordé *)
    MaintenanceZoneAccess   : BOOL;                            (* Bouton IHM d'accès zone Maintenance *)
    SafeStop                : BOOL;                            (* SafeStop M3 effectif *)
    PowerCutOff             : BOOL;                            (* Coupure puissance demandée par la safety M3 *)
    LimitSwitchTremie       : BOOL;                            (* Fin de course Trémie (stable) *)
    LimitSwitchMaintenance  : BOOL;                            (* Fin de course Maintenance ou P1 si zone interdite *)
    PositionReached         : BOOL;                            (* Cible atteinte *)
    ActiveTremie            : BOOL;                            (* Commande active vers Trémie *)
    ActiveMaintenance       : BOOL;                            (* Commande active vers Maintenance *)
    AtTremie                : BOOL;                            (* Jeton dernier point franchi : Trémie *)
    AtPV                    : BOOL;                            (* Jeton dernier point franchi : PV *)
    AtP2                    : BOOL;                            (* Jeton dernier point franchi : P2 *)
    AtP1                    : BOOL;                            (* Jeton dernier point franchi : P1 *)
    AtMaintenance           : BOOL;                            (* Jeton dernier point franchi : Maintenance *)
    SensorWordIncoherent    : BOOL;                            (* Mot capteurs incohérent côté PLC *)
    EstimatedPos_M          : REAL;                            (* Position estimée PLC, m (0 Maint -> +X Trémie) *)
    SafetyErrorId           : WORD;                            (* Bitfield live FB_Safety_Translation *)
END_STRUCT
END_TYPE

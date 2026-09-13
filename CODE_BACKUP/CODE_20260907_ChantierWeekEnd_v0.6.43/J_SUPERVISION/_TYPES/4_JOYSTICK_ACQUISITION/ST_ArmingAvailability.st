(* =======================================================================
   🚦 ST_ArmingAvailability — Disponibilité de mouvement par axe et sens
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : dire, pour chaque axe x sens, si le mouvement peut REELLEMENT
      partir (permis effectif + pas de SafeStop/faute de CET axe). Sert de
      base honnête à ArmingPermit (au moins un dispo) et de diagnostic
      « pourquoi ça bloque » pour l'IHM / le troubleshooting.
   📤 Producteur : PRG_04_Treuils_Benne (agrège M1/M2 + lit M3 via bus PRG_05, lag 1 scan).
   📄 Doc : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md §7
   ======================================================================= *)
TYPE ST_ArmingAvailability :
STRUCT
    M1AscentAvail      : BOOL;   // TRUE = montée M1 peut partir
    M1DescendAvail     : BOOL;   // TRUE = descente M1 peut partir
    M2AscentAvail      : BOOL;   // TRUE = montée/fermeture M2 peut partir
    M2DescendAvail     : BOOL;   // TRUE = descente/ouverture M2 peut partir
    M3TremieAvail      : BOOL;   // TRUE = translation M3 vers trémie peut partir
    M3MaintenanceAvail : BOOL;   // TRUE = translation M3 vers maintenance peut partir
    AnyAxisAvail       : BOOL;   // OR des 6 — au moins une action peut partir (condition d'armement)
    BlockedReason      : E_ArmingBlockReason;   // Motif si armement impossible
END_STRUCT
END_TYPE

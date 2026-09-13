(* =======================================================================
   🔌 ST_fbMachineHomingCycle_AxisHomingStatus — Statut homing d'un axe treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe l'etat de homing d'un axe (M1 ou M2) consomme par
             FB_MachineHomingCycle pour piloter le guide et la transaction.
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
TYPE ST_fbMachineHomingCycle_AxisHomingStatus :
STRUCT
    HomedAndReliable : BOOL;   (* Codeur reference ET mesure jugee fiable (gate strict) *)
    HomingBusy       : BOOL;   (* Sequence de homing en cours sur l'axe *)
    HomingDone       : BOOL;   (* Homing termine avec succes (HomingLifecycle.Done cote FB_Encoder) *)
    HomingError      : BOOL;   (* Homing en erreur sur l'axe (HomingFault.Error) *)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🚦 ST_ModesState — États et diagnostics IHM des modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesState :
STRUCT
    CurrentMode           : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    AnyFaultActive        : BOOL;   (* : au moins un défaut/alarme actif dans le domaine
                                        sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                        BtnFaultReset a été pressé (OR de tous les .Error du domaine,
                                        même périmètre que BtnFaultReset) *)

    (* Miroir IHM des états de maintenance (AF-05 §4bis) *)
    ModeChangePendingBlocked : BOOL;   (* 🚦 Changement de mode refusé : treuils non à l'arrêt confirmé (contacteurs retombés + frein serré + |v| < seuil) *)
    ModeChangeBlockReason    : STRING(40); (* 🚦 Motif du blocage de bascule (texte court, ex. "Chgt mode refuse : contacteur M1") *)
    (* Détail des 6 sous-conditions de ModeChangeAllowed (diagnostic IHM) — TRUE = condition satisfaite *)
    M1ContactorsReleased : BOOL; (* M1 : contacteurs retombés *)
    M1BrakeApplied       : BOOL; (* M1 : frein serré *)
    M1SpeedLow           : BOOL; (* M1 : vitesse sous seuil *)
    M2ContactorsReleased : BOOL; (* M2 : contacteurs retombés *)
    M2BrakeApplied       : BOOL; (* M2 : frein serré *)
    M2SpeedLow           : BOOL; (* M2 : vitesse sous seuil *)
    HomingRequiredM1         : BOOL;   (* 🧭 M1 : re-homing obligatoire avant retour SEMI_AUTO *)
    HomingRequiredM2         : BOOL;   (* 🧭 M2 : re-homing obligatoire avant retour SEMI_AUTO *)
END_STRUCT
END_TYPE

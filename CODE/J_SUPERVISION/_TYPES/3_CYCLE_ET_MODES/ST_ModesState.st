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
    HomingRequiredM1         : BOOL;   (* 🧭 M1 : re-homing obligatoire avant retour SEMI_AUTO *)
    HomingRequiredM2         : BOOL;   (* 🧭 M2 : re-homing obligatoire avant retour SEMI_AUTO *)
END_STRUCT
END_TYPE

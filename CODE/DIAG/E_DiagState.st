(* ═══════════════════════════════════════════════════════════════
   🚦 E_DiagState — Énumération des phases de diagnostic bus
   ═══════════════════════════════════════════════════════════════ *)
TYPE E_DiagState :
(
    DISABLED   := 0,  (* Désactivé (surveillance non active) *)
    READY      := 1,  (* Prêt (opérationnel, pas de défaut) *)
    INIT       := 2,  (* Initialisation en cours / Recherche de réseau *)
    MONITORING := 3,  (* Surveillance active (états transitoires) *)
    ERROR      := 4   (* Présence anomalie de communication *)
);
END_TYPE

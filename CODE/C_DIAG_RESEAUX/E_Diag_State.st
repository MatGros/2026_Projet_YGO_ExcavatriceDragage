(* ═══════════════════════════════════════════════════════════════
   🚦 E_Diag_State — Phases du cycle de diagnostic bus
   ═══════════════════════════════════════════════════════════════ *)
TYPE E_Diag_State :
(
    DISABLED   := 0,  (* Désactivé (surveillance non active) *)
    READY      := 1,  (* Opérationnel réel, pas de défaut *)
    INIT       := 2,  (* Initialisation / Recherche de réseau *)
    MONITORING := 3,  (* Surveillance active (états transitoires) *)
    ERROR      := 4,  (* Anomalie de communication *)
    SIMULATED  := 5   (* Bypass simulation ou bypass réseau IHM — pas le bus réel *)
);
END_TYPE

(* =======================================================================
   📊 E_Diag_State — Enumération des états du cycle de diagnostic réseau
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Phases d'état de surveillance diagnostic d'un bus ou équipement
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.0.md
   ======================================================================= *)
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

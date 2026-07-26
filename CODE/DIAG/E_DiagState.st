(* ═══════════════════════════════════════════════════════════════
   🚦 E_DiagState — Énumération des phases de diagnostic bus
   ═══════════════════════════════════════════════════════════════ *)
TYPE E_DiagState :
(
    DISABLED   := 0,  (* Désactivé (surveillance non active) *)
    READY      := 1,  (* Prêt (opérationnel réel, pas de défaut) *)
    INIT       := 2,  (* Initialisation en cours / Recherche de réseau *)
    MONITORING := 3,  (* Surveillance active (états transitoires) *)
    ERROR      := 4,  (* Présence anomalie de communication *)
    // 🆕 REX 2026-07-24 (demande utilisateur, mise en service) : distingue explicitement "bypassé
    // par simulation/bypass réseau IHM" de READY (réellement online) — évite la confusion vue en
    // mise en service (PLC affichait Operational=1 sans indiquer que c'était un bypass, pas le bus réel).
    SIMULATED  := 5   (* Bypass simulation (Bus<Device>IsReal=FALSE) ou bypass réseau IHM actif — pas le bus réel *)
);
END_TYPE

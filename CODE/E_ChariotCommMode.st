(* ═══════════════════════════════════════════════════════════════
   🔀 E_ChariotCommMode — Mode de communication FB_Chariot
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.2.md
   🧭 Sélection MANUELLE (maintenance), jamais de bascule automatique
      pendant un mouvement — voir Partie11 §1.
   ═══════════════════════════════════════════════════════════════ *)

TYPE E_ChariotCommMode :
ENUM
    ETHERCAT    := 0,   (* Nominal : mot commande/état + consigne fréquence via EtherCAT (AC600) *)
    DEGRADED_IO := 1    (* Dégradé : relais de sens + présélection vitesse PV/GV (TOR), vitesse/rampes réglées sur le variateur en local *)
END_ENUM
END_TYPE

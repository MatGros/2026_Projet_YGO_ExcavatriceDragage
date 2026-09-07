(* ═══════════════════════════════════════════════════════════════
   🛠️ ST_MaintenanceN2Cmd — Commandes manuelles IHM en mode MAINT_N2
   ───────────────────────────────────────────────────────────────
   📄 Commandes de forçage unitaire et couplé sous mot de passe IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_MaintenanceN2Cmd :
STRUCT
    // === Commandes Mouvements N2 (Palier 1 Vitesse Lente) ===
    BtnM1Ascent          : BOOL; (* ⬆️ M1 Montée seul (Relais Fwd + Palier 1 + Frein) *)
    BtnM1Descend         : BOOL; (* ⬇️ M1 Descente seul (Relais Rev + Palier 1 + Frein) *)
    BtnM2Ascent          : BOOL; (* ⬆️ M2 Montée / Fermeture seul (Relais Fwd + Palier 1 + Frein) *)
    BtnM2Descend         : BOOL; (* ⬇️ M2 Descente / Ouverture seul (Relais Rev + Palier 1 + Frein) *)
    BtnBothAscent        : BOOL; (* ⬆️ M1 + M2 Montée couplée (Relais Fwd + Palier 1 + Frein) *)
    BtnBothDescend       : BOOL; (* ⬇️ M1 + M2 Descente couplée (Relais Rev + Palier 1 + Frein) *)

    // === Commandes Translation M3 (Petite Vitesse 10.0 Hz + Frein) ===
    BtnM3Tremie          : BOOL; (* ⬅️ M3 vers Trémie (Mot Cmd 1 + Freq 10 Hz + Frein) *)
    BtnM3Maintenance     : BOOL; (* ➡️ M3 vers Maintenance (Mot Cmd 2 + Freq 10 Hz + Frein) *)

    // === Commandes Freins N2 Seuls (Vérification mécanique) ===
    BtnM1BrakeRelease    : BOOL; (* 🔓 Desserrage direct frein treuil M1 *)
    BtnM2BrakeRelease    : BOOL; (* 🔓 Desserrage direct frein treuil M2 *)
    BtnM3BrakeRelease    : BOOL; (* 🔓 Desserrage direct frein translation M3 *)
END_STRUCT
END_TYPE

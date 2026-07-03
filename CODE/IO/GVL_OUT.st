(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_OUT — Commandes déjà rampées des FB métier (entrée de FB_OutputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔧 AJOUT (2026-07-03quindecies, demande utilisateur) : `PRG_MAIN` écrit ICI les
      commandes déjà rampées de `FB_Winch`/`FB_Chariot` par simples affectations
      (naturel en LD : 1 rung = 1 bobine), plutôt que de les passer en paramètres
      d'un appel de FB à 15 entrées (lourd à câbler en Ladder). `FB_OutputsMachine`
      lit ensuite ces variables directement en interne, appelée SANS paramètre.
   ⚠️ Écart assumé à Partie2 §0 ("quasi pas de GVL, sauf échange IHM") — même choix
      pragmatique que `GVL_IN`.
   🔴 Écrit UNIQUEMENT par `PRG_MAIN` (après `FB_Winch`/`FB_Chariot`), lu UNIQUEMENT
      par `FB_OutputsMachine`.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_OUT) ===

VAR_GLOBAL
    // 🪝 WINCH M1
    M1RelayFwd        : BOOL;
    M1RelayRev        : BOOL;
    M1SpeedContactor1 : BOOL;
    M1SpeedContactor2 : BOOL;
    M1SpeedContactor3 : BOOL;
    M1SpeedContactor4 : BOOL;
    M1BrakeCmd        : BOOL;

    // 🪝 WINCH M2
    M2RelayFwd        : BOOL;
    M2RelayRev        : BOOL;
    M2SpeedContactor1 : BOOL;
    M2SpeedContactor2 : BOOL;
    M2SpeedContactor3 : BOOL;
    M2SpeedContactor4 : BOOL;
    M2BrakeCmd        : BOOL;

    // ↔️ CHARIOT M3 — seul BrakeCmd est réel
    ChariotBrakeCmd   : BOOL;
END_VAR

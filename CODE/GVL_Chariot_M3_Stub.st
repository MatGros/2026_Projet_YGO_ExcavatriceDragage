(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Chariot_M3_Stub — Variables STUB minimales M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.2.md §7
   🔧 CORRECTIF (2026-07-03) : réduit au minimum — M3_RelayFwd/Rev,
      M3_ContactorFeedback*, M3_DriveFaultFeedback retirés (câblés en
      I/O Mapping réel depuis Device.export). Restent seulement :
      - `StubChariotPositionSelect_IHM` : sélecteur maintenance (en attente
        de FB_Cycle)
      - `M3_BrakeFeedback` : retour frein (pas encore câblé)
   ═══════════════════════════════════════════════════════════════ *)

VAR_GLOBAL
    StubChariotPositionSelect_IHM : INT := 0;   // 🖥️ Sélecteur test maintenance (0=Aucun, 1=Fosse1, 2=Fosse2, 3=Maintenance, 4=Trémie)
    M3_BrakeFeedback : BOOL;                     // 🧪 Retour frein M3 (stub — pas câblé)
END_VAR

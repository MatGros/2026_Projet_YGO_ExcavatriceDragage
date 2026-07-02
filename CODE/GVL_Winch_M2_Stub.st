(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Winch_M2_Stub — Variables LOGICIELLES temporaires M2
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md §7 Étape 9bis
   ⚠️ TEMPORAIRE — aucun relais réel piloté. Même principe que
      `GVL_Winch_M1_Stub.st` : à supprimer dès que le matériel M2
      (relais sens/vitesse/frein + retours) sera câblé en I/O Mapping
      avec ces MÊMES noms de variables (les deux mécanismes ne
      peuvent pas coexister — conflit de nom).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Winch_M2_Stub) ===

VAR_GLOBAL
    M2_RelayFwd              : BOOL;   // 🔌 Sortie — contacteur sens avant M2 (STUB)
    M2_RelayRev              : BOOL;   // 🔌 Sortie — contacteur sens arrière M2 (STUB)
    M2_Contactor1            : BOOL;   // 🔌 Sortie — contacteur vitesse 1 M2 (STUB)
    M2_Contactor2            : BOOL;   // 🔌 Sortie — contacteur vitesse 2 M2 (STUB)
    M2_Contactor3            : BOOL;   // 🔌 Sortie — contacteur vitesse 3 M2 (STUB)
    M2_Contactor4            : BOOL;   // 🔌 Sortie — contacteur vitesse 4 M2 (STUB)
    M2_BrakeCmd              : BOOL;   // 🔌 Sortie — bobine frein M2 (STUB)
    // 🔧 Mirés activement par PRG_MAIN.st (bloc 🧪 SIMULATION) sur les commandes ci-dessus
    // (contacteur "idéal"), pas "toujours FALSE" — même principe que GVL_Winch_M1_Stub.
    M2_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M2 (STUB, miroir de M2_RelayFwd)
    M2_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M2 (STUB, miroir de M2_RelayRev)
    M2_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M2 (STUB, miroir de M2_BrakeCmd)

    // 🎯 AJOUT 2026-07-02 (lot Homing) — capteur position haute M2 (physique, PAS de miroir
    // automatique : reste FALSE tant que non forcé manuellement dans la vue instance CODESYS).
    // ⚠️ Homing volontairement IMPOSSIBLE tant que ce stub reste FALSE (sécurité : ne jamais
    // simuler un signal safety-relevant comme actif par défaut).
    M2_TopPositionSensor     : BOOL;   // 🔌 Entrée — capteur position haute M2 (STUB, toujours FALSE)
END_VAR

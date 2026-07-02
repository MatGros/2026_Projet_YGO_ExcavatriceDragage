(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Translation_M3_Stub — Variables LOGICIELLES temporaires M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Translation_v1.1.md §7
   ⚠️ TEMPORAIRE — aucun relais/capteur réel piloté. Même principe que
      `GVL_Winch_M1_Stub.st`/`GVL_Winch_M2_Stub.st` : à supprimer dès
      que le matériel M3 (relais sens/PV-GV/frein + retours + capteur
      position cible) sera câblé en I/O Mapping avec ces MÊMES noms
      (les deux mécanismes ne peuvent pas coexister — conflit de nom).
   🔴 M3_DriveFaultFeedback : laissé à FALSE (STUB) — NE PAS interpréter
      comme "pas de défaut variateur confirmé", c'est juste l'absence
      de retour câblé pour l'instant (Partie11 §3, ne jamais stubber
      un "pas de défaut" arbitraire comme s'il était réel).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Translation_M3_Stub) ===

VAR_GLOBAL
    M3_RelayFwd              : BOOL;   // 🔌 Sortie — contacteur sens avant M3 (STUB, DEGRADED_IO)
    M3_RelayRev              : BOOL;   // 🔌 Sortie — contacteur sens arrière M3 (STUB, DEGRADED_IO)
    M3_RelaySpeedGv          : BOOL;   // 🔌 Sortie — présélection GV M3 (STUB, DEGRADED_IO)
    M3_BrakeCmd              : BOOL;   // 🔌 Sortie — bobine frein M3 (STUB)

    // 🔧 Mirés activement par PRG_MAIN.st (bloc 🧪 SIMULATION) sur les commandes ci-dessus
    // (contacteur "idéal"), même principe que GVL_Winch_M1_Stub/M2_Stub.
    M3_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M3 (STUB, miroir de M3_RelayFwd)
    M3_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M3 (STUB, miroir de M3_RelayRev)
    M3_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M3 (STUB, miroir de M3_BrakeCmd)

    // 🎯 Capteur position cible (PAS de miroir automatique — physique, forcer manuellement
    // dans la vue instance CODESYS pour tester l'arrêt sur capteur, Partie11 §9bis).
    M3_PositionSensorTarget  : BOOL;   // 🔌 Entrée — capteur position cible M3 (STUB, toujours FALSE)

    // 🔴 Retour défaut variateur — PAS de miroir, reste FALSE tant que non câblé (voir en-tête)
    M3_DriveFaultFeedback    : BOOL;   // 🔌 Entrée — défaut variateur TOR M3 (STUB, toujours FALSE)
END_VAR

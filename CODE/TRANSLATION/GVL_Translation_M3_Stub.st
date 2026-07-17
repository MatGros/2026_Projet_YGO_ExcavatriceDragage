(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Translation_M3_Stub — Variables STUB M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.8.md §7
   🔧 CORRECTIF (2026-07-03) : réintégration de M3_RelayFwd/Rev/SpeedGv,
      M3_ContactorFeedbackFwd/Rev, M3_DriveFaultFeedback,
      M3_PositionSensorTarget — retirés par erreur le 2026-07-03
      (câblage I/O réel pas encore fait, PRG_MAIN.st en dépend toujours
      → 31 erreurs de compilation). Seul `M3_BrakeCmd` est réel (I/O
      Mapping Device.export, 2026-07-02) — il ne revient PAS ici.
   🔧 CORRECTIF (2026-07-03quattuordecies) : `M3_BrakeFeedback` RETIRÉ — retour
      frein M3 désormais réel (`M3_BrakeContactorFeedback_DI`, conditionné dans
      `FB_InputsMachine`), plus de miroir logiciel nécessaire.
   ═══════════════════════════════════════════════════════════════ *)

VAR_GLOBAL
    // 🔌 Nouvelle entrée physique PV à mapper dans CODESYS.
    PosPV_DI : BOOL;

    // 🆕 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 §3bis) — 5 capteurs Trémie|PV|P2|P1|
    // Maintenance. PV n'est JAMAIS une cible sélectionnable (point de ralentissement seul).
    StubTranslationPositionSelect_IHM : INT := 0;   // 🖥️ Sélecteur test maintenance (0=Aucun, 1=Trémie, 2=P2, 3=P1, 4=Maintenance)

    M3_RelayFwd              : BOOL;   // 🔌 Sortie — contacteur sens avant M3 (STUB, DEGRADED_IO)
    M3_RelayRev              : BOOL;   // 🔌 Sortie — contacteur sens arrière M3 (STUB, DEGRADED_IO)
    M3_RelaySpeedGv          : BOOL;   // 🔌 Sortie — présélection GV M3 (STUB, DEGRADED_IO)

    // 🔧 Mirés activement par PRG_MAIN.st (bloc 🧪 SIMULATION) sur les commandes ci-dessus (contacteur "idéal")
    M3_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M3 (STUB, miroir de M3_RelayFwd)
    M3_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M3 (STUB, miroir de M3_RelayRev)

    // 🎯 Capteur position cible (PAS de miroir automatique — forcer manuellement en instance CODESYS, Partie11 §9bis)
    M3_PositionSensorTarget  : BOOL;   // 🔌 Entrée — capteur position cible M3 (STUB, arbitré par sélecteur ci-dessus)

    // 🔴 Retour défaut variateur — PAS de miroir, reste FALSE tant que non câblé
    M3_DriveFaultFeedback    : BOOL;   // 🔌 Entrée — défaut variateur TOR M3 (STUB, toujours FALSE)
END_VAR

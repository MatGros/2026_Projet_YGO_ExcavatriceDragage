(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Chariot_M3_Stub — Variables LOGICIELLES temporaires M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie11_Fonction_Chariot_v1.2.md §7
   🔧 2026-07-02 : renommage métier Translation→Chariot (demande utilisateur).
      Préfixe I/O physique M3 inchangé (mapping matériel).
   🔴 CORRECTIF (2026-07-02, nouvel export Device.export) : `M3_BrakeCmd`
      est désormais câblé en I/O Mapping RÉEL — RETIRÉ d'ici (conflit de
      nom sinon). Le reste (relais sens/PV-GV, retours, capteur cible,
      défaut variateur) reste STUB, pas encore câblé côté device.
   ⚠️ TEMPORAIRE — aucun relais/capteur réel piloté (hors BrakeCmd). Même
      principe que `GVL_Winch_M1_Stub.st`/`GVL_Winch_M2_Stub.st` : à
      supprimer dès que le matériel M3 restant sera câblé en I/O Mapping
      avec ces MÊMES noms (les deux mécanismes ne peuvent pas coexister —
      conflit de nom).
   🔴 M3_DriveFaultFeedback : laissé à FALSE (STUB) — NE PAS interpréter
      comme "pas de défaut variateur confirmé", c'est juste l'absence
      de retour câblé pour l'instant (Partie11 §3, ne jamais stubber
      un "pas de défaut" arbitraire comme s'il était réel).
   🎯 AJOUT (2026-07-02, demande utilisateur) : sélecteur STUB maintenance
      pour tester individuellement chaque capteur position réel du chariot
      (`PosiFosse1`/`PosFosse2`/`PosMaintenance`/`PosTremie`, câblés en I/O
      Mapping réel — hors ce GVL) AVANT que `FB_Cycle` existe pour piloter
      la sélection de cible en exploitation normale (Partie11 §9bis).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Chariot_M3_Stub) ===

VAR_GLOBAL
    M3_RelayFwd              : BOOL;   // 🔌 Sortie — contacteur sens avant M3 (STUB, DEGRADED_IO)
    M3_RelayRev              : BOOL;   // 🔌 Sortie — contacteur sens arrière M3 (STUB, DEGRADED_IO)
    M3_RelaySpeedGv          : BOOL;   // 🔌 Sortie — présélection GV M3 (STUB, DEGRADED_IO)

    // 🔧 Mirés activement par PRG_MAIN.st (bloc 🧪 SIMULATION) sur les commandes ci-dessus
    // (contacteur "idéal"), même principe que GVL_Winch_M1_Stub/M2_Stub.
    M3_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M3 (STUB, miroir de M3_RelayFwd)
    M3_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M3 (STUB, miroir de M3_RelayRev)
    M3_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M3 (STUB, miroir de M3_BrakeCmd — désormais I/O réel)

    // 🎯 Capteur position cible ARBITRÉ (PAS de miroir automatique — alimenté par le sélecteur
    // STUB ci-dessous en attendant FB_Cycle, Partie11 §9bis).
    M3_PositionSensorTarget  : BOOL;   // 🔌 Entrée FB_Chariot — capteur position cible arbitré (STUB)

    // 🔴 Retour défaut variateur — PAS de miroir, reste FALSE tant que non câblé (voir en-tête)
    M3_DriveFaultFeedback    : BOOL;   // 🔌 Entrée — défaut variateur TOR M3 (STUB, toujours FALSE)

    // 🎯 SÉLECTEUR STUB MAINTENANCE (2026-07-02) — choix manuel du capteur position réel à
    // tester, EN ATTENDANT la sélection de cible normale par FB_Cycle (pas encore codé).
    // 0 = aucun (M3_PositionSensorTarget reste FALSE) ; 1..4 = capteur réel correspondant.
    StubChariotPositionSelect_IHM : INT := 0;   // 🖥️ 0=Aucun, 1=Fosse1, 2=Fosse2, 3=Maintenance, 4=Trémie
END_VAR

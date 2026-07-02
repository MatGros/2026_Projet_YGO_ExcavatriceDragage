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
    // ⚠️ INUTILE de forcer ces 3 variables manuellement pour un essai (ex. homing) : le miroir
    // PRG_MAIN les réécrit CHAQUE cycle depuis M2_RelayFwd/Rev/M2_BrakeCmd — un forçage serait
    // écrasé au cycle suivant. Elles se stabilisent SEULES en environ 500 ms (DelayMotorDecel)
    // dès que le joystick reste au neutre (aucun mouvement commandé).
    M2_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M2 (STUB, miroir de M2_RelayFwd)
    M2_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M2 (STUB, miroir de M2_RelayRev)
    // 🔧 Polarité frein à manque de courant (confirmée FB_Brake.st §BrakeCmd / FB_Encoder_Homing.st
    // §ArretConfirme) : TRUE = relâché (bobine alimentée) ; FALSE = collé/serré (arrêt sûr tenu).
    M2_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M2 (STUB, miroir de M2_BrakeCmd — TRUE=relâché/FALSE=collé)

    // 🔴 CORRECTIF (2026-07-02, retour terrain) : le capteur de position haute a été RETIRÉ
    // d'ici — il n'y a qu'UN SEUL capteur physique, COMMUN aux 2 treuils (le grappin le touche
    // en montant), pas un par treuil. Voir désormais CODE/GVL_Homing_Stub.st
    // (`GrappinTopPositionSensor`), câblé identiquement sur instHomingM1 ET instHomingM2.
END_VAR

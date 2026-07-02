(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Winch_M1_Stub — Variables LOGICIELLES temporaires M1
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md §7 Étape 9bis
   ⚠️ TEMPORAIRE — aucun relais réel piloté. Créé uniquement pour
      compiler/tester la logique FB_Winch(M1) sans matériel branché
      (pas encore de carte de sortie/entrée disponible pour ce lot).
   🔴 QUAND LE MATÉRIEL SERA PRÊT : SUPPRIMER ce GVL entièrement, puis
      saisir les MÊMES noms directement dans la colonne "Variable" de
      l'onglet I/O Mapping des canaux physiques concernés (comme
      JoyXRaw_ANA1/JoyYRaw_ANA2/JoyBtnRaw) — CODESYS créera alors les
      variables globales réelles à cet endroit. Les DEUX déclarations
      (ce GVL + I/O Mapping) NE PEUVENT PAS coexister (conflit de nom).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Winch_M1_Stub) ===

VAR_GLOBAL
    M1_RelayFwd              : BOOL;   // 🔌 Sortie — contacteur sens avant M1 (STUB)
    M1_RelayRev              : BOOL;   // 🔌 Sortie — contacteur sens arrière M1 (STUB)
    M1_Contactor1            : BOOL;   // 🔌 Sortie — contacteur vitesse 1 M1 (STUB)
    M1_Contactor2            : BOOL;   // 🔌 Sortie — contacteur vitesse 2 M1 (STUB)
    M1_Contactor3            : BOOL;   // 🔌 Sortie — contacteur vitesse 3 M1 (STUB)
    M1_Contactor4            : BOOL;   // 🔌 Sortie — contacteur vitesse 4 M1 (STUB)
    M1_BrakeCmd              : BOOL;   // 🔌 Sortie — bobine frein M1 (STUB)
    // 🔧 CORRECTIF (revue de code) : PAS "toujours FALSE" — PRG_MAIN.st (bloc 🧪 SIMULATION)
    // mire activement ces 3 retours sur les commandes ci-dessus à chaque scan (contacteur idéal).
    // ⚠️ INUTILE de forcer ces 3 variables manuellement pour un essai (ex. homing) : le miroir
    // PRG_MAIN les réécrit CHAQUE cycle depuis M1_RelayFwd/Rev/M1_BrakeCmd — un forçage serait
    // écrasé au cycle suivant. Elles se stabilisent SEULES en environ 500 ms (DelayMotorDecel)
    // dès que le joystick reste au neutre (aucun mouvement commandé).
    M1_ContactorFeedbackFwd  : BOOL;   // 🔌 Entrée — retour contacteur sens avant M1 (STUB, miroir de M1_RelayFwd)
    M1_ContactorFeedbackRev  : BOOL;   // 🔌 Entrée — retour contacteur sens arrière M1 (STUB, miroir de M1_RelayRev)
    // 🔧 Polarité frein à manque de courant (confirmée FB_Brake.st §BrakeCmd / FB_Encoder_Homing.st
    // §ArretConfirme) : TRUE = relâché (bobine alimentée) ; FALSE = collé/serré (arrêt sûr tenu).
    M1_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M1 (STUB, miroir de M1_BrakeCmd — TRUE=relâché/FALSE=collé)

    // 🎯 AJOUT 2026-07-02 (lot Homing) — capteur position haute M1 (physique, PAS de miroir
    // automatique : reste FALSE tant que non forcé manuellement dans la vue instance CODESYS).
    // ⚠️ Homing volontairement IMPOSSIBLE tant que ce stub reste FALSE (sécurité : ne jamais
    // simuler un signal safety-relevant comme actif par défaut).
    M1_TopPositionSensor     : BOOL;   // 🔌 Entrée — capteur position haute M1 (STUB, toujours FALSE)
END_VAR

(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Winch_M1_Stub — Variables LOGICIELLES temporaires M1
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.1.md §7 Étape 9bis
   🔴 CORRECTIF (2026-07-02, nouvel export Device.export) : RelayFwd/Rev,
      Contactor1..4 (renommés `M1_SpeedContactor_1..4` côté device),
      BrakeCmd, ContactorFeedbackFwd/Rev sont désormais câblés en I/O
      Mapping RÉEL — RETIRÉS d'ici (conflit de nom sinon, les 2
      déclarations NE PEUVENT PAS coexister). Seul `M1_BrakeFeedback`
      reste non câblé côté device pour ce lot.
   ⚠️ TEMPORAIRE — `M1_BrakeFeedback` reste piloté par le miroir logiciel
      dans PRG_MAIN.st (bloc 🧪 SIMULATION) tant que le retour frein réel
      n'est pas câblé.
   🔴 QUAND LE MATÉRIEL SERA PRÊT : SUPPRIMER ce GVL entièrement, puis
      saisir le MÊME nom directement dans la colonne "Variable" de
      l'onglet I/O Mapping du canal physique concerné — CODESYS créera
      alors la variable globale réelle à cet endroit.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Winch_M1_Stub) ===

VAR_GLOBAL
    // 🔧 Polarité frein à manque de courant (confirmée FB_Brake.st §BrakeCmd / FB_Encoder_Homing.st
    // §ArretConfirme) : TRUE = relâché (bobine alimentée) ; FALSE = collé/serré (arrêt sûr tenu).
    M1_BrakeFeedback         : BOOL;   // 🔌 Entrée — retour contacteur frein M1 (STUB, miroir de M1_BrakeCmd — TRUE=relâché/FALSE=collé)
END_VAR

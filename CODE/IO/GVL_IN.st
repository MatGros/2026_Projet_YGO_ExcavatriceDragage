(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_IN — États conditionnés des entrées réelles (sortie de FB_InputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔧 AJOUT (2026-07-03quindecies, demande utilisateur) : les sorties conditionnées de
      `FB_InputsMachine` sont écrites ICI plutôt qu'en `VAR_OUTPUT` de l'instance —
      accès direct par tag global (`GVL_IN.Xxx`) depuis n'importe quel POU,
      plus pratique en LD que de déplier `instInputsMachine.Xxx`. Noms COURTS, sans
      suffixe (`GVL_IN.EmergencyStopOk`, pas `EmergencyStopOkState`) — le préfixe
      `GVL_IN.` suffit à indiquer qu'il s'agit de la valeur déjà conditionnée.
   ⚠️ Écart assumé à Partie2 §0 ("quasi pas de GVL, sauf échange IHM") — choix pragmatique
      utilisateur pour la lisibilité en Ladder, pas un oubli.
   🔴 Écrit UNIQUEMENT par `FB_InputsMachine` — ne jamais écrire ces variables ailleurs
      (lecture seule pour tous les autres consommateurs : Homing/Safety_Winch/Winch/
      Safety_Chariot/Chariot).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_IN) ===

VAR_GLOBAL
    // 🛑 COMMUN
    EmergencyStopOk      : BOOL;
    SlackCableSwitch     : BOOL;
    TopPositionSensor    : BOOL;
    PhaseRotationOk      : BOOL;   // 🆕 Contrôle rotation phases élec. — TRUE = correcte.
    // 🔧 RETIRÉ (2026-07-03duovicies, demande utilisateur) : init `:= TRUE` retirée — l'utilisateur
    // a créé son propre bypass dédié `GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST` (OR'é sur le
    // signal brut dans FB_InputsMachine), cohérent avec le pattern EmergencyStopOk/
    // TopPositionSensor (aucun des deux n'a d'init GVL_IN non plus). Voir AUDIT D75.

    // 🪝 WINCH M1
    M1ContactorFeedbackFwd : BOOL;
    M1ContactorFeedbackRev : BOOL;
    M1ThermalFeedback      : BOOL;
    M1BrakeFeedback        : BOOL;

    // 🪝 WINCH M2
    M2ContactorFeedbackFwd : BOOL;
    M2ContactorFeedbackRev : BOOL;
    M2ThermalFeedback      : BOOL;
    M2BrakeFeedback        : BOOL;

    // ↔️ CHARIOT M3
    ChariotPosFosse1      : BOOL;
    ChariotPosFosse2      : BOOL;
    ChariotPosMaintenance : BOOL;
    ChariotPosTremie      : BOOL;
    M3BrakeFeedback       : BOOL;
END_VAR

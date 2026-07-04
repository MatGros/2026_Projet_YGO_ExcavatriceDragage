(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_IN — Entrées machine CONDITIONNÉES (sortie de FB_InputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔴 ÉCRITURE : FB_InputsMachine SEULEMENT
   🔌 RÈGLE NC (capteurs de sécurité) : REPOS=TRUE ✅ | DÉFAUT/FIL COUPÉ=FALSE 🔴
   🔌 RÈGLE NO (position atteinte)    : REPOS=FALSE | ACTIONNÉ=TRUE ✅
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_IN) ===

VAR_GLOBAL

    // ── 🛑 SÉCURITÉS COMMUNES (NC — repos=TRUE sain, FALSE=défaut/fil coupé) ──────────────
    EmergencyStopOk      : BOOL;   // 🚨 Chaîne AU : TRUE=fermée/armée ✅ | FALSE=AU appuyé ou fil coupé 🔴
    TopPositionSensor    : BOOL;   // 🔝 Fin de course HAUT (NC) : TRUE=libre ✅ | FALSE=butée atteinte 🔴→ForbidAscent
    SlackCableSwitch     : BOOL;   // 🔗 Mou câble sur tambour M2 (NC) : TRUE=câble tendu ✅ | FALSE=mou détecté 🔴→ForbidDescent
    PhaseRotationOk      : BOOL;   // ⚡ Rotation phases élec. (NC) : TRUE=phases OK ✅ | FALSE=inversées/absentes 🔴→SafeStop

    // ── 🪝 TREUIL M1 (contacteurs=NO miroir bobine ; thermique/frein=NC) ────────────────
    M1ContactorFeedbackFwd : BOOL; // 📡 Retour contacteur MONTÉE M1 (NO) : TRUE=contacteur fermé | FALSE=ouvert
    M1ContactorFeedbackRev : BOOL; // 📡 Retour contacteur DESCENTE M1 (NO) : TRUE=contacteur fermé | FALSE=ouvert
    M1ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M1 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M1BrakeFeedback        : BOOL; // 🔒 Retour frein M1 (NC) : TRUE=frein serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2ContactorFeedbackFwd : BOOL; // 📡 Retour contacteur MONTÉE M2 (NO) : TRUE=fermé | FALSE=ouvert
    M2ContactorFeedbackRev : BOOL; // 📡 Retour contacteur DESCENTE M2 (NO) : TRUE=fermé | FALSE=ouvert
    M2ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M2 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M2BrakeFeedback        : BOOL; // 🔒 Retour frein M2 (NC) : TRUE=serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── ↔️ CHARIOT M3 (capteurs position=NO — position atteinte=TRUE) ────────────────────
    ChariotPosFosse1      : BOOL;  // 📍 Position fosse 1 (NO) : TRUE=chariot en fosse 1 ✅ | FALSE=absent
    ChariotPosFosse2      : BOOL;  // 📍 Position fosse 2 (NO) : TRUE=chariot en fosse 2 ✅ | FALSE=absent
    ChariotPosMaintenance : BOOL;  // 🔧 Position maintenance (NO) : TRUE=en position service ✅ | FALSE=absent
    ChariotPosTremie      : BOOL;  // 🗑️ Position trémie vidange (NO) : TRUE=en position trémie ✅ | FALSE=absent
    M3BrakeFeedback       : BOOL;  // 🔒 Retour frein chariot M3 (NC) : TRUE=serré repos ✅ | FALSE=desserré 🔴

END_VAR

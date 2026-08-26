(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationInterPrg — Bus d'échange inter-PRG produit par PRG_05_Translation
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler la demande finale M3, l'état public TranslationState
      et le diagnostic TranslationSafety publiés par PRG_05_Translation vers
      les consommateurs (PRG_03/06/07).
   📤 Producteur unique : PRG_05_Translation (VAR_OUTPUT Data : ST_TranslationInterPrg).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_TranslationInterPrg :
STRUCT
    // === ⚡ Demande finale M3 ===
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest; // ↔️ Demande finale et interlocks translation M3

    // === 📊 État public translation ===
    TranslationState                 : ST_TranslationState; // 🚦 Etat public translation M3

    // === 🛡️ Sécurité translation ===
    TranslationSafety                : ST_SafetyTranslation; // 🛡️ Diagnostic et securites translation M3
END_STRUCT
END_TYPE

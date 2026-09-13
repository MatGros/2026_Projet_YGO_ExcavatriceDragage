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

    // === 🎯 Faits decodeur position M3 (produits par PRG_05, AF-02 TBD §8 #5) ===
    M3_SensorWordIncoherent   : BOOL; // ❌ Incoherence detectee mot capteurs M3

    // === ⚙️ États dynamiques & positions stables translation M3 ===
    TranslationBusy           : BOOL; // ⚙️ Translation M3 en mouvement effectif
    TranslationDone           : BOOL; // ✅ Cible translation atteinte et confirmee
    M3_AtTremieStable         : BOOL; // 🎯 M3 positionne stable a la Tremie
    M3_AtP1Stable             : BOOL; // 🎯 M3 positionne stable au Point 1
    M3_AtMaintenanceStable    : BOOL; // 🎯 M3 positionne stable en zone Maintenance
    M3_AtWorkPositionStable   : BOOL; // 🎯 M3 arrete a une position de travail (P1 ou Maintenance) — STATIQUE (mot capteurs), vrai des le boot sans franchissement. Consomme par le verrou descente treuil T249-A.

    // === 🕵️ Trace de blocage terrain (consommée FB_TroubleshootingView) ===
    TranslationTrace             : ST_TraceTranslation; // 🕵️ Trace blocage translation M3 (cause priorisée + horodatage)
END_STRUCT
END_TYPE

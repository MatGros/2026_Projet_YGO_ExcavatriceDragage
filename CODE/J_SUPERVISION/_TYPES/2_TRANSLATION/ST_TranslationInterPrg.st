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
    TranslationPosTremie      : BOOL; // 📍 Zone Tremie (1=Present)
    TranslationPosPV          : BOOL; // 📍 Zone pre-ralentissement PV (1=Present)
    TranslationPosP2          : BOOL; // 📍 Zone P2 (1=Present)
    TranslationPosP1          : BOOL; // 📍 Zone P1 (1=Present)
    TranslationPosMaintenance : BOOL; // 📍 Zone Maintenance (1=Present)
    TranslationAtTremie       : BOOL; // 🎯 Position exacte Tremie (1=Atteint)
    TranslationAtPV           : BOOL; // 🎯 Position exacte PV (1=Atteint)
    TranslationAtP2           : BOOL; // 🎯 Position exacte P2 (1=Atteint)
    TranslationAtP1           : BOOL; // 🎯 Position exacte P1 (1=Atteint)
    TranslationAtMaintenance  : BOOL; // 🎯 Position exacte Maintenance (1=Atteint)
    M3_LimitSwitchFwd         : BOOL; // 🛡️ Fin de course avant M3 (1=Actionne)
    M3_LimitSwitchRev         : BOOL; // 🛡️ Fin de course arriere M3 (1=Actionne)
    M3_SensorWordIncoherent   : BOOL; // ❌ Incoherence detectee mot capteurs M3
    M3_SensorsWord             : BYTE; // 📊 Mot d'etat capteurs M3

    // === ⚙️ États dynamiques & positions stables translation M3 ===
    TranslationBusy           : BOOL; // ⚙️ Translation M3 en mouvement effectif
    TranslationDone           : BOOL; // ✅ Cible translation atteinte et confirmee
    M3_AtTremieStable         : BOOL; // 🎯 M3 positionne stable a la Tremie
    M3_AtP1Stable             : BOOL; // 🎯 M3 positionne stable au Point 1
    M3_AtMaintenanceStable    : BOOL; // 🎯 M3 positionne stable en zone Maintenance

    // === 🕵️ Trace de blocage terrain (consommée FB_TroubleshootingView) ===
    TranslationTrace             : ST_TraceTranslation; // 🕵️ Trace blocage translation M3 (cause priorisée + horodatage)
END_STRUCT
END_TYPE

(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests — Variables globales du banc de validation
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de données pour l'IHM et rapports de tests
      conformément à la spécification v1.2 de l'AF Partie 14.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    Cmd                        : ST_PlcTestsCmd;      // 🎮 Commandes de pilotage des tests
    Status                     : ST_PlcTestsStatus;   // 🚦 Progression et statut des tests

    // 📊 Rapports par suite — 1 variable NOMMÉE par suite (pas de tableau générique,
    // choix utilisateur 2026-07-16) : chaque nouvelle suite ajoute SA variable ici
    // (ex. SuiteWinchValidation à venir), jamais un index à retenir.
    SuiteSafetyValidation      : ST_TestSuiteReport;  // Rapport de la suite Safety
    SuiteTranslationValidation : ST_TestSuiteReport;  // Rapport de la suite Translation M3
    SuiteBucketValidation      : ST_TestSuiteReport;  // Rapport de la suite Bucket

    // ⚡ Surcharges (overrides) physiques lues par PRG_00_Inputs — chaîne Safety AU
    OverrideChainTrue          : BOOL;                // Force la boucle AU à TRUE
    OverrideChainFalse         : BOOL;                // Force la boucle AU à FALSE
    OverrideContactorFalse     : BOOL;                // Force le retour contacteur à FALSE

    // ⚡ Surcharges (overrides) physiques lues par PRG_00_Inputs — Translation M3
    // (niveau capteur amont uniquement, jamais une sortie de commande calculée — voir
    // AF_Partie-14 §7.3.2/§7.5.5)
    OverrideM3AtTremie         : BOOL;                // Force TranslationPosTremie (Fdc extrême avant) à TRUE
    OverrideM3BrakeStuckOpen   : BOOL;                // Force M3BrakeFeedback (retour bobine) à TRUE (desserré) — simule Méca B
    OverrideM3PhantomFreq      : BOOL;                // Force M3_ActualFrequencyHz_Filtered à 1.00Hz malgré arrêt commandé — simule Méca A

    // ⚡ Surcharges (overrides) physiques — Bucket
    OverrideM1Slip           : BOOL;                // Simule glissement modéré M1 (1.5m)
    OverrideM1SlipCritical   : BOOL;                // Simule glissement critique M1 (2.5m)
    OverrideM2Stuck          : BOOL;                // Simule blocage mécanique M2 (position figée)
    OverrideM2BootDrift      : BOOL;                // Simule dérive position M2 au démarrage (Boot)
END_VAR

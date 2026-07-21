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
    EventLog                   : ARRAY[1..GVL_PLC_Tests_Const.MaxTestEvents] OF ST_TestEvent;
    EventCount                 : INT;
    EventSequence              : UDINT;
    EventOverflow              : BOOL;

    // 📊 Rapports par suite — 1 variable NOMMÉE par suite (pas de tableau générique,
    // choix utilisateur 2026-07-16) : chaque nouvelle suite ajoute SA variable ici
    // (ex. SuiteWinchValidation à venir), jamais un index à retenir.
    SuiteSafetyValidation      : ST_TestSuiteReport;  // Rapport de la suite Safety
    SuiteTranslationValidation : ST_TestSuiteReport;  // Rapport de la suite Translation M3
    SuiteBucketValidation      : ST_TestSuiteReport;  // Rapport de la suite Bucket
    SuiteEncoderValidation     : ST_TestSuiteReport;  // Rapport de la suite Codeurs/Homing nominal
    SuiteModesValidation       : ST_TestSuiteReport;  // Rapport de la suite Modes/Homme-mort (post-IHM_MANU)
    SuiteHeartbeatValidation   : ST_TestSuiteReport;  // Rapport de la suite Heartbeat IHM↔PLC

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
    // 🆕 REX 2026-07-18 : force directement les 5 capteurs position M3 depuis un mot de test —
    // seul moyen de tester les 6 mots valides ET les combinaisons incohérentes indépendamment
    // du temps de trajet simulé (FB_Sim_Translation). bit4=Trémie,bit3=PV,bit2=P2,bit1=P1,bit0=Maintenance.
    OverrideM3SensorsWordActive : BOOL;                // TRUE = force les 5 capteurs depuis OverrideM3SensorsWord
    OverrideM3SensorsWord       : BYTE;                // Mot de test (voir FB_Translation_PositionDecoder)

    // ⚡ Surcharges (overrides) physiques — Bucket
    OverrideM1Slip           : BOOL;                // Simule glissement modéré M1 (1.5m)
    OverrideM1SlipCritical   : BOOL;                // Simule glissement critique M1 (2.5m)
    OverrideM2Stuck          : BOOL;                // Simule blocage mécanique M2 (position figée)
    OverrideM2BootDrift      : BOOL;                // Simule dérive position M2 au démarrage (Boot)

    // ⚡ Surcharges (overrides) — Joystick (SUITE_MODES, 2026-07-19, voir FB_Sim_Joystick)
    OverrideJoystickActive     : BOOL;              // TRUE = RawX/Y/Button pilotés par les 3 champs suivants
    OverrideJoystickRawX       : INT;                // Débattement axe X simulé (5000=neutre, 10000=fond)
    OverrideJoystickRawY       : INT;                // Débattement axe Y simulé (5000=neutre, 10000=fond)
    OverrideJoystickRawButton  : BOOL;               // Appui homme-mort simulé

    // 💓 Heartbeat IHM↔PLC — stimulus AMONT uniquement, consommé par PRG_01.
    // Aucun test n'écrit dans HeartbeatIhmOk/SafeStop/PowerCutOff calculés.
    OverrideIhmHeartbeatActive : BOOL;               // TRUE = le banc fournit le toggle IHM
    OverrideIhmHeartbeatToggle : BOOL;               // Valeur IHM→PLC, figée ou inversée par FB_HeartbeatValidation

    // 🛡️ Surcharges retours arrêt M1/M2 — polaires inversées : arrêt confirmé = TRUE.
    OverrideM1FwdRevSpeedFbOff : BOOL;               // TRUE = contacteurs retombés (sain)
    OverrideM1BrakeFeedback    : BOOL;               // TRUE = frein serré (sain)
    OverrideM2FwdRevSpeedFbOff : BOOL;               // TRUE = contacteurs retombés (sain)
    OverrideM2BrakeFeedback    : BOOL;               // TRUE = frein serré (sain)
END_VAR

// ═══════════════════════════════════════════════════════════════
// 🧪 ST_PlcTestsCmd — Commandes de pilotage du banc de validation
// ═══════════════════════════════════════════════════════════════

TYPE ST_PlcTestsCmd :
STRUCT
    // Commandes unitaires : une seule suite manuelle à la fois.
    RunSafety     : BOOL;   // Lance la suite Safety
    RunTranslation: BOOL;   // Lance la suite Translation
    RunBucket     : BOOL;   // Lance la suite Benne
    RunEncoder    : BOOL;   // Lance la suite Codeurs/Homing
    RunModes      : BOOL;   // Lance la suite Modes/Homme-mort
    RunHeartbeat  : BOOL;   // Lance la suite Heartbeat IHM↔PLC
    RunFramework  : BOOL;   // Lance l'autotest indépendant du framework
    RunAll        : BOOL;   // Déprécié : ignoré, aucune campagne automatique
    RunSuite      : INT;    // Compatibilité : >0 lance une suite manuelle
    RunCase       : INT;    // Cas de la commande unitaire sélectionnée
    Abort         : BOOL;   // Abandonne le test en cours
    ClearReport   : BOOL;   // Efface les rapports de tests
END_STRUCT
END_TYPE

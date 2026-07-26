// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestCaseResult — Résultat d'un cas de test
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestCaseResult :
STRUCT
    Name         : STRING(32);       // 🏷️ Libellé lisible (copié de CaseTable[i].Name) — identifie le cas sans chercher l'index
    Executed     : BOOL;             // Le cas de test a-t-elle été exécuté (ex. non exécuté si setup précédent abort)
    Ok           : BOOL;             // Succès global du cas de test
    FailedStepId : INT;              // Index de la première étape en échec (0 si aucune)
    FailReason   : E_TestFailReason; // Cause de l'échec global du cas de test
    Duration     : TIME;             // Durée totale du cas de test
END_STRUCT
END_TYPE

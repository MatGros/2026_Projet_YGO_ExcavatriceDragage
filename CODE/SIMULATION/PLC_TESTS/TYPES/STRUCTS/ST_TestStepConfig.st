// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestStepConfig — Configuration d'une étape de test
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestStepConfig :
STRUCT
    Name       : STRING(32);         // Libellé IHM + rapport
    CaseId     : INT;                // Rattachement au cas de test
    StimulusId : INT;                // Id du stimulus appliqué (0 = neutre)
    CheckIdx   : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF INT; // Index des checks (0 = vide)
    DwellPT    : TIME;               // Temporisation avant évaluation
    MinPT      : TIME;               // Fenêtre temporelle minimale
    TimeoutPT  : TIME;               // Temps limite pour réussir l'étape
    NextOnPass : INT;                // Étape suivante en cas de succès (0 = fin)
    NextOnFail : INT;                // Étape suivante en cas d'échec (souvent teardown, 0 = fin)
    FailAction : E_TestFailAction;   // Action en cas d'échec (continuer ou arrêter la suite)
END_STRUCT
END_TYPE

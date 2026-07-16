// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestStimAnalogConfig — Configuration d'un stimulus instrumenté
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestStimAnalogConfig :
STRUCT
    Kind       : E_TestStimKind;     // Type de stimulus (pulse, rampe, séquence)
    StartReal  : REAL;               // Valeur de départ pour la rampe
    TargetReal : REAL;               // Valeur cible pour la rampe
    PulsePT    : TIME;               // Durée de l'impulsion (PULSE_BOOL)
    RampPT     : TIME;               // Durée de transition de la rampe
    SeqValues  : ARRAY[1..GVL_PLC_Tests_Const.MaxSeqValues] OF REAL; // Valeurs de la séquence
    SeqCount   : INT;                // Nombre de valeurs utilisées dans la séquence
    SeqDwellPT : TIME;               // Temps de maintien de chaque valeur de la séquence
END_STRUCT
END_TYPE

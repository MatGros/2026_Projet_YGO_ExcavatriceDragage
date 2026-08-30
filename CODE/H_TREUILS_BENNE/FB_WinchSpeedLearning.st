(* =======================================================================
   💾 FB_WinchSpeedLearning — Collecteur passif vitesse par palier
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Apprentissage passif des vitesses reelles par palier (RETAIN)
   📄 Doc metier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔒 Collecteur pur : aucune commande moteur, aucune surveillance survitesse
   ======================================================================= *)

FUNCTION_BLOCK FB_WinchSpeedLearning
VAR_INPUT
    // === CONTRAT LIGHT (Enable) ===
    Enable                          : BOOL;   // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    LearnStart                      : BOOL;   // --> [CMD] Bit IHM lancer apprentissage
    WinchId                         : INT;    // --> [CMD] Axe cible (1=M1, 2=M2)
    Direction                       : INT;    // --> [HW] Sens mesure (-1 descente, 0 stop, +1 montee)
    StepNumber                      : INT;    // --> [HW] Palier actif (1..5)
    MeasuredSpeedMps                : REAL;   // --> [HW] Vitesse mesuree (m/s)
    MeasuredSpeedValid              : BOOL;   // --> [HW] Mesure exploitable
    LoadPresent                     : BOOL;   // --> [HW] Charge presente (TRUE=charge, FALSE=vide)
    StableForLearn                  : BOOL;   // --> [HW] Conditions stables pour apprentissage

    // === REGLAGES & CONFIGURATION ===
    Config                          : ST_fbWinchSpeedLearning_Cfg; // --> [CFG] Enveloppes de plausibilite par palier
END_VAR
VAR_OUTPUT
    // === CONTRAT LIGHT (Ready) ===
    Ready                           : BOOL;   // <-- [STAT] FB pret (Enable)

    // === ETATS & DIAGNOSTIC ===
    Learning                        : BOOL;   // <-- [STAT] Collecte en cours
    TableComplete                   : BOOL;   // <-- [STAT] Table charge ET vide complete
    LampLearn                       : BOOL;   // <-- [STAT] Voyant IHM apprentissage
    CellsFilled                     : INT;    // <-- [DIAG] Nombre de cellules validees
    CellsTotal                      : INT;    // <-- [DIAG] Nombre total de cellules
END_VAR
VAR_IN_OUT
    // === STRUCTURES DE DONNEES PARTAGEES ===
    Table                           : ST_fbWinchSpeedLearning_Table; // <-> [BUS] Table RETAIN apprentissage
END_VAR
VAR
    // === VARIABLES LOCALES CALCULEES ===
    LearnRequested                  : BOOL;   // . [LOC] Bit IHM + Enable
    MeasureUsable                   : BOOL;   // . [LOC] Mesure valide + conditions stables
    SensActive                      : BOOL;   // . [LOC] Sens non nul
    StepInRange                     : BOOL;   // . [LOC] Palier dans 1..5
    AxeInRange                      : BOOL;   // . [LOC] Axe dans 1..2
    ContextValid                    : BOOL;   // . [LOC] Sens, palier et axe dans le domaine
    CollectAllowed                  : BOOL;   // . [LOC] Conditions de collecte reunies
    SpeedPlausible                  : BOOL;   // . [LOC] Vitesse dans l'enveloppe du palier
    SensIdx                         : INT;    // . [LOC] Index sens (1=montee, 2=descente)
    ChargeIdx                       : INT;    // . [LOC] Index charge (1=vide, 2=charge)
    CurrentCell                     : ST_fbWinchSpeedLearning_Cell; // . [LOC] Cellule courante
    AxeIdx                          : INT;    // . [LOC] Index axe boucle
    SensLoopIdx                     : INT;    // . [LOC] Index sens boucle
    ChargeLoopIdx                   : INT;    // . [LOC] Index charge boucle
    PalierIdx                       : INT;    // . [LOC] Index palier boucle
END_VAR
VAR CONSTANT
    CST_AxeCount                    : INT := 2;   // Nombre d'axes (M1, M2)
    CST_SensCount                   : INT := 2;   // Nombre de sens (ascending, descending)
    CST_ChargeCount                 : INT := 2;   // Nombre d'etats de charge (vide, charge)
    CST_PalierCount                 : INT := 5;   // Nombre de paliers (1..5)
    CST_IdxAscending                : INT := 1;   // Index sens ascending
    CST_IdxDescending               : INT := 2;   // Index sens descending
    CST_IdxVide                     : INT := 1;   // Index charge vide
    CST_IdxCharge                   : INT := 2;   // Index charge presente
END_VAR

{region "§1 Gate et conditions de collecte"}
Ready := Enable;
Learning := FALSE;
LampLearn := FALSE;

// Conditions de collecte scindees (lisibilite Watch, <=3 termes par predicat)
LearnRequested := Enable AND LearnStart;
MeasureUsable := MeasuredSpeedValid AND StableForLearn;
SensActive := (Direction <> 0);
StepInRange := (StepNumber >= 1) AND (StepNumber <= CST_PalierCount);
AxeInRange := (WinchId >= 1) AND (WinchId <= CST_AxeCount);
ContextValid := SensActive AND StepInRange AND AxeInRange;
CollectAllowed := LearnRequested AND MeasureUsable AND ContextValid;
{endregion}

{region "§2 Collecte passive"}
IF CollectAllowed THEN
    // Index sens et charge
    IF Direction > 0 THEN SensIdx := CST_IdxAscending; ELSE SensIdx := CST_IdxDescending; END_IF;
    IF LoadPresent THEN ChargeIdx := CST_IdxCharge; ELSE ChargeIdx := CST_IdxVide; END_IF;

    // Plausibilite : vitesse dans l'enveloppe du palier (borne min/max)
    SpeedPlausible := (MeasuredSpeedMps >= Config.MinSpeedMps[StepNumber])
                      AND (MeasuredSpeedMps <= Config.MaxSpeedMps[StepNumber]);

    CurrentCell := Table.Cell[WinchId, SensIdx, ChargeIdx, StepNumber];
    IF SpeedPlausible THEN
        // Accumulation (moyenne glissante)
        IF CurrentCell.SampleCount = 0 THEN
            CurrentCell.SpeedMps := MeasuredSpeedMps;
            CurrentCell.SampleCount := 1;
        ELSE
            CurrentCell.SpeedMps := (CurrentCell.SpeedMps * UDINT_TO_REAL(CurrentCell.SampleCount) + MeasuredSpeedMps)
                                    / UDINT_TO_REAL(CurrentCell.SampleCount + 1);
            CurrentCell.SampleCount := CurrentCell.SampleCount + 1;
        END_IF;
        CurrentCell.Valid := (CurrentCell.SampleCount >= Config.MinSamples);
    ELSE
        // Valeur hors enveloppe -> cellule invalidee
        CurrentCell.Valid := FALSE;
        CurrentCell.SampleCount := 0;
        CurrentCell.SpeedMps := 0.0;
    END_IF;
    Table.Cell[WinchId, SensIdx, ChargeIdx, StepNumber] := CurrentCell;

    Learning := TRUE;
    LampLearn := TRUE;
END_IF;
{endregion}

{region "§3 Comptage et completude"}
CellsTotal := CST_AxeCount * CST_SensCount * CST_ChargeCount * CST_PalierCount;
CellsFilled := 0;
FOR AxeIdx := 1 TO CST_AxeCount DO
    FOR SensLoopIdx := 1 TO CST_SensCount DO
        FOR ChargeLoopIdx := 1 TO CST_ChargeCount DO
            FOR PalierIdx := 1 TO CST_PalierCount DO
                IF Table.Cell[AxeIdx, SensLoopIdx, ChargeLoopIdx, PalierIdx].Valid THEN
                    CellsFilled := CellsFilled + 1;
                END_IF;
            END_FOR;
        END_FOR;
    END_FOR;
END_FOR;
TableComplete := (CellsFilled >= CellsTotal);
{endregion}

(* =======================================================================
   FB_SpeedStep — Décodeur palier vers contacteurs
   Rôle : applique les bornes de palier puis lit la table contacteurs.
   Le calcul de la consigne discrète est fait par le producteur amont.
   ======================================================================= *)

{attribute 'qualified_only'}
{attribute 'hide_all_locals'}

FUNCTION_BLOCK PUBLIC FB_SpeedStep
VAR_INPUT
    Enable                          : BOOL;
    SpeedStepReq                    : INT := 0;                       // --> [CMD] Palier demandé (0..5)
    Table                           : ST_SpeedStepTable;              // --> [CFG] Table contacteurs propre au treuil
    MinStepNumber                   : INT := 1;                       // --> [CFG] Plancher palier, rétro-compatible
    MaxStepNumber                   : INT := 5;                       // --> [CFG] Plafond palier atteignable
END_VAR
VAR_OUTPUT
    StepNumber                      : INT;                            // <-- [STAT] Palier actif (0..5)
    Contactor1                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 1
    Contactor2                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 2
    Contactor3                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 3
    Contactor4                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 4
    ConfigError                     : BOOL;                           // <-- [DIAG] Table de paliers invalide
    ConfigErrorId                   : WORD;                           // <-- [DIAG] Bitfield erreur table
END_VAR
VAR
    _ConfigValid                    : BOOL;
    _ConfigErrorIdInt               : WORD;
    _MaxStepClamped                 : INT;
    _MinStepClamped                 : INT;
END_VAR

{region "§0 Bornes et validation table"}
// Le plafond est borné avant le plancher : si le plancher demandé dépasse le
// plafond de sécurité, celui-ci garde la priorité.
_MaxStepClamped := LIMIT(1, MaxStepNumber, 5);
_MinStepClamped := LIMIT(1, MinStepNumber, _MaxStepClamped);

// Les seuils restent validés pour conserver le diagnostic table historique.
// Ils ne participent plus au calcul du palier dans ce FB.
_ConfigValid := TRUE;
_ConfigErrorIdInt := 16#0000;
IF NOT (Table.StepThreshold_Pct[1] < Table.StepThreshold_Pct[2] AND
        Table.StepThreshold_Pct[2] < Table.StepThreshold_Pct[3] AND
        Table.StepThreshold_Pct[3] < Table.StepThreshold_Pct[4] AND
        Table.StepThreshold_Pct[4] < Table.StepThreshold_Pct[5]) THEN
    _ConfigValid := FALSE;
    _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
END_IF;
IF (Table.StepThreshold_Pct[1] < 0.0) OR (Table.StepThreshold_Pct[5] > 100.0) THEN
    _ConfigValid := FALSE;
    _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
END_IF;
ConfigErrorId := _ConfigErrorIdInt;
ConfigError := (ConfigErrorId <> 16#0000);
{endregion}

{region "§1 Gate"}
// Relâche ou table invalide : aucun plancher ne peut maintenir un contacteur.
IF (NOT Enable) OR (NOT _ConfigValid) OR (SpeedStepReq <= 0) THEN
    StepNumber := 0;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Clamp et table contacteurs"}
// Le plancher agit sur la cible. StepNumber ne reçoit jamais directement
// MinStepNumber ; LIMIT final garantit la plage 1..5 après le plafond.
StepNumber := LIMIT(_MinStepClamped, SpeedStepReq, _MaxStepClamped);

CASE StepNumber OF
    1:  Contactor1 := Table.P1R1; Contactor2 := Table.P1R2; Contactor3 := Table.P1R3; Contactor4 := Table.P1R4;
    2:  Contactor1 := Table.P2R1; Contactor2 := Table.P2R2; Contactor3 := Table.P2R3; Contactor4 := Table.P2R4;
    3:  Contactor1 := Table.P3R1; Contactor2 := Table.P3R2; Contactor3 := Table.P3R3; Contactor4 := Table.P3R4;
    4:  Contactor1 := Table.P4R1; Contactor2 := Table.P4R2; Contactor3 := Table.P4R3; Contactor4 := Table.P4R4;
    5:  Contactor1 := Table.P5R1; Contactor2 := Table.P5R2; Contactor3 := Table.P5R3; Contactor4 := Table.P5R4;
ELSE
    // Défense en profondeur face à une divergence type/outil.
    StepNumber := 0;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_CASE;
{endregion}

END_FUNCTION_BLOCK

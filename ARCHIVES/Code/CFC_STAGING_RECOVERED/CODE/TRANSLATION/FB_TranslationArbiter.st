(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationArbiter — Arbitrage des consignes M3
   ───────────────────────────────────────────────────────────────
   📄 Migration M4 : extrait sans changement la logique de page de
      PRG_TRANSLATION_CFC.st afin que le CFC natif ne porte aucun IF/CASE.
   🔒 Ce FB ne commande aucun actionneur : il produit uniquement la demande
      arbitrée consommée par FB_Translation.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationArbiter
VAR_INPUT
    Mode                         : E_Mode;
    AutoStart                    : BOOL;
    AutoTarget                   : INT;
    DeadmanArmed                 : BOOL;
    AxisCmd                      : ST_Joystick_AxisCmd;
    MaintenancePositioning       : BOOL;
    MaintenanceTarget            : INT;
    BtnFwd                       : BOOL;
    BtnRev                       : BOOL;
    TglJoystickMaster            : BOOL;
    SetFreqHz                    : REAL;
    BypassGlobal                 : BOOL;
    InvertDirection              : BOOL;
    MaintenanceM3TargetEnable    : BOOL;
    PosTremie                    : BOOL;
    PosP2                        : BOOL;
    PosP1                        : BOOL;
    PosMaintenance               : BOOL;
    AutoSpeedCapPct              : REAL;
    TranslationMaxFreqHz         : REAL;
END_VAR
VAR_OUTPUT
    StartStop                    : BOOL;
    Direction                    : INT;
    SpeedRefPct                  : REAL;
    PositionSensorTarget         : BOOL;
    PositioningActive            : BOOL;
    SelectedTarget               : INT;
END_VAR
VAR
    FreqPct                      : REAL;
END_VAR

(* ── Arbitrage sources Semi-auto / Maintenance / conduite manuelle ── *)
IF Mode = E_Mode.SEMI_AUTO THEN
    PositioningActive := TRUE;
    SelectedTarget := AutoTarget;
    StartStop := AutoStart AND DeadmanArmed AND AxisCmd.StartStop;
    SpeedRefPct := ABS(AxisCmd.SpeedRef);
    IF SpeedRefPct > AutoSpeedCapPct THEN
        SpeedRefPct := AutoSpeedCapPct;
    END_IF;

    IF SelectedTarget = 1 THEN
        Direction := 1;
    ELSE
        Direction := -1;
    END_IF;
ELSIF (Mode = E_Mode.MAINT_N1) OR (Mode = E_Mode.MAINT_N2) THEN
    PositioningActive := MaintenancePositioning;
    IF PositioningActive THEN
        SelectedTarget := MaintenanceTarget;
    ELSE
        SelectedTarget := 0;
    END_IF;

    IF (NOT TglJoystickMaster) AND BtnFwd THEN
        Direction := 1;
    ELSIF (NOT TglJoystickMaster) AND BtnRev THEN
        Direction := -1;
    ELSIF TglJoystickMaster THEN
        Direction := AxisCmd.Direction;
    ELSE
        Direction := 0;
    END_IF;

    StartStop := (Direction <> 0)
                 AND (DeadmanArmed OR BypassGlobal)
                 AND ((NOT TglJoystickMaster) OR AxisCmd.StartStop);

    IF SetFreqHz > 0.0 THEN
        FreqPct := (SetFreqHz / TranslationMaxFreqHz) * 100.0;
    ELSE
        FreqPct := 30.0;
    END_IF;

    IF TglJoystickMaster THEN
        SpeedRefPct := (ABS(AxisCmd.SpeedRef) / 100.0) * FreqPct;
    ELSE
        SpeedRefPct := FreqPct;
    END_IF;
ELSE
    PositioningActive := FALSE;
    SelectedTarget := MaintenanceTarget;
    StartStop := AxisCmd.StartStop;
    Direction := AxisCmd.Direction;
    SpeedRefPct := AxisCmd.SpeedRef;
END_IF;

(* ── Gardes conservation : inversion, borne vitesse, MAINT_N2 et cible ── *)
IF InvertDirection THEN
    Direction := Direction * (-1);
END_IF;

SpeedRefPct := ABS(SpeedRefPct);
IF SpeedRefPct > 100.0 THEN
    SpeedRefPct := 100.0;
END_IF;

IF (SelectedTarget = 4) AND (NOT MaintenanceM3TargetEnable) THEN
    SelectedTarget := 0;
END_IF;

CASE SelectedTarget OF
    1: PositionSensorTarget := PosTremie;
    2: PositionSensorTarget := PosP2;
    3: PositionSensorTarget := PosP1;
    4: PositionSensorTarget := PosMaintenance;
ELSE
    PositionSensorTarget := FALSE;
END_CASE;

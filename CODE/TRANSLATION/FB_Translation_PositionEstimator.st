(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Translation_PositionEstimator — Estimateur de Position Continue M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v2.1.md §3
   🎯 Rôle : Calculer par odométrie (intégration temporelle vitesse/fréquence Hz * sens)
      la position estimée continue en mètres (0.0 m à la Maintenance -> +X m à la Trémie),
      avec re-calage absolu automatique instantané sur le franchissement des 5 capteurs fixes.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation_PositionEstimator
VAR_INPUT
    Enable               : BOOL;   (* Active le calcul *)
    Reset                : BOOL;   (* Front d'acquittement / réinitialisation *)
    DriveActualFreqHz    : REAL;   (* Fréquence réelle variateur en Hz (ex: 5.0 Hz) *)
    Direction            : INT;    (* Sens effectif : +1 = Fwd (vers Trémie), -1 = Rev (vers Maint), 0 = Arrêt *)
    
    (* 5 Capteurs de position fixes *)
    SensorMaintenance    : BOOL;   (* Capteur 0 : Maintenance (0.0 m) *)
    SensorP1             : BOOL;   (* Capteur 1 : P1 (ex: 6.0 m) *)
    SensorP2             : BOOL;   (* Capteur 2 : P2 (ex: 14.0 m) *)
    SensorPV             : BOOL;   (* Capteur 3 : PV (ex: 21.0 m) *)
    SensorTremie         : BOOL;   (* Capteur 4 : Trémie (ex: 25.0 m) *)

    (* Positions de référence calibrées (mètres) depuis GVL_PERSISTENT *)
    PosMaintenanceM      : REAL := 0.0;
    PosP1M               : REAL := 6.0;
    PosP2M               : REAL := 14.0;
    PosPVM               : REAL := 21.0;
    PosTremieM           : REAL := 25.0;

    (* Gain de vitesse : mètres parcourus par Hz par seconde (ex: 50 Hz = 0.416 m/s => Gain = 0.008333 m/Hz.s) *)
    GainMetersPerHzSec   : REAL := 0.008333;
END_VAR

VAR_OUTPUT
    PositionEstimatedM   : REAL;   (* Position continue estimée en mètres *)
    Recalibrated         : BOOL;   (* Pulse 1 cycle lors d'un recalage sur capteur *)
    RecalibratedSensorId : INT;    (* 0=Maint, 1=P1, 2=P2, 3=PV, 4=Trémie, -1=Aucun *)
END_VAR

VAR
    TrigTremie           : R_TRIG;
    TrigPV               : R_TRIG;
    TrigP2               : R_TRIG;
    TrigP1               : R_TRIG;
    TrigMaintenance      : R_TRIG;
    CycleTimeCalc        : FB_CycleTime;
    Initialized          : BOOL;
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    Recalibrated := FALSE;
    RecalibratedSensorId := -1;
    RETURN;
END_IF;

CycleTimeCalc(DefaultValueS := 0.010);
Recalibrated := FALSE;

// 1. Détection des fronts montants sur franchissement des capteurs fixes
TrigTremie(CLK := SensorTremie);
TrigPV(CLK := SensorPV);
TrigP2(CLK := SensorP2);
TrigP1(CLK := SensorP1);
TrigMaintenance(CLK := SensorMaintenance);

// 2. Recalage absolu prioritaire sur contact capteur
IF TrigMaintenance.Q THEN
    PositionEstimatedM := PosMaintenanceM;
    Recalibrated := TRUE;
    RecalibratedSensorId := 0;
ELSIF TrigP1.Q THEN
    PositionEstimatedM := PosP1M;
    Recalibrated := TRUE;
    RecalibratedSensorId := 1;
ELSIF TrigP2.Q THEN
    PositionEstimatedM := PosP2M;
    Recalibrated := TRUE;
    RecalibratedSensorId := 2;
ELSIF TrigPV.Q THEN
    PositionEstimatedM := PosPVM;
    Recalibrated := TRUE;
    RecalibratedSensorId := 3;
ELSIF TrigTremie.Q THEN
    PositionEstimatedM := PosTremieM;
    Recalibrated := TRUE;
    RecalibratedSensorId := 4;
ELSE
    // Initialisation au tout premier démarrage sur le premier capteur actif vu
    IF NOT Initialized THEN
        IF SensorTremie THEN PositionEstimatedM := PosTremieM; Initialized := TRUE;
        ELSIF SensorPV THEN PositionEstimatedM := PosPVM; Initialized := TRUE;
        ELSIF SensorP2 THEN PositionEstimatedM := PosP2M; Initialized := TRUE;
        ELSIF SensorP1 THEN PositionEstimatedM := PosP1M; Initialized := TRUE;
        ELSIF SensorMaintenance THEN PositionEstimatedM := PosMaintenanceM; Initialized := TRUE;
        END_IF;
    END_IF;

    // 3. Intégration temporelle continue (Odométrie cycle par cycle)
    // dX = Direction * (FreqHz * Gain) * dt
    IF Direction <> 0 AND DriveActualFreqHz > 0.1 THEN
        PositionEstimatedM := PositionEstimatedM + (INT_TO_REAL(Direction) * DriveActualFreqHz * GainMetersPerHzSec * CycleTimeCalc.CycleTimeS);
    END_IF;
END_IF;

// Bornage de sécurité pour éviter la dérive infinie hors rail
PositionEstimatedM := LIMIT(PosMaintenanceM - 0.5, PositionEstimatedM, PosTremieM + 0.5);

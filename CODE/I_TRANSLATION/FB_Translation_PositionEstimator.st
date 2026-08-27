(* ═══════════════════════════════════════════════════════════════
   ⚙️ FB_Translation_PositionEstimator — Estimateur de Position Continue M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md §3
   🎯 Rôle : Calculer par odométrie (intégration temporelle vitesse/fréquence Hz * sens)
      la position estimée continue en mètres (0.0 m à la Trémie -> +30.0 m à la Maintenance),
      avec re-calage absolu automatique instantané sur le franchissement des 5 capteurs fixes.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation_PositionEstimator
VAR_INPUT
    Enable               : BOOL;   (* --> [CMD] Active le calcul *)
    Reset                : BOOL;   (* --> [CMD] Front d'acquittement / réinitialisation *)
    DriveActualFreqHz    : REAL;   (* --> [HW] Fréquence réelle variateur en Hz (ex: 5.0 Hz) *)
    Direction            : INT;    (* --> [CMD] Sens effectif : +1 = Fwd (vers Trémie), -1 = Rev (vers Maint), 0 = Arrêt *)
    
    (* 5 Capteurs de position fixes *)
    SensorMaintenance    : BOOL;   (* --> [HW] Capteur Maintenance (30.0 m) *)
    SensorP1             : BOOL;   (* --> [HW] Capteur P1 (20.0 m) *)
    SensorP2             : BOOL;   (* --> [HW] Capteur P2 (15.0 m) *)
    SensorPV             : BOOL;   (* --> [HW] Capteur PV (5.0 m) *)
    SensorTremie         : BOOL;   (* --> [HW] Capteur Trémie (0.0 m) *)

    (* Positions de référence calibrées (mètres) depuis GVL_PERSISTENT *)
    PosMaintenanceM      : REAL := 30.0;   (* --> [CFG] Position Maintenance *)
    PosP1M               : REAL := 20.0;   (* --> [CFG] Position P1 *)
    PosP2M               : REAL := 15.0;   (* --> [CFG] Position P2 *)
    PosPVM               : REAL := 5.0;   (* --> [CFG] Position PV *)
    PosTremieM           : REAL := 0.0;   (* --> [CFG] Position Trémie *)

    (* Gain de vitesse : mètres parcourus par Hz par seconde (ex: 50 Hz = 0.416 m/s => Gain = 0.008333 m/Hz.s) *)
    GainMetersPerHzSec   : REAL := 0.008333;   (* --> [CFG] Gain odométrie *)

    (* Reprise après reboot — l'appelant recopie en continu PositionEstimatedM/Initialized vers
       GVL_PERSISTENT (pas de bridge dédié, simple recopie) et réinjecte ici au redémarrage, pour
       ne pas perdre l'estimation odométrique à chaque coupure. *)
    PersistedPositionM   : REAL := 0.0;   (* --> [CFG] Position persistée *)
    PersistedInitialized : BOOL := FALSE;   (* --> [CFG] Initialisation persistée *)
END_VAR

VAR_OUTPUT
    PositionEstimatedM   : REAL;   (* <-- [STAT] Position continue estimée en mètres *)
    Initialized          : BOOL;   (* <-- [STAT] Exposé pour recopie persistante côté appelant *)
    Recalibrated         : BOOL;   (* <-- [STAT] Pulse 1 cycle lors d'un recalage sur capteur *)
    RecalibratedSensorId : INT;    (* <-- [DIAG] 0=Maint, 1=P1, 2=P2, 3=PV, 4=Trémie, -1=Aucun *)
END_VAR

VAR
    TrigTremie           : R_TRIG;   (* . [LOC] Front montant Trémie *)
    TrigPV                : R_TRIG;   (* . [LOC] Front montant PV *)
    TrigP2                : R_TRIG;   (* . [LOC] Front montant P2 *)
    TrigP1                : R_TRIG;   (* . [LOC] Front montant P1 *)
    TrigMaintenance       : R_TRIG;   (* . [LOC] Front montant Maintenance *)
    CycleTimeCalc         : FB_CycleTime;   (* * [INST] Mesure temps de cycle *)
    ColdStart             : BOOL := TRUE;  (* . [LOC] Seed unique depuis Persisted* au premier scan utile *)
    FirstScanDone         : BOOL := FALSE; (* . [LOC] Vrai après le 1er scan utile : les capteurs déjà présents à l'init ne sont pas des franchissements *)
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate et initialisation"}
IF NOT Enable THEN
    Recalibrated := FALSE;
    RecalibratedSensorId := -1;
    // 🔒 Sorties odométriques VOLONTAIREMENT conservées hors Enable (AC3 / persistance continue RETAIN) :
    // - PositionEstimatedM & Initialized : estimation odométrique et référence absolue maintenues pour ne pas perdre la position M3 hors Enable
    RETURN;
END_IF;

IF ColdStart THEN
    PositionEstimatedM := PersistedPositionM;
    Initialized := PersistedInitialized;
    ColdStart := FALSE;
END_IF;

CycleTimeCalc(DefaultValueS := 0.010);
Recalibrated := FALSE;
{endregion}

{region "§2 Fronts capteurs"}
// 1. Détection des fronts montants sur franchissement des capteurs fixes
TrigTremie(CLK := SensorTremie);
TrigPV(CLK := SensorPV);
TrigP2(CLK := SensorP2);
TrigP1(CLK := SensorP1);
TrigMaintenance(CLK := SensorMaintenance);
{endregion}

{region "§3 Recalage et intégration"}
// 2. Recalage absolu sur franchissement capteur — UNIQUEMENT après le premier scan utile.
//    Au 1er scan, un capteur "déjà présent" à l'initialisation (sim démarre à la trémie :
//    5 capteurs actifs) n'est pas un franchissement réel ; sinon le recalage IF/ELSIF
//    partirait de Maintenance (premier dans l'ordre) et écraserait la position à 30 m.
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
ELSE
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
    END_IF;
END_IF;

// 3. Initialisation au tout premier démarrage sur le premier capteur actif vu (si non initialisé)
IF NOT Initialized THEN
    IF SensorTremie THEN PositionEstimatedM := PosTremieM; Initialized := TRUE;
    ELSIF SensorPV THEN PositionEstimatedM := PosPVM; Initialized := TRUE;
    ELSIF SensorP2 THEN PositionEstimatedM := PosP2M; Initialized := TRUE;
    ELSIF SensorP1 THEN PositionEstimatedM := PosP1M; Initialized := TRUE;
    ELSIF SensorMaintenance THEN PositionEstimatedM := PosMaintenanceM; Initialized := TRUE;
    END_IF;
END_IF;

// 4. Intégration temporelle continue (Odométrie cycle par cycle)
// dX = -Direction * (FreqHz * Gain) * dt — convention 0 m=Trémie, 30 m=Maintenance :
// le sens +1 (vers Trémie) DÉCROÎT la position vers 0 m, le sens -1 (vers Maintenance) la CROÎT vers 30 m.
IF Direction <> 0 AND DriveActualFreqHz > 0.1 THEN
    PositionEstimatedM := PositionEstimatedM - (INT_TO_REAL(Direction) * DriveActualFreqHz * GainMetersPerHzSec * CycleTimeCalc.CycleTimeS);
END_IF;
{endregion}

{region "§4 Bornage"}
// Bornage de sécurité pour éviter la dérive infinie hors rail
// Convention 0 m=Trémie, 30 m=Maintenance : bornage [Trémie-0.5, Maintenance+0.5].
PositionEstimatedM := LIMIT(PosTremieM - 0.5, PositionEstimatedM, PosMaintenanceM + 0.5);
{endregion}

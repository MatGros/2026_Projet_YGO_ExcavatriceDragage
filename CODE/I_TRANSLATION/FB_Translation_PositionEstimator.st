(* ═══════════════════════════════════════════════════════════════
   ⚙️ FB_Translation_PositionEstimator — Estimateur de Position Continue M3
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md §1 (TC-P11-016) et §4
      (convention de position & cotes M3) ; fiche composant FB_Translation_PositionEstimator_v1.0.md
   🎯 Rôle : Calculer par odométrie (intégration temporelle vitesse/fréquence Hz * sens)
      la position estimée continue en mètres (0.0 m à la Trémie -> +30.0 m à la Maintenance),
      avec re-calage absolu automatique instantané sur le franchissement des 5 capteurs fixes,
      DANS LES DEUX SENS de déplacement (voir §2/§3).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation_PositionEstimator
VAR_INPUT
    Enable               : BOOL;   (* --> [CMD] Active le calcul *)
    Reset                : BOOL;   (* --> [CMD] Front d'acquittement / réinitialisation *)
    DriveActualFreqHz    : REAL;   (* --> [HW] Fréquence réelle variateur en Hz (ex: 5.0 Hz) *)
    ReqTremie            : BOOL;   (* --> [CMD] Demande explicite vers Trémie *)
    ReqMaintenance       : BOOL;   (* --> [CMD] Demande explicite vers Maintenance *)
    
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
    (* T361 — TÉMOIN D'ANOMALIE DE RECALAGE. Pulse 1 cycle lorsque la correction effectivement
       appliquée dépasse CST_RecalibrationAnomalyM. La correction est APPLIQUÉE dans tous les cas :
       ce signal ne conditionne jamais l'affectation de PositionEstimatedM et n'est jamais un
       verrou (voir §2bis et le gate G520). *)
    RecalibrationAnomaly : BOOL;   (* <-- [DIAG] Recalage de ce scan au-delà du seuil de plausibilité *)
    (* Amplitude de la DERNIÈRE correction appliquée (valeur absolue, mètres). Maintenue entre deux
       recalages pour rester lisible par une IHM ou une trace lente : c'est le pendant mesuré du
       témoin RecalibrationAnomaly. *)
    RecalibrationCorrectionM : REAL;   (* <-- [DIAG] |PositionEstimatedM - position avant recalage| *)
END_VAR

VAR
    TrigTremie           : R_TRIG;   (* . [LOC] Front montant Trémie (vers la Trémie) *)
    TrigPV                : R_TRIG;   (* . [LOC] Front montant PV *)
    TrigP2                : R_TRIG;   (* . [LOC] Front montant P2 *)
    TrigP1                : R_TRIG;   (* . [LOC] Front montant P1 *)
    TrigMaintenance       : R_TRIG;   (* . [LOC] Front montant Maintenance (départ Maintenance) *)
    TrigDnTremie          : F_TRIG;   (* . [LOC] Front descendant Trémie (départ Trémie) *)
    TrigDnPV              : F_TRIG;   (* . [LOC] Front descendant PV *)
    TrigDnP2              : F_TRIG;   (* . [LOC] Front descendant P2 *)
    TrigDnP1              : F_TRIG;   (* . [LOC] Front descendant P1 *)
    TrigDnMaintenance     : F_TRIG;   (* . [LOC] Front descendant Maintenance (ARRIVÉE Maintenance) *)
    CycleTimeCalc         : FB_CycleTime;   (* * [INST] Mesure temps de cycle *)
    ColdStart             : BOOL := TRUE;  (* . [LOC] Seed unique depuis Persisted* au premier scan utile *)
    FirstScanDone         : BOOL := FALSE; (* . [LOC] Vrai après le 1er scan utile : les capteurs déjà présents à l'init ne sont pas des franchissements *)
    (* T361 — Position AVANT tout recalage de ce scan : sert à MESURER la correction réellement
       appliquée (§2bis), sans toucher à la chaîne de recalage elle-même. *)
    PositionBeforeM       : REAL;          (* . [LOC] Position estimée avant recalage du scan courant *)
END_VAR

VAR CONSTANT
    (* T361 — SEUIL D'ANOMALIE DE RECALAGE (m). AU-DELÀ : correction appliquée + anomalie publiée.
       0,50 m = 5 % de l'écart maximal entre deux repères absolus (10,0 m : PV->P2 et
       P1->Maintenance) : au-delà, l'erreur de gain dépasse 5 %, niveau auquel le gain provisoire
       GVL_PERSISTENT._TranslationGainMetersPerHzSec (0,02 m/(Hz.s), NON CALIBRÉ — T301 en attente)
       doit être remis en cause. ⚠️ Ce seuil n'est PAS une garde : c'est un témoin.
       DÉCISION UTILISATEUR 2026-09-21 : 5 capteurs, recalage TOUJOURS appliqué, signal d'anomalie
       seul — aucune zone morte, aucun blocage (la décision Q2 du lot T333 « recaler SANS garde tant
       que T301 n'a pas calibré le gain » reste la règle).
       NE COUVRE PAS l'acquisition de la référence initiale (branche « NOT Initialized ») : c'est une
       amorce unique, pas la correction d'une dérive odométrique — la signaler ferait apparaître une
       anomalie à chaque premier démarrage après intervention. *)
    CST_RecalibrationAnomalyM : REAL := 0.50;
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate et initialisation"}
IF NOT Enable THEN
    Recalibrated := FALSE;
    RecalibratedSensorId := -1;
    RecalibrationAnomaly := FALSE;
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
RecalibrationAnomaly := FALSE;   (* T361 : témoin à pulse, remis à zéro à chaque scan comme Recalibrated *)
{endregion}

{region "§2 Fronts capteurs"}
// 1. Détection des fronts sur franchissement des capteurs fixes — MONTANT ET DESCENDANT.
//    Les 5 capteurs forment un mot thermomètre CUMULATIF (FB_Translation_PositionDecoder :
//    bit_X = TRUE ssi position <= cote_X). Chaque capteur bascule donc à SA cote dans les DEUX
//    sens : front MONTANT en venant de Maintenance (trajet vers la Trémie), front DESCENDANT en
//    allant vers la Maintenance. Ne consommer que le front montant ne recalait que le trajet
//    vers la Trémie — et JAMAIS l'arrivée en Maintenance, dont le mot 00000 est justement le
//    front DESCENDANT du capteur Maintenance (front montant = départ de Maintenance).
TrigTremie(CLK := SensorTremie);              TrigDnTremie(CLK := SensorTremie);
TrigPV(CLK := SensorPV);                      TrigDnPV(CLK := SensorPV);
TrigP2(CLK := SensorP2);                      TrigDnP2(CLK := SensorP2);
TrigP1(CLK := SensorP1);                      TrigDnP1(CLK := SensorP1);
TrigMaintenance(CLK := SensorMaintenance);    TrigDnMaintenance(CLK := SensorMaintenance);
{endregion}

{region "§3 Recalage et intégration"}
// 2. Recalage absolu sur franchissement capteur — sur front MONTANT ou DESCENDANT, et
//    UNIQUEMENT après le premier scan utile.
//    Au 1er scan, un capteur "déjà présent" à l'initialisation (sim démarre à la trémie :
//    5 capteurs actifs) n'est pas un franchissement réel ; sinon le recalage IF/ELSIF
//    partirait de Maintenance (premier dans l'ordre) et écraserait la position à 30 m.
//    Ordre de priorité inchangé (Maintenance -> P1 -> P2 -> PV -> Trémie) : sur un mot
//    thermomètre une seule bascule survient par scan, la priorité ne départage donc qu'un mot
//    incohérent (capteur collé / parasite), cas déjà surveillé par le décodeur (Incoherent).
PositionBeforeM := PositionEstimatedM;   (* T361 : référence de mesure, AVANT tout recalage de ce scan *)
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
ELSE
    IF TrigMaintenance.Q OR TrigDnMaintenance.Q THEN
        PositionEstimatedM := PosMaintenanceM;
        Recalibrated := TRUE;
        RecalibratedSensorId := 0;
    ELSIF TrigP1.Q OR TrigDnP1.Q THEN
        PositionEstimatedM := PosP1M;
        Recalibrated := TRUE;
        RecalibratedSensorId := 1;
    ELSIF TrigP2.Q OR TrigDnP2.Q THEN
        PositionEstimatedM := PosP2M;
        Recalibrated := TRUE;
        RecalibratedSensorId := 2;
    ELSIF TrigPV.Q OR TrigDnPV.Q THEN
        PositionEstimatedM := PosPVM;
        Recalibrated := TRUE;
        RecalibratedSensorId := 3;
    ELSIF TrigTremie.Q OR TrigDnTremie.Q THEN
        PositionEstimatedM := PosTremieM;
        Recalibrated := TRUE;
        RecalibratedSensorId := 4;
    END_IF;
END_IF;

// 2bis. T361 — TÉMOIN D'ANOMALIE DE RECALAGE : OBSERVER, JAMAIS BLOQUER.
// Le recalage ci-dessus est TOUJOURS appliqué, sans condition : le capteur franchi reste la
// meilleure référence absolue disponible, et refuser la correction laisserait une position FAUSSE
// ET NON CORRIGÉE. Ce bloc ne fait que MESURER la correction effectivement appliquée et PUBLIER
// l'anomalie au-delà de CST_RecalibrationAnomalyM — c'est précisément ce qui a manqué sur la trace
// Suivi_74 : des sauts de 4,53 à 9,12 m (audit T360) qui n'ont été vus qu'en post-mortem.
// 🔒 Le seuil ci-dessous ne doit JAMAIS devenir une condition des affectations `PositionEstimatedM`
// du bloc 2 : ce serait refuser un recalage légitime, l'erreur exacte que le gate G520 interdit.
// La décision Q2 du lot T333 (recaler sans garde tant que T301 n'a pas calibré le gain) reste la
// règle — l'anomalie est un témoin de diagnostic, pas un verrou.
IF Recalibrated THEN
    RecalibrationCorrectionM := ABS(PositionEstimatedM - PositionBeforeM);
    RecalibrationAnomaly := RecalibrationCorrectionM > CST_RecalibrationAnomalyM;
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
// Les bits explicites portent le sens sémantique. Une demande contradictoire est
// neutralisée : aucun déplacement estimé ne doit être inventé.
IF DriveActualFreqHz > 0.1 THEN
    IF ReqTremie AND NOT ReqMaintenance THEN
        PositionEstimatedM := PositionEstimatedM - (DriveActualFreqHz * GainMetersPerHzSec * CycleTimeCalc.CycleTimeS);
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        PositionEstimatedM := PositionEstimatedM + (DriveActualFreqHz * GainMetersPerHzSec * CycleTimeCalc.CycleTimeS);
    END_IF;
END_IF;
{endregion}

{region "§4 Bornage"}
// Bornage de sécurité pour éviter la dérive infinie hors rail
// Convention 0 m=Trémie, 30 m=Maintenance : bornage [Trémie-0.5, Maintenance+0.5].
PositionEstimatedM := LIMIT(PosTremieM - 0.5, PositionEstimatedM, PosMaintenanceM + 0.5);
{endregion}

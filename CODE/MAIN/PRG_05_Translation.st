(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_05_Translation — Pilotage de la Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5 (après PRG_04_Treuils_Benne).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF_Partie-11_Fonction_Translation_v2.1.md
   🛡️ Sécurité : instSafetyTranslationM3 (FB_Safety_Translation) câblée en parallèle
      de instTranslationM3 depuis le 2026-08-05 (lot M4) — SafeStop/PowerCutOff réels.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_05_Translation

VAR_OUTPUT
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest;
    TranslationStateHMI : ST_TranslationState;
    TranslationSafetyHMI : ST_SafetyTranslation;
END_VAR

VAR
    instTranslationM3           : FB_Translation;
    instSafetyTranslationM3     : FB_Safety_Translation;
    instPosEstimatorM3          : FB_Translation_PositionEstimator;

    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;

    SelTarget       : INT;
    FreqPct                 : REAL;

    M3_SafeStop_Active      : BOOL; // Cause historique : InputModuleFault (AF06 §3bis)
    M3_SafeStop_Aggregate   : BOOL; // 🛡️ SafeStop réellement appliqué au mouvement = InputModuleFault OR safety M3 (8 mécanismes)

    M3_HeightInterlockOk    : BOOL; // 🆕 2026-08-06 : TRUE = M1 ET M2 au-dessus de la hauteur mini (ou bypass actif)
    M3_LimitSwitchRevEffective : BOOL; // 🆕 2026-08-06 : coupure dure §5bis — bascule sur P1 si Maintenance interdite
    M3_LimitSwitchFwdStable : BOOL; // 🆕 2026-08-06 : verrou bistable Fdc Trémie (mémorisé stable contre les rebonds)
    M3_LimitSwitchRevStable : BOOL; // 🆕 2026-08-06 : verrou bistable Fdc Maintenance/P1 (mémorisé stable contre les rebonds)
END_VAR

// === 🚧 §0 INTERLOCK HAUTEUR M1/M2 (retour terrain, risque collision translation) ===
// PRG_02_Acquisition s'exécute avant ce POU dans la MainTask (rang 01 < 05) : lecture
// du même scan, aucun retard. Bypass = maintenance consciente, doctrine ST_BypassTranslation.
// ⚠️ Revue 2026-08-06 : une position encodeur incohérente (hors plage OU homing suspect,
// FB_Encoder_Safety) ne doit PAS pouvoir se lire comme "≥ seuil" par accident — fail-safe :
// hauteur non confirmée = interlock actif (comme une hauteur insuffisante), sauf bypass.
// 🔒 Décision 2026-08-06 : Bypass.Global NE lève PLUS cet interlock (contrairement aux autres
// causes de l'axe M3) — risque de collision jugé trop grave pour être levé par un bypass
// générique. Seul Bypass.MinHeight (dédié, conscient) lève l'anti-collision hauteur.
M3_HeightInterlockOk := GVL_IHM.TranslationM3.Bypass.MinHeight
                        OR (NOT PRG_02_Acquisition.M1_EncoderIncoherent
                            AND NOT PRG_02_Acquisition.M2_EncoderIncoherent
                            AND (PRG_02_Acquisition.CablePosM1 >= GVL_PERSISTENT._TranslationMinHeightM1M2_M)
                            AND (PRG_02_Acquisition.CablePosM2 >= GVL_PERSISTENT._TranslationMinHeightM1M2_M));
TranslationStateHMI.HeightInterlockBlocking := NOT M3_HeightInterlockOk;

// === 🚧 §0bis COUPURE DURE (LimitSwitchRev) — bascule sur P1 si Maintenance interdite ===
// 🆕 2026-08-06 (retour terrain) : LimitSwitchFwd/Rev protègent nativement Trémie/Maintenance
// (§5bis FB_Translation : coupure immédiate, sans rampe, dès que CommandedDirection insiste
// dans l'extrémité). P1/P2 n'ont aucune protection dure équivalente — seul le verrou souple
// (arrival-lock) les couvre. Quand Maintenance est interdite, la coupure dure doit protéger
// P1 comme si c'était l'extrémité réelle : mot 00001 (P1=0 ET Maintenance=1), UN CRAN AVANT
// la vraie extrémité Maintenance (00000) — backup si le verrou souple a déjà échoué à arrêter
// avant P1, garde la machine hors de la zone interdite plutôt que d'attendre le vrai fond.
M3_LimitSwitchRevEffective := SEL(PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable,
                                   NOT PRG_02_Acquisition.TranslationPosP1 AND PRG_02_Acquisition.TranslationPosMaintenance,
                                   PRG_02_Acquisition.M3_LimitSwitchRev);

// 🔒 §0ter STABILISATION BISTABLE FINS DE COURSE EXTRÊMES (Trémie & Maintenance/P1)
// Maintient la détection stable à 1 même si le capteur physique vibre ou saute brièvement.
// Se libère uniquement sur un mouvement effectif dans le SENS INVERSE (dégagement).
IF PRG_02_Acquisition.M3_LimitSwitchFwd THEN
    M3_LimitSwitchFwdStable := TRUE;
ELSIF M3_Direction_Active = -1 THEN
    M3_LimitSwitchFwdStable := FALSE;
END_IF;

IF M3_LimitSwitchRevEffective THEN
    M3_LimitSwitchRevStable := TRUE;
ELSIF M3_Direction_Active = 1 OR (PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable AND NOT PRG_02_Acquisition.M3_LimitSwitchRev) THEN
    M3_LimitSwitchRevStable := FALSE;
END_IF;

// === 🔀 §1 ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // ⚠️ T106 : SelTarget forcé à 0 et jamais réarbitré par un séquenceur (FB_Cycle n'est pas
    // instancié — audit M3 2026-08-05) → M3_StartStop_Active reste FALSE en pratique. Le
    // AND PRG_02_Acquisition.JoystickDeadmanArmed exigé par AF08 §6 devra être ajouté ici
    // au moment où le cycle SEMI_AUTO M3 sera réellement câblé, pas avant (rien à protéger
    // aujourd'hui, ne pas figer une condition sur du code mort).
    M3_PositioningActive  := TRUE;
    SelTarget    := 0;
    M3_StartStop_Active  := FALSE;
    M3_SpeedRef_Active   := 0.0;

    IF SelTarget = 1 THEN
        M3_Direction_Active := 1;
    ELSE
        M3_Direction_Active := -1;
    END_IF;
ELSIF (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1)
   OR (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2) THEN
    M3_PositioningActive := GVL_IHM.TranslationM3.Cmd.SelPositioning;
    SelTarget := 0;

    IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnFwd THEN
        M3_Direction_Active := 1;
    ELSIF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnRev THEN
        M3_Direction_Active := -1;
    ELSIF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        M3_Direction_Active := PRG_02_Acquisition.JoystickDirectionX;
    ELSE
        M3_Direction_Active := 0;
    END_IF;

    // 🔫 T106 (audit M3 2026-08-05) : homme-mort exigé même pour boutons IHM en MAINT_N1/N2
    // (AF_Partie-08 §6, AF_Partie-11 §4.2) — pas seulement pour un pilotage joystick réel.
    // 🔀 2026-08-06 : TglJoystickMaster consolidé — un seul switch machine (GVL_IHM.Modes.Cmd),
    // plus de doublon par axe (ex GVL_IHM.TranslationM3.Cmd.TglJoystickMaster, supprimé).
    M3_StartStop_Active := (M3_Direction_Active <> 0)
                           AND (GVL_IHM.TranslationM3.Bypass.Global
                                OR NOT GVL_IHM.Modes.Cmd.TglJoystickMaster
                                OR GVL_IHM.Modes.Cmd.TglJoystickMaster)
                           AND PRG_02_Acquisition.JoystickDeadmanArmed
                           AND M3_HeightInterlockOk; // 🆕 2026-08-06 : hauteur mini M1/M2 (risque collision)

    FreqPct := SEL(GVL_IHM.TranslationM3.Cmd.SetFreq_Hz > 0.0,
                  100.0,
                  (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz / SEL(GVL_PERSISTENT._TranslationMaxFreq_Hz > 0.0, 50.0, GVL_PERSISTENT._TranslationMaxFreq_Hz)) * 100.0);
    // 🕹️ Si TglJoystickMaster (global) = TRUE, le manche (0..100%) est mis à l'échelle sur la consigne SetFreq_Hz (ou 100% si non renseignée).
    M3_SpeedRef_Active := SEL(GVL_IHM.Modes.Cmd.TglJoystickMaster,
                              FreqPct,
                              (PRG_02_Acquisition.JoystickSpeedPctX / 100.0) * FreqPct);
ELSE
    M3_PositioningActive := FALSE;
    SelTarget    := 0;
    M3_StartStop_Active  := FALSE;
    M3_Direction_Active  := 0;
    M3_SpeedRef_Active   := 0.0;
END_IF;

IF GVL_IHM.TranslationM3.Cmd.InvertDirection THEN
    M3_Direction_Active := M3_Direction_Active * (-1);
END_IF;

M3_SpeedRef_Active := LIMIT(0.0, ABS(M3_SpeedRef_Active), 100.0);

IF (SelTarget = 4) AND NOT PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/positions du VH_0808ETP/VH_0800END portant M3 — rampe rapide.
M3_SafeStop_Active := PRG_02_Acquisition.InputModuleFault;

// 🆕 2026-08-06 (retour terrain, anti-rebond arrêt) : SelTarget reste à 0 en mode manuel
// (MAINT_N1/N2, T106 — aucun séquenceur SEMI_AUTO ne le réarbitre à ce jour), donc la CASE
// ci-dessous tombait toujours en ELSE=FALSE et le verrou anti-rebond §4ter de FB_Translation
// (DirectionAtArrival) ne s'armait jamais en usage réel. Repli explicite hors sélection
// SEMI_AUTO : n'importe quel des 3 points d'arrêt (Trémie/P1/Maintenance) arme le verrou.
// 🆕 2026-08-06 : mot EXACT (TranslationAtXxx), pas le cumulatif (TranslationPosXxx) — front
// franc à l'arrivée quel que soit le sens de venue (voir FB_Translation_PositionDecoder.st).
CASE SelTarget OF
    1: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtTremie;
    2: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtP2;
    3: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtP1;
    4: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtMaintenance;
ELSE
    IF M3_Direction_Active = 1 THEN
        // En Marche Avant (+1 vers Trémie) : seule Trémie est le point d'arrêt automatique
        M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtTremie;
    ELSIF M3_Direction_Active = -1 THEN
        // En Marche Arrière (-1 vers Maintenance) :
        // - Si Maintenance autorisée -> arrêt sur Maintenance
        // - Si Maintenance interdite -> arrêt sur P1
        IF PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable THEN
            M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtMaintenance;
        ELSE
            M3_PositionSensorTarget := PRG_02_Acquisition.TranslationAtP1;
        END_IF;
    ELSE
        M3_PositionSensorTarget := FALSE;
    END_IF;
END_CASE;


// === 🛡️ §1bis SÉCURITÉ M3 (FB_Safety_Translation, câblée en parallèle visible) ===
// ⚠️ Ordre d'appel volontaire : la safety lit ici le BrakeReleaseRequest et le
// BrakeCmd du SCAN PRÉCÉDENT d'instTranslationM3 (elle est appelée avant), exactement
// le même retard d'un scan que documenté en AF_Partie-11 §5 alerte 4 pour l'ancien
// code CFC — non éliminé par ce lot (nécessite la fusion CFC complète, lot M4 migration
// 7 POU, hors périmètre). Bénin : BrakeReleaseRequest ne change pas plus vite qu'un
// scan MainTask 10 ms sur une commande frein.
instSafetyTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    JoystickOnline          := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational     := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    PhaseRotationOk         := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    BrakeThermalFeedback    := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    DriveOnline             := PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Online,
    DriveOperational        := PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Operational,
    DriveStatusWord         := PRG_02_Acquisition.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BrakeCmd                := instTranslationM3.BrakeReleaseRequest,
    Direction               := M3_Direction_Active,
    LimitSwitchFwd          := M3_LimitSwitchFwdStable,
    LimitSwitchRev          := M3_LimitSwitchRevStable,
    SensorWordIncoherent    := PRG_02_Acquisition.M3_SensorWordIncoherent,
    BypassGlobal            := GVL_IHM.TranslationM3.Bypass.Global,
    BypassOperatorComm      := GVL_IHM.TranslationM3.Bypass.OperatorComm,
    BypassDriveComm         := GVL_IHM.TranslationM3.Bypass.DriveComm,
    BypassPhaseRotation     := GVL_IHM.TranslationM3.Bypass.PhaseRotation,
    BypassBrakeThermal      := GVL_IHM.TranslationM3.Bypass.BrakeThermal,
    BypassMecaB             := GVL_IHM.TranslationM3.Bypass.MecaB,
    BypassMecaA             := GVL_IHM.TranslationM3.Bypass.MecaA,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.LimitSwitch,
    BypassSensorIncoherent  := GVL_IHM.TranslationM3.Bypass.SensorIncoherent,
    BypassSafety            := GVL_IHM.TranslationM3.Bypass.Safety,
    BypassProcess           := GVL_IHM.TranslationM3.Bypass.Process
);

// SafeStop réellement appliqué au mouvement = agrégat InputModuleFault (historique)
// OR safety M3 (8 mécanismes) — aucune des deux causes ne doit être perdue.
M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;

// === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===

instTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := M3_SafeStop_Aggregate,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    SlowdownSensorTremie       := PRG_02_Acquisition.TranslationPosPV,
    SlowdownSensorMaintenance  := PRG_02_Acquisition.TranslationPosMaintenance AND NOT PRG_02_Acquisition.TranslationPosP2,
    SlowdownSensorP1           := PRG_02_Acquisition.TranslationPosP2,
    LimitSwitchFwd          := M3_LimitSwitchFwdStable,
    LimitSwitchRev          := M3_LimitSwitchRevStable,
    DriveStatusWord         := PRG_02_Acquisition.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0,
    CfgRampAccelRate        := _TranslationRampAccelRate_Pct,
    CfgRampDecelNormalRate  := _TranslationRampDecelNormal_Pct,
    CfgRampDecelFastRate    := _TranslationRampDecelFast_Pct,
    ApproachSpeedTremieHz       := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedTremie_Hz,
    ApproachSpeedMaintenanceHz  := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedMaintenance_Hz,
    ApproachSpeedP1Hz           := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedP1_Hz,
    DriveFreqScaleMaxHz     := _TranslationMaxFreq_Hz,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.ContactorFeedback,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);

// 📐 Estimateur de position continue M3 (odométrie + recalage 5 capteurs)
instPosEstimatorM3(
    Enable               := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    DriveActualFreqHz    := TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0,
    Direction            := M3_Direction_Active,
    SensorMaintenance    := PRG_02_Acquisition.TranslationPosMaintenance,
    SensorP1             := PRG_02_Acquisition.TranslationPosP1,
    SensorP2             := PRG_02_Acquisition.TranslationPosP2,
    SensorPV             := PRG_02_Acquisition.TranslationPosPV,
    SensorTremie         := PRG_02_Acquisition.TranslationPosTremie,
    PosMaintenanceM      := GVL_PERSISTENT._TranslationPosMaintenance_M,
    PosP1M               := GVL_PERSISTENT._TranslationPosP1_M,
    PosP2M               := GVL_PERSISTENT._TranslationPosP2_M,
    PosPVM               := GVL_PERSISTENT._TranslationPosPV_M,
    PosTremieM           := GVL_PERSISTENT._TranslationPosTremie_M,
    GainMetersPerHzSec   := GVL_PERSISTENT._TranslationGainMetersPerHzSec,
    PersistedPositionM   := GVL_PERSISTENT._TranslationPosEstimated_M,
    PersistedInitialized := GVL_PERSISTENT._TranslationPosEstimatedInitialized
);
// 🆕 Recopie continue (reprise après reboot, doctrine _TranslationSetFreq_Hz) — pas de bridge dédié.
GVL_PERSISTENT._TranslationPosEstimated_M := instPosEstimatorM3.PositionEstimatedM;
GVL_PERSISTENT._TranslationPosEstimatedInitialized := instPosEstimatorM3.Initialized;


// === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===

TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE);
TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;
TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;

// === 📤 PUBLICATION ÉTAT TRANSLATION IHM (lecture seule) ===
TranslationStateHMI.FBState := instTranslationM3.State;
TranslationStateHMI.Ready := instTranslationM3.Ready;
TranslationStateHMI.Busy := instTranslationM3.Busy;
TranslationStateHMI.Done := instTranslationM3.Done;
TranslationStateHMI.Error := instTranslationM3.Error;
TranslationStateHMI.ErrorId := instTranslationM3.ErrorId;
TranslationStateHMI.BrakeCmd := instTranslationM3.BrakeReleaseRequest;
TranslationStateHMI.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationStateHMI.PositionReached := instTranslationM3.TargetReached;
TranslationStateHMI.DriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationStateHMI.DriveFreqRef_Hz := instTranslationM3.RequestedDriveFreqHz;
TranslationStateHMI.ActiveDirection := M3_Direction_Active;
TranslationStateHMI.ActiveSpeedRef_Pct := M3_SpeedRef_Active;
TranslationStateHMI.PositionTremie := PRG_02_Acquisition.TranslationPosTremie;
TranslationStateHMI.PositionPV := PRG_02_Acquisition.TranslationPosPV;
TranslationStateHMI.PositionP2 := PRG_02_Acquisition.TranslationPosP2;
TranslationStateHMI.PositionP1 := PRG_02_Acquisition.TranslationPosP1;
TranslationStateHMI.PositionMaintenance := PRG_02_Acquisition.TranslationPosMaintenance;
TranslationStateHMI.AtTremie := PRG_02_Acquisition.TranslationAtTremie;
TranslationStateHMI.AtPV := PRG_02_Acquisition.TranslationAtPV;
TranslationStateHMI.AtP2 := PRG_02_Acquisition.TranslationAtP2;
TranslationStateHMI.AtP1 := PRG_02_Acquisition.TranslationAtP1;
TranslationStateHMI.AtMaintenance := PRG_02_Acquisition.TranslationAtMaintenance;
TranslationStateHMI.EstimatedPosM3_M := instPosEstimatorM3.PositionEstimatedM;
TranslationStateHMI.SensorsWord := PRG_02_Acquisition.M3_SensorsWord;
TranslationStateHMI.SensorWordIncoherent := PRG_02_Acquisition.M3_SensorWordIncoherent;
TranslationStateHMI.LimitSwitchFwd := M3_LimitSwitchFwdStable;
TranslationStateHMI.LimitSwitchRev := M3_LimitSwitchRevStable;
TranslationStateHMI.DriveActualFreq_Hz := TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0;
TranslationStateHMI.DriveThermalOk := PRG_02_Acquisition.HwIn.Translation.M3_ThermalOK_DI;
TranslationStateHMI.JoystickDeflection_Pct := INT_TO_REAL(PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1);
TranslationStateHMI.FinalInterlockState := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.State;
TranslationStateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Reason;
TranslationStateHMI.FinalInterlockError := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Error;
TranslationStateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.ErrorId;
TranslationStateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.BrakeTimeoutElapsed;
TranslationStateHMI.DriveCommReady := (PRG_02_Acquisition.M3_StatusWord_Filtered AND 16#0080) <> 0;
TranslationStateHMI.DrivePowerReady := (PRG_02_Acquisition.M3_StatusWord_Filtered AND 16#0001) <> 0;
TranslationStateHMI.MaintenanceTargetEnable := PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable;
TranslationStateHMI.SimulationModeActive := GVL_Simulation.SimulationModeActive;

// 🛡️ Producteur unique (CODE_QUALITY_STANDARDS §5) : la safety M3 (instSafetyTranslationM3)
// est désormais la source de tous les diagnostics de sécurité — ErrorLimitSwitch/
// ErrorSensorIncoherent ne sont plus recalculés ici (ancien calcul ignorait les bypass,
// pouvait afficher un défaut alors qu'il était sciemment bypassé). Les erreurs propres au
// mouvement (frein, variateur AC600) restent sur TranslationStateHMI.ErrorId ci-dessus,
// bitfield différent, jamais mélangé.
TranslationSafetyHMI.SafeStop := M3_SafeStop_Aggregate;
TranslationSafetyHMI.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationSafetyHMI.Error := instSafetyTranslationM3.Error;
TranslationSafetyHMI.ErrorId := instSafetyTranslationM3.ErrorId;
TranslationSafetyHMI.ErrorOperatorComm := instSafetyTranslationM3.ErrorOperatorComm;
TranslationSafetyHMI.ErrorDriveComm := instSafetyTranslationM3.ErrorDriveComm;
TranslationSafetyHMI.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;
TranslationSafetyHMI.ErrorBrakeThermal := instSafetyTranslationM3.ErrorBrakeThermal;
TranslationSafetyHMI.ErrorMecaB := instSafetyTranslationM3.ErrorMecaB;
TranslationSafetyHMI.ErrorMecaA := instSafetyTranslationM3.ErrorMecaA;
TranslationSafetyHMI.ErrorLimitSwitch := instSafetyTranslationM3.ErrorLimitSwitch;
TranslationSafetyHMI.ErrorSensorIncoherent := instSafetyTranslationM3.ErrorSensorIncoherent;

END_PROGRAM

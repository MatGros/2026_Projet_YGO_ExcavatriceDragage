(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_07_TranslationControl — Pilotage de la Translation Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_07_TranslationControl
VAR
    instTranslationM3           : FB_Translation;
    instPositionDecoder         : FB_Translation_PositionDecoder; // 🆕 REX 2026-07-18 : décodage mot 5 capteurs (AF_Partie-02 v2.12 §3bis)

    // Commandes arbitrées après sélection Manuel/Auto
    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositionSensorTarget : BOOL;

    // Target active (HMI en manuel, instCycle en auto) — 0=Aucun, 1=Trémie, 2=P2, 3=P1,
    // 4=Maintenance. PV n'est JAMAIS une cible sélectionnable (point de ralentissement seul).
    SelectedTargetNum       : INT;

    // 🆕 REX 2026-07-16 : IHM_MANU comme 3ᵉ source d'arbitrage (voir §1bis ci-dessous)
    FreqPct                 : REAL; // Conversion FreqSetpointHz (Hz) → % pleine échelle pour SpeedRefPct
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_07_TranslationControl) ===

// ── 0. DÉCODAGE MOT CAPTEURS (5 positions, indépendant du mode/de la cible) ─
// 🆕 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 §3bis) — remplace le câblage direct
// des anciens capteurs Fosse1/Tremie sur LimitSwitchFwd/Rev par un décodage complet du mot
// 5 bits (Trémie|PV|P2|P1|Maintenance), avec détection d'incohérence (capteur collé/HS).
instPositionDecoder(
    SensorTremie      := PRG_00_Inputs.TranslationPosTremie,
    SensorPV          := PRG_00_Inputs.TranslationPosPV,
    SensorP2          := PRG_00_Inputs.TranslationPosP2,
    SensorP1          := PRG_00_Inputs.TranslationPosP1,
    SensorMaintenance := PRG_00_Inputs.TranslationPosMaintenance
);

// ── 1. ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ──────────────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // Mode Auto/Semi-Auto : Consigne issue du séquenceur de cycle
    SelectedTargetNum    := PRG_05_Cycle.instCycle.CmdTranslationM3_Target;
    // 🛡️ SEMI_AUTO reste conditionné par l'homme-mort : relâchement = arrêt,
    // nouvelle sollicitation valide = reprise à l'étape courante.
    M3_StartStop_Active  := PRG_05_Cycle.instCycle.CmdTranslationM3_Start
                            AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                            AND PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.StartStop;
    M3_SpeedRef_Active   := MIN(40.0,
                                ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef));

    // Détermination automatique du sens de marche selon la cible :
    // - Trémie (cible 1) = Marche Avant (Direction := 1)
    // - P2/P1/Maintenance (cibles 2/3/4) = Marche Arrière (Direction := -1)
    IF SelectedTargetNum = 1 THEN
        M3_Direction_Active := 1;
    ELSE
        M3_Direction_Active := -1;
    END_IF;
// ── 1bis. IHM_MANU — 3ᵉ source d'arbitrage (mirroir PRG_06_WinchControl §1/§2) ──
// 🆕 REX 2026-07-16 : remplace l'ex-bypass direct M3_CommandWord dans PRG_10_Outputs — M3 est
// désormais piloté par la MÊME instance instTranslationM3 (FB_Translation) qu'en Auto, avec la
// rampe accel/décel et l'interlock changement de sens natifs, sous surveillance réelle de
// FB_Safety_Translation (voir PRG_03_Safety, Enable désormais inconditionnel).
ELSIF PRG_10_Outputs.ManuActive THEN
    // Pas de sélecteur de cible dédié en Manu — comportement actuel inchangé (StubTranslationPositionSelect_IHM).
    SelectedTargetNum := StubTranslationPositionSelect_IHM;

    // Demande (boutons IHM ou joystick, déjà arbitrée par PRG_10_Outputs : M3Fwd_Demand/M3Rev_Demand)
    // lue avec 1 scan de retard (~10ms, PRG_10 position 10 > PRG_07 position 7) — même principe
    // déjà accepté côté PRG_06_WinchControl pour M1Fwd_Demand/M2Fwd_Demand.
    IF PRG_10_Outputs.M3Fwd_Demand THEN
        M3_Direction_Active := 1;
    ELSIF PRG_10_Outputs.M3Rev_Demand THEN
        M3_Direction_Active := -1;
    ELSE
        M3_Direction_Active := 0;
    END_IF;
    M3_StartStop_Active := (M3_Direction_Active <> 0);

    // 🎯 Vitesse : conserve GVL_IHM.TranslationM3.FreqSetpointHz (consigne Hz réglable opérateur,
    // clampée par PRG_10_Outputs à _TranslationMaxFreq_Hz) comme cible pleine échelle — identique
    // pour boutons HMI ET joystick (reproduit exactement l'ex-bypass PRG_10_Outputs, ex-lignes
    // 250-251/271-272 : FreqSetpointHz = 100%, déflexion joystick = % de cette cible). Convertie en
    // pourcentage car SpeedRefPct (entrée FB_Translation) est une échelle 0-100%, pas des Hz.
    FreqPct := (GVL_IHM.TranslationM3.FreqSetpointHz / _TranslationMaxFreq_Hz) * 100.0;
    M3_SpeedRef_Active := SEL(GVL_IHM.IHM_MANU.JoystickSelect,
                              FreqPct,
                              (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef) / 100.0) * FreqPct);
ELSE
    // Mode Manuel/Maintenance : Consignes issues du Joystick et sélecteur HMI
    SelectedTargetNum    := StubTranslationPositionSelect_IHM;
    M3_StartStop_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.StartStop;
    M3_Direction_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.Direction;
    M3_SpeedRef_Active   := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
END_IF;

// 🆕 REX 2026-07-18 : cible Maintenance (4) bloquée hors MAINT_N2 (AF_Partie-02 v2.12 §3bis) —
// arbitrage centralisé dans FB_Modes (aucun re-test de Mode ici), refuse toute cible si interdite.
IF (SelectedTargetNum = 4) AND NOT PRG_04_Modes.instModes.MaintenanceM3TargetEnable THEN
    SelectedTargetNum := 0;
END_IF;

// Câblage du capteur de butée de la cible sélectionnée (PV exclu : jamais une cible d'arrêt)
CASE SelectedTargetNum OF
    1: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosTremie;
    2: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosP2;
    3: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosP1;
    4: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosMaintenance;
ELSE
    M3_PositionSensorTarget := FALSE;   // Aucun capteur visé
END_CASE;

// ── 2. EXÉCUTION DU PILOTAGE DU TRANSLATION M3 ──────────────────────────────
instTranslationM3(
    Enable                  := PRG_06_WinchControl.StubMachineEnableN1,
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := PRG_03_Safety.instSafetyTranslationM3.SafeStop,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    SlowdownSensor          := PRG_00_Inputs.TranslationPosPV, // 🆕 remplace ApproachTime (timer) — ralentissement avant Trémie uniquement
    LimitSwitchFwd          := instPositionDecoder.LimitSwitchFwd, // 🆕 dérivé du mot capteurs (extrême Trémie, mot=11111)
    LimitSwitchRev          := instPositionDecoder.LimitSwitchRev, // 🆕 dérivé du mot capteurs (extrême Maintenance, mot=00000)
    DriveStatusWord         := PRG_00_Inputs.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.BypassContactorFeedback, PRG_00_Inputs.M3BrakeFeedback, instTranslationM3.BrakeCmd),
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal
);

// 🔴 Recopie commande de frein translation
PRG_10_Outputs.TranslationBrakeCmd := instTranslationM3.BrakeCmd;

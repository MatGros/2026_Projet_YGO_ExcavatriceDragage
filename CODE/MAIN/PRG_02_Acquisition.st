(* ═══════════════════════════════════════════════════════════════
   📡 PRG_02_Acquisition — Programme d'Acquisition et Conditionnement I/O
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1 (premier POU du cycle).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md §2
   🎯 Rôle unique : Produire les images HwReal/HwSim/HwIn,
      acquérir et traiter les mesures codeurs (M1/M2), décoder M3, traiter le joystick
      et publier les retours.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_02_Acquisition

VAR_OUTPUT
    HwReal                   : ST_HardwareImage;  (* Image brute réelle ; TRUE = état physique lu *)
    HwSim                    : ST_HardwareImage;  (* Image simulée ; TRUE = état modèle normalisé *)
    HwIn                     : ST_HardwareImage;  (* Image utilisée ; TRUE = état logique métier *)
    WinchInputSourceChanged  : BOOL;              (* TRUE pendant 1 cycle si source Winch change *)

    JoystickDeadmanArmed      : BOOL;   (* TRUE = geste homme-mort joystick armé (FB_Joystick.DeadmanArmed, AF08 §4/§6) *)
    JoystickYNeutral          : BOOL;   (* 🆕 2026-08-05 : TRUE = axe Y joystick au neutre — armement Méca B (FB_Safety_Winch) *)
    JoystickDirectionX        : INT;    (* -1 = Gauche/Rev, 0 = Neutre, +1 = Droite/Fwd *)
    JoystickSpeedPctX         : REAL;   (* Magnitude déviation axe X en % (0..100) *)
    JoystickXNeutral          : BOOL;   (* TRUE = axe X joystick au neutre *)

    TranslationPosTremie      : BOOL;   (* TRUE = translation en position Trémie — CUMULATIF, ralentissement uniquement *)
    TranslationPosPV          : BOOL;   (* TRUE = translation en zone pré-ralentissement PV — CUMULATIF *)
    TranslationPosP2          : BOOL;   (* TRUE = translation en position P2 — CUMULATIF *)
    TranslationPosP1          : BOOL;   (* TRUE = translation en position P1 — CUMULATIF *)
    TranslationPosMaintenance : BOOL;   (* TRUE = translation en position Maintenance — CUMULATIF *)

    (* 🆕 2026-08-06 : mot EXACT — détection d'arrivée/cible et coupure dure UNIQUEMENT,
       jamais le ralentissement (zone trop étroite). Voir FB_Translation_PositionDecoder.st *)
    TranslationAtTremie      : BOOL;
    TranslationAtPV          : BOOL;
    TranslationAtP2          : BOOL;
    TranslationAtP1          : BOOL;
    TranslationAtMaintenance : BOOL;

    M3_StatusWord_Filtered        : UINT; (* WORD/UINT d'état variateur filtré *)
    M3_ActualFrequencyHz_Filtered : UINT; (* UINT fréquence M3 filtrée, unité : 0,01 Hz *)

    M3_LimitSwitchFwd          : BOOL; (* TRUE = limite avant active *)
    M3_LimitSwitchRev          : BOOL; (* TRUE = limite arrière active *)
    M3_SensorWordIncoherent    : BOOL; (* TRUE = mot capteurs incohérent *)
    M3_SensorsWord             : BYTE; (* BYTE mot capteurs M3 *)

    (* 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (§1bis).
       Granularité MODULE, pas canal : GetDeviceState() est un état de carte. *)
    LocalDigitalIoOk           : BOOL;   (* TRUE = module Local_Digital_IO opérationnel *)
    Vh0800EndOk                : BOOL;   (* TRUE = module VH_0800END opérationnel (freins/thermiques/AU) *)
    Vh0808EtpOk                : BOOL;   (* TRUE = module VH_0808ETP opérationnel (positions M3/hydraulique/crible) *)
    InputModuleFault           : BOOL;   (* TRUE = au moins un des 3 modules DI hors service *)
    (* 🧲 Positions câbles calculées en mètres (mises à l'échelle après homing, bornées et
       gelées sur doute par FB_Encoder_Safety — CablePosM1/M2 ne sont PLUS la sortie brute
       FB_Encoder_Scale depuis le 2026-08-05, voir §4bis) *)
    CablePosM1                 : REAL;   (* Position câble M1 en mètres *)
    CablePosM2                 : REAL;   (* Position câble M2 en mètres *)
    M1_EncoderIncoherent       : BOOL;   (* 🆕 2026-08-05 : TRUE = position hors plage ±99m OU homing suspect (FB_Encoder_Safety) *)
    M2_EncoderIncoherent       : BOOL;
    (* 🆕 2026-08-05 : vitesse câble mesurée (FB_Encoder_SpeedMeasure), prérequis FB_Safety_Winch Méca A/F/G *)
    M1_Speed_Mps               : REAL;   (* Vitesse absolue M1, m/s *)
    M1_SignedSpeed_Mps         : REAL;   (* Vitesse signée M1 (+ montée / - descente), m/s *)
    M1_SpeedValid              : BOOL;   (* TRUE après 6 échantillons couvrant ≥50ms, position saine *)
    M2_Speed_Mps               : REAL;
    M2_SignedSpeed_Mps         : REAL;
    M2_SpeedValid              : BOOL;
END_VAR

VAR_INPUT
    (* 🔌 Entrées variateur AC600 EtherCAT M3 *)
    M3_StatusWord              : WORD;  (* Status Word 0x3102 (%IW8) *)
    M3_ActualFrequencyHz       : UINT;  (* Actual Frequency 0x3103 (%IW9, x100) *)
END_VAR

VAR
    (* ── Blocs complexes ── *)
    instSimBench             : FB_SimBench;
    instJoystick             : FB_Joystick;
    instEncoderAbsM1         : FB_Encoder_Abs;
    instEncoderScaleM1       : FB_Encoder_Scale;
    instHomingM1             : FB_Encoder_Homing;
    instEncoderSafetyM1      : FB_Encoder_Safety;       // 🆕 2026-08-05
    instEncoderSpeedMeasureM1: FB_Encoder_SpeedMeasure;  // 🆕 2026-08-05
    instEncoderAbsM2         : FB_Encoder_Abs;
    instEncoderScaleM2       : FB_Encoder_Scale;
    instHomingM2             : FB_Encoder_Homing;
    // 🆕 2026-08-07 (19) : BtnConfirmOpenPos/ClosePos (benne) référencent aussi le codeur M2,
    // comme BtnHome -- voir bandeau instHomingM2 plus bas.
    M2BucketRefOpenEdge      : R_TRIG;
    M2BucketRefCloseEdge     : R_TRIG;
    M2BucketRefRequested     : BOOL;
    M2BucketRefTargetM       : REAL;
    instEncoderSafetyM2      : FB_Encoder_Safety;       // 🆕 2026-08-05
    instEncoderSpeedMeasureM2: FB_Encoder_SpeedMeasure;  // 🆕 2026-08-05
    instPosDecoderM3         : FB_Translation_PositionDecoder;

    (* ── Sélection de source par domaine ── *)
    WinchInputSourceSimulated         : BOOL;
    TranslationInputSourceSimulated   : BOOL;
    OperatorInputSourceSimulated      : BOOL;
    MachineInputSourceSimulated       : BOOL;

    (* ── Mémoire de détection de changement Winch ── *)
    PreviousWinchInputSourceSimulated : BOOL;
    WinchInputSourceInitialized       : BOOL;

    (* ── Fronts session simulation ── *)
    SimulationModeRise                : R_TRIG;
    SimulationModeFall                : F_TRIG;
END_VAR

VAR CONSTANT
    // ⚙️ Constantes mécaniques & électriques chaîne codeurs treuils (DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md §2)
    ENCODER_POINTS_PER_REV     : UDINT := 8192; // 13 bits single-turn (8192 pts/tour)
    ENCODER_MULTITURN_REVS_MAX : UDINT := 4096; // 12 bits multi-turn (4096 tours max)
    WINCH_CABLE_M_PER_REV      : REAL  := 2.0;  // 2.0 mètres de câble par tour de tambour treuil
END_VAR

{region "§0 Session simulation & aiguillage"}
// === 🧪 §0 SIMULATION & SÉLECTION DE SOURCE ===
// 🎯 Producteur unique des aiguillages Réel/Simu par domaine (HwReal vs HwSim -> HwIn).
// ⚡ Fronts maître : initialisent/nettoient les stimuli banc sans état résiduel.

SimulationModeRise(CLK := GVL_Simulation.SimulationModeActive);
SimulationModeFall(CLK := GVL_Simulation.SimulationModeActive);

IF SimulationModeRise.Q THEN
    GVL_Simulation.SimWinchActive := TRUE;
    GVL_Simulation.SimTranslationActive := TRUE;
    GVL_Simulation.SimOperatorActive := TRUE;
    GVL_Simulation.SimSafetyActive := TRUE;
    GVL_Simulation.SimJoystickRawButton := TRUE;
END_IF;

IF SimulationModeFall.Q THEN
    GVL_Simulation.SimWinchActive := FALSE;
    GVL_Simulation.SimTranslationActive := FALSE;
    GVL_Simulation.SimOperatorActive := FALSE;
    GVL_Simulation.SimSafetyActive := FALSE;

    GVL_Simulation.SimM3SensorsWordOverrideActive := FALSE;
    GVL_Simulation.SimM3SensorsWord := 16#07;
    GVL_Simulation.SimJoystickLeftActive := FALSE;
    GVL_Simulation.SimJoystickRightActive := FALSE;
    GVL_Simulation.SimJoystickForwardActive := FALSE;
    GVL_Simulation.SimJoystickReverseActive := FALSE;
    GVL_Simulation.SimJoystickRawX := 5000;
    GVL_Simulation.SimJoystickRawY := 5000;
    GVL_Simulation.SimJoystickRawButton := FALSE;
    GVL_Simulation.SimEncoderSpeedFactor := 1.0;
    GVL_Simulation.SimSyncDeviationInjectM1 := FALSE;
    GVL_Simulation.SimSyncDeviationInjectM2 := FALSE;
    GVL_Simulation.SimSyncDeviationOffset_M := 0.5;
    GVL_Simulation.SimKoboldContactValue := FALSE;
END_IF;

// 🔀 Aiguillages de source uniques par domaine
WinchInputSourceSimulated       := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
TranslationInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
OperatorInputSourceSimulated    := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive;
MachineInputSourceSimulated     := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimSafetyActive;
{endregion}

{region "§1 Acquisition brute — HwReal"}
// === 📥 §1 ACQUISITION BRUTE MATÉRIELLE (HwReal) ===

// Winch M1 / M2 et codeurs
HwReal.Winch.M1_ContactorsReleased_DI := M1_ContactorsReleased_DI;
HwReal.Winch.M1_ThermalOk_DI          := M1_ThermalOk_DI;
HwReal.Winch.M1_BrakeIsOpen_DI        := M1_BrakeIsOpen_DI;

HwReal.Winch.M2_ContactorsReleased_DI := M2_ContactorsReleased_DI;
HwReal.Winch.M2_ThermalOk_DI          := M2_ThermalOk_DI;
HwReal.Winch.M2_BrakeIsOpen_DI        := M2_BrakeIsOpen_DI;

HwReal.Winch.M1M2_TopPositionFree_DI  := M1M2_TopPositionFree_DI;
HwReal.Winch.M2_TensionedCable_DI     := M2_TensionedCable_DI;

HwReal.Winch.COD1_PosValue            := COD1_PosValue;
HwReal.Winch.COD1_Alarms              := COD1_Alarms;
HwReal.Winch.COD1_Warnings            := COD1_Warnings;
HwReal.Winch.COD1_DeviceState         := COD1_CODEUR.GetDeviceState();

HwReal.Winch.COD2_PosValue            := COD2_PosValue;
HwReal.Winch.COD2_Alarms              := COD2_Alarms;
HwReal.Winch.COD2_Warnings            := COD2_Warnings;
HwReal.Winch.COD2_DeviceState         := COD2_CODEUR.GetDeviceState();

// Translation M3 et variateur AC600
HwReal.Translation.M3_PosTremie_DI      := M3_PosTremie_DI;
HwReal.Translation.M3_PosPV_DI          := M3_PosPV_DI;
HwReal.Translation.M3_PosPVP2_DI        := M3_PosPVP2_DI;
HwReal.Translation.M3_PosP1_DI          := M3_PosP1_DI;
HwReal.Translation.M3_PosMaintenance_DI := M3_PosMaintenance_DI;
HwReal.Translation.M3_BrakeIsOpen_DI    := M3_BrakeIsOpen_DI;
HwReal.Translation.M3_ThermalOK_DI       := M3_ThermalOK_DI;
HwReal.Translation.M3_StatusWord        := M3_StatusWord;
HwReal.Translation.M3_ActualFrequencyHz := M3_ActualFrequencyHz;
HwReal.Translation.AC600_DeviceState    := AC600_ECAT_Drive.GetDeviceState();

// Opérateur / Joystick / bus CANopen
HwReal.Operator.JoyXRaw_ANA1      := JoyXRaw_ANA1;
HwReal.Operator.JoyYRaw_ANA2      := JoyYRaw_ANA2;
HwReal.Operator.JoyBtnRaw         := JoyBtnRaw;
HwReal.Operator.CanBusState       := CANbus.GetBusState();
HwReal.Operator.JOY1_DeviceState  := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();

// Sécurités / Communs Machine
HwReal.Machine.PowerContactorEngaged_DI   := PowerContactorEngaged_DI;
HwReal.Machine.EmergencyChainClosed_DI    := EmergencyChainClosed_DI;
HwReal.Machine.PhaseRotationOk_DI         := PhaseRotationOk_DI;
HwReal.Machine.M1_M2_M3_BrakeThermalOk_DI  := M1_M2_M3_BrakeThermalOk_DI;
HwReal.Machine.M1_M2_KoboldBottomTouch_DI  := M1_M2_KoboldBottomTouch_DI;
HwReal.Machine.HydraulicThermalOk_DI       := HydraulicThermalOk_DI;
HwReal.Machine.ConveyorInfeedReady_DI      := ConveyorInfeedReady_DI;
HwReal.Machine.HopperFull_OR_GateRaised_DI := HopperFull_OR_GateRaised_DI; // 🆕 2026-08-12 : déclaré, pas encore consommé
{endregion}

{region "§1bis Diagnostic modules DI"}
// 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (AF06 §3bis).
// GetDeviceState() = RUNNING => module opérationnel. Si la simulation globale/machine est active,
// les cartes physiques absentes sont simulées OK pour permettre le fonctionnement banc.
IF MachineInputSourceSimulated THEN
    LocalDigitalIoOk := TRUE;
    Vh0800EndOk      := TRUE;
    Vh0808EtpOk      := TRUE;
ELSE
    LocalDigitalIoOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING);
    Vh0800EndOk      := (VH_0800END.GetDeviceState() = DEVICE_STATE.RUNNING);
    Vh0808EtpOk      := (VH_0808ETP.GetDeviceState() = DEVICE_STATE.RUNNING);
END_IF;
InputModuleFault := NOT (LocalDigitalIoOk AND Vh0800EndOk AND Vh0808EtpOk);
{endregion}

{region "§2 Simulation et aiguillage — HwIn"}
// === 🎭 §2 SIMULATION & AIGUILLAGE (HwIn) ===

instSimBench(
    Enable                   := GVL_Simulation.SimulationModeActive,
    M1_RelayFwd              := GVL_Global.M1RelayFwd,
    M1_RelayRev              := GVL_Global.M1RelayRev,
    M1_SpeedContactor_1      := GVL_Global.M1SpeedContactor1,
    M1_SpeedContactor_2      := GVL_Global.M1SpeedContactor2,
    M1_SpeedContactor_3      := GVL_Global.M1SpeedContactor3,
    M1_SpeedContactor_4      := GVL_Global.M1SpeedContactor4,
    M1_SpeedRefPct           := PRG_04_Treuils_Benne.M1_SpeedRef_Active,
    M1_PresetTriggerCmd      := instEncoderAbsM1.PresetTriggerCmd,
    M1_PresetValueOut        := instEncoderAbsM1.PresetValueOut,
    M1_BrakeCmd              := GVL_Global.M1BrakeCmd,
    M2_RelayFwd              := GVL_Global.M2RelayFwd,
    M2_RelayRev              := GVL_Global.M2RelayRev,
    M2_SpeedContactor_1      := GVL_Global.M2SpeedContactor1,
    M2_SpeedContactor_2      := GVL_Global.M2SpeedContactor2,
    M2_SpeedContactor_3      := GVL_Global.M2SpeedContactor3,
    M2_SpeedContactor_4      := GVL_Global.M2SpeedContactor4,
    M2_SpeedRefPct           := PRG_04_Treuils_Benne.M2_SpeedRef_Active,
    M2_PresetTriggerCmd      := instEncoderAbsM2.PresetTriggerCmd,
    M2_PresetValueOut        := instEncoderAbsM2.PresetValueOut,
    M2_BrakeCmd              := GVL_Global.M2BrakeCmd,
    M3_Direction             := PRG_05_Translation.M3_Direction_Active,
    M3_SpeedRefPct           := PRG_05_Translation.M3_SpeedRef_Active,
    M3_BrakeCmd              := GVL_Global.TranslationBrakeCmd,
    PowerKeepAlive_A         := PRG_06_Outputs_LD.PowerKeepAliveACmd,
    PowerKeepAlive_B         := PRG_06_Outputs_LD.PowerKeepAliveBCmd,
    // 🧪 Simulation uniquement : l'état étape 5 sécurise le transfert même si la sortie
    // inter-POU ArmPulse est observée avec un cycle de retard dans la tâche.
    EmergencyArming_RQ       := PRG_06_Outputs_LD.EmergencyArmingCmd
                                 OR (PRG_06_Outputs_LD.ArmingSeqStep = 5),
    SimEncoderSpeedFactor    := GVL_Simulation.SimEncoderSpeedFactor,
    SimSyncDeviationInjectM1 := GVL_Simulation.SimSyncDeviationInjectM1,
    SimSyncDeviationInjectM2 := GVL_Simulation.SimSyncDeviationInjectM2,
    SimSyncDeviationOffset_M := GVL_Simulation.SimSyncDeviationOffset_M,
    SimM3SensorsWordOverrideActive := GVL_Simulation.SimM3SensorsWordOverrideActive,
    SimM3SensorsWord               := GVL_Simulation.SimM3SensorsWord,
    SimJoystickLeftActive          := GVL_Simulation.SimJoystickLeftActive,
    SimJoystickRightActive         := GVL_Simulation.SimJoystickRightActive,
    SimJoystickForwardActive       := GVL_Simulation.SimJoystickForwardActive,
    SimJoystickReverseActive       := GVL_Simulation.SimJoystickReverseActive,
    SimJoystickRawX                := GVL_Simulation.SimJoystickRawX,
    SimJoystickRawY          := GVL_Simulation.SimJoystickRawY,
    SimJoystickRawButton     := GVL_Simulation.SimJoystickRawButton,
    SimKoboldContactValue    := GVL_Simulation.SimKoboldContactValue,
    BtnEmergencyStop         := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff,
    HwReal                   := HwReal,
    RawPosM1                 := _SimEncoderRawPosM1,
    RawPosM2                 := _SimEncoderRawPosM2
);

// Exposition de l'image de simulation produite par le banc
HwSim.Winch       := instSimBench.Winch;
HwSim.Translation := instSimBench.Translation;
HwSim.Operator    := instSimBench.Operator;
HwSim.Machine     := instSimBench.Machine;

IF NOT WinchInputSourceInitialized THEN
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
    WinchInputSourceInitialized := TRUE;
    WinchInputSourceChanged := FALSE;
ELSE
    WinchInputSourceChanged := (WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated);
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

// 🔧 SEL(G, IN0, IN1) : brique standard IEC 61131-3, retourne IN1 si G=TRUE, IN0 sinon
// (AF_Partie-03 §1 : composer l'existant avant réimplémentation) — remplace les 4 IF/ELSE
// compactés qui cassaient le générateur ST→LD (REX 2026-08-13, CODE_QUALITY_STANDARDS.md §11).
// Utilisation explicite de HwSim.* et des 4 variables de sélection par domaine.
HwIn.Winch       := SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch);
HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);
HwIn.Operator    := SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator);
HwIn.Machine     := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);
{endregion}


{region "§3 Traitement joystick"}
// === 🕹️ §3 TRAITEMENT JOYSTICK ===

instJoystick(
    Enable                    := TRUE,
    Reset                     := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                      := PRG_03_Modes_Cycle.Auth.Mode,
    BenneBusy                 := PRG_04_Treuils_Benne.instBucket.Busy,
    PreserveArmingAfterBucket := PRG_04_Treuils_Benne.instExtractionSequence.Busy
                                 AND (PRG_04_Treuils_Benne.instExtractionSequence.ExtractionState = E_ExtractionSequenceState.CLOSING_BUCKET),
    BusCanOpenOP              := PRG_07_Supervision.instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP                := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick,
    RawX                      := HwIn.Operator.JoyXRaw_ANA1,
    RawY                      := HwIn.Operator.JoyYRaw_ANA2,
    RawButton                 := HwIn.Operator.JoyBtnRaw,
    BtnCalibrate              := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
    InvertX                   := _JoystickInvertX,
    InvertY                   := _JoystickInvertY,
    DeadbandRaw               := _JoystickDeadbandRaw,
    FilterTime                := _JoystickFilterTime,
    NeutralHoldTime           := T#100MS,
    DeadmanArmHoldTime        := T#100MS,
    DeadmanArmGraceTime       := T#3S,
    NeutralXMem               := _JoystickNeutralX,
    NeutralYMem               := _JoystickNeutralY
);

// 📤 Publication des états et axes joystick
JoystickDeadmanArmed := instJoystick.DeadmanArmed;
JoystickYNeutral     := (instJoystick.DirectionY = 0);
JoystickDirectionX   := instJoystick.DirectionX;
JoystickSpeedPctX    := ABS(instJoystick.SpeedXPct);
JoystickXNeutral     := (instJoystick.DirectionX = 0);
{endregion}

{region "§4 Codeurs et homing — M1/M2"}
// === 🧲 §4 CODEURS & HOMING (M1 / M2) ===

// ── TREUIL M1 (Retenue) ──
instEncoderAbsM1(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn              := HwIn.Winch.COD1_PosValue,
    AlarmsIn              := HwIn.Winch.COD1_Alarms,
    WarningsIn            := HwIn.Winch.COD1_Warnings,
    SlaveOperational      := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM1.Operational,
    PresetRequest         := instHomingM1.PresetRequest,
    PresetValue           := instHomingM1.PresetValue
);

instHomingM1(
    Enable                 := TRUE,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    Home                   := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    UnitaryMode            := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                              AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 0),
    WinchSelected          := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 1),
    CfgHomingTargetM       := _WinchM1CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence    := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    TopPositionSensor      := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM       := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback          := HwIn.Winch.M1_BrakeIsOpen_DI,
    RawPos                 := instEncoderAbsM1.RawPos,
    EncoderAvailable       := instEncoderAbsM1.EncoderAvailable,
    PresetAck              := instEncoderAbsM1.PresetAck,
    PresetNak              := instEncoderAbsM1.PresetNak,
    PointsPerRev           := ENCODER_POINTS_PER_REV,
    MultiTurnRevsMax       := ENCODER_MULTITURN_REVS_MAX,
    CableM_PerRev          := WINCH_CABLE_M_PER_REV,
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    Calib                  := _CalibM1
);

instEncoderScaleM1(
    RawPos        := instEncoderAbsM1.RawPos,
    HomingRefRaw  := instHomingM1.HomingRefRaw,
    CableM_PerRev := WINCH_CABLE_M_PER_REV,
    PointsPerRev  := ENCODER_POINTS_PER_REV
);

instEncoderSafetyM1(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM             := instEncoderScaleM1.CablePosM,
    HomingSuspect         := instHomingM1.HomingSuspect,
    BypassGlobal          := GVL_IHM.M1TreuilRetenue.Bypass.Global
);
CablePosM1           := instEncoderSafetyM1.CablePosMSafe;
M1_EncoderIncoherent := instEncoderSafetyM1.EncoderIncoherent;

instEncoderSpeedMeasureM1(
    Enable        := TRUE,
    Reset         := PRG_07_Supervision.FaultMachineReset_IHM,
    Position_M    := instEncoderSafetyM1.CablePosMSafe,
    PositionValid := instEncoderAbsM1.EncoderAvailable AND NOT instEncoderSafetyM1.EncoderIncoherent
);
M1_Speed_Mps       := instEncoderSpeedMeasureM1.Speed_Mps;
M1_SignedSpeed_Mps := instEncoderSpeedMeasureM1.SignedSpeed_Mps;
M1_SpeedValid      := instEncoderSpeedMeasureM1.Valid;

// ── TREUIL M2 (Benne) ──
instEncoderAbsM2(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn              := HwIn.Winch.COD2_PosValue,
    AlarmsIn              := HwIn.Winch.COD2_Alarms,
    WarningsIn            := HwIn.Winch.COD2_Warnings,
    SlaveOperational      := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM2.Operational,
    PresetRequest         := instHomingM2.PresetRequest,
    PresetValue           := instHomingM2.PresetValue
);

// Synchronisation référencement M2 sur ouverture/fermeture benne
M2BucketRefOpenEdge(CLK := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos);
M2BucketRefCloseEdge(CLK := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos);
M2BucketRefRequested := (M2BucketRefOpenEdge.Q OR M2BucketRefCloseEdge.Q)
    AND (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
    AND NOT PRG_04_Treuils_Benne.instWinchM1.Busy AND NOT PRG_04_Treuils_Benne.instWinchM2.Busy;
IF M2BucketRefRequested AND M2BucketRefOpenEdge.Q THEN
    M2BucketRefTargetM := CablePosM1;
ELSIF M2BucketRefRequested AND M2BucketRefCloseEdge.Q THEN
    M2BucketRefTargetM := CablePosM1 + _BucketCfgPersist.Config.OffsetCloseM;
END_IF;

instHomingM2(
    Enable                 := TRUE,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    Home                   := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero OR M2BucketRefRequested,
    UseDynamicTarget       := M2BucketRefRequested,
    DynamicHomingTargetM   := M2BucketRefTargetM,
    UnitaryMode            := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                              AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 0),
    WinchSelected          := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2),
    CfgHomingTargetM       := _WinchM2CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence    := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence,
    TopPositionSensor      := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM       := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _WinchM2CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback          := HwIn.Winch.M2_BrakeIsOpen_DI,
    RawPos                 := instEncoderAbsM2.RawPos,
    EncoderAvailable       := instEncoderAbsM2.EncoderAvailable,
    PresetAck              := instEncoderAbsM2.PresetAck,
    PresetNak              := instEncoderAbsM2.PresetNak,
    PointsPerRev           := ENCODER_POINTS_PER_REV,
    MultiTurnRevsMax       := ENCODER_MULTITURN_REVS_MAX,
    CableM_PerRev          := WINCH_CABLE_M_PER_REV,
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    Calib                  := _CalibM2
);

instEncoderScaleM2(
    RawPos        := instEncoderAbsM2.RawPos,
    HomingRefRaw  := instHomingM2.HomingRefRaw,
    CableM_PerRev := WINCH_CABLE_M_PER_REV,
    PointsPerRev  := ENCODER_POINTS_PER_REV
);

instEncoderSafetyM2(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM             := instEncoderScaleM2.CablePosM,
    HomingSuspect         := instHomingM2.HomingSuspect,
    BypassGlobal          := GVL_IHM.M2TreuilBenne.Bypass.Global
);
CablePosM2           := instEncoderSafetyM2.CablePosMSafe;
M2_EncoderIncoherent := instEncoderSafetyM2.EncoderIncoherent;

instEncoderSpeedMeasureM2(
    Enable        := TRUE,
    Reset         := PRG_07_Supervision.FaultMachineReset_IHM,
    Position_M    := instEncoderSafetyM2.CablePosMSafe,
    PositionValid := instEncoderAbsM2.EncoderAvailable AND NOT instEncoderSafetyM2.EncoderIncoherent
);
M2_Speed_Mps       := instEncoderSpeedMeasureM2.Speed_Mps;
M2_SignedSpeed_Mps := instEncoderSpeedMeasureM2.SignedSpeed_Mps;
M2_SpeedValid      := instEncoderSpeedMeasureM2.Valid;
{endregion}

{region "§5 Décodage position translation — M3"}
// === ↔️ §5 DÉCODAGE POSITION TRANSLATION (M3) ===

instPosDecoderM3(
    SensorTremie      := HwIn.Translation.M3_PosTremie_DI,
    SensorPV          := HwIn.Translation.M3_PosPV_DI,
    SensorP2          := HwIn.Translation.M3_PosPVP2_DI,
    SensorP1          := HwIn.Translation.M3_PosP1_DI,
    SensorMaintenance := HwIn.Translation.M3_PosMaintenance_DI
);

TranslationPosTremie      := instPosDecoderM3.TranslationPosTremie;
TranslationPosPV          := instPosDecoderM3.TranslationPosPV;
TranslationPosP2          := instPosDecoderM3.TranslationPosP2;
TranslationPosP1          := instPosDecoderM3.TranslationPosP1;
TranslationPosMaintenance := instPosDecoderM3.TranslationPosMaintenance;
TranslationAtTremie      := instPosDecoderM3.TranslationAtTremie;
TranslationAtPV          := instPosDecoderM3.TranslationAtPV;
TranslationAtP2          := instPosDecoderM3.TranslationAtP2;
TranslationAtP1          := instPosDecoderM3.TranslationAtP1;
TranslationAtMaintenance := instPosDecoderM3.TranslationAtMaintenance;
M3_LimitSwitchFwd       := instPosDecoderM3.LimitSwitchFwd;
M3_LimitSwitchRev       := instPosDecoderM3.LimitSwitchRev;
M3_SensorWordIncoherent := instPosDecoderM3.Incoherent;
{endregion}

{region "§6 Retours variateur — M3"}
// === 📊 §6 RETOURS VARIATEUR (M3) CONDITIONNÉS ===
M3_StatusWord_Filtered        := WORD_TO_UINT(HwIn.Translation.M3_StatusWord);
M3_ActualFrequencyHz_Filtered := HwIn.Translation.M3_ActualFrequencyHz;
{endregion}

END_PROGRAM

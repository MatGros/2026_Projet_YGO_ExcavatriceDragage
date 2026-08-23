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

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA GVL_IHM & GVL_Simulation) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data                     : ST_AcquisitionInterPrg; // <-- [BUS] Mesures/joystick/positions M3/diag DI publiés

    // === 🖼️ IMAGES PROCESS MATÉRIEL / SIMULATION ===
    HwReal                   : ST_HardwareImage; // <-- [STAT] Image brute reelle physique
    HwSim                    : ST_HardwareImage; // <-- [STAT] Image simulee banc
    HwIn                     : ST_HardwareImage; // <-- [STAT] Image utilisee par le metier (arbitree)
END_VAR

VAR
    // === 🧩 SOUS-INSTANCES FB ===
    instSimBench             : FB_SimBench;                   // * [INST] Banc de simulation integré
    instJoystick             : FB_Joystick;                   // * [INST] Traitement et filtrage joystick
    instDiagCanOpen          : FB_Diag_CanOpen;               // * [INST] Diagnostic reseau CANopen (joystick) — rang 02 (consomme PRG 04/05)
    instDiagEthercat         : FB_Diag_Ethercat;              // * [INST] Diagnostic reseau EtherCAT (codeurs/variateur) — rang 02
    instEncoderM1            : FB_Encoder;                    // * [INST] Facade codeur complet M1 (Abs+Homing+Scale+Safety+Rel+Speed)
    instEncoderM2            : FB_Encoder;                    // * [INST] Facade codeur complet M2
    instPosDecoderM3         : FB_Translation_PositionDecoder;// * [INST] Decodage position translation M3

    // === 🎛️ VARIABLES LOCALES & DÉTECTEURS ===
    M2BucketRefOpenEdge      : R_TRIG; // . [LOC] Front demande reference benne ouverte
    M2BucketRefCloseEdge     : R_TRIG; // . [LOC] Front demande reference benne fermee
    M2BucketRefRequested     : BOOL;   // . [LOC] Demande d'etalonnage M2 active
    M2BucketRefTargetM       : REAL;   // . [LOC] Cible metrique etalonnage M2
    HwM1                     : ST_EncoderHw; // . [LOC] Frontiere hardware codeur M1 (in/out)
    HwM2                     : ST_EncoderHw; // . [LOC] Frontiere hardware codeur M2 (in/out)

    WinchInputSourceSimulated         : BOOL; // . [LOC] Source Winch simulee active
    TranslationInputSourceSimulated   : BOOL; // . [LOC] Source Translation simulee active
    OperatorInputSourceSimulated      : BOOL; // . [LOC] Source Pupitre simulee active
    MachineInputSourceSimulated       : BOOL; // . [LOC] Source Machine simulee active

    PreviousWinchInputSourceSimulated : BOOL; // . [LOC] Memoire cycle precedent source Winch
    WinchInputSourceInitialized       : BOOL; // . [LOC] Indicateur initialisation source Winch

    SimulationModeRise                : R_TRIG; // . [LOC] Front montant activation simulation
    SimulationModeFall                : F_TRIG; // . [LOC] Front descendant desactivation simulation
END_VAR

VAR CONSTANT
    // === ⚙️ CONSTANTES MÉCANIQUES (AF09 §2) ===
    ENCODER_POINTS_PER_REV     : UDINT := 8192; // 13 bits single-turn (8192 pts/tour)
    ENCODER_MULTITURN_REVS_MAX : UDINT := 4096; // 12 bits multi-turn (4096 tours max)
    WINCH_CABLE_M_PER_REV      : REAL  := 2.0;  // 2.0 metres de cable par tour tambour
END_VAR

{region "§0 Session simulation & aiguillage"}
// === 🧪 §0 SIMULATION & SÉLECTION DE SOURCE ===
// 🎯 Producteur unique des aiguillages Reel/Simu par domaine (HwReal vs HwSim -> HwIn).

SimulationModeRise(CLK := GVL_Simulation.SimulationModeActive);
SimulationModeFall(CLK := GVL_Simulation.SimulationModeActive);

IF SimulationModeRise.Q THEN
    GVL_Simulation.SimWinchActive := TRUE;
    GVL_Simulation.SimTranslationActive := TRUE;
    GVL_Simulation.SimOperatorActive := TRUE;
    GVL_Simulation.SimSafetyActive := TRUE;
END_IF;

IF SimulationModeFall.Q THEN
    GVL_Simulation.SimWinchActive := FALSE;
    GVL_Simulation.SimTranslationActive := FALSE;
    GVL_Simulation.SimOperatorActive := FALSE;
    GVL_Simulation.SimSafetyActive := FALSE;
    GVL_Simulation.SimM3SensorsWordOverrideActive := FALSE;
    GVL_Simulation.SimM3SensorsWord := 16#07;
    GVL_Simulation.SimJoystickLeft_Rev_TREMIE_Active := FALSE;
    GVL_Simulation.SimJoystickRight_Fwd_MAINT_Active := FALSE;
    GVL_Simulation.SimJoystickFwd_Up_Close_Active := FALSE;
    GVL_Simulation.SimJoystickRev_Down_Open_Active := FALSE;
    GVL_Simulation.SimJoystickRawX := 5000;
    GVL_Simulation.SimJoystickRawY := 5000;
    GVL_Simulation.SimJoystickRawButton := FALSE;
    GVL_Simulation.SimJoystickOvershoot_Active := FALSE;
    GVL_Simulation.SimJoystickBagotement_Active := FALSE;
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
HwReal.Machine.HopperFull_OR_GateRaised_DI := HopperFull_OR_GateRaised_DI; // Déclaré, pas encore consommé
{endregion}

{region "§1bis Diagnostic modules DI"}
// 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (AF06 §3bis).
// GetDeviceState() = RUNNING => module opérationnel. Si la simulation globale/machine est active,
// les cartes physiques absentes sont simulées OK pour permettre le fonctionnement banc.
IF MachineInputSourceSimulated THEN
    Data.LocalDigitalIoOk := TRUE;
    Data.Vh0800EndOk      := TRUE;
    Data.Vh0808EtpOk      := TRUE;
ELSE
    Data.LocalDigitalIoOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.Vh0800EndOk      := (VH_0800END.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.Vh0808EtpOk      := (VH_0808ETP.GetDeviceState() = DEVICE_STATE.RUNNING);
END_IF;
Data.InputModuleFault := NOT (Data.LocalDigitalIoOk AND Data.Vh0800EndOk AND Data.Vh0808EtpOk);
{endregion}

{region "§1ter Diagnostic reseaux (CANopen + EtherCAT)"}
// 🔌 Diagnostics reseau produits ICI (rang 02) car consommes par PRG_02 (joystick,
// codeurs) et par les PRG 04/05 — producteur avant consommateur (AF02 §4).
instDiagCanOpen(
    Enable                 := TRUE,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    CANbusStateRaw         := HwReal.Operator.CanBusState,
    DeviceJoystickStateRaw := HwReal.Operator.JOY1_DeviceState,
    SimBypassActive        := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive,
    NetworkBypassActive    := GVL_IHM.Network.Bypass.Global
);
instDiagEthercat(
    Enable                   := TRUE,
    Reset                    := PRG_07_Supervision.FaultMachineReset_IHM,
    DeviceVariateurStateRaw  := HwReal.Translation.AC600_DeviceState,
    DeviceVariateurSimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive,
    DeviceEncoderM1StateRaw  := HwReal.Winch.COD1_DeviceState,
    DeviceEncoderM1SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    DeviceEncoderM2StateRaw  := HwReal.Winch.COD2_DeviceState,
    DeviceEncoderM2SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    NetworkBypassActive      := GVL_IHM.Network.Bypass.Global
);
{endregion}

{region "§2 Simulation et aiguillage — HwIn"}
// === 🎭 §2 SIMULATION & AIGUILLAGE (HwIn) ===

instSimBench(
    Enable                   := GVL_Simulation.SimulationModeActive,
    M1_RelayFwd              := PRG_06_Outputs.Data.M1RelayFwd,
    M1_RelayRev              := PRG_06_Outputs.Data.M1RelayRev,
    M1_SpeedContactor_1      := PRG_06_Outputs.Data.M1SpeedContactor1,
    M1_SpeedContactor_2      := PRG_06_Outputs.Data.M1SpeedContactor2,
    M1_SpeedContactor_3      := PRG_06_Outputs.Data.M1SpeedContactor3,
    M1_SpeedContactor_4      := PRG_06_Outputs.Data.M1SpeedContactor4,
    M1_SpeedRefPct           := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedRef_Pct,
    M1_StepNumber            := PRG_04_Treuils_Benne.Data.WinchM1State.StepNumber,
    M1_PresetTriggerCmd      := instEncoderM1.HwOut.PresetTriggerCmd,
    M1_PresetValueOut        := instEncoderM1.HwOut.PresetValueOut,
    M1_BrakeCmd              := PRG_06_Outputs.Data.M1BrakeCmd,
    M2_RelayFwd              := PRG_06_Outputs.Data.M2RelayFwd,
    M2_RelayRev              := PRG_06_Outputs.Data.M2RelayRev,
    M2_SpeedContactor_1      := PRG_06_Outputs.Data.M2SpeedContactor1,
    M2_SpeedContactor_2      := PRG_06_Outputs.Data.M2SpeedContactor2,
    M2_SpeedContactor_3      := PRG_06_Outputs.Data.M2SpeedContactor3,
    M2_SpeedContactor_4      := PRG_06_Outputs.Data.M2SpeedContactor4,
    M2_SpeedRefPct           := PRG_04_Treuils_Benne.Data.M2LogicRequestSpeedRef_Pct,
    M2_StepNumber            := PRG_04_Treuils_Benne.Data.WinchM2State.StepNumber,
    M2_PresetTriggerCmd      := instEncoderM2.HwOut.PresetTriggerCmd,
    M2_PresetValueOut        := instEncoderM2.HwOut.PresetValueOut,
    M2_BrakeCmd              := PRG_06_Outputs.Data.M2BrakeCmd,
    // 🧪 Simulation M3 — FIDÉLITÉ : le modèle ne doit progresser QUE quand la
    // vraie machine commande réellement (sortie FB_Translation, post-interlock), pas sur la
    // commande brute (sinon il outrepasse butées/limites). Même principe que les treuils M1/M2
    // (alimentés par la sortie PRG_06). Gate direction + vitesse = demande réelle (rampe/arrêt).
    M3_Direction             := SEL(PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord <> 0,
                                    PRG_05_Translation.M3_Direction_Active, 0),
    M3_SpeedRefPct           := LIMIT(0.0,
                                      PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz / GVL_PERSISTENT._TranslationMaxFreq_Hz * 100.0,
                                      100.0),
    M3_BrakeCmd              := PRG_06_Outputs.Data.TranslationBrakeCmd,
    PowerKeepAlive_A         := PRG_06_Outputs.Data.PowerKeepAliveACmd,
    PowerKeepAlive_B         := PRG_06_Outputs.Data.PowerKeepAliveBCmd,
    // 🧪 Simulation uniquement : l'état étape 5 sécurise le transfert même si la sortie
    // inter-POU ArmPulse est observée avec un cycle de retard dans la tâche.
    EmergencyArming_RQ       := PRG_06_Outputs.Data.EmergencyArmingCmd
                                 OR (PRG_06_Outputs.ArmingSeqStep = 5),
    SimEncoderSpeedFactor    := GVL_Simulation.SimEncoderSpeedFactor,
    SimSyncDeviationInjectM1 := GVL_Simulation.SimSyncDeviationInjectM1,
    SimSyncDeviationInjectM2 := GVL_Simulation.SimSyncDeviationInjectM2,
    SimSyncDeviationOffset_M := GVL_Simulation.SimSyncDeviationOffset_M,
    SimM3SensorsWordOverrideActive := GVL_Simulation.SimM3SensorsWordOverrideActive,
    SimM3SensorsWord               := GVL_Simulation.SimM3SensorsWord,
    SimJoystickLeft_Rev_TREMIE_Active  := GVL_Simulation.SimJoystickLeft_Rev_TREMIE_Active,
    SimJoystickRight_Fwd_MAINT_Active  := GVL_Simulation.SimJoystickRight_Fwd_MAINT_Active,
    SimJoystickFwd_Up_Close_Active     := GVL_Simulation.SimJoystickFwd_Up_Close_Active,
    SimJoystickRev_Down_Open_Active    := GVL_Simulation.SimJoystickRev_Down_Open_Active,
    SimJoystickRawX                    := GVL_Simulation.SimJoystickRawX,
    SimJoystickRawY                    := GVL_Simulation.SimJoystickRawY,
    SimJoystickRawButton               := GVL_Simulation.SimJoystickRawButton,
    SimJoystickOvershoot_Active        := GVL_Simulation.SimJoystickOvershoot_Active,
    SimJoystickBagotement_Active       := GVL_Simulation.SimJoystickBagotement_Active,
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
    Data.WinchInputSourceChanged := FALSE;
ELSE
    Data.WinchInputSourceChanged := (WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated);
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

// 🔧 SEL(G, IN0, IN1) : brique standard IEC 61131-3, retourne IN1 si G=TRUE, IN0 sinon
// (AF_Partie-03 §1 : composer l'existant avant réimplémentation) — remplace les 4 IF/ELSE
// compactés qui cassaient le générateur ST→LD (CODE_QUALITY_STANDARDS.md §11).
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
    // 🚨 ArmingPermit = ENTRÉE du joystick (vue joystick), alimentée de n'importe où.
    // 🔧 Câblage TEMPORAIRE : producteur à analyser plus tard (hors scope LOT_JOYSTICK_ARMINGPERMIT).
    //    TRUE = armement autorisé en attendant la future chaîne de permission système.
    ArmingPermit              := TRUE,
    BusCanOpenOP              := instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP                := instDiagCanOpen.DeviceJoystick,
    RawX                      := HwIn.Operator.JoyXRaw_ANA1,
    RawY                      := HwIn.Operator.JoyYRaw_ANA2,
    RawButton                 := HwIn.Operator.JoyBtnRaw,
    BtnCalibrate              := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
    DeadbandRaw               := _JoystickDeadbandRaw,
    NeutralHoldTime           := T#100MS,
    DeadmanArmHoldTime        := T#100MS,
    DeadmanArmGraceTime       := T#3S,
    RawOutOfRangeMargin       := 500,
    NeutralXMem               := _JoystickNeutralX,
    NeutralYMem               := _JoystickNeutralY
);

// 📤 Publication des états et axes joystick
Data.JoystickDeadmanArmed := instJoystick.DeadmanArmed;
Data.JoystickYNeutral     := (instJoystick.DirectionY = 0);
Data.JoystickDirectionX   := instJoystick.DirectionX;
Data.JoystickSpeedPctX    := ABS(instJoystick.SpeedXPct);
Data.JoystickXNeutral     := (instJoystick.DirectionX = 0);
{endregion}

{region "§4 Codeurs et homing — M1/M2"}
// === 🧲 §4 CODEURS & HOMING (M1 / M2) ===

// ── TREUIL M1 (Retenue) ──
// Facade codeur complete : Abs→Homing→Scale→Safety→Reliability→Speed.
// L'autorisation de homing est calculee ici (mode + treuil selectionne).
// Frontiere hardware remplie avant l'appel (le bus Hw est passe en entier).
HwM1.RawPosIn          := HwIn.Winch.COD1_PosValue;
HwM1.AlarmsIn          := HwIn.Winch.COD1_Alarms;
HwM1.WarningsIn        := HwIn.Winch.COD1_Warnings;
HwM1.SlaveOperational  := instDiagEthercat.DeviceEncoderM1.Operational;
instEncoderM1(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    HomingPermit          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                             AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 2),
    HomingAtTargetM       := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome,
    HomingAtZero          := GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    ConfirmCoherence      := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    CfgHomingTargetM      := _WinchM1CfgPersist.CfgHomingTarget_M,
    CfgTopSensorPosM      := _WinchM1CfgPersist.CfgTopSensorPos_M,
    UseDynamicTarget      := FALSE,
    DynamicHomingTargetM  := 0.0,
    TopPositionSensor     := HwIn.Winch.M1M2_TopPositionFree_DI,
    Hw                    := HwM1,
    PointsPerRev          := ENCODER_POINTS_PER_REV,
    CableM_PerRev         := WINCH_CABLE_M_PER_REV,
    BypassGlobal          := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    Calib                 := _CalibM1
);
Data.CablePosM1           := instEncoderM1.Measurement.CablePosM;
Data.M1_EncoderIncoherent := instEncoderM1.Measurement.EncoderIncoherent;
Data.M1_EncoderFault      := instEncoderM1.EncoderFault;
Data.M1_HomedAndReliable  := instEncoderM1.HomedAndReliable;
Data.M1_Speed_Mps         := instEncoderM1.Measurement.Speed_Mps;
Data.M1_SignedSpeed_Mps   := instEncoderM1.Measurement.SignedSpeed_Mps;
Data.M1_SpeedValid        := instEncoderM1.Measurement.SpeedValid;
COD1_PresettTrigCmd := instEncoderM1.HwOut.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderM1.HwOut.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderM1.HwOut.PresetValueOut;

// ── TREUIL M2 (Benne) ──
// Ordre POO : synchronisation benne, puis Homing, puis facade.

// Synchronisation référencement M2 sur ouverture/fermeture benne
M2BucketRefOpenEdge(CLK := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos);
M2BucketRefCloseEdge(CLK := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos);
M2BucketRefRequested := (M2BucketRefOpenEdge.Q OR M2BucketRefCloseEdge.Q)
    AND (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
    AND NOT PRG_04_Treuils_Benne.instWinchM1.Status.Busy AND NOT PRG_04_Treuils_Benne.instWinchM2.Status.Busy;
IF M2BucketRefRequested AND M2BucketRefOpenEdge.Q THEN
    M2BucketRefTargetM := Data.CablePosM1;
ELSIF M2BucketRefRequested AND M2BucketRefCloseEdge.Q THEN
    M2BucketRefTargetM := Data.CablePosM1 + _BucketCfgPersist.Config.OffsetCloseM;
END_IF;

// Frontiere hardware remplie avant l'appel (le bus Hw est passe en entier).
HwM2.RawPosIn          := HwIn.Winch.COD2_PosValue;
HwM2.AlarmsIn          := HwIn.Winch.COD2_Alarms;
HwM2.WarningsIn        := HwIn.Winch.COD2_Warnings;
HwM2.SlaveOperational  := instDiagEthercat.DeviceEncoderM2.Operational;
instEncoderM2(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    HomingPermit          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                             AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 1),
    HomingAtTargetM       := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR M2BucketRefRequested,
    HomingAtZero          := GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero,
    ConfirmCoherence      := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence,
    CfgHomingTargetM      := _WinchM2CfgPersist.CfgHomingTarget_M,
    CfgTopSensorPosM      := _WinchM2CfgPersist.CfgTopSensorPos_M,
    UseDynamicTarget      := M2BucketRefRequested,
    DynamicHomingTargetM  := M2BucketRefTargetM,
    TopPositionSensor     := HwIn.Winch.M1M2_TopPositionFree_DI,
    Hw                    := HwM2,
    PointsPerRev          := ENCODER_POINTS_PER_REV,
    CableM_PerRev         := WINCH_CABLE_M_PER_REV,
    BypassGlobal          := GVL_IHM.M2TreuilBenne.Bypass.Global,
    Calib                 := _CalibM2
);
Data.CablePosM2           := instEncoderM2.Measurement.CablePosM;
Data.M2_EncoderIncoherent := instEncoderM2.Measurement.EncoderIncoherent;
Data.M2_EncoderFault      := instEncoderM2.EncoderFault;
Data.M2_HomedAndReliable  := instEncoderM2.HomedAndReliable;
Data.M2_Speed_Mps         := instEncoderM2.Measurement.Speed_Mps;
Data.M2_SignedSpeed_Mps   := instEncoderM2.Measurement.SignedSpeed_Mps;
Data.M2_SpeedValid        := instEncoderM2.Measurement.SpeedValid;
COD2_PresettTrigCmd := instEncoderM2.HwOut.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderM2.HwOut.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderM2.HwOut.PresetValueOut;
{endregion}

{region "§5 Acquisition Translation M3"}
// === ↔️ §5 ACQUISITION TRANSLATION (M3) — position & retours variateur ===

instPosDecoderM3(
    SensorTremie      := HwIn.Translation.M3_PosTremie_DI,
    SensorPV          := HwIn.Translation.M3_PosPV_DI,
    SensorP2          := HwIn.Translation.M3_PosPVP2_DI,
    SensorP1          := HwIn.Translation.M3_PosP1_DI,
    SensorMaintenance := HwIn.Translation.M3_PosMaintenance_DI
);

Data.TranslationPosTremie      := instPosDecoderM3.TranslationPosTremie;
Data.TranslationPosPV          := instPosDecoderM3.TranslationPosPV;
Data.TranslationPosP2          := instPosDecoderM3.TranslationPosP2;
Data.TranslationPosP1          := instPosDecoderM3.TranslationPosP1;
Data.TranslationPosMaintenance := instPosDecoderM3.TranslationPosMaintenance;
Data.TranslationAtTremie      := instPosDecoderM3.TranslationAtTremie;
Data.TranslationAtPV          := instPosDecoderM3.TranslationAtPV;
Data.TranslationAtP2          := instPosDecoderM3.TranslationAtP2;
Data.TranslationAtP1          := instPosDecoderM3.TranslationAtP1;
Data.TranslationAtMaintenance := instPosDecoderM3.TranslationAtMaintenance;
Data.M3_LimitSwitchFwd       := instPosDecoderM3.LimitSwitchFwd;
Data.M3_LimitSwitchRev       := instPosDecoderM3.LimitSwitchRev;
Data.M3_SensorWordIncoherent := instPosDecoderM3.Incoherent;
// ⚠️ M3_SensorsWord jamais assigné (bug préexistant) — conservé à 0, à corriger en lot dédié.
Data.M3_SensorsWord            := 0;

// 📊 Retours variateur M3 conditionnés (HwIn arbitré en §2)
Data.M3_StatusWord_Filtered        := WORD_TO_UINT(HwIn.Translation.M3_StatusWord);
Data.M3_ActualFrequencyHz_Filtered := HwIn.Translation.M3_ActualFrequencyHz;
{endregion}

END_PROGRAM

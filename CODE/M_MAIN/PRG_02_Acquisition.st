(* ═══════════════════════════════════════════════════════════════
   📡 PRG_02_Acquisition — Programme d'Acquisition et Conditionnement I/O
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1 (premier POU du cycle).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §2
   🎯 Rôle unique : Produire les images HwReal/HwSim/HwIn,
      acquérir et traiter les mesures codeurs (M1/M2), décoder M3, traiter le joystick
      et publier les retours qualifiés sur le bus Data.
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
    instMachineHomingCycle       : FB_MachineHomingCycle;             // * [INST] Guide reference machine et homing conjoint benne

    // === 🎛️ VARIABLES LOCALES & DÉTECTEURS ===
    HwInM1                   : ST_fbEncoder_HwIn; // . [LOC] Entrees hardware codeur M1
    HwInM2                   : ST_fbEncoder_HwIn; // . [LOC] Entrees hardware codeur M2
    MachineHomingM1Status    : ST_fbMachineHomingCycle_AxisHomingStatus; // . [LOC] Statut homing M1
    MachineHomingM2Status    : ST_fbMachineHomingCycle_AxisHomingStatus; // . [LOC] Statut homing M2
    MachineHomingMechanicalStopOk : BOOL; // . [LOC] Arret mecanique conjoint M1/M2 confirme

    WinchInputSourceSimulated         : BOOL; // . [LOC] Source Winch simulee active
    TranslationInputSourceSimulated   : BOOL; // . [LOC] Source Translation simulee active
    OperatorInputSourceSimulated      : BOOL; // . [LOC] Source Pupitre simulee active
    MachineInputSourceSimulated       : BOOL; // . [LOC] Source Machine simulee active

    PreviousWinchInputSourceSimulated : BOOL; // . [LOC] Memoire cycle precedent source Winch
    WinchInputSourceInitialized       : BOOL; // . [LOC] Indicateur initialisation source Winch
    PreviousTranslationInputSourceSimulated : BOOL; // . [LOC] Memoire cycle precedent source Translation
    TranslationInputSourceInitialized        : BOOL; // . [LOC] Indicateur initialisation source Translation
    PreviousOperatorInputSourceSimulated     : BOOL; // . [LOC] Memoire cycle precedent source Operateur
    OperatorInputSourceInitialized           : BOOL; // . [LOC] Indicateur initialisation source Operateur
    PreviousMachineInputSourceSimulated      : BOOL; // . [LOC] Memoire cycle precedent source Machine
    MachineInputSourceInitialized            : BOOL; // . [LOC] Indicateur initialisation source Machine

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
    GVL_Simulation.SimTopPositionActive := FALSE;
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
HwReal.Machine.TremieFull_OR_GateRaised_DI := TremieFull_OR_GateRaised_DI; // 🚧 Déclaré, non consommé — interlock trémie à câbler
{endregion}

{region "§1bis Diagnostic modules E/S"}
// === 🩺 §1bis DIAGNOSTIC MODULES E/S ===
// 🩺 Diagnostic carte des 5 modules d'E/S physiques (AF06 §3bis).
// GetDeviceState() = RUNNING => module opérationnel. Si la simulation globale/machine est active,
// les cartes physiques absentes sont simulées OK pour permettre le fonctionnement banc.
IF MachineInputSourceSimulated OR GVL_IHM.Network.Bypass.Global OR GVL_IHM.Network.Bypass.InputModules THEN
    Data.InputModules.LocalDigitalIoOk := TRUE;
    Data.InputModules.Vh0800EndOk      := TRUE;
    Data.InputModules.Vh0808EtpOk      := TRUE;
    Data.InputModules.Vh0008ErOk       := TRUE;
    Data.InputModules.Vh0008Er1Ok      := TRUE;
ELSE
    Data.InputModules.LocalDigitalIoOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.InputModules.Vh0800EndOk      := (VH_0800END.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.InputModules.Vh0808EtpOk      := (VH_0808ETP.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.InputModules.Vh0008ErOk       := (VH_0008ER.GetDeviceState() = DEVICE_STATE.RUNNING);
    Data.InputModules.Vh0008Er1Ok      := (VH_0008ER_1.GetDeviceState() = DEVICE_STATE.RUNNING);
END_IF;
Data.InputModules.Fault := NOT (Data.InputModules.LocalDigitalIoOk AND Data.InputModules.Vh0800EndOk AND Data.InputModules.Vh0808EtpOk AND Data.InputModules.Vh0008ErOk AND Data.InputModules.Vh0008Er1Ok);
{endregion}

{region "§1ter Diagnostic reseaux (CANopen + EtherCAT)"}
// === 🔌 §1ter DIAGNOSTIC RÉSEAUX (CANopen + EtherCAT) ===
// 🔌 Diagnostics reseau produits ICI (rang 02) car consommes par PRG_02 (joystick,
// codeurs) et par les PRG 04/05 — producteur avant consommateur (AF02 §4).
instDiagCanOpen(
    Enable                 := TRUE,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    CANbusStateRaw         := HwReal.Operator.CanBusState,
    DeviceJoystickStateRaw := HwReal.Operator.JOY1_DeviceState,
    SimBypassActive        := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive,
    NetworkBypassActive    := GVL_IHM.Network.Bypass.Global,
    CanBusBypassActive     := GVL_IHM.Network.Bypass.BusCanOpen,
    JoystickBypassActive   := GVL_IHM.Network.Bypass.Joystick
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
    NetworkBypassActive      := GVL_IHM.Network.Bypass.Global,
    EcatBusBypassActive      := GVL_IHM.Network.Bypass.BusEthercat,
    VariateurBypassActive    := GVL_IHM.Network.Bypass.VariateurM3,
    EncoderM1BypassActive    := GVL_IHM.Network.Bypass.EncoderM1,
    EncoderM2BypassActive    := GVL_IHM.Network.Bypass.EncoderM2
);

// 📤 Publication du sous-bus diagnostics réseaux
Data.Network.CanOpenMaster   := instDiagCanOpen.DeviceCanOpenMaster;
Data.Network.Joystick        := instDiagCanOpen.DeviceJoystick;
Data.Network.EthercatMaster  := instDiagEthercat.DeviceEthercatMaster;
Data.Network.EncoderM1       := instDiagEthercat.DeviceEncoderM1;
Data.Network.EncoderM2       := instDiagEthercat.DeviceEncoderM2;
Data.Network.DriveM3         := instDiagEthercat.DeviceVariateur;
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
    M1_SpeedCmd_Pct          := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedCmd_Pct,
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
    M2_SpeedCmd_Pct          := PRG_04_Treuils_Benne.Data.M2LogicRequestSpeedCmd_Pct,
    M2_StepNumber            := PRG_04_Treuils_Benne.Data.WinchM2State.StepNumber,
    M2_PresetTriggerCmd      := instEncoderM2.HwOut.PresetTriggerCmd,
    M2_PresetValueOut        := instEncoderM2.HwOut.PresetValueOut,
    M2_BrakeCmd              := PRG_06_Outputs.Data.M2BrakeCmd,
    // 🧪 Simulation M3 — FIDÉLITÉ : le modèle ne doit progresser QUE quand la
    // vraie machine commande réellement (sortie FB_Translation, post-interlock), pas sur la
    // commande brute (sinon il outrepasse butées/limites). Même principe que les treuils M1/M2
    // (alimentés par la sortie PRG_06). Gate direction + vitesse = demande réelle (rampe/arrêt).
    M3_Direction             := SEL(PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord <> 0,
                                    PRG_05_Translation.Data.TranslationState.ActiveDirection, 0),
    M3_SpeedCmd_Pct          := LIMIT(0.0,
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
    CfgTopSensorRawPos       := REAL_TO_UDINT(_WinchM1CfgPersist.CfgTopSensorPos_M
                                 * (UDINT_TO_REAL(ENCODER_POINTS_PER_REV) / WINCH_CABLE_M_PER_REV)),
    SimTopPositionActive     := GVL_Simulation.SimTopPositionActive,
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

// 🔀 Détection de bascule de source (réel/simu) par domaine — impulsion 1 cycle.
// Même pattern que Winch : mémoire Previous*InputSourceSimulated + comparaison.
IF NOT WinchInputSourceInitialized THEN
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
    WinchInputSourceInitialized := TRUE;
    Data.InputSource.WinchInputSourceChanged := FALSE;
ELSE
    Data.InputSource.WinchInputSourceChanged := (WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated);
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

IF NOT TranslationInputSourceInitialized THEN
    PreviousTranslationInputSourceSimulated := TranslationInputSourceSimulated;
    TranslationInputSourceInitialized := TRUE;
    Data.InputSource.TranslationInputSourceChanged := FALSE;
ELSE
    Data.InputSource.TranslationInputSourceChanged := (TranslationInputSourceSimulated <> PreviousTranslationInputSourceSimulated);
    PreviousTranslationInputSourceSimulated := TranslationInputSourceSimulated;
END_IF;

IF NOT OperatorInputSourceInitialized THEN
    PreviousOperatorInputSourceSimulated := OperatorInputSourceSimulated;
    OperatorInputSourceInitialized := TRUE;
    Data.InputSource.OperatorInputSourceChanged := FALSE;
ELSE
    Data.InputSource.OperatorInputSourceChanged := (OperatorInputSourceSimulated <> PreviousOperatorInputSourceSimulated);
    PreviousOperatorInputSourceSimulated := OperatorInputSourceSimulated;
END_IF;

IF NOT MachineInputSourceInitialized THEN
    PreviousMachineInputSourceSimulated := MachineInputSourceSimulated;
    MachineInputSourceInitialized := TRUE;
    Data.InputSource.MachineInputSourceChanged := FALSE;
ELSE
    Data.InputSource.MachineInputSourceChanged := (MachineInputSourceSimulated <> PreviousMachineInputSourceSimulated);
    PreviousMachineInputSourceSimulated := MachineInputSourceSimulated;
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
    // 🔧 Producteur = PRG_04_Treuils_Benne (combiné interlock benne) via le bus Data.
    //    TRUE = armement autorisé (polarité positive NC-100).
    ArmingPermit              := PRG_04_Treuils_Benne.Data.ArmingPermit,
    BusCanOpenOP              := instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP                := instDiagCanOpen.DeviceJoystick,
    RawX                      := HwIn.Operator.JoyXRaw_ANA1,
    RawY                      := HwIn.Operator.JoyYRaw_ANA2,
    RawButton                 := HwIn.Operator.JoyBtnRaw,
    Calibrate                 := GVL_IHM.JOY1Joystick.Cmd.Calibrate,
    Cfg                       := GVL_PERSISTENT._JoystickCfgPersist,
    NeutralXMem               := _JoystickNeutralX,
    NeutralYMem               := _JoystickNeutralY
);

// 📤 Publication du sous-bus joystick qualifié
Data.Joystick.AxisX              := instJoystick.AxisCmdX;
Data.Joystick.AxisY              := instJoystick.AxisCmdY;
Data.Joystick.DeadmanArmed       := instJoystick.DeadmanArmed;
Data.Joystick.AtNeutralXY        := instJoystick.AtNeutralXY;
Data.Joystick.ArmingPermitDenied := instJoystick.ArmingPermitDenied;
Data.Joystick.Ready              := instJoystick.Ready;
Data.Joystick.Fault              := instJoystick.Fault;
Data.Joystick.NeutralXAct        := instJoystick.NeutralXAct;
Data.Joystick.NeutralYAct        := instJoystick.NeutralYAct;
{endregion}

{region "§4 Codeurs et homing — M1/M2"}
// === 🧲 §4 CODEURS & HOMING (M1 / M2) ===

// ── TREUIL M1 (Retenue) ──
// Facade codeur complete : Abs→Homing→Scale→Safety→Reliability→Speed.
// L'autorisation de homing est calculee ici (mode + treuil selectionne).
// Frontiere hardware remplie avant l'appel (le bus Hw est passe en entier).
(* Centralise les fronts IHM avant les deux facades codeur. La polarite du DI
   est explicite : Free=TRUE signifie capteur haut non atteint. *)
MachineHomingM1Status.HomedAndReliable := Data.EncoderM1.HomedAndReliable;
MachineHomingM1Status.HomingBusy       := Data.EncoderM1.Measurement.HomingLifecycle.Busy;
MachineHomingM1Status.HomingDone       := Data.EncoderM1.Measurement.HomingLifecycle.Done;
MachineHomingM1Status.HomingError      := Data.EncoderM1.Measurement.HomingFault.Error;
MachineHomingM2Status.HomedAndReliable := Data.EncoderM2.HomedAndReliable;
MachineHomingM2Status.HomingBusy       := Data.EncoderM2.Measurement.HomingLifecycle.Busy;
MachineHomingM2Status.HomingDone       := Data.EncoderM2.Measurement.HomingLifecycle.Done;
MachineHomingM2Status.HomingError      := Data.EncoderM2.Measurement.HomingFault.Error;
MachineHomingMechanicalStopOk := HwIn.Winch.M1_ContactorsReleased_DI AND NOT HwIn.Winch.M1_BrakeIsOpen_DI
                                 AND (ABS(Data.EncoderM1.Measurement.Speed_Mps) < 0.02)
                                 AND HwIn.Winch.M2_ContactorsReleased_DI AND NOT HwIn.Winch.M2_BrakeIsOpen_DI
                                 AND (ABS(Data.EncoderM2.Measurement.Speed_Mps) < 0.02);
instMachineHomingCycle(
    Enable                     := TRUE,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    Mode                       := PRG_03_Modes_Cycle.Data.Auth.Mode,
    TopPositionActive          := NOT HwIn.Winch.M1M2_TopPositionFree_DI,
    WinchesMechanicallyStopped  := MachineHomingMechanicalStopOk,
    M1Status                   := MachineHomingM1Status,
    M2Status                   := MachineHomingM2Status,
    BucketOffsetValid          := PRG_04_Treuils_Benne.Data.BucketState.MechState.ActiveOffsetValid,
    ConfirmOpenPosition        := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
    ConfirmClosePosition       := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
    CfgTopHomingTargetM        := _WinchM1CfgPersist.CfgTopSensorPos_M,
    CfgOffsetOpenM             := _BucketCfgPersist.Config.OffsetOpenM,
    CfgOffsetCloseM            := _BucketCfgPersist.Config.OffsetCloseM
);
Data.MachineHoming.Homed            := instMachineHomingCycle.MachineHomed;
Data.MachineHoming.SetPosBucketOpen := instMachineHomingCycle.BucketCommit.CommitOpen;
Data.MachineHoming.SetPosBucketClose := instMachineHomingCycle.BucketCommit.CommitClose;
Data.MachineHoming.Active           := instMachineHomingCycle.MachineHomingActive;
Data.MachineHoming.HomingLoss       := instMachineHomingCycle.MachineHomingLossSafeStop;
Data.MachineHoming.Step             := TO_INT(instMachineHomingCycle.MachineHomingStep);
Data.MachineHoming.Instruction      := instMachineHomingCycle.MachineHomingInstruction;
Data.MachineHoming.Failed           := instMachineHomingCycle.MachineHomingFailed;
HwInM1.RawPosIn          := HwIn.Winch.COD1_PosValue;
HwInM1.AlarmsIn          := HwIn.Winch.COD1_Alarms;
HwInM1.WarningsIn        := HwIn.Winch.COD1_Warnings;
HwInM1.SlaveOperational  := instDiagEthercat.DeviceEncoderM1.Operational;
HwInM1.PresetStatusBit    := FALSE;
instEncoderM1(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
                               AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated <> 2)
                               AND (MachineHomingMechanicalStopOk OR (NOT GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero
                                                                       AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
                              OR instMachineHomingCycle.M1Demand.HomeReq),
    HomingAtTargetM       := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR instMachineHomingCycle.M1Demand.HomeReq,
    HomingAtZero          := GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    ConfirmCoherence      := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    CfgHomingTargetM      := _WinchM1CfgPersist.CfgHomingTarget_M,
    CfgTopSensorPosM      := _WinchM1CfgPersist.CfgTopSensorPos_M,
    UseDynamicTarget      := FALSE,
    DynamicHomingTargetM  := 0.0,
    TopPositionSensor     := HwIn.Winch.M1M2_TopPositionFree_DI,
    HwIn                  := HwInM1,
    PointsPerRev          := ENCODER_POINTS_PER_REV,
    CableM_PerRev         := WINCH_CABLE_M_PER_REV,
    Cfg                   := GVL_IHM.Commun.EncoderCfg,
    BypassGlobal          := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    Calib                 := _CalibM1
);

// 📤 Publication de la façade codeur M1 qualifiée
Data.EncoderM1.Measurement              := instEncoderM1.Measurement;
Data.EncoderM1.Ready                    := instEncoderM1.Ready;
Data.EncoderM1.Fault                    := instEncoderM1.Fault;
Data.EncoderM1.Homed                    := instEncoderM1.Homed;
Data.EncoderM1.HomingSuspect            := instEncoderM1.HomingSuspect;
Data.EncoderM1.EncoderFault             := instEncoderM1.EncoderFault;
Data.EncoderM1.HomedAndReliable         := instEncoderM1.HomedAndReliable;
Data.EncoderM1.PresetConfirmationFailed := instEncoderM1.PresetConfirmationFailed;
Data.EncoderM1.HwOut                    := instEncoderM1.HwOut;
COD1_PresettTrigCmd := instEncoderM1.HwOut.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderM1.HwOut.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderM1.HwOut.PresetValueOut;

// ── TREUIL M2 (Benne) ──
// Ordre POO : synchronisation benne, puis Homing, puis facade.

// Frontiere hardware remplie avant l'appel (le bus Hw est passe en entier).
HwInM2.RawPosIn          := HwIn.Winch.COD2_PosValue;
HwInM2.AlarmsIn          := HwIn.Winch.COD2_Alarms;
HwInM2.WarningsIn        := HwIn.Winch.COD2_Warnings;
HwInM2.SlaveOperational  := instDiagEthercat.DeviceEncoderM2.Operational;
HwInM2.PresetStatusBit    := FALSE;
instEncoderM2(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    HomingPermit          := (((PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
                               AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated <> 1)
                               AND (MachineHomingMechanicalStopOk OR (NOT GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero
                                                                       AND NOT HwIn.Winch.M1M2_TopPositionFree_DI)))
                              OR instMachineHomingCycle.M2Demand.HomeReq),
    HomingAtTargetM       := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR instMachineHomingCycle.M2Demand.HomeReq,
    HomingAtZero          := GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero,
    ConfirmCoherence      := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence,
    CfgHomingTargetM      := _WinchM2CfgPersist.CfgHomingTarget_M,
    CfgTopSensorPosM      := _WinchM2CfgPersist.CfgTopSensorPos_M,
    UseDynamicTarget      := instMachineHomingCycle.M2Demand.UseDynamicTarget,
    DynamicHomingTargetM  := instMachineHomingCycle.M2Demand.DynamicTarget_M,
    TopPositionSensor     := HwIn.Winch.M1M2_TopPositionFree_DI,
    HwIn                  := HwInM2,
    PointsPerRev          := ENCODER_POINTS_PER_REV,
    CableM_PerRev         := WINCH_CABLE_M_PER_REV,
    Cfg                   := GVL_IHM.Commun.EncoderCfg,
    BypassGlobal          := GVL_IHM.M2TreuilBenne.Bypass.Global,
    Calib                 := _CalibM2
);

// 📤 Publication de la façade codeur M2 qualifiée
Data.EncoderM2.Measurement              := instEncoderM2.Measurement;
Data.EncoderM2.Ready                    := instEncoderM2.Ready;
Data.EncoderM2.Fault                    := instEncoderM2.Fault;
Data.EncoderM2.Homed                    := instEncoderM2.Homed;
Data.EncoderM2.HomingSuspect            := instEncoderM2.HomingSuspect;
Data.EncoderM2.EncoderFault             := instEncoderM2.EncoderFault;
Data.EncoderM2.HomedAndReliable         := instEncoderM2.HomedAndReliable;
Data.EncoderM2.PresetConfirmationFailed := instEncoderM2.PresetConfirmationFailed;
Data.EncoderM2.HwOut                    := instEncoderM2.HwOut;
COD2_PresettTrigCmd := instEncoderM2.HwOut.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderM2.HwOut.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderM2.HwOut.PresetValueOut;
{endregion}

{region "§5 Retours variateur M3"}
// === ↔️ §5 RETOURS VARIATEUR M3 (décodage position migré vers PRG_05, AF-02 TBD §8 #5) ===

// 📊 Retours variateur M3 conditionnés (HwIn arbitré en §2)
Data.M3.StatusWord        := WORD_TO_UINT(HwIn.Translation.M3_StatusWord);
Data.M3.ActualFrequencyHz := HwIn.Translation.M3_ActualFrequencyHz;
{endregion}

{region "§6 Qualification globale du bus Data"}
// === 🛡️ §6 QUALIFICATION GLOBALE DU BUS DATA ===
// DataValid = TRUE uniquement si les modules E/S physiques et les bus réseaux sont opérationnels.
Data.DataValid := NOT Data.InputModules.Fault 
                  AND instDiagCanOpen.Ready 
                  AND instDiagEthercat.Ready;
{endregion}

END_PROGRAM

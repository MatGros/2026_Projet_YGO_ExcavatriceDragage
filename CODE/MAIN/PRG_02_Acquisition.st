(* ═══════════════════════════════════════════════════════════════
   📡 PRG_02_Acquisition — Programme d'Acquisition et Qualification I/O
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §2
   ⚙️ Exécuté en tête de la chaîne métier (après les initialisations système).
   🎯 Rôle unique : Produire les images HwReal/HwRealQualified/HwSim/HwIn,
      acquérir et traiter les mesures codeurs (M1/M2), décoder M3, traiter le joystick
      et publier les retours.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_02_Acquisition

VAR_OUTPUT
    HwReal                   : ST_HardwareImage;  (* Image brute réelle ; TRUE = état physique lu *)
    HwRealQualified          : ST_HardwareImage;  (* Image réelle TOR filtrée ; TRUE = état stable *)
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
    (* ── Filtrage temporel des 22 TOR réelles ── *)
        instFilterPowerContactor      : FB_DigitalInputFilter;
    instFilterEmergencyChain      : FB_DigitalInputFilter;
    instFilterPhaseRotation       : FB_DigitalInputFilter;
    instFilterBrakeThermal        : FB_DigitalInputFilter;
    instFilterM1Brake              : FB_DigitalInputFilter;
    instFilterM2Brake              : FB_DigitalInputFilter;
    instFilterM3Brake              : FB_DigitalInputFilter;
    instFilterM1Contactors         : FB_DigitalInputFilter;
    instFilterM1Thermal            : FB_DigitalInputFilter;
    instFilterM2Contactors         : FB_DigitalInputFilter;
    instFilterM2Thermal            : FB_DigitalInputFilter;
    instFilterTensionedCable       : FB_DigitalInputFilter;
    instFilterKobold               : FB_DigitalInputFilter;
    instFilterM3Thermal            : FB_DigitalInputFilter;
    instFilterTopPosition          : FB_DigitalInputFilter;
    instFilterPosTremie            : FB_DigitalInputFilter;
    instFilterPosPV                : FB_DigitalInputFilter;
    instFilterPosP2                : FB_DigitalInputFilter;
    instFilterPosP1                : FB_DigitalInputFilter;
    instFilterPosMaintenance       : FB_DigitalInputFilter;
    instFilterHydraulicThermal     : FB_DigitalInputFilter;
    instFilterConveyorReady        : FB_DigitalInputFilter;

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

    (* ── Filtrage retours variateur M3 ── *)
    instCycleTimeAcq            : FB_CycleTime;
    instFilterM3StatusWord      : FB_Filter_PT1;
    instFilterM3ActualFreqHz    : FB_Filter_PT1;

    (* ── Mémoire bascule simulation Winch ── *)
    WinchInputSourceSimulated         : BOOL;
    PreviousWinchInputSourceSimulated : BOOL;
    WinchInputSourceInitialized       : BOOL;

    (* ── Bascule simulation autres domaines (§2, sans mémoire de front) ── *)
    TranslationSourceSimulated : BOOL;
    OperatorSourceSimulated    : BOOL;
    MachineSourceSimulated     : BOOL;
END_VAR

// === 📥 §1 ACQUISITION BRUTE (HwReal) ===

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
HwReal.Translation.M3_PosP2_DI          := M3_PosP2_DI;
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
// === 🧰 §1bis FILTRAGE TOR RÉEL ===
// HwReal reste brut pour le diagnostic. HwRealQualified porte la même image
// après filtrage temporel ; aucune inversion ni information de santé carte ici.
HwRealQualified := HwReal;

instFilterPowerContactor(InputRaw := HwReal.Machine.PowerContactorEngaged_DI, FilterTime := T#20MS);
HwRealQualified.Machine.PowerContactorEngaged_DI := instFilterPowerContactor.State;
instFilterEmergencyChain(InputRaw := HwReal.Machine.EmergencyChainClosed_DI, FilterTime := T#20MS);
HwRealQualified.Machine.EmergencyChainClosed_DI := instFilterEmergencyChain.State;
instFilterPhaseRotation(InputRaw := HwReal.Machine.PhaseRotationOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.PhaseRotationOk_DI := instFilterPhaseRotation.State;
instFilterBrakeThermal(InputRaw := HwReal.Machine.M1_M2_M3_BrakeThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.M1_M2_M3_BrakeThermalOk_DI := instFilterBrakeThermal.State;
instFilterKobold(InputRaw := HwReal.Machine.M1_M2_KoboldBottomTouch_DI, FilterTime := T#20MS);
HwRealQualified.Machine.M1_M2_KoboldBottomTouch_DI := instFilterKobold.State;
instFilterHydraulicThermal(InputRaw := HwReal.Machine.HydraulicThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Machine.HydraulicThermalOk_DI := instFilterHydraulicThermal.State;
instFilterConveyorReady(InputRaw := HwReal.Machine.ConveyorInfeedReady_DI, FilterTime := T#20MS);
HwRealQualified.Machine.ConveyorInfeedReady_DI := instFilterConveyorReady.State;
// 🆕 2026-08-12 : HopperFull_OR_GateRaised_DI déclaré, pas encore filtré/consommé (pas de câblage
// électrique confirmé) — pas de FB_DigitalInputFilter tant qu'aucun consommateur n'existe.
HwRealQualified.Machine.HopperFull_OR_GateRaised_DI := HwReal.Machine.HopperFull_OR_GateRaised_DI;

instFilterM1Contactors(InputRaw := HwReal.Winch.M1_ContactorsReleased_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_ContactorsReleased_DI := instFilterM1Contactors.State;
instFilterM1Thermal(InputRaw := HwReal.Winch.M1_ThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_ThermalOk_DI := instFilterM1Thermal.State;
instFilterM1Brake(InputRaw := HwReal.Winch.M1_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1_BrakeIsOpen_DI := instFilterM1Brake.State;
instFilterM2Contactors(InputRaw := HwReal.Winch.M2_ContactorsReleased_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_ContactorsReleased_DI := instFilterM2Contactors.State;
instFilterM2Thermal(InputRaw := HwReal.Winch.M2_ThermalOk_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_ThermalOk_DI := instFilterM2Thermal.State;
instFilterM2Brake(InputRaw := HwReal.Winch.M2_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_BrakeIsOpen_DI := instFilterM2Brake.State;
instFilterTensionedCable(InputRaw := HwReal.Winch.M2_TensionedCable_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M2_TensionedCable_DI := instFilterTensionedCable.State;
instFilterTopPosition(InputRaw := HwReal.Winch.M1M2_TopPositionFree_DI, FilterTime := T#20MS);
HwRealQualified.Winch.M1M2_TopPositionFree_DI := instFilterTopPosition.State;

instFilterM3Brake(InputRaw := HwReal.Translation.M3_BrakeIsOpen_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_BrakeIsOpen_DI := instFilterM3Brake.State;
instFilterM3Thermal(InputRaw := HwReal.Translation.M3_ThermalOK_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_ThermalOK_DI := instFilterM3Thermal.State;
instFilterPosTremie(InputRaw := HwReal.Translation.M3_PosTremie_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosTremie_DI := instFilterPosTremie.State;
instFilterPosPV(InputRaw := HwReal.Translation.M3_PosPV_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosPV_DI := instFilterPosPV.State;
instFilterPosP2(InputRaw := HwReal.Translation.M3_PosP2_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosP2_DI := instFilterPosP2.State;
instFilterPosP1(InputRaw := HwReal.Translation.M3_PosP1_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosP1_DI := instFilterPosP1.State;
instFilterPosMaintenance(InputRaw := HwReal.Translation.M3_PosMaintenance_DI, FilterTime := T#20MS);
HwRealQualified.Translation.M3_PosMaintenance_DI := instFilterPosMaintenance.State;

// 🩺 Diagnostic carte des 3 modules DI portant les 22 TOR réelles (AF06 §3bis).
// GetDeviceState() = RUNNING => module opérationnel. Si la simulation globale/machine est active,
// les cartes physiques absentes sont simulées OK pour permettre le fonctionnement banc.
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimMachineActive THEN
    LocalDigitalIoOk := TRUE;
    Vh0800EndOk      := TRUE;
    Vh0808EtpOk      := TRUE;
ELSE
    LocalDigitalIoOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING);
    Vh0800EndOk      := (VH_0800END.GetDeviceState() = DEVICE_STATE.RUNNING);
    Vh0808EtpOk      := (VH_0808ETP.GetDeviceState() = DEVICE_STATE.RUNNING);
END_IF;
InputModuleFault := NOT (LocalDigitalIoOk AND Vh0800EndOk AND Vh0808EtpOk);
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
    M3_TargetNum             := GVL_IHM.TranslationM3.Cmd.SelTarget,
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
    SimM3SensorsWordActive   := GVL_Simulation.SimM3SensorsWordActive,
    SimM3SensorsWord         := GVL_Simulation.SimM3SensorsWord,
    SimJoystickRawX          := GVL_Simulation.SimJoystickRawX,
    SimJoystickRawY          := GVL_Simulation.SimJoystickRawY,
    SimJoystickRawButton     := GVL_Simulation.SimJoystickRawButton,
    SimKoboldContactValue    := GVL_Simulation.SimKoboldContactValue,
    BtnEmergencyStop         := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff,
    HwReal                   := HwReal,
    RawPosM1                 := _SimEncoderRawPosM1,
    RawPosM2                 := _SimEncoderRawPosM2
);

HwSim.Winch       := instSimBench.Winch;
HwSim.Translation := instSimBench.Translation;
HwSim.Operator    := instSimBench.Operator;
HwSim.Machine     := instSimBench.Machine;

WinchInputSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
IF NOT WinchInputSourceInitialized THEN
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
    WinchInputSourceInitialized := TRUE;
    WinchInputSourceChanged := FALSE;
ELSE
    WinchInputSourceChanged := (WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated);
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

TranslationSourceSimulated := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
OperatorSourceSimulated    := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive;
MachineSourceSimulated     := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimMachineActive;

// 🔧 SEL(G, IN0, IN1) : brique standard IEC 61131-3, retourne IN1 si G=TRUE, IN0 sinon
// (AF_Partie-03 §1 : composer l'existant avant réimplémentation) — remplace les 4 IF/ELSE
// compactés qui cassaient le générateur ST→LD (REX 2026-08-13, CODE_QUALITY_STANDARDS.md §11).
// ⚠️ Premier usage SEL() sur STRUCT dans ce projet (précédents = REAL/INT/BOOL uniquement) :
// à confirmer par compilation CODESYS réelle avant de considérer ce lot terminé.
HwIn.Winch       := SEL(WinchInputSourceSimulated, HwRealQualified.Winch, instSimBench.Winch);
HwIn.Translation := SEL(TranslationSourceSimulated, HwRealQualified.Translation, instSimBench.Translation);
HwIn.Operator     := SEL(OperatorSourceSimulated, HwReal.Operator, instSimBench.Operator);
HwIn.Machine      := SEL(MachineSourceSimulated, HwRealQualified.Machine, instSimBench.Machine);


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
    DeadmanRearmTimeout       := T#10S,
    NeutralHoldTime           := T#100MS, // 🔧 2026-08-07 (demande client) : réduit de 500ms — désarme plus vite au retour neutre
    DeadmanArmHoldTime        := T#100MS, // 🆕 2026-08-07 (demande client) : appui maintenu 100ms arme, indépendamment de la position des axes
    DeadmanArmGraceTime       := T#3S,    // 🆕 2026-08-07 (retour terrain) : grâce avant que le désarmement neutre puisse s'appliquer après un armement
    DeadmanReconfEnable       := FALSE,
    NeutralXMem               := _JoystickNeutralX,
    NeutralYMem               := _JoystickNeutralY
);

// 🔫 AF08 §6 : DeadmanArmed jusqu'ici jamais publié hors instJoystick (instance privée) —
// exigé par Translation/Winch/Cycle en aval (T106, audit M3 2026-08-05).
JoystickDeadmanArmed := instJoystick.DeadmanArmed;
JoystickYNeutral := (instJoystick.DirectionY = 0);   // 🆕 2026-08-05 : prérequis FB_Safety_Winch Méca B
JoystickDirectionX := instJoystick.DirectionX;
JoystickSpeedPctX := ABS(instJoystick.SpeedXPct);
JoystickXNeutral := (instJoystick.DirectionX = 0);
// === 🧲 §4 CODEURS & HOMING (M1 / M2) ===

instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn            := HwIn.Winch.COD1_PosValue,
    AlarmsIn            := HwIn.Winch.COD1_Alarms,
    WarningsIn          := HwIn.Winch.COD1_Warnings,
    SlaveOperational    := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM1.Operational,
    PresetRequest       := instHomingM1.PresetRequest,
    PresetValue         := instHomingM1.PresetValue
);

instHomingM1(
    Enable               := TRUE,
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                 := PRG_03_Modes_Cycle.Auth.Mode,
    Home                 := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    UnitaryMode          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                            AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 0),
    WinchSelected        := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 1),
    CfgHomingTargetM        := _WinchM1CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    TopPositionSensor    := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM   := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback        := HwIn.Winch.M1_BrakeIsOpen_DI,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    Calib                := _CalibM1
);

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

// 🆕 2026-08-05 : bornage physique ±99m + gel sur doute (audit sécurité M3) — CablePosM1
// (producteur unique position, consommé machine entière) n'était protégé par AUCUN étage
// avant ce lot, contrairement à ce qu'affirmait AF_Partie-09 §4.1 (écart doc/code trouvé
// par l'audit). Sémantique inchangée en fonctionnement normal (position dans la plage) ;
// seul un doute (hors plage ou homing suspect) fige désormais la valeur au lieu de la
// laisser divaguer.
instEncoderSafetyM1(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM             := instEncoderScaleM1.CablePosM,
    HomingSuspect         := instHomingM1.HomingSuspect,
    BypassGlobal          := GVL_IHM.M1TreuilRetenue.Bypass.Global
);
CablePosM1 := instEncoderSafetyM1.CablePosMSafe;
M1_EncoderIncoherent := instEncoderSafetyM1.EncoderIncoherent;

// 🆕 2026-08-05 : vitesse câble mesurée — prérequis FB_Safety_Winch Méca A/F/G (audit sécurité M3).
// PositionValid combine disponibilité codeur ET cohérence position (gel sur doute ci-dessus) :
// une position figée par FB_Encoder_Safety ne doit jamais alimenter un calcul de vitesse réel.
instEncoderSpeedMeasureM1(
    Enable        := TRUE,
    Reset         := PRG_07_Supervision.FaultMachineReset_IHM,
    Position_M    := instEncoderSafetyM1.CablePosMSafe,
    PositionValid := instEncoderAbsM1.EncoderAvailable AND NOT instEncoderSafetyM1.EncoderIncoherent
);
M1_Speed_Mps       := instEncoderSpeedMeasureM1.Speed_Mps;
M1_SignedSpeed_Mps := instEncoderSpeedMeasureM1.SignedSpeed_Mps;
M1_SpeedValid      := instEncoderSpeedMeasureM1.Valid;

instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    RawPosIn            := HwIn.Winch.COD2_PosValue,
    AlarmsIn            := HwIn.Winch.COD2_Alarms,
    WarningsIn          := HwIn.Winch.COD2_Warnings,
    SlaveOperational    := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM2.Operational,
    PresetRequest       := instHomingM2.PresetRequest,
    PresetValue         := instHomingM2.PresetValue
);

// 🆕 2026-08-07 (19) — retour terrain, demande client : BtnConfirmOpenPos/ClosePos (benne)
// doivent AUSSI référencer le codeur M2, comme BtnHome -- pas seulement mémoriser IsOpen/IsClosed
// (FB_Bucket.st, inchangé, continue de le faire en parallèle). Cible dynamique : ouverture =
// position réelle actuelle de M1 (offset 0) ; fermeture = M1 + OffsetCloseM (config benne, 15m
// actuellement). Mêmes gardes que le Confirm logique (Mode MAINT_N1/N2, M1/M2 à l'arrêt) --
// lecture 1 scan en retard sur PRG_03/PRG_04 (pattern déjà accepté ailleurs, action manuelle
// ponctuelle, pas un mouvement).
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
    Enable               := TRUE,
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                 := PRG_03_Modes_Cycle.Auth.Mode,
    Home                 := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero OR M2BucketRefRequested,
    UseDynamicTarget     := M2BucketRefRequested,
    DynamicHomingTargetM := M2BucketRefTargetM,
    UnitaryMode          := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
                            AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated <> 0),
    WinchSelected        := (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2),
    CfgHomingTargetM        := _WinchM2CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence,
    TopPositionSensor    := HwIn.Winch.M1M2_TopPositionFree_DI,
    CfgTopSensorPosM   := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _WinchM2CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback        := HwIn.Winch.M2_BrakeIsOpen_DI,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M2TreuilBenne.Bypass.Global,
    Calib                := _CalibM2
);

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

// 🆕 2026-08-05 : bornage physique ±99m + gel sur doute (audit sécurité M3) — voir M1 ci-dessus.
instEncoderSafetyM2(
    Enable                := TRUE,
    Reset                 := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI,
    Mode                  := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM             := instEncoderScaleM2.CablePosM,
    HomingSuspect         := instHomingM2.HomingSuspect,
    BypassGlobal          := GVL_IHM.M2TreuilBenne.Bypass.Global
);
CablePosM2 := instEncoderSafetyM2.CablePosMSafe;
M2_EncoderIncoherent := instEncoderSafetyM2.EncoderIncoherent;

// 🆕 2026-08-05 : vitesse câble mesurée — prérequis FB_Safety_Winch Méca A/F/G (audit sécurité M3).
instEncoderSpeedMeasureM2(
    Enable        := TRUE,
    Reset         := PRG_07_Supervision.FaultMachineReset_IHM,
    Position_M    := instEncoderSafetyM2.CablePosMSafe,
    PositionValid := instEncoderAbsM2.EncoderAvailable AND NOT instEncoderSafetyM2.EncoderIncoherent
);
M2_Speed_Mps       := instEncoderSpeedMeasureM2.Speed_Mps;
M2_SignedSpeed_Mps := instEncoderSpeedMeasureM2.SignedSpeed_Mps;
M2_SpeedValid      := instEncoderSpeedMeasureM2.Valid;
// === ↔️ §5 DÉCODAGE POSITION TRANSLATION (M3) ===

instPosDecoderM3(
    SensorTremie      := HwIn.Translation.M3_PosTremie_DI,
    SensorPV          := HwIn.Translation.M3_PosPV_DI,
    SensorP2          := HwIn.Translation.M3_PosP2_DI,
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
M3_SensorsWord          := instPosDecoderM3.SensorsWord;
// === 📊 §6 FILTRAGE PT1 RETOURS VARIATEUR (M3) ===

instCycleTimeAcq(DefaultValueS := 0.010);

instFilterM3StatusWord(
    ValueIn    := UINT_TO_REAL(WORD_TO_UINT(HwIn.Translation.M3_StatusWord)),
    TimeConst  := T#0MS,
    CycleTimeS := instCycleTimeAcq.CycleTimeS
);
M3_StatusWord_Filtered := REAL_TO_UINT(instFilterM3StatusWord.ValueOut);

instFilterM3ActualFreqHz(
    ValueIn    := UINT_TO_REAL(HwIn.Translation.M3_ActualFrequencyHz),
    TimeConst  := T#0MS,
    CycleTimeS := instCycleTimeAcq.CycleTimeS
);
M3_ActualFrequencyHz_Filtered := REAL_TO_UINT(instFilterM3ActualFreqHz.ValueOut);

END_PROGRAM

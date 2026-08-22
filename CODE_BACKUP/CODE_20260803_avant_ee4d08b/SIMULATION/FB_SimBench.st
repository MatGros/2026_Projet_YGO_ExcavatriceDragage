(* ═══════════════════════════════════════════════════════════════
   🧪 FB_SimBench — Enveloppe unique de simulation pour banc d'essai
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v2.0.md
   📄 Lot L6 (Rebranchement du banc de simulation derrière HwIn)
   
   🎯 Rôle : Compose les 4 blocs de modèle de simulation existants :
      - FB_Sim_Encoder (instM1, instM2)
      - FB_Sim_Translation (instTranslation)
      - FB_Sim_Joystick (instJoystick)
      - FB_Sim_Safety (instSafety)
   
   🔒 Brique réduite : 0 lecture de variable globale en interne.
      Toutes les entrées (commandes, stimuli, HwReal) sont passées en paramètres.
   
   🔴 RÈGLES SÉCURITÉ ET POLARITÉ :
      - Modèle frein M1/M2/M3 : M1_BrakeIsOpen_DI := M1_BrakeCmd (1 = OUVERT).
        Ne JAMAIS faire NOT BrakeCmd ! (P1 Lot L6).
      - Retours contacteurs M1/M2 : 1 = tous retombés (TRUE quand RelayFwd=0 et RelayRev=0).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_SimBench
VAR_INPUT
    Enable                     : BOOL;             // Activation globale (GVL_Simulation.SimulationModeActive)

    // ── Commandes issues de l'automate (Scan N-1 / PRG_07 / PRG_10) ──────────
    M1_RelayFwd                : BOOL;
    M1_RelayRev                : BOOL;
    // 🔧 REX 2026-07-27 : les 4 contacteurs de palier participent au retour unique
    // « tous contacteurs retombés » — sans eux, le modèle annonce l'arrêt alors qu'un
    // palier est encore engagé (fausse condition d'armement Méca A).
    M1_SpeedContactor_1        : BOOL;
    M1_SpeedContactor_2        : BOOL;
    M1_SpeedContactor_3        : BOOL;
    M1_SpeedContactor_4        : BOOL;
    M1_SpeedRefPct             : REAL;
    M1_PresetTriggerCmd        : WORD;
    M1_PresetValueOut          : UDINT;
    M1_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M1

    M2_RelayFwd                : BOOL;
    M2_RelayRev                : BOOL;
    M2_SpeedContactor_1        : BOOL;   // 🔧 REX 2026-07-27 : idem M1, voir ci-dessus
    M2_SpeedContactor_2        : BOOL;
    M2_SpeedContactor_3        : BOOL;
    M2_SpeedContactor_4        : BOOL;
    M2_SpeedRefPct             : REAL;
    M2_PresetTriggerCmd        : WORD;
    M2_PresetValueOut          : UDINT;
    M2_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M2

    M3_Direction               : INT;              // 1 = Avant, -1 = Arrière, 0 = Arrêt
    M3_SpeedRefPct             : REAL;
    M3_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M3
    M3_TargetNum               : INT;              // Cible sélectionnée (0..4)

    PowerKeepAlive_A           : BOOL;             // TRUE = relais A maintenu sagement par le PLC
    PowerKeepAlive_B           : BOOL;             // TRUE = relais B maintenu sagement par le PLC
    EmergencyArming_RQ         : BOOL;             // Impulsion de réarmement puissance

    // ── Stimuli & Paramètres de banc ─────────────────────────────────────────
    SimEncoderSpeedFactor      : REAL := 1.0;
    SimSyncDeviationInjectM1   : BOOL := FALSE;
    SimSyncDeviationInjectM2   : BOOL := FALSE;
    SimSyncDeviationOffset_M   : REAL := 0.5;

    SimM3SensorsWordActive     : BOOL := FALSE;
    SimM3SensorsWord           : BYTE := 16#01;

    SimJoystickRawX            : INT := 5000;
    SimJoystickRawY            : INT := 5000;
    SimJoystickRawButton       : BOOL := FALSE;

    SimKoboldContactValue      : BOOL := FALSE;
    BtnEmergencyStop           : BOOL := FALSE;    // Simulation appui coup-de-poing AU

    // ── Image réelle fallback ────────────────────────────────────────────────
    HwReal                     : ST_HardwareImage;
END_VAR

VAR_OUTPUT
    Winch                      : ST_HwWinch;
    Translation                : ST_HwTranslation;
    Operator                   : ST_HwOperator;
    Machine                    : ST_HwMachine;
END_VAR

VAR_IN_OUT
    RawPosM1                   : UDINT;            // Mémoire _SimEncoderRawPosM1 dans GVL_PERSISTENT
    RawPosM2                   : UDINT;            // Mémoire _SimEncoderRawPosM2 dans GVL_PERSISTENT
END_VAR

VAR
    // Modèles sous-jacents
    instSimEncoderM1           : FB_Sim_Encoder;
    instSimEncoderM2           : FB_Sim_Encoder;
    instSimTranslation         : FB_Sim_Translation;
    instSimJoystick            : FB_Sim_Joystick;
    instSimSafety              : FB_Sim_Safety;

    // Calculs internes
    M1_PresetCmd               : BOOL;
    M2_PresetCmd               : BOOL;
    M1_OffsetPts               : DINT;
    M2_OffsetPts               : DINT;

    M3_RelayFwd                : BOOL;
    M3_RelayRev                : BOOL;

    M3_ActualFreqHz            : UINT;
    M3_StatusWordSim           : WORD;
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    Winch       := HwReal.Winch;
    Translation := HwReal.Translation;
    Operator    := HwReal.Operator;
    Machine     := HwReal.Machine;
    RETURN;
END_IF;


// ── 1. MODÈLE TREUILS (M1 + M2) ─────────────────────────────────────────────
// Presets codeurs : déclenchés si PresetTriggerCmd = 2
M1_PresetCmd := (M1_PresetTriggerCmd = 2);
M2_PresetCmd := (M2_PresetTriggerCmd = 2);

// Conversions d'injection d'écart synchro (0.5m -> points codeur avec 8192 pts/tour, 2m/tour)
// 1m = 4096 points codeur.
M1_OffsetPts := REAL_TO_DINT(SimSyncDeviationOffset_M * 4096.0);
M2_OffsetPts := REAL_TO_DINT(SimSyncDeviationOffset_M * 4096.0);

// Instance modèle codeur M1
instSimEncoderM1(
    Enable           := TRUE,
    RelayFwd         := M1_RelayFwd,
    RelayRev         := M1_RelayRev,
    SpeedRefPct      := M1_SpeedRefPct,
    PresetCmd        := M1_PresetCmd,
    PresetValue      := M1_PresetValueOut,
    SpeedScaleFactor := SimEncoderSpeedFactor,
    TestOffsetCmd    := SimSyncDeviationInjectM1,
    TestOffsetPts    := M1_OffsetPts,
    RawPos           := RawPosM1
);

// Instance modèle codeur M2
instSimEncoderM2(
    Enable           := TRUE,
    RelayFwd         := M2_RelayFwd,
    RelayRev         := M2_RelayRev,
    SpeedRefPct      := M2_SpeedRefPct,
    PresetCmd        := M2_PresetCmd,
    PresetValue      := M2_PresetValueOut,
    SpeedScaleFactor := SimEncoderSpeedFactor,
    TestOffsetCmd    := SimSyncDeviationInjectM2,
    TestOffsetPts    := M2_OffsetPts,
    RawPos           := RawPosM2
);

// Recopie structures Winch simulées :
// 🛑 POLARITÉ DE FREIN SIMULÉ (P1 Lot L6) : 1 = contacteur commandé = frein OUVERT.
// Câblage réel : DI = 1 ⟺ frein OUVERT. Le modèle produit donc M1_BrakeIsOpen_DI := M1_BrakeCmd !
Winch.M1_BrakeIsOpen_DI        := M1_BrakeCmd;
// 🔧 REX 2026-07-27 : retour UNIQUE « tous contacteurs retombés » = sens ET vitesse.
// Omettre les paliers ferait croire à l'arrêt pendant les transitoires → Méca A armée à tort.
Winch.M1_ContactorsReleased_DI := NOT (M1_RelayFwd OR M1_RelayRev
                                    OR M1_SpeedContactor_1 OR M1_SpeedContactor_2
                                    OR M1_SpeedContactor_3 OR M1_SpeedContactor_4);
Winch.M1_ThermalOk_DI          := TRUE; // Sauf panne simulée

Winch.M2_BrakeIsOpen_DI        := M2_BrakeCmd;
Winch.M2_ContactorsReleased_DI := NOT (M2_RelayFwd OR M2_RelayRev
                                    OR M2_SpeedContactor_1 OR M2_SpeedContactor_2
                                    OR M2_SpeedContactor_3 OR M2_SpeedContactor_4);
Winch.M2_ThermalOk_DI          := TRUE;

Winch.M1M2_TopPositionFree_DI  := TRUE; // Butée libre au repos en simu
Winch.M2_TensionedCable_DI     := TRUE; // Câble tendu en simu

Winch.COD1_PosValue            := instSimEncoderM1.RawPosOut;
Winch.COD1_Alarms              := 0;
Winch.COD1_Warnings            := 0;
Winch.COD1_DeviceState         := 4; // DEVICE_STATE RUNNING = 4 (bus OK)

Winch.COD2_PosValue            := instSimEncoderM2.RawPosOut;
Winch.COD2_Alarms              := 0;
Winch.COD2_Warnings            := 0;
Winch.COD2_DeviceState         := 4; // DEVICE_STATE RUNNING = 4


// ── 2. MODÈLE TRANSLATION M3 (AC600) ─────────────────────────────────────────
M3_RelayFwd := (M3_Direction = 1);
M3_RelayRev := (M3_Direction = -1);

instSimTranslation(
    Enable      := TRUE,
    TargetNum   := M3_TargetNum,
    RelayFwd    := M3_RelayFwd,
    RelayRev    := M3_RelayRev,
    TravelTimeS := 8.0,
    PVLeadTimeS := 2.0
);

// Remplissage capteurs de position M3 :
IF SimM3SensorsWordActive THEN
    Translation.M3_PosTremie_DI      := SimM3SensorsWord.0;
    Translation.M3_PosPV_DI          := SimM3SensorsWord.1;
    Translation.M3_PosP2_DI          := SimM3SensorsWord.2;
    Translation.M3_PosP1_DI          := SimM3SensorsWord.3;
    Translation.M3_PosMaintenance_DI := SimM3SensorsWord.4;
ELSE
    Translation.M3_PosTremie_DI      := instSimTranslation.PosTremie;
    Translation.M3_PosPV_DI          := instSimTranslation.PosPV;
    Translation.M3_PosP2_DI          := instSimTranslation.PosP2;
    Translation.M3_PosP1_DI          := instSimTranslation.PosP1;
    Translation.M3_PosMaintenance_DI := instSimTranslation.PosMaintenance;
END_IF;

// Polarité frein M3 (1 = OUVERT)
Translation.M3_BrakeIsOpen_DI    := M3_BrakeCmd;

// 🆕 T96 : thermique moteur/variateur AC600 — pas de panne simulée, toujours OK (comme Winch.M1/M2_ThermalOk_DI)
Translation.M3_ThermalFeedback_DI := TRUE;

// Simulation StatusWord AC600 : Bit 0 (Power Ready) = 1, Bit 7 (Comm Ready) = 1 -> 16#0081
IF (M3_Direction <> 0) THEN
    M3_StatusWordSim := 16#0087; // + Operating/Running
    M3_ActualFreqHz  := REAL_TO_UINT(M3_SpeedRefPct * 50.0); // 50.0 Hz à 100% (x100 -> 5000)
ELSE
    M3_StatusWordSim := 16#0081;
    M3_ActualFreqHz  := 0;
END_IF;

Translation.M3_StatusWord        := M3_StatusWordSim;
Translation.M3_ActualFrequencyHz := M3_ActualFreqHz;
Translation.AC600_DeviceState    := 4; // DEVICE_STATE RUNNING = 4


// ── 3. MODÈLE OPÉRATEUR / JOYSTICK ───────────────────────────────────────────
instSimJoystick(
    Enable     := TRUE,
    NeutralRaw := 5000,
    MaxRaw     := 10000
);

// Permet aux stimuli de banc de surcharger le retour du joystick si spécifié :
IF SimJoystickRawX <> 5000 THEN
    Operator.JoyXRaw_ANA1 := SimJoystickRawX;
ELSE
    Operator.JoyXRaw_ANA1 := instSimJoystick.RawX;
END_IF;

IF SimJoystickRawY <> 5000 THEN
    Operator.JoyYRaw_ANA2 := SimJoystickRawY;
ELSE
    Operator.JoyYRaw_ANA2 := instSimJoystick.RawY;
END_IF;

IF SimJoystickRawButton THEN
    Operator.JoyBtnRaw := TRUE;
ELSE
    Operator.JoyBtnRaw := instSimJoystick.RawButton;
END_IF;

Operator.CanBusState      := 2; // CANbusState 2 = ACTIVE (confirmé terrain)
Operator.JOY1_DeviceState := 4; // DEVICE_STATE RUNNING = 4


// ── 4. MODÈLE SÉCURITÉ & COMMUNS MACHINE ─────────────────────────────────────
instSimSafety(
    Enable           := TRUE,
    PowerCutOff_A    := PowerKeepAlive_A,
    PowerCutOff_B    := PowerKeepAlive_B,
    EmergencyArming  := EmergencyArming_RQ,
    BtnEmergencyStop := BtnEmergencyStop
);

Machine.PowerContactorEngaged_DI   := instSimSafety.SimContactorOk;
Machine.EmergencyChainClosed_DI    := instSimSafety.SimChainOk;
Machine.PhaseRotationOk_DI         := TRUE;
Machine.BrakeThermalOk_DI          := TRUE;
Machine.M1_M2_KoboldContactFond_DI := SimKoboldContactValue;
Machine.HydraulicThermalOk_DI      := TRUE;

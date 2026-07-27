(* ══════════════════════════════════════════════════════════════════════════
   📥 PRG_00_Inputs — ACQUISITION & CONDITIONNEMENT       ⚙️ scan position 0
   ══════════════════════════════════════════════════════════════════════════
   §0  MATÉRIEL ──► HwReal (Acquisition brute unique)
   §0bis HwReal / SimBench ──► HwIn (Aiguillage simulation par domaine)
   §1  HwIn     ──► FB_Input ──► VAR_OUTPUT (Filtre 20 ms, polarité NO/NC)
   §2  Décodage mot capteurs M3
   ══════════════════════════════════════════════════════════════════════════
   MAP CARTE DES BLOCAGES — ce qui empêche la machine de bouger si FALSE
   [BLOQUE] mouvement interdit · [ESCAL.] escalade safety · [DIAG] information seule
   ┌──────────────────────────┬──────────┬─────────────────────────────────┐
   │ EmergencyStopOk          │ [BLOQUE] │ portail maître — tout le prog.  │
   │ TopPositionSensor        │ [BLOQUE] │ ForbidAscent M1+M2 (hors bypass)│
   │ SlackCableSwitch         │ [BLOQUE] │ ForbidDescent M2                │
   │ BrakeThermalFeedback     │ [ESCAL.] │ SafeStop + PowerCutOff (3 axes) │
   │ PhaseRotationOk          │ [ESCAL.] │ SafeStop (3 axes)               │
   │ M1/M2ThermalFeedback     │ [ESCAL.] │ SafeStop axe                    │
   │ M1/M2/M3BrakeFeedback    │ [ESCAL.] │ Méca A/B/D si arrêt non confirmé│
   │ KoboldContactFond        │ [BLOQUE] │ cycle figé BOTTOM_TOUCH_WAIT    │
   │ HydraulicThermalOk       │ [DIAG]   │ aucun effet sur le mouvement    │
   └──────────────────────────┴──────────┴─────────────────────────────────┘
   📄 Doc : DOC/AF_Partie-06_IO_Conditioning_v1.6.md §5
   ⚙️ Exécuté par la tâche PLC (Task Manager) en position 0.
   ✅ Expose ses sorties en VAR_OUTPUT (lecture seule pour le reste du code).
   ══════════════════════════════════════════════════════════════════════════ *)

PROGRAM PRG_00_Inputs
VAR_OUTPUT
    // ── 🏗️ FRONTIÈRE UNIQUE HW (Image matérielle brute) ────────────────────
    HwReal               : ST_HardwareImage; // Image matérielle brute (acquis §0)
    HwIn                 : ST_HardwareImage; // Image d'entrée consommée par tout le programme (§0bis)

    // ── 🛑 SÉCURITÉS COMMUNES (NC — repos=TRUE sain, FALSE=défaut/fil coupé) ──────────────
    // 🔧 REX 2026-07-07 : précision terrain — PowerContactorEngaged_DI (retour contact auxiliaire NO)
    // est en fait la confirmation que le CONTACTEUR DE PUISSANCE est réellement engagé (1=actif),
    // PAS la boucle AU elle-même (ça, c'est EmergencyChainClosed_DI, ci-dessous). Nom EmergencyStopOk
    // conservé tel quel (contrat FB standard Partie3 §1, utilisé partout) — reste le portail
    // maître du programme, car "puissance réellement présente" est la garantie la plus forte.
    EmergencyStopOk      : BOOL;   // 🚨 Contacteur de puissance confirmé engagé : TRUE=armé/actif ✅ | FALSE=non armé ou coupure 🔴
    EmergencyChain       : BOOL;   // 🔗 REX 2026-07-07 : boucle AU (coup-de-poing + contact PLC) : TRUE=saine ✅ | FALSE=AU appuyé ou PowerCutOff PLC actif 🔴 — précondition à l'armement, PAS le portail maître
    TopPositionSensor    : BOOL;   // 🔝 Fin de course HAUT (NC) : TRUE=libre ✅ | FALSE=butée atteinte 🔴→ForbidAscent
    SlackCableSwitch     : BOOL;   // 🔗 Mou câble sur tambour M2 (NC) : TRUE=câble tendu ✅ | FALSE=mou détecté 🔴→ForbidDescent
    KoboldContactFond    : BOOL;   // 🪨 Retour détecteur fond Kobold (NO) : TRUE=contact fond détecté ✅
    PhaseRotationOk      : BOOL;   // ⚡ Rotation phases élec. (NC) : TRUE=phases OK ✅ | FALSE=inversées/absentes 🔴→SafeStop
    // 🆕 REX 2026-07-08 : retour thermique COMMUN aux 3 freins M1/M2/M3 (1 seul fil, impossible
    // de savoir lequel des 3 est en cause) — demande utilisateur : la perte de ce retour peut
    // signifier un frein qui colle instantanément (frein à manque de courant) → traité comme
    // les autres défauts francs du domaine, escalade PowerCutOff côté FB_Safety_Winch/_Translation
    // (voir bit10/bit3 respectifs).
    BrakeThermalFeedback : BOOL;   // 🌡️ Thermique frein M1/M2/M3 commun (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴→SafeStop+PowerCutOff

    // ── 🪝 TREUIL M1 (frein=NC ; feedback contacteurs=retour unique REX 2026-07-07) ─────
    M1FwdRevSpeedFeedbackOff : BOOL; // 📡 REX 2026-07-07 : retour unique "tous contacteurs (sens+vitesse)
                                      // retombés" M1 — remplace M1ContactorFeedbackFwd/Rev (feedback
                                      // individuel par sens supprimé côté matériel, plus jamais câblé).
                                      // TRUE = tous retombés (sain, rien d'engagé)
    M1ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M1 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M1BrakeFeedback        : BOOL; // 🔒 Retour frein M1, NORMALISÉ : TRUE=frein serré ✅ | FALSE=desserré 🔴
                                    // ⚠️ Le DI physique vaut 1 quand le frein est OUVERT (image du contacteur
                                    // de commande) — inversion faite par BrakeFeedbackInvertLogic, voir VAR.

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2FwdRevSpeedFeedbackOff : BOOL; // 📡 REX 2026-07-07 : idem M1, voir ci-dessus
    M2ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M2 (NC) : TRUE=surchauffe ou coupure 🔴→SafeStop+PowerCutOff
    M2BrakeFeedback        : BOOL; // 🔒 Retour frein M2, NORMALISÉ : TRUE=frein serré ✅ | FALSE=desserré 🔴
                                    // ⚠️ Même remarque que M1 (DI physique = 1 quand frein ouvert).

    // ── ↔️ TRANSLATION M3 (capteurs position=NO — position atteinte=TRUE) ────────────────────
    // 🆕 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 §3bis) — 5 capteurs Trémie|PV|P2|P1|
    // Maintenance (ex-Fosse1/Fosse2/Maintenance/Trémie, 4 capteurs). PV=pré-ralentissement avant
    // Trémie. Décodage du mot + limites extrêmes + incohérence : voir FB_Translation_PositionDecoder
    // (PRG_07_TranslationControl).
    TranslationPosTremie      : BOOL;  // 🗑️ Position trémie vidange (NO), extrême gauche : TRUE=en position trémie ✅ | FALSE=absent
    TranslationPosPV          : BOOL;  // 🐢 Pré-ralentissement (Point de Vitesse) avant Trémie (NO) : TRUE=zone PV atteinte ✅ | FALSE=absent
    TranslationPosP2          : BOOL;  // 📍 Position P2 (NO, ex-Fosse2) : TRUE=translation en P2 ✅ | FALSE=absent
    TranslationPosP1          : BOOL;  // 📍 Position P1 (NO, ex-Fosse1) : TRUE=translation en P1 ✅ | FALSE=absent
    TranslationPosMaintenance : BOOL;  // 🔧 Position maintenance (NO), extrême droite, accès MAINT_N2 uniquement : TRUE=en position service ✅ | FALSE=absent
    M3BrakeFeedback       : BOOL;  // 🔒 Retour frein M3, NORMALISÉ : TRUE=frein serré ✅ | FALSE=desserré 🔴
                                    // ⚠️ Même remarque que M1/M2 (DI physique = 1 quand frein ouvert).

    // 🆕 REX 2026-07-21 : décodage du mot des 5 capteurs position M3 (position 0, avant PRG_03_Safety)
    instPositionDecoder           : FB_Translation_PositionDecoder;

    M3_StatusWord_Filtered        : WORD;
    M3_ActualFrequencyHz_Filtered : UINT;
END_VAR
VAR
    // Instances de filtrage
    instEmergencyStopOk   : FB_Input;
    instEmergencyChain    : FB_Input; // 🔧 REX 2026-07-07
    instSlackCableSwitch  : FB_Input;
    instKoboldContactFond : FB_Input;
    instTopPositionSensor : FB_Input;
    instCtrlPhaseRotation : FB_Input;
    instBrakeThermalFeedback : FB_Input; // 🆕 REX 2026-07-08

    instM1FwdRevSpeedFeedbackOff : FB_Input; // 🔧 REX 2026-07-07 : remplace instM1ContactorFwd/Rev
    instM1Thermal      : FB_Input;
    instM1BrakeFeedback: FB_Input;

    instM2FwdRevSpeedFeedbackOff : FB_Input; // 🔧 REX 2026-07-07 : remplace instM2ContactorFwd/Rev
    instM2Thermal      : FB_Input;
    instM2BrakeFeedback: FB_Input;

    instTranslationPosTremie      : FB_Input;
    instTranslationPosPV          : FB_Input;
    instTranslationPosP2          : FB_Input;
    instTranslationPosP1          : FB_Input;
    instTranslationPosMaintenance : FB_Input;
    instM3BrakeFeedback       : FB_Input;

    // 🧪 Instance de simulation banc d'essai (Lot L6)
    instSimBench              : FB_SimBench;

    // 🧹 Purge one-shot des commandes IHM RETAIN, avant leur première consommation.
    HmiCommandsInitialized               : BOOL;

    // 🔩 ═══ POINT DE BASCULE UNIQUE — POLARITÉ DU RETOUR FREIN M1/M2/M3 ═══
    // 🆕 REX 2026-07-26 (relevé terrain) : le frein est à MANQUE DE COURANT (sortie PLC = 1 →
    // frein OUVERT). Le retour câblé est l'état du CONTACTEUR DE COMMANDE : s'il est commandé,
    // donc frein ouvert, on reçoit 1. Câblage réel : DI = 1 ⟺ frein OUVERT.
    // Or tout le programme aval (FB_Safety_Winch Méca A/B/D/E, FB_Safety_Translation Méca B,
    // FB_Brake) raisonne en « TRUE = frein SERRÉ » — l'état sûr. On normalise donc ICI, à la
    // frontière, via l'inversion NO/NC de FB_Input (rôle prévu, voir AF_Partie-06 §1).
    // 👉 SUR SITE : si la mesure montre que le retour est en fait inversé (DI = 1 ⟺ frein serré),
    //    passer CETTE SEULE VARIABLE à FALSE. Rien d'autre à toucher dans tout le programme.
    //    Modifiable à chaud en vue instance, sans recompiler.
    BrakeFeedbackInvertLogic             : BOOL := TRUE;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_00_Inputs) ===

// 🧹 WINCH-CORE-01 — PURGE COMMANDES IHM RETAIN AU BOOT
// PRG_00 est exécuté avant PRG_01..PRG_10 : aucune commande mémorisée ne peut donc
// produire un front ou un mouvement pendant le premier scan. Les états sûrs maintenus
// (`BtnEmergencyCutOff`, inhibitions) ne sont volontairement pas effacés.
IF NOT HmiCommandsInitialized THEN
    GVL_IHM.HmiInitDone := FALSE;

    // 🔧 REX 2026-07-24 (demande utilisateur) : Les boutons d'acquittement/reset (BtnFaultReset, etc.)
    // ne sont plus écrasés en boucle à FALSE par l'automate. Les blocs métier utilisent leur propre R_TRIG (ResetEdge).
    // Cela permet au technicien terrain de basculer la variable librement à 1 puis 0 dans CODESYS.
    GVL_IHM.Modes.Cmd.BtnEmergencyArming := FALSE;

    GVL_IHM.M1TreuilRetenue.Cmd.BtnHome := FALSE;
    GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault := FALSE;
    GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence := FALSE;
    GVL_IHM.M2TreuilBenne.Cmd.BtnHome := FALSE;
    GVL_IHM.M2TreuilBenne.Bypass.EncoderFault := FALSE;
    GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence := FALSE;

    GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen := FALSE;
    GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose := FALSE;
    GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos := FALSE;
    GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos := FALSE;

    GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
    GVL_IHM.Cycle.Cmd.BtnPause := FALSE;
    GVL_IHM.Cycle.Cmd.BtnAbort := FALSE;

    GVL_IHM.TranslationM3.Cmd.SelPositioning := FALSE;
    GVL_IHM.TranslationM3.Cmd.BtnFwd := FALSE;
    GVL_IHM.TranslationM3.Cmd.BtnRev := FALSE;
    GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate := FALSE;

    HmiCommandsInitialized := TRUE;
    GVL_IHM.HmiInitDone := TRUE;
END_IF;


// ─── §0 MATÉRIEL ──► HwReal (Acquisition brute unique) ──────────────────────
// Winch M1/M2 & Codeurs
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

// Translation M3 & AC600
HwReal.Translation.M3_PosTremie_DI      := M3_PosTremie_DI;
HwReal.Translation.M3_PosPV_DI          := M3_PosPV_DI;
HwReal.Translation.M3_PosP2_DI          := M3_PosP2_DI;
HwReal.Translation.M3_PosP1_DI          := M3_PosP1_DI;
HwReal.Translation.M3_PosMaintenance_DI := M3_PosMaintenance_DI;
HwReal.Translation.M3_BrakeIsOpen_DI    := M3_BrakeIsOpen_DI;
HwReal.Translation.M3_StatusWord        := M3_StatusWord;
HwReal.Translation.M3_ActualFrequencyHz := M3_ActualFrequencyHz;
HwReal.Translation.AC600_DeviceState    := AC600_ECAT_Drive.GetDeviceState();

// Opérateur / Joystick / CANopen
HwReal.Operator.JoyXRaw_ANA1      := JoyXRaw_ANA1;
HwReal.Operator.JoyYRaw_ANA2      := JoyYRaw_ANA2;
HwReal.Operator.JoyBtnRaw         := JoyBtnRaw;
HwReal.Operator.CanBusState       := CANbus.GetBusState();
HwReal.Operator.JOY1_DeviceState  := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();

// Sécurités / Communs Machine
HwReal.Machine.PowerContactorEngaged_DI   := PowerContactorEngaged_DI;
HwReal.Machine.EmergencyChainClosed_DI    := EmergencyChainClosed_DI;
HwReal.Machine.PhaseRotationOk_DI         := PhaseRotationOk_DI;
HwReal.Machine.BrakeThermalOk_DI          := BrakeThermalOk_DI;
HwReal.Machine.M1_M2_KoboldContactFond_DI := M1_M2_KoboldContactFond_DI;
HwReal.Machine.HydraulicThermalOk_DI      := HydraulicThermalOk_DI;


// ─── §0bis HwReal / SimBench ──► HwIn (Aiguillage simulation par domaine) ────
instSimBench(
    Enable                   := GVL_Simulation.SimulationModeActive,
    M1_RelayFwd              := PRG_10_Outputs.M1RelayFwd,
    M1_RelayRev              := PRG_10_Outputs.M1RelayRev,
    M1_SpeedContactor_1      := PRG_10_Outputs.M1SpeedContactor1,   // 🔧 REX 2026-07-27 : paliers
    M1_SpeedContactor_2      := PRG_10_Outputs.M1SpeedContactor2,   // inclus dans le retour unique
    M1_SpeedContactor_3      := PRG_10_Outputs.M1SpeedContactor3,   // « tous contacteurs retombés »
    M1_SpeedContactor_4      := PRG_10_Outputs.M1SpeedContactor4,
    M1_SpeedRefPct           := PRG_06_WinchControl.M1_SpeedRef_Active,
    M1_PresetTriggerCmd      := PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd,
    M1_PresetValueOut        := PRG_02_Encoders.instEncoderAbsM1.PresetValueOut,
    M1_BrakeCmd              := PRG_10_Outputs.M1BrakeCmd,
    M2_RelayFwd              := PRG_10_Outputs.M2RelayFwd,
    M2_RelayRev              := PRG_10_Outputs.M2RelayRev,
    M2_SpeedContactor_1      := PRG_10_Outputs.M2SpeedContactor1,   // 🔧 REX 2026-07-27 : idem M1
    M2_SpeedContactor_2      := PRG_10_Outputs.M2SpeedContactor2,
    M2_SpeedContactor_3      := PRG_10_Outputs.M2SpeedContactor3,
    M2_SpeedContactor_4      := PRG_10_Outputs.M2SpeedContactor4,
    M2_SpeedRefPct           := PRG_06_WinchControl.M2_SpeedRef_Active,
    M2_PresetTriggerCmd      := PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd,
    M2_PresetValueOut        := PRG_02_Encoders.instEncoderAbsM2.PresetValueOut,
    M2_BrakeCmd              := PRG_10_Outputs.M2BrakeCmd,
    M3_Direction             := PRG_07_TranslationControl.M3_Direction_Active,
    M3_SpeedRefPct           := PRG_07_TranslationControl.M3_SpeedRef_Active,
    M3_BrakeCmd              := PRG_10_Outputs.TranslationBrakeCmd,
    M3_TargetNum             := GVL_IHM.TranslationM3.Cmd.SelTarget,
    PowerKeepAlive_A         := PRG_10_Outputs.PowerCutOff_A,
    PowerKeepAlive_B         := PRG_10_Outputs.PowerCutOff_B,
    EmergencyArming_RQ       := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
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

IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive
    THEN HwIn.Winch := instSimBench.Winch;             ELSE HwIn.Winch := HwReal.Winch;             END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive
    THEN HwIn.Translation := instSimBench.Translation; ELSE HwIn.Translation := HwReal.Translation; END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive
    THEN HwIn.Operator := instSimBench.Operator;       ELSE HwIn.Operator := HwReal.Operator;       END_IF;
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimMachineActive
    THEN HwIn.Machine := instSimBench.Machine;         ELSE HwIn.Machine := HwReal.Machine;         END_IF;


// ─── §1 HwIn ──► FB_Input ──► VAR_OUTPUT (Conditionnement des entrées) ───────

//  🔌 HwIn.Machine.PowerContactorEngaged_DI ····· câblage réel : 1 = contacteur puissance engagé
//         └─►[ instEmergencyStopOk 🔩 ]         ← filtre anti-rebond 20 ms
//                └─► EmergencyStopOk ··········· [BLOQUE] TRUE = puissance présente ✅ (portail maître)
//                       └─► PRG_01..11 · FB_Safety_* · FB_Cycle · FB_Winch
instEmergencyStopOk(InputRaw := HwIn.Machine.PowerContactorEngaged_DI, FilterTime := T#20MS);
EmergencyStopOk := instEmergencyStopOk.State;

//  🔌 HwIn.Machine.EmergencyChainClosed_DI ······ câblage réel : 1 = boucle AU fermée
//         └─►[ instEmergencyChain 🔩 ]          ← filtre anti-rebond 20 ms
//                └─► EmergencyChain ············ [BLOQUE] TRUE = boucle AU saine ✅ (précondition armement)
//                       └─► PRG_03_Safety · PRG_06_WinchControl · PRG_11_Troubleshooting
instEmergencyChain(InputRaw := HwIn.Machine.EmergencyChainClosed_DI, FilterTime := T#20MS);
EmergencyChain := instEmergencyChain.State;

//  🔌 HwIn.Winch.M2_TensionedCable_DI ··········· câblage réel : 1 = câble tendu (NC)
//         └─►[ instSlackCableSwitch 🔩 ]        ← filtre anti-rebond 20 ms
//                └─► SlackCableSwitch ·········· [BLOQUE] TRUE = câble tendu ✅ | FALSE = mou 🔴→ForbidDescent M2
//                       └─► PRG_03_Safety (instSafetyWinchM1/M2) · PRG_11_Troubleshooting
instSlackCableSwitch(InputRaw := HwIn.Winch.M2_TensionedCable_DI, FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;

//  🔌 HwIn.Machine.M1_M2_KoboldContactFond_DI ·· câblage réel : 1 = contact fond détecté (NO)
//         └─►[ instKoboldContactFond 🔩 ]       ← filtre anti-rebond 20 ms
//                └─► KoboldContactFond ········· [BLOQUE] TRUE = fond touché ✅ → cycle figé BOTTOM_TOUCH_WAIT
//                       └─► PRG_05_Cycle (instCycle) · PRG_09_Supervision
instKoboldContactFond(InputRaw := HwIn.Machine.M1_M2_KoboldContactFond_DI, FilterTime := T#20MS);
KoboldContactFond := instKoboldContactFond.State;

//  🔌 HwIn.Winch.M1M2_TopPositionFree_DI ········ câblage réel : 1 = fin de course libre (NC)
//         └─►[ instTopPositionSensor 🔩 ]       ← filtre anti-rebond 20 ms
//                └─► TopPositionSensor ········· [BLOQUE] TRUE = libre ✅ | FALSE = butée haute 🔴→ForbidAscent M1+M2
//                       └─► PRG_02_Encoders (instHomingM1/M2) · PRG_03_Safety
instTopPositionSensor(InputRaw := HwIn.Winch.M1M2_TopPositionFree_DI, FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;

//  🔌 HwIn.Machine.PhaseRotationOk_DI ··········· câblage réel : 1 = rotation phases correcte (NC)
//         └─►[ instCtrlPhaseRotation 🔩 ]       ← filtre anti-rebond 20 ms
//                └─► PhaseRotationOk ··········· [ESCAL.] TRUE = phases OK ✅ | FALSE = inversées 🔴→SafeStop 3 axes
//                       └─► PRG_03_Safety (instSafetyWinchM1/M2/TranslationM3)
instCtrlPhaseRotation(InputRaw := HwIn.Machine.PhaseRotationOk_DI, FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;

//  🔌 HwIn.Machine.BrakeThermalOk_DI ············ câblage réel : 1 = temp. freins OK (NC, commun M1/M2/M3)
//         └─►[ instBrakeThermalFeedback 🔩 ]    ← filtre anti-rebond 20 ms
//                └─► BrakeThermalFeedback ····· [ESCAL.] TRUE = temp OK ✅ | FALSE = surchauffe 🔴→SafeStop+PowerCutOff
//                       └─► PRG_03_Safety (instSafetyWinchM1/M2/TranslationM3)
instBrakeThermalFeedback(InputRaw := HwIn.Machine.BrakeThermalOk_DI, FilterTime := T#20MS);
BrakeThermalFeedback := instBrakeThermalFeedback.State;

// 🪝 TREUIL M1
//  🔌 HwIn.Winch.M1_ContactorsReleased_DI ······· câblage réel : 1 = tous contacteurs retombés
//         └─►[ instM1FwdRevSpeedFeedbackOff 🔩 ]← filtre anti-rebond 20 ms
//                └─► M1FwdRevSpeedFeedbackOff · [ESCAL.] TRUE = retombés ✅ | FALSE = contacteur collé 🔴→Méca A/C
//                       └─► PRG_02_Encoders · PRG_03_Safety (instSafetyWinchM1)
instM1FwdRevSpeedFeedbackOff(InputRaw := HwIn.Winch.M1_ContactorsReleased_DI, FilterTime := T#20MS);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;

//  🔌 HwIn.Winch.M1_ThermalOk_DI ················ câblage réel : 1 = temp. moteur M1 OK (NC)
//         └─►[ instM1Thermal 🔩 ]               ← filtre anti-rebond 20 ms
//                └─► M1ThermalFeedback ········· [ESCAL.] TRUE = temp OK ✅ | FALSE = surchauffe 🔴 (NOTE: PRG_03 inverse en "TRUE=défaut")
//                       └─► PRG_03_Safety (instSafetyWinchM1) · PRG_09_Supervision
instM1Thermal(InputRaw := HwIn.Winch.M1_ThermalOk_DI, FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;

//  🔌 HwIn.Winch.M1_BrakeIsOpen_DI ·············· câblage réel : 1 = contacteur commandé = DESSERRÉ
//         └─►[ instM1BrakeFeedback 🔩 ]         ← bascule unique BrakeFeedbackInvertLogic, 📄 AF_Partie-09 §5bis
//                └─► M1BrakeFeedback ··········· [ESCAL.] TRUE = frein SERRÉ (état sûr) ✅ | FALSE = desserré 🔴
//                       └─► PRG_02_Encoders · PRG_03_Safety (instSafetyWinchM1 Méca A/B/D/E)
instM1BrakeFeedback(InputRaw := HwIn.Winch.M1_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 TREUIL M2
//  🔌 HwIn.Winch.M2_ContactorsReleased_DI ······· câblage réel : 1 = tous contacteurs retombés
//         └─►[ instM2FwdRevSpeedFeedbackOff 🔩 ]← filtre anti-rebond 20 ms
//                └─► M2FwdRevSpeedFeedbackOff · [ESCAL.] TRUE = retombés ✅ | FALSE = contacteur collé 🔴→Méca A/C
//                       └─► PRG_02_Encoders · PRG_03_Safety (instSafetyWinchM2)
instM2FwdRevSpeedFeedbackOff(InputRaw := HwIn.Winch.M2_ContactorsReleased_DI, FilterTime := T#20MS);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;

//  🔌 HwIn.Winch.M2_ThermalOk_DI ················ câblage réel : 1 = temp. moteur M2 OK (NC)
//         └─►[ instM2Thermal 🔩 ]               ← filtre anti-rebond 20 ms
//                └─► M2ThermalFeedback ········· [ESCAL.] TRUE = temp OK ✅ | FALSE = surchauffe 🔴 (NOTE: PRG_03 inverse en "TRUE=défaut")
//                       └─► PRG_03_Safety (instSafetyWinchM2) · PRG_09_Supervision
instM2Thermal(InputRaw := HwIn.Winch.M2_ThermalOk_DI, FilterTime := T#20MS);
M2ThermalFeedback := instM2Thermal.State;

//  🔌 HwIn.Winch.M2_BrakeIsOpen_DI ·············· câblage réel : 1 = contacteur commandé = DESSERRÉ
//         └─►[ instM2BrakeFeedback 🔩 ]         ← bascule unique BrakeFeedbackInvertLogic, 📄 AF_Partie-09 §5bis
//                └─► M2BrakeFeedback ··········· [ESCAL.] TRUE = frein SERRÉ (état sûr) ✅ | FALSE = desserré 🔴
//                       └─► PRG_02_Encoders · PRG_03_Safety (instSafetyWinchM2 Méca A/B/D/E)
instM2BrakeFeedback(InputRaw := HwIn.Winch.M2_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M2BrakeFeedback := instM2BrakeFeedback.State;

// ↔️ TRANSLATION M3
//  🔌 HwIn.Translation.M3_PosTremie_DI ········· câblage réel : 1 = position trémie atteinte (NO)
//         └─►[ instTranslationPosTremie 🔩 ]    ← filtre anti-rebond 20 ms
//                └─► TranslationPosTremie ····· [DIAG] TRUE = en position trémie ✅
//                       └─► instPositionDecoder · PRG_05_Cycle · PRG_09_Supervision
instTranslationPosTremie(InputRaw := HwIn.Translation.M3_PosTremie_DI, FilterTime := T#20MS);
TranslationPosTremie := instTranslationPosTremie.State;

//  🔌 HwIn.Translation.M3_PosPV_DI ············· câblage réel : 1 = zone PV atteinte (NO)
//         └─►[ instTranslationPosPV 🔩 ]        ← filtre anti-rebond 20 ms
//                └─► TranslationPosPV ········· [DIAG] TRUE = zone PV atteinte ✅ (pré-ralentissement Trémie)
//                       └─► instPositionDecoder · PRG_09_Supervision
instTranslationPosPV(InputRaw := HwIn.Translation.M3_PosPV_DI, FilterTime := T#20MS);
TranslationPosPV := instTranslationPosPV.State;

//  🔌 HwIn.Translation.M3_PosP2_DI ············· câblage réel : 1 = position P2 atteinte (NO)
//         └─►[ instTranslationPosP2 🔩 ]        ← filtre anti-rebond 20 ms
//                └─► TranslationPosP2 ········· [DIAG] TRUE = position P2 atteinte ✅
//                       └─► instPositionDecoder · PRG_05_Cycle · PRG_09_Supervision
instTranslationPosP2(InputRaw := HwIn.Translation.M3_PosP2_DI, FilterTime := T#20MS);
TranslationPosP2 := instTranslationPosP2.State;

//  🔌 HwIn.Translation.M3_PosP1_DI ············· câblage réel : 1 = position P1 atteinte (NO)
//         └─►[ instTranslationPosP1 🔩 ]        ← filtre anti-rebond 20 ms
//                └─► TranslationPosP1 ········· [DIAG] TRUE = position P1 atteinte ✅
//                       └─► instPositionDecoder · PRG_05_Cycle · PRG_09_Supervision
instTranslationPosP1(InputRaw := HwIn.Translation.M3_PosP1_DI, FilterTime := T#20MS);
TranslationPosP1 := instTranslationPosP1.State;

//  🔌 HwIn.Translation.M3_PosMaintenance_DI ···· câblage réel : 1 = position service atteinte (NO)
//         └─►[ instTranslationPosMaintenance 🔩 ]← filtre anti-rebond 20 ms
//                └─► TranslationPosMaintenance · [DIAG] TRUE = position service atteinte ✅
//                       └─► instPositionDecoder · PRG_05_Cycle · PRG_09_Supervision
instTranslationPosMaintenance(InputRaw := HwIn.Translation.M3_PosMaintenance_DI, FilterTime := T#20MS);
TranslationPosMaintenance := instTranslationPosMaintenance.State;

//  🔌 ─── §2 DÉCODAGE MOT CAPTEURS M3 ──────────────────────────────────────────
// 🆕 REX 2026-07-21 : Décodage immédiat du mot 5 capteurs position M3 (scan position 0)
instPositionDecoder(
    SensorTremie      := TranslationPosTremie,
    SensorPV          := TranslationPosPV,
    SensorP2          := TranslationPosP2,
    SensorP1          := TranslationPosP1,
    SensorMaintenance := TranslationPosMaintenance
);

//  🔌 HwIn.Translation.M3_BrakeIsOpen_DI ······· câblage réel : 1 = contacteur commandé = DESSERRÉ
//         └─►[ instM3BrakeFeedback 🔩 ]         ← bascule unique BrakeFeedbackInvertLogic, 📄 AF_Partie-11 §5
//                └─► M3BrakeFeedback ··········· [ESCAL.] TRUE = frein SERRÉ (état sûr) ✅ | FALSE = desserré 🔴
//                       └─► PRG_03_Safety (instSafetyTranslationM3 Méca B) · PRG_09_Supervision
instM3BrakeFeedback(InputRaw := HwIn.Translation.M3_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M3BrakeFeedback := instM3BrakeFeedback.State;

// Retours variateur EtherCAT M3 physiques directs (recopie HwIn)
M3_ActualFrequencyHz_Filtered := HwIn.Translation.M3_ActualFrequencyHz;
M3_StatusWord_Filtered        := HwIn.Translation.M3_StatusWord;

(* ═══════════════════════════════════════════════════════════════
   📥 PRG_00_Inputs — Acquisition et conditionnement des ENTRÉES (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_IO_Conditioning_v1.6.md §5
   ⚙️ Exécuté par la tâche PLC (Task Manager) en position 0.
   ✅ Expose ses sorties en VAR_OUTPUT (lecture seule pour le reste du code).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_00_Inputs
VAR_OUTPUT
    // ── 🛑 SÉCURITÉS COMMUNES (NC — repos=TRUE sain, FALSE=défaut/fil coupé) ──────────────
    // 🔧 REX 2026-07-07 : précision terrain — EmergencyStopOk_DI (retour contact auxiliaire NO)
    // est en fait la confirmation que le CONTACTEUR DE PUISSANCE est réellement engagé (1=actif),
    // PAS la boucle AU elle-même (ça, c'est EmergencyChainOK_DI, ci-dessous). Nom EmergencyStopOk
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
    M1BrakeFeedback        : BOOL; // 🔒 Retour frein M1 (NC) : TRUE=frein serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2FwdRevSpeedFeedbackOff : BOOL; // 📡 REX 2026-07-07 : idem M1, voir ci-dessus
    M2ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M2 (NC) : TRUE=surchauffe ou coupure 🔴→SafeStop+PowerCutOff
    M2BrakeFeedback        : BOOL; // 🔒 Retour frein M2 (NC) : TRUE=serré repos ✅ | FALSE=desserré/coupure 🔴

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
    M3BrakeFeedback       : BOOL;  // 🔒 Retour frein translation M3 (NC) : TRUE=serré repos ✅ | FALSE=desserré 🔴

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

    // 🧪 Simulation dynamique du trajet translation M3 (Lot 4, non prioritaire — voir DOC/AF_Partie-13_Fonction_Simulation_v1.2.md)
    instSimTranslation            : FB_Sim_Translation;

    // 🧪 Simulation de la chaîne de sécurité AU / réarmement (Lot 1, combler le trou d'intégration)
    instSimSafety             : FB_Sim_Safety;

    // 🧪 Simulation des retours contacteurs et freins M1/M2 (Lot 1)
    M1_FwdRevSpeedFeedbackOff_Simulated : BOOL;
    M1BrakeFeedback_Simulated           : BOOL;
    M2_FwdRevSpeedFeedbackOff_Simulated : BOOL;
    M2BrakeFeedback_Simulated           : BOOL;
    M3BrakeFeedback_Simulated           : BOOL;
 
    // 🆕 REX 2026-07-08 (4) : cohérence simulation capteur haut (voir instTopPositionSensor ci-dessous)
    SimTopSensorTriggered                : BOOL;
    
    // 🧪 Suite de tests de validation (exécutée uniquement en simulation)
    instTestsManagement                  : FB_PLC_Tests_Management;

    // 🧹 Purge one-shot des commandes IHM RETAIN, avant leur première consommation.
    HmiCommandsInitialized               : BOOL;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_00_Inputs) ===

// 🧹 WINCH-CORE-01 — PURGE COMMANDES IHM RETAIN AU BOOT
// PRG_00 est exécuté avant PRG_01..PRG_10 : aucune commande mémorisée ne peut donc
// produire un front ou un mouvement pendant le premier scan. Les états sûrs maintenus
// (`CmdEmergencyCutOff`, inhibitions) ne sont volontairement pas effacés.
// L'override permet uniquement à la suite PLC de rejouer ce scénario en simulation.
IF NOT HmiCommandsInitialized
   OR (GVL_Simulation.SimulationModeActive AND GVL_PLC_Tests.OverrideHmiCommandPurge) THEN
    GVL_IHM.HmiInitDone := FALSE;

    GVL_IHM.Modes.FaultMachineReset := FALSE;
    GVL_IHM.Modes.ModeReset := FALSE;
    GVL_IHM.Modes.CmdEmergencyArming := FALSE;

    GVL_IHM.M1TreuilRetenue.CmdReset := FALSE;
    GVL_IHM.M1TreuilRetenue.CmdHome := FALSE;
    GVL_IHM.M1TreuilRetenue.CmdEncoderFaultBypass := FALSE;
    GVL_IHM.M1TreuilRetenue.ConfirmCoherence := FALSE;
    GVL_IHM.M2TreuilBucket.CmdReset := FALSE;
    GVL_IHM.M2TreuilBucket.CmdHome := FALSE;
    GVL_IHM.M2TreuilBucket.CmdEncoderFaultBypass := FALSE;
    GVL_IHM.M2TreuilBucket.ConfirmCoherence := FALSE;

    GVL_IHM.Bucket.CmdOpen := FALSE;
    GVL_IHM.Bucket.CmdClose := FALSE;
    GVL_IHM.Bucket.CmdReset := FALSE;
    GVL_IHM.Bucket.CmdConfirmOpenPosition := FALSE;
    GVL_IHM.Bucket.CmdConfirmClosePosition := FALSE;

    GVL_IHM.Cycle.CmdStart := FALSE;
    GVL_IHM.Cycle.CmdPause := FALSE;
    GVL_IHM.Cycle.CmdAbort := FALSE;
    GVL_IHM.Cycle.CmdReset := FALSE;

    GVL_IHM.TranslationM3.PositioningSelect := FALSE;
    GVL_IHM.TranslationM3.ReqFwd := FALSE;
    GVL_IHM.TranslationM3.ReqRev := FALSE;
    GVL_IHM.JoystickJOY1.Calibrate := FALSE;

    HmiCommandsInitialized := TRUE;
    GVL_IHM.HmiInitDone := TRUE;
END_IF;

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
// 🧪 Simulation : chaque OR ci-dessous force le capteur à son état "sain" (famille
// sécurité, TRUE=OK) quand SimulationModeActive ET que ce capteur précis n'est
// pas encore câblé réellement (GVL_Simulation.*_IsReal). Voir DOC/AF_Partie-13_Fonction_Simulation_v1.2.md.

// Simulation de la chaîne de sécurité AU / réarmement (Lot 1)
instSimSafety(
    Enable          := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EmergencyStopChain_IsReal,
    PowerCutOff_A   := PowerCutOff_A_RQ,
    PowerCutOff_B   := PowerCutOff_B_RQ,
    EmergencyArming := EmergencyArming_RQ,
    BtnEmergencyStop := GVL_PLC_Tests.OverrideChainFalse
);

instEmergencyStopOk(InputRaw := EmergencyStopOk_DI OR instSimSafety.SimContactorOk, FilterTime := T#20MS);
EmergencyStopOk := instEmergencyStopOk.State;

// 🔧 REX 2026-07-07 : boucle AU (coup-de-poing + contact PLC) — distincte du contacteur de
// puissance ci-dessus. Réutilise le même flag simulation (même sous-système physique AU).
instEmergencyChain(InputRaw := EmergencyChainOK_DI OR instSimSafety.SimChainOk, FilterTime := T#20MS);
EmergencyChain := instEmergencyChain.State;

// 🔧 REX 2026-07-07 : M1_M2_SlackCableSwitch_DI → M2_SlackCableSwitch_DI (capteur physiquement
// uniquement sur le tambour M2, le préfixe M1_M2_ ne reflétait pas la réalité du câblage)
instSlackCableSwitch(InputRaw := M2_SlackCableSwitch_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal), FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;

// 🪨 Kobold : entrée dédiée, distincte du mou de câble.
// Adresse terrain : KoboldContactFond_DI = %IX0.5.
instKoboldContactFond(
    InputRaw := KoboldContactFond_DI
                OR (GVL_Simulation.SimulationModeActive
                    AND NOT GVL_Simulation.KoboldContactFond_IsReal
                    AND GVL_Simulation.KoboldContactFond_Simulated),
    FilterTime := T#20MS);
KoboldContactFond := instKoboldContactFond.State;

// 🆕 REX 2026-07-08 (4) : cohérence simulation (demande utilisateur) — l'ancien câblage forçait
// TopPositionSensor à TOUJOURS TRUE (sain) en simulation, quelle que soit la position codeur :
// impossible de tester bit5/Méca D (capteur haut) en simulation, il ne se déclenchait JAMAIS.
// Dérivé désormais de la position M1 simulée (référence de l'ensemble, voir FB_Bucket/
// ActiveOffsetM) — 1 cycle de retard (PRG_00 avant PRG_02 dans l'ordre de tâche), négligeable,
// même principe déjà assumé ailleurs (EncoderFaultPresent, BenneHoldStillActive).
SimTopSensorTriggered := (NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _HomingTargetM1_M))
                      OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= _HomingTargetM2_M));
instTopPositionSensor(InputRaw := M1_M2_TopPositionSensor_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal AND NOT SimTopSensorTriggered), FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;

instCtrlPhaseRotation(InputRaw := CtrlPhaseRotation_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.PhaseRotationOk_IsReal), FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;

// 🆕 REX 2026-07-08 : thermique frein commun M1/M2/M3 (1 seul fil, voir bandeau ci-dessus)
instBrakeThermalFeedback(InputRaw := BrakeThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BrakeThermal_IsReal), FilterTime := T#20MS);
BrakeThermalFeedback := instBrakeThermalFeedback.State;

// 🪝 ─── WINCH M1 ──────────────────────────────────────────────────────────
// 🧪 Simulation des retours contacteurs M1 (retombés si aucun sens/vitesse commandé)
M1_FwdRevSpeedFeedbackOff_Simulated := NOT (PRG_10_Outputs.M1RelayFwd OR PRG_10_Outputs.M1RelayRev OR PRG_10_Outputs.M1SpeedContactor1 OR PRG_10_Outputs.M1SpeedContactor2 OR PRG_10_Outputs.M1SpeedContactor3 OR PRG_10_Outputs.M1SpeedContactor4);
instM1FwdRevSpeedFeedbackOff(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal, M1_FwdRevSpeedFeedbackOff_DI, M1_FwdRevSpeedFeedbackOff_Simulated), FilterTime := T#20MS);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;

instM1Thermal(InputRaw := M1_ThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ThermalM1_IsReal), FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;

// 🧪 Simulation du retour frein M1 (fermé si commande inactive)
M1BrakeFeedback_Simulated := NOT PRG_10_Outputs.M1BrakeCmd;
instM1BrakeFeedback(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal, M1_BrakeFeedback_DI, M1BrakeFeedback_Simulated), FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
// 🧪 Simulation des retours contacteurs M2 (retombés si aucun sens/vitesse commandé)
M2_FwdRevSpeedFeedbackOff_Simulated := NOT (PRG_10_Outputs.M2RelayFwd OR PRG_10_Outputs.M2RelayRev OR PRG_10_Outputs.M2SpeedContactor1 OR PRG_10_Outputs.M2SpeedContactor2 OR PRG_10_Outputs.M2SpeedContactor3 OR PRG_10_Outputs.M2SpeedContactor4);
instM2FwdRevSpeedFeedbackOff(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal, M2_FwdRevSpeedFeedbackOff_DI, M2_FwdRevSpeedFeedbackOff_Simulated), FilterTime := T#20MS);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;

instM2Thermal(InputRaw := M2_ThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ThermalM2_IsReal), FilterTime := T#20MS);
M2ThermalFeedback := instM2Thermal.State;

// 🧪 Simulation du retour frein M2 (fermé si commande inactive)
M2BrakeFeedback_Simulated := NOT PRG_10_Outputs.M2BrakeCmd;
instM2BrakeFeedback(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal, M2_BrakeFeedback_DI, M2BrakeFeedback_Simulated), FilterTime := T#20MS);
M2BrakeFeedback := instM2BrakeFeedback.State;

// ↔️ ─── TRANSLATION M3 ────────────────────────────────────────────────────────
// 🧪 Simulation dynamique du trajet M3 (FB_Sim_Translation, non prioritaire — voir DOC/AF_Partie-13_Fonction_Simulation_v1.2.md
// §Translation). Appelée AVANT les FB_Input pour que ses sorties soient à jour au même cycle
// (sinon décalage d'1 cycle sur le OR ci-dessous). Remplace le forçage manuel en vue instance.
// 🔧 L'ancien mode relais DEGRADED_IO est supprimé. La simulation déduit directement le sens de
// `M3_CommandWord`, variable PDO EtherCAT réellement envoyée en Auto comme en Manuel.
// Lecture décalée d'1 cycle (10 ms, M3_CommandWord réécrit en position
// 10 par PRG_10_Outputs après ce PRG_00) — négligeable devant TravelTimeS (8s).
instSimTranslation(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal,
    TargetNum   := GVL_Translation_M3_Stub.StubTranslationPositionSelect_IHM,
    RelayFwd    := M3_CommandWord = 1,
    RelayRev    := M3_CommandWord = 2,
    TravelTimeS := 8.0
);

instTranslationPosTremie(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal, PosTremie_DI, instSimTranslation.PosTremie), FilterTime := T#20MS);
TranslationPosTremie := instTranslationPosTremie.State;

instTranslationPosPV(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal, GVL_Translation_M3_Stub.PosPV_DI, instSimTranslation.PosPV), FilterTime := T#20MS);
TranslationPosPV := instTranslationPosPV.State;

instTranslationPosP2(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal, PosFosse2_DI, instSimTranslation.PosP2), FilterTime := T#20MS);
TranslationPosP2 := instTranslationPosP2.State;

instTranslationPosP1(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal, PosFosse1_DI, instSimTranslation.PosP1), FilterTime := T#20MS);
TranslationPosP1 := instTranslationPosP1.State;

instTranslationPosMaintenance(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal, PosMaintenance_DI, instSimTranslation.PosMaintenance), FilterTime := T#20MS);
TranslationPosMaintenance := instTranslationPosMaintenance.State;

// 🆕 REX 2026-07-21 : Décodage immédiat du mot 5 capteurs position M3 (scan position 0)
instPositionDecoder(
    SensorTremie      := TranslationPosTremie,
    SensorPV          := TranslationPosPV,
    SensorP2          := TranslationPosP2,
    SensorP1          := TranslationPosP1,
    SensorMaintenance := TranslationPosMaintenance
);
 
// 🧪 Simulation du retour frein M3 (fermé/NC=TRUE si commande inactive)
M3BrakeFeedback_Simulated := NOT PRG_07_TranslationControl.instTranslationM3.BrakeCmd;
instM3BrakeFeedback(InputRaw := SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal, M3_BrakeFeedback_DI, M3BrakeFeedback_Simulated), FilterTime := T#20MS);
M3BrakeFeedback := instM3BrakeFeedback.State;

// 🧪 Simulation/Filtrage des retours variateur EtherCAT M3 (lecture seule physique contournée)
IF GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.VariateurM3_IsReal THEN
    M3_ActualFrequencyHz_Filtered := M3_SetpointFrequencyHz;
    
    // Status Word : Bit0 (Operation), Bit7 (Operation Enable)
    IF M3_CommandWord = 1 THEN
        M3_StatusWord_Filtered := 16#0081; // Operation + Operation Enable
    ELSIF M3_CommandWord = 2 THEN
        M3_StatusWord_Filtered := 16#0089; // Operation + Operation Enable + Reverse (bit3)
    ELSE
        M3_StatusWord_Filtered := 16#0080; // Stopped + Operation Enable
    END_IF;
ELSE
    M3_ActualFrequencyHz_Filtered := M3_ActualFrequencyHz;
    M3_StatusWord_Filtered        := M3_StatusWord;
END_IF;

// 🧪 Appel de la suite globale de tests de validation automate
instTestsManagement(instBucket := GVL_Simulation.refBucket, instWinchM2 := GVL_Simulation.refWinchM2);

// Surcharges (overrides) demandées par le banc de tests automatique
IF GVL_PLC_Tests.OverrideChainTrue THEN
    EmergencyChain := TRUE;
END_IF;
IF GVL_PLC_Tests.OverrideChainFalse THEN
    EmergencyChain := FALSE;
END_IF;
IF GVL_PLC_Tests.OverrideContactorFalse THEN
    EmergencyStopOk := FALSE;
ELSIF GVL_PLC_Tests.OverrideEmergencyStopOkTrue THEN
    EmergencyStopOk := TRUE;
END_IF;

// Surcharges (overrides) du banc de tests — Translation M3 (niveau capteur amont uniquement)
IF GVL_PLC_Tests.OverrideM3AtTremie THEN
    TranslationPosTremie := TRUE; // 🧪 Simule le Fdc extrême avant sans attendre le trajet simulé complet
END_IF;
// 🆕 REX 2026-07-18 : force les 5 capteurs position depuis un mot de test (indépendant du temps
// de trajet simulé) — seul moyen de tester les 6 mots valides ET les combinaisons incohérentes.
IF GVL_PLC_Tests.OverrideM3SensorsWordActive THEN
    TranslationPosTremie      := GVL_PLC_Tests.OverrideM3SensorsWord.4;
    TranslationPosPV          := GVL_PLC_Tests.OverrideM3SensorsWord.3;
    TranslationPosP2          := GVL_PLC_Tests.OverrideM3SensorsWord.2;
    TranslationPosP1          := GVL_PLC_Tests.OverrideM3SensorsWord.1;
    TranslationPosMaintenance := GVL_PLC_Tests.OverrideM3SensorsWord.0;
END_IF;
IF GVL_PLC_Tests.OverrideM3BrakeStuckOpen THEN
    M3BrakeFeedback := TRUE; // 🧪 Simule Méca B : retour frein resté desserré malgré commande fermée
END_IF;
IF GVL_PLC_Tests.OverrideM3PhantomFreq THEN
    M3_ActualFrequencyHz_Filtered := 100; // 🧪 Simule Méca A : 1.00Hz mesuré malgré arrêt commandé (seuil 0.5Hz)
END_IF;

// 🛡️ Surcharges retours arrêt M1/M2 — polarité inverse : arrêt confirmé = TRUE.
IF GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff THEN
    M1FwdRevSpeedFeedbackOff := GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff;
END_IF;
IF GVL_PLC_Tests.OverrideM1BrakeFeedback THEN
    M1BrakeFeedback := GVL_PLC_Tests.OverrideM1BrakeFeedback;
END_IF;
IF GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff THEN
    M2FwdRevSpeedFeedbackOff := GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff;
END_IF;
IF GVL_PLC_Tests.OverrideM2BrakeFeedback THEN
    M2BrakeFeedback := GVL_PLC_Tests.OverrideM2BrakeFeedback;
END_IF;

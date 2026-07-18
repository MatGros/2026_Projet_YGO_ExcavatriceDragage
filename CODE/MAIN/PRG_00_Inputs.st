(* ═══════════════════════════════════════════════════════════════
   📥 PRG_00_Inputs — Acquisition et conditionnement des ENTRÉES (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
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

    // 🆕 Variables intermédiaires filtrées/simulées pour contourner la lecture seule des PDO
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

    // 🧪 Simulation dynamique du trajet translation M3 (Lot 4, non prioritaire — voir AF_Partie13)
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
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_00_Inputs) ===

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
// 🧪 Simulation : chaque OR ci-dessous force le capteur à son état "sain" (famille
// sécurité, TRUE=OK) quand SimulationModeActive ET que ce capteur précis n'est
// pas encore câblé réellement (GVL_Simulation.*_IsReal). Voir AF_Partie13.

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
// 🧪 Simulation dynamique du trajet M3 (FB_Sim_Translation, non prioritaire — voir AF_Partie13
// §Translation). Appelée AVANT les FB_Input pour que ses sorties soient à jour au même cycle
// (sinon décalage d'1 cycle sur le OR ci-dessous). Remplace le forçage manuel en vue instance.
// 🔧 REX 2026-07-15 (3) : RelayFwd/RelayRev câblés sur M3_CommandWord (variable globale
// mappée PDO EtherCAT, valeur réellement envoyée, Auto ET Manu confondus) — ex-
// GVL_Translation_M3_Stub.M3_RelayFwd/Rev n'étaient plus jamais écrits depuis l'abandon du mode
// relais DEGRADED_IO (v0.4.11), la simulation de trajet M3 restait bloquée en permanence
// (relais toujours FALSE). Lecture décalée d'1 cycle (10ms, M3_CommandWord réécrit en position
// 10 par PRG_10_Outputs après ce PRG_00) — négligeable devant TravelTimeS (8s).
instSimTranslation(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TranslationPosition_IsReal,
    TargetNum   := GVL_Translation_M3_Stub.StubTranslationPositionSelect_IHM,
    RelayFwd    := M3_CommandWord = 1,
    RelayRev    := M3_CommandWord = 2,
    TravelTimeS := 8.0
);

instTranslationPosTremie(InputRaw := PosTremie_DI OR instSimTranslation.PosTremie, FilterTime := T#20MS);
TranslationPosTremie := instTranslationPosTremie.State;

instTranslationPosPV(InputRaw := GVL_Translation_M3_Stub.PosPV_DI OR instSimTranslation.PosPV, FilterTime := T#20MS);
TranslationPosPV := instTranslationPosPV.State;

instTranslationPosP2(InputRaw := PosFosse2_DI OR instSimTranslation.PosP2, FilterTime := T#20MS);
TranslationPosP2 := instTranslationPosP2.State;

instTranslationPosP1(InputRaw := PosFosse1_DI OR instSimTranslation.PosP1, FilterTime := T#20MS);
TranslationPosP1 := instTranslationPosP1.State;

instTranslationPosMaintenance(InputRaw := PosMaintenance_DI OR instSimTranslation.PosMaintenance, FilterTime := T#20MS);
TranslationPosMaintenance := instTranslationPosMaintenance.State;
 
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

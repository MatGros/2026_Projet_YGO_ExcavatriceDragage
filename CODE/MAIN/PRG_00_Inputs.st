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

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
// 🧪 Simulation : chaque OR ci-dessous force le capteur à son état "sain" (famille
// sécurité, TRUE=OK) quand SimulationModeActive ET que ce capteur précis n'est
// pas encore câblé réellement (GVL_Simulation.Bus*/Sensor*IsReal). Voir DOC/AF_Partie-13_Fonction_Simulation_v1.4.md.

instEmergencyStopOk(InputRaw := PowerContactorEngaged_DI, FilterTime := T#20MS);
EmergencyStopOk := instEmergencyStopOk.State;

// 🔧 REX 2026-07-07 : boucle AU (coup-de-poing + contact PLC)
instEmergencyChain(InputRaw := EmergencyChainClosed_DI, FilterTime := T#20MS);
EmergencyChain := instEmergencyChain.State;

instSlackCableSwitch(InputRaw := M2_TensionedCable_DI, FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;

instKoboldContactFond(InputRaw := M1_M2_KoboldContactFond_DI, FilterTime := T#20MS);
KoboldContactFond := instKoboldContactFond.State;

instTopPositionSensor(InputRaw := M1M2_TopPositionFree_DI, FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;

instCtrlPhaseRotation(InputRaw := PhaseRotationOk_DI, FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;

instBrakeThermalFeedback(InputRaw := BrakeThermalOk_DI, FilterTime := T#20MS);
BrakeThermalFeedback := instBrakeThermalFeedback.State;

// 🪝 ─── WINCH M1 ──────────────────────────────────────────────────────────
instM1FwdRevSpeedFeedbackOff(InputRaw := M1_ContactorsReleased_DI, FilterTime := T#20MS);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;

instM1Thermal(InputRaw := M1_ThermalOk_DI, FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;

instM1BrakeFeedback(InputRaw := M1_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2FwdRevSpeedFeedbackOff(InputRaw := M2_ContactorsReleased_DI, FilterTime := T#20MS);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;

instM2Thermal(InputRaw := M2_ThermalOk_DI, FilterTime := T#20MS);
M2ThermalFeedback := instM2Thermal.State;

instM2BrakeFeedback(InputRaw := M2_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M2BrakeFeedback := instM2BrakeFeedback.State;

// ↔️ ─── TRANSLATION M3 ────────────────────────────────────────────────────────
instTranslationPosTremie(InputRaw := M3_PosTremie_DI, FilterTime := T#20MS);
TranslationPosTremie := instTranslationPosTremie.State;

instTranslationPosPV(InputRaw := M3_PosPV_DI, FilterTime := T#20MS);
TranslationPosPV := instTranslationPosPV.State;

instTranslationPosP2(InputRaw := M3_PosP2_DI, FilterTime := T#20MS);
TranslationPosP2 := instTranslationPosP2.State;

instTranslationPosP1(InputRaw := M3_PosP1_DI, FilterTime := T#20MS);
TranslationPosP1 := instTranslationPosP1.State;

instTranslationPosMaintenance(InputRaw := M3_PosMaintenance_DI, FilterTime := T#20MS);
TranslationPosMaintenance := instTranslationPosMaintenance.State;

// 🆕 REX 2026-07-21 : Décodage immédiat du mot 5 capteurs position M3 (scan position 0)
instPositionDecoder(
    SensorTremie      := TranslationPosTremie,
    SensorPV          := TranslationPosPV,
    SensorP2          := TranslationPosP2,
    SensorP1          := TranslationPosP1,
    SensorMaintenance := TranslationPosMaintenance
);

instM3BrakeFeedback(InputRaw := M3_BrakeIsOpen_DI, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M3BrakeFeedback := instM3BrakeFeedback.State;

// Retours variateur EtherCAT M3 physiques directs
M3_ActualFrequencyHz_Filtered := M3_ActualFrequencyHz;
M3_StatusWord_Filtered        := M3_StatusWord;

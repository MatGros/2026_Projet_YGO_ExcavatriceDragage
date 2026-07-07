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
    // PAS la boucle AU elle-même (ça, c'est EmergencyChain_DI, ci-dessous). Nom EmergencyStopOk
    // conservé tel quel (contrat FB standard Partie3 §1, utilisé partout) — reste le portail
    // maître du programme, car "puissance réellement présente" est la garantie la plus forte.
    EmergencyStopOk      : BOOL;   // 🚨 Contacteur de puissance confirmé engagé : TRUE=armé/actif ✅ | FALSE=non armé ou coupure 🔴
    EmergencyChain       : BOOL;   // 🔗 REX 2026-07-07 : boucle AU (coup-de-poing + contact PLC) : TRUE=saine ✅ | FALSE=AU appuyé ou PowerCutOff PLC actif 🔴 — précondition à l'armement, PAS le portail maître
    TopPositionSensor    : BOOL;   // 🔝 Fin de course HAUT (NC) : TRUE=libre ✅ | FALSE=butée atteinte 🔴→ForbidAscent
    SlackCableSwitch     : BOOL;   // 🔗 Mou câble sur tambour M2 (NC) : TRUE=câble tendu ✅ | FALSE=mou détecté 🔴→ForbidDescent
    PhaseRotationOk      : BOOL;   // ⚡ Rotation phases élec. (NC) : TRUE=phases OK ✅ | FALSE=inversées/absentes 🔴→SafeStop

    // ── 🪝 TREUIL M1 (frein=NC ; feedback contacteurs=retour unique REX 2026-07-07) ─────
    M1FwdRevSpeedFeedbackOff : BOOL; // 📡 REX 2026-07-07 : retour unique "tous contacteurs (sens+vitesse)
                                      // retombés" M1 — remplace M1ContactorFeedbackFwd/Rev (feedback
                                      // individuel par sens supprimé côté matériel, plus jamais câblé).
                                      // TRUE = tous retombés (sain, rien d'engagé)
    M1ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M1 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M1BrakeFeedback        : BOOL; // 🔒 Retour frein M1 (NC) : TRUE=frein serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2FwdRevSpeedFeedbackOff : BOOL; // 📡 REX 2026-07-07 : idem M1, voir ci-dessus
    M2ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M2 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M2BrakeFeedback        : BOOL; // 🔒 Retour frein M2 (NC) : TRUE=serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── ↔️ CHARIOT M3 (capteurs position=NO — position atteinte=TRUE) ────────────────────
    ChariotPosFosse1      : BOOL;  // 📍 Position fosse 1 (NO) : TRUE=chariot en fosse 1 ✅ | FALSE=absent
    ChariotPosFosse2      : BOOL;  // 📍 Position fosse 2 (NO) : TRUE=chariot en fosse 2 ✅ | FALSE=absent
    ChariotPosMaintenance : BOOL;  // 🔧 Position maintenance (NO) : TRUE=en position service ✅ | FALSE=absent
    ChariotPosTremie      : BOOL;  // 🗑️ Position trémie vidange (NO) : TRUE=en position trémie ✅ | FALSE=absent
    M3BrakeFeedback       : BOOL;  // 🔒 Retour frein chariot M3 (NC) : TRUE=serré repos ✅ | FALSE=desserré 🔴
END_VAR
VAR
    // Instances de filtrage
    instEmergencyStopOk   : FB_Input;
    instEmergencyChain    : FB_Input; // 🔧 REX 2026-07-07
    instSlackCableSwitch  : FB_Input;
    instTopPositionSensor : FB_Input;
    instCtrlPhaseRotation : FB_Input;

    instM1FwdRevSpeedFeedbackOff : FB_Input; // 🔧 REX 2026-07-07 : remplace instM1ContactorFwd/Rev
    instM1Thermal      : FB_Input;
    instM1BrakeFeedback: FB_Input;

    instM2FwdRevSpeedFeedbackOff : FB_Input; // 🔧 REX 2026-07-07 : remplace instM2ContactorFwd/Rev
    instM2Thermal      : FB_Input;
    instM2BrakeFeedback: FB_Input;

    instChariotPosFosse1      : FB_Input;
    instChariotPosFosse2      : FB_Input;
    instChariotPosMaintenance : FB_Input;
    instChariotPosTremie      : FB_Input;
    instM3BrakeFeedback       : FB_Input;

    // 🧪 Simulation dynamique du trajet chariot M3 (Lot 4, non prioritaire — voir AF_Partie13)
    instSimChariot            : FB_Sim_Chariot;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_00_Inputs) ===

// 🛑 ─── COMMUN ────────────────────────────────────────────────────────────
// 🧪 Simulation : chaque OR ci-dessous force le capteur à son état "sain" (famille
// sécurité, TRUE=OK) quand SimulationModeActive ET que ce capteur précis n'est
// pas encore câblé réellement (GVL_Simulation.*_IsReal). Voir AF_Partie13.
instEmergencyStopOk(InputRaw := EmergencyStopOk_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EmergencyStopChain_IsReal), FilterTime := T#20MS);
EmergencyStopOk := instEmergencyStopOk.State;

// 🔧 REX 2026-07-07 : boucle AU (coup-de-poing + contact PLC) — distincte du contacteur de
// puissance ci-dessus. Réutilise le même flag simulation (même sous-système physique AU).
instEmergencyChain(InputRaw := EmergencyChain_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EmergencyStopChain_IsReal), FilterTime := T#20MS);
EmergencyChain := instEmergencyChain.State;

// 🔧 REX 2026-07-07 : M1_M2_SlackCableSwitch_DI → M2_SlackCableSwitch_DI (capteur physiquement
// uniquement sur le tambour M2, le préfixe M1_M2_ ne reflétait pas la réalité du câblage)
instSlackCableSwitch(InputRaw := M2_SlackCableSwitch_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal), FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;

instTopPositionSensor(InputRaw := M1_M2_TopPositionSensor_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal), FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;

instCtrlPhaseRotation(InputRaw := CtrlPhaseRotation_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.PhaseRotationOk_IsReal), FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;

// 🪝 ─── WINCH M1 ──────────────────────────────────────────────────────────
// 🔧 REX 2026-07-07 : M1_FeedbackFwd_DI/M1_FeedbackRev_DI (par sens) remplacés par un retour
// unique M1_FwdRevSpeedFeedbackOff_DI ("tous contacteurs sens+vitesse retombés").
instM1FwdRevSpeedFeedbackOff(InputRaw := M1_FwdRevSpeedFeedbackOff_DI, FilterTime := T#20MS);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;

instM1Thermal(InputRaw := M1_ThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ThermalM1_IsReal), FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;

instM1BrakeFeedback(InputRaw := M1_BrakeFeedback_DI, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2FwdRevSpeedFeedbackOff(InputRaw := M2_FwdRevSpeedFeedbackOff_DI, FilterTime := T#20MS);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;

instM2Thermal(InputRaw := M2_ThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ThermalM2_IsReal), FilterTime := T#20MS);
M2ThermalFeedback := instM2Thermal.State;

instM2BrakeFeedback(InputRaw := M2_BrakeFeedback_DI, FilterTime := T#20MS);
M2BrakeFeedback := instM2BrakeFeedback.State;

// ↔️ ─── CHARIOT M3 ────────────────────────────────────────────────────────
// 🧪 Simulation dynamique du trajet M3 (FB_Sim_Chariot, non prioritaire — voir AF_Partie13
// §Chariot). Appelée AVANT les FB_Input pour que ses sorties soient à jour au même cycle
// (sinon décalage d'1 cycle sur le OR ci-dessous). Remplace le forçage manuel en vue instance.
instSimChariot(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ChariotPosition_IsReal,
    TargetNum   := GVL_Chariot_M3_Stub.StubChariotPositionSelect_IHM,
    RelayFwd    := GVL_Chariot_M3_Stub.M3_RelayFwd,
    RelayRev    := GVL_Chariot_M3_Stub.M3_RelayRev,
    TravelTimeS := 8.0
);

instChariotPosFosse1(InputRaw := PosFosse1_DI OR instSimChariot.PosFosse1, FilterTime := T#20MS);
ChariotPosFosse1 := instChariotPosFosse1.State;

instChariotPosFosse2(InputRaw := PosFosse2_DI OR instSimChariot.PosFosse2, FilterTime := T#20MS);
ChariotPosFosse2 := instChariotPosFosse2.State;

instChariotPosMaintenance(InputRaw := PosMaintenance_DI OR instSimChariot.PosMaintenance, FilterTime := T#20MS);
ChariotPosMaintenance := instChariotPosMaintenance.State;

instChariotPosTremie(InputRaw := PosTremie_DI OR instSimChariot.PosTremie, FilterTime := T#20MS);
ChariotPosTremie := instChariotPosTremie.State;

instM3BrakeFeedback(InputRaw := M3_BrakeFeedback_DI, FilterTime := T#20MS);
M3BrakeFeedback := instM3BrakeFeedback.State;

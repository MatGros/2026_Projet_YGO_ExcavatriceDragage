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
    EmergencyStopOk      : BOOL;   // 🚨 Chaîne AU : TRUE=fermée/armée ✅ | FALSE=AU appuyé ou fil coupé 🔴
    TopPositionSensor    : BOOL;   // 🔝 Fin de course HAUT (NC) : TRUE=libre ✅ | FALSE=butée atteinte 🔴→ForbidAscent
    SlackCableSwitch     : BOOL;   // 🔗 Mou câble sur tambour M2 (NC) : TRUE=câble tendu ✅ | FALSE=mou détecté 🔴→ForbidDescent
    PhaseRotationOk      : BOOL;   // ⚡ Rotation phases élec. (NC) : TRUE=phases OK ✅ | FALSE=inversées/absentes 🔴→SafeStop

    // ── 🪝 TREUIL M1 (contacteurs=NO miroir bobine ; thermique/frein=NC) ────────────────
    M1ContactorFeedbackFwd : BOOL; // 📡 Retour contacteur MONTÉE M1 (NO) : TRUE=contacteur fermé | FALSE=ouvert
    M1ContactorFeedbackRev : BOOL; // 📡 Retour contacteur DESCENTE M1 (NO) : TRUE=contacteur fermé | FALSE=ouvert
    M1ThermalFeedback      : BOOL; // 🌡️ Thermique moteur M1 (NC) : TRUE=temp OK ✅ | FALSE=surchauffe ou coupure 🔴
    M1BrakeFeedback        : BOOL; // 🔒 Retour frein M1 (NC) : TRUE=frein serré repos ✅ | FALSE=desserré/coupure 🔴

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2ContactorFeedbackFwd : BOOL; // 📡 Retour contacteur MONTÉE M2 (NO) : TRUE=fermé | FALSE=ouvert
    M2ContactorFeedbackRev : BOOL; // 📡 Retour contacteur DESCENTE M2 (NO) : TRUE=fermé | FALSE=ouvert
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
    instSlackCableSwitch  : FB_Input;
    instTopPositionSensor : FB_Input;
    instCtrlPhaseRotation : FB_Input;

    instM1ContactorFwd : FB_Input;
    instM1ContactorRev : FB_Input;
    instM1Thermal      : FB_Input;
    instM1BrakeFeedback: FB_Input;

    instM2ContactorFwd : FB_Input;
    instM2ContactorRev : FB_Input;
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

instSlackCableSwitch(InputRaw := M1_M2_SlackCableSwitch_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal), FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;

instTopPositionSensor(InputRaw := M1_M2_TopPositionSensor_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal), FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;

instCtrlPhaseRotation(InputRaw := CtrlPhaseRotation_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.PhaseRotationOk_IsReal), FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;

// 🪝 ─── WINCH M1 ──────────────────────────────────────────────────────────
instM1ContactorFwd(InputRaw := M1_FeedbackFwd_DI, FilterTime := T#20MS);
M1ContactorFeedbackFwd := instM1ContactorFwd.State;

instM1ContactorRev(InputRaw := M1_FeedbackRev_DI, FilterTime := T#20MS);
M1ContactorFeedbackRev := instM1ContactorRev.State;

instM1Thermal(InputRaw := M1_ThermalFeedback_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ThermalM1_IsReal), FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;

instM1BrakeFeedback(InputRaw := M1_BrakeFeedback_DI, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2ContactorFwd(InputRaw := M2_FeedbackFwd_DI, FilterTime := T#20MS);
M2ContactorFeedbackFwd := instM2ContactorFwd.State;

instM2ContactorRev(InputRaw := M2_FeedbackRev_DI, FilterTime := T#20MS);
M2ContactorFeedbackRev := instM2ContactorRev.State;

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

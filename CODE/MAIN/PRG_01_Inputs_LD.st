(* ═══════════════════════════════════════════════════════════════
   📥 PRG_INPUTS_LD — Affichage qualifié des entrées TOR (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §2
   🎨 Rôle : conditionner les 19 E/S TOR retenues du traçage legacy via FB_Input.
              Aucune décision métier (SafeStop, mode, commande) n'est prise ici.
   🔗 Dépendances : PRG_02_Acquisition_CFC produit HwIn ; consommateurs = Safety/Modes/Cycle/Supervision.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_01_Inputs_LD

VAR_INPUT
    HwIn : ST_HardwareImage;    (* Image matérielle qualifiée produite par PRG_02_Acquisition_CFC *)
END_VAR

VAR_OUTPUT
    // ── [PUISSANCE & SÉCURITÉ COMMUNE] ─────────────────────────────────────────────────────
    PowerContactorEngaged   : BOOL := TRUE;   (* TRUE = contacteur de puissance engagé / portail maître OK *)
    EmergencyChainClosed    : BOOL := TRUE;   (* TRUE = boucle AU fermée (coup-de-poing + contact PLC) *)
    PhaseRotationOk         : BOOL := TRUE;   (* TRUE = rotation des phases électriques correcte *)
    BrakeThermalFeedback    : BOOL := TRUE;   (* TRUE = thermique freins M1/M2/M3 commun OK *)

    // ── [TREUILS M1 / M2] ─────────────────────────────────────────────────────────────────
    TopPositionSensor       : BOOL := TRUE;   (* TRUE = fin de course haut M1/M2 libre / non atteinte *)
    SlackCableSwitch        : BOOL := TRUE;   (* TRUE = câble M2 tendu / capteur mou non déclenché *)
    M1FwdRevSpeedFeedbackOff: BOOL := TRUE;   (* TRUE = tous contacteurs M1 retombés / aucun collage *)
    M1ThermalFeedback       : BOOL := TRUE;   (* TRUE = thermique moteur M1 OK *)
    M1BrakeFeedback         : BOOL := TRUE;   (* TRUE = frein M1 OUVERT (desserré) — polarité physique directe *)
    M2FwdRevSpeedFeedbackOff: BOOL := TRUE;   (* TRUE = tous contacteurs M2 retombés / aucun collage *)
    M2ThermalFeedback       : BOOL := TRUE;   (* TRUE = thermique moteur M2 OK *)
    M2BrakeFeedback         : BOOL := TRUE;   (* TRUE = frein M2 OUVERT (desserré) — polarité physique directe *)

    // ── [KOBOLD FOND] ──────────────────────────────────────────────────────────────────────
    KoboldContactFond       : BOOL;           (* TRUE = détecteur de fond Kobold en contact *)

    // ── [TRANSLATION M3] ───────────────────────────────────────────────────────────────────
    TranslationPosTremie       : BOOL;       (* TRUE = translation en position Trémie *)
    TranslationPosPV           : BOOL;       (* TRUE = translation en zone pré-ralentissement PV *)
    TranslationPosP2           : BOOL;       (* TRUE = translation en position P2 *)
    TranslationPosP1           : BOOL;       (* TRUE = translation en position P1 *)
    TranslationPosMaintenance  : BOOL;       (* TRUE = translation en position Maintenance *)
    M3BrakeFeedback            : BOOL := TRUE;   (* TRUE = frein M3 OUVERT (desserré) — polarité physique directe *)

END_VAR

VAR
    // ── [Instances de qualification FB_Input] ───────────────────────────────────────────────
    instPowerContactorEngaged     : FB_Input;
    instEmergencyChainClosed      : FB_Input;
    instTopPositionSensor         : FB_Input;
    instSlackCableSwitch          : FB_Input;
    instKoboldContactFond         : FB_Input;
    instCtrlPhaseRotation         : FB_Input;
    instBrakeThermalFeedback      : FB_Input;
    instM1FwdRevSpeedFeedbackOff  : FB_Input;
    instM1Thermal                 : FB_Input;
    instM1BrakeFeedback           : FB_Input;
    instM2FwdRevSpeedFeedbackOff  : FB_Input;
    instM2Thermal                 : FB_Input;
    instM2BrakeFeedback           : FB_Input;
    instTranslationPosTremie      : FB_Input;
    instTranslationPosPV          : FB_Input;
    instTranslationPosP2          : FB_Input;
    instTranslationPosP1          : FB_Input;
    instTranslationPosMaintenance : FB_Input;
    instM3BrakeFeedback           : FB_Input;
END_VAR

VAR CONSTANT
    CST_InputFilterTime          : TIME := T#20MS;   (* Temporisation commune anti-rebond des entrées TOR *)
END_VAR

// === IMPLEMENTATION ===

// === [PUISSANCE & SÉCURITÉ COMMUNE] ===
instPowerContactorEngaged(
    InputRaw    := HwIn.Machine.PowerContactorEngaged_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
PowerContactorEngaged := instPowerContactorEngaged.State;

instEmergencyChainClosed(
    InputRaw    := HwIn.Machine.EmergencyChainClosed_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
EmergencyChainClosed := instEmergencyChainClosed.State;

instCtrlPhaseRotation(
    InputRaw    := HwIn.Machine.PhaseRotationOk_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
PhaseRotationOk := instCtrlPhaseRotation.State;

instBrakeThermalFeedback(
    InputRaw    := HwIn.Machine.BrakeThermalOk_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
BrakeThermalFeedback := instBrakeThermalFeedback.State;

instKoboldContactFond(
    InputRaw    := HwIn.Machine.M1_M2_KoboldContactFond_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
KoboldContactFond := instKoboldContactFond.State;

// === [TREUILS M1 / M2] ===
instTopPositionSensor(
    InputRaw    := HwIn.Winch.M1M2_TopPositionFree_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TopPositionSensor := instTopPositionSensor.State;

instSlackCableSwitch(
    InputRaw    := HwIn.Winch.M2_TensionedCable_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
SlackCableSwitch := instSlackCableSwitch.State;

instM1FwdRevSpeedFeedbackOff(
    InputRaw    := HwIn.Winch.M1_ContactorsReleased_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;

instM1Thermal(
    InputRaw    := HwIn.Winch.M1_ThermalOk_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M1ThermalFeedback := instM1Thermal.State;

instM1BrakeFeedback(
    InputRaw    := HwIn.Winch.M1_BrakeIsOpen_DI,
    InvertLogic := TRUE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M1BrakeFeedback := instM1BrakeFeedback.State;  (* TRUE = frein M1 ouvert (logique physique directe) *)

instM2FwdRevSpeedFeedbackOff(
    InputRaw    := HwIn.Winch.M2_ContactorsReleased_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;

instM2Thermal(
    InputRaw    := HwIn.Winch.M2_ThermalOk_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M2ThermalFeedback := instM2Thermal.State;

instM2BrakeFeedback(
    InputRaw    := HwIn.Winch.M2_BrakeIsOpen_DI,
    InvertLogic := TRUE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M2BrakeFeedback := instM2BrakeFeedback.State;  (* TRUE = frein M2 ouvert (logique physique directe) *)

// === [TRANSLATION M3] ===
instTranslationPosTremie(
    InputRaw    := HwIn.Translation.M3_PosTremie_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TranslationPosTremie := instTranslationPosTremie.State;

instTranslationPosPV(
    InputRaw    := HwIn.Translation.M3_PosPV_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TranslationPosPV := instTranslationPosPV.State;

instTranslationPosP2(
    InputRaw    := HwIn.Translation.M3_PosP2_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TranslationPosP2 := instTranslationPosP2.State;

instTranslationPosP1(
    InputRaw    := HwIn.Translation.M3_PosP1_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TranslationPosP1 := instTranslationPosP1.State;

instTranslationPosMaintenance(
    InputRaw    := HwIn.Translation.M3_PosMaintenance_DI,
    InvertLogic := FALSE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
TranslationPosMaintenance := instTranslationPosMaintenance.State;

instM3BrakeFeedback(
    InputRaw    := HwIn.Translation.M3_BrakeIsOpen_DI,
    InvertLogic := TRUE,
    FilterTime  := CST_InputFilterTime,
    ChannelOk   := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING)
);
M3BrakeFeedback := instM3BrakeFeedback.State;  (* TRUE = frein M3 ouvert (logique physique directe) *)

(* ═══════════════════════════════════════════════════════════════
   📥 PRG_01_Inputs_LD — ACQUISITION & QUALIFICATION DES ENTRÉES (LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §1/§4
   ⚙️ Exécuté par la tâche PLC en position 1 (premier programme).
   🎯 Lit les 22 TOR réelles depuis leurs symboles bruts mappés (CSV
       Device_IO_20260729.csv), applique un filtre anti-rebond 20 ms et
       publie :
         • Qualified : ST_InputsQualified  (image qualifiée, lecteur unique
                                            PRG_02_Acquisition_CFC)
         • 14 scalaires legacy             (consommateurs historiques)
   🛡️ Polarité : le nom de chaque entrée dit ce que TRUE signifie. Seuls
       les freins portent InvertLogic := FALSE (REX 2026-08-03 : TRUE =
       frein OUVERT). Aucune autre inversion (contacts NC câblés 1 = sain).
   📄 Converti automatiquement en Ladder Diagram (<LD>) dans CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_01_Inputs_LD
VAR_OUTPUT
    Qualified : ST_InputsQualified;
    PowerContactorEngaged : BOOL;   // TRUE = contacteur de puissance engagé (NO)
    EmergencyChainClosed  : BOOL;   // TRUE = boucle AU fermée (NC, câblage 1 = sain)
    PhaseRotationOk       : BOOL;   // TRUE = rotation phases correcte (NC)
    BrakeThermalFeedback  : BOOL;   // TRUE = thermique freins M1/M2/M3 OK (NC)
    M1ThermalFeedback     : BOOL;   // TRUE = thermique M1 OK (NC)
    M2ThermalFeedback     : BOOL;   // TRUE = thermique M2 OK (NC)
    M1BrakeFeedback       : BOOL;   // TRUE = frein M1 OUVERT (desserré) — REX 2026-08-03
    M2BrakeFeedback       : BOOL;   // TRUE = frein M2 OUVERT (desserré) — REX 2026-08-03
    M3BrakeFeedback       : BOOL;   // TRUE = frein M3 OUVERT (desserré) — REX 2026-08-03
    M1FwdRevSpeedFeedbackOff : BOOL; // TRUE = contacteurs sens M1 retombés (NO)
    M2FwdRevSpeedFeedbackOff : BOOL; // TRUE = contacteurs sens M2 retombés (NO)
    TopPositionSensor     : BOOL;   // TRUE = position extrême haut libre (NC)
    SlackCableSwitch      : BOOL;   // TRUE = câble M2 tendu (NC)
    KoboldContactFond     : BOOL;   // TRUE = Kobold fond détecté (NO)
END_VAR
VAR
    instPowerContactorEngaged : FB_Input;
    instEmergencyChainClosed  : FB_Input;
    instCtrlPhaseRotation     : FB_Input;
    instBrakeThermalFeedback  : FB_Input;
    instKoboldContactFond     : FB_Input;
    instHydraulicThermalOk    : FB_Input;
    instConveyorInfeedReady   : FB_Input;
    instM1FwdRevSpeedFeedbackOff : FB_Input;
    instM1Thermal             : FB_Input;
    instM1BrakeFeedback       : FB_Input;
    instM2FwdRevSpeedFeedbackOff : FB_Input;
    instM2Thermal             : FB_Input;
    instM2BrakeFeedback       : FB_Input;
    instTopPositionSensor     : FB_Input;
    instSlackCableSwitch      : FB_Input;
    instM3BrakeFeedback       : FB_Input;
    instM3ThermalFeedback     : FB_Input;
    instTranslationPosTremie  : FB_Input;
    instTranslationPosPV      : FB_Input;
    instTranslationPosP2      : FB_Input;
    instTranslationPosP1      : FB_Input;
    instTranslationPosMaintenance : FB_Input;
END_VAR

// === IMPLEMENTATION ===

// === [MACHINE] ===
// 🔌 Contacteur de puissance géré par l'arrêt d'urgence (NO) — TRUE = engagé
instPowerContactorEngaged(InputRaw := PowerContactorEngaged_DI, FilterTime := T#20MS);
PowerContactorEngaged := instPowerContactorEngaged.State;
Qualified.Machine.PowerContactorEngaged_DI := PowerContactorEngaged;

// 🔗 Boucle d'arrêt d'urgence coup-de-poing + contact PLC (NC) — TRUE = saine
instEmergencyChainClosed(InputRaw := EmergencyChainClosed_DI, FilterTime := T#20MS);
EmergencyChainClosed := instEmergencyChainClosed.State;
Qualified.Machine.EmergencyChainClosed_DI := EmergencyChainClosed;

// ⚡ Contrôle rotation phases (NC) — TRUE = correcte
instCtrlPhaseRotation(InputRaw := PhaseRotationOk_DI, FilterTime := T#20MS);
PhaseRotationOk := instCtrlPhaseRotation.State;
Qualified.Machine.PhaseRotationOk_DI := PhaseRotationOk;

// 🌡️ Thermique freins commun M1/M2/M3 (NC) — TRUE = OK
instBrakeThermalFeedback(InputRaw := BrakeThermalOk_DI, FilterTime := T#20MS);
BrakeThermalFeedback := instBrakeThermalFeedback.State;
Qualified.Machine.BrakeThermalOk_DI := BrakeThermalFeedback;

// 🪨 Détecteur fond Kobold (NO) — TRUE = fond détecté
instKoboldContactFond(InputRaw := M1_M2_KoboldContactFond_DI, FilterTime := T#20MS);
KoboldContactFond := instKoboldContactFond.State;
Qualified.Machine.M1_M2_KoboldContactFond_DI := KoboldContactFond;

// 🌡️ Thermique moteur hydraulique (NC) — TRUE = OK
instHydraulicThermalOk(InputRaw := HydraulicThermalOk_DI, FilterTime := T#20MS);
Qualified.Machine.HydraulicThermalOk_DI := instHydraulicThermalOk.State;

// ⚙️ Autorisation démarrage crible (NO) — TRUE = autorisé
instConveyorInfeedReady(InputRaw := ConveyorInfeedReady_DI, FilterTime := T#20MS);
Qualified.Machine.ConveyorInfeedReady_DI := instConveyorInfeedReady.State;

// === [WINCH] ===
// 📡 Contacteurs sens M1 relâchés (NO) — TRUE = retombés
instM1FwdRevSpeedFeedbackOff(InputRaw := M1_ContactorsReleased_DI, FilterTime := T#20MS);
M1FwdRevSpeedFeedbackOff := instM1FwdRevSpeedFeedbackOff.State;
Qualified.Winch.M1_ContactorsReleased_DI := M1FwdRevSpeedFeedbackOff;

// 🌡️ Thermique moteur M1 (NC) — TRUE = OK
instM1Thermal(InputRaw := M1_ThermalOk_DI, FilterTime := T#20MS);
M1ThermalFeedback := instM1Thermal.State;
Qualified.Winch.M1_ThermalOk_DI := M1ThermalFeedback;

// 🔒 Retour frein M1 — REX 2026-08-03 : InvertLogic := FALSE, TRUE = frein OUVERT
instM1BrakeFeedback(InputRaw := M1_BrakeIsOpen_DI, InvertLogic := FALSE, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;
Qualified.Winch.M1_BrakeIsOpen_DI := M1BrakeFeedback;

// 📡 Contacteurs sens M2 relâchés (NO) — TRUE = retombés
instM2FwdRevSpeedFeedbackOff(InputRaw := M2_ContactorsReleased_DI, FilterTime := T#20MS);
M2FwdRevSpeedFeedbackOff := instM2FwdRevSpeedFeedbackOff.State;
Qualified.Winch.M2_ContactorsReleased_DI := M2FwdRevSpeedFeedbackOff;

// 🌡️ Thermique moteur M2 (NC) — TRUE = OK
instM2Thermal(InputRaw := M2_ThermalOk_DI, FilterTime := T#20MS);
M2ThermalFeedback := instM2Thermal.State;
Qualified.Winch.M2_ThermalOk_DI := M2ThermalFeedback;

// 🔒 Retour frein M2 — REX 2026-08-03 : InvertLogic := FALSE, TRUE = frein OUVERT
instM2BrakeFeedback(InputRaw := M2_BrakeIsOpen_DI, InvertLogic := FALSE, FilterTime := T#20MS);
M2BrakeFeedback := instM2BrakeFeedback.State;
Qualified.Winch.M2_BrakeIsOpen_DI := M2BrakeFeedback;

// 🔝 Fin de course position extrême haut (NC) — TRUE = libre, déclenche AU
instTopPositionSensor(InputRaw := M1M2_TopPositionFree_DI, FilterTime := T#20MS);
TopPositionSensor := instTopPositionSensor.State;
Qualified.Winch.M1M2_TopPositionFree_DI := TopPositionSensor;

// 🔗 Capteur mou de câble M2 (NC) — TRUE = câble tendu
instSlackCableSwitch(InputRaw := M2_TensionedCable_DI, FilterTime := T#20MS);
SlackCableSwitch := instSlackCableSwitch.State;
Qualified.Winch.M2_TensionedCable_DI := SlackCableSwitch;

// === [TRANSLATION] ===
// 🔒 Retour frein M3 — REX 2026-08-03 : InvertLogic := FALSE, TRUE = frein OUVERT
instM3BrakeFeedback(InputRaw := M3_BrakeIsOpen_DI, InvertLogic := FALSE, FilterTime := T#20MS);
M3BrakeFeedback := instM3BrakeFeedback.State;
Qualified.Translation.M3_BrakeIsOpen_DI := M3BrakeFeedback;

// 🌡️ Thermique moteur M3 (NC) — TRUE = OK
instM3ThermalFeedback(InputRaw := M3_ThermalFeedback_DI, FilterTime := T#20MS);
Qualified.Translation.M3_ThermalFeedback_DI := instM3ThermalFeedback.State;

// 🏭 Capteurs de position chariot M3 (NO) — TRUE = position atteinte
instTranslationPosTremie(InputRaw := M3_PosTremie_DI, FilterTime := T#20MS);
Qualified.Translation.M3_PosTremie_DI := instTranslationPosTremie.State;

instTranslationPosPV(InputRaw := M3_PosPV_DI, FilterTime := T#20MS);
Qualified.Translation.M3_PosPV_DI := instTranslationPosPV.State;

instTranslationPosP2(InputRaw := M3_PosP2_DI, FilterTime := T#20MS);
Qualified.Translation.M3_PosP2_DI := instTranslationPosP2.State;

instTranslationPosP1(InputRaw := M3_PosP1_DI, FilterTime := T#20MS);
Qualified.Translation.M3_PosP1_DI := instTranslationPosP1.State;

instTranslationPosMaintenance(InputRaw := M3_PosMaintenance_DI, FilterTime := T#20MS);
Qualified.Translation.M3_PosMaintenance_DI := instTranslationPosMaintenance.State;

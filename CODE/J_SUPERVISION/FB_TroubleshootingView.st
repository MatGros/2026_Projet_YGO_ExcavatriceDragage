(* ═══════════════════════════════════════════════════════════════
   🕵️♂️ FB_TroubleshootingView — Mise en forme lecture seule pour dépannage
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.2.md
   🔗 Producteur unique de GVL_Troubleshooting.* — instancié UNE SEULE FOIS,
      dans PRG_07_Supervision, après §3 Projections IHM.
   🔒 Lecture seule stricte : aucune VAR_OUTPUT de commande, aucun calcul métier,
      aucune fusion de source — pure recopie de faits déjà publiés ailleurs.
   ⚠️ WinchM2 est typé ST_WinchBenneHMI (pas ST_WinchHMI comme WinchM1) : ce lot
      (LOT_TROUBLESHOOTING_VIEW_ET_WINCHHMI) a introduit ST_WinchBenneHMI pour porter
      Bucket côté M2 uniquement (GVL_IHM.M2TreuilBenne) — adaptation du port fiche §3
      nécessaire suite à AC5 (Bucket retiré de ST_WinchHMI commun M1/M2).
   Écriture GVL directe : seule exception au principe "pas de GVL comme bus de
      commande" (AF_Partie-03 §5) — GVL_Troubleshooting n'est jamais relue par un FB
      métier, uniquement par Watch CODESYS / export SCADA dépannage (fiche §3/§7).
   ⚠️ Idx201_JoystickSelected (ContexteMachineGlobal) lit GVL_IHM.Modes.Cmd.TglJoystickMaster
      directement (variable globale IEC 61131-3, visible sans passage par VAR_INPUT) — ce
      port n'est pas dans la table fiche §3 mais le producteur exact est documenté fiche §5.1.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_TroubleshootingView
VAR_INPUT
    Enable                   : BOOL; (* --> [CMD] TRUE en permanence — fiche §3, aucune condition de scan *)

    (* 📡 PRG_02_Acquisition *)
    HwIn                     : ST_HardwareImage;   (* --> [HW] Image entrées qualifiées *)
    HwReal                   : ST_HardwareImage;   (* --> [HW] Image entrées réelles *)
    InputModuleFault         : BOOL;   (* --> [HW] Défaut module d'entrée *)
    LocalDigitalIoOk         : BOOL; (* --> [HW] Mirroir Network.InputModules — pas de champ ST_Chain* dédié ce lot *)
    Vh0800EndOk              : BOOL; (* --> [HW] idem *)
    Vh0808EtpOk              : BOOL; (* --> [HW] idem *)

    (* 🎚️ PRG_03_Modes_Cycle *)
    Auth                     : ST_Modes_Autorisations;   (* --> [SAFE] Autorisations machine *)

    (* 🛗 PRG_04_Treuils_Benne — demandes publiques déjà arbitrées *)
    M1LogicRequestSpeedCmd_Pct : REAL;   (* --> [CMD] Consigne vitesse M1 *)
    M1LogicRequestDirection    : INT;   (* --> [CMD] Sens M1 *)
    M2LogicRequestSpeedCmd_Pct : REAL;   (* --> [CMD] Consigne vitesse M2 *)
    M2LogicRequestDirection    : INT;   (* --> [CMD] Sens M2 *)
    WinchBothMotionDirection : INT;   (* --> [CMD] Direction couplée *)
    WinchBothMotionActive    : BOOL;   (* --> [CMD] Demande couplée active *)
    CycleAutoBusy                : BOOL;   (* --> [HW] Cycle auto actif *)
    CycleM1SpeedTgt_Pct          : REAL;   (* --> [CMD] Consigne cycle M1 *)
    CycleM2SpeedTgt_Pct          : REAL;   (* --> [CMD] Consigne cycle M2 *)
    CycleBucketOpen              : BOOL;   (* --> [HW] Benne ouverte cycle *)
    CycleTargetPosition          : INT;   (* --> [CMD] Cible cycle *)

    (* 🎭 GVL_Simulation *)
    SimulationModeActive     : BOOL;   (* --> [TST] Mode simulation *)
    SimWinchActive           : BOOL;   (* --> [TST] Sim treuils *)
    SimTranslationActive     : BOOL;   (* --> [TST] Sim translation *)
    SimOperatorActive        : BOOL;   (* --> [TST] Sim opérateur *)
    SimSafetyActive          : BOOL;   (* --> [TST] Sim sécurité *)

    (* 🛗 GVL_IHM — images publiques déjà produites *)
    WinchM1                  : ST_WinchHMI;      (* --> [HW] GVL_IHM.M1TreuilRetenue *)
    WinchM2                  : ST_WinchBenneHMI; (* --> [HW] GVL_IHM.M2TreuilBenne — porte Bucket *)
    Sync                     : ST_SyncHMI;       (* --> [HW] GVL_IHM.M1M2Sync *)
    Translation              : ST_TranslationHMI;(* --> [HW] GVL_IHM.TranslationM3 *)
    Commun                   : ST_CommunHMI;     (* --> [HW] GVL_IHM.Commun *)
    Network                  : ST_NetworkDiagHMI;(* --> [HW] GVL_IHM.Network *)
    DredgingAssist           : ST_DredgingAssistHMI; (* --> [HW] GVL_IHM.DredgingAssist *)
    JoystickHMI              : ST_JoystickHMI;   (* --> [HW] GVL_IHM.JOY1Joystick *)

    (* 🛡️ Sorties publiques AU produites par PRG_06_Outputs *)
    EmergencyState           : ST_Safety_Emergency_State;   (* --> [SAFE] État AU *)
    EmergencyDiag            : ST_Safety_Emergency_Diag;   (* --> [SAFE] Diagnostic AU *)
    PowerCutOffActive        : BOOL;   (* --> [SAFE] Coupure puissance *)
    ArmingPulseActive        : BOOL;   (* --> [SAFE] Impulsion réarmement *)
    MaintainAActive          : BOOL;   (* --> [SAFE] Maintien canal A *)
    MaintainBActive          : BOOL;   (* --> [SAFE] Maintien canal B *)

    (* 🔄 Séquenceur de cycle semi-automatique *)
    CycleReady               : BOOL;   (* --> [STAT] Séquenceur prêt *)
    CycleDone                : BOOL;   (* --> [STAT] Séquenceur terminé *)
    CycleError               : BOOL;   (* --> [STAT] Séquenceur en erreur *)
    CycleErrorId             : WORD;   (* --> [DIAG] Code erreur séquenceur *)
    CycleStep                : E_CycleStep; (* --> [STAT] Étape courante *)
    CycleStepStr             : STRING(80);  (* --> [STAT] Libellé étape *)
    CycleStepAtError         : E_CycleStep; (* --> [DIAG] Étape au défaut *)
    CycleWaitingForOperator  : BOOL;        (* --> [STAT] Attente action humaine *)
    CycleWaitingForProcess   : BOOL;        (* --> [STAT] Attente condition procédé *)
    CycleOperatorActionId    : WORD;        (* --> [DIAG] ID action attendue *)
    CycleOperatorAction      : STRING(120); (* --> [DIAG] Consigne explicite *)
    CycleExpectedAxis        : E_OperatorAxis; (* --> [STAT] Organe attendu *)
    CycleExpectedDirection   : INT;         (* --> [STAT] Sens attendu (-1, 0, +1) *)
    CycleStartRequest        : BOOL;   (* --> [CMD] Demande Start *)
    CycleAbortRequest        : BOOL;   (* --> [CMD] Demande Abort *)
    CycleTargetDepth_M       : REAL;   (* --> [CFG] Profondeur consigne *)
    CycleKoboldBottomTouch   : BOOL;   (* --> [HW] Contact fond *)
    CycleSpeedMismatchActive : BOOL;   (* --> [DIAG] Écart vitesse M1/M2 *)
    CycleLimitLegalReached   : BOOL;   (* --> [SAFE] Limite légale atteinte *)
    CycleWinchSyncError      : BOOL;   (* --> [SAFE] Erreur synchro treuils *)
    JoystickDeadmanArmed     : BOOL;   (* --> [CMD] Homme-mort armé *)
    JoystickAtNeutral        : BOOL;   (* --> [HW] Joystick au neutre *)
    HomedM1                  : BOOL;   (* --> [HW] Codeur M1 référencé *)
    HomedM2                  : BOOL;   (* --> [HW] Codeur M2 référencé *)

    (* 📐 Config effective limite haute — source _CommunCfgPersist (≠ copie IHM) *)
    CfgTopLimitM             : REAL;   (* --> [CFG] Limite haute active (m) = CfgCableLimitAscent_M *)

    (* 🕵️ PRG_04/05 — Trace de blocage terrain (cause priorisée + horodatage, produite
       par PRG_04 §8bis / PRG_05 §4bis, publiée via Data ; pure recopie ici) *)
    WinchM1Trace             : ST_TraceWinch;       (* --> [DIAG] Trace blocage treuil M1 *)
    WinchM2Trace             : ST_TraceWinch;       (* --> [DIAG] Trace blocage treuil M2 *)
    TranslationTrace         : ST_TraceTranslation; (* --> [DIAG] Trace blocage translation M3 *)
END_VAR
VAR_OUTPUT
    Ready                    : BOOL; (* <-- [STAT] Diagnostic interne minimal — fiche §3 *)
END_VAR

// 🛑 GATE — neutralisation ; aucune écriture GVL_Troubleshooting si Enable=FALSE
IF NOT Enable THEN
    Ready := FALSE;
    RETURN;
END_IF;
Ready := TRUE;

{region "§0 Contexte machine global"}
// === 🌐 0. ContexteMachineGlobal : ST_ChainContextGlobal (fiche §5.1) ===
GVL_Troubleshooting.ContexteMachineGlobal.Idx101_ModeActive        := Auth.Mode;
GVL_Troubleshooting.ContexteMachineGlobal.Idx102_SimulationEnabled := SimulationModeActive;
GVL_Troubleshooting.ContexteMachineGlobal.Idx103_JoystickCommOk    := Network.Joystick.Operational;
GVL_Troubleshooting.ContexteMachineGlobal.Idx201_JoystickSelected  := GVL_IHM.Modes.Cmd.TglJoystickMaster;
GVL_Troubleshooting.ContexteMachineGlobal.Idx202_BypassNetworkGlobal := Network.Bypass.Global;
GVL_Troubleshooting.ContexteMachineGlobal.Idx203_BypassSensorsGlobal := FALSE; // TBD non câblé - voir fiche §6 (agrégat multi-domaine à définir)
GVL_Troubleshooting.ContexteMachineGlobal.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.ContexteMachineGlobal.Idx302_PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI;
// Agrégat simple OR de faits déjà publiés (fiche §5.1) — pas un nouveau calcul métier
GVL_Troubleshooting.ContexteMachineGlobal.Idx303_SafeStopActiveAny := WinchM1.Safety.SafeStop OR WinchM2.Safety.SafeStop OR Translation.Safety.SafeStop;
GVL_Troubleshooting.ContexteMachineGlobal.Idx304_PowerCutOffActiveAny := WinchM1.Safety.PowerCutOff OR WinchM2.Safety.PowerCutOff OR Translation.Safety.PowerCutOff;
GVL_Troubleshooting.ContexteMachineGlobal.Idx401_HmiHeartbeatOk    := Commun.HeartbeatIhmOk;
GVL_Troubleshooting.ContexteMachineGlobal.Idx402_CycleAutoBusy     := CycleAutoBusy;

{endregion}

{region "§1 Levage synchronise M1/M2"}
// === 🛗 1. LevageSynchroniseM1M2 : ST_ChainWinchSync (fiche §5.2) ===
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx101_M1_CablePos_M  := WinchM1.State.Position_M;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx102_M2_CablePos_M  := WinchM2.State.Position_M;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx103_SyncDelta_M    := Sync.State.DeltaPos_M;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM := Sync.Cmd.SelSyncEnable;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx302_SyncFaultActive := Sync.State.Error;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx303_M1_AscentPermit := WinchM1.Safety.AscentPermit;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx304_M2_AscentPermit := WinchM2.Safety.AscentPermit;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx501_M1_CmdRelayFwd_DQ := WinchM1.State.RelayFwd;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx502_M2_CmdRelayFwd_DQ := WinchM2.State.RelayFwd;
// Idx201_JoyYRaw_Pct / Idx203_ArbitratedSpeed_Pct / Idx303-304_AscentPermit / Idx401_SyncMotionAllowed /
// Idx402-403_SetpointSpeed : non câblés — fiche §5.2 "(reste) champs à revoir un par un", laissés à
// leur valeur d'initialisation, pas de calcul inventé (fiche §7).

{endregion}

{region "§2 Levage unitaire M1/M2"}
// === 🛗 2. LevageUnitaireM1 / LevageUnitaireM2 : ST_ChainWinch (fiche §5.3) ===
// --- M1 ---
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx101_EncoderRawPos := UDINT_TO_DINT(HwIn.Winch.COD1_PosValue);
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx102_CablePos_M := WinchM1.State.Position_M;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx103_ContactorsReleased_DI := HwIn.Winch.M1_ContactorsReleased_DI;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx104_BrakeApplied := NOT HwIn.Winch.M1_BrakeIsOpen_DI;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx105_ThermalOk_DI := HwIn.Winch.M1_ThermalOk_DI;

GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx201_JoyRawPhysical_ANA := HwIn.Operator.JoyYRaw_ANA2;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx202_JoyScaledPhysical_Pct := JoystickHMI.State.AxisCmdY.Deflection;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx203_HmiManualCmd_BtnAscent := WinchM1.Cmd.BtnAscent;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx204_HmiManualCmd_BtnDescent := WinchM1.Cmd.BtnDescent;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx205_CycleAutoCmd_Pct := CycleM1SpeedTgt_Pct;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx206_ModeActive := Auth.Mode;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx207_BypassOperatorComm := WinchM1.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx208_ArbitratedSpeed_Pct := M1LogicRequestSpeedCmd_Pct;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx209_ArbitratedDirection := M1LogicRequestDirection;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx210_CoupledUserRequestDirection := WinchBothMotionDirection;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx211_CoupledUserRequestActive := WinchBothMotionActive;

GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx302_SafeStopActive := WinchM1.Safety.SafeStop;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx303_PowerCutOffActive := WinchM1.Safety.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx304_TopSensorPhysical_DI := HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx305_TopSensorBypassActive := Commun.SimTopSensorBypassActive;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx306_AscentPermitEffective := WinchM1.Safety.AscentPermit;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI := FALSE; // TBD non câblé - voir fiche §6 (capteur mou de câble présent uniquement côté M2 dans ST_HwWinch)
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx308_SlackCableBypassActive := Commun.SimSlackCableBypassActive;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx309_DescendPermitEffective := WinchM1.Safety.DescendPermit;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx310_ErrorOperatorComm := WinchM1.Safety.ErrorOperatorComm;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx311_ErrorEncoder      := WinchM1.Safety.ErrorEncoder;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx312_ErrorPhaseRotation:= WinchM1.Safety.ErrorPhaseRotation;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx313_ErrorMecaA        := WinchM1.Safety.ErrorMecaA;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx314_ErrorMecaB        := WinchM1.Safety.ErrorMecaB;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx315_ErrorMecaC        := WinchM1.Safety.ErrorMecaC;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx316_ErrorMecaD        := WinchM1.Safety.ErrorMecaD;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx317_ErrorMecaE        := WinchM1.Safety.ErrorMecaE;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx318_ErrorBrakeThermal := WinchM1.Safety.ErrorBrakeThermal;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx319_ErrorOppositeDir  := WinchM1.Safety.ErrorOppositeDir;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx320_ErrorNoMovement   := WinchM1.Safety.ErrorNoMovement;
// ⛔ Bloc "limite haute" — pourquoi la montée ne s'arrête pas (M1)
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx321_CfgTopLimitM               := CfgTopLimitM;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx322_CablePosM                  := WinchM1.State.Position_M;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx323_TopLimitReached            := (WinchM1.State.Position_M >= CfgTopLimitM) AND NOT WinchM1.State.Encoder.HomingBusy;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx324_AscentBlockedByTopLimit    := (WinchM1.State.Position_M >= CfgTopLimitM) AND NOT WinchM1.State.Encoder.HomingBusy AND NOT (WinchM1.Bypass.TopLimitSoftware OR Commun.Bypass.TopLimitSoftware);
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx325_BypassTopLimitSoftware     := WinchM1.Bypass.TopLimitSoftware;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx326_BypassTopLimitSoftCommun   := Commun.Bypass.TopLimitSoftware;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx327_BypassTopLimitSwitch       := WinchM1.Bypass.TopLimitSwitch;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx328_BypassTopLimitSwitchCommun := Commun.Bypass.TopLimitSwitch;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx329_BypassGlobal               := WinchM1.Bypass.Global;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx330_BypassGlobalCommun         := Commun.Bypass.Global;

GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx401_MotionAllowed := WinchM1.State.Ready;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx402_SpeedStepCalculated := WinchM1.State.StepNumber;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx403_SpeedRamp_Pct := WinchM1.State.SpeedCmd_Pct;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx404_BrakeReleaseAuthorized := WinchM1.State.BrakeCmd;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx405_FinalInterlockState := WinchM1.State.FinalInterlockState;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx406_FinalInterlockReason := WinchM1.State.FinalInterlockReason;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx407_FinalAuthorizedStep := WinchM1.State.FinalAuthorizedStep;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx408_BrakeCommandOpenConfirmed := WinchM1.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx409_BrakeTimeoutElapsed := WinchM1.State.FinalBrakeTimeoutElapsed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx410_RestartDelayElapsed := WinchM1.State.FinalRestartDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx411_StepDelayElapsed := WinchM1.State.FinalStepDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx412_InTopSlowdownZone := WinchM1.State.InTopSlowdownZone;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx413_InBottomSlowdownZone := WinchM1.State.InBottomSlowdownZone;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx414_BottomLimitActiveM := WinchM1.State.BottomLimitActiveM;

GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx501_CmdRelayAscent_DQ := WinchM1.State.RelayFwd;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx502_CmdRelayDescent_DQ := WinchM1.State.RelayRev;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx503_CmdSpeedContactor1_DQ := WinchM1.State.Contactor1;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx504_CmdSpeedContactor4_DQ := WinchM1.State.Contactor4;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx505_CmdBrakeRelease_RQ := WinchM1.State.BrakeCmd;

// --- M2 (même patron, source WinchM2) ---
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx101_EncoderRawPos := UDINT_TO_DINT(HwIn.Winch.COD2_PosValue);
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx102_CablePos_M := WinchM2.State.Position_M;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx103_ContactorsReleased_DI := HwIn.Winch.M2_ContactorsReleased_DI;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx104_BrakeApplied := NOT HwIn.Winch.M2_BrakeIsOpen_DI;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx105_ThermalOk_DI := HwIn.Winch.M2_ThermalOk_DI;

GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx201_JoyRawPhysical_ANA := HwIn.Operator.JoyYRaw_ANA2;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx202_JoyScaledPhysical_Pct := JoystickHMI.State.AxisCmdY.Deflection;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx203_HmiManualCmd_BtnAscent := WinchM2.Cmd.BtnAscent;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx204_HmiManualCmd_BtnDescent := WinchM2.Cmd.BtnDescent;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx205_CycleAutoCmd_Pct := CycleM2SpeedTgt_Pct;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx206_ModeActive := Auth.Mode;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx207_BypassOperatorComm := WinchM2.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx208_ArbitratedSpeed_Pct := M2LogicRequestSpeedCmd_Pct;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx209_ArbitratedDirection := M2LogicRequestDirection;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx210_CoupledUserRequestDirection := WinchBothMotionDirection;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx211_CoupledUserRequestActive := WinchBothMotionActive;

GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx302_SafeStopActive := WinchM2.Safety.SafeStop;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx303_PowerCutOffActive := WinchM2.Safety.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx304_TopSensorPhysical_DI := HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx305_TopSensorBypassActive := Commun.SimTopSensorBypassActive;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx306_AscentPermitEffective := WinchM2.Safety.AscentPermit;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx307_SlackCablePhysical_DI := HwIn.Winch.M2_TensionedCable_DI;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx308_SlackCableBypassActive := Commun.SimSlackCableBypassActive;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx309_DescendPermitEffective := WinchM2.Safety.DescendPermit;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx310_ErrorOperatorComm := WinchM2.Safety.ErrorOperatorComm;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx311_ErrorEncoder      := WinchM2.Safety.ErrorEncoder;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx312_ErrorPhaseRotation:= WinchM2.Safety.ErrorPhaseRotation;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx313_ErrorMecaA        := WinchM2.Safety.ErrorMecaA;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx314_ErrorMecaB        := WinchM2.Safety.ErrorMecaB;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx315_ErrorMecaC        := WinchM2.Safety.ErrorMecaC;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx316_ErrorMecaD        := WinchM2.Safety.ErrorMecaD;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx317_ErrorMecaE        := WinchM2.Safety.ErrorMecaE;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx318_ErrorBrakeThermal := WinchM2.Safety.ErrorBrakeThermal;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx319_ErrorOppositeDir  := WinchM2.Safety.ErrorOppositeDir;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx320_ErrorNoMovement   := WinchM2.Safety.ErrorNoMovement;
// ⛔ Bloc "limite haute" — pourquoi la montée ne s'arrête pas (M2, sans M2_LimitShift ici)
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx321_CfgTopLimitM               := CfgTopLimitM;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx322_CablePosM                  := WinchM2.State.Position_M;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx323_TopLimitReached            := (WinchM2.State.Position_M >= CfgTopLimitM) AND NOT WinchM2.State.Encoder.HomingBusy;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx324_AscentBlockedByTopLimit    := (WinchM2.State.Position_M >= CfgTopLimitM) AND NOT WinchM2.State.Encoder.HomingBusy AND NOT (WinchM2.Bypass.TopLimitSoftware OR Commun.Bypass.TopLimitSoftware);
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx325_BypassTopLimitSoftware     := WinchM2.Bypass.TopLimitSoftware;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx326_BypassTopLimitSoftCommun   := Commun.Bypass.TopLimitSoftware;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx327_BypassTopLimitSwitch       := WinchM2.Bypass.TopLimitSwitch;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx328_BypassTopLimitSwitchCommun := Commun.Bypass.TopLimitSwitch;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx329_BypassGlobal               := WinchM2.Bypass.Global;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx330_BypassGlobalCommun         := Commun.Bypass.Global;

GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx401_MotionAllowed := WinchM2.State.Ready;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx402_SpeedStepCalculated := WinchM2.State.StepNumber;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx403_SpeedRamp_Pct := WinchM2.State.SpeedCmd_Pct;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx404_BrakeReleaseAuthorized := WinchM2.State.BrakeCmd;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx405_FinalInterlockState := WinchM2.State.FinalInterlockState;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx406_FinalInterlockReason := WinchM2.State.FinalInterlockReason;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx407_FinalAuthorizedStep := WinchM2.State.FinalAuthorizedStep;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx408_BrakeCommandOpenConfirmed := WinchM2.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx409_BrakeTimeoutElapsed := WinchM2.State.FinalBrakeTimeoutElapsed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx410_RestartDelayElapsed := WinchM2.State.FinalRestartDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx411_StepDelayElapsed := WinchM2.State.FinalStepDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx412_InTopSlowdownZone := WinchM2.State.InTopSlowdownZone;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx413_InBottomSlowdownZone := WinchM2.State.InBottomSlowdownZone;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx414_BottomLimitActiveM := WinchM2.State.BottomLimitActiveM;

GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx501_CmdRelayAscent_DQ := WinchM2.State.RelayFwd;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx502_CmdRelayDescent_DQ := WinchM2.State.RelayRev;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx503_CmdSpeedContactor1_DQ := WinchM2.State.Contactor1;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx504_CmdSpeedContactor4_DQ := WinchM2.State.Contactor4;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx505_CmdBrakeRelease_RQ := WinchM2.State.BrakeCmd;

{endregion}

{region "§3 Benne ouverture et fermeture"}
// === 🪣 3. BenneOuvertureFermeture : ST_ChainBucket (fiche §5.4, source WinchM2.Bucket) ===
GVL_Troubleshooting.BenneOuvertureFermeture.Idx101_BucketIsOpen := WinchM2.Bucket.State.MechState.IsOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx102_BucketIsClosed := WinchM2.Bucket.State.MechState.IsClosed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx103_OffsetPos_M := WinchM2.Bucket.State.ActiveOffset_M;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx104_AutoSeqActive := WinchM2.Bucket.State.AutoBucketSeqActive;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx105_StateIncoherent := WinchM2.Bucket.State.MechState.StateIncoherent;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx106_FBState := WinchM2.Bucket.State.FBState;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx107_LastPosM2Open_M := WinchM2.Bucket.State.MechState.LastPosM2Open;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx108_LastPosM2Close_M := WinchM2.Bucket.State.MechState.LastPosM2Close;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx109_BucketTooOpen := WinchM2.Bucket.State.MechState.TooOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx110_BucketTooClosed := WinchM2.Bucket.State.MechState.TooClosed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx111_BucketIsIntermediate := WinchM2.Bucket.State.MechState.IsIntermediate;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx112_DeltaPosition_M := WinchM2.Bucket.State.DeltaPosition_M;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx113_MachineHomed := WinchM2.Bucket.State.MachineHomed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx114_MachineHomingStep := WinchM2.Bucket.State.MachineHomingStep;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx115_MachineHomingFailed := WinchM2.Bucket.State.MachineHomingFailed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx116_M1ReferenceMissing := NOT WinchM1.State.Encoder.Homed OR WinchM1.State.Encoder.HomingSuspect;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx117_M2ReferenceMissing := NOT WinchM2.State.Encoder.Homed OR WinchM2.State.Encoder.HomingSuspect;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx118_BucketOffsetUnknown := NOT WinchM2.Bucket.State.MechState.ActiveOffsetValid;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx119_ReferenceTransaction := WinchM2.Bucket.State.MachineHomingActive;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx120_MachineHomingLossSafeStop := WinchM2.Bucket.State.MachineHomingLossSafeStop;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx201_HmiCmd_BtnOpen := WinchM2.Bucket.Cmd.BtnOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx202_HmiCmd_BtnClose := WinchM2.Bucket.Cmd.BtnClose;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx203_CycleCmd_Open := CycleBucketOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx204_CoupledDiveOpenArmed := WinchM2.Bucket.State.CoupledDiveOpenArmed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx205_CoupledAscentCloseArmed := WinchM2.Bucket.State.CoupledAscentCloseArmed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx206_CloseReqActive := WinchM2.Bucket.State.CloseActive;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx207_OpenReqActive := WinchM2.Bucket.State.OpenActive;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx208_MotionBlockedByBucket := WinchM2.Bucket.State.CoupledMotionBlockedByBucket;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx302_BucketFaultActive := WinchM2.Bucket.State.Error;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx303_KoboldAutoStopEnabled := Commun.Cfg.TglEnableKoboldAutoStopDescent;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx304_KoboldImmersionConfirmed := Commun.KoboldImmersionConfirmed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx305_KoboldBottomTouchLatched := Commun.KoboldBottomTouchLatched;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx306_ErrorIdRaw := WinchM2.Bucket.State.ErrorId;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx401_BucketBusy := WinchM2.Bucket.State.Busy;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx402_BucketDone := WinchM2.Bucket.State.Done;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx403_ExtractionControlActive := WinchM2.Bucket.State.ExtractionControlActive;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx501_M2_CmdRev_DQ := FALSE; // TBD non câblé - voir fiche §6 (pas de DQ relais benne dédié publié, benne pilote M2_StartStop/M2_Direction, pas un relais propre)

{endregion}

{region "§4 Assistance dragage"}
// === 🌊 5bis. AssistanceDragage : ST_ChainDredgingAssist ===
GVL_Troubleshooting.AssistanceDragage.Idx101_EnableDiveSearch         := DredgingAssist.Cmd.TglEnableDiveSearch;
GVL_Troubleshooting.AssistanceDragage.Idx102_EnableExtractionSequence := DredgingAssist.Cmd.TglEnableExtractionSequence;
GVL_Troubleshooting.AssistanceDragage.Idx103_EnableDumpAtTremie       := DredgingAssist.Cmd.TglEnableDumpAtTremie;

GVL_Troubleshooting.AssistanceDragage.Idx201_DiveReady               := DredgingAssist.State.DiveReady;
GVL_Troubleshooting.AssistanceDragage.Idx202_DiveBusy                := DredgingAssist.State.DiveBusy;
GVL_Troubleshooting.AssistanceDragage.Idx203_DiveDone                := DredgingAssist.State.DiveDone;
GVL_Troubleshooting.AssistanceDragage.Idx204_DiveState                := DredgingAssist.State.DiveState;
GVL_Troubleshooting.AssistanceDragage.Idx205_DiveError                := DredgingAssist.State.DiveError;
GVL_Troubleshooting.AssistanceDragage.Idx206_DiveErrorId              := DredgingAssist.State.DiveErrorId;
GVL_Troubleshooting.AssistanceDragage.Idx207_BottomTouchConfirmed    := DredgingAssist.State.BottomTouchConfirmed;
GVL_Troubleshooting.AssistanceDragage.Idx208_DiveStepAtFault          := DredgingAssist.State.DiveStepAtFault;

GVL_Troubleshooting.AssistanceDragage.Idx301_ExtractionReady          := DredgingAssist.State.ExtractionReady;
GVL_Troubleshooting.AssistanceDragage.Idx302_ExtractionBusy           := DredgingAssist.State.ExtractionBusy;
GVL_Troubleshooting.AssistanceDragage.Idx303_ExtractionDone           := DredgingAssist.State.ExtractionDone;
GVL_Troubleshooting.AssistanceDragage.Idx304_ExtractionState          := DredgingAssist.State.ExtractionState;
GVL_Troubleshooting.AssistanceDragage.Idx305_ExtractionError          := DredgingAssist.State.ExtractionError;
GVL_Troubleshooting.AssistanceDragage.Idx306_ExtractionErrorId        := DredgingAssist.State.ExtractionErrorId;
GVL_Troubleshooting.AssistanceDragage.Idx307_ExtractionStepAtFault    := DredgingAssist.State.ExtractionStepAtFault;

GVL_Troubleshooting.AssistanceDragage.Idx401_OperatorActionId        := DredgingAssist.State.OperatorActionId;
GVL_Troubleshooting.AssistanceDragage.Idx402_OperatorAction          := DredgingAssist.State.OperatorAction;

GVL_Troubleshooting.AssistanceDragage.Idx501_DumpAtTremieArmed          := DredgingAssist.State.DumpAtTremieArmed;
GVL_Troubleshooting.AssistanceDragage.Idx502_DumpAtTremieAssistActive   := DredgingAssist.State.DumpAtTremieAssistActive;
GVL_Troubleshooting.AssistanceDragage.Idx503_DumpAtTremieAtTremie       := DredgingAssist.State.DumpAtTremieAtTremie;
GVL_Troubleshooting.AssistanceDragage.Idx504_DumpAtTremieBucketOpenArmed := DredgingAssist.State.DumpAtTremieBucketOpenArmed;
GVL_Troubleshooting.AssistanceDragage.Idx505_DumpAtTremieDescentLocked := DredgingAssist.State.DumpAtTremieDescentLocked;

GVL_Troubleshooting.AssistanceDragage.Idx601_BypassDiveActive          := DredgingAssist.State.BypassDiveActive;
GVL_Troubleshooting.AssistanceDragage.Idx602_BypassKoboldBottomTouched := DredgingAssist.State.BypassKoboldBottomTouched;

{endregion}

{region "§5 Translation pont M3"}
// === ↔️ 4. TranslationPontM3 : ST_ChainTranslation (fiche §5.5, source Translation) ===
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx101_PosTremie_DI := Translation.State.PositionTremie;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx102_PosPV_DI := Translation.State.PositionPV;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx103_PosP2_DI := Translation.State.PositionP2;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx104_PosP1_DI := Translation.State.PositionP1;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI := Translation.State.PositionMaintenance;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz := Translation.State.DriveActualFreq_Hz;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx107_DriveStatusWord := HwIn.Translation.M3_StatusWord;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx108_BrakeApplied := NOT Translation.State.BrakeFeedback;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx109_DriveThermalOk := Translation.State.DriveThermalOk;

GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx201_JoyXRaw_ANA := HwIn.Operator.JoyXRaw_ANA1;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx202_JoyXScaled_Pct := GVL_IHM.JOY1Joystick.State.AxisCmdX.Deflection;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx203_HmiCmd_BtnTremie := Translation.Cmd.BtnTremie;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx204_HmiCmd_BtnMaintenance := Translation.Cmd.BtnMaintenance;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx205_HmiTargetPosition := Translation.Cmd.SelTarget;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx206_CycleTargetPosition := CycleTargetPosition;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx207_ModeActive := Auth.Mode;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx208_BypassNetworkActive := Translation.Bypass.Global;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx209_ArbitratedSpeed_Pct := Translation.State.SpeedCmd_Pct;

GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx301_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx302_SafeStopActive := Translation.Safety.SafeStop;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx303_PowerCutOffActive := Translation.Safety.PowerCutOff;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx304_LimitSwitchTremieActive := Translation.State.LimitSwitchTremie;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx305_LimitSwitchMaintenanceActive := Translation.State.LimitSwitchMaintenance;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx306_BypassLimitSwitch := Translation.Bypass.LimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx307_PositionDecoderIncoherent := Translation.State.SensorWordIncoherent;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx308_HeightInterlockBlocking := Translation.State.HeightInterlockBlocking;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx309_ErrorOperatorComm := Translation.Safety.ErrorOperatorComm;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx310_ErrorDriveComm    := Translation.Safety.ErrorDriveComm;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx311_ErrorPhaseRotation:= Translation.Safety.ErrorPhaseRotation;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx312_ErrorBrakeThermal := Translation.Safety.ErrorBrakeThermal;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx313_ErrorMecaB        := Translation.Safety.ErrorMecaB;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx314_ErrorMecaA        := Translation.Safety.ErrorMecaA;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx315_ErrorLimitSwitch  := Translation.Safety.ErrorLimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx316_ErrorSensorIncoherent := Translation.Safety.ErrorSensorIncoherent;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx317_ErrorId := Translation.Safety.ErrorId; // Masque brut complet (latch cause, source d'arbitrage PowerCutOff)

GVL_Troubleshooting.TranslationPontM3.Control_400.Idx401_MotionAllowed := Translation.State.Ready;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz := Translation.State.DriveFreqCmd_Hz;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx403_DriveControlWord := Translation.State.DriveControlWord;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx404_FinalInterlockState := Translation.State.FinalInterlockState;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx405_FinalInterlockReason := Translation.State.FinalInterlockReason;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx406_BrakeCommandOpenConfirmed := Translation.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx407_BrakeTimeoutElapsed := Translation.State.FinalBrakeTimeoutElapsed;

GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx501_CmdDriveControlWord := Translation.State.DriveControlWord;
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz := 0; // TBD non câblé - voir fiche §6 (format UINT 0.01Hz non exposé, seul DriveFreqCmd_Hz en REAL Hz existe)
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ := Translation.State.BrakeCmd;

{endregion}

{region "§6 Diagnostic homing"}
// === 🎯 6. Diagnostic Chronologique Homing (HomingM1 & HomingM2) ===
// --- M1 ---
GVL_Troubleshooting.HomingM1.Step1_ModeAuthorized     := (Auth.Mode = E_Mode.MAINT_N1) OR (Auth.Mode = E_Mode.MAINT_N2);
GVL_Troubleshooting.HomingM1.Step2_WinchSelected      := (Auth.Mode <> E_Mode.MAINT_N2) OR (Auth.JoystickWinchSelectArbitrated = 1);
GVL_Troubleshooting.HomingM1.Step3_EncoderAvailable   := Network.EncoderM1.Operational AND NOT InputModuleFault;

GVL_Troubleshooting.HomingM1.HwIn_ContactorsReleased_DI := HwIn.Winch.M1_ContactorsReleased_DI;
GVL_Troubleshooting.HomingM1.HwIn_BrakeIsOpen_DI        := HwIn.Winch.M1_BrakeIsOpen_DI;
GVL_Troubleshooting.HomingM1.HwIn_TopPositionFree_DI    := HwIn.Winch.M1M2_TopPositionFree_DI;

GVL_Troubleshooting.HomingM1.Step4_ContactorsReleased := HwIn.Winch.M1_ContactorsReleased_DI;
GVL_Troubleshooting.HomingM1.Step5_BrakeApplied       := NOT HwIn.Winch.M1_BrakeIsOpen_DI;
GVL_Troubleshooting.HomingM1.TopPositionSensorActive  := Commun.TopPositionSensorActive;
GVL_Troubleshooting.HomingM1.BucketIsOpen             := WinchM2.Bucket.State.MechState.IsOpen;

GVL_Troubleshooting.HomingM1.AllConditionsMet := GVL_Troubleshooting.HomingM1.Step1_ModeAuthorized
                                              AND GVL_Troubleshooting.HomingM1.Step2_WinchSelected
                                              AND GVL_Troubleshooting.HomingM1.Step3_EncoderAvailable
                                              AND GVL_Troubleshooting.HomingM1.Step4_ContactorsReleased
                                              AND GVL_Troubleshooting.HomingM1.Step5_BrakeApplied;

GVL_Troubleshooting.HomingM1.HomingBusy      := WinchM1.State.Encoder.HomingBusy;
GVL_Troubleshooting.HomingM1.HomingDone      := WinchM1.State.Encoder.HomingDone;
GVL_Troubleshooting.HomingM1.HomingHomed     := WinchM1.State.Encoder.Homed;
GVL_Troubleshooting.HomingM1.HomingSuspect   := WinchM1.State.Encoder.HomingSuspect;
GVL_Troubleshooting.HomingM1.RejectErrorMask := WinchM1.State.Encoder.HomingErrorId;

// --- M2 ---
GVL_Troubleshooting.HomingM2.Step1_ModeAuthorized     := (Auth.Mode = E_Mode.MAINT_N1) OR (Auth.Mode = E_Mode.MAINT_N2);
GVL_Troubleshooting.HomingM2.Step2_WinchSelected      := (Auth.Mode <> E_Mode.MAINT_N2) OR (Auth.JoystickWinchSelectArbitrated = 2);
GVL_Troubleshooting.HomingM2.Step3_EncoderAvailable   := Network.EncoderM2.Operational AND NOT InputModuleFault;

GVL_Troubleshooting.HomingM2.HwIn_ContactorsReleased_DI := HwIn.Winch.M2_ContactorsReleased_DI;
GVL_Troubleshooting.HomingM2.HwIn_BrakeIsOpen_DI        := HwIn.Winch.M2_BrakeIsOpen_DI;
GVL_Troubleshooting.HomingM2.HwIn_TopPositionFree_DI    := HwIn.Winch.M1M2_TopPositionFree_DI;

GVL_Troubleshooting.HomingM2.Step4_ContactorsReleased := HwIn.Winch.M2_ContactorsReleased_DI;
GVL_Troubleshooting.HomingM2.Step5_BrakeApplied       := NOT HwIn.Winch.M2_BrakeIsOpen_DI;
GVL_Troubleshooting.HomingM2.TopPositionSensorActive  := Commun.TopPositionSensorActive;
GVL_Troubleshooting.HomingM2.BucketIsOpen             := WinchM2.Bucket.State.MechState.IsOpen;

GVL_Troubleshooting.HomingM2.AllConditionsMet := GVL_Troubleshooting.HomingM2.Step1_ModeAuthorized
                                              AND GVL_Troubleshooting.HomingM2.Step2_WinchSelected
                                              AND GVL_Troubleshooting.HomingM2.Step3_EncoderAvailable
                                              AND GVL_Troubleshooting.HomingM2.Step4_ContactorsReleased
                                              AND GVL_Troubleshooting.HomingM2.Step5_BrakeApplied;

GVL_Troubleshooting.HomingM2.HomingBusy      := WinchM2.State.Encoder.HomingBusy;
GVL_Troubleshooting.HomingM2.HomingDone      := WinchM2.State.Encoder.HomingDone;
GVL_Troubleshooting.HomingM2.HomingHomed     := WinchM2.State.Encoder.Homed;
GVL_Troubleshooting.HomingM2.HomingSuspect   := WinchM2.State.Encoder.HomingSuspect;
GVL_Troubleshooting.HomingM2.RejectErrorMask := WinchM2.State.Encoder.HomingErrorId;

{endregion}

{region "§7 Diagnostic chaine securite et AU"}
// === 🛡️ 7. Diagnostic Chronologique Chaîne de Sécurité & AU (Safety) ===
GVL_Troubleshooting.Safety.SimulationModeActive       := SimulationModeActive;
GVL_Troubleshooting.Safety.SimSafetyActive            := SimSafetyActive;

GVL_Troubleshooting.Safety.HwIn_EmergencyChainClosed_DI  := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.Safety.HwIn_PowerContactorEngaged_DI := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.Safety.HwIn_EmergencyBtnCut_HMI      := GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff;

GVL_Troubleshooting.Safety.Step1_InputModulesOk       := NOT InputModuleFault;
GVL_Troubleshooting.Safety.Step2_EmergencyBtnNotCut   := NOT GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff;
GVL_Troubleshooting.Safety.Step3_EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI;
GVL_Troubleshooting.Safety.Step4_ContactorReleased     := NOT HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.Safety.Step5_ArmingAllowed        := EmergencyState.Armable;

GVL_Troubleshooting.Safety.ArmingStep            := EmergencyState.Step;
GVL_Troubleshooting.Safety.ArmingPulseActive    := ArmingPulseActive;
GVL_Troubleshooting.Safety.ArmingBusy           := EmergencyState.ArmingBusy;
GVL_Troubleshooting.Safety.LockoutActive        := EmergencyDiag.LockoutActive;
GVL_Troubleshooting.Safety.PowerContactorEngaged := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.Safety.PowerCutOffActive    := PowerCutOffActive;
GVL_Troubleshooting.Safety.PowerCutOffRequest   := PowerCutOffActive;
GVL_Troubleshooting.Safety.MaintainAActive      := MaintainAActive;
GVL_Troubleshooting.Safety.MaintainBActive      := MaintainBActive;

(* État final uniquement : ce n'est pas une précondition de réarmement. *)
GVL_Troubleshooting.Safety.AllConditionsMet := HwIn.Machine.EmergencyChainClosed_DI
                                            AND HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.Safety.SafetyError          := EmergencyDiag.Error;
GVL_Troubleshooting.Safety.ArmingErrorId       := EmergencyDiag.ErrorId;
GVL_Troubleshooting.Safety.RedundancyTestFailed := EmergencyDiag.RedundancyTestFailed;
GVL_Troubleshooting.Safety.ArmingFailed         := EmergencyDiag.ArmFailed;
GVL_Troubleshooting.Safety.LastAbortStep        := EmergencyDiag.LastAbortStep;
GVL_Troubleshooting.Safety.LastAbortCause       := EmergencyDiag.LastAbortCause;

{endregion}

{region "§8 Diagnostic CAN et joystick"}
// === 🕹️ 8. Diagnostic Chronologique Bus CAN & Joystick (Joystick) ===
GVL_Troubleshooting.Joystick.Step1_CanBusActive        := Network.BusCanOpen.Operational;
GVL_Troubleshooting.Joystick.Step2_JoystickOperational := Network.Joystick.Operational;
GVL_Troubleshooting.Joystick.HwIn_JoyBtnRaw_DI         := HwIn.Operator.JoyBtnRaw;
GVL_Troubleshooting.Joystick.NeutralXAct               := (HwIn.Operator.JoyXRaw_ANA1 >= 4800 AND HwIn.Operator.JoyXRaw_ANA1 <= 5200);
GVL_Troubleshooting.Joystick.NeutralYAct               := (HwIn.Operator.JoyYRaw_ANA2 >= 4800 AND HwIn.Operator.JoyYRaw_ANA2 <= 5200);
GVL_Troubleshooting.Joystick.Step3_DeadmanPressed      := HwIn.Operator.JoyBtnRaw;
GVL_Troubleshooting.Joystick.Step4_NeutralAcquired     := JoystickHMI.State.AtNeutral;
GVL_Troubleshooting.Joystick.DeadmanArmed             := JoystickHMI.State.DeadmanArmed;

GVL_Troubleshooting.Joystick.AllConditionsMet := GVL_Troubleshooting.Joystick.Step1_CanBusActive
                                              AND GVL_Troubleshooting.Joystick.Step2_JoystickOperational
                                              AND GVL_Troubleshooting.Joystick.DeadmanArmed;

GVL_Troubleshooting.Joystick.JoystickSelected := GVL_IHM.Modes.Cmd.TglJoystickMaster;
GVL_Troubleshooting.Joystick.SelJoystickWinch := GVL_IHM.Modes.Cmd.SelJoystickWinch;
GVL_Troubleshooting.Joystick.RawX             := HwIn.Operator.JoyXRaw_ANA1;
GVL_Troubleshooting.Joystick.RawY             := HwIn.Operator.JoyYRaw_ANA2;
GVL_Troubleshooting.Joystick.DeflectionX_Pct  := JoystickHMI.State.AxisCmdX.Deflection;
GVL_Troubleshooting.Joystick.DeflectionY_Pct  := JoystickHMI.State.AxisCmdY.Deflection;
// Direction exprimée en bits (ST_fbJoystick_AxisCmd) : conversion locale bits→INT (-1/0/+1),
// car ici on lit le struct (JoystickHMI.State.AxisCmdX/Y), pas le miroir FB DirectionX/Y.
IF JoystickHMI.State.AxisCmdX.DirectionPositive THEN
    GVL_Troubleshooting.Joystick.DirectionX := 1;
ELSIF JoystickHMI.State.AxisCmdX.DirectionNegative THEN
    GVL_Troubleshooting.Joystick.DirectionX := -1;
ELSE
    GVL_Troubleshooting.Joystick.DirectionX := 0;
END_IF;
IF JoystickHMI.State.AxisCmdY.DirectionPositive THEN
    GVL_Troubleshooting.Joystick.DirectionY := 1;
ELSIF JoystickHMI.State.AxisCmdY.DirectionNegative THEN
    GVL_Troubleshooting.Joystick.DirectionY := -1;
ELSE
    GVL_Troubleshooting.Joystick.DirectionY := 0;
END_IF;

{endregion}

{region "§9 Diagnostic mouvement treuil M1"}
// === ⚙️ 9. Diagnostic Chronologique Mouvement Treuil M1 (MotionM1) ===
GVL_Troubleshooting.MotionM1.Step1_PowerEngaged       := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM1.HwIn_PowerContactorEngaged_DI := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM1.HwIn_BrakeIsOpen_DI      := HwIn.Winch.M1_BrakeIsOpen_DI;
GVL_Troubleshooting.MotionM1.Cmd_BrakeRelease         := WinchM1.State.BrakeCmd;

GVL_Troubleshooting.MotionM1.Step2_ModeAuthorized     := (Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2);
GVL_Troubleshooting.MotionM1.Step3_NotBusyOtherTask   := NOT WinchM1.State.Encoder.HomingBusy AND NOT (WinchM2.Bucket.State.FBState = E_State.BUSY);
GVL_Troubleshooting.MotionM1.Step4_MotionRequested    := WinchM1.State.Busy OR (WinchM1.State.SpeedCmd_Pct > 0.0);
GVL_Troubleshooting.MotionM1.RequestedDirection       := SEL(WinchM1.State.RelayFwd, SEL(WinchM1.State.RelayRev, 0, -1), 1);
GVL_Troubleshooting.MotionM1.RequestedSpeedPct        := WinchM1.State.SpeedCmd_Pct;
GVL_Troubleshooting.MotionM1.Step5_NoSafetyFault      := NOT WinchM1.Safety.SafeStop AND NOT WinchM1.Safety.ThermalFault;
GVL_Troubleshooting.MotionM1.Step6_DirectionAllowed   := SEL(GVL_Troubleshooting.MotionM1.RequestedDirection = 1, WinchM1.Safety.DescendPermit, WinchM1.Safety.AscentPermit);
GVL_Troubleshooting.MotionM1.Step7_BrakeReleased      := WinchM1.State.BrakeCmd AND WinchM1.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.MotionM1.Step8_OutputInterlockOk  := NOT WinchM1.State.FinalInterlockError;

GVL_Troubleshooting.MotionM1.AllConditionsMet := GVL_Troubleshooting.MotionM1.Step1_PowerEngaged
                                              AND GVL_Troubleshooting.MotionM1.Step2_ModeAuthorized
                                              AND GVL_Troubleshooting.MotionM1.Step3_NotBusyOtherTask
                                              AND GVL_Troubleshooting.MotionM1.Step4_MotionRequested
                                              AND GVL_Troubleshooting.MotionM1.Step5_NoSafetyFault
                                              AND GVL_Troubleshooting.MotionM1.Step6_DirectionAllowed
                                              AND GVL_Troubleshooting.MotionM1.Step7_BrakeReleased
                                              AND GVL_Troubleshooting.MotionM1.Step8_OutputInterlockOk;

GVL_Troubleshooting.MotionM1.RelayFwdActive        := WinchM1.State.RelayFwd;
GVL_Troubleshooting.MotionM1.RelayRevActive        := WinchM1.State.RelayRev;
GVL_Troubleshooting.MotionM1.SpeedContactor1Active := WinchM1.State.Contactor1;

{endregion}

{region "§10 Diagnostic mouvement treuil M2"}
// === ⚙️ 10. Diagnostic Chronologique Mouvement Treuil M2 (MotionM2) ===
GVL_Troubleshooting.MotionM2.Step1_PowerEngaged       := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM2.HwIn_PowerContactorEngaged_DI := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM2.HwIn_BrakeIsOpen_DI      := HwIn.Winch.M2_BrakeIsOpen_DI;
GVL_Troubleshooting.MotionM2.Cmd_BrakeRelease         := WinchM2.State.BrakeCmd;

GVL_Troubleshooting.MotionM2.Step2_ModeAuthorized     := (Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2);
GVL_Troubleshooting.MotionM2.Step3_NotBusyOtherTask   := NOT WinchM2.State.Encoder.HomingBusy;
GVL_Troubleshooting.MotionM2.Step4_MotionRequested    := WinchM2.State.Busy OR (WinchM2.State.SpeedCmd_Pct > 0.0);
GVL_Troubleshooting.MotionM2.RequestedDirection       := SEL(WinchM2.State.RelayFwd, SEL(WinchM2.State.RelayRev, 0, -1), 1);
GVL_Troubleshooting.MotionM2.RequestedSpeedPct        := WinchM2.State.SpeedCmd_Pct;
GVL_Troubleshooting.MotionM2.Step5_NoSafetyFault      := NOT WinchM2.Safety.SafeStop AND NOT WinchM2.Safety.ThermalFault AND NOT WinchM2.Safety.SlackCable;
GVL_Troubleshooting.MotionM2.Step6_DirectionAllowed   := SEL(GVL_Troubleshooting.MotionM2.RequestedDirection = 1, WinchM2.Safety.DescendPermit, WinchM2.Safety.AscentPermit);
GVL_Troubleshooting.MotionM2.Step7_BrakeReleased      := WinchM2.State.BrakeCmd AND WinchM2.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.MotionM2.Step8_OutputInterlockOk  := NOT WinchM2.State.FinalInterlockError;

GVL_Troubleshooting.MotionM2.AllConditionsMet := GVL_Troubleshooting.MotionM2.Step1_PowerEngaged
                                              AND GVL_Troubleshooting.MotionM2.Step2_ModeAuthorized
                                              AND GVL_Troubleshooting.MotionM2.Step3_NotBusyOtherTask
                                              AND GVL_Troubleshooting.MotionM2.Step4_MotionRequested
                                              AND GVL_Troubleshooting.MotionM2.Step5_NoSafetyFault
                                              AND GVL_Troubleshooting.MotionM2.Step6_DirectionAllowed
                                              AND GVL_Troubleshooting.MotionM2.Step7_BrakeReleased
                                              AND GVL_Troubleshooting.MotionM2.Step8_OutputInterlockOk;

GVL_Troubleshooting.MotionM2.RelayFwdActive        := WinchM2.State.RelayFwd;
GVL_Troubleshooting.MotionM2.RelayRevActive        := WinchM2.State.RelayRev;
GVL_Troubleshooting.MotionM2.SpeedContactor1Active := WinchM2.State.Contactor1;

{endregion}

{region "§11 Diagnostic mouvement translation M3"}
// === ⚙️ 10bis. Diagnostic Chronologique Mouvement Translation M3 (MotionM3) ===
GVL_Troubleshooting.MotionM3.Step1_PowerEngaged       := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM3.HwIn_PowerContactorEngaged_DI := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.MotionM3.HwIn_BrakeIsOpen_DI      := HwIn.Translation.M3_BrakeIsOpen_DI;
GVL_Troubleshooting.MotionM3.Cmd_BrakeRelease         := Translation.State.BrakeCmd;

GVL_Troubleshooting.MotionM3.Step2_ModeAuthorized     := (Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2);
GVL_Troubleshooting.MotionM3.Step3_NotBusyOtherTask   := TRUE; // Aucune tâche exclusive connue bloquant M3 (pas de homing translation)
GVL_Troubleshooting.MotionM3.Step4_MotionRequested    := Translation.State.Busy OR (Translation.State.SpeedCmd_Pct > 0.0);
GVL_Troubleshooting.MotionM3.RequestedDirection       := Translation.State.ActiveDirection;
GVL_Troubleshooting.MotionM3.RequestedSpeedPct        := Translation.State.SpeedCmd_Pct;
GVL_Troubleshooting.MotionM3.Step5_NoSafetyFault      := NOT Translation.Safety.SafeStop AND NOT Translation.State.Error;
GVL_Troubleshooting.MotionM3.Step6_DirectionAllowed   := NOT Translation.State.HeightInterlockBlocking; // Interlock hauteur M1/M2 (risque collision)
GVL_Troubleshooting.MotionM3.Step7_BrakeReleased      := Translation.State.BrakeCmd AND Translation.State.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.MotionM3.Step8_OutputInterlockOk  := NOT Translation.State.FinalInterlockError;

GVL_Troubleshooting.MotionM3.AllConditionsMet := GVL_Troubleshooting.MotionM3.Step1_PowerEngaged
                                              AND GVL_Troubleshooting.MotionM3.Step2_ModeAuthorized
                                              AND GVL_Troubleshooting.MotionM3.Step3_NotBusyOtherTask
                                              AND GVL_Troubleshooting.MotionM3.Step4_MotionRequested
                                              AND GVL_Troubleshooting.MotionM3.Step5_NoSafetyFault
                                              AND GVL_Troubleshooting.MotionM3.Step6_DirectionAllowed
                                              AND GVL_Troubleshooting.MotionM3.Step7_BrakeReleased
                                              AND GVL_Troubleshooting.MotionM3.Step8_OutputInterlockOk;

// 🔌 M3 piloté par variateur AC600 (pas de relais/contacteur de palier comme M1/M2) : ces
// champs restent des indicateurs de sens actif, pas des retours relais physiques réels.
GVL_Troubleshooting.MotionM3.RelayFwdActive        := (Translation.State.ActiveDirection = 1) AND Translation.State.Busy;
GVL_Troubleshooting.MotionM3.RelayRevActive        := (Translation.State.ActiveDirection = -1) AND Translation.State.Busy;
GVL_Troubleshooting.MotionM3.SpeedContactor1Active := FALSE; // Non applicable — M3 n'a pas de contacteur de vitesse par palier

{endregion}

{region "§12 Images entrees reelles et simulees"}
// === 📥 11. Image Complète des Entrées Réelles / Simulées (Inputs) ===
GVL_Troubleshooting.Inputs := HwIn;
{endregion}

{region "§13 Séquenceur de cycle semi-automatique"}
// === 🔄 12. Diagnostic Chronologique Séquenceur Semi-Auto (CycleSemiAuto) ===
GVL_Troubleshooting.CycleSemiAuto.Idx101_ModeSemiAutoActive        := (Auth.Mode = E_Mode.SEMI_AUTO);
GVL_Troubleshooting.CycleSemiAuto.Idx102_PowerAndSafetyOk          := HwIn.Machine.PowerContactorEngaged_DI;
GVL_Troubleshooting.CycleSemiAuto.Idx103_HeartbeatIhmOk            := Commun.HeartbeatIhmOk;
GVL_Troubleshooting.CycleSemiAuto.Idx104_DeadmanArmed              := JoystickDeadmanArmed;
GVL_Troubleshooting.CycleSemiAuto.Idx105_MancheDeflechi            := NOT JoystickAtNeutral;
GVL_Troubleshooting.CycleSemiAuto.Idx106_HomedM1M2                 := HomedM1 AND HomedM2;
GVL_Troubleshooting.CycleSemiAuto.Idx107_StartCycleRequest         := CycleStartRequest;
GVL_Troubleshooting.CycleSemiAuto.Idx108_AbortCycleRequest         := CycleAbortRequest;

GVL_Troubleshooting.CycleSemiAuto.Idx201_Ready                     := CycleReady;
GVL_Troubleshooting.CycleSemiAuto.Idx202_Busy                      := CycleAutoBusy;
GVL_Troubleshooting.CycleSemiAuto.Idx203_Done                      := CycleDone;
GVL_Troubleshooting.CycleSemiAuto.Idx204_Error                     := CycleError;
GVL_Troubleshooting.CycleSemiAuto.Idx205_ErrorId                   := CycleErrorId;
GVL_Troubleshooting.CycleSemiAuto.Idx206_Step                      := CycleStep;
GVL_Troubleshooting.CycleSemiAuto.Idx207_StepStr                   := CycleStepStr;
GVL_Troubleshooting.CycleSemiAuto.Idx208_StepAtError               := CycleStepAtError;
GVL_Troubleshooting.CycleSemiAuto.Idx209_WaitingForOperator        := CycleWaitingForOperator;
GVL_Troubleshooting.CycleSemiAuto.Idx210_WaitingForProcess         := CycleWaitingForProcess;
GVL_Troubleshooting.CycleSemiAuto.Idx211_OperatorActionId          := CycleOperatorActionId;
GVL_Troubleshooting.CycleSemiAuto.Idx212_OperatorAction            := CycleOperatorAction;
GVL_Troubleshooting.CycleSemiAuto.Idx213_ExpectedAxis              := CycleExpectedAxis;
GVL_Troubleshooting.CycleSemiAuto.Idx214_ExpectedDirection         := CycleExpectedDirection;
GVL_Troubleshooting.CycleSemiAuto.Idx215_WaitingResume             := (Auth.Mode <> E_Mode.SEMI_AUTO) AND (CycleStep <> E_CycleStep.X0_PREPARATION) AND (CycleStep <> E_CycleStep.X13_DONE_SYNC) AND (CycleStep <> E_CycleStep.STABILIZING);
GVL_Troubleshooting.CycleSemiAuto.Idx216_PausedState               := CycleStep;

GVL_Troubleshooting.CycleSemiAuto.Idx301_TargetPosition            := CycleTargetPosition;
GVL_Troubleshooting.CycleSemiAuto.Idx302_TargetDepth_M             := CycleTargetDepth_M;
GVL_Troubleshooting.CycleSemiAuto.Idx303_KoboldBottomTouch         := CycleKoboldBottomTouch;
GVL_Troubleshooting.CycleSemiAuto.Idx304_SpeedMismatchActive       := CycleSpeedMismatchActive;
GVL_Troubleshooting.CycleSemiAuto.Idx305_LimitLegalReached         := CycleLimitLegalReached;
GVL_Troubleshooting.CycleSemiAuto.Idx306_WinchSyncError            := CycleWinchSyncError;
{endregion}

{region "§14 Trace de blocage terrain (winch M1/M2 + translation M3)"}
// === 🕵️ 13. Trace de blocage terrain (ST_TraceWinch / ST_TraceTranslation) ===
// Pur recopie des traces publiées par PRG_04 (§8bis) et PRG_05 (§4bis). Aucun calcul métier ici.
GVL_Troubleshooting.TraceWinchM1     := WinchM1Trace;
GVL_Troubleshooting.TraceWinchM2     := WinchM2Trace;
GVL_Troubleshooting.TraceTranslation := TranslationTrace;
{endregion}


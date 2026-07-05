(* ═══════════════════════════════════════════════════════════════
   🔄 PRG_05_Cycle — Séquenceur du Cycle Automatique / Semi-Auto (Grafcet)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5.
   ✅ Gère la machine d'état principale de dragage (FB_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_05_Cycle
VAR
    // Instance du séquenceur automatique
    instCycle           : FB_Cycle;

    // Commandes issues de la supervision (IHM)
    CmdStartCycle_IHM   : BOOL;         // Lancement cycle automatique
    CmdPauseCycle_IHM   : BOOL;         // Pause cycle automatique
    CmdAbortCycle_IHM   : BOOL;         // Abandon / arrêt cycle automatique

    // Paramètres cibles réglés par l'opérateur
    TargetDepthM        : REAL := -12.5; // Profondeur de dragage cible (mètres, négative)
    TargetOffsetM       : REAL := 1.5;  // Décalage cible de fermeture du grappin (mètres)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_05_Cycle) ===

// Appel du séquenceur de cycle principal avec tous ses raccordements
instCycle(
    Enable              := (PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO),
    Reset               := PRG_09_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    
    StartCycle          := CmdStartCycle_IHM,
    PauseCycle          := CmdPauseCycle_IHM,
    AbortCycle          := CmdAbortCycle_IHM,
    
    TargetDepthM        := TargetDepthM,
    TargetOffsetM       := TargetOffsetM,
    SelectedTargetNum_IHM := GVL_IHM.Chariot.SelectedTargetNum,

    // Capteur fond touché détecté par le mou de câble physique (sécurité positive)
    BottomTouched       := NOT PRG_00_Inputs.SlackCableSwitch,
    M1_CablePosM        := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2_CablePosM        := PRG_02_Encoders.instEncoderScaleM2.CablePosM,

    // Position chariot
    Chariot_At_Fosse1   := PRG_00_Inputs.ChariotPosFosse1,
    Chariot_At_Fosse2   := PRG_00_Inputs.ChariotPosFosse2,
    Chariot_At_Maintenance := PRG_00_Inputs.ChariotPosMaintenance,
    Chariot_At_Tremie   := PRG_00_Inputs.ChariotPosTremie,
    Chariot_Busy        := PRG_07_ChariotControl.instChariotM3.Busy,
    Chariot_Done        := PRG_07_ChariotControl.instChariotM3.Done,

    // Mouvements mâchoires grappin (gérés par instGrappin)
    Grappin_Busy        := PRG_06_WinchControl.instGrappin.Busy,
    Grappin_Done        := PRG_06_WinchControl.instGrappin.Done,
    Grappin_IsOpen      := GVL_PERSISTENT.GrappinState.IsOpen,
    Grappin_IsClosed    := GVL_PERSISTENT.GrappinState.IsClosed
);

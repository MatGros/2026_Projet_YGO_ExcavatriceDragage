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
    CmdResetCycle_IHM   : BOOL;         // 🔧 REX 2026-07-07 : reset dédié FB_Cycle, jamais mélangé au reset défauts général

    // Paramètres cibles réglés par l'opérateur
    TargetDepthM        : REAL := -12.5; // Profondeur de dragage cible (mètres, négative)
    TargetOffsetM       : REAL := 1.5;  // Décalage cible de fermeture du benne (mètres)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_05_Cycle) ===

// Appel du séquenceur de cycle principal avec tous ses raccordements
instCycle(
    Enable              := (PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO) AND NOT PRG_10_Outputs.ManuActive,
    Reset               := CmdResetCycle_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    
    StartCycle          := CmdStartCycle_IHM,
    PauseCycle          := CmdPauseCycle_IHM,
    AbortCycle          := CmdAbortCycle_IHM,
    
    TargetDepthM        := TargetDepthM,
    TargetOffsetM       := TargetOffsetM,
    SelectedTargetNum_IHM := GVL_IHM.TranslationM3.SelectedTargetNum,

    // Capteur fond touché détecté par le mou de câble physique (sécurité positive)
    BottomTouched       := NOT PRG_00_Inputs.SlackCableSwitch,
    M1_CablePosM        := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2_CablePosM        := PRG_02_Encoders.instEncoderScaleM2.CablePosM,

    // Position translation
    Translation_At_Fosse1   := PRG_00_Inputs.TranslationPosFosse1,
    Translation_At_Fosse2   := PRG_00_Inputs.TranslationPosFosse2,
    Translation_At_Maintenance := PRG_00_Inputs.TranslationPosMaintenance,
    Translation_At_Tremie   := PRG_00_Inputs.TranslationPosTremie,
    Translation_Busy        := PRG_07_TranslationControl.instTranslationM3.Busy,
    Translation_Done        := PRG_07_TranslationControl.instTranslationM3.Done,

    // Mouvements mâchoires benne (gérés par instBucket)
    Benne_Busy        := PRG_06_WinchControl.instBucket.Busy,
    Benne_Done        := PRG_06_WinchControl.instBucket.Done,
    Benne_IsOpen      := GVL_PERSISTENT.BucketState.IsOpen,
    Benne_IsClosed    := GVL_PERSISTENT.BucketState.IsClosed
);

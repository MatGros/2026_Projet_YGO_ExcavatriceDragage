(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_04_Modes — Gestion et Arbitrage du Mode Machine
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Modes
VAR
    instModes : FB_Modes; // Arbitrage du mode machine (DISABLE, MAINT, SEMI_AUTO, etc.)
    PrevInhibitM1 : BOOL; // 🆕 Mémoire d'état M1
    PrevInhibitM2 : BOOL; // 🆕 Mémoire d'état M2
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_04_Modes) ===

// 🆕 Exclusion mutuelle des inhibitions de treuils (soit M1, soit M2, jamais les deux)
IF GVL_IHM.WinchM1.CmdInhibit AND GVL_IHM.WinchM2.CmdInhibit THEN
    // Si M1 était déjà activé, on rejette la demande sur M2 (M2 retombe à FALSE)
    IF PrevInhibitM1 THEN
        GVL_IHM.WinchM2.CmdInhibit := FALSE;
    // Si M2 était déjà activé, on rejette la demande sur M1 (M1 retombe à FALSE)
    ELSIF PrevInhibitM2 THEN
        GVL_IHM.WinchM1.CmdInhibit := FALSE;
    ELSE
        // repli de sécurité si les deux s'activent de façon synchrone sans transition
        GVL_IHM.WinchM1.CmdInhibit := FALSE;
        GVL_IHM.WinchM2.CmdInhibit := FALSE;
    END_IF;
END_IF;

PrevInhibitM1 := GVL_IHM.WinchM1.CmdInhibit;
PrevInhibitM2 := GVL_IHM.WinchM2.CmdInhibit;

// 🆕 Si l'un des treuils est inhibé, synchro impossible par nature -> reset case IHM à TRUE
// (🔧 REX 2026-07-08 : polarité inversée, TRUE = état neutre "synchro voulue")
IF GVL_IHM.WinchM1.CmdInhibit OR GVL_IHM.WinchM2.CmdInhibit THEN
    GVL_IHM.Sync.SyncEnableRequest := TRUE;
END_IF;

instModes(
    Enable              := TRUE,
    Reset               := GVL_IHM.Modes.ModeReset,  // 🔧 REX 2026-07-07 : dédié, jamais mélangé au reset défauts général
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur IHM
    SyncEnableRequest   := GVL_Modes_Stub.SyncEnableRequest_IHM,
    InhibitM1Request    := GVL_IHM.WinchM1.CmdInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    InhibitM2Request    := GVL_IHM.WinchM2.CmdInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    HomingApproachEnableRequest := GVL_IHM.Common.HomingApproachEnableRequest, // 🆕 REX 2026-07-08 (2)
    EncoderFaultPresent := PRG_02_Encoders.EncoderFaultPresent,   // 1 cycle de retard (reçu de PRG_02_Encoders)
    JoystickWinchSelectRequest := GVL_IHM.IHM_MANU.JoystickWinchSelect // 🆕 TASK-0001
);

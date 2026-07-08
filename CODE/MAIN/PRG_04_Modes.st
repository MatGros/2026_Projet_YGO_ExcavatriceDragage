(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_04_Modes — Gestion et Arbitrage du Mode Machine
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Modes
VAR
    instModes : FB_Modes; // Arbitrage du mode machine (DISABLE, MAINT, SEMI_AUTO, etc.)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_04_Modes) ===

instModes(
    Enable              := TRUE,
    Reset               := GVL_IHM.Modes.ModeReset,  // 🔧 REX 2026-07-07 : dédié, jamais mélangé au reset défauts général
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur IHM
    OverrideSyncRequest := GVL_Modes_Stub.OverrideSyncRequest_IHM,
    InhibitM1Request    := GVL_IHM.WinchM1.CmdInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    InhibitM2Request    := GVL_IHM.WinchM2.CmdInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    OverrideTopStopRequest := GVL_IHM.Common.OverrideTopStopRequest, // 🆕 REX 2026-07-08 (2)
    EncoderFaultPresent := PRG_02_Encoders.EncoderFaultPresent   // 1 cycle de retard (reçu de PRG_02_Encoders)
);

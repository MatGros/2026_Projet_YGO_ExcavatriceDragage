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
    Reset               := PRG_09_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur IHM
    PasswordOk          := GVL_Modes_Stub.PasswordOk_IHM,       // 🖥️ Stub mot de passe
    OverrideSyncRequest := GVL_Modes_Stub.OverrideSyncRequest_IHM,
    EncoderFaultPresent := PRG_02_Encoders.EncoderFaultPresent   // 1 cycle de retard (reçu de PRG_02_Encoders)
);

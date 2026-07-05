(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_4_Modes — Gestion et Arbitrage du Mode Machine
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_4_Modes
VAR
    instModes : FB_Modes; // Arbitrage du mode machine (DISABLE, MAINT, SEMI_AUTO, etc.)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_4_Modes) ===

instModes(
    Enable              := TRUE,
    Reset               := PRG_9_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur IHM
    PasswordOk          := GVL_Modes_Stub.PasswordOk_IHM,       // 🖥️ Stub mot de passe
    OverrideSyncRequest := GVL_Modes_Stub.OverrideSyncRequest_IHM,
    EncoderFaultPresent := PRG_2_Encoders.EncoderFaultPresent   // 1 cycle de retard (reçu de PRG_2_Encoders)
);

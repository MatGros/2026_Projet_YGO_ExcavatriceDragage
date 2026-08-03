(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_03_Modes_Cycle — Gestion, Modes Machine et Séquenceur de Cycle
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après PRG_02_Acquisition).
   📄 Docs : DOC/AF_Partie-05_Modes_Maintenance_v2.0.md
   🎯 Rôle unique : Instancier FB_Modes, distribuer le bus ST_Modes_Autorisations.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Modes_Cycle

VAR
    instModes : FB_Modes;  // Arbitrage mode + bus autorisations
END_VAR

VAR_OUTPUT
    Auth : ST_Modes_Autorisations;  // Bus d'autorisations (producteur unique)
END_VAR

// === 🔀 §1 ARBITRAGE DES MODES MACHINE ===

instModes(
    Enable                  := TRUE,
    Reset                   := GVL_IHM.Modes.Cmd.BtnModeReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    SelMode                 := GVL_IHM.Modes.Cmd.SelMode,
    SelSyncEnable           := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable,
    InhibitM1Request        := GVL_IHM.M1TreuilRetenue.Cmd.BtnInhibit,
    InhibitM2Request        := GVL_IHM.M2TreuilBenne.Cmd.BtnInhibit,
    SelHomingApproachEnable := GVL_IHM.Commun.Cfg.SelHomingApproachEnable,
    EncoderFaultPresent     := NOT PRG_02_Acquisition.HwIn.Winch.COD1_DeviceState,
    JoystickWinchSelectRequest := GVL_IHM.Modes.Cmd.SelJoystickWinch
);


// === 📤 §2 PUBLICATION DU BUS AUTORISATIONS ===

Auth := instModes.Auth;

END_PROGRAM

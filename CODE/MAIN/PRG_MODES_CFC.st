(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_MODES_CFC — Gestion et Arbitrage du Mode Machine
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après Acquisition/Inputs).
   📄 Docs : DOC/AF_Partie-05_Modes_Maintenance_v2.0.md
   ⚠️ Programme CFC pur : instance FB_Modes + câblage, ZÉRO logique métier.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_MODES_CFC
VAR
    instModes : FB_Modes;  // Arbitrage mode + bus autorisations
END_VAR
VAR_OUTPUT
    Auth : ST_Modes_Autorisations;  // Bus d'autorisations (producteur unique)
END_VAR

// === IMPLEMENTATION ===

instModes(
    Enable                  := TRUE,
    Reset                   := GVL_IHM.Modes.Cmd.BtnModeReset,
    PowerContactorEngaged   := PRG_INPUTS_LD.PowerContactorEngaged,
    SelMode                 := GVL_IHM.Modes.Cmd.SelMode,
    SelSyncEnable           := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable,
    InhibitM1Request        := GVL_IHM.M1TreuilRetenue.Cmd.BtnInhibit,
    InhibitM2Request        := GVL_IHM.M2TreuilBenne.Cmd.BtnInhibit,
    SelHomingApproachEnable := GVL_IHM.Commun.Cfg.SelHomingApproachEnable,
    EncoderFaultPresent     := PRG_02_Encoders.EncoderFaultPresent,
    JoystickWinchSelectRequest := GVL_IHM.Modes.Cmd.SelJoystickWinch
);

// Propagation bus autorisations
Auth := instModes.Auth;

END_PROGRAM
(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_04_Modes — Gestion et Arbitrage du Mode Machine
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-05_Modes_Maintenance_v1.6.md
*)

PROGRAM PRG_04_Modes
VAR
    instModes : FB_Modes; // Arbitrage du mode machine (DISABLE, MAINT, SEMI_AUTO, etc.)
    PrevInhibitM1 : BOOL; // 🆕 Mémoire d'état M1
    PrevInhibitM2 : BOOL; // 🆕 Mémoire d'état M2
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_04_Modes) ===

// 🆕 Exclusion mutuelle des inhibitions de treuils (soit M1, soit M2, jamais les deux)
IF GVL_IHM.M1TreuilRetenue.BtnInhibit AND GVL_IHM.M2TreuilBucket.BtnInhibit THEN
    // Si M1 était déjà activé, on rejette la demande sur M2 (M2 retombe à FALSE)
    IF PrevInhibitM1 THEN
        GVL_IHM.M2TreuilBucket.BtnInhibit := FALSE;
    // Si M2 était déjà activé, on rejette la demande sur M1 (M1 retombe à FALSE)
    ELSIF PrevInhibitM2 THEN
        GVL_IHM.M1TreuilRetenue.BtnInhibit := FALSE;
    ELSE
        // repli de sécurité si les deux s'activent de façon synchrone sans transition
        GVL_IHM.M1TreuilRetenue.BtnInhibit := FALSE;
        GVL_IHM.M2TreuilBucket.BtnInhibit := FALSE;
    END_IF;
END_IF;

PrevInhibitM1 := GVL_IHM.M1TreuilRetenue.BtnInhibit;
PrevInhibitM2 := GVL_IHM.M2TreuilBucket.BtnInhibit;

// 🆕 Si l'un des treuils est inhibé, synchro impossible par nature -> reset case IHM à TRUE
// (🔧 REX 2026-07-08 : polarité inversée, TRUE = état neutre "synchro voulue")
IF GVL_IHM.M1TreuilRetenue.BtnInhibit OR GVL_IHM.M2TreuilBucket.BtnInhibit THEN
    GVL_IHM.Sync.SelSyncEnable := TRUE;
END_IF;

instModes(
    Enable              := TRUE,
    Reset               := GVL_IHM.Modes.BtnModeReset,  // 🔧 REX 2026-07-07 : dédié, jamais mélangé au reset défauts général
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    SelMode         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur IHM
    SelSyncEnable   := GVL_Modes_Stub.SyncEnableRequest_IHM,
    InhibitM1Request    := GVL_IHM.M1TreuilRetenue.BtnInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    InhibitM2Request    := GVL_IHM.M2TreuilBucket.BtnInhibit, // 🆕 REX 2026-07-08 : IHM réelle, pas GVL_Modes_Stub
    SelHomingApproachEnable := GVL_IHM.Commun.SelHomingApproachEnable, // 🆕 REX 2026-07-08 (2)
    EncoderFaultPresent := PRG_02_Encoders.EncoderFaultPresent,   // 1 cycle de retard (reçu de PRG_02_Encoders)
    JoystickWinchSelectRequest := GVL_IHM.Modes.SelJoystickWinch // 🆕 TASK-0001, rapatrié depuis IHM_MANU (2026-07-19)
);

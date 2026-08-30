(* ═══════════════════════════════════════════════════════════════
   🪝 FB_WinchCmdArbitrationM2 — Arbitrage de commande treuil M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Arbitrer la source de commande M2 (joystick / boutons IHM /
       demande cycle / chemin benne selon le mode) et produire la commande arbitrée.
   🔌 FB d'arbitrage (non-mouvement) : ne porte ni SafeStop ni StartStop
       de sécurité — il produit la commande logique, la safety reste dans
       FB_Safety_Winch / FB_Winch.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔒 Bit-identique à l'ancien PRG_04 §3 (refactor POO).
   ⚠️ Asymétries M2 vs M1 : chemin benne (override), Select=0/2, synchro inversée.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_WinchCmdArbitrationM2
VAR_INPUT
    Enable     : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Joystick   : ST_AcquisitionJoystickQualified;  // --> [HW] Données joystick qualifiées (AxisY, DeadmanArmed)
    Auth       : ST_fbModes_Autorisations;          // --> [CMD] Autorisations mode (Mode, JoystickWinchSelectArbitrated)
    ReqWinch   : ST_ProgramWinchRequest;            // --> [REQ] Demande cycle treuil M2 (SEMI_AUTO)
    BothIntent : ST_WinchBothIntent;           // --> [CMD] Intention both opérateur (source unique PRG_03)
    IHM        : ST_fbWinchCmdArbitration_IHM;  // --> [CMD] Boutons IHM (BtnUpM2/BtnDownM2, both)
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd, source unique)
    Context    : ST_fbWinchCmdArbitration_Context; // --> [STAT] Gating benne/synchro + chemin benne (partagé M1/M2)
    Cfg        : ST_fbWinchCmdArbitration_Cfg;     // --> [CFG] Vitesse override benne
END_VAR
VAR_OUTPUT
    Ready     : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    StartStop : BOOL;  // <-- [CMD] Commande marche/arrêt arbitrée
    Direction : INT;   // <-- [CMD] Sens arbitré (-1: Descending, 0: Stop, 1: Ascending)
    SpeedPct  : REAL;  // <-- [CMD] Consigne vitesse arbitrée (0..100 %)
END_VAR
VAR
    BenneBusyFallEdge : F_TRIG;  // . [LOC] Front descendant action benne (arrêt forcé)
END_VAR

// === IMPLEMENTATION ===

Ready := Enable;

// Front de fin d'action benne (détecté en interne, mécanisme de sécurité)
BenneBusyFallEdge(CLK := Context.BucketBusy);

IF NOT Enable THEN
    StartStop := FALSE;
    Direction := 0;
    SpeedPct  := 0.0;
ELSE
    // ── Chemin benne : M2 piloté par l'action benne (override) ──
    IF Context.BucketBusy AND Context.BucketM2StartStop THEN
        StartStop := Context.BucketM2StartStop;
        Direction := SEL(Context.BucketM2Open, -1, 1);  // Open → +1, Close → -1
        SpeedPct  := Cfg.BucketOverrideSpeedPct;
    ELSE
        // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
        IF Auth.Mode = E_Mode.SEMI_AUTO THEN
            StartStop := ReqWinch.ReqStartStop;
            Direction := ReqWinch.ReqDirection;
            SpeedPct  := ReqWinch.SpeedTgtPct;
        ELSE
            // ── Mode manuel : commande both issue de l'intention UNIQUE PRG_03 (BothIntent),
            //    commande unitaire M2 dérivée des boutons/joystick (Select=2). ──
            IF NOT TglJoystickMaster THEN
                // Mode Boutons IHM
                IF BothIntent.Active THEN
                    // Both (BtnWinchBothUp/Down) — source unique PRG_03, plus de re-dérivation
                    Direction := BothIntent.Direction;
                    SpeedPct  := 100.0;
                ELSIF IHM.BtnUpM2 THEN
                    Direction := 1;
                    SpeedPct  := 100.0;
                ELSIF IHM.BtnDownM2 THEN
                    Direction := -1;
                    SpeedPct  := 100.0;
                ELSE
                    Direction := 0;
                    SpeedPct  := 0.0;
                END_IF;
            ELSE
                // Mode Joystick Maître — M2 unitaire si Select = 2, both si Select = 0
                IF Auth.JoystickWinchSelectArbitrated = 2 THEN
                    Direction := Joystick.AxisY.Direction;
                    SpeedPct  := ABS(Joystick.AxisY.SpeedTgt);
                ELSIF BothIntent.Active THEN
                    // Both (Select=0) — source unique PRG_03, plus de re-dérivation
                    Direction := BothIntent.Direction;
                    SpeedPct  := ABS(Joystick.AxisY.SpeedTgt);
                ELSE
                    Direction := 0;
                    SpeedPct  := 0.0;
                END_IF;
            END_IF;

            // Gating StartStop (bit-identique PRG_04 §3) — synchro INVERSÉE vs M1,
            // homme-mort qualifié en joystick
            StartStop := (Direction <> 0)
                      AND NOT Context.WinchBothMotionBlockedByBucket
                      AND NOT ((Context.SyncBlocksUp   AND (Direction = -1))
                            OR (Context.SyncBlocksDown AND (Direction = 1)))
                      AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed);
        END_IF;
    END_IF;

    // Front de fin d'action benne : arrêt forcé sauf mouvement both actif
    IF BenneBusyFallEdge.Q AND NOT (BothIntent.Active AND (BothIntent.Direction <> 0)) THEN
        StartStop := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK

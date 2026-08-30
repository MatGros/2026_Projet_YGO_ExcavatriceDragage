(* ═══════════════════════════════════════════════════════════════
   🪝 FB_WinchCmdArbitrationM1 — Arbitrage de commande treuil M1
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Arbitrer la source de commande M1 (joystick / boutons IHM /
       demande cycle selon le mode) et produire la commande arbitrée.
   🔌 FB d'arbitrage (non-mouvement) : ne porte ni SafeStop ni StartStop
       de sécurité — il produit la commande logique, la safety reste dans
       FB_Safety_Winch / FB_Winch.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔒 Bit-identique à l'ancien PRG_04 §3 (refactor POO).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_WinchCmdArbitrationM1
VAR_INPUT
    Enable     : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Joystick   : ST_AcquisitionJoystickQualified;  // --> [HW] Données joystick qualifiées (AxisY, DeadmanArmed)
    Auth       : ST_fbModes_Autorisations;          // --> [CMD] Autorisations mode (Mode, JoystickWinchSelectArbitrated)
    ReqWinch   : ST_ProgramWinchRequest;            // --> [REQ] Demande cycle treuil M1 (SEMI_AUTO)
    BothIntent : ST_OperatorCoupledIntent;           // --> [CMD] Intention both opérateur (WinchBothMotionActive/Direction)
    IHM        : ST_fbWinchCmdArbitration_IHM;  // --> [CMD] Boutons IHM (BtnUpM1/BtnDownM1, both)
    Context    : ST_fbWinchCmdArbitration_Context; // --> [STAT] Gating benne/synchro (partagé M1/M2)
END_VAR
VAR_OUTPUT
    Ready     : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    StartStop : BOOL;  // <-- [CMD] Commande marche/arrêt arbitrée
    Direction : INT;   // <-- [CMD] Sens arbitré (-1: Descente, 0: Stop, 1: Montée)
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
    // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
    IF Auth.Mode = E_Mode.SEMI_AUTO THEN
        StartStop := ReqWinch.ReqStartStop;
        Direction := ReqWinch.ReqDirection;
        SpeedPct  := ReqWinch.SpeedTgtPct;
    ELSE
        // ── Mode manuel : boutons IHM ou joystick maître ──
        IF NOT IHM.TglJoystickMaster THEN
            // Mode Boutons IHM
            IF IHM.BtnWinchBothUp OR IHM.BtnUpM1 THEN
                Direction := 1;
                SpeedPct  := 100.0;
            ELSIF IHM.BtnWinchBothDown OR IHM.BtnDownM1 THEN
                Direction := -1;
                SpeedPct  := 100.0;
            ELSE
                Direction := 0;
                SpeedPct  := 0.0;
            END_IF;
        ELSE
            // Mode Joystick Maître — M1 autorisé si Select = 0 (both) ou 1 (M1)
            IF (Auth.JoystickWinchSelectArbitrated = 0 OR Auth.JoystickWinchSelectArbitrated = 1) THEN
                Direction := Joystick.AxisY.Direction;
                SpeedPct  := ABS(Joystick.AxisY.SpeedTgt);
            ELSE
                Direction := 0;
                SpeedPct  := 0.0;
            END_IF;
        END_IF;

        // Gating StartStop (bit-identique PRG_04 §3)
        StartStop := (Direction <> 0)
                  AND NOT Context.BucketBusy
                  AND NOT Context.WinchBothMotionBlockedByBucket
                  AND NOT ((Context.SyncBlocksUp   AND (Direction = 1))
                        OR (Context.SyncBlocksDown AND (Direction = -1)))
                  AND (NOT IHM.TglJoystickMaster OR Joystick.DeadmanArmed);
    END_IF;

    // Front de fin d'action benne : arrêt forcé sauf mouvement both actif
    IF BenneBusyFallEdge.Q AND NOT (BothIntent.Active AND (BothIntent.Direction <> 0)) THEN
        StartStop := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK

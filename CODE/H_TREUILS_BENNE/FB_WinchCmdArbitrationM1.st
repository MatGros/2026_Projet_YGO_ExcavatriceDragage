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
   🪜 -B : la sortie est désormais un PALIER (StepTgt, 1-5) au lieu d'un
       pourcentage. En SEMI_AUTO, passthrough de ReqWinch.StepTgt ; en manuel,
       le joystick est le producteur UNIQUE du palier (passthrough de
       Joystick.AxisY.StepTgt), boutons/both = palier 5 (pleine vitesse).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_WinchCmdArbitrationM1
VAR_INPUT
    Enable     : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Joystick   : ST_AcquisitionJoystickQualified;  // --> [HW] Données joystick qualifiées (AxisY, DeadmanArmed)
    Auth       : ST_Modes_Autorisations;          // --> [CMD] Autorisations mode (Mode, JoystickWinchSelectArbitrated)
    ReqWinch   : ST_ProgramWinchRequest;            // --> [REQ] Demande cycle treuil M1 (SEMI_AUTO)
    BothIntent : ST_WinchBothIntent;           // --> [CMD] Intention both opérateur (source unique PRG_03)
    IHM        : ST_fbWinchCmdArbitration_IHM;  // --> [CMD] Boutons IHM (BtnAscentM1/BtnDescentM1, both)
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd, source unique)
    Context    : ST_fbWinchCmdArbitration_Context; // --> [STAT] Gating benne/synchro (partagé M1/M2)
    Cfg        : ST_fbWinchCmdArbitration_Cfg;     // --> [CFG] Palier boutons/both (BtnStepTgt)
END_VAR
VAR_OUTPUT
    Ready     : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    StartStop : BOOL;  // <-- [CMD] Commande marche/arrêt arbitrée
    Direction : INT;   // <-- [CMD] Sens arbitré (-1: Descending, 0: Stop, 1: Ascending)
    StepTgt   : INT;   // <-- [CMD] Palier de vitesse arbitré (1..5, 0 = arrêt)
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
    StepTgt   := 0;
ELSE
    // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
    IF Auth.Mode = E_Mode.SEMI_AUTO THEN
        StartStop := ReqWinch.ReqStartStop;
        Direction := ReqWinch.ReqDirection;
        StepTgt   := ReqWinch.StepTgt;
    ELSE
        // ── Mode manuel : commande both issue de l'intention UNIQUE PRG_03 (BothIntent),
        //    commande unitaire M1 dérivée des boutons/joystick (Select=1). ──
        // 🪜 StepTgt : le joystick est le producteur UNIQUE du palier (FB_Joystick §6).
        //    Boutons/both = pleine vitesse (100 % → palier 5) ; joystick = passthrough
        //    de Joystick.AxisY.StepTgt. Plus de re-dérivation %→palier ici.
        IF NOT TglJoystickMaster THEN
            // Mode Boutons IHM
            IF BothIntent.Active THEN
                // Both (BtnWinchBothAscent/Descent) — source unique PRG_03, plus de re-dérivation
                Direction := BothIntent.Direction;
                StepTgt   := Cfg.BtnStepTgt;   // 100 % → palier max (configurable)
            ELSIF IHM.BtnAscentM1 THEN
                Direction := 1;
                StepTgt   := Cfg.BtnStepTgt;
            ELSIF IHM.BtnDescentM1 THEN
                Direction := -1;
                StepTgt   := Cfg.BtnStepTgt;
            ELSE
                Direction := 0;
                StepTgt   := 0;
            END_IF;
        ELSE
            // Mode Joystick Maître — M1 unitaire si Select = 1, both si Select = 0
            IF Auth.JoystickWinchSelectArbitrated = 1 THEN
                Direction := Joystick.AxisY.Direction;
                StepTgt   := Joystick.AxisY.StepTgt;
            ELSIF BothIntent.Active THEN
                // Both (Select=0) — source unique PRG_03, plus de re-dérivation
                Direction := BothIntent.Direction;
                StepTgt   := Joystick.AxisY.StepTgt;
            ELSE
                Direction := 0;
                StepTgt   := 0;
            END_IF;
        END_IF;

        // Gating StartStop (bit-identique PRG_04 §3) — homme-mort qualifié en joystick
        StartStop := (Direction <> 0)
                  AND NOT Context.BucketBusy
                  AND NOT Context.WinchBothMotionBlockedByBucket
                  AND NOT ((Context.SyncBlocksAscent   AND (Direction = 1))
                        OR (Context.SyncBlocksDescent AND (Direction = -1)))
                  AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed);
    END_IF;

    // Front de fin d'action benne : arrêt forcé sauf mouvement both actif
    IF BenneBusyFallEdge.Q AND NOT (BothIntent.Active AND (BothIntent.Direction <> 0)) THEN
        StartStop := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK

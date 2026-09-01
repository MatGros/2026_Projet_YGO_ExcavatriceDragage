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
   🪜 -B : la sortie est désormais un PALIER (StepTgt, 1-5) au lieu d'un
       pourcentage. En SEMI_AUTO, passthrough de ReqWinch.StepTgt ; en manuel,
       le joystick est le producteur UNIQUE du palier (passthrough de
       Joystick.AxisY.StepTgt), boutons/both = palier 5, override benne = palier 1.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_WinchCmdArbitrationM2
VAR_INPUT
    Enable     : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Joystick   : ST_AcquisitionJoystickQualified;  // --> [HW] Données joystick qualifiées (AxisY, DeadmanArmed)
    Auth       : ST_Modes_Autorisations;          // --> [CMD] Autorisations mode (Mode, JoystickWinchSelectArbitrated)
    ReqWinch   : ST_ProgramWinchRequest;            // --> [REQ] Demande cycle treuil M2 (SEMI_AUTO)
    BothIntent : ST_WinchBothIntent;           // --> [CMD] Intention both opérateur (source unique PRG_03)
    IHM        : ST_fbWinchCmdArbitration_IHM;  // --> [CMD] Boutons IHM (BtnAscentM2/BtnDescentM2, both)
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd, source unique)
    Context    : ST_fbWinchCmdArbitration_Context; // --> [STAT] Gating benne/synchro + chemin benne (partagé M1/M2)
    Cfg        : ST_fbWinchCmdArbitration_Cfg;     // --> [CFG] Vitesse override benne
END_VAR
VAR_OUTPUT
    Ready     : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    RunRequest : BOOL; // <-- [CMD] Demande marche arbitrée
    ReqAscent  : BOOL; // <-- [CMD] Demande montée arbitrée
    ReqDescend : BOOL; // <-- [CMD] Demande descente arbitrée
    StepTgt   : INT;   // <-- [CMD] Palier de vitesse arbitré (1..5, 0 = arrêt)
END_VAR
VAR
    BenneBusyFallEdge : F_TRIG;  // . [LOC] Front descendant action benne (arrêt forcé)
    BothDirectionAuthorized : BOOL; // . [LOC] Atomicité Both : deux axes autorisés dans le même sens
    RequestConflict         : BOOL; // . [LOC] Double demande de sens refusée
END_VAR

// === IMPLEMENTATION ===

Ready := Enable;

// Front de fin d'action benne (détecté en interne, mécanisme de sécurité)
BenneBusyFallEdge(CLK := Context.BucketBusy);

IF NOT Enable THEN
    RunRequest := FALSE;
    ReqAscent  := FALSE;
    ReqDescend := FALSE;
    StepTgt   := 0;
ELSE
    // ── Chemin benne : M2 piloté par l'action benne (override) ──
    IF Context.BucketBusy AND Context.BucketM2RunRequest THEN
        RunRequest := Context.BucketM2RunRequest;
        ReqAscent  := Context.BucketM2ReqAscent;
        ReqDescend := Context.BucketM2ReqDescend;
        StepTgt   := Cfg.BucketOverrideStepTgt;   // override benne = vitesse lente (palier configurable)
    ELSE
        // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
        IF Auth.Mode = E_Mode.SEMI_AUTO THEN
            RunRequest := ReqWinch.RunRequest;
            ReqAscent  := ReqWinch.ReqAscent;
            ReqDescend := ReqWinch.ReqDescend;
            StepTgt   := ReqWinch.StepTgt;
        ELSE
            // ── Mode manuel : commande both issue de l'intention UNIQUE PRG_03 (BothIntent),
            //    commande unitaire M2 dérivée des boutons/joystick (Select=2). ──
            // 🪜 StepTgt : le joystick est le producteur UNIQUE du palier (FB_Joystick §6).
            //    Boutons/both = pleine vitesse (100 % → palier 5) ; joystick = passthrough
            //    de Joystick.AxisY.StepTgt. Plus de re-dérivation %→palier ici.
            IF NOT TglJoystickMaster THEN
                // Mode Boutons IHM
                IF BothIntent.Active THEN
                    // Both (BtnWinchBothAscent/Descent) — source unique PRG_03, plus de re-dérivation
                    ReqAscent  := BothIntent.ReqAscent;
                    ReqDescend := BothIntent.ReqDescend;
                    StepTgt   := Cfg.BtnStepTgt;   // 100 % → palier max (configurable)
                ELSIF IHM.BtnAscentM2 THEN
                    ReqAscent  := TRUE;
                    ReqDescend := FALSE;
                    StepTgt   := Cfg.BtnStepTgt;
                ELSIF IHM.BtnDescentM2 THEN
                    ReqAscent  := FALSE;
                    ReqDescend := TRUE;
                    StepTgt   := Cfg.BtnStepTgt;
                ELSE
                    ReqAscent  := FALSE;
                    ReqDescend := FALSE;
                    StepTgt   := 0;
                END_IF;
            ELSE
                // Mode Joystick Maître — M2 unitaire si Select = 2, both si Select = 0
                IF Auth.JoystickWinchSelectArbitrated = 2 THEN
                    ReqAscent  := Joystick.AxisY.Direction > 0;
                    ReqDescend := Joystick.AxisY.Direction < 0;
                    StepTgt   := Joystick.AxisY.StepTgt;
                ELSIF BothIntent.Active THEN
                    // Both (Select=0) — source unique PRG_03, plus de re-dérivation
                    ReqAscent  := BothIntent.ReqAscent;
                    ReqDescend := BothIntent.ReqDescend;
                    StepTgt   := Joystick.AxisY.StepTgt;
                ELSE
                    ReqAscent  := FALSE;
                    ReqDescend := FALSE;
                    StepTgt   := 0;
                END_IF;
            END_IF;

            // Gating StartStop (bit-identique PRG_04 §3) — synchro INVERSÉE vs M1,
            // homme-mort qualifié en joystick
            // 🔗 Atomicité Both : cf. M1 — en both, la commande ne consomme QUE le
            // permit agrégé du sens demandé. Départ jamais isolé entre les 2 treuils.
            RequestConflict := ReqAscent AND ReqDescend;
            BothDirectionAuthorized := (NOT BothIntent.Active)
                OR ((ReqAscent AND NOT ReqDescend) AND Context.M1AscentAllowed AND Context.M2AscentAllowed)
                OR ((ReqDescend AND NOT ReqAscent) AND Context.M1DescendAllowed AND Context.M2DescendAllowed);
            RunRequest := (ReqAscent OR ReqDescend) AND NOT RequestConflict
                      AND NOT Context.WinchBothMotionBlockedByBucket
                      AND NOT ((Context.SyncBlocksAscent   AND ReqDescend)
                            OR (Context.SyncBlocksDescent AND ReqAscent))
                      AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed)
                      AND BothDirectionAuthorized;
        END_IF;
    END_IF;

    // Front de fin d'action benne : arrêt forcé sauf mouvement both actif
    IF BenneBusyFallEdge.Q AND NOT (BothIntent.Active AND (BothIntent.ReqAscent OR BothIntent.ReqDescend)) THEN
        RunRequest := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK

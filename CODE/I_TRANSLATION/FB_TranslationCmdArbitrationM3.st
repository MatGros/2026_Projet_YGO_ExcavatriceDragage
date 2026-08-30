(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationCmdArbitrationM3 — Arbitrage de commande M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Arbitrer la source de commande M3 (joystick jog / boutons IHM /
       demande cycle selon le mode) et produire la commande arbitrée.
   🔌 FB d'arbitrage (non-mouvement) : ne porte ni SafeStop ni StartStop
       de sécurité — il produit la commande logique, la safety reste dans
       FB_Safety_Translation / FB_Translation.
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔒 Bit-identique à l'ancien PRG_05 §1 (refactor POO).
   ⚠️ Tautologie (BypassGlobal OR NOT Tgl OR Tgl) conservée bit-identique
       (bug latent conservateur, documenté — ne pas corriger ici).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_TranslationCmdArbitrationM3
VAR_INPUT
    Enable         : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Joystick       : ST_AcquisitionJoystickQualified;   // --> [HW] Données joystick qualifiées (AxisX, DeadmanArmed)
    Auth           : ST_fbModes_Autorisations;           // --> [CMD] Autorisations mode (Mode, MaintenanceM3TargetEnable)
    ReqTranslation : ST_ProgramTranslationRequest;        // --> [REQ] Demande cycle translation (SEMI_AUTO)
    IHM            : ST_fbTranslationCmdArbitration_IHM;  // --> [CMD] Boutons IHM, sélecteur, fréquence
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd, source unique)
    Context        : ST_fbTranslationCmdArbitration_Context; // --> [SAFE] Interlock hauteur
    Cfg            : ST_fbTranslationCmdArbitration_Cfg;     // --> [CFG] Fréquence max (échelle FreqPct)
END_VAR
VAR_OUTPUT
    Ready             : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    StartStop         : BOOL;  // <-- [CMD] Commande marche/arrêt arbitrée
    Direction         : INT;   // <-- [CMD] Sens arbitré (-1: Rev, 0: Stop, 1: Fwd)
    SpeedPct          : REAL;  // <-- [CMD] Consigne vitesse arbitrée (0..100 %)
    PositioningActive : BOOL;  // <-- [CMD] Mode positionnement actif (SEMI_AUTO)
    SelTarget         : INT;   // <-- [CMD] Cible position (1=Trémie, 2=P2, 3=P1, 4=Maintenance) — SEMI_AUTO
END_VAR
VAR
    FreqPct : REAL;  // . [LOC] Échelle fréquence (0..100 %)
END_VAR

// === IMPLEMENTATION ===

Ready := Enable;

IF NOT Enable THEN
    StartStop         := FALSE;
    Direction         := 0;
    SpeedPct          := 0.0;
    PositioningActive := FALSE;
    SelTarget         := 0;
ELSE
    // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
    IF Auth.Mode = E_Mode.SEMI_AUTO THEN
        PositioningActive := TRUE;
        SelTarget := ReqTranslation.PositionTgt;
        StartStop := ReqTranslation.ReqStart AND Context.HeightInterlockOk;
        IF StartStop THEN
            SpeedPct := 100.0;
            IF SelTarget = 1 THEN
                Direction := 1;
            ELSE
                Direction := -1;
            END_IF;
        ELSE
            SpeedPct := 0.0;
            Direction := 0;
        END_IF;
    ELSIF (Auth.Mode = E_Mode.MAINT_N1) OR (Auth.Mode = E_Mode.MAINT_N2) THEN
        // ── Mode maintenance : jog joystick ou boutons IHM ──
        PositioningActive := IHM.SelPositioning;
        SelTarget := 0;

        IF NOT TglJoystickMaster AND IHM.BtnFwd THEN
            Direction := 1;
        ELSIF NOT TglJoystickMaster AND IHM.BtnRev THEN
            Direction := -1;
        ELSIF TglJoystickMaster THEN
            Direction := Joystick.AxisX.Direction;
        ELSE
            Direction := 0;
        END_IF;

        // Homme-mort exigé même pour boutons IHM en MAINT_N1/N2.
        // ⚠️ Tautologie conservée bit-identique : (BypassGlobal OR NOT Tgl OR Tgl) = toujours TRUE.
        StartStop := (Direction <> 0)
                     AND (IHM.BypassGlobal OR NOT TglJoystickMaster OR TglJoystickMaster)
                     AND Joystick.DeadmanArmed
                     AND Context.HeightInterlockOk;

        // Échelle fréquence : SetFreq_Hz (ou 100% si non renseignée), manche mis à l'échelle si joystick maître
        FreqPct := SEL(IHM.SetFreq_Hz > 0.0,
                       100.0,
                       (IHM.SetFreq_Hz / SEL(Cfg.MaxFreq_Hz > 0.0, 50.0, Cfg.MaxFreq_Hz)) * 100.0);
        SpeedPct := SEL(TglJoystickMaster,
                        FreqPct,
                        (ABS(Joystick.AxisX.SpeedTgt) / 100.0) * FreqPct);
    ELSE
        // ── Autres modes : neutralisé ──
        PositioningActive := FALSE;
        SelTarget := 0;
        StartStop := FALSE;
        Direction := 0;
        SpeedPct  := 0.0;
    END_IF;
END_IF;

// Clamp consigne (bit-identique PRG_05 §1)
SpeedPct := LIMIT(0.0, ABS(SpeedPct), 100.0);

// SelTarget = Maintenance (4) interdit si Maintenance non autorisée
IF (SelTarget = 4) AND NOT Auth.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

END_FUNCTION_BLOCK

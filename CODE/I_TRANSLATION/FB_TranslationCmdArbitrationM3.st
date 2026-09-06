(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationCmdArbitrationM3 — Arbitrage de commande M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Arbitrer la source de commande M3 (joystick jog / boutons IHM /
       demande cycle selon le mode) et produire la commande arbitrée.
   🔌 FB d'arbitrage (non-mouvement) : ne porte ni SafeStop ni arrêt de sécurité
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
    Auth           : ST_Modes_Autorisations;           // --> [CMD] Autorisations mode (Mode, MaintenanceM3TargetEnable)
    ReqTranslation : ST_ProgramTranslationRequest;        // --> [REQ] Demande cycle translation (SEMI_AUTO)
    IHM            : ST_fbTranslationCmdArbitration_IHM;  // --> [CMD] Boutons IHM, sélecteur, fréquence
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd, source unique)
    Context        : ST_fbTranslationCmdArbitration_Context; // --> [SAFE] Interlock hauteur
    Cfg            : ST_fbTranslationCmdArbitration_Cfg;     // --> [CFG] Fréquence max (échelle FreqPct)
END_VAR
VAR_OUTPUT
  Ready             : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
  RunRequest        : BOOL;  // <-- [CMD] Demande de marche maintenue (FALSE = décélération/arrêt)
  ReqTremie         : BOOL;  // <-- [CMD] Demande explicite vers Trémie
  ReqMaintenance    : BOOL;  // <-- [CMD] Demande explicite vers Maintenance
  CommandConflict   : BOOL;  // <-- [DIAG] Deux sens demandés simultanément
    SpeedPct          : REAL;  // <-- [CMD] Consigne vitesse arbitrée (0..100 %)
    PositioningActive : BOOL;  // <-- [CMD] Mode positionnement actif (SEMI_AUTO)
    SelTarget         : INT;   // <-- [CMD] Cible position (1=Trémie, 2=P2, 3=P1, 4=Maintenance) — SEMI_AUTO
END_VAR
VAR
    FreqPct : REAL;  // . [LOC] Échelle fréquence (0..100 %)
    CycleTargetDirectionOk : BOOL; // . [LOC] Axe X cohérent avec la cible SEMI_AUTO
    CycleJoystickAxisOk    : BOOL; // . [LOC] Axe Y neutre avant translation SEMI_AUTO
END_VAR

// === IMPLEMENTATION ===

Ready := Enable;

// Les deux bits de sens sont reconstruits à chaque cycle : aucune demande ne doit
// rester mémorisée lors d'un changement de source (IHM/joystick/cycle).
RunRequest      := FALSE;
ReqTremie       := FALSE;
ReqMaintenance  := FALSE;
CommandConflict := FALSE;

IF NOT Enable THEN
    RunRequest        := FALSE;
    ReqTremie         := FALSE;
    ReqMaintenance    := FALSE;
    CommandConflict   := FALSE;
    SpeedPct          := 0.0;
    PositioningActive := FALSE;
    SelTarget         := 0;
ELSE
    // ── Pont SEMI_AUTO : consomme la demande du séquenceur de cycle ──
    IF Auth.Mode = E_Mode.SEMI_AUTO THEN
        PositioningActive := TRUE;
        SelTarget := ReqTranslation.PositionTgt;
        CycleTargetDirectionOk := ((SelTarget = 1) AND Joystick.AxisX.DirectionPositive)
                               OR ((SelTarget <> 1) AND Joystick.AxisX.DirectionNegative);
        CycleJoystickAxisOk := CycleTargetDirectionOk AND Joystick.AxisY.AtNeutral;
        RunRequest := ReqTranslation.ReqStart AND Context.HeightInterlockOk AND CycleJoystickAxisOk;
        IF RunRequest THEN
            SpeedPct := 100.0;
            IF SelTarget = 1 THEN
                ReqTremie := TRUE;
            ELSE
                ReqMaintenance := TRUE;
            END_IF;
        ELSE
            SpeedPct := 0.0;
        END_IF;
    ELSIF (Auth.Mode = E_Mode.MAINT_N1) OR (Auth.Mode = E_Mode.MAINT_N2) THEN
        // ── Mode maintenance : jog joystick ou boutons IHM ──
        PositioningActive := IHM.SelPositioning;
        SelTarget := 0;

        IF NOT TglJoystickMaster AND IHM.BtnTremie THEN
            ReqTremie := TRUE;
        ELSIF NOT TglJoystickMaster AND IHM.BtnMaintenance THEN
            ReqMaintenance := TRUE;
        ELSIF TglJoystickMaster THEN
            ReqTremie := Joystick.AxisX.DirectionPositive;
            ReqMaintenance := Joystick.AxisX.DirectionNegative;
        END_IF;

        // Homme-mort exigé même pour boutons IHM en MAINT_N1/N2.
        // ⚠️ Tautologie conservée bit-identique : (BypassGlobal OR NOT Tgl OR Tgl) = toujours TRUE.
        RunRequest := (ReqTremie OR ReqMaintenance)
                     AND (IHM.BypassGlobal OR NOT TglJoystickMaster OR TglJoystickMaster)
                     AND Joystick.DeadmanArmed
                     // Interlock inter-axes : un ordre treuil Y bloque M3.
                     AND (NOT TglJoystickMaster OR (Joystick.AxisY.Direction = 0))
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
        RunRequest := FALSE;
        SpeedPct  := 0.0;
    END_IF;
END_IF;

// Une demande contradictoire est toujours neutralisée. RunRequest reste vrai afin de
// conserver la sémantique de décélération de FB_Translation ; aucune direction n'est choisie.
CommandConflict := ReqTremie AND ReqMaintenance;
IF CommandConflict THEN
    ReqTremie := FALSE;
    ReqMaintenance := FALSE;
END_IF;

// Clamp consigne (bit-identique PRG_05 §1)
SpeedPct := LIMIT(0.0, ABS(SpeedPct), 100.0);

// SelTarget = Maintenance (4) interdit si Maintenance non autorisée
IF (SelTarget = 4) AND NOT Auth.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

END_FUNCTION_BLOCK

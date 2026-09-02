(* ═══════════════════════════════════════════════════════════════
   🪣 FB_BucketCmdArbitration — Arbitrage de commande benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Arbitrer la source de commande benne (boutons IHM /
       séquencement couplé both / demande cycle selon le mode) et produire
       les commandes arbitrées (ouverture, fermeture, contacteur Kobold).
   🔌 FB d'arbitrage (non-mouvement) : ne porte ni SafeStop ni StartStop
       de sécurité — il produit la commande logique, la safety reste dans
       FB_Bucket / FB_Safety_Winch.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔒 Bit-identique à l'ancien PRG_04 §1/§2 (refactor POO §5 : décision dans
       le FB, plus dans le PRG). Symétrique à FB_WinchCmdArbitrationM1/M2.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_BucketCmdArbitration
VAR_INPUT
    Enable    : BOOL;  // --> [CMD] Autorisation FB (TRUE=arbitre actif)
    Auth      : ST_Modes_Autorisations;          // --> [CMD] Autorisations mode (Mode, gating séquencement couplé)
    ReqBucket : ST_ProgramBucketRequest;            // --> [REQ] Demande cycle benne (SEMI_AUTO)
    IHM       : ST_fbBucketCmdArbitration_IHM;      // --> [CMD] Boutons IHM benne (BtnOpen/BtnClose)
    Context   : ST_fbBucketCmdArbitration_Context;   // --> [STAT] Gating séquencement couplé benne
END_VAR
VAR_OUTPUT
    Ready     : BOOL;  // <-- [STAT] FB prêt à arbitrer (Enable)
    CmdOpen_IHM  : BOOL;  // <-- [CMD] Commande ouverture benne arbitrée
    CmdClose_IHM : BOOL;  // <-- [CMD] Commande fermeture benne arbitrée
    KoboldContactorCmdArbitrated : BOOL;  // <-- [CMD] Ordre contacteur capteur fond Kobold arbitré
    WinchBothDiveBucketOpenArmed    : BOOL;  // <-- [STAT] Séquencement couplé : descente benne ouverte armé
    WinchBothAscentBucketCloseArmed : BOOL;  // <-- [STAT] Séquencement couplé : montée benne fermée armé
END_VAR

// === IMPLEMENTATION ===

Ready := Enable;

IF NOT Enable THEN
    CmdOpen_IHM  := FALSE;
    CmdClose_IHM := FALSE;
    KoboldContactorCmdArbitrated := FALSE;
    WinchBothDiveBucketOpenArmed    := FALSE;
    WinchBothAscentBucketCloseArmed := FALSE;
ELSE
    // ── Règle absolue en pilotage both normal (bit-identique PRG_04 §1) ──
    // Descente autorisée UNIQUEMENT benne ouverte, montée UNIQUEMENT benne fermée.
    WinchBothDiveBucketOpenArmed := Context.TglEnableCoupledBucketSequencing
        AND (Auth.Mode <> E_Mode.SEMI_AUTO)
        AND Context.MotionActive AND Context.ReqDescend
        AND NOT Context.BucketIsOpen;
    WinchBothAscentBucketCloseArmed := Context.TglEnableCoupledBucketSequencing
        AND (Auth.Mode <> E_Mode.SEMI_AUTO)
        AND Context.MotionActive AND Context.ReqAscent
        AND NOT Context.BucketIsClosed;

    // ── Ouverture benne : bouton IHM OU séquencement couplé descente benne ouverte
    //    OU demande cycle (bit-identique PRG_04 §2) ──
    CmdOpen_IHM := IHM.BtnOpen OR WinchBothDiveBucketOpenArmed OR ReqBucket.ReqOpen;

    // ── Fermeture benne : demande cycle > séquencement couplé montée benne fermée
    //    > bouton IHM (bit-identique PRG_04 §1) ──
    IF ReqBucket.ReqClose THEN
        CmdClose_IHM := TRUE;
    ELSIF WinchBothAscentBucketCloseArmed THEN
        CmdClose_IHM := TRUE;
    ELSE
        CmdClose_IHM := IHM.BtnClose;
    END_IF;

    // ── Contacteur Kobold : demande cycle (source unique PRG_03, bit-identique PRG_04 §1) ──
    KoboldContactorCmdArbitrated := ReqBucket.ReqKoboldMeasureEnable;
END_IF;

END_FUNCTION_BLOCK

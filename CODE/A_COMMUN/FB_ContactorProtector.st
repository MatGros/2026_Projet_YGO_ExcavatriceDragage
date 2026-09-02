(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_ContactorProtector — Garde anti-chatter avant sortie contacteur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : à placer juste avant une sortie contacteur puissance (comme un
      interlock). Une activation autorisée passe intégralement ; à sa retombée,
      aucune nouvelle activation avant Cfg_MinInterval. Empêche le cyclage
      rapide destructif quelle que soit la source (bug logique, spam, bypass).
   🔒 Sécurité positive : Enable=FALSE => Cmd=FALSE. Ne force jamais une sortie.
   📄 Doc métier : DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_ContactorProtector
VAR_INPUT
    Enable          : BOOL;          // --> [CMD] Autorisation (FALSE => Cmd=FALSE, Ready=FALSE)
    Request         : BOOL;          // --> [CMD] Demande de commande contacteur (niveau)
    Cfg_MinInterval : TIME := T#500ms; // --> [CFG] Intervalle mini entre deux activations
END_VAR
VAR_OUTPUT
    Ready           : BOOL; // <-- [STAT] Garde active
    Allowed         : BOOL; // <-- [STAT] TRUE = nouvelle activation possible (hors intervalle)
    Cmd             : BOOL; // <-- [ACT]  Commande filtree a cabler au contacteur
END_VAR
VAR
    ReqFall         : F_TRIG; // . [LOC] Front descendant Request (arme l'intervalle)
    TonInterval     : TON;    // . [LOC] Tempo intervalle mini (armee a la retombee)
    InhibitActive   : BOOL;   // . [LOC] Intervalle en cours -> nouvelle activation bloquee
    ActivationLatched : BOOL; // . [LOC] Activation autorisee en cours (passe toute la duree de Request)
END_VAR

IF NOT Enable THEN
    Cmd := FALSE;
    Ready := FALSE;
    Allowed := FALSE;
    InhibitActive := FALSE;
    ActivationLatched := FALSE;
    TonInterval(IN := FALSE);
ELSE
    Ready := TRUE;
    ReqFall(CLK := Request);

    // Intervalle : arme a la retombee d'une activation, tient Cfg_MinInterval
    IF ReqFall.Q THEN
        InhibitActive := TRUE;
    END_IF;
    TonInterval(IN := InhibitActive, PT := Cfg_MinInterval);
    IF TonInterval.Q THEN
        InhibitActive := FALSE;
    END_IF;

    // Une demande passe integralement (non decoupee) tant qu'elle est maintenue, mais ne
    // peut (re)demarrer que hors intervalle. Test de niveau : robuste si Request est deja
    // TRUE au demarrage (pas de front observe).
    IF Request AND NOT InhibitActive THEN
        ActivationLatched := TRUE;
    END_IF;
    IF NOT Request THEN
        ActivationLatched := FALSE;
    END_IF;

    Allowed := NOT InhibitActive;
    Cmd := ActivationLatched;
END_IF;

END_FUNCTION_BLOCK

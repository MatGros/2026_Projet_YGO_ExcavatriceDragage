(* ═══════════════════════════════════════════════════════════════
   📊 ST_EmergencyState — État IHM de la chaîne AU / sécurité
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : État/diagnostic IHM de la chaîne d'arrêt d'urgence,
      sorti de `Modes.State`. Point de vue IHM : `State` regroupe les
      champs d'état AU (ChainOk, ContactorOk, Armable, ArmingBusy, Step)
      en champs plats, les commandes physiques fail-safe du FB AU
      (MaintainA/B_Cmd, ArmPulse_Cmd) exposées comme states/info, et le
      diagnostic AU (`Diag : ST_Safety_Emergency_Diag`) en structure
      interne. PAS de sous-State imbriqué, PAS de dossier `Diag` au top
      de `Emergency` — le diagnostic vit dans `State`.
   🔌 Interface : Produit par PRG_07_Supervision, consommé par l'IHM.
   📄 Doc : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md §5
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EmergencyState :
STRUCT
    // ── État AU (champs plats, miroir du DUT AU ST_Safety_Emergency_State) ──
    ChainOk     : BOOL; // Boucle AU fermee (EmergencyChainClosed = TRUE)
    ContactorOk : BOOL; // Contacteur puissance confirme engage (PowerContactorEngaged = TRUE)
    Step        : INT;  // Etape sequence armement : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    Armable     : BOOL; // Rearmement possible maintenant (= ArmRequestAllowed) : chain OK, step=0, pas de lockout
    ArmingBusy  : BOOL; // Sequence armement OU lockout en cours (nouvelle demande ignoree)

    // ── États publics FB AU (Ready/Done/Fault/OperatorMessage) ──
    // Miroir des champs Status du FB_Safety_EmergencyManagement (produits par PRG_06).
    // Busy n'est PAS exposé : redondant avec ArmingBusy (déjà présent ci-dessus).
    Ready           : BOOL; // FB AU pret a fonctionner (Enable + pas de StartupFail)
    Done            : BOOL; // Cycle rearmement AU termine (contacteur puissance confirme engage)
    Fault           : ST_Fault; // Defaut latte de la chaine AU (socle FB_FaultCore, vue live + latchee)
    OperatorMessage : STRING(120); // Message operateur par etat / par probleme de la chaine AU

    // ── Commandes physiques fail-safe du FB AU (exposées comme states/info) ──
    MaintainA_Cmd : BOOL; // Sortie pilotage canal A (TRUE = voie maintenue) — interne FB AU
    MaintainB_Cmd : BOOL; // Sortie pilotage canal B (TRUE = voie maintenue) — interne FB AU
    ArmPulse_Cmd  : BOOL; // Impulsion rearmement physique (1s) — interne FB AU

    // ── Diagnostic AU (structure interne de State) ──
    Diag : ST_Safety_Emergency_Diag; // Diagnostic et erreurs de la chaîne AU
END_STRUCT
END_TYPE
